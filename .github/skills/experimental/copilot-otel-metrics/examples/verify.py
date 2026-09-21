#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Verify the local Copilot OTel stack is healthy and actually storing signals.

The OTLP endpoint returns HTTP 200 for payloads it silently discards, so a
successful export call proves nothing. Every check here queries the store.

Exits non-zero if any required check fails.

Every request goes through the shared policy module rather than raw urllib.
The endpoints below are loopback constants today, so nothing is currently
refused that was previously allowed; routing them through the chokepoint means
a later endpoint change inherits the scheme, authority, port, redirect, and
remote-opt-in rules instead of quietly escaping them.
"""

from __future__ import annotations

import base64
import json
import os
import time
import urllib.error
import urllib.parse
import urllib.request

from _input_policy import open_url

GRAFANA = "http://localhost:3000"
PROM = "http://localhost:9090"
TEMPO = "http://localhost:3200"

# The credential grafana/otel-lgtm ships with. Grafana sets the admin password
# only when it creates its database, so a stack started against a pre-existing
# database keeps this pair even though COPILOT_OTEL_GRAFANA_PASSWORD was set.
GRAFANA_DEFAULT_USER = "admin"
GRAFANA_DEFAULT_PASSWORD = "admin"

COPILOT_SERVICES = ("copilot-chat", "github-copilot", "claude-code")

results: list[tuple[str, bool, str]] = []


def record(name: str, ok: bool, detail: str) -> None:
    results.append((name, ok, detail))


def api(base: str, path: str, params: dict | None = None, timeout: int = 15) -> dict:
    url = f"{base}{path}"
    if params:
        url += "?" + urllib.parse.urlencode(params, doseq=True)
    with open_url(url, timeout=timeout) as resp:
        return json.load(resp)


def check_health() -> None:
    for name, url in (
        ("grafana", f"{GRAFANA}/api/health"),
        ("prometheus", f"{PROM}/-/ready"),
        ("tempo", f"{TEMPO}/ready"),
    ):
        try:
            with open_url(url, timeout=10) as resp:
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


def grafana_accepts(user: str, password: str) -> bool | None:
    """Whether Grafana accepts the pair, or None when the probe got no answer.

    A rejected credential and an unreachable Grafana call for different
    operator actions, so they are not collapsed into one boolean.
    """
    token = base64.b64encode(f"{user}:{password}".encode()).decode("ascii")
    request = urllib.request.Request(f"{GRAFANA}/api/org")
    request.add_header("Authorization", f"Basic {token}")
    try:
        with open_url(request, timeout=10) as resp:
            return resp.status == 200
    except urllib.error.HTTPError as exc:
        if exc.code in (401, 403):
            return False
        return None
    except Exception:  # noqa: BLE001 - an unanswered probe is not a rejection
        return None


def check_grafana_credentials() -> None:
    """Report which admin credential is live, not only whether yours works.

    "My password is rejected" is a configuration problem. "The image default
    still authenticates" is a disclosure problem, because Grafana holds the
    dashboards over stored prompt content. The second is the one worth failing
    the run for, and a check that only tried the configured pair would report
    it as a mismatch.
    """
    user = os.environ.get("COPILOT_OTEL_GRAFANA_USER")
    password = os.environ.get("COPILOT_OTEL_GRAFANA_PASSWORD")
    if user and password:
        accepted = grafana_accepts(user, password)
        detail = {
            True: "Grafana accepted the configured pair",
            False: "Grafana rejected it; its database predates this password",
            None: "no answer from Grafana",
        }[accepted]
        record("configured grafana credential works", accepted is True, detail)
    else:
        record(
            "configured grafana credential works",
            False,
            "COPILOT_OTEL_GRAFANA_USER and COPILOT_OTEL_GRAFANA_PASSWORD are not both set",
        )

    if (user, password) == (GRAFANA_DEFAULT_USER, GRAFANA_DEFAULT_PASSWORD):
        record(
            "grafana default credential inactive",
            False,
            "the configured credential is the image default admin/admin",
        )
        return

    live = grafana_accepts(GRAFANA_DEFAULT_USER, GRAFANA_DEFAULT_PASSWORD)
    detail = {
        True: "admin/admin authenticates; reset it, see examples/README.md",
        False: "admin/admin is rejected",
        None: "no answer from Grafana",
    }[live]
    record("grafana default credential inactive", live is False, detail)


def check_copilot_metrics() -> None:
    try:
        names = api(PROM, "/api/v1/label/__name__/values")["data"]
        copilot = [n for n in names if n.startswith(("copilot_chat", "gen_ai"))]
        record(
            "copilot metric names present",
            bool(copilot),
            f"{len(copilot)} names: {copilot[:6]}",
        )

        now = int(time.time())
        stored = []
        for n in copilot:
            res = (
                api(
                    PROM,
                    "/api/v1/query_range",
                    {"query": n, "start": now - 3600, "end": now, "step": "60"},
                )
                .get("data", {})
                .get("result", [])
            )
            if res:
                stored.append(n)
        record(
            "copilot metrics have samples",
            bool(stored),
            f"{len(stored)} of {len(copilot)} with data in last hour",
        )
    except Exception as exc:  # noqa: BLE001
        record("copilot metric names present", False, str(exc))


def check_copilot_traces() -> None:
    found = {}
    for svc in COPILOT_SERVICES:
        try:
            res = api(
                TEMPO,
                "/api/search",
                {"q": f'{{resource.service.name="{svc}"}}', "limit": "5"},
            )
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
    check_grafana_credentials()
    check_copilot_metrics()
    check_copilot_traces()

    width = max(len(n) for n, _, _ in results)
    print("=== local Copilot OTel stack verification ===\n")
    for name, ok, detail in results:
        print(f"  [{'PASS' if ok else 'FAIL'}] {name:<{width}}  {detail}")

    # Health, the delta flag, and a dead default credential are infrastructure
    # and must pass. A rejected configured credential is reported but does not
    # fail the run, because running this without exporting the pair is a
    # reasonable thing to do and says nothing about the stack. Signal presence
    # depends on the editor having exported something.
    required = [
        ok
        for name, ok, _ in results
        if "reachable" in name or "delta" in name or "default credential" in name
    ]
    signals = [ok for name, ok, _ in results if "copilot" in name]

    print()
    if not all(required):
        # A stopped stack also fails the credential probe, so health is reported
        # first rather than sending the operator to the rotation procedure.
        if all(ok for name, ok, _ in results if "reachable" in name or "delta" in name):
            print("RESULT: the Grafana admin credential you configured is not the live one.")
            print("        See 'If you already ran an older version of this stack' in")
            print("        examples/README.md.")
        else:
            print("RESULT: stack is not healthy. Start it with: docker compose up -d")
        return 1
    if not any(signals):
        print("RESULT: stack healthy, but no Copilot signals stored yet.")
        print(
            "        Confirm export is enabled in user settings.json, "
            "then reload the VS Code window."
        )
        return 1
    print("RESULT: stack healthy and storing Copilot signals.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
