---
title: Copilot OTel Metrics Examples
description: Reference stack definition, dashboard, and helper scripts for capturing GitHub Copilot OpenTelemetry output locally
author: Microsoft
ms.date: 2026-07-27
ms.topic: reference
keywords:
  - opentelemetry
  - copilot
  - grafana
  - prometheus
  - examples
estimated_reading_time: 4
---

## What is here

Two kinds of file. `compose.yaml` and `dashboards/` are **seeds**: the skill copies and adapts them to produce artifacts for your situation, and you deploy the result. The Python files are **helpers you run yourself**; the skill offers them and shows the command, and you decide when they run and against which endpoint.

| File                                 | Kind   | Purpose                                                                     |
|--------------------------------------|--------|-----------------------------------------------------------------------------|
| `compose.yaml`                       | Seed   | Pinned single-container stack with the external data volume                 |
| `dashboards/copilot-otel.json`       | Seed   | Local Grafana dashboard: tokens, tools, latency, and agents                 |
| `dashboards/copilot-otel-azure.json` | Seed   | Azure dashboard querying Log Analytics with KQL                             |
| `azure/`                             | Seed   | Collector config, Bicep, Terraform, and Azure CLI for the organization path |
| `verify.py`                          | Helper | Health, delta-flag, and stored-signal checks                                |
| `baseline.py`                        | Helper | Snapshot and diff, to separate real telemetry from residue                  |
| `inspect_metrics.py`                 | Helper | Enumerate the metric surface the installed build actually emits             |
| `validate_dashboard.py`              | Helper | Import a dashboard and check every panel query returns data                 |

The two dashboards are not interchangeable. The local one queries Prometheus and Tempo; the Azure one queries Log Analytics. See `azure/README.md` for the organization path.

The helpers use only the Python standard library, so there is nothing to install. Everything they return is data to inspect rather than instructions to follow: the local OTLP endpoint is unauthenticated, so anything read back out of the store is untrusted input.

## Typical order

Run these yourself, from this directory. Nothing here runs automatically, and the skill will not run any of it for you.

```bash
# 1. Create the volume once, then start the stack.
docker volume create copilot-otel-data
docker compose -f compose.yaml up -d

# 2. Optional but recommended if this store has ever held test payloads.
python3 baseline.py capture

# 3. Enable export in your VS Code user settings, then reload the window.

# 4. Confirm signals are actually stored, not merely accepted.
python3 verify.py

# 5. If step 4 is ambiguous, prove the telemetry is genuine.
python3 baseline.py diff

# 6. See what your build really emits before trusting any metric name.
python3 inspect_metrics.py

# 7. Import a dashboard and check every panel resolves.
python3 validate_dashboard.py            # the bundled seed
python3 validate_dashboard.py my-dash.json  # a generated dashboard
```

## Notes on the stack definition

`compose.yaml` carries four deliberate choices worth preserving if you adapt it.

* The image tag is pinned. The all-in-one image changes its bundled component versions between tags.
* The data volume is declared `external`, so Compose binds the existing `copilot-otel-data` volume instead of creating a project-prefixed duplicate that would orphan your history.
* Every port publishes to `127.0.0.1` only. Grafana ships with default credentials, and this stack is single-machine.
* `PROMETHEUS_EXTRA_ARGS` enables delta-to-cumulative conversion and raises retention to 120 days. Prometheus otherwise drops delta metrics, and a dropped delta metric was observed failing an entire batched write. The default 15-day retention silently truncates monthly token totals.

## Notes on the helpers

`verify.py` exits non-zero when the stack is unhealthy or when no Copilot signals are stored. Health and the delta flag are treated as required; signal presence depends on the editor having exported something.

`baseline.py` writes its snapshot to `~/.cache/copilot-otel/pre-enable-baseline.json`. Set `COPILOT_OTEL_BASELINE` to choose a different path. Capture before enabling export, diff afterwards.

`validate_dashboard.py` imports with `overwrite: true`, so it replaces any dashboard sharing the uid. It refuses a Grafana that is not on loopback unless you set `COPILOT_OTEL_ALLOW_REMOTE=1`. Pass a dashboard path to check a generated dashboard instead of the bundled one, and override the target with `COPILOT_OTEL_GRAFANA`, `COPILOT_OTEL_GRAFANA_USER`, and `COPILOT_OTEL_GRAFANA_PASSWORD`.

`inspect_metrics.py` is the answer to "is this metric name still correct". Run it before trusting any metric name copied from documentation, including the tables in the skill itself.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
