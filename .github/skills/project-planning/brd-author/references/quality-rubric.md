---
description: 'Operational BRD quality scoring rubric used by BRD Quality Reviewer to map requirement quality evidence to status taxonomy - Brought to you by microsoft/hve-core'
---

# BRD Author Quality Rubric

This file is the operational scoring rubric the `BRD Quality Reviewer` subagent applies at Define exit, during mid-Define on-demand assessments, and during Govern drift checks. It is intentionally narrow: it specifies the scoring scale and the status taxonomy the BRD Builder surfaces to authors. The paired `BRD_QUALITY_REPORT_V1` payload owns gate decisions and threshold-to-decision rules.

The underlying attribute definitions (ISO 29148 individual-requirement characteristics, ISO/IEC 25010 NFR categories, SMART business-goal pass/fail, ISTQB testability heuristics) are owned by the `requirements-definition` skill bundle and cited from there rather than duplicated here.

For the source-of-truth attribute definitions and the reviewer's emitted findings schema, see [requirements-quality-rubric.md](requirements-quality-rubric.md).

## Status taxonomy

Every reviewer finding rolls up to exactly one of four statuses. The status is the only verdict authors and orchestrators read; the underlying scores live in the `BRD_STANDARD_FINDINGS_V1` payload for tooling.

| Status           | Author meaning                                                                            | Report input                                            |
|------------------|-------------------------------------------------------------------------------------------|---------------------------------------------------------|
| `COVERED`        | The requirement, business goal, or NFR category meets the rubric's minimum bar.           | Counts toward passing evidence.                         |
| `CAUTION`        | The item carries a concern worth surfacing but does not itself fail the rubric.            | Counts toward review-needed evidence.                   |
| `RISK`           | The item fails the rubric's minimum bar and needs repair or waiver.                        | Counts toward failing evidence.                         |
| `NOT_APPLICABLE` | The item is intentionally out of scope for this BRD and is excluded from scoring.          | Excluded from threshold calculations; rationale remains. |

Findings emit statuses only. They do not emit `gate_decision`, `gate_decisions`, `define_exit`, or `govern_exit` fields.

## Per-requirement scoring scale

For each FR, NFR, and CON, the reviewer scores the nine ISO/IEC/IEEE 29148:2018 §5.2.5 characteristics on a 0–3 anchor scale and then maps the row to a single status. The scale is the same scale used by [iso-29148-quality-attrs.md](iso-29148-quality-attrs.md); the anchor descriptions here govern the BRD Builder's interpretation.

| Score | Anchor name      | Anchor description                                                                                                                          |
|-------|------------------|---------------------------------------------------------------------------------------------------------------------------------------------|
| `0`   | Absent           | The attribute is not addressed at all by the requirement statement; the statement cannot be evaluated against this attribute.               |
| `1`   | Substandard     | The attribute is addressed only by implication; a reader has to infer it and could easily reach the opposite conclusion.                    |
| `2`   | Acceptable      | The attribute is explicit and a competent reader can act on it; minor phrasing improvements may still be desirable but are not required.    |
| `3`   | Exemplary        | The attribute is explicit, unambiguous to any reader, and the statement is suitable as a downstream PRD/architecture/test input as written. |

Score-to-status mapping per individual attribute:

| Score | Maps to status |
|-------|----------------|
| `0`   | `RISK`         |
| `1`   | `CAUTION`      |
| `2`   | `COVERED`      |
| `3`   | `COVERED`      |

A requirement's row-level status is the worst (highest severity) status across its nine attribute statuses. `RISK` > `CAUTION` > `COVERED`.

Score `1` is caution in the rubric. The quality report separately applies threshold rules: ISO 29148 core attributes below `2` (`necessary`, `unambiguous`, `singular`, and `verifiable`) block through `BRD_QUALITY_REPORT_V1.gate_decisions`.

## Per-BRD NFR category scoring

For each of the eight ISO/IEC 25010 product-quality categories ([iso-25010-nfr-taxonomy.md](iso-25010-nfr-taxonomy.md)), the reviewer emits a single status:

| Observation                                                                                | Status            |
|--------------------------------------------------------------------------------------------|-------------------|
| At least one NFR in the BRD targets the category.                                          | `COVERED`         |
| No NFR targets the category, and the BRD frontmatter does not declare it out of scope.     | `CAUTION`         |
| The BRD frontmatter explicitly declares the category out of scope with a written rationale.| `NOT_APPLICABLE`  |

ISO 25010 absence is intentionally a `CAUTION`, not a `RISK`, per DD-012: NFR completeness flags the report but does not itself fail rubric scoring.

## Per-business-goal SMART scoring

For each business goal, the reviewer evaluates the five SMART attributes per [smart-rubric.md](smart-rubric.md) as `pass` or `fail`, then maps the row:

| Observation                                       | Status   |
|---------------------------------------------------|----------|
| All five attributes `pass`.                       | `COVERED`|
| Exactly one attribute `fail`.                     | `CAUTION`|
| Two or more attributes `fail`.                    | `RISK`   |

The per-BRD goal-level status (`business_goal_smart_status` in the frontmatter overlay per DD-008) is the worst status across all goals.

## Quality report decision inputs

The `BRD Quality Reviewer` sends scoring signals to the paired `BRD_QUALITY_REPORT_V1` payload. The report, not this rubric, combines those signals into `gate_decisions.define_exit` and `gate_decisions.govern_exit`.

| Signal                                                                                                                      | Status evidence              |
|-----------------------------------------------------------------------------------------------------------------------------|------------------------------|
| Requirement rows with `RISK`, `CAUTION`, `COVERED`, or `NOT_APPLICABLE` status                                             | Row-level quality evidence   |
| Business goal rows with `RISK`, `CAUTION`, or `COVERED` status                                                             | SMART quality evidence       |
| FR-to-AC coverage percentage and configured `fr_to_ac_coverage_threshold_pct`                                               | Coverage threshold evidence  |
| ISO 25010 NFR category presence or absence                                                                                  | NFR coverage evidence        |
| ISTQB testability notes attached to requirements                                                                            | Diagnostic evidence          |

The quality report records the resulting decision and the orchestrator later carries the Govern decision into the `BRD_TO_PRD_HANDOFF_V1` payload's `quality_report.govern_exit_decision` field per [handoff-payload-schema.md](handoff-payload-schema.md).

## Govern drift detection

During Govern, the same rubric is re-applied on a cadence defined by the orchestrator. A drift event is recorded when, comparing the most recent passing assessment to the current assessment, any of the following occur:

* A requirement row that was previously `COVERED` becomes `CAUTION` or `RISK`.
* A business goal row that was previously `COVERED` becomes `CAUTION` or `RISK`.
* An NFR category that was previously `COVERED` becomes `CAUTION`.

Drift events set `assessment_outcome = drift` on the findings payload and surface a Govern alert. The quality report decides whether that drift blocks, warns, or remains informational.

## Authoring conventions for reviewer findings

* Always emit per-row status alongside the underlying numeric scores so authors and tooling can both consume the result.
* Always include a concise finding description per `RISK` and `CAUTION` row that names the specific attribute or category causing the status.
* Never aggregate the three dimensions into a single composite number; report them as three independent verdicts.
* Never include gate decision fields in findings; `BRD_QUALITY_REPORT_V1` owns gate decisions.
* Refer to attribute and category definitions by linking to `requirements-definition` reference anchors; do not paraphrase the definitions in the findings payload.

## License

This rubric is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The third-party standards underlying the scoring dimensions (ISO/IEC/IEEE 29148:2018, ISO/IEC 25010:2023, SMART criteria, ISTQB Glossary) are cited by name only in [standards-excerpts.md](standards-excerpts.md) and remain the property of their respective rights holders.

> Brought to you by microsoft/hve-core

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
