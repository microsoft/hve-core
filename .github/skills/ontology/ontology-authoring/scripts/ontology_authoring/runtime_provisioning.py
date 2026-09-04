#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Provision and verify the ontology-authoring runtime from its canonical lock."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import platform
import shutil
import subprocess
import sys
import sysconfig
import tempfile
import tomllib
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
EXPECTED_PYTHON = (3, 11)
EXPECTED_UV_VERSION = "0.10.8"
PUBLIC_INDEX = "https://pypi.org/simple"
INDEX_ENVIRONMENT_VARIABLES = (
    "PIP_EXTRA_INDEX_URL",
    "PIP_INDEX_URL",
    "UV_DEFAULT_INDEX",
    "UV_EXTRA_INDEX_URL",
    "UV_INDEX",
    "UV_INDEX_URL",
)
IMPORT_CHECK = """
import importlib.metadata
import json
import socket

def deny_network(*args, **kwargs):
    raise RuntimeError("network access is disabled during runtime verification")

socket.create_connection = deny_network
socket.socket.connect = deny_network

try:
    socket.create_connection(("example.invalid", 443))
except RuntimeError as error:
    if str(error) != "network access is disabled during runtime verification":
        raise
else:
    raise RuntimeError("network deny control did not block socket access")

import jsonschema
import pyshacl
import rdflib

print(json.dumps({
    name: importlib.metadata.version(name)
    for name in ("jsonschema", "pyshacl", "rdflib")
}, sort_keys=True))
""".strip()


class ProvisioningError(Exception):
    """Raised when portable runtime provisioning cannot be trusted."""


def sha256_file(path: Path) -> str:
    """Return the lowercase SHA-256 digest for a file."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def validate_python_version(version_info: tuple[int, int]) -> None:
    """Require the Python minor version governed by the canonical lock."""
    if version_info != EXPECTED_PYTHON:
        raise ProvisioningError(
            "Python 3.11 is required; install Python 3.11 and rerun this command"
        )


def parse_uv_version(output: str) -> str:
    """Return and validate the exact uv version from command output."""
    parts = output.strip().split()
    if len(parts) < 2 or parts[0] != "uv":
        raise ProvisioningError("Could not determine the installed uv version")
    version = parts[1]
    if version != EXPECTED_UV_VERSION:
        raise ProvisioningError(
            f"uv {EXPECTED_UV_VERSION} is required; found {version}. "
            f"Install uv {EXPECTED_UV_VERSION} and rerun this command"
        )
    return version


def verify_public_lock(lock_path: Path) -> str:
    """Verify that every registry package remains bound to canonical public PyPI."""
    if not lock_path.is_file():
        raise ProvisioningError(f"Canonical lock not found: {lock_path}")
    lock = tomllib.loads(lock_path.read_text(encoding="utf-8"))
    if lock.get("requires-python") != "==3.11.*":
        raise ProvisioningError("Canonical lock does not require Python 3.11")
    packages = lock.get("package")
    if not isinstance(packages, list):
        raise ProvisioningError("Canonical lock does not contain a package array")
    for package in packages:
        if not isinstance(package, dict):
            raise ProvisioningError("Canonical lock contains a malformed package entry")
        source = package.get("source")
        if not isinstance(source, dict):
            raise ProvisioningError("Canonical lock contains a package without a source")
        registry = source.get("registry")
        if registry is not None and registry != PUBLIC_INDEX:
            raise ProvisioningError(
                f"Package {package.get('name', '<unknown>')} is not locked to {PUBLIC_INDEX}"
            )
    return sha256_file(lock_path)


def default_environment_path(lock_digest: str, system: str | None = None) -> Path:
    """Return a platform-appropriate external cache path keyed by lock digest."""
    operating_system = system or platform.system()
    if operating_system == "Windows":
        cache_root = Path(os.environ.get("LOCALAPPDATA", Path.home() / "AppData" / "Local"))
    elif operating_system == "Darwin":
        cache_root = Path.home() / "Library" / "Caches"
    else:
        cache_root = Path(os.environ.get("XDG_CACHE_HOME", Path.home() / ".cache"))
    return cache_root / "hve-core" / "ontology-authoring" / lock_digest[:16]


def environment_python_path(environment_path: Path, system: str | None = None) -> Path:
    """Return the virtual-environment interpreter path for the target host."""
    operating_system = system or platform.system()
    if operating_system == "Windows":
        return environment_path / "Scripts" / "python.exe"
    return environment_path / "bin" / "python"


def build_sync_command(uv_command: str, project_root: Path) -> list[str]:
    """Build the frozen runtime-only synchronization command."""
    return [
        uv_command,
        "sync",
        "--project",
        str(project_root),
        "--frozen",
        "--no-dev",
        "--no-group",
        "fuzz",
        "--no-install-project",
    ]


def build_export_command(
    uv_command: str, project_root: Path, requirements_path: Path
) -> list[str]:
    """Build a frozen runtime-only export command for configured indexes."""
    return [
        uv_command,
        "export",
        "--project",
        str(project_root),
        "--frozen",
        "--no-dev",
        "--no-group",
        "fuzz",
        "--no-emit-project",
        "--format",
        "requirements.txt",
        "--output-file",
        str(requirements_path),
    ]


def build_pip_sync_command(
    uv_command: str, runtime_python: Path, requirements_path: Path
) -> list[str]:
    """Build an exact hash-required, wheels-only synchronization command."""
    return [
        uv_command,
        "pip",
        "sync",
        "--python",
        str(runtime_python),
        "--require-hashes",
        "--strict",
        "--only-binary",
        ":all:",
        str(requirements_path),
    ]


def classify_restore() -> str:
    """Classify index configuration without retaining endpoint values."""
    if any(os.environ.get(name) for name in INDEX_ENVIRONMENT_VARIABLES):
        return "environment-configured-index"
    return "canonical-public-index"


def redact_configured_indexes(message: str, environment: dict[str, str]) -> str:
    """Remove configured package-index values from command output."""
    redacted = message
    for name in INDEX_ENVIRONMENT_VARIABLES:
        value = environment.get(name)
        if value:
            redacted = redacted.replace(value, "<configured-index>")
    return redacted


def run_command(command: list[str], *, environment: dict[str, str] | None = None) -> str:
    """Run a command and return stdout, preserving useful failure output."""
    try:
        result = subprocess.run(
            command,
            capture_output=True,
            check=True,
            env=environment,
            text=True,
        )
    except FileNotFoundError as error:
        raise ProvisioningError(f"Required command not found: {command[0]}") from error
    except subprocess.CalledProcessError as error:
        details = (error.stderr or error.stdout or "no command output").strip()
        details = redact_configured_indexes(details, environment or os.environ)
        raise ProvisioningError(f"Command failed ({error.returncode}): {details}") from error
    return result.stdout.strip()


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(
        description="Provision the portable ontology-authoring Python runtime"
    )
    parser.add_argument("--project-root", type=Path, required=True)
    parser.add_argument("--environment", type=Path)
    parser.add_argument("--evidence-output", type=Path)
    parser.add_argument("--uv-command", default="uv")
    parser.add_argument("--dry-run", action="store_true")
    return parser


def provision(args: argparse.Namespace) -> dict[str, Any]:
    """Provision the exact runtime graph and verify imports without dependency egress."""
    validate_python_version((sys.version_info.major, sys.version_info.minor))
    project_root = args.project_root.resolve()
    lock_digest = verify_public_lock(project_root / "uv.lock")
    uv_path = shutil.which(args.uv_command)
    if uv_path is None:
        raise ProvisioningError(
            f"uv {EXPECTED_UV_VERSION} is required; install it and rerun this command"
        )
    uv_version = parse_uv_version(run_command([uv_path, "--version"]))
    environment_path = (
        args.environment.expanduser().resolve()
        if args.environment
        else default_environment_path(lock_digest)
    )
    sync_command = build_sync_command(uv_path, project_root)
    restore_class = classify_restore()
    runtime_python = environment_python_path(environment_path)
    if args.dry_run:
        result = {
            "dryRun": True,
            "environmentClass": "external-lock-keyed-cache",
            "lockSha256": lock_digest,
            "restoreClass": restore_class,
            "uvVersion": uv_version,
        }
        if restore_class == "environment-configured-index":
            requirements_path = Path("<temporary-requirements>")
            result["restoreCommands"] = [
                build_export_command(uv_path, project_root, requirements_path),
                [uv_path, "venv", "--python", sys.executable, str(environment_path)],
                build_pip_sync_command(uv_path, runtime_python, requirements_path),
            ]
        else:
            result["restoreCommands"] = [sync_command]
        return result

    command_environment = os.environ.copy()
    if restore_class == "environment-configured-index":
        environment_path.parent.mkdir(parents=True, exist_ok=True)
        descriptor, requirement_name = tempfile.mkstemp(
            dir=environment_path.parent,
            prefix=f".{environment_path.name}-",
            suffix="-requirements.txt",
        )
        os.close(descriptor)
        requirements_path = Path(requirement_name)
        try:
            run_command(
                build_export_command(uv_path, project_root, requirements_path),
                environment=command_environment,
            )
            run_command(
                [uv_path, "venv", "--python", sys.executable, str(environment_path)],
                environment=command_environment,
            )
            run_command(
                build_pip_sync_command(uv_path, runtime_python, requirements_path),
                environment=command_environment,
            )
        finally:
            requirements_path.unlink(missing_ok=True)
    else:
        command_environment["UV_PROJECT_ENVIRONMENT"] = str(environment_path)
        run_command(sync_command, environment=command_environment)
    if not runtime_python.is_file():
        raise ProvisioningError("uv completed without creating the runtime interpreter")
    package_output = run_command([str(runtime_python), "-I", "-c", IMPORT_CHECK])
    packages = json.loads(package_output)
    evidence = {
        "schemaVersion": "1.0",
        "createdAt": datetime.now(UTC).isoformat(),
        "status": "passed",
        "environmentClass": "external-lock-keyed-cache",
        "lockSha256": lock_digest,
        "networkVerification": "socket-connect-denied-during-imports",
        "packages": packages,
        "restoreClass": restore_class,
        "target": {
            "architecture": platform.machine(),
            "operatingSystem": platform.system(),
            "pythonAbi": sysconfig.get_config_var("SOABI") or "unknown",
            "pythonImplementation": platform.python_implementation(),
            "pythonVersion": platform.python_version(),
            "uvVersion": uv_version,
        },
    }
    if args.evidence_output:
        output_path = args.evidence_output.expanduser().resolve()
        output_path.parent.mkdir(parents=True, exist_ok=True)
        output_path.write_text(
            json.dumps(evidence, indent=2, sort_keys=True) + "\n", encoding="utf-8"
        )
    return evidence


def main() -> int:
    """Run portable runtime provisioning."""
    try:
        result = provision(create_parser().parse_args())
        print(json.dumps(result, indent=2, sort_keys=True))
        return EXIT_SUCCESS
    except ProvisioningError as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_ERROR
    except (OSError, json.JSONDecodeError, tomllib.TOMLDecodeError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        return EXIT_FAILURE
    except KeyboardInterrupt:
        print("Interrupted by user", file=sys.stderr)
        return 130


if __name__ == "__main__":
    sys.exit(main())
