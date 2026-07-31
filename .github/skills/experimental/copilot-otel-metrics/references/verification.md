---
description: "Shared verification reference: proving Copilot telemetry actually landed, the false positives that look like success or failure, and how to enumerate the metric surface a build emits"
---

# Verification and currency

## Intended Use

Read this in every mode before telling a user their telemetry works. It carries the minimum queries that prove data landed, the responses and delays that get misread as success or failure, and the enumeration step that settles metric names against the store rather than against any table.

## Prove it from the store

The exporter's response is not evidence. Query the backend.

Read-only queries against a local telemetry endpoint are the agent's to run: they change nothing, and they are how verification works. Everything under `examples/` belongs to the user, per the execution boundary in `SKILL.md`. When a helper is the right answer, hand over the command with an absolute path so it runs from wherever the user's shell happens to be.

**Metrics, minimum proving query.** Against Prometheus, ask whether any Copilot series exists at all:

```promql
count({__name__=~"copilot_chat.*|gen_ai.*"})
```

A number greater than zero means metrics arrived and were stored. Zero means they did not, whatever the exporter reported.

**Traces, minimum proving query.** Against Tempo, ask for anything from the Copilot service, with explicit time bounds:

```bash
curl -s --get http://localhost:3200/api/search \
  --data-urlencode 'q={resource.service.name="copilot-chat"}' \
  --data-urlencode "start=$(($(date +%s) - 3600))" \
  --data-urlencode "end=$(date +%s)"
```

Tempo search returns zero results without explicit `start` and `end`, which is easy to mistake for missing data.

For the Azure path the same principle applies against Log Analytics: a `count` over the dependency or trace table for the Copilot service, scoped to the last hour, is what proves ingestion. A collector that reports success has proved only that the collector accepted the payload.

Offer `examples/verify.py` when the user wants this run end to end for the local stack. Offer the command, not the execution.

## Four things that look like failure and are not

**HTTP 200 does not mean stored.** A dropped payload returns `200 {"partialSuccess":{}}`, byte-identical to an accepted one. This is the single most misleading signal in the entire pipeline. Never report success from an export response.

**Traces take roughly 30 seconds to appear.** Tempo flushes before a trace becomes searchable. An empty trace panel immediately after a chat turn is expected. Prometheus has no such delay, so reach for metrics when a fast answer matters.

**Delta-temporality metrics are dropped, and they take others with them.** Prometheus drops delta metrics by default, and a dropped delta metric was observed failing an entire batched write, losing unrelated cumulative metrics that shared the batch. The generated stack sets `--enable-feature=otlp-deltatocumulative` so conversion happens instead. If a user adapted the compose file and lost that flag, this is the first thing to check.

**A metric can be absent because nothing has happened yet.** Agent invocation and edit-survival metrics do not exist until the matching activity occurs. An enumeration run before any agent turn will conclude they are missing when they are merely dormant.

## Metric names are settled by the store

Names drift between builds, and a wrong name fails silently: Prometheus returns an empty result and Grafana renders an empty panel, indistinguishable from a correct panel with no activity. Nothing errors.

Enumerate before trusting any name, including the names in this skill:

```bash
python3 examples/inspect_metrics.py
```

That prints every `copilot_chat` and `gen_ai` series currently in the store with its labels and values. Offer the command to the user; the output is theirs to read.

Translation from OTel names to Prometheus names follows a rule of thumb: dots become underscores, monotonic sums gain `_total`, unit `s` gains `_seconds`, unit `1` on a gauge gains `_ratio`. It is a rule of thumb rather than a guarantee. `gen_ai.client.operation.duration` is emitted with **no unit**, so the histogram is `gen_ai_client_operation_duration_bucket` and *not* `..._seconds_bucket`. Assuming the suffix produces an empty panel and no error.

Where documentation and the store disagree, prefer the store: documentation describes intent, enumeration reports what arrived. Prefer is not the same as trust. The local OTLP endpoint is unauthenticated, so any local process can write series carrying genuine Copilot names. When authenticity matters rather than merely presence, establish provenance with a baseline first.

## Separating real telemetry from residue

Synthetic test payloads can carry the same service name and metric names as the extension, so presence alone cannot prove telemetry came from Copilot. When the store may have held test payloads:

```bash
python3 examples/baseline.py capture   # before enabling export
python3 examples/baseline.py diff      # after enabling export and reloading
```

The diff reports what is genuinely new and names the discriminators only the real extension produces.

## Currency

Every setting name, metric name, and API version in this skill is a snapshot of one build at one moment, and the extension moves faster than the skill.

* **Settings:** the installed extension manifest is the arbiter. Read `contributes.configuration` in the Copilot Chat extension's `package.json`, or filter the Settings UI on `otel`. External documentation has been observed listing OTel knobs as environment-variable-only while the installed manifest exposed them as settings.
* **Metrics and span attributes:** the store is the arbiter, via `inspect_metrics.py`.
* **Azure API versions and resource types:** current provider documentation is the arbiter. Look it up rather than reusing a version from a template.

Re-check after every extension update. When a name cannot be verified in the moment, say so rather than presenting this skill's value as current.

## When nothing arrives

Work down this list before assuming something is broken.

1. Was the window reloaded after the settings change? These settings are read at startup.
2. Was the setting written to the file that actually resolves? Application-scoped settings come from the default profile regardless of the active profile.
3. Is a policy or environment variable overriding the setting? **Developer: Policy Diagnostics** answers the policy half.
4. Is the backend actually up and listening on the endpoint the setting names?
5. Has any Copilot activity occurred since the reload? An idle editor emits nothing.
6. For traces only, has 30 seconds elapsed?

