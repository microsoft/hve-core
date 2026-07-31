#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Verify the local Copilot OTel stack is healthy and actually storing signals.

The OTLP endpoint returns HTTP 200 for payloads it silently discards, so a
successful export call proves nothing. Every check here queries the store.

Exits non-zero if any required check fails.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request

GRAFANA = "http://localhost:3000"
PROM = "http://localhost:9090"
TEMPO = "http://localhost:3200"

COPILOT_SERVICES = ("copilot-chat", "github-copilot", "claude-code")

results: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, detail: str) -> None:
    results.append((name, ok, detail))


def api(base: str, path: str, params: dict | None = None, timeout: int = 15) -> dict:
    url = f"{base}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=timeout) as resp:
        return json.load(resp)


def check_health() -> None:
    for name, url in (
        ("grafana", f"{GRAFANA}/api/health"),
        ("prometheus", f"{PROM}/-/ready"),
        ("tempo", f"{TEMPO}/ready"),
    ):
        try:
            with urllib.request.urlopen(url, timeout=10) as resp:
                record(f"{name} reachable", resp.status == 200, f"HTTP {resp.status}")
        except Exception as exc:  # noqa: BLE001 - report, do not raise
            record(f"{name} reachable", False, str(exc))


def check_delta_flag() -> None:
    """Confirm delta metrics are converted rather than silently dropped."""
    try:
        flags = api(PROM, "/api/v1/status/flags").get("data", {})
        feature = flags.get("enable-feature", "")
        ok = "otlp-deltatocumulative" in feature
        record("delta-to-cumulative enabled", ok, f"enable-feature={feature!r}")
    except Exception as exc:  # noqa: BLE001
        record("delta-to-cumulative enabled", False, str(exc))


def check_copilot_metrics() -> None:
    try:
        names = api(PROM, "/api/v1/label/__name__/values")["data"]
        copilot = [n for n in names if n.startswith(("copilot_chat", "gen_ai"))]
        record("copilot metric names present", bool(copilot), f"{len(copilot)} names: {copilot[:6]}")

        now = int(time.time())
        stored = []
        for n in copilot:
            res = (
                api(PROM, "/api/v1/query_range", {"query": n, "start": now - 3600, "end": now, "step": "60"})
                .get("data", {})
                .get("result", [])
            )
            if res:
                stored.append(n)
        record("copilot metrics have samples", bool(stored), f"{len(stored)} of {len(copilot)} with data in last hour")
    except Exception as exc:  # noqa: BLE001
        record("copilot metric names present", False, str(exc))


def check_copilot_traces() -> None:
    found = {}
    for svc in COPILOT_SERVICES:
        try:
            res = api(TEMPO, "/api/search", {"q": f'{{resource.service.name="{svc}"}}', "limit": "5"})
            n = len(res.get("traces") or [])
            if n:
                found[svc] = n
        except Exception:  # noqa: BLE001 - absent service is not an error
            pass
    record(
        "copilot traces present",
        bool(found),
        f"{found}" if found else "none (traces need ~30s to become searchable)",
    )


def main() -> int:
    check_health()
    check_delta_flag()
    check_copilot_metrics()
    check_copilot_traces()

    width = max(len(n) for n, _, _ in results)
    print("=== local Copilot OTel stack verification ===\n")
    for name, ok, detail in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name:<{width}}  {detail}")

    # Health and the delta flag are infrastructure and must pass. Signal presence
    # depends on the editor having exported something, which is reported but does
    # not by itself indicate a broken stack.
    required = [ok for name, ok, _ in results if "reachable" in name or "delta" in name]
    signals = [ok for name, ok, _ in results if "copilot" in name]

    print()
    if not all(required):
        print("RESULT: stack is not healthy. Start it with: docker compose up -d")
        return 1
    if not any(signals):
        print("RESULT: stack healthy, but no Copilot signals stored yet.")
        print("        Confirm export is enabled in user settings.json, then reload the VS Code window.")
        return 1
    print("RESULT: stack healthy and storing Copilot signals.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
