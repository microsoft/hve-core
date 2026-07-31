#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Enumerate the Copilot metric surface the installed build actually emits.

The emitted metric set drifts between builds and some metrics only appear once
the matching activity has occurred. Run this before trusting any metric name
copied from documentation, including the tables in this skill.

Reports every copilot_chat and gen_ai series with its labels and current value,
the resource identity, and the Copilot services currently present in Tempo.
"""

from __future__ import annotations

import json
import time
import urllib.parse
import urllib.request

PROM = "http://localhost:9090"
TEMPO = "http://localhost:3200"


def api(base: str, path: str, params: dict | None = None) -> dict:
    url = f"{base}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    with urllib.request.urlopen(url, timeout=20) as resp:
        return json.load(resp)


names = api(PROM, "/api/v1/label/__name__/values")["data"]
copilot = sorted(n for n in names if n.startswith(("copilot_chat", "gen_ai")))
now = int(time.time())

print("=== real Copilot metrics: series, labels, values ===\n")
for n in copilot:
    res = api(PROM, "/api/v1/query", {"query": n}).get("data", {}).get("result", [])
    if not res:
        print(f"{n}\n    (no current samples)")
        continue
    print(f"{n}   [{len(res)} series]")
    for r in res[:4]:
        labels = {k: v for k, v in r["metric"].items() if k not in ("__name__", "job", "instance")}
        print(f"    {r['value'][1]:>12}  {labels}")
    if len(res) > 4:
        print(f"    ... {len(res) - 4} more")
    print()

print("=== resource identity (target_info) ===")
for r in api(PROM, "/api/v1/query", {"query": "target_info"}).get("data", {}).get("result", []):
    m = r["metric"]
    if "copilot" in m.get("service_name", ""):
        print(f"    {dict(sorted((k, v) for k, v in m.items() if k != '__name__'))}")

print("\n=== tempo: copilot services ===")
for svc in ("copilot-chat", "github-copilot", "claude-code"):
    try:
        res = api(TEMPO, "/api/search", {"q": f'{{resource.service.name="{svc}"}}', "limit": "5"})
        traces = res.get("traces") or []
        print(f"    {svc:<16} {len(traces)} traces")
        for t in traces[:3]:
            print(f"        {t.get('rootTraceName')}  {t.get('durationMs')}ms  {t.get('traceID')[:16]}")
    except Exception as exc:  # noqa: BLE001
        print(f"    {svc:<16} error: {exc}")
