#!/usr/bin/env python3
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
"""Import a dashboard and confirm every panel query returns data.

A panel can resolve its datasource, raise no error, and still be empty because
the metric name is wrong. This runs each panel's query against the store so an
empty panel is distinguishable from a mistyped one.

    validate_dashboard.py [dashboard.json]

The dashboard argument is resolved against the current directory, so a
generated dashboard anywhere on this machine can be checked. Confining it to
the installed skill directory made the documented workflow impossible: a
dashboard worth validating is usually one that was just produced, not one that
ships here.

Handles Prometheus and Tempo panels only. There is no Azure Monitor path, so
this cannot validate the Azure dashboard.

The import uses overwrite semantics, so it replaces any dashboard sharing the
uid. It therefore refuses a non-loopback Grafana unless the target is confirmed
disposable via COPILOT_OTEL_ALLOW_REMOTE=1.

Environment overrides: COPILOT_OTEL_GRAFANA, COPILOT_OTEL_PROMETHEUS,
COPILOT_OTEL_TEMPO.

Required: COPILOT_OTEL_GRAFANA_USER, COPILOT_OTEL_GRAFANA_PASSWORD. These are
the same variables compose.yaml requires; there is no default credential.

The Grafana credential is passed to the one request that needs it rather than
held in a module global. Five of this tool's six requests go to Prometheus or
Tempo, neither of which authenticates against Grafana, and a shared builder
that attaches the header unconditionally sends the credential to all six.
Making it a parameter means a call site can only send it by naming it.
"""

from __future__ import annotations

import base64
import json
import os
import pathlib
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections.abc import Callable

from _input_policy import (
    PolicyError,
    check_url,
    is_loopback_host,
    open_url,
    require_credentials,
)

EXAMPLES_DIR = pathlib.Path(__file__).resolve().parent
DEFAULT_GRAFANA = "http://localhost:3000"
DEFAULT_PROMETHEUS = "http://localhost:9090"
DEFAULT_TEMPO = "http://localhost:3200"

TRACEQL_METRICS_FUNCTIONS = (
    "rate()",
    "_over_time(",
    "quantile_over_time",
    "histogram_over_time",
)


def basic_auth(user: str, password: str) -> str:
    """Render a Basic credential for the Grafana API."""
    return "Basic " + base64.b64encode(f"{user}:{password}".encode()).decode()


def build_request(
    url: str,
    data: bytes | None = None,
    method: str = "GET",
    *,
    authorization: str | None = None,
) -> urllib.request.Request:
    """Build a request, attaching a credential only when one is supplied.

    Building is separate from sending so the header set of every call site is
    inspectable without a network.
    """
    request = urllib.request.Request(url, data=data, method=method)
    if authorization is not None:
        request.add_header("Authorization", authorization)
    if data:
        request.add_header("Content-Type", "application/json")
    return request


def fetch(
    url: str,
    data: bytes | None = None,
    method: str = "GET",
    *,
    authorization: str | None = None,
    allow_remote: bool = False,
) -> dict:
    """Send a built request through the shared policy boundary and decode JSON."""
    request = build_request(url, data, method, authorization=authorization)
    with open_url(request, allow_remote=allow_remote, timeout=25) as response:
        return json.load(response)


def validate_panels(
    dash: dict,
    *,
    prometheus: str,
    tempo: str,
    store: Callable[[str], dict],
) -> tuple[int, int]:
    """Run every panel query through the credential-free transport."""
    now = int(time.time())
    print("=== panel query validation ===\n")
    ok_count = empty_count = 0

    for panel in dash["panels"]:
        if panel.get("type") == "row":
            print(f"-- {panel['title']}")
            continue
        ds = panel["datasource"]["type"]
        title = panel["title"]

        for target in panel.get("targets", []):
            expr = target.get("expr") or target.get("query", "")
            # substitute dashboard variables with match-all for validation
            expr_r = expr.replace("$model", ".*").replace("[$__range]", "[1h]")
            label = target.get("legendFormat", target["refId"])

            if ds == "prometheus":
                try:
                    if target.get("instant"):
                        rows = store(
                            f"{prometheus}/api/v1/query?"
                            + urllib.parse.urlencode({"query": expr_r})
                        )["data"]["result"]
                    else:
                        rows = store(
                            f"{prometheus}/api/v1/query_range?"
                            + urllib.parse.urlencode(
                                {"query": expr_r, "start": now - 7200, "end": now, "step": "60"}
                            )
                        )["data"]["result"]
                    n = len(rows)
                except urllib.error.HTTPError as exc:
                    print(f"   [ERROR] {title:<44} {label:<28} {exc.read().decode()[:80]}")
                    continue
            else:
                # A TraceQL metrics query aggregates span attributes over time
                # and uses a different endpoint than a search query.
                is_metrics = any(fn in expr_r for fn in TRACEQL_METRICS_FUNCTIONS)
                try:
                    if is_metrics:
                        result = store(
                            f"{tempo}/api/metrics/query_range?"
                            + urllib.parse.urlencode(
                                {
                                    "q": expr_r,
                                    "start": (now - 7200) * 10**9,
                                    "end": now * 10**9,
                                    "step": "5m",
                                }
                            )
                        )
                        rows = [s for s in (result.get("series") or []) if s.get("samples")]
                    else:
                        # Tempo search returns nothing without explicit bounds;
                        # Grafana always sends them.
                        rows = (
                            store(
                                f"{tempo}/api/search?"
                                + urllib.parse.urlencode(
                                    {"q": expr_r, "limit": "20", "start": now - 7200, "end": now}
                                )
                            ).get("traces")
                            or []
                        )
                    n = len(rows)
                except urllib.error.HTTPError as exc:
                    print(
                        f"   [ERROR] {title:<44} {label:<28} {exc.code} {exc.read().decode()[:70]}"
                    )
                    continue
                except Exception as exc:  # noqa: BLE001
                    print(f"   [ERROR] {title:<44} {label:<28} {exc}")
                    continue

            if n:
                ok_count += 1
                print(f"   [DATA ] {title:<44} {label:<28} {n} series/traces")
            else:
                empty_count += 1
                # distinguish "metric absent" from "metric present but no
                # samples in window"
                metrics = set(
                    re.findall(r"\b([a-z_][a-z0-9_]*(?:_total|_sum|_count|_bucket))\b", expr_r)
                )
                missing = []
                if ds == "prometheus" and metrics:
                    names = store(f"{prometheus}/api/v1/label/__name__/values")["data"]
                    missing = sorted(m for m in metrics if m not in names)
                reason = f"metric name absent: {missing}" if missing else "no samples in window"
                print(f"   [EMPTY] {title:<44} {label:<28} {reason}")

    return ok_count, empty_count


def load_dashboard(argument: str | None) -> dict:
    """Read a caller-selected dashboard, or the bundled one, with reportable errors.

    Every failure here is a mistyped path or a malformed file, which is a
    message the caller can act on. A traceback would report the same thing as
    an internal defect.
    """
    path = (
        pathlib.Path(argument).expanduser()
        if argument
        else EXAMPLES_DIR / "dashboards" / "copilot-otel.json"
    )
    if not path.is_absolute():
        path = pathlib.Path.cwd() / path

    # Checked before reading because the two platforms disagree about which
    # error a directory read raises, and the caller needs one message.
    if path.is_dir():
        raise PolicyError(f"{path} is a directory, not a dashboard file")

    try:
        text = path.read_text(encoding="utf-8")
    except FileNotFoundError as exc:
        raise PolicyError(f"no dashboard at {path}") from exc
    except (OSError, UnicodeDecodeError) as exc:
        raise PolicyError(f"cannot read {path}: {exc}") from exc

    try:
        dashboard = json.loads(text)
    except json.JSONDecodeError as exc:
        raise PolicyError(f"{path} is not valid JSON: {exc}") from exc

    if not isinstance(dashboard, dict) or not isinstance(dashboard.get("panels"), list):
        raise PolicyError(f"{path} is not a Grafana dashboard: no panels array")
    return dashboard


def main(argv: list[str] | None = None) -> int:
    args = sys.argv[1:] if argv is None else argv
    grafana_url = os.environ.get("COPILOT_OTEL_GRAFANA", DEFAULT_GRAFANA)
    prometheus_url = os.environ.get("COPILOT_OTEL_PROMETHEUS", DEFAULT_PROMETHEUS)
    tempo_url = os.environ.get("COPILOT_OTEL_TEMPO", DEFAULT_TEMPO)
    allow_remote = os.environ.get("COPILOT_OTEL_ALLOW_REMOTE") == "1"

    # All three endpoints go through the same check. Previously only Grafana
    # was guarded, so a redirected Prometheus or Tempo override could send
    # queries anywhere while the import still looked contained.
    try:
        for _name, _url in (
            ("Grafana", grafana_url),
            ("Prometheus", prometheus_url),
            ("Tempo", tempo_url),
        ):
            check_url(_url, allow_remote=allow_remote)
        user, password = require_credentials(
            "COPILOT_OTEL_GRAFANA_USER", "COPILOT_OTEL_GRAFANA_PASSWORD"
        )
        dash = load_dashboard(args[0] if args else None)
        # The import uses overwrite semantics, so a target that is not this
        # machine is worth saying out loud. The same resolved-address rule the
        # policy uses decides it; a hostname prefix comparison would call a
        # name that merely starts with "localhost" local.
        grafana_is_local = is_loopback_host(
            check_url(grafana_url, allow_remote=allow_remote).hostname
        )
    except PolicyError as exc:
        print(str(exc), file=sys.stderr)
        return 1

    if not grafana_is_local:
        print(
            f"warning: importing into {grafana_url} overwrites any dashboard sharing the same uid.",
            file=sys.stderr,
        )

    authorization = basic_auth(user, password)

    def grafana(url: str, data: bytes | None = None, method: str = "GET") -> dict:
        """The only transport that carries the Grafana credential."""
        return fetch(url, data, method, authorization=authorization, allow_remote=allow_remote)

    def store(url: str) -> dict:
        """Prometheus and Tempo. No credential is in scope for this closure."""
        return fetch(url, allow_remote=allow_remote)

    # Silently falling through to Tempo for an unknown datasource would produce
    # empty results indistinguishable from a genuinely empty store, which is the
    # exact failure this tool exists to detect.
    types = {p["datasource"]["type"] for p in dash["panels"] if p.get("type") != "row"}
    if not types <= {"prometheus", "tempo"}:
        unsupported = ", ".join(sorted(types - {"prometheus", "tempo"}))
        print(
            f"unsupported datasource types: {unsupported}.\n"
            "This tool validates Prometheus and Tempo panels only. "
            "The Azure dashboard has no supported path here.",
            file=sys.stderr,
        )
        return 1

    body = {
        "dashboard": dash,
        "overwrite": True,
        "folderId": 0,
        "message": "validated against live telemetry",
    }
    imported = grafana(f"{grafana_url}/api/dashboards/db", json.dumps(body).encode(), "POST")
    print(f"import: {imported.get('status')}  ->  {grafana_url}{imported.get('url')}\n")

    ok_count, empty_count = validate_panels(
        dash, prometheus=prometheus_url, tempo=tempo_url, store=store
    )
    print(f"\nqueries with data: {ok_count}   empty: {empty_count}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
