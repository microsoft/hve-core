---
description: Shared telemetry overlay applying telemetry-foundations vocabulary across planner, ADR, PRD, accessibility, code-review, and implementation artifacts
applyTo: '**/.copilot-tracking/sssc-plans/**, **/.copilot-tracking/rai-plans/**, **/.copilot-tracking/security-plans/**, **/.copilot-tracking/adr-plans/**, **/docs/planning/adrs/**, **/.copilot-tracking/prd-sessions/**, **/.copilot-tracking/accessibility/**, **/.copilot-tracking/reviews/code-reviews/**, **/.copilot-tracking/changes/**'
---

# Shared Telemetry Overlay

## When to Apply

Activates whenever the parent agent produces or revises artifacts that touch observable behavior, audit trails, or production telemetry decisions.

## Required Vocabulary Source

Always consult the `telemetry-foundations` skill for trace, metric, log, PII, and resource-attribute vocabulary. Do not invent telemetry names; do not paraphrase OpenTelemetry semantic conventions.

## Decision Tree

1. Is the new behavior observable in production? If no, stop. No telemetry required.
2. Does it cross a service boundary or process? If yes, require trace span(s) per the skill's Trace Vocabulary section.
3. Does it produce a measurable rate, count, or duration? If yes, choose an instrument from the skill's Metric Vocabulary section and apply UCUM units.
4. Does it carry PII? If yes, consult the skill's `pii-denylist` reference and apply the redaction strategy listed there.
5. Is the cardinality bound? If no, demote to a log event; do not emit as a metric attribute.
6. Apply the artifact-specific mandatory telemetry from the table below that matches the artifact context.

## Artifact-Specific Mandatory Telemetry

| Artifact context                                    | Additional mandatory telemetry                                                                                                     |
|-----------------------------------------------------|------------------------------------------------------------------------------------------------------------------------------------|
| SSSC plans (`sssc-plans/`)                          | Require build/release telemetry attributes (`vcs.*`, `ci.*`) on supply-chain controls per the skill's Resource Attributes section. |
| RAI plans (`rai-plans/`)                            | Capture model-output telemetry (latency, refusal rate, content-filter triggers) as metrics in the impact-assessment record.        |
| Security plans (`security-plans/`)                  | Treat security-event emission as mandatory; cross-reference STRIDE entries with the skill's Log Vocabulary severity levels.        |
| ADR artifacts (`adr-plans/`, `docs/planning/adrs/`) | Record the chosen telemetry strategy under "Consequences"; cite the skill section that justifies each instrument choice.           |
| PRD sessions (`prd-sessions/`)                      | Capture telemetry acceptance criteria in the PRD's "Success Metrics" and "Operational Readiness" sections.                         |
| Accessibility plans (`accessibility/`)              | No additional mandate beyond steps 1-5; apply the decision tree to any observable accessibility behavior.                          |
| Code-review reports (`reviews/code-reviews/`)       | Flag any production code path that emits telemetry without a corresponding semantic-convention reference.                          |
| Implementation changes (`changes/`)                 | Verify each new emitter's attributes against the skill before marking the implementation step complete.                            |

## Fallback

When the skill does not yet cover a needed concept, propose an addition through the skill's `proposed-additions` reference in the same change. Do not silently invent vocabulary.
