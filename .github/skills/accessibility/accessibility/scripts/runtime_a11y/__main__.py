#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""CLI entry point for the runtime accessibility probe harness.

Subcommands:
    run-all   Run every scoped probe and aggregate the normalized results.
    probe     Run a single probe by id across its scoped surfaces and states.

The harness invokes pinned Playwright probes through ``npx`` so no skill-local
package.json or node_modules are required. Config is passed to the Node runner
through environment variables. Exit code is 0 on a completed run even when
findings exist; a non-zero exit signals a harness error (bad config, missing
Node or browser, or a blocked target).
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterator

from runtime_a11y._config import load_validated_config
from runtime_a11y._errors import EXIT_SUCCESS, EXIT_USAGE, ScriptError

_PACKAGE_DIR = Path(__file__).resolve().parent
_RUNNER_INDEX = _PACKAGE_DIR / "runner" / "index.mjs"
_PROBE_MAP_PATH = _PACKAGE_DIR / "probe-criteria-map.json"

_PLAYWRIGHT_PIN = "playwright@1.61.1"
_AXE_PIN = "@axe-core/playwright@4.12.1"


def _all_probe_ids() -> list[str]:
    payload = json.loads(_PROBE_MAP_PATH.read_text(encoding="utf-8"))
    return [probe["probeId"] for probe in payload.get("probes", [])]


def _normalize_probe_id(name: str, known: set[str]) -> str | None:
    """Resolve a config probe name to a known runner probe id, or None."""
    if name in known:
        return name
    prefixed = name if name.startswith("probe-") else f"probe-{name}"
    if prefixed in known:
        return prefixed
    matches = [pid for pid in known if name in pid]
    return matches[0] if len(matches) == 1 else None


def _iter_runs(
    config: dict[str, Any], probe_filter: str | None = None
) -> Iterator[tuple[str, str, str]]:
    """Yield (probeId, surfaceId, state) combinations to execute."""
    known = set(_all_probe_ids())
    surfaces = {s["id"]: s for s in config.get("surfaces", []) if "id" in s}
    scoping = config.get("probeScoping") or []
    if scoping:
        for entry in scoping:
            probe = _normalize_probe_id(str(entry.get("probe", "")), known)
            if probe is None:
                continue
            if probe_filter and probe != probe_filter:
                continue
            surface_ids = entry.get("surfaces") or list(surfaces)
            states = entry.get("states") or ["default"]
            for sid in surface_ids:
                for state in states:
                    yield probe, sid, state
        return
    probes = [probe_filter] if probe_filter else sorted(known)
    for probe in probes:
        for sid, surface in surfaces.items():
            states = [st.get("state") for st in surface.get("states", [])] or [
                "default"
            ]
            for state in states:
                yield probe, sid, state


def _run_probe(
    config: dict[str, Any],
    probe_id: str,
    surface_id: str,
    state: str,
    base_url: str,
    trace: bool,
) -> dict[str, Any]:
    """Invoke the Node runner for one probe/surface/state and parse its JSON."""
    command = [
        "npx",
        "--yes",
        "--package",
        _PLAYWRIGHT_PIN,
        "--package",
        _AXE_PIN,
        "node",
        str(_RUNNER_INDEX),
        probe_id,
    ]
    env = {
        **os.environ,
        "RUNTIME_A11Y_CONFIG": json.dumps(config),
        "RUNTIME_A11Y_PROBE_ID": probe_id,
        "RUNTIME_A11Y_SURFACE_ID": surface_id,
        "RUNTIME_A11Y_STATE": state,
        "RUNTIME_A11Y_BASE_URL": base_url,
        "RUNTIME_A11Y_TRACE": "1" if trace else "0",
    }
    try:
        completed = subprocess.run(
            command,
            capture_output=True,
            text=True,
            check=True,
            env=env,
        )
    except FileNotFoundError as exc:
        raise ScriptError(
            "Node is unavailable. Install Node.js and system Google Chrome to "
            "run runtime probes.",
            EXIT_USAGE,
        ) from exc
    except subprocess.CalledProcessError as exc:
        stderr = (exc.stderr or "").strip() or "No probe output captured"
        raise ScriptError(
            f"Probe '{probe_id}' failed for surface '{surface_id}' "
            f"state '{state}': {stderr}"
        ) from exc

    try:
        return json.loads(completed.stdout)
    except json.JSONDecodeError as exc:
        raise ScriptError(f"Probe '{probe_id}' returned invalid JSON output") from exc


def run(
    config: dict[str, Any],
    probe_filter: str | None,
    base_url: str,
    trace: bool,
) -> dict[str, Any]:
    """Execute the scoped runs and aggregate normalized probe results."""
    runs: list[dict[str, Any]] = []
    results: list[dict[str, Any]] = []
    for probe_id, surface_id, state in _iter_runs(config, probe_filter):
        payload = _run_probe(config, probe_id, surface_id, state, base_url, trace)
        runs.append(
            {
                "probeId": payload.get("probeId", probe_id),
                "surfaceId": surface_id,
                "state": state,
            }
        )
        for item in payload.get("results", []):
            results.append(item)
    return {
        "tool": "runtime_a11y",
        "runAt": datetime.now(timezone.utc).isoformat(),
        "baseUrl": base_url,
        "runs": runs,
        "results": results,
    }


def _write_output(document: dict[str, Any], out_path: Path | None) -> None:
    payload = json.dumps(document, indent=2)
    if out_path is None:
        print(payload)
        return
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(payload + "\n", encoding="utf-8")


def create_parser() -> argparse.ArgumentParser:
    """Create and configure the argument parser."""
    parser = argparse.ArgumentParser(
        prog="runtime_a11y",
        description="Run project-parameterized accessibility runtime probes.",
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    def _add_common(sub: argparse.ArgumentParser) -> None:
        sub.add_argument(
            "--config",
            type=Path,
            required=True,
            help="Path to a11y-runtime.config.json",
        )
        sub.add_argument(
            "--out",
            type=Path,
            default=None,
            help="Path to write the aggregated results JSON (defaults to stdout)",
        )
        sub.add_argument(
            "--base-url",
            default=None,
            help="Override the config baseUrl",
        )
        sub.add_argument(
            "--trace",
            action="store_true",
            help="Capture Playwright traces and screenshots for each run",
        )
        sub.add_argument(
            "--allow-external",
            action="store_true",
            help="Confirm intentional probing of a non-loopback host",
        )

    run_all = subparsers.add_parser("run-all", help="Run every scoped probe")
    _add_common(run_all)

    probe = subparsers.add_parser("probe", help="Run a single probe by id")
    probe.add_argument("probe_id", help="Probe id, e.g. probe-axe")
    _add_common(probe)

    return parser


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args(argv)

    try:
        config = load_validated_config(args.config, allow_external=args.allow_external)
        base_url = args.base_url or config.get("baseUrl", "")
        probe_filter = getattr(args, "probe_id", None)
        document = run(config, probe_filter, base_url, args.trace)
    except ScriptError as exc:
        print(f"Error: {exc}", file=sys.stderr)
        return exc.exit_code

    _write_output(document, args.out)
    return EXIT_SUCCESS


if __name__ == "__main__":
    sys.exit(main())
