#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Capture and compare pre-enablement baselines of the local telemetry store.

Synthetic test payloads can carry the real Copilot service name and real Copilot
metric names into the same persistent volume this stack uses. A presence check
therefore cannot distinguish editor output from that residue. This tool snapshots
the store before export is enabled, then reports what is genuinely new afterwards.

    baseline.py capture          write a snapshot
    baseline.py diff             compare the store against the snapshot

The snapshot defaults to a user cache path. Set COPILOT_OTEL_BASELINE to override.
"""

from __future__ import annotations

import argparse
import json
import os
import pathlib
import sys
import time
import urllib.parse
import urllib.request

PROM = "http://localhost:9090"
TEMPO = "http://localhost:3200"
SNAPSHOT = pathlib.Path(
    os.environ.get("COPILOT_OTEL_BASELINE")
    or pathlib.Path.home() / ".cache" / "copilot-otel" / "pre-enable-baseline.json"
)

# Copilot metrics that a synthetic sender is unlikely to fabricate, because they
# require real editor activity to exist at all. Any of these appearing after the
# baseline is a positive discriminator for genuine extension output.
REAL_ACTIVITY_ONLY = [
    "copilot_chat_tool_call_duration",
    "copilot_chat_agent_invocation_duration",
    "copilot_chat_agent_turn_count",
    "copilot_chat_time_to_first_token",
    "copilot_chat_edit_acceptance_count",
    "copilot_chat_chat_edit_outcome_count",
    "copilot_chat_edit_survival_four_gram",
    "copilot_chat_edit_survival_no_revert",
    "copilot_chat_user_action_count",
    "copilot_chat_user_feedback_count",
    "copilot_chat_agent_edit_response_count",
    "copilot_chat_agent_summarization_count",
]

# A synthetic sender typically hard-codes a service.version; the real extension
# reports its own. Set this to the version your test payloads used, if any.
SYNTHETIC_SERVICE_VERSION = os.environ.get("COPILOT_OTEL_SYNTHETIC_VERSION", "")


def api(base: str, path: str, params: dict | None = None) -> dict:
    url = f"{base}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=20) as resp:
        return json.load(resp)


def label_values(label: str) -> list[str]:
    try:
        return sorted(api(PROM, f"/api/v1/label/{label}/values")["data"])
    except Exception:  # noqa: BLE001 - a missing label is a valid empty baseline
        return []


def tempo_trace_names() -> list[str]:
    try:
        res = api(TEMPO, "/api/search", {"q": '{resource.service.name="copilot-chat"}', "limit": "50"})
        return sorted({t.get("rootTraceName", "") for t in (res.get("traces") or [])})
    except Exception:  # noqa: BLE001
        return []


def snapshot() -> dict:
    return {
        "captured_at": int(time.time()),
        "captured_at_iso": time.strftime("%Y-%m-%dT%H:%M:%S%z"),
        "metric_names": label_values("__name__"),
        "service_names": label_values("service_name"),
        "service_versions": label_values("service_version"),
        "session_ids": label_values("session_id"),
        "tempo_trace_names": tempo_trace_names(),
    }


def do_capture() -> int:
    snap = snapshot()
    SNAPSHOT.parent.mkdir(parents=True, exist_ok=True)
    SNAPSHOT.write_text(json.dumps(snap, indent=2) + "\n")

    copilot_metrics = [n for n in snap["metric_names"] if n.startswith(("copilot_chat", "gen_ai"))]
    print(f"baseline written: {SNAPSHOT}")
    print(f"  captured at        : {snap['captured_at_iso']}")
    print(f"  total metric names : {len(snap['metric_names'])}")
    print(f"  copilot/gen_ai     : {len(copilot_metrics)}  <- already present before enablement")
    for n in copilot_metrics:
        print(f"      {n}")
    print(f"  service_versions   : {snap['service_versions']}")
    print(f"  session_ids        : {len(snap['session_ids'])}")
    print(f"  tempo trace names  : {snap['tempo_trace_names']}")
    print()
    print("Positive discriminators (these require real editor activity):")
    for n in REAL_ACTIVITY_ONLY:
        print(f"      {n}*")
    return 0


def do_diff() -> int:
    if not SNAPSHOT.exists():
        print(f"no baseline at {SNAPSHOT}; run 'baseline.py capture' first", file=sys.stderr)
        return 2

    base = json.loads(SNAPSHOT.read_text())
    now = snapshot()

    new_metrics = sorted(set(now["metric_names"]) - set(base["metric_names"]))
    new_versions = sorted(set(now["service_versions"]) - set(base["service_versions"]))
    new_sessions = sorted(set(now["session_ids"]) - set(base["session_ids"]))
    new_traces = sorted(set(now["tempo_trace_names"]) - set(base["tempo_trace_names"]))

    print(f"baseline from {base['captured_at_iso']}")
    print(f"new metric names   : {len(new_metrics)}")
    for n in new_metrics:
        print(f"    {n}")
    print(f"new service_versions: {new_versions}")
    print(f"new session_ids     : {len(new_sessions)}")
    print(f"new tempo traces    : {new_traces}")

    strong = [n for n in new_metrics if any(n.startswith(d) for d in REAL_ACTIVITY_ONLY)]
    real_version = [v for v in new_versions if v and v != SYNTHETIC_SERVICE_VERSION]

    print()
    print("=== VERDICT ===")
    if strong:
        print("  CONFIRMED: real Copilot telemetry.")
        print(f"  Decisive discriminator(s) requiring real editor activity: {strong}")
        return 0
    if real_version:
        print("  CONFIRMED: real Copilot telemetry.")
        print(f"  New service_version not used by synthetic payloads: {real_version}")
        return 0
    if new_metrics or new_sessions or new_traces:
        print("  INCONCLUSIVE: something new arrived, but nothing uniquely attributable to the extension.")
        print("  Treat as not yet confirmed and re-check after more editor activity.")
        return 1
    print("  NOT CONFIRMED: nothing new since baseline.")
    print("  Most likely cause: the setting needs a VS Code window reload to take effect.")
    return 1


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("action", choices=["capture", "diff"])
    args = parser.parse_args()
    return do_capture() if args.action == "capture" else do_diff()


if __name__ == "__main__":
    raise SystemExit(main())
