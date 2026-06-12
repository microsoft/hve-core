---
description: ADR Planner telemetry overlay applying telemetry-foundations vocabulary to ADR artifacts
applyTo: '**/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**'
---

# ADR Planner Telemetry Overlay

## When to Apply

Activates whenever the parent agent produces or revises ADR artifacts that touch observable behavior, audit trails, or production telemetry decisions.

## Required Vocabulary Source

Always consult the `telemetry-foundations` skill for trace, metric, log, PII, and resource-attribute vocabulary. Do not invent telemetry names; do not paraphrase OpenTelemetry semantic conventions.

## Decision Tree

1. Is the new behavior observable in production? If no, stop. No telemetry required.
2. Does it cross a service boundary or process? If yes, require trace span(s) per the skill's Trace Vocabulary section.
3. Does it produce a measurable rate, count, or duration? If yes, choose an instrument from the skill's Metric Vocabulary section and apply UCUM units.
4. Does it carry PII? If yes, consult the skill's `pii-denylist` reference and apply the redaction strategy listed there.
5. Is the cardinality bound? If no, demote to a log event; do not emit as a metric attribute.
6. Record the chosen telemetry strategy under "Consequences"; cite the skill section that justifies each instrument choice.

## Fallback

When the skill does not yet cover a needed concept, propose an addition through the skill's `proposed-additions` reference in the same change. Do not silently invent vocabulary.
