#!/usr/bin/env python3
# Copyright (c) Microsoft Corporation.
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
            "passes": (
                len(passes_payload) if isinstance(passes_payload, list) else 0
            ),
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


def run_scan(target: str) -> dict[str, Any]:
    """Run the external axe-core scanner and normalize the output."""
    command = ["npx", "--yes", "@axe-core/cli", target]
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
            "Install Node.js and run 'npx --yes @axe-core/cli'.",
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

    return normalize_results(raw_payload, target)


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
        result = run_scan(args.target)
    except ScriptError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return exc.exit_code

    write_output(result, args.output)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
