---
description: 'PRD_STANDARD_FINDINGS_V1 schema - detailed findings output emitted by PRD Quality Reviewer with ISO 29148, NIST SP 800-160 NFR, SMART, and acceptance-coverage evidence'
---

# PRD Standard Findings — `PRD_STANDARD_FINDINGS_V1`

This document defines the `PRD_STANDARD_FINDINGS_V1` payload emitted by the `PRD Quality Reviewer` subagent (`prd-quality-reviewer`). One payload is produced in the same invocation as the paired `PRD_QUALITY_REPORT_V1` payload. The PRD payload mirrors the BRD-side [`BRD_STANDARD_FINDINGS_V1`](../brd/brd-standard-findings-v1.md) shape, diverging only where the PRD lifecycle, NFR taxonomy, and identifier set differ.

## Purpose

The payload captures structured issue details for one PRD quality review. Findings carry status, severity, location, optional requirement identifiers, observations, and recommendations. Findings MUST NOT carry gate decisions; the paired `PRD_QUALITY_REPORT_V1` payload owns Validate-exit and Finalize-exit decisions.

## Format

The payload is YAML. Top-level fields are unordered; producers SHOULD emit fields in the order documented below for human readability. Consumers MUST tolerate any field order.

```yaml
schema_version: PRD_STANDARD_FINDINGS_V1
assessment_id: <ASSESSMENT_ID>
assessed_at: <ISO_8601_TIMESTAMP>
prd:
  id: <PRD_ID>
  version: <PRD_VERSION>
  phase: <PRD_PHASE>
  partition_id: <PARTITION_ID>
  artifact_path: <PRD_ARTIFACT_PATH>
standard:
  skill_name: <STANDARD_SKILL_NAME>
  skill_version: <STANDARD_SKILL_VERSION>
mode: plan
assessment_outcome: <ASSESSMENT_OUTCOME>
overall_status: <OVERALL_STATUS>
summary_counts:
  RISK: <RISK_COUNT>
  CAUTION: <CAUTION_COUNT>
  COVERED: <COVERED_COUNT>
  NOT_APPLICABLE: <NA_COUNT>
findings:
  - finding_id: <FINDING_ID>
    checklist_item: <CHECKLIST_ITEM_ID>
    requirement_id: <REQUIREMENT_ID>
    status: <FINDING_STATUS>
    severity: <FINDING_SEVERITY>
    location:
      section: <PRD_SECTION>
      line_range: <LINE_RANGE>
    finding: <FINDING_DESCRIPTION>
    recommendation: <RECOMMENDATION>
iso_29148_attributes:
  necessary: <ATTRIBUTE_SCORE>
  appropriate: <ATTRIBUTE_SCORE>
  unambiguous: <ATTRIBUTE_SCORE>
  complete: <ATTRIBUTE_SCORE>
  singular: <ATTRIBUTE_SCORE>
  feasible: <ATTRIBUTE_SCORE>
  verifiable: <ATTRIBUTE_SCORE>
  correct: <ATTRIBUTE_SCORE>
  conforming: <ATTRIBUTE_SCORE>
nist_800_160_nfr_categories:
  performance_and_capacity: <PRESENCE_BOOLEAN>
  reliability_and_resilience: <PRESENCE_BOOLEAN>
  security: <PRESENCE_BOOLEAN>
  privacy: <PRESENCE_BOOLEAN>
  scalability_and_elasticity: <PRESENCE_BOOLEAN>
  maintainability_and_operability: <PRESENCE_BOOLEAN>
  observability: <PRESENCE_BOOLEAN>
  usability_and_accessibility: <PRESENCE_BOOLEAN>
  compatibility_and_interoperability: <PRESENCE_BOOLEAN>
  portability: <PRESENCE_BOOLEAN>
smart_product_goals:
  - goal_id: <PRODUCT_GOAL_ID>
    statement: <PRODUCT_GOAL_STATEMENT>
    specific: <SMART_BOOLEAN>
    measurable: <SMART_BOOLEAN>
    achievable: <SMART_BOOLEAN>
    relevant: <SMART_BOOLEAN>
    time_bound: <SMART_BOOLEAN>
    overall: <SMART_PASS_FAIL>
fr_ac_coverage:
  fr_total: <FR_TOTAL>
  fr_with_ac: <FR_WITH_AC>
  coverage_pct: <COVERAGE_PCT>
notes: <REVIEWER_NOTES>
```

## Field definitions

### Top-level metadata

* `schema_version` (string, required) — MUST be the literal string `PRD_STANDARD_FINDINGS_V1`. Consumers fail fast on any other value.
* `assessment_id` (string, required) — Unique identifier for this assessment run. Recommended form: `<standard_skill_name>-<prd_id>-<ISO_8601_basic_timestamp>`.
* `assessed_at` (string, required) — ISO 8601 timestamp (UTC) when the assessment completed.
* `mode` (string, required) — MUST be the literal string `plan`. The `PRD Quality Reviewer` operates in plan mode; `audit` and `diff` are reserved for future scenarios.
* `assessment_outcome` (string, optional) — One of `plan`, `drift`. Omit or set to `plan` for ordinary Validate-exit or on-request reviews. Set to `drift` when Finalize drift detection finds a regression from the last passing review.

### `prd` (object, required)

* `id` (string, required) — Stable PRD identifier (for example `PRD-2026-014`).
* `version` (string, required) — Semantic version of the PRD draft assessed (for example `0.4.0`). Drafts use `0.x.y`; finalized PRDs use `1.x.y`.
* `phase` (string, required) — One of `Assess`, `Discover`, `Create`, `Build`, `Integrate`, `Validate`, `Finalize`. Matches the PRD Builder lifecycle phase active when the assessment ran.
* `partition_id` (string, optional) — Identifier of the PRD partition assessed when the PRD is partitioned. Omit when the assessment covers the full PRD.
* `artifact_path` (string, required) — Workspace-relative path to the PRD artifact.

### `standard` (object, required)

* `skill_name` (string, required) — Name of the standard skill bundle that supplied the rubric (for example `requirements-quality`).
* `skill_version` (string, required) — `spec_version` value from the standard skill's `SKILL.md` frontmatter.

### `overall_status` (string, required)

One of:

* `RISK` — At least one finding has status `RISK`. Validate-exit gate blocked.
* `CAUTION` — No `RISK` findings; one or more `CAUTION` findings. Soft-block; surface in coaching.
* `COVERED` — All applicable checklist items satisfied; no `RISK` or `CAUTION` findings.
* `NOT_APPLICABLE` — The standard is not applicable to this PRD partition; no findings emitted other than `NOT_APPLICABLE` rows.

### `summary_counts` (object, required)

Integer counts of findings by status. Sum MUST equal the length of the `findings` array.

* `RISK` (integer, required, ≥ 0).
* `CAUTION` (integer, required, ≥ 0).
* `COVERED` (integer, required, ≥ 0).
* `NOT_APPLICABLE` (integer, required, ≥ 0).

### `findings` (array, required)

Zero or more finding objects, one per checklist item evaluated. Each item:

* `finding_id` (string, required) — Unique within the payload. Recommended form: `<standard_skill_name>-<sequence>` (for example `req-qual-001`).
* `checklist_item` (string, required) — Identifier of the rubric checklist item from the standard skill (for example `iso-29148-singular`).
* `requirement_id` (string, optional) — Requirement, product goal, acceptance criterion, or decision identifier the finding evaluates. Use canonical three-or-more-digit identifiers such as `FR-001`, `AC-001`, `NFR-001`, `CON-001`, `GOAL-001`, or `DD-001` when the finding maps to one item.
* `status` (string, required) — One of `RISK`, `CAUTION`, `COVERED`, `NOT_APPLICABLE`.
* `severity` (string, required) — One of `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `N/A`. `N/A` MUST be used when `status` is `COVERED` or `NOT_APPLICABLE`.
* `location` (object, required) — Pointer into the PRD artifact.
  * `section` (string, required) — Section identifier or heading text (for example `6. Functional Requirements`).
  * `line_range` (string, optional) — Line range in the PRD artifact (for example `L142-L158`). Omit when the finding spans the whole section.
* `finding` (string, required) — Narrative description of what the reviewer observed. One to three sentences.
* `recommendation` (string, required) — Concrete next action for the author. `null` is permitted only when `status` is `COVERED` or `NOT_APPLICABLE`.

### `iso_29148_attributes` (object, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Score (integer, 0–3 inclusive) per ISO/IEC/IEEE 29148 individual-requirement attribute. Scoring anchors are defined in the shared [requirements-definition](../_shared/requirements-definition.md) rubric reference.

Required keys when present: `necessary`, `appropriate`, `unambiguous`, `complete`, `singular`, `feasible`, `verifiable`, `correct`, `conforming`.

### `nist_800_160_nfr_categories` (object, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Boolean per NIST SP 800-160 NFR category indicating whether the PRD partition addresses at least one NFR in that category. Category definitions and presence indicators are in [nist-800-160-nfr.md](nist-800-160-nfr.md). Per DD-02 the PRD side uses this ten-bucket taxonomy in place of the eight ISO/IEC 25010 categories used on the BRD side. Missing categories surface as a qualitative flag and do not require an N/A justification.

Required keys when present: `performance_and_capacity`, `reliability_and_resilience`, `security`, `privacy`, `scalability_and_elasticity`, `maintainability_and_operability`, `observability`, `usability_and_accessibility`, `compatibility_and_interoperability`, `portability`.

### `smart_product_goals` (array, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Zero or more goal objects. Every product goal in the PRD must be SMART by Finalize exit.

* `goal_id` (string, required) — Identifier of the product goal in the PRD (for example `GOAL-001`).
* `statement` (string, required) — Verbatim goal statement from the PRD.
* `specific`, `measurable`, `achievable`, `relevant`, `time_bound` (boolean, required) — Per-attribute pass/fail.
* `overall` (string, required) — `PASS` when all five attributes are `true`; `FAIL` otherwise.

### `fr_ac_coverage` (object, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Coverage of functional requirements by acceptance criteria.

* `fr_total` (integer, required, ≥ 0).
* `fr_with_ac` (integer, required, 0 ≤ value ≤ `fr_total`).
* `coverage_pct` (number, required, 0.0–100.0) — Computed as `100 * fr_with_ac / fr_total` when `fr_total > 0`; `0.0` when `fr_total == 0`.

### `notes` (string, optional)

Free-form reviewer commentary not tied to a specific finding (for example calibration notes, ambiguous edge cases observed during scoring).

## Validation rules

1. `schema_version` MUST equal `PRD_STANDARD_FINDINGS_V1`.
2. `overall_status` MUST be consistent with `summary_counts`:
   * `RISK` when `summary_counts.RISK > 0`.
   * `CAUTION` when `summary_counts.RISK == 0` and `summary_counts.CAUTION > 0`.
   * `COVERED` when `summary_counts.RISK == 0`, `summary_counts.CAUTION == 0`, and `summary_counts.COVERED > 0`.
   * `NOT_APPLICABLE` when `summary_counts.COVERED == 0`, `summary_counts.RISK == 0`, and `summary_counts.CAUTION == 0`.
3. Every `findings[].finding_id` MUST be unique within the payload.
4. Every `findings[].requirement_id`, when present, MUST use the canonical `PREFIX-###` form with at least three digits.
5. Every `findings[].severity` MUST be `N/A` when `findings[].status` is `COVERED` or `NOT_APPLICABLE`.
6. Every `findings[].recommendation` MUST be non-null when `findings[].status` is `RISK` or `CAUTION`.
7. `iso_29148_attributes.*` values MUST be integers in the closed interval `[0, 3]`, and the object MUST include `correct` when present.
8. `smart_product_goals[].overall` MUST be `PASS` if and only if all five SMART booleans are `true`.
9. `fr_ac_coverage.fr_with_ac` MUST be less than or equal to `fr_ac_coverage.fr_total`.
10. `assessed_at` MUST be a valid ISO 8601 timestamp with timezone designator.
11. The payload MUST NOT include `gate_decision`, `gate_decisions`, `validate_exit`, or `finalize_exit`; gate decisions belong to `PRD_QUALITY_REPORT_V1`.

## Example payload

```yaml
schema_version: PRD_STANDARD_FINDINGS_V1
assessment_id: requirements-quality-PRD-2026-014-20260612T140312Z
assessed_at: "2026-06-12T14:03:12Z"
prd:
  id: PRD-2026-014
  version: 0.4.0
  phase: Validate
  partition_id: checkout-redesign
  artifact_path: docs/prds/2026/prd-checkout-redesign.md
standard:
  skill_name: requirements-quality
  skill_version: "1.0"
mode: plan
assessment_outcome: plan
overall_status: RISK
summary_counts:
  RISK: 2
  CAUTION: 1
  COVERED: 6
  NOT_APPLICABLE: 0
findings:
  - finding_id: req-qual-001
    checklist_item: iso-29148-unambiguous
    requirement_id: FR-001
    status: RISK
    severity: HIGH
    location:
      section: "6. Functional Requirements"
      line_range: L142-L148
    finding: FR-001 uses the unqualified term "fast" without a measurable threshold, violating ISO 29148 unambiguity.
    recommendation: Restate FR-001 with a quantitative latency target (for example "render the cart within 1 second of update").
  - finding_id: req-qual-002
    checklist_item: smart-product-goal-measurable
    requirement_id: GOAL-001
    status: RISK
    severity: HIGH
    location:
      section: "1. Executive Summary"
      line_range: L48-L52
    finding: Product goal GOAL-001 has no measurable success metric and fails the SMART Measurable attribute.
    recommendation: Add a numeric KPI to GOAL-001 (for example "increase checkout completion rate by 8%").
  - finding_id: req-qual-003
    checklist_item: nist-800-160-observability-coverage
    requirement_id: NFR-004
    status: CAUTION
    severity: MEDIUM
    location:
      section: "7. Non-Functional Requirements"
    finding: The Observability category contains no NFR naming required logs, metrics, traces, or alerting thresholds.
    recommendation: Add an NFR defining checkout funnel instrumentation and alert thresholds.
  - finding_id: req-qual-004
    checklist_item: iso-29148-singular
    requirement_id: FR-002
    status: COVERED
    severity: N/A
    location:
      section: "6. Functional Requirements"
    finding: All functional requirements are atomic; no compound statements detected.
    recommendation: null
iso_29148_attributes:
  necessary: 3
  appropriate: 3
  unambiguous: 1
  complete: 2
  singular: 3
  feasible: 3
  verifiable: 2
  correct: 3
  conforming: 3
nist_800_160_nfr_categories:
  performance_and_capacity: true
  reliability_and_resilience: true
  security: true
  privacy: true
  scalability_and_elasticity: false
  maintainability_and_operability: false
  observability: false
  usability_and_accessibility: true
  compatibility_and_interoperability: false
  portability: false
smart_product_goals:
  - goal_id: GOAL-001
    statement: Increase checkout completion rate by 8% within two quarters of launch.
    specific: true
    measurable: true
    achievable: true
    relevant: true
    time_bound: true
    overall: PASS
  - goal_id: GOAL-002
    statement: Make the checkout experience feel modern.
    specific: false
    measurable: false
    achievable: true
    relevant: true
    time_bound: false
    overall: FAIL
fr_ac_coverage:
  fr_total: 18
  fr_with_ac: 15
  coverage_pct: 83.33
notes: Partition `checkout-redesign` reviewed in isolation; cross-partition NFRs (data residency) deferred to the PRD-level aggregate run.
```

## License

This reference file is original Microsoft content licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). The schema definition and validation rules are HVE-Core IP and may be reused under the same license.


