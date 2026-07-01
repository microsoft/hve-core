---
description: 'BRD_STANDARD_FINDINGS_V1 schema - detailed findings output emitted by BRD Quality Reviewer with ISO 29148, ISO 25010, SMART, and coverage evidence'
---

# BRD Standard Findings — `BRD_STANDARD_FINDINGS_V1`

This document defines the `BRD_STANDARD_FINDINGS_V1` payload emitted by the `BRD Quality Reviewer` subagent (`brd-quality-reviewer`). One payload is produced in the same invocation as the paired `BRD_QUALITY_REPORT_V1` payload.

## Purpose

The payload captures structured issue details for one BRD quality review. Findings carry status, severity, location, optional requirement identifiers, observations, and recommendations. Findings MUST NOT carry gate decisions; the paired `BRD_QUALITY_REPORT_V1` payload owns Define-exit and Govern-exit decisions.

## Format

The payload is YAML. Top-level fields are unordered; producers SHOULD emit fields in the order documented below for human readability. Consumers MUST tolerate any field order.

```yaml
schema_version: BRD_STANDARD_FINDINGS_V1
assessment_id: <ASSESSMENT_ID>
assessed_at: <ISO_8601_TIMESTAMP>
brd:
  id: <BRD_ID>
  version: <BRD_VERSION>
  phase: <BRD_PHASE>
  partition_id: <PARTITION_ID>
  artifact_path: <BRD_ARTIFACT_PATH>
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
      section: <BRD_SECTION>
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
iso_25010_categories:
  functional_suitability: <PRESENCE_BOOLEAN>
  performance_efficiency: <PRESENCE_BOOLEAN>
  compatibility: <PRESENCE_BOOLEAN>
  usability: <PRESENCE_BOOLEAN>
  reliability: <PRESENCE_BOOLEAN>
  security: <PRESENCE_BOOLEAN>
  maintainability: <PRESENCE_BOOLEAN>
  portability: <PRESENCE_BOOLEAN>
smart_business_goals:
  - goal_id: <BUSINESS_GOAL_ID>
    statement: <BUSINESS_GOAL_STATEMENT>
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

* `schema_version` (string, required) — MUST be the literal string `BRD_STANDARD_FINDINGS_V1`. Consumers fail fast on any other value.
* `assessment_id` (string, required) — Unique identifier for this assessment run. Recommended form: `<standard_skill_name>-<brd_id>-<ISO_8601_basic_timestamp>`.
* `assessed_at` (string, required) — ISO 8601 timestamp (UTC) when the assessment completed.
* `mode` (string, required) — MUST be the literal string `plan`. The `BRD Quality Reviewer` operates in plan mode; `audit` and `diff` are reserved for future scenarios.
* `assessment_outcome` (string, optional) — One of `plan`, `drift`. Omit or set to `plan` for ordinary Define-exit or on-request reviews. Set to `drift` when Govern drift detection finds a regression from the last passing review.

### `brd` (object, required)

* `id` (string, required) — Stable BRD identifier (for example `BRD-2026-018`).
* `version` (string, required) — Semantic version of the BRD draft assessed (for example `0.3.1`). Drafts use `0.x.y`; signed-off BRDs use `1.x.y`.
* `phase` (string, required) — One of `Discover`, `Define`, `Govern`. Matches the BRD Builder lifecycle phase active when the assessment ran.
* `partition_id` (string, optional) — Identifier of the BRD partition assessed when the BRD is partitioned. Omit when the assessment covers the full BRD.
* `artifact_path` (string, required) — Workspace-relative path to the BRD artifact.

### `standard` (object, required)

* `skill_name` (string, required) — Name of the standard skill bundle that supplied the rubric (for example `requirements-quality`).
* `skill_version` (string, required) — `spec_version` value from the standard skill's `SKILL.md` frontmatter.

### `overall_status` (string, required)

One of:

* `RISK` — At least one finding has status `RISK`. Define-exit gate blocked.
* `CAUTION` — No `RISK` findings; one or more `CAUTION` findings. Soft-block; surface in coaching.
* `COVERED` — All applicable checklist items satisfied; no `RISK` or `CAUTION` findings.
* `NOT_APPLICABLE` — The standard is not applicable to this BRD partition; no findings emitted other than `NOT_APPLICABLE` rows.

### `summary_counts` (object, required)

Integer counts of findings by status. Sum MUST equal the length of the `findings` array.

* `RISK` (integer, required, ≥ 0).
* `CAUTION` (integer, required, ≥ 0).
* `COVERED` (integer, required, ≥ 0).
* `NOT_APPLICABLE` (integer, required, ≥ 0).

### `findings` (array, required)

Zero or more finding objects, one per checklist item evaluated. Each item:

* `finding_id` (string, required) — Unique within the payload. Recommended form: `<standard_skill_name>-<sequence>` (for example `req-eng-001`).
* `checklist_item` (string, required) — Identifier of the rubric checklist item from the standard skill (for example `iso-29148-singular`).
* `requirement_id` (string, optional) — Requirement, business goal, acceptance criterion, or decision identifier the finding evaluates. Use canonical three-or-more-digit identifiers such as `FR-001`, `AC-001`, `NFR-001`, `CON-001`, `BR-001`, `BG-001`, or `DD-001` when the finding maps to one item.
* `status` (string, required) — One of `RISK`, `CAUTION`, `COVERED`, `NOT_APPLICABLE`.
* `severity` (string, required) — One of `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`, `N/A`. `N/A` MUST be used when `status` is `COVERED` or `NOT_APPLICABLE`.
* `location` (object, required) — Pointer into the BRD artifact.
  * `section` (string, required) — Section identifier or heading text (for example `3.2 Functional Requirements`).
  * `line_range` (string, optional) — Line range in the BRD artifact (for example `L142-L158`). Omit when the finding spans the whole section.
* `finding` (string, required) — Narrative description of what the reviewer observed. One to three sentences.
* `recommendation` (string, required) — Concrete next action for the author. `null` is permitted only when `status` is `COVERED` or `NOT_APPLICABLE`.

### `iso_29148_attributes` (object, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Score (integer, 0–3 inclusive) per ISO/IEC/IEEE 29148 individual-requirement attribute. Scoring anchors are defined in the `requirements-definition` skill's rubric reference.

Required keys when present: `necessary`, `appropriate`, `unambiguous`, `complete`, `singular`, `feasible`, `verifiable`, `correct`, `conforming`.

### `iso_25010_categories` (object, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Boolean per ISO/IEC 25010 quality characteristic indicating whether the BRD partition addresses at least one NFR in that category. Per DD-012, missing categories surface as a qualitative flag and do not require an N/A justification.

Required keys when present: `functional_suitability`, `performance_efficiency`, `compatibility`, `usability`, `reliability`, `security`, `maintainability`, `portability`.

### `smart_business_goals` (array, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Zero or more goal objects. Per DD-008, every business goal in the BRD must be SMART by Govern exit.

* `goal_id` (string, required) — Identifier of the business goal in the BRD (for example `BG-001`).
* `statement` (string, required) — Verbatim goal statement from the BRD.
* `specific`, `measurable`, `achievable`, `relevant`, `time_bound` (boolean, required) — Per-attribute pass/fail.
* `overall` (string, required) — `PASS` when all five attributes are `true`; `FAIL` otherwise.

### `fr_ac_coverage` (object, conditional)

Required when `standard.skill_name` is `requirements-quality`; otherwise optional.
Coverage of functional requirements by acceptance criteria, per DD-009.

* `fr_total` (integer, required, ≥ 0).
* `fr_with_ac` (integer, required, 0 ≤ value ≤ `fr_total`).
* `coverage_pct` (number, required, 0.0–100.0) — Computed as `100 * fr_with_ac / fr_total` when `fr_total > 0`; `0.0` when `fr_total == 0`.

### `notes` (string, optional)

Free-form reviewer commentary not tied to a specific finding (for example calibration notes, ambiguous edge cases observed during scoring).

## Validation rules

1. `schema_version` MUST equal `BRD_STANDARD_FINDINGS_V1`.
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
8. `smart_business_goals[].overall` MUST be `PASS` if and only if all five SMART booleans are `true`.
9. `fr_ac_coverage.fr_with_ac` MUST be less than or equal to `fr_ac_coverage.fr_total`.
10. `assessed_at` MUST be a valid ISO 8601 timestamp with timezone designator.
11. The payload MUST NOT include `gate_decision`, `gate_decisions`, `define_exit`, or `govern_exit`; gate decisions belong to `BRD_QUALITY_REPORT_V1`.

## Example payload

```yaml
schema_version: BRD_STANDARD_FINDINGS_V1
assessment_id: requirements-quality-BRD-2026-018-20260508T140312Z
assessed_at: "2026-05-08T14:03:12Z"
brd:
  id: BRD-2026-018
  version: 0.3.1
  phase: Define
  partition_id: claims-intake
  artifact_path: docs/brds/2026/brd-claims-intake.md
standard:
  skill_name: requirements-quality
  skill_version: "1.0"
mode: plan
assessment_outcome: plan
overall_status: RISK
summary_counts:
  RISK: 2
  CAUTION: 1
  COVERED: 5
  NOT_APPLICABLE: 0
findings:
  - finding_id: req-qual-001
    checklist_item: iso-29148-unambiguous
    requirement_id: FR-001
    status: RISK
    severity: HIGH
    location:
      section: "3.2 Functional Requirements"
      line_range: L142-L148
    finding: FR-001 uses the unqualified term "quickly" without a measurable threshold, violating ISO 29148 unambiguity.
    recommendation: Restate FR-001 with a quantitative latency target (for example "within 2 seconds of submission").
  - finding_id: req-qual-002
    checklist_item: smart-business-goal-measurable
    requirement_id: BG-001
    status: RISK
    severity: HIGH
    location:
      section: "1.3 Business Goals"
      line_range: L48-L52
    finding: Business goal BG-001 has no measurable success metric and fails the SMART Measurable attribute.
    recommendation: Add a numeric KPI to BG-001 (for example "reduce claim cycle time by 30%").
  - finding_id: req-qual-003
    checklist_item: iso-25010-security-coverage
    requirement_id: NFR-001
    status: CAUTION
    severity: MEDIUM
    location:
      section: "4 Non-Functional Requirements"
    finding: The Security category contains a single authentication NFR; no NFRs address confidentiality, integrity, or auditability.
    recommendation: Add NFRs covering data confidentiality at rest and audit logging retention.
  - finding_id: req-qual-004
    checklist_item: iso-29148-singular
    requirement_id: FR-002
    status: COVERED
    severity: N/A
    location:
      section: "3.2 Functional Requirements"
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
  conforming: 3
iso_25010_categories:
  functional_suitability: true
  performance_efficiency: true
  compatibility: false
  usability: true
  reliability: true
  security: true
  maintainability: false
  portability: false
smart_business_goals:
  - goal_id: BG-001
    statement: Reduce average claim adjudication time by 30% within 12 months of launch.
    specific: true
    measurable: true
    achievable: true
    relevant: true
    time_bound: true
    overall: PASS
  - goal_id: BG-002
    statement: Improve customer satisfaction with the claims experience.
    specific: false
    measurable: false
    achievable: true
    relevant: true
    time_bound: false
    overall: FAIL
fr_ac_coverage:
  fr_total: 24
  fr_with_ac: 21
  coverage_pct: 87.5
notes: Partition `claims-intake` reviewed in isolation; cross-partition NFRs (residency, retention) deferred to the BRD-level aggregate run.
```


