---
name: brd-quality-formats
description: 'Payload schemas and data contracts for the BRD Builder orchestrator, its quality-assessment subagents, and the BRD-to-PRD handoff - Brought to you by microsoft/hve-core'
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-05-08"
---

# BRD Quality Formats — Skill Entry

This `SKILL.md` is the entrypoint for the BRD quality format specifications skill. It is the single source of truth for the JSON/YAML payload contracts that BRD-quality subagents emit and the orchestrator consumes.

The skill provides three versioned schemas used during BRD assessment, rollup reporting, and downstream handoff. Each reference file covers one schema and includes an explicit `schema_version` identifier, field-level types, validation rules, and a complete example payload.

## When to apply

Apply this skill in the following situations:

* Implementing or maintaining the `brd-standard-assessor` subagent (Phase 4) — it must emit a `BRD_STANDARD_FINDINGS_V1` payload per invocation.
* Implementing or maintaining the `brd-quality-report-generator` subagent (Phase 4) — it must emit a `BRD_QUALITY_REPORT_V1` payload that aggregates per-standard findings.
* Implementing or maintaining the BRD-to-PRD handoff produced at the Govern exit gate — the handoff payload follows `BRD_TO_PRD_HANDOFF_V1`.
* Authoring or updating the frontmatter validator script (`validate_frontmatter.py`, Step 2.7) — that script consults these schemas when verifying BRD-quality artifacts.
* Reviewing pull requests that touch BRD-quality subagent outputs, the BRD-to-PRD handoff payload, or any tool that produces or consumes these payloads.

## Normative references

1. [BRD Standard Findings V1](references/brd-standard-findings-v1.md) — `BRD_STANDARD_FINDINGS_V1` payload emitted by the `brd-standard-assessor` subagent for a single standard assessment.
2. [BRD Quality Report V1](references/brd-quality-report-v1.md) — `BRD_QUALITY_REPORT_V1` payload emitted by the `brd-quality-report-generator` subagent that rolls up per-standard findings into the BRD-level quality report.
3. [BRD-to-PRD Handoff V1](references/brd-to-prd-handoff-v1.md) — `BRD_TO_PRD_HANDOFF_V1` payload produced at the Govern exit gate and consumed by the PRD Builder.

## Schema producers and consumers

| Schema | Produced by | Consumed by | Trigger |
|--------|-------------|-------------|---------|
| `BRD_STANDARD_FINDINGS_V1` | `brd-standard-assessor` subagent | `brd-quality-report-generator` subagent; BRD Builder orchestrator (Define-exit gate) | One invocation per applicable standard at Define-exit or on user request |
| `BRD_QUALITY_REPORT_V1` | `brd-quality-report-generator` subagent | BRD Builder orchestrator (Define-exit and Govern-exit gates); human reviewer | Once per Define-exit gate run; regenerated after material BRD revisions |
| `BRD_TO_PRD_HANDOFF_V1` | BRD Builder orchestrator at Govern exit | PRD Builder orchestrator (downstream agent); release manager; auditing tools | Once per Govern-exit signoff |

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — schema specification documents.
  * `brd-standard-findings-v1.md` — single-standard assessor output schema.
  * `brd-quality-report-v1.md` — aggregated BRD quality report schema.
  * `brd-to-prd-handoff-v1.md` — BRD-to-PRD handoff payload schema.

## Schema versioning

Every payload defined in this skill carries an explicit `schema_version` string field set to the schema identifier (for example `BRD_STANDARD_FINDINGS_V1`). Consumers MUST validate `schema_version` before processing a payload and MUST fail fast on an unrecognized value.

When a schema changes in a backward-incompatible way, the new version is published as a new reference file (for example `brd-standard-findings-v2.md`) with a bumped identifier (`BRD_STANDARD_FINDINGS_V2`). Old payloads continue to validate against the old reference. The orchestrator and producing subagents are updated together so they emit and consume the same version.

## License

This skill and all files under `references/` are original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The schemas themselves are HVE-Core IP and may be reused under the same license. No third-party standards or templates are redistributed by this skill.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
