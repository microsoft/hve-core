#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

"""CLI entry point for the runtime accessibility probe harness.

Subcommands:
    run-all        Run every scoped probe and aggregate the normalized results.
    probe          Run a single probe by id across its scoped surfaces/states.
    verify-intent  Write a design-intent verification artifact from results.
    project-intent Render a design intent record as Markdown for review.

The harness invokes pinned Playwright probes through ``npx`` so no skill-local
package.json or node_modules are required. Config is passed to the Node runner
through environment variables. Exit code is 0 on a completed run even when
findings exist; a non-zero exit signals a harness error (bad config, missing
Node or browser, or a blocked target). ``verify-intent`` additionally exits
with EXIT_INTENT_DRIFT when a blocking design-intent expectation failed, and
with EXIT_INTENT_UNCOVERED when a blocking expectation was never evaluated.
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

from runtime_a11y import _intent as intent
from runtime_a11y import _projection as projection
from runtime_a11y._config import load_validated_config
from runtime_a11y._errors import (
    EXIT_INTENT_DRIFT,
    EXIT_INTENT_UNCOVERED,
    EXIT_SUCCESS,
    EXIT_USAGE,
    ScriptError,
)

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
        emitting_probe = payload.get("probeId", probe_id)
        runs.append(
            {
                "probeId": emitting_probe,
                "surfaceId": surface_id,
                "state": state,
            }
        )
        for item in payload.get("results", []):
            # Stamp the emitting probe on every row. Probes may push rows
            # inline rather than exclusively through the shared result
            # builder, so this aggregation point is the only place that sees
            # them all. Consumers that join a row back to a declared
            # expectation need it because criterion coverage overlaps across
            # probes.
            results.append({**item, "probeId": emitting_probe})
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

    verify_intent = subparsers.add_parser(
        "verify-intent",
        help="Write a design-intent verification artifact from probe results",
    )
    verify_intent.add_argument(
        "--record",
        type=Path,
        required=True,
        help="Path to design-intent/<surface-id>.intent.yaml",
    )
    verify_intent.add_argument(
        "--results",
        type=Path,
        required=True,
        help="Path to a results document produced by run-all",
    )
    verify_intent.add_argument(
        "--config",
        type=Path,
        default=None,
        help="Optional runtime config used to validate surface and state bindings",
    )
    verify_intent.add_argument(
        "--out",
        type=Path,
        default=None,
        help=(
            "Path to write the verification artifact "
            "(defaults to the record's .verification directory)"
        ),
    )

    project_intent = subparsers.add_parser(
        "project-intent",
        help="Render a design intent record as Markdown for engineering review",
    )
    project_intent.add_argument(
        "--record",
        type=Path,
        required=True,
        help="Path to design-intent/<surface-id>.intent.yaml",
    )
    project_intent.add_argument(
        "--out",
        type=Path,
        default=None,
        help="Path to write the Markdown projection (defaults to stdout)",
    )

    return parser


def _project_intent(args: argparse.Namespace) -> int:
    """Render a record as Markdown, to a file or stdout."""
    markdown, destination = projection.project(args.record, args.out)
    if destination is None:
        print(markdown, end="")
    else:
        print(f"Wrote {destination}")
    return EXIT_SUCCESS


def _warn_override_conflicts(
    record: dict[str, Any], assertions: list[dict[str, Any]]
) -> None:
    """Report each conclusive disagreement between a probe and its override.

    The gate fails closed on a conclusive disagreement. The artifact does not
    reproduce human-authored override fields, so diagnostics read the authored
    record to report the override outcome accurately.
    """
    override_outcomes = {
        (intent_item.get("id"), expectation.get("id")): (
            expectation.get("override") or {}
        ).get("outcome")
        for intent_item in record.get("intents", [])
        for expectation in intent_item.get("expectations", [])
    }
    for item in assertions:
        if not item.get("overrideConflict"):
            continue
        override_outcome = override_outcomes.get(
            (item["intentId"], item["expectationId"])
        )
        print(
            "Warning: design intent override conflict: "
            f"intent '{item['intentId']}' expectation '{item['expectationId']}'; "
            f"observed outcome '{item['outcome']}'; "
            f"override outcome '{override_outcome}'.",
            file=sys.stderr,
        )


def _verify_intent(args: argparse.Namespace) -> int:
    """Generate a verification artifact and report blocking intent drift."""
    raw_text = intent.read_record_text(args.record)
    config = load_validated_config(args.config) if args.config else None
    record = intent.parse_record(raw_text, args.record, config)
    destination, document = intent.generate(
        args.record, args.results, args.out, prepared=(raw_text, record)
    )
    print(f"Wrote {destination}")
    _warn_override_conflicts(record, document["assertions"])
    blocking = intent.evaluate_blocking(record, document["assertions"])
    if blocking == intent.BLOCKING_FAILED:
        print(
            "Error: a blocking design intent expectation failed",
            file=sys.stderr,
        )
        return EXIT_INTENT_DRIFT
    if blocking == intent.BLOCKING_UNCOVERED:
        print(
            "Error: a blocking design intent expectation was never evaluated",
            file=sys.stderr,
        )
        return EXIT_INTENT_UNCOVERED
    return EXIT_SUCCESS


def main(argv: list[str] | None = None) -> int:
    """Main entry point."""
    parser = create_parser()
    args = parser.parse_args(argv)

    try:
        if args.command == "verify-intent":
            return _verify_intent(args)
        if args.command == "project-intent":
            return _project_intent(args)
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
