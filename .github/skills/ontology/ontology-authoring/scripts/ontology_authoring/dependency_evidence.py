#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Generate provenance-bound dependency evidence from a canonical uv lock."""

from __future__ import annotations

import argparse
import hashlib
import importlib.metadata
import json
import re
import sys
import tomllib
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable
from datetime import UTC, datetime
from pathlib import Path
from typing import Any

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_ERROR = 2
PUBLIC_INDEX = "https://pypi.org/simple"
SHA_PATTERN = re.compile(r"^[0-9a-f]{40}$")
AUDITED_LICENSE_OVERRIDES = {
    ("atheris", "3.1.0"): {
        "expression": "Apache-2.0",
        "metadataSource": (
            "https://api.github.com/repos/google/atheris/git/blobs/"
            "7a4a3ea2424c09fbe48d455aed1eaa94d9124835"
        ),
    },
}


class EvidenceError(Exception):
    """Raised when dependency evidence cannot be trusted."""


def canonicalize_name(name: str) -> str:
    """Return a normalized Python distribution name."""
    return re.sub(r"[-_.]+", "-", name).lower()


def sha256_file(path: Path) -> str:
    """Return the lowercase SHA-256 digest for a file."""
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: dict[str, Any]) -> None:
    """Write stable UTF-8 JSON with a trailing newline."""
    path.write_text(json.dumps(value, indent=2,
                    sort_keys=True) + "\n", encoding="utf-8")


def read_lock_packages(lock_path: Path) -> tuple[list[dict[str, Any]], set[str]]:
    """Read canonical registry packages and direct dependency names from a uv lock."""
    lock = tomllib.loads(lock_path.read_text(encoding="utf-8"))
    packages = lock.get("package")
    if not isinstance(packages, list):
        raise EvidenceError("uv.lock does not contain a package array")

    direct_names: set[str] = set()
    registry_packages: list[dict[str, Any]] = []
    for package in packages:
        if not isinstance(package, dict):
            raise EvidenceError("uv.lock contains a malformed package entry")
        source = package.get("source")
        if not isinstance(source, dict):
            raise EvidenceError(
                f"Package {package.get('name', '<unknown>')} has no source")
        if "virtual" in source or "editable" in source:
            for dependency in package.get("dependencies", []):
                if isinstance(dependency, dict) and isinstance(dependency.get("name"), str):
                    direct_names.add(canonicalize_name(dependency["name"]))
            for dependencies in package.get("dev-dependencies", {}).values():
                for dependency in dependencies:
                    if isinstance(dependency, dict) and isinstance(dependency.get("name"), str):
                        direct_names.add(canonicalize_name(dependency["name"]))
            continue
        if source.get("registry") != PUBLIC_INDEX:
            raise EvidenceError(
                f"Package {package.get('name', '<unknown>')} is not locked to {PUBLIC_INDEX}"
            )
        if not isinstance(package.get("name"), str) or not isinstance(package.get("version"), str):
            raise EvidenceError(
                "Registry package is missing a name or version")
        registry_packages.append(package)

    return registry_packages, direct_names


def extract_license_fields(metadata: importlib.metadata.PackageMetadata) -> dict[str, Any]:
    """Normalize available core-metadata license fields."""
    expression = (metadata.get("License-Expression") or "").strip()
    declared = (metadata.get("License") or "").strip()
    if declared.upper() == "UNKNOWN":
        declared = ""
    classifiers = sorted(
        classifier
        for classifier in (metadata.get_all("Classifier") or [])
        if classifier.startswith("License ::")
    )
    return {
        "expression": expression or None,
        "declared": declared or None,
        "classifiers": classifiers,
        "status": "known" if expression or declared or classifiers else "unknown",
    }


def fetch_public_metadata(name: str, version: str) -> dict[str, Any]:
    """Fetch immutable release metadata for a platform-conditional lock entry."""
    quoted_name = urllib.parse.quote(name, safe="")
    quoted_version = urllib.parse.quote(version, safe="")
    url = f"https://pypi.org/pypi/{quoted_name}/{quoted_version}/json"
    try:
        with urllib.request.urlopen(url, timeout=30) as response:  # noqa: S310
            payload = json.load(response)
    except (OSError, urllib.error.URLError, json.JSONDecodeError) as error:
        raise EvidenceError(
            f"Could not retrieve public metadata for {name}=={version}") from error
    info = payload.get("info") if isinstance(payload, dict) else None
    if not isinstance(info, dict):
        raise EvidenceError(
            f"Public metadata is malformed for {name}=={version}")
    expression = str(info.get("license_expression") or "").strip()
    declared = str(info.get("license") or "").strip()
    if declared.upper() == "UNKNOWN":
        declared = ""
    classifiers = sorted(
        classifier
        for classifier in info.get("classifiers", [])
        if isinstance(classifier, str) and classifier.startswith("License ::")
    )
    return {
        "expression": expression or None,
        "declared": declared or None,
        "classifiers": classifiers,
        "status": "known" if expression or declared or classifiers else "unknown",
    }


def apply_audited_license_override(
    name: str,
    version: str,
    license_fields: dict[str, Any],
    metadata_source: str,
) -> tuple[dict[str, Any], str]:
    """Apply an exact audited fallback when package metadata omits its license."""
    if license_fields["status"] != "unknown":
        return license_fields, metadata_source
    override = AUDITED_LICENSE_OVERRIDES.get(
        (canonicalize_name(name), version))
    if override is None:
        return license_fields, metadata_source
    return (
        {
            "expression": override["expression"],
            "declared": None,
            "classifiers": [],
            "status": "known",
        },
        override["metadataSource"],
    )


def collect_license_inventory(
    lock_path: Path,
    distribution_provider: Callable[[str], importlib.metadata.Distribution]
    = importlib.metadata.distribution,
    public_metadata_provider: Callable[[
        str, str], dict[str, Any]] = fetch_public_metadata,
) -> list[dict[str, Any]]:
    """Reconcile every locked registry package with its installed metadata."""
    packages, direct_names = read_lock_packages(lock_path)
    inventory: list[dict[str, Any]] = []
    for package in packages:
        name = package["name"]
        try:
            distribution = distribution_provider(name)
        except (importlib.metadata.PackageNotFoundError, KeyError):
            license_fields = public_metadata_provider(name, package["version"])
            metadata_source = "https://pypi.org/pypi"
        else:
            if distribution.version != package["version"]:
                license_fields = public_metadata_provider(
                    name, package["version"])
                metadata_source = "https://pypi.org/pypi"
            else:
                license_fields = extract_license_fields(distribution.metadata)
                metadata_source = "installed-core-metadata"
        license_fields, metadata_source = apply_audited_license_override(
            name,
            package["version"],
            license_fields,
            metadata_source,
        )
        inventory.append(
            {
                "name": canonicalize_name(name),
                "version": package["version"],
                "relationship": (
                    "direct" if canonicalize_name(
                        name) in direct_names else "transitive"
                ),
                "source": PUBLIC_INDEX,
                "metadataSource": metadata_source,
                "license": license_fields,
            }
        )

    unknown = [item["name"]
               for item in inventory if item["license"]["status"] == "unknown"]
    if unknown:
        raise EvidenceError(
            f"Unknown license metadata: {', '.join(sorted(unknown))}")
    return sorted(inventory, key=lambda item: item["name"])


def create_evidence(args: argparse.Namespace) -> None:
    """Create the license inventory, generation record, and inner hash manifest."""
    if not SHA_PATTERN.fullmatch(args.source_commit):
        raise EvidenceError(
            "source commit must be a full lowercase 40-character SHA")
    bundle_dir = args.bundle_dir.resolve()
    bundle_dir.mkdir(parents=True, exist_ok=True)
    lock_path = bundle_dir / "uv.lock"
    sbom_path = bundle_dir / "dependency-sbom.cdx.json"
    command_path = bundle_dir / "command-evidence.json"
    for required_path in (lock_path, sbom_path, command_path, args.pyproject):
        if not required_path.is_file():
            raise EvidenceError(
                f"Required evidence input is missing: {required_path}")

    inventory = collect_license_inventory(lock_path)
    inventory_path = bundle_dir / "dependency-license-inventory.json"
    write_json(
        inventory_path,
        {
            "schemaVersion": "1.0",
            "generatedAt": datetime.now(UTC).isoformat(),
            "packages": inventory,
        },
    )

    generation_path = bundle_dir / "dependency-generation-record.json"
    write_json(
        generation_path,
        {
            "schemaVersion": "1.0",
            "repository": args.repository,
            "sourceCommit": args.source_commit,
            "workflowRef": args.workflow_ref,
            "workflowRunId": args.workflow_run_id,
            "workflowRunUrl": args.workflow_run_url,
            "artifactName": args.artifact_name,
            "checkoutAction": args.checkout_action,
            "uploadArtifactAction": args.upload_artifact_action,
            "pythonVersion": args.python_version,
            "uvVersion": args.uv_version,
            "pyprojectSha256": sha256_file(args.pyproject),
            "lockSha256": sha256_file(lock_path),
            "sbomSha256": sha256_file(sbom_path),
            "commandEvidenceSha256": sha256_file(command_path),
        },
    )

    manifest_path = bundle_dir / "artifact-manifest.json"
    files = []
    for path in sorted(bundle_dir.iterdir(), key=lambda item: item.name):
        if path.is_file() and path != manifest_path:
            files.append(
                {"path": path.name, "sha256": sha256_file(
                    path), "sizeBytes": path.stat().st_size}
            )
    write_json(
        manifest_path,
        {"schemaVersion": "1.0", "algorithm": "SHA256", "files": files},
    )


def create_parser() -> argparse.ArgumentParser:
    """Create the command-line parser."""
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--bundle-dir", type=Path, required=True)
    parser.add_argument("--pyproject", type=Path, required=True)
    parser.add_argument("--repository", required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--workflow-ref", required=True)
    parser.add_argument("--workflow-run-id", required=True)
    parser.add_argument("--workflow-run-url", required=True)
    parser.add_argument("--artifact-name", required=True)
    parser.add_argument("--checkout-action", required=True)
    parser.add_argument("--upload-artifact-action", required=True)
    parser.add_argument("--python-version", required=True)
    parser.add_argument("--uv-version", required=True)
    return parser


def main() -> int:
    """Run dependency evidence generation."""
    try:
        create_evidence(create_parser().parse_args())
        return EXIT_SUCCESS
    except EvidenceError as error:
        print(f"Error: {error}", file=sys.stderr)
        return EXIT_FAILURE
    except KeyboardInterrupt:
        return 130


if __name__ == "__main__":
    sys.exit(main())
