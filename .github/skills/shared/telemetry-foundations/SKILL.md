---
name: telemetry-foundations
description: 'Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling'
---

# Telemetry Foundations

## Overview

A shared vocabulary for observability across HVE Core agents. This skill describes *what* telemetry data exists and *how it is named*, not which SDK or vendor to use. Agents producing planning artifacts (ADRs, PRDs, security/RAI plans, code-review reports) and agents producing user-facing application code reference this skill so that downstream pipelines (traces, metrics, logs) speak a consistent OpenTelemetry-aligned language.

## When to Apply

Apply this skill in the following situations:

* Any agent producing user-facing application code that emits spans, metrics, or structured logs.
* Architecture Decision Records that touch observability, monitoring, or audit logging.
* Code-review reports that flag telemetry gaps, inconsistent span naming, or unbounded metric cardinality.
* Security or Responsible AI plans that cite audit logs, traceability, or evidence chains.
* Product or business requirement documents that specify success metrics expressed as service telemetry.

## Core Principles

The vocabulary in this skill follows five principles:

* Declarative, not prescriptive. Define the names and shapes; leave the choice of SDK, exporter, and backend to the implementing team.
* OpenTelemetry-aligned. Trace, metric, and log models follow the OTel data model so artifacts remain portable.
* Semantic conventions first. Where an OTel semantic convention exists for a domain (HTTP, RPC, database, messaging, GenAI, FaaS), prefer it over a bespoke attribute.
* PII by denylist. Treat PII as default-deny via the denylist in [references/pii-denylist.md](references/pii-denylist.md); any field listed there requires an explicit redaction strategy before it can be emitted.
* Vendor-agnostic. Avoid coupling vocabulary to a single backend; OTLP is the assumed wire protocol.

## Trace Vocabulary

Spans describe a unit of work and its causal relationship to other work.

Span kinds:

* `server` - inbound request handled by this service.
* `client` - outbound request issued by this service.
* `producer` - asynchronous message published to a queue or topic.
* `consumer` - asynchronous message received from a queue or topic.
* `internal` - in-process operation with no remote peer.

Required resource-scoped attributes on every span:

* `service.name`
* `service.version`
* `deployment.environment`

Span naming pattern: `<verb>.<resource>` using lowercase dot-separated tokens. The verb describes the operation (`get`, `create`, `publish`, `consume`, `query`); the resource describes the target entity (`order`, `customer`, `payment.intent`). Examples: `get.order`, `publish.order.created`, `query.customer.by_email`.

For domains covered by OTel semantic conventions (HTTP, RPC, database, messaging, GenAI, FaaS), use the convention's span-naming guidance instead of the generic pattern above.

## Metric Vocabulary

Metrics describe aggregate measurements over time.

Instrument types:

* `counter` - monotonic, additive (request count, bytes sent).
* `up-down-counter` - non-monotonic, additive (queue depth, active connections).
* `histogram` - distribution of values (request duration, payload size).
* `gauge` - last-sampled value, non-additive (CPU temperature, memory in use).
* `observable-counter`, `observable-up-down-counter`, `observable-gauge` - async variants polled by the SDK.

Unit conventions follow [UCUM](https://ucum.org/ucum). Examples: `s` (seconds), `ms` (milliseconds), `By` (bytes), `1` (dimensionless count). Express durations as histograms in seconds (`s`) by default to align with OTel HTTP semantic conventions.

Metric naming pattern: `<domain>.<entity>.<measure>` using lowercase dot-separated tokens. Examples: `http.server.request.duration`, `db.client.connections.usage`, `messaging.publish.duration`.

Cardinality discipline: every attribute attached to a metric multiplies the time-series count. Bound high-cardinality dimensions (user ID, request ID, free-form strings) at the source or move them to exemplars and traces.

## Log Vocabulary

Structured logs carry discrete events with severity and context.

Severity levels (OTel log data model):

* `TRACE` - fine-grained diagnostic detail, off by default.
* `DEBUG` - diagnostic detail useful during development.
* `INFO` - normal operational events.
* `WARN` - unexpected condition that does not block the operation.
* `ERROR` - operation failed; the caller likely saw a failure.
* `FATAL` - process is going to terminate.

Recommended structured fields on every log record:

* `timestamp` (ISO-8601, UTC).
* `severity_text` and `severity_number`.
* `body` (the human-readable message; structured data goes in `attributes`).
* `attributes.*` (typed key-value pairs scoped to this event).
* `resource.*` (inherited from the producing service).

Trace correlation: when a log record is emitted within an active span, inject `trace_id` and `span_id` so traces and logs join cleanly downstream. Logging libraries that integrate with the OTel context propagator do this automatically.

## PII Handling

Personally Identifiable Information is handled by denylist. The authoritative list lives in [references/pii-denylist.md](references/pii-denylist.md). Treat any field on that list as default-deny: do not emit it as a span attribute, metric dimension, or log field without an explicit redaction strategy.

Redaction patterns:

* Hash - one-way hash (SHA-256, optionally truncated) for fields that must remain joinable across events but should not be human-readable.
* Drop - omit the field entirely from telemetry.
* Tokenize - replace with an opaque token resolvable only through a separate, access-controlled store.

Identifier convention: where a stable user reference is needed in telemetry, use `user.id` populated with an opaque hash of the canonical user identifier, never the raw email, phone, or external account ID.

When introducing a new attribute that could contain PII, add it to the denylist first and choose a redaction strategy before emitting it.

## Sampling and Cost

Sampling controls the volume of telemetry shipped to downstream collectors.

Sampling strategies:

* Head-based - decision made at span start, propagated through the trace. Low cost, simple, but cannot bias toward late-discovered properties (such as errors).
* Tail-based - decision made after a trace completes, typically in a collector. Higher cost, allows policies such as "keep all error traces" and "keep slow traces".

Defaults:

* Use a parent-based sampler so child spans inherit the parent's sampling decision and traces remain whole.
* When tail-based sampling is available, bias toward keeping error traces and a representative sample of successful traces.

Metric and log sampling: metrics are pre-aggregated and rarely sampled; logs are typically rate-limited per severity rather than sampled.

## Resource Attributes

Resource attributes describe the entity producing the telemetry and are attached to every span, metric, and log record automatically by the SDK.

Required:

* `service.name`
* `service.version`
* `deployment.environment`
* `telemetry.sdk.name`
* `telemetry.sdk.language`
* `telemetry.sdk.version`

Recommended when applicable:

* `cloud.*` (cloud provider, region, account ID).
* `k8s.*` (cluster name, namespace, pod name).
* `host.*` (hostname, architecture, OS type).

Follow the OTel [Resource Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/resource/) for canonical attribute names.

## Decision Tree

Use this quick-select when choosing whether and how to instrument:

1. Is this user-facing or part of a user-visible flow? If no, prefer DEBUG logs and skip span/metric emission unless needed for capacity planning.
2. Is the cardinality of the proposed attributes bounded? If no, move the unbounded field to a log attribute or trace exemplar rather than a metric dimension.
3. Does the data contain or derive from a field in [references/pii-denylist.md](references/pii-denylist.md)? If yes, apply a redaction strategy before emitting.
4. Does the operation cross a service boundary (network, queue, process)? If yes, emit a span with the matching `server`, `client`, `producer`, or `consumer` kind and propagate context.
5. Is the operation high-volume? If yes, rely on parent-based sampling and (where available) tail-based policies; do not disable instrumentation outright.
6. Does an OpenTelemetry semantic convention cover this domain? If yes, use its attribute names and span-naming guidance; if no, follow the naming patterns in this skill and propose a new entry in [references/proposed-additions.md](references/proposed-additions.md).

## References

Authoritative external sources:

* [OpenTelemetry Semantic Conventions v1.41.0](https://opentelemetry.io/docs/specs/semconv/)
* [W3C Trace Context](https://www.w3.org/TR/trace-context/)
* [OpenTelemetry Protocol (OTLP) Specification](https://opentelemetry.io/docs/specs/otlp/)
* [OpenTelemetry Logs Data Model](https://opentelemetry.io/docs/specs/otel/logs/data-model/)
* [OpenTelemetry FaaS Semantic Conventions](https://opentelemetry.io/docs/specs/semconv/faas/)

Portions adapted from OpenTelemetry Semantic Conventions, (C) OpenTelemetry Authors, licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).

Internal:

* [references/pii-denylist.md](references/pii-denylist.md) - authoritative PII denylist with redaction strategies.
* [references/proposed-additions.md](references/proposed-additions.md) - intake for new vocabulary proposals.

*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
