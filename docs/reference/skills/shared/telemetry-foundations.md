---
title: telemetry-foundations
description: "Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling"
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - shared
  - telemetry-foundations
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                   |
|-------------|-----------------------------------------------------------------------------------------|
| Kind        | skill                                                                                   |
| Source      | `.github/skills/shared/telemetry-foundations`                                           |
| Invocation  | Invoked directly as `/telemetry-foundations`, or loaded on demand by referencing agents |
| Interactive | No                                                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Declarative OpenTelemetry-aligned telemetry vocabulary and instrumentation conventions for traces, metrics, logs, and PII handling
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when code, requirements, ADRs, or review findings need consistent
OpenTelemetry-aligned names and shapes for traces, metrics, and logs. It defines
vocabulary and data-handling conventions without choosing an SDK, exporter, or
monitoring vendor. Use it to clarify an instrumentation contract, not to provision
a telemetry backend or claim data is being collected.

## Example usage

Ask: `/telemetry-foundations Review this sample order API's proposed telemetry:
request-duration metrics, queue publish/consume spans, and structured error logs.
Recommend names and privacy-safe fields without editing code or deploying anything.`
Supply the operation boundaries and proposed attribute list, using synthetic data.

Expect existing domain semantic conventions to take precedence over generic naming,
duration histograms to carry explicit units, and spans/logs to share trace context.
The review should identify unbounded metric dimensions and apply the PII denylist
before recommending emission. Moving a field from metrics to logs does not waive
its privacy treatment.

Success is an implementable naming and field contract with resource identity,
cardinality, redaction, and sampling decisions visible. Actual SDK configuration,
emission checks, and backend verification remain separate implementation work.
