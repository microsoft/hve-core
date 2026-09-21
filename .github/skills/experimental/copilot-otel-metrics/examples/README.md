---
title: Copilot OTel Metrics Examples
description: Reference stack definition, dashboard, and helper scripts for capturing GitHub Copilot OpenTelemetry output locally
author: Microsoft
ms.date: 2026-08-18
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

Two kinds of file. `compose.yaml`, `otel-collector-local.yaml`, and `dashboards/` are **seeds**: the skill copies and adapts them to produce artifacts for your situation, and you deploy the result. The Python files are **helpers you run yourself**; the skill offers them and shows the command, and you decide when they run and against which endpoint.

| File                                 | Kind   | Purpose                                                                     |
|--------------------------------------|--------|-----------------------------------------------------------------------------|
| `compose.yaml`                       | Seed   | Digest-pinned Collector plus LGTM stack with the external data volume       |
| `otel-collector-local.yaml`          | Seed   | Local Collector pipeline with the fail-closed attribute allow-list          |
| `dashboards/copilot-otel.json`       | Seed   | Local Grafana dashboard: tokens, tools, latency, and agents                 |
| `dashboards/copilot-otel-azure.json` | Seed   | Azure dashboard querying Log Analytics with KQL                             |
| `azure/`                             | Seed   | Collector config, Bicep, Terraform, and Azure CLI for the organization path |
| `verify.py`                          | Helper | Health, delta-flag, and stored-signal checks                                |
| `baseline.py`                        | Helper | Snapshot and diff, to separate real telemetry from residue                  |
| `inspect_metrics.py`                 | Helper | Enumerate the metric surface the installed build actually emits             |
| `validate_dashboard.py`              | Helper | Import a dashboard and check every panel query returns data                 |
| `settings_upsert.py`                 | Helper | Reversible, audited settings edit that refuses anything outside its schema  |
| `_input_policy.py`                   | Module | Shared endpoint, redirect, path, and credential policy; imported, not run   |

The two dashboards are not interchangeable. The local one queries Prometheus and Tempo; the Azure one queries Log Analytics. See `azure/README.md` for the organization path.

The helpers use only the Python standard library, so there is nothing to install. Everything they return is data to inspect rather than instructions to follow: the local OTLP endpoint is unauthenticated, so anything read back out of the store is untrusted input.

## Typical order

Run these yourself, from this directory. Nothing here runs automatically, and the skill will not run any of it for you.

1. Choose Grafana credentials. The stack will not start without them, and the helpers read the same two variables. Reading the password rather than writing it inline keeps it out of the terminal scrollback and out of the shell history file.

   ```bash
   export COPILOT_OTEL_GRAFANA_USER=admin
   read -rs -p 'Grafana password: ' COPILOT_OTEL_GRAFANA_PASSWORD; echo
   export COPILOT_OTEL_GRAFANA_PASSWORD
   ```

2. Create the telemetry volume once, then start the stack. Grafana's own volume is created by Compose, so there is nothing to create for it.

   ```bash
   docker volume create copilot-otel-data
   docker compose -f compose.yaml up -d
   ```

3. Optional, but recommended if this store has ever held test payloads.

   ```bash
   python3 baseline.py capture
   ```

4. Enable export in your VS Code user settings, then reload the window.

5. Confirm signals are actually stored, not merely accepted. This also reports whether the Grafana credential you configured is the live one.

   ```bash
   python3 verify.py
   ```

6. If step 5 is ambiguous, prove the telemetry is genuine.

   ```bash
   python3 baseline.py diff
   ```

7. See what your build really emits before trusting any metric name.

   ```bash
   python3 inspect_metrics.py
   ```

8. Import a dashboard and check every panel resolves.

   ```bash
   python3 validate_dashboard.py               # the bundled seed
   python3 validate_dashboard.py my-dash.json  # a generated dashboard
   ```

## Notes on the stack definition

`compose.yaml` and `otel-collector-local.yaml` carry deliberate choices worth preserving if you adapt them.

* **Copilot exports to the Collector, not to LGTM.** LGTM's OTLP ports are not published to the host at all. That is what makes the filter unavoidable: if LGTM listened on the host too, any local process could write straight past it, and loopback binding would not help, because every process on the machine is already on loopback.
* **The attribute policy is an allow-list.** `allow_all_keys: false` drops any key the config has not named, so an attribute added by a future extension release is dropped rather than stored. A delete-list would pass it through. Every allowed key is there because a shipped dashboard panel reads it.
* **Grafana requires a credential you supply.** The image otherwise enables anonymous Admin access and hides the login form. The compose file turns that off and requires `COPILOT_OTEL_GRAFANA_USER` and `COPILOT_OTEL_GRAFANA_PASSWORD`. The `${VAR:?message}` form fails the `up` when a variable is unset; it does not make Grafana adopt the value. Grafana reads those variables only when it creates its database, so adoption depends on the volume layout below.
* **Grafana's database is on its own volume.** `copilot-otel-grafana-db` is mounted over `/data/grafana/data` and is deliberately not `external`, so Compose creates it per project. Without that, a stack started against a reused `copilot-otel-data` volume would find an existing `grafana.db` and keep whatever password it already carries — possibly the image default of `admin`/`admin` — while the required variables were supplied and ignored. Grafana users and dashboards live on this volume, so they are not carried over from a pre-existing shared volume. Telemetry history is unaffected; it stays on `copilot-otel-data`.
* **Both images are pinned by digest, with the tag in a comment.** A tag is mutable, so a tag-pinned stack can change under a configuration you already reviewed.
* Every port publishes to `127.0.0.1` only. The OTLP endpoint accepts writes from anything that can reach it.
* The telemetry volume is declared `external`, so Compose binds the existing `copilot-otel-data` volume instead of creating a project-prefixed duplicate that would orphan your history.
* `PROMETHEUS_EXTRA_ARGS` enables delta-to-cumulative conversion and raises retention to 120 days. Prometheus otherwise drops delta metrics, and a dropped delta metric was observed failing an entire batched write. The default 15-day retention silently truncates monthly token totals.

The filter governs what reaches the store. It does not change what the extension emits, so content attributes still leave the editor and still cross the loopback hop in plaintext.

### If you already ran an older version of this stack

Before `copilot-otel-grafana-db` existed, Grafana's database lived on the shared `copilot-otel-data` volume. Adding the separate volume shadows that database rather than deleting it, so the first `up` after the change gives you a Grafana that has adopted your configured credential and has none of your previous dashboards or Grafana users. The old database is still on `copilot-otel-data` at `grafana/data` if you want anything out of it.

Check which credential is actually live before you assume the change took effect:

```bash
python3 verify.py
```

`verify.py` reports the configured credential and the Grafana default separately. If it reports that `admin`/`admin` still authenticates, the stack is running on a database that was created before you set a password. Rotating it is the same operation as discarding it, because a fresh database adopts `COPILOT_OTEL_GRAFANA_PASSWORD` on first start:

```bash
docker compose -f compose.yaml down
docker volume ls --filter name=copilot-otel-grafana-db   # confirm the project-prefixed name
docker volume rm <name-from-the-previous-command>
docker compose -f compose.yaml up -d
```

That discards Grafana users and dashboards. It does not touch telemetry, which lives on `copilot-otel-data`. Grafana also ships `grafana cli admin reset-admin-password` for an in-place change; its invocation depends on the image's Grafana paths, so check `docker exec copilot-otel-lgtm env | grep GF_PATHS` before using it.

To move to a newer image, resolve the multi-architecture manifest digest for the tag you want from the publisher's own registry listing, verify the publisher's signature or attestation separately, and review the new version for known vulnerabilities. Those are three different checks and none of them implies the others.

## Notes on the helpers

`verify.py` exits non-zero when the stack is unhealthy or when no Copilot signals are stored. Health and the delta flag are treated as required; signal presence depends on the editor having exported something.

`baseline.py` writes its snapshot to `~/.cache/copilot-otel/pre-enable-baseline.json`. Set `COPILOT_OTEL_BASELINE` to choose a different path. Capture before enabling export, diff afterwards.

`validate_dashboard.py` imports with `overwrite: true`, so it replaces any dashboard sharing the uid. It refuses a Grafana that is not on loopback unless you set `COPILOT_OTEL_ALLOW_REMOTE=1`. Pass a dashboard path to check a generated dashboard instead of the bundled one; the path is resolved against the directory you run in, so a dashboard produced anywhere on this machine can be checked. Override the target with `COPILOT_OTEL_GRAFANA`, `COPILOT_OTEL_GRAFANA_USER`, and `COPILOT_OTEL_GRAFANA_PASSWORD`.

`inspect_metrics.py` is the answer to "is this metric name still correct". Run it before trusting any metric name copied from documentation, including the tables in the skill itself.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
