---
description: 'Payload schemas and data contracts for the BRD Builder orchestrator, BRD Quality Reviewer, and BRD-to-PRD handoff'
---

# BRD Quality Formats — Skill Entry

This `SKILL.md` is the entrypoint for the BRD quality format specifications skill. It is the single source of truth for the JSON/YAML payload contracts that the `BRD Quality Reviewer` emits and the orchestrator consumes.

The skill provides three versioned schemas used during BRD assessment, rollup reporting, and downstream handoff. Each reference file covers one schema and includes an explicit `schema_version` identifier, field-level types, validation rules, and a complete example payload.

## When to apply

Apply this skill in the following situations:

* Implementing or maintaining the `BRD Quality Reviewer` subagent (Phase 4) — it must emit both `BRD_STANDARD_FINDINGS_V1` and `BRD_QUALITY_REPORT_V1` in one invocation.
* Implementing or maintaining the BRD-to-PRD handoff produced at the Govern exit gate — the handoff payload follows `BRD_TO_PRD_HANDOFF_V1`.
* Validating BRD frontmatter and quality artifacts against the documented schemas.
* Reviewing pull requests that touch BRD quality reviewer outputs, the BRD-to-PRD handoff payload, or any tool that produces or consumes these payloads.

## Normative references

1. [BRD Standard Findings V1](brd-standard-findings-v1.md) — `BRD_STANDARD_FINDINGS_V1` payload emitted by the `BRD Quality Reviewer` subagent for detailed findings.
2. [BRD Quality Report V1](brd-quality-report-v1.md) — `BRD_QUALITY_REPORT_V1` payload emitted by the `BRD Quality Reviewer` subagent in the same invocation as the findings payload.
3. [BRD-to-PRD Handoff V1](brd-to-prd-handoff-v1.md) — `BRD_TO_PRD_HANDOFF_V1` payload produced at the Govern exit gate and consumed by the PRD Builder.

## Schema producers and consumers

| Schema                     | Produced by                                              | Consumed by                                                                                                | Trigger                                                                             |
|----------------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------|
| `BRD_STANDARD_FINDINGS_V1` | `BRD Quality Reviewer` subagent (`brd-quality-reviewer`) | `BRD Quality Reviewer` report composition in the same invocation; BRD Builder orchestrator; human reviewer | Once per reviewer invocation at Define exit, Govern drift check, or on user request |
| `BRD_QUALITY_REPORT_V1`    | `BRD Quality Reviewer` subagent (`brd-quality-reviewer`) | BRD Builder orchestrator for Define-exit and Govern-exit gates; human reviewer                             | Once per reviewer invocation, emitted with the paired findings payload              |
| `BRD_TO_PRD_HANDOFF_V1`    | BRD Builder orchestrator at Govern exit                  | PRD Builder orchestrator (downstream agent); release manager; auditing tools                               | Once per Govern-exit signoff                                                        |

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — schema specification documents.
  * `brd-standard-findings-v1.md` — reviewer findings output schema.
  * `brd-quality-report-v1.md` — BRD quality report and gate-decision schema.
  * `brd-to-prd-handoff-v1.md` — BRD-to-PRD handoff payload schema.

## Schema versioning

Every payload defined in this skill carries an explicit `schema_version` string field set to the schema identifier (for example `BRD_STANDARD_FINDINGS_V1`). Consumers MUST validate `schema_version` before processing a payload and MUST fail fast on an unrecognized value.

When a schema changes in a backward-incompatible way, the new version is published as a new reference file (for example `brd-standard-findings-v2.md`) with a bumped identifier (`BRD_STANDARD_FINDINGS_V2`). Old payloads continue to validate against the old reference. The orchestrator and `BRD Quality Reviewer` are updated together so they emit and consume the same version.

## License

This skill and all files under `references/` are original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The schemas themselves are HVE-Core IP and may be reused under the same license. No third-party standards or templates are redistributed by this skill.


