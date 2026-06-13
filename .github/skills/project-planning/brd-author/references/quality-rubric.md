---
description: 'Operational BRD quality rubric used by the brd-standard-assessor subagent and the Define-phase exit gate - maps the requirements-definition 0-3 attribute scoring to the BRD author status taxonomy (RISK, CAUTION, COVERED, NOT_APPLICABLE) and defines anchor descriptions for every score level - Brought to you by microsoft/hve-core'
---

# BRD Author Quality Rubric

This file is the operational rubric the `brd-standard-assessor` subagent applies at the Define-phase exit gate, on mid-Define on-demand assessments, and during Govern drift checks. It is intentionally narrow: it specifies the scoring scale, the status taxonomy the BRD Builder surfaces to authors, and the gate decision rule. The underlying attribute definitions (ISO 29148 individual-requirement characteristics, ISO/IEC 25010 NFR categories, SMART business-goal pass/fail, ISTQB testability heuristics) are owned by the `requirements-definition` skill bundle and cited from there rather than duplicated here.

For the source-of-truth attribute definitions and the assessor's emitted findings schema, see [requirements-definition/references/quality-rubric.md](../../requirements-definition/references/quality-rubric.md).

## Status taxonomy

Every assessor finding rolls up to exactly one of four statuses. The status is the only verdict authors and orchestrators read; the underlying scores live in the `BRD_STANDARD_FINDINGS_V1` payload for tooling.

| Status           | Author meaning                                                                                       | Gate effect             |
|------------------|------------------------------------------------------------------------------------------------------|-------------------------|
| `COVERED`        | The requirement, business goal, or NFR category meets the rubric's minimum bar.                      | Allow                   |
| `CAUTION`        | The item is acceptable for Define exit but carries a non-blocking concern worth surfacing.           | Allow with comment      |
| `RISK`           | The item fails the rubric's minimum bar; Define exit is blocked until the item is repaired or waived.| Block                   |
| `NOT_APPLICABLE` | The item is intentionally out of scope for this BRD and is excluded from scoring.                    | Allow; record rationale |

The assessor also emits a per-payload `gate_decision` (`approve`, `approve_with_comments`, or `block`) computed from the rules in the next section.

## Per-requirement scoring scale

For each FR, NFR, and CON, the assessor scores the nine ISO/IEC/IEEE 29148:2018 §5.2.5 characteristics on a 0–3 anchor scale and then maps the row to a single status. The scale is the same scale used by [requirements-definition/references/iso-29148-quality-attrs.md](../../requirements-definition/references/iso-29148-quality-attrs.md); the anchor descriptions here govern the BRD Builder's interpretation.

| Score | Anchor name      | Anchor description                                                                                                                          |
|-------|------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `0`   | Absent           | The attribute is not addressed at all by the requirement statement; the statement cannot be evaluated against this attribute.               |
| `1`   | Substandard     | The attribute is addressed only by implication; a reader has to infer it and could easily reach the opposite conclusion.                    |
| `2`   | Acceptable      | The attribute is explicit and a competent reader can act on it; minor phrasing improvements may still be desirable but are not required.    |
| `3`   | Exemplary        | The attribute is explicit, unambiguous to any reader, and the statement is suitable as a downstream PRD/architecture/test input as written. |

Score-to-status mapping per individual attribute:

| Score | Maps to status              |
|-------|-----------------------------|
| `0`   | `RISK` if attribute is `unambiguous`, `verifiable`, `singular`, or `necessary`; else `CAUTION`. |
| `1`   | `CAUTION`                   |
| `2`   | `COVERED`                   |
| `3`   | `COVERED`                   |

A requirement's row-level status is the worst (highest severity) status across its nine attribute statuses. `RISK` > `CAUTION` > `COVERED`.

## Per-BRD NFR category scoring

For each of the eight ISO/IEC 25010 product-quality categories ([requirements-definition/references/iso-25010-nfr-taxonomy.md](../../requirements-definition/references/iso-25010-nfr-taxonomy.md)), the assessor emits a single status:

| Observation                                                                                | Status            |
|--------------------------------------------------------------------------------------------|-------------------|
| At least one NFR in the BRD targets the category.                                          | `COVERED`         |
| No NFR targets the category, and the BRD frontmatter does not declare it out of scope.     | `CAUTION`         |
| The BRD frontmatter explicitly declares the category out of scope with a written rationale.| `NOT_APPLICABLE`  |

ISO 25010 absence is intentionally a `CAUTION`, not a `RISK`, per DD-12: NFR completeness flags Define exit but does not block it.

## Per-business-goal SMART scoring

For each business goal, the assessor evaluates the five SMART attributes per [requirements-definition/references/smart-rubric.md](../../requirements-definition/references/smart-rubric.md) as `pass` or `fail`, then maps the row:

| Observation                                       | Status   |
|---------------------------------------------------|----------|
| All five attributes `pass`.                       | `COVERED`|
| Exactly one attribute `fail`.                     | `CAUTION`|
| Two or more attributes `fail`.                    | `RISK`   |

The per-BRD goal-level decision (`business_goal_smart_status` in the frontmatter overlay per DD-08) is the worst status across all goals.

## Define-to-Govern gate decision rule

The Define → Govern transition is decided by combining the three scored dimensions per the rule below. Any blocking condition forces `gate_decision = block`; any flagging condition forces `gate_decision = approve_with_comments` if no blocking condition is present.

| Condition                                                                                                                   | Effect        |
|-----------------------------------------------------------------------------------------------------------------------------|---------------|
| Any requirement row carries status `RISK`.                                                                                  | Block         |
| Any business goal row carries status `RISK`.                                                                                | Block         |
| Coverage of FR → AC links drops below the threshold declared in the BRD frontmatter (`fr_to_ac_coverage_threshold_pct`).    | Block         |
| Any requirement row carries status `CAUTION`.                                                                               | Approve with comment |
| Any business goal row carries status `CAUTION`.                                                                             | Approve with comment |
| One or more ISO 25010 NFR categories carry status `CAUTION`.                                                                | Approve with comment |
| ISTQB testability heuristics flagged one or more requirements during diagnostic review.                                     | Approve with comment |
| All rows are `COVERED` or `NOT_APPLICABLE` and coverage thresholds are met.                                                 | Approve       |

The orchestrator records the decision in the `BRD_TO_PRD_HANDOFF_V1` payload's `quality_report.govern_exit_decision` field per the [handoff-payload-schema.md](handoff-payload-schema.md) (Step 2.6 reference).

## Govern drift detection

During Govern, the same rubric is re-applied on a cadence defined by the orchestrator. A drift event is recorded when, comparing the most recent passing assessment to the current assessment, any of the following occur:

* A requirement row that was previously `COVERED` becomes `CAUTION` or `RISK`.
* A business goal row that was previously `COVERED` becomes `CAUTION` or `RISK`.
* An NFR category that was previously `COVERED` becomes `CAUTION`.

Drift events set `assessment_outcome = drift` on the findings payload and surface a Govern alert; they do not, by themselves, move the BRD back out of Govern.

## Authoring conventions for assessor findings

* Always emit per-row status alongside the underlying numeric scores so authors and tooling can both consume the result.
* Always include a one-line `reason` per `RISK` and `CAUTION` row that names the specific attribute or category causing the verdict; the orchestrator surfaces this verbatim in the gate report.
* Never aggregate the three dimensions into a single composite number; report them as three independent verdicts.
* Refer to attribute and category definitions by linking to `requirements-definition` reference anchors; do not paraphrase the definitions in the findings payload.

## License

This rubric is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The third-party standards underlying the scoring dimensions (ISO/IEC/IEEE 29148:2018, ISO/IEC 25010:2023, SMART criteria, ISTQB Glossary) are cited by name only in [standards-excerpts.md](standards-excerpts.md) and remain the property of their respective rights holders.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
