---
description: 'BRD-author view of the BRD-to-PRD handoff payload contract - the brd-author scope statement, business goals, stakeholders, requirements, traceability matrix, open questions, and assumptions that the BRD Builder orchestrator emits at Govern exit for consumption by the PRD Builder - Brought to you by microsoft/hve-core'
---

# BRD-to-PRD Handoff Payload — BRD Author View

This document is the brd-author skill's authoritative description of the payload the BRD Builder orchestrator emits at Govern exit and that the PRD Builder accepts via its `from-brd-handoff` entry mode. The payload itself is governed by the schema in [brd-quality-formats/references/brd-to-prd-handoff-v1.md](../../brd-quality-formats/references/brd-to-prd-handoff-v1.md); this file restates the schema in the BRD author's vocabulary so the canonical template, the orchestrator's exit gate, and the `brd-standard-assessor` subagent all reference a single contract.

The brd-author bundle is the sole writer of the `brd:`, `business_goals:`, `partitions:`, `known_open_items:`, and `prd_consumer_notes:` fields. The `quality_report:`, `counts:`, `traceability:`, and `signoff:` fields are written by the orchestrator and assessor pipeline; this view documents them for completeness so the template author knows what downstream consumers will receive.

## Required versus optional

Required and optional flags below match the upstream schema. The brd-author bundle MUST populate every required field before requesting Govern exit; the orchestrator rejects the handoff if a required field is missing or fails validation.

## Field summary (brd-author authoring view)

The fields below are the ones an author or BRD template placeholder feeds directly. They map 1:1 onto the `BRD_TO_PRD_HANDOFF_V1` schema.

| Author-facing field    | Schema field path                          | Type                          | Required | Source artifact                                         |
|------------------------|--------------------------------------------|-------------------------------|----------|---------------------------------------------------------|
| `brd_id`               | `brd.id`                                   | string                        | yes      | BRD frontmatter overlay `brd_id`                        |
| `brd_version`          | `brd.version`                              | string (`>= 1.0.0`)           | yes      | BRD frontmatter overlay `version`                       |
| `brd_title`            | `brd.title`                                | string                        | yes      | BRD frontmatter overlay `title`                         |
| `brd_artifact_path`    | `brd.artifact_path`                        | string (workspace-relative)   | yes      | Orchestrator (workspace path at signoff)                |
| `brd_artifact_sha256`  | `brd.artifact_sha256`                      | string (64 lowercase hex)     | yes      | Orchestrator (computed at signoff)                      |
| `scope_statement`      | `prd_consumer_notes` (preface paragraph)   | string                        | yes      | BRD §Scope of Work                                      |
| `business_goals[]`     | `business_goals[]`                         | array, length ≥ 1             | yes      | BRD §Business Goals                                     |
| `stakeholders[]`       | `business_goals[].kpi` cross-refs          | array                         | yes      | BRD §Stakeholders                                       |
| `requirements[]`       | `counts.{functional,non_functional,…}`     | array (FR + NFR + CON)        | yes      | BRD §FR + §NFR + §Constraints                           |
| `traceability_matrix`  | `traceability.matrix_ref`                  | string (workspace-relative)   | yes      | BRD §Traceability Matrix or sibling matrix artifact     |
| `open_questions[]`     | `known_open_items[]`                       | array                         | yes (may be empty) | BRD §Open Questions                            |
| `assumptions[]`        | `prd_consumer_notes` (assumptions section) | array                         | yes (may be empty) | BRD §Assumptions                              |

Fields outside this table are written by the orchestrator (`signoff`, `quality_report`, `counts`) or by the assessor (`business_goals[].smart_status`); the BRD template does not bind to them directly.

## YAML shape (subset emitted by brd-author)

The shape below is the brd-author-owned subset of the full payload, in the same field order the upstream schema uses, so the orchestrator can splice the two without reordering.

```yaml
schema_version: BRD_TO_PRD_HANDOFF_V1
brd:
  id: <BRD_ID>                          # required, matches frontmatter brd_id
  version: <BRD_VERSION>                # required, semver >= 1.0.0
  title: <BRD_TITLE>                    # required
  artifact_path: <BRD_ARTIFACT_PATH>    # required, written by orchestrator
  artifact_sha256: <SHA256_HEX>         # required, written by orchestrator
business_goals:
  - id: <BG_ID>                         # required, matches traceability-naming BG-### scheme
    statement: <SMART_GOAL_STATEMENT>   # required, evaluated by SMART rubric
    priority: <MUST|SHOULD|COULD|WONT>  # required, MoSCoW per prioritization-schemes
    kpi: <KPI_STATEMENT>                # required, free text
    smart_status: <PASS|FAIL>           # written by assessor, surfaced here for handoff
partitions:                             # optional unless BRD is partitioned
  - id: <PARTITION_ID>
    title: <PARTITION_TITLE>
    summary: <PARTITION_SUMMARY>
known_open_items:                       # required (may be empty)
  - id: <OPEN_ITEM_ID>                  # unique within payload
    summary: <OPEN_ITEM_SUMMARY>
    rationale_for_deferral: <DEFERRAL_RATIONALE>
    target_phase: <PRD|Implementation|Operations|Future-Release>
prd_consumer_notes: |                   # optional, free text; conventionally hosts
                                        # the BRD scope statement and assumptions
  scope_statement: <SCOPE_STATEMENT>
  assumptions:
    - <ASSUMPTION_STATEMENT>
```

## Field rules the brd-author is responsible for

* `brd.id` MUST be allocated by `scripts/update_lineage.py allocate` (Step 2.8) and recorded in the BRD frontmatter overlay before Govern exit.
* `brd.version` MUST advance to `1.0.0` or higher at signoff; drafts (`0.x.y`) are rejected by upstream validation.
* `business_goals[].id` MUST match the `BG-###` namespace described in [`traceability-naming`](../../traceability-naming/SKILL.md).
* `business_goals[].priority` MUST be drawn from the MoSCoW labels defined in [`prioritization-schemes`](../../prioritization-schemes/SKILL.md).
* `business_goals[].smart_status` is written by the `brd-standard-assessor` subagent per [quality-rubric.md](quality-rubric.md); the brd-author MUST NOT emit a goal whose statement does not meet the SMART rubric before requesting signoff.
* `known_open_items[].target_phase` MUST be one of the four upstream-allowed values; deferring to anything else is rejected.
* `partitions[]` MUST be present when the BRD declares partitions in its frontmatter overlay; otherwise it MUST be omitted.
* `prd_consumer_notes` MUST be valid YAML if the BRD chooses to express scope statement and assumptions as a nested mapping; otherwise it MAY be a plain string.

## Fields the orchestrator and assessor write (informational)

These fields are not authored from the BRD template, but the template's quality fields determine the values written by the pipeline. They are listed here so the BRD author can predict what consumers will see.

* `signoff.{status,approvers,waivers}` — written by the orchestrator from the Govern approval workflow.
* `quality_report.{report_ref,overall_status,govern_exit_decision}` — written by the orchestrator from the final `brd-standard-assessor` run.
* `counts.{functional_requirements,non_functional_requirements,business_rules,constraints,acceptance_criteria,business_goals}` — written by the orchestrator from a structural pass over the BRD artifact.
* `traceability.{matrix_ref,fr_to_ac_coverage_pct,fr_to_bg_coverage_pct}` — written by the orchestrator from the traceability matrix snapshot at signoff.

## Validation surface

The brd-author bundle's contribution to the payload is validated by:

1. `scripts/validate_frontmatter.py` (Step 2.7) — confirms `brd_id`, `version`, `title`, `business_goal_ids`, and `business_goal_smart_status` are present and well-formed on the BRD source.
2. The orchestrator's pre-handoff structural check — confirms `business_goals[].id` cardinality matches the BRD's §Business Goals section.
3. The upstream `BRD_TO_PRD_HANDOFF_V1` schema validator owned by [brd-quality-formats](../../brd-quality-formats/SKILL.md) — final authority on the assembled payload.

## License

This file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The upstream `BRD_TO_PRD_HANDOFF_V1` schema definition lives in the `brd-quality-formats` skill bundle; this file is a brd-author view of that schema and never replaces it.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
