---
description: 'Payload schemas and data contracts for the PRD Builder orchestrator and PRD Quality Reviewer'
---

# PRD Quality Formats — Skill Entry

This document is the entrypoint for the PRD quality format specifications. It is the single source of truth for the YAML payload contracts that the `PRD Quality Reviewer` emits and the PRD Builder orchestrator consumes. The PRD contracts mirror the BRD-side [BRD Quality Formats](../brd/brd-quality-formats.md), diverging only where the PRD lifecycle gates, NFR taxonomy, and identifier set differ.

The skill provides two versioned schemas used during PRD assessment and rollup reporting. Each reference file covers one schema and includes an explicit `schema_version` identifier, field-level types, validation rules, and a complete example payload.

## When to apply

Apply this skill in the following situations:

* Implementing or maintaining the `PRD Quality Reviewer` subagent (`prd-quality-reviewer`) — it must emit both `PRD_STANDARD_FINDINGS_V1` and `PRD_QUALITY_REPORT_V1` in one invocation.
* Validating PRD frontmatter and quality artifacts against the documented schemas.
* Reviewing pull requests that touch PRD quality reviewer outputs or any tool that produces or consumes these payloads.

## Normative references

1. [PRD Standard Findings V1](prd-standard-findings-v1.md) — `PRD_STANDARD_FINDINGS_V1` payload emitted by the `PRD Quality Reviewer` subagent for detailed findings.
2. [PRD Quality Report V1](prd-quality-report-v1.md) — `PRD_QUALITY_REPORT_V1` payload emitted by the `PRD Quality Reviewer` subagent in the same invocation as the findings payload.

## Schema producers and consumers

| Schema                     | Produced by                                              | Consumed by                                                                                                | Trigger                                                                                 |
|----------------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------------------|-----------------------------------------------------------------------------------------|
| `PRD_STANDARD_FINDINGS_V1` | `PRD Quality Reviewer` subagent (`prd-quality-reviewer`) | `PRD Quality Reviewer` report composition in the same invocation; PRD Builder orchestrator; human reviewer | Once per reviewer invocation at Validate exit, Finalize drift check, or on user request |
| `PRD_QUALITY_REPORT_V1`    | `PRD Quality Reviewer` subagent (`prd-quality-reviewer`) | PRD Builder orchestrator for Validate-exit and Finalize-exit gates; human reviewer                         | Once per reviewer invocation, emitted with the paired findings payload                  |

## Schema layout

* `prd-quality-formats.md` — this file (PRD quality format entrypoint).
* `prd-standard-findings-v1.md` — reviewer findings output schema.
* `prd-quality-report-v1.md` — PRD quality report and gate-decision schema.

## Schema versioning

Every payload defined here carries an explicit `schema_version` string field set to the schema identifier (for example `PRD_STANDARD_FINDINGS_V1`). Consumers MUST validate `schema_version` before processing a payload and MUST fail fast on an unrecognized value.

When a schema changes in a backward-incompatible way, the new version is published as a new reference file (for example `prd-standard-findings-v2.md`) with a bumped identifier (`PRD_STANDARD_FINDINGS_V2`). Old payloads continue to validate against the old reference. The orchestrator and `PRD Quality Reviewer` are updated together so they emit and consume the same version.

## Gate ownership

The findings and report payloads split responsibilities so that gate decisions live in exactly one place:

* `PRD_STANDARD_FINDINGS_V1` captures structured observations only. It MUST NOT carry gate decisions.
* `PRD_QUALITY_REPORT_V1` is the only quality gate decision record. It owns `gate_decisions.validate_exit` and `gate_decisions.finalize_exit`, plus the threshold-to-decision rules that convert reviewer findings into gate outcomes.

## License

This skill and all files under `references/prd/` are original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The schemas themselves are HVE-Core IP and may be reused under the same license. No third-party standards or templates are redistributed by this skill.


