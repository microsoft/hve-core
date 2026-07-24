---
description: 'BRD_QUALITY_REPORT_V1 schema - BRD-level quality report emitted by BRD Quality Reviewer with gate decisions, thresholds, summaries, and recommendations'
---

# BRD Quality Report — `BRD_QUALITY_REPORT_V1`

This document defines the `BRD_QUALITY_REPORT_V1` payload emitted by the `BRD Quality Reviewer` subagent (`brd-quality-reviewer`). One payload is produced per Define-exit, Govern-exit, Govern drift, or on-request BRD quality run in the same invocation as the paired `BRD_STANDARD_FINDINGS_V1` payload.

## Purpose

The payload provides the BRD Builder orchestrator with the only quality gate decision record. It owns `gate_decisions.define_exit`, `gate_decisions.govern_exit`, and the threshold-to-decision rules that convert reviewer findings into gate outcomes.

## Format

The payload is YAML.

```yaml
schema_version: BRD_QUALITY_REPORT_V1
report_id: <REPORT_ID>
generated_at: <ISO_8601_TIMESTAMP>
brd:
  id: <BRD_ID>
  version: <BRD_VERSION>
  phase: <BRD_PHASE>
  artifact_path: <BRD_ARTIFACT_PATH>
overall_status: <OVERALL_STATUS>
decision_thresholds:
  iso_29148_core_min_score: <MIN_CORE_SCORE>
  fr_to_ac_min_pct: <FR_AC_MIN_PCT>
  fr_to_bg_target_pct: <FR_BG_TARGET_PCT>
gate_decisions:
  define_exit: <GATE_DECISION>
  govern_exit: <GATE_DECISION>
summary_counts:
  RISK: <RISK_COUNT>
  CAUTION: <CAUTION_COUNT>
  COVERED: <COVERED_COUNT>
  NOT_APPLICABLE: <NA_COUNT>
severity_breakdown:
  CRITICAL: <CRITICAL_COUNT>
  HIGH: <HIGH_COUNT>
  MEDIUM: <MEDIUM_COUNT>
  LOW: <LOW_COUNT>
standards_assessed:
  - skill_name: <STANDARD_SKILL_NAME>
    skill_version: <STANDARD_SKILL_VERSION>
    overall_status: <STANDARD_OVERALL_STATUS>
    findings_ref: <FINDINGS_PAYLOAD_PATH>
    findings_count: <FINDINGS_COUNT>
category_summaries:
  iso_29148:
    average_score: <AVERAGE_SCORE>
    weakest_attribute: <ATTRIBUTE_NAME>
    weakest_attribute_score: <ATTRIBUTE_SCORE>
  iso_25010:
    covered_categories: <COVERED_COUNT>
    missing_categories:
      - <CATEGORY_NAME>
  smart:
    goals_total: <GOALS_TOTAL>
    goals_passing: <GOALS_PASSING>
    pass_rate_pct: <PASS_RATE_PCT>
  fr_ac_coverage:
    fr_total: <FR_TOTAL>
    fr_with_ac: <FR_WITH_AC>
    coverage_pct: <COVERAGE_PCT>
    threshold_pct: <THRESHOLD_PCT>
  fr_bg_coverage:
    fr_total: <FR_TOTAL>
    fr_with_bg: <FR_WITH_BG>
    bg_total: <BG_TOTAL>
    coverage_pct: <COVERAGE_PCT>
    target_pct: <TARGET_PCT>
    waiver_required: <BOOLEAN>
top_findings:
  - finding_id: <FINDING_ID>
    standard: <STANDARD_SKILL_NAME>
    severity: <FINDING_SEVERITY>
    status: <FINDING_STATUS>
    location:
      section: <BRD_SECTION>
      line_range: <LINE_RANGE>
    finding: <FINDING_DESCRIPTION>
    recommendation: <RECOMMENDATION>
recommendations:
  - id: <RECOMMENDATION_ID>
    priority: <RECOMMENDATION_PRIORITY>
    target_section: <BRD_SECTION>
    action: <RECOMMENDATION_ACTION>
    related_finding_ids:
      - <FINDING_ID>
warnings:
  - id: <WARNING_ID>
    severity: <WARNING_SEVERITY>
    message: <WARNING_MESSAGE>
    related_finding_ids:
      - <FINDING_ID>
notes: <REPORT_NOTES>
```

## Field definitions

### Top-level metadata

* `schema_version` (string, required) — MUST be `BRD_QUALITY_REPORT_V1`.
* `report_id` (string, required) — Unique identifier for this report. Recommended form: `<brd_id>-quality-<ISO_8601_basic_timestamp>`.
* `generated_at` (string, required) — ISO 8601 timestamp (UTC) when the report was generated.

### `brd` (object, required)

Same shape as `brd` in `BRD_STANDARD_FINDINGS_V1`, minus `partition_id`. Reports are always BRD-level.

* `id`, `version`, `phase`, `artifact_path` — required strings; see [BRD Standard Findings V1](brd-standard-findings-v1.md#brd-object-required) for definitions.

### `overall_status` (string, required)

One of:

* `PASS` — No reviewer finding has `status: RISK` or `status: CAUTION`, and all threshold rules are met.
* `NEEDS_REVIEW` — One or more reviewer findings has `status: CAUTION`, or a warning-level threshold rule needs acknowledgement or waiver, and no blocking threshold rule is breached.
* `FAIL` — One or more reviewer findings has `status: RISK`, or any blocking threshold rule is breached.

### `decision_thresholds` (object, required)

Thresholds the `BRD Quality Reviewer` applied when deriving `gate_decisions` from the paired findings payload.

* `iso_29148_core_min_score` (integer, required) — Minimum acceptable score for core ISO 29148 attributes. MUST be `2` unless a future schema version changes the threshold.
* `fr_to_ac_min_pct` (number, required) — Minimum FR-to-AC coverage percentage required by the active BRD frontmatter. Default is `80.0` when the BRD does not override it.
* `fr_to_bg_target_pct` (number, required) — Target FR-to-BG coverage percentage. MUST be `100.0`; gaps are waivable only through Govern signoff.

### `gate_decisions` (object, required)

* `define_exit` (string, required) — One of `APPROVED`, `APPROVED_WITH_COMMENTS`, `BLOCKED`, `NOT_EVALUATED`. MUST be `BLOCKED` when `overall_status` is `FAIL`.
* `govern_exit` (string, required) — One of `APPROVED`, `APPROVED_WITH_COMMENTS`, `BLOCKED`, `NOT_EVALUATED`. MUST be `NOT_EVALUATED` when the BRD phase is `Discover` or `Define`.

### `summary_counts` (object, required)

Integer counts of findings by status from the paired `BRD_STANDARD_FINDINGS_V1` payload. Same key set as `BRD_STANDARD_FINDINGS_V1.summary_counts`. Each value MUST be ≥ 0.

### `severity_breakdown` (object, required)

Integer counts of `RISK` and `CAUTION` findings by severity from the paired `BRD_STANDARD_FINDINGS_V1` payload. `COVERED` and `NOT_APPLICABLE` findings (severity `N/A`) are excluded.

* `CRITICAL`, `HIGH`, `MEDIUM`, `LOW` (integer, required, ≥ 0).

### `standards_assessed` (array, required)

Single-element reviewer assessment array. The array shape is retained for compatibility with existing consumers, but `BRD Quality Reviewer` MUST emit exactly one entry representing its combined requirements quality review. It is not a multi-subagent fan-in list.

* `skill_name` (string, required) — Reviewer rubric skill bundle name. Use `requirements-quality` for the combined BRD quality review.
* `skill_version` (string, required) — `spec_version` of the reviewer rubric skill.
* `overall_status` (string, required) — Mirrors the paired `BRD_STANDARD_FINDINGS_V1.overall_status`.
* `findings_ref` (string, optional) — Workspace-relative path to the persisted `BRD_STANDARD_FINDINGS_V1` payload, when persisted by the orchestrator. Omit when the report and findings are returned inline.
* `findings_count` (integer, required, ≥ 0).

### `category_summaries` (object, required)

Rollup statistics derived from the paired `BRD_STANDARD_FINDINGS_V1` payload.

* `iso_29148` (object, required when any assessed standard emits `iso_29148_attributes`; otherwise OPTIONAL).
  * `average_score` (number, required) — Mean of the nine per-attribute scores, rounded to two decimals.
  * `weakest_attribute` (string, required) — Name of the lowest-scoring attribute. Ties resolved by listed order: `necessary`, `appropriate`, `unambiguous`, `complete`, `singular`, `feasible`, `verifiable`, `correct`, `conforming`.
  * `weakest_attribute_score` (integer, required, 0–3).
* `iso_25010` (object, required when any assessed standard emits `iso_25010_categories`; otherwise OPTIONAL).
  * `covered_categories` (integer, required, 0–8).
  * `missing_categories` (array of strings, required) — Names of categories whose presence boolean is `false`. Empty array when all eight categories are covered.
* `smart` (object, required when any assessed standard emits `smart_business_goals`; otherwise OPTIONAL).
  * `goals_total` (integer, required, ≥ 0).
  * `goals_passing` (integer, required, 0 ≤ value ≤ `goals_total`).
  * `pass_rate_pct` (number, required, 0.0–100.0) — `100 * goals_passing / goals_total` when `goals_total > 0`; `100.0` otherwise.
* `fr_ac_coverage` (object, required when any assessed standard emits `fr_ac_coverage`; otherwise OPTIONAL).
  * Same shape as `BRD_STANDARD_FINDINGS_V1.fr_ac_coverage`.
  * `threshold_pct` (number, required) — Threshold applied for Define-exit decisioning.
* `fr_bg_coverage` (object, required when the BRD contains functional requirements or business goals; otherwise OPTIONAL).
  * `fr_total` (integer, required, ≥ 0).
  * `fr_with_bg` (integer, required, 0 ≤ value ≤ `fr_total`) — Count of functional requirements linked to at least one business goal.
  * `bg_total` (integer, required, ≥ 0) — Count of business goals detected in the BRD.
  * `coverage_pct` (number, required, 0.0–100.0) — `100 * fr_with_bg / fr_total` when `fr_total > 0`; `0.0` when `fr_total == 0`.
  * `target_pct` (number, required) — Target coverage percentage, normally `100.0`.
  * `waiver_required` (boolean, required) — `true` when `coverage_pct` is below `target_pct`.

### `top_findings` (array, required)

Up to ten findings selected for executive surfacing. Selection rule: take all `RISK` findings first (ordered by severity then by appearance in the underlying payloads), then `CAUTION` findings, up to ten total.

Each entry:

* `finding_id` (string, required) — Same value as in the source `BRD_STANDARD_FINDINGS_V1.findings[].finding_id`.
* `standard` (string, required) — Source reviewer rubric skill name.
* `severity` (string, required) — `CRITICAL`, `HIGH`, `MEDIUM`, `LOW`. `N/A` is forbidden in `top_findings`.
* `status` (string, required) — `RISK` or `CAUTION`. `COVERED` and `NOT_APPLICABLE` are forbidden in `top_findings`.
* `location`, `finding`, `recommendation` — same shape as in `BRD_STANDARD_FINDINGS_V1.findings`.

### `recommendations` (array, required)

Zero or more prioritized actions the author should take before re-requesting the gate. Each entry consolidates one or more underlying findings into a single coaching item.

* `id` (string, required) — Unique within the payload. Recommended form: `REC-<sequence>`.
* `priority` (string, required) — `P0`, `P1`, `P2`, `P3`. `P0` MUST be used when any related finding has severity `CRITICAL`; `P1` when any related finding has severity `HIGH`.
* `target_section` (string, required) — BRD section the author should revise.
* `action` (string, required) — Concrete revision instruction.
* `related_finding_ids` (array of strings, required, length ≥ 1) — Finding IDs from `BRD_STANDARD_FINDINGS_V1.findings[].finding_id`.

### `warnings` (array, optional)

Zero or more non-finding warnings the orchestrator or author should consider. Use warnings for calibration caveats, waivable coverage gaps, partial source availability, or drift context that does not belong to a single finding.

* `id` (string, required) — Unique within the payload. Recommended form: `WARN-001`.
* `severity` (string, required) — One of `INFO`, `WARNING`, `ADVISORY`.
* `message` (string, required) — Concise warning text.
* `related_finding_ids` (array of strings, optional) — Finding IDs from `BRD_STANDARD_FINDINGS_V1.findings[].finding_id`.

### `notes` (string, optional)

Free-form reviewer commentary (for example calibration warnings, missing source caveats, or drift review context).

## Validation rules

1. `schema_version` MUST equal `BRD_QUALITY_REPORT_V1`.
2. `overall_status` MUST be consistent with the paired findings payload and threshold rules:
  * `FAIL` if `summary_counts.RISK > 0`.
  * `FAIL` if any core ISO 29148 attribute (`necessary`, `unambiguous`, `singular`, or `verifiable`) scores below `decision_thresholds.iso_29148_core_min_score`.
  * `FAIL` if `category_summaries.fr_ac_coverage.coverage_pct` is below `decision_thresholds.fr_to_ac_min_pct`.
  * `NEEDS_REVIEW` if no fail condition is present and `summary_counts.CAUTION > 0`.
  * `NEEDS_REVIEW` if no fail condition is present and `category_summaries.fr_bg_coverage.waiver_required` is `true`.
  * `PASS` otherwise.
3. ISO 29148 score `1` maps to `CAUTION` in general rubric scoring, but any core ISO 29148 attribute below `2` is blocking through this report's threshold rules.
4. `gate_decisions.define_exit` MUST be `BLOCKED` when `overall_status` is `FAIL`.
5. `gate_decisions.define_exit` MUST be `APPROVED_WITH_COMMENTS` when `overall_status` is `NEEDS_REVIEW`.
6. `gate_decisions.define_exit` MAY be `APPROVED` only when `overall_status` is `PASS`.
7. `gate_decisions.govern_exit` MUST be `NOT_EVALUATED` when `brd.phase` is `Discover` or `Define`.
8. `gate_decisions.govern_exit` MUST be `BLOCKED` when `brd.phase` is `Govern`, `overall_status` is `FAIL`, and no approved waiver covers the blocking condition.
9. `gate_decisions.govern_exit` MUST be `APPROVED_WITH_COMMENTS` when `brd.phase` is `Govern`, no blocking condition remains, and warnings or waivable coverage gaps remain.
10. `summary_counts.*` MUST equal the corresponding counts in the paired `BRD_STANDARD_FINDINGS_V1` payload.
11. `severity_breakdown.*` MUST equal the count of `RISK` and `CAUTION` findings at each severity in the paired findings payload.
12. `standards_assessed` MUST have exactly one entry when produced by `BRD Quality Reviewer`.
13. Every `recommendations[].id` MUST be unique within the payload.
14. Every `recommendations[].related_finding_ids[]` value MUST exist as a `findings[].finding_id` in the paired `BRD_STANDARD_FINDINGS_V1` payload.
15. Every `warnings[].id`, when present, MUST be unique within the payload.
16. `top_findings` MUST contain only `RISK` and `CAUTION` items; length MUST be ≤ 10.

## Example payload

```yaml
schema_version: BRD_QUALITY_REPORT_V1
report_id: BRD-2026-018-quality-20260508T141055Z
generated_at: "2026-05-08T14:10:55Z"
brd:
  id: BRD-2026-018
  version: 0.3.1
  phase: Define
  artifact_path: docs/brds/2026/brd-claims-intake.md
overall_status: FAIL
decision_thresholds:
  iso_29148_core_min_score: 2
  fr_to_ac_min_pct: 80.0
  fr_to_bg_target_pct: 100.0
gate_decisions:
  define_exit: BLOCKED
  govern_exit: NOT_EVALUATED
summary_counts:
  RISK: 3
  CAUTION: 4
  COVERED: 18
  NOT_APPLICABLE: 2
severity_breakdown:
  CRITICAL: 0
  HIGH: 2
  MEDIUM: 4
  LOW: 1
standards_assessed:
  - skill_name: requirements-quality
    skill_version: "1.0"
    overall_status: RISK
    findings_ref: .copilot-tracking/quality/2026-05-08/BRD-2026-018/req-qual-findings.yml
    findings_count: 23
category_summaries:
  iso_29148:
    average_score: 2.50
    weakest_attribute: unambiguous
    weakest_attribute_score: 1
  iso_25010:
    covered_categories: 5
    missing_categories:
      - compatibility
      - maintainability
      - portability
  smart:
    goals_total: 4
    goals_passing: 3
    pass_rate_pct: 75.0
  fr_ac_coverage:
    fr_total: 24
    fr_with_ac: 21
    coverage_pct: 87.5
    threshold_pct: 80.0
  fr_bg_coverage:
    fr_total: 24
    fr_with_bg: 22
    bg_total: 4
    coverage_pct: 91.67
    target_pct: 100.0
    waiver_required: true
top_findings:
  - finding_id: req-qual-001
    standard: requirements-quality
    severity: HIGH
    status: RISK
    location:
      section: "3.2 Functional Requirements"
      line_range: L142-L148
    finding: FR-001 uses the unqualified term "quickly" without a measurable threshold.
    recommendation: Restate FR-001 with a quantitative latency target (for example "within 2 seconds of submission").
  - finding_id: req-qual-002
    standard: requirements-quality
    severity: HIGH
    status: RISK
    location:
      section: "1.3 Business Goals"
      line_range: L48-L52
    finding: Business goal BG-001 has no measurable success metric and fails SMART Measurable.
    recommendation: Add a numeric KPI to BG-001 (for example "reduce claim cycle time by 30%").
  - finding_id: ac-003
    standard: acceptance-criteria
    severity: MEDIUM
    status: CAUTION
    location:
      section: "5 Acceptance Criteria"
    finding: Three functional requirements (FR-007, FR-012, FR-018) have no Gherkin AC blocks.
    recommendation: Author at least one Given/When/Then scenario per uncovered FR.
recommendations:
  - id: REC-1
    priority: P1
    target_section: "3.2 Functional Requirements"
    action: Quantify every NFR-style adverb (quickly, often, large) currently embedded in FR statements; move performance constraints to the NFR section with measurable thresholds.
    related_finding_ids:
      - req-qual-001
  - id: REC-2
    priority: P1
    target_section: "1.3 Business Goals"
    action: Add SMART-compliant KPIs to BG-001 and re-confirm BG-004 timeline anchors.
    related_finding_ids:
      - req-qual-002
  - id: REC-3
    priority: P2
    target_section: "5 Acceptance Criteria"
    action: Backfill Gherkin acceptance criteria for FR-007, FR-012, FR-018 to reach 100% FR-to-AC coverage before Govern.
    related_finding_ids:
      - ac-003
warnings:
  - id: WARN-001
    severity: WARNING
    message: FR-to-BG coverage is below the 100% Govern target and requires an approved waiver before signoff.
    related_finding_ids:
      - req-qual-002
notes: Compatibility, maintainability, and portability NFR categories are absent; flagged for stakeholder discussion before Govern (no automatic block per DD-012).
```


