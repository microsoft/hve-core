---
description: 'Task Implementor telemetry overlay: applies telemetry-foundations vocabulary to implementation change artifacts. Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/changes/**'
---

# Task Implementor Telemetry Overlay

## When to Apply

Activates whenever the parent agent produces or revises implementation change artifacts that touch observable behavior, audit trails, or production telemetry decisions.

## Required Vocabulary Source

Always consult the `telemetry-foundations` skill for trace, metric, log, PII, and resource-attribute vocabulary. Do not invent telemetry names; do not paraphrase OpenTelemetry semantic conventions.

## Decision Tree

1. Is the new behavior observable in production? If no, stop — no telemetry required.
2. Does it cross a service boundary or process? If yes, require trace span(s) per the skill's Trace Vocabulary section.
3. Does it produce a measurable rate, count, or duration? If yes, choose an instrument from the skill's Metric Vocabulary section and apply UCUM units.
4. Does it carry PII? If yes, consult the skill's `pii-denylist` reference and apply the redaction strategy listed there.
5. Is the cardinality bound? If no, demote to a log event; do not emit as a metric attribute.
6. Verify each new emitter's attributes against the skill before marking the implementation step complete.

## Fallback

When the skill does not yet cover a needed concept, propose an addition through the skill's `proposed-additions` reference in the same change. Do not silently invent vocabulary.

Brought to you by microsoft/hve-core
