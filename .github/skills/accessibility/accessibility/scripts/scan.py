#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# /// script
# requires-python = ">=3.11"
# ///

"""Thin CLI wrapper for the Node-based axe-core accessibility scanner."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from pathlib import Path
from typing import Any
from urllib.parse import urlparse
from urllib.request import url2pathname

from runtime_a11y._config import assert_host_allowed
from runtime_a11y._errors import ScriptError as RuntimeScriptError

EXIT_SUCCESS = 0
EXIT_FAILURE = 1
EXIT_USAGE = 2


class ScriptError(Exception):
    """Raised when the scanner cannot complete the requested operation."""

    def __init__(self, message: str, exit_code: int = EXIT_FAILURE) -> None:
        super().__init__(message)
        self.exit_code = exit_code


def create_parser() -> argparse.ArgumentParser:
    """Create and configure argument parser."""
    parser = argparse.ArgumentParser(
        description="Run the axe-core accessibility scanner against a URL or file."
    )
    parser.add_argument("target", help="URL or local file to scan")
    parser.add_argument(
        "--output",
        type=Path,
        default=None,
        help="Path to write normalized JSON output (defaults to stdout)",
    )
    parser.add_argument(
        "--allow-host",
        action="append",
        default=[],
        metavar="HOST",
        help="Authorize one non-loopback HTTP(S) host (repeatable)",
    )
    parser.add_argument(
        "--allow-external",
        action="store_true",
        help="Confirm intentional access to any non-loopback HTTP(S) host",
    )
    return parser


def normalize_results(raw_results: dict[str, Any], target: str) -> dict[str, Any]:
    """Normalize raw axe-core findings into a stable JSON shape.

    Args:
        raw_results: Raw JSON payload from the axe-core scanner.
        target: Target URL or file path that was scanned.

    Returns:
        Normalized result object with summary and violations details.
    """
    if not isinstance(raw_results, dict):
        return {
            "target": target,
            "summary": {
                "violations": 0,
                "passes": 0,
                "incomplete": 0,
                "inapplicable": 0,
            },
            "violations": [],
        }

    results_payload = raw_results.get("results")
    violations_payload = raw_results.get("violations")
    if isinstance(results_payload, list):
        for item in results_payload:
            if isinstance(item, dict) and isinstance(item.get("violations"), list):
                violations_payload = item.get("violations")
                break

    passes_payload = raw_results.get("passes")
    incomplete_payload = raw_results.get("incomplete")
    inapplicable_payload = raw_results.get("inapplicable")

    violations = []
    if isinstance(violations_payload, list):
        for violation in violations_payload:
            if isinstance(violation, dict):
                violations.append(
                    {
                        "id": violation.get("id", ""),
                        "impact": violation.get("impact", ""),
                        "description": violation.get("description", ""),
                        "nodes": len(violation.get("nodes", []) or []),
                    }
                )

    normalized = {
        "target": target,
        "summary": {
            "violations": len(violations),
            "passes": (len(passes_payload) if isinstance(passes_payload, list) else 0),
            "incomplete": (
                len(incomplete_payload) if isinstance(incomplete_payload, list) else 0
            ),
            "inapplicable": (
                len(inapplicable_payload)
                if isinstance(inapplicable_payload, list)
                else 0
            ),
        },
        "violations": violations,
    }
    return normalized


def _is_network_path(path: Path) -> bool:
    """Return True for UNC or protocol-relative paths that would reach the network."""
    return str(path).replace("\\", "/").startswith("//")


def _canonical_local_file(path: Path) -> str:
    """Return a canonical file URI for an existing regular local file."""
    # Rejected before any probe so a UNC path never triggers an outbound SMB request.
    if _is_network_path(path):
        raise ScriptError(
            "Network-share and protocol-relative scan targets are not supported",
            EXIT_USAGE,
        )
    if not path.exists():
        raise ScriptError("Local scan target does not exist", EXIT_USAGE)
    if not path.is_file():
        raise ScriptError("Local scan target must be a regular file", EXIT_USAGE)
    return path.resolve().as_uri()


def resolve_scan_target(
    target: str,
    allow_hosts: list[str] | None = None,
    allow_external: bool = False,
) -> str:
    """Classify and authorize a URL or local-file scan target."""
    if not isinstance(target, str) or not target:
        raise ScriptError("Scan target must not be empty", EXIT_USAGE)
    if target.startswith("-"):
        raise ScriptError("Scan target must not begin with '-'", EXIT_USAGE)
    if target.startswith(("\\\\", "//")):
        raise ScriptError(
            "Network-share and protocol-relative scan targets are not supported",
            EXIT_USAGE,
        )

    local_path = Path(target).expanduser()
    if local_path.exists() or (
        len(target) >= 3 and target[0].isalpha() and target[1:3] in {":\\", ":/"}
    ):
        return _canonical_local_file(local_path)

    if any(ord(character) <= 32 or ord(character) == 127 for character in target):
        raise ScriptError(
            "Remote scan target must not include whitespace or control characters",
            EXIT_USAGE,
        )

    parsed = urlparse(target)
    scheme = parsed.scheme.lower()
    if scheme == "file":
        if parsed.netloc and parsed.netloc.lower() != "localhost":
            raise ScriptError("Remote file authorities are not supported", EXIT_USAGE)
        return _canonical_local_file(Path(url2pathname(parsed.path)))

    if scheme in {"http", "https"}:
        if not parsed.hostname:
            raise ScriptError(
                "Remote scan target must be an absolute HTTP(S) URL with a host",
                EXIT_USAGE,
            )
        if parsed.username is not None or parsed.password is not None:
            raise ScriptError(
                "Remote scan target must not include credentials", EXIT_USAGE
            )
        try:
            parsed.port
        except ValueError as exc:
            raise ScriptError(
                "Remote scan target includes an invalid port", EXIT_USAGE
            ) from exc
        try:
            assert_host_allowed(
                parsed.hostname,
                allowlist=allow_hosts,
                allow_external=allow_external,
            )
        except RuntimeScriptError as exc:
            raise ScriptError(
                f"Refusing to scan non-loopback host '{parsed.hostname}'. "
                "Re-run with --allow-host HOST or --allow-external to confirm "
                "intentional external access.",
                exc.exit_code,
            ) from exc
        return target

    if scheme:
        raise ScriptError(
            f"Unsupported scan target scheme '{scheme}'",
            EXIT_USAGE,
        )
    raise ScriptError("Local scan target does not exist", EXIT_USAGE)


def run_scan(
    target: str,
    allow_hosts: list[str] | None = None,
    allow_external: bool = False,
) -> dict[str, Any]:
    """Run the external axe-core scanner and normalize the output."""
    resolved_target = resolve_scan_target(
        target,
        allow_hosts=allow_hosts,
        allow_external=allow_external,
    )
    command = ["npx", "--yes", "@axe-core/cli@4.12.1", "--", resolved_target]
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node-based axe scanner is unavailable. "
            "Install Node.js and run 'npx --yes @axe-core/cli@4.12.1'.",
            EXIT_USAGE,
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = exc.stderr.strip() or "No scanner output captured"
        raise ScriptError(f"Scanner failed: {stderr}", EXIT_FAILURE) from exc

    try:
        raw_payload = json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise ScriptError("Scanner returned invalid JSON output", EXIT_FAILURE) from exc

    if not isinstance(raw_payload, dict):
        raise ScriptError("Scanner returned unexpected payload format", EXIT_FAILURE)

    return normalize_results(raw_payload, resolved_target)


def write_output(result: dict[str, Any], output_path: Path | None) -> None:
    """Write the normalized result object to stdout or an output file."""
    payload = json.dumps(result, indent=2)
    if output_path is None:
        print(payload)
        return

    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(payload + "\n", encoding="utf-8")


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args(argv)

    try:
        result = run_scan(
            args.target,
            allow_hosts=args.allow_host,
            allow_external=args.allow_external,
        )
    except ScriptError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return exc.exit_code

    write_output(result, args.output)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
