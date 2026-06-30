---
description: 'BRD_TO_PRD_HANDOFF_V1 schema - Govern-exit handoff payload produced by the BRD Builder orchestrator and consumed by the PRD Builder, carrying BRD identity, signoff status, requirement counts, traceability matrix pointer, business goals, and quality-report linkage'
---

# BRD-to-PRD Handoff — `BRD_TO_PRD_HANDOFF_V1`

This document defines the `BRD_TO_PRD_HANDOFF_V1` payload produced by the BRD Builder orchestrator at the Govern exit gate. The payload is the canonical contract by which a signed-off BRD is handed off to the downstream PRD Builder.

## Purpose

The payload gives the PRD Builder (or any downstream consumer such as a release manager or auditing tool) a single, self-describing manifest that:

* identifies which BRD is being handed off and at what version;
* documents the signoff status and approvers;
* enumerates the requirement counts the PRD must trace back to;
* points at the BRD artifact, the traceability matrix, and the quality report that justified the gate decision;
* surfaces business goals the PRD must continue to satisfy;
* lists known open items deferred from BRD into PRD scope.

## Format

The payload is YAML.

```yaml
schema_version: BRD_TO_PRD_HANDOFF_V1
handoff_id: <HANDOFF_ID>
handoff_at: <ISO_8601_TIMESTAMP>
brd:
  id: <BRD_ID>
  version: <BRD_VERSION>
  title: <BRD_TITLE>
  artifact_path: <BRD_ARTIFACT_PATH>
  artifact_sha256: <BRD_ARTIFACT_SHA256>
signoff:
  status: <SIGNOFF_STATUS>
  approvers:
    - name: <APPROVER_NAME>
      role: <APPROVER_ROLE>
      decision: <APPROVER_DECISION>
      decided_at: <ISO_8601_TIMESTAMP>
      comments: <APPROVER_COMMENTS>
  waivers:
    - id: <WAIVER_ID>
      summary: <WAIVER_SUMMARY>
      granted_by: <WAIVER_GRANTOR>
      expires_at: <ISO_8601_DATE>
quality_report:
  report_ref: <QUALITY_REPORT_PATH>
  overall_status: <REPORT_OVERALL_STATUS>
  govern_exit_decision: <REPORT_GOVERN_DECISION>
counts:
  functional_requirements: <FR_COUNT>
  non_functional_requirements: <NFR_COUNT>
  business_rules: <BR_COUNT>
  constraints: <CONSTRAINT_COUNT>
  acceptance_criteria: <AC_COUNT>
  business_goals: <BG_COUNT>
traceability:
  matrix_ref: <TRACEABILITY_MATRIX_PATH>
  fr_to_ac_coverage_pct: <COVERAGE_PCT>
  fr_to_bg_coverage_pct: <COVERAGE_PCT>
business_goals:
  - id: <BUSINESS_GOAL_ID>
    statement: <BUSINESS_GOAL_STATEMENT>
    priority: <BUSINESS_GOAL_PRIORITY>
    kpi: <BUSINESS_GOAL_KPI>
    smart_status: <SMART_PASS_FAIL>
partitions:
  - id: <PARTITION_ID>
    title: <PARTITION_TITLE>
    summary: <PARTITION_SUMMARY>
known_open_items:
  - id: <OPEN_ITEM_ID>
    summary: <OPEN_ITEM_SUMMARY>
    rationale_for_deferral: <DEFERRAL_RATIONALE>
    target_phase: <TARGET_PHASE>
prd_consumer_notes: <CONSUMER_NOTES>
```

## Field definitions

### Top-level metadata

* `schema_version` (string, required) — MUST be `BRD_TO_PRD_HANDOFF_V1`.
* `handoff_id` (string, required) — Unique identifier for this handoff event. Recommended form: `<brd_id>-handoff-<ISO_8601_basic_timestamp>`.
* `handoff_at` (string, required) — ISO 8601 timestamp (UTC) when the handoff payload was produced.

### `brd` (object, required)

* `id` (string, required) — Stable BRD identifier (for example `BRD-2026-018`).
* `version` (string, required) — Signed-off BRD version. MUST be `≥ 1.0.0`. Drafts (`0.x.y`) are not eligible for handoff.
* `title` (string, required) — Human-readable BRD title.
* `artifact_path` (string, required) — Workspace-relative path to the BRD artifact at signoff.
* `artifact_sha256` (string, required) — Lowercase hex SHA-256 of the BRD artifact bytes at signoff. Allows the PRD Builder to detect post-handoff drift.

### `signoff` (object, required)

* `status` (string, required) — One of:
  * `SIGNED_OFF` — All required approvers approved; no blocking waivers.
  * `WAIVED` — Signed off with one or more documented waivers (see `waivers`).
  * `CONDITIONAL` — Signed off pending follow-up actions captured in `known_open_items`.
* `approvers` (array, required, length ≥ 1) — One entry per stakeholder asked to approve.
  * `name` (string, required) — Display name or stable identifier.
  * `role` (string, required) — Role at signoff (for example `Business Sponsor`, `Engineering Lead`, `Compliance Officer`).
  * `decision` (string, required) — One of `APPROVED`, `APPROVED_WITH_COMMENTS`, `REJECTED`. `REJECTED` is forbidden when `signoff.status` is `SIGNED_OFF` or `WAIVED`.
  * `decided_at` (string, required) — ISO 8601 timestamp.
  * `comments` (string, optional) — Approver commentary.
* `waivers` (array, optional) — Zero or more waiver records. Required to be present and non-empty when `signoff.status` is `WAIVED`.
  * `id` (string, required) — Unique within the payload.
  * `summary` (string, required) — One-sentence description of what is waived.
  * `granted_by` (string, required) — Authority who granted the waiver.
  * `expires_at` (string, optional) — ISO 8601 date when the waiver lapses.

### `quality_report` (object, required)

* `report_ref` (string, required) — Workspace-relative path to the `BRD_QUALITY_REPORT_V1` payload that backed the Govern decision.
* `overall_status` (string, required) — Mirrors the referenced report's `overall_status` (`PASS`, `NEEDS_REVIEW`, or `FAIL`).
* `govern_exit_decision` (string, required) — Mirrors the referenced report's `gate_decisions.govern_exit` (`APPROVED`, `APPROVED_WITH_COMMENTS`, `BLOCKED`, `NOT_EVALUATED`). MUST NOT be `BLOCKED` or `NOT_EVALUATED` (otherwise the handoff is not authorized).

### `counts` (object, required)

Integer counts of artifacts in the BRD at signoff. Each value MUST be ≥ 0.

* `functional_requirements` (integer, required).
* `non_functional_requirements` (integer, required).
* `business_rules` (integer, required).
* `constraints` (integer, required).
* `acceptance_criteria` (integer, required).
* `business_goals` (integer, required, ≥ 1).

### `traceability` (object, required)

* `matrix_ref` (string, required) — Workspace-relative path to the traceability matrix (Markdown or CSV) covering BG ↔ FR ↔ AC linkage.
* `fr_to_ac_coverage_pct` (number, required, 0.0–100.0).
* `fr_to_bg_coverage_pct` (number, required, 0.0–100.0). Target is `100.0%`; any gap requires an active waiver under `signoff.waivers[]`.

### `business_goals` (array, required, length ≥ 1)

* `id` (string, required) — Business goal identifier (for example `BG-001`).
* `statement` (string, required) — Verbatim business-goal statement.
* `priority` (string, required) — One of `MUST`, `SHOULD`, `COULD`, `WONT`. MoSCoW labels per the `prioritization-schemes` skill.
* `kpi` (string, required) — The KPI used to evidence the goal at outcome time. Free text.
* `smart_status` (string, required) — `PASS` or `FAIL`. MUST be `PASS` when `signoff.status` is `SIGNED_OFF`; MAY be `FAIL` only when waived under `signoff.status: WAIVED`.

### `partitions` (array, required when the BRD is partitioned; otherwise optional)

* `id` (string, required) — Partition identifier.
* `title` (string, required) — Human-readable partition title.
* `summary` (string, required) — One- to three-sentence scope description.

### `known_open_items` (array, required)

Zero or more items the BRD knowingly defers to downstream phases. Empty array is permitted.

* `id` (string, required) — Unique within the payload.
* `summary` (string, required) — What was deferred.
* `rationale_for_deferral` (string, required) — Why it was deferred from the BRD.
* `target_phase` (string, required) — One of `PRD`, `Implementation`, `Operations`, `Future-Release`.

### `prd_consumer_notes` (string, optional)

Free-form orchestrator notes intended for the PRD Builder (for example "treat partition `claims-intake` as the seed scope; partition `appeals` is sequenced for Q3").

## Validation rules

1. `schema_version` MUST equal `BRD_TO_PRD_HANDOFF_V1`.
2. `brd.version` MUST start with `1.` or a higher major version; draft `0.x.y` versions are rejected.
3. `brd.artifact_sha256` MUST be 64 lowercase hex characters.
4. `quality_report.govern_exit_decision` MUST be `APPROVED` or `APPROVED_WITH_COMMENTS`.
5. `signoff.approvers` MUST have length ≥ 1, and every entry's `decision` MUST be `APPROVED` or `APPROVED_WITH_COMMENTS`.
6. When `signoff.status` is `WAIVED`, `signoff.waivers` MUST be present and have length ≥ 1.
7. `counts.business_goals` MUST equal the length of `business_goals`.
8. `traceability.fr_to_ac_coverage_pct` MUST be ≥ 80.0 unless an active waiver in `signoff.waivers` covers FR↔AC gap.
9. `traceability.fr_to_bg_coverage_pct` MUST equal `100.0` unless an active waiver in `signoff.waivers` covers the FR-to-BG gap.
10. Every `business_goals[].smart_status` MUST be `PASS` when `signoff.status` is `SIGNED_OFF`.
11. Every `known_open_items[].id` MUST be unique within the payload.
12. Every `waivers[].id` MUST be unique within the payload.

## Example payload

```yaml
schema_version: BRD_TO_PRD_HANDOFF_V1
handoff_id: BRD-2026-018-handoff-20260512T093015Z
handoff_at: "2026-05-12T09:30:15Z"
brd:
  id: BRD-2026-018
  version: 1.0.0
  title: Claims Intake Modernization
  artifact_path: docs/brds/2026/brd-claims-intake.md
  artifact_sha256: 9b74c9897bac770ffc029102a200c5de1f3a4d9f0ea2c95c3b56a17e1d5fa1c4
signoff:
  status: SIGNED_OFF
  approvers:
    - name: Priya Subramanian
      role: Business Sponsor
      decision: APPROVED
      decided_at: "2026-05-12T08:45:00Z"
      comments: Confident in the prioritization; tracking BG-004 timeline closely.
    - name: Marcus Lee
      role: Engineering Lead
      decision: APPROVED_WITH_COMMENTS
      decided_at: "2026-05-12T09:05:00Z"
      comments: Coverage gap on partition `appeals` is acceptable for v1 scope.
    - name: Dana Okafor
      role: Compliance Officer
      decision: APPROVED
      decided_at: "2026-05-12T09:18:00Z"
      comments: Audit logging NFR satisfies retention policy.
  waivers: []
quality_report:
  report_ref: docs/brds/2026/quality/BRD-2026-018-quality-final.yml
  overall_status: PASS
  govern_exit_decision: APPROVED_WITH_COMMENTS
counts:
  functional_requirements: 24
  non_functional_requirements: 11
  business_rules: 6
  constraints: 3
  acceptance_criteria: 38
  business_goals: 4
traceability:
  matrix_ref: docs/brds/2026/trace/BRD-2026-018-trace.md
  fr_to_ac_coverage_pct: 95.8
  fr_to_bg_coverage_pct: 100.0
business_goals:
  - id: BG-001
    statement: Reduce average claim adjudication time by 30% within 12 months of launch.
    priority: MUST
    kpi: 30-day rolling average adjudication time (target ≤ 70% of baseline).
    smart_status: PASS
  - id: BG-002
    statement: Achieve a 4.4/5 customer satisfaction score for the claims experience within 12 months of launch.
    priority: MUST
    kpi: Post-claim CSAT survey rolling average (target ≥ 4.4/5).
    smart_status: PASS
  - id: BG-003
    statement: Reduce claims rework rate by 25% by end of fiscal year.
    priority: SHOULD
    kpi: Quarterly rework-rate report from operations.
    smart_status: PASS
  - id: BG-004
    statement: Comply with regional data residency requirements in all launch markets by general availability.
    priority: MUST
    kpi: Region-by-region residency audit attestation at GA.
    smart_status: PASS
partitions:
  - id: claims-intake
    title: Claims Intake Channel
    summary: Web and mobile intake forms, document upload, and triage routing into the adjudication queue.
  - id: appeals
    title: Appeals Workflow
    summary: Post-decision appeals capture and reviewer dashboard. Sequenced for v1.1.
known_open_items:
  - id: OPEN-1
    summary: Self-service status portal UX details.
    rationale_for_deferral: Stakeholder validation pending; not on the v1 critical path.
    target_phase: PRD
  - id: OPEN-2
    summary: Multi-currency support for cross-border claims.
    rationale_for_deferral: Out of scope for launch markets; flagged for future expansion.
    target_phase: Future-Release
prd_consumer_notes: Treat partition `claims-intake` as the seed scope for the PRD; partition `appeals` is intentionally deferred to v1.1 and should be re-scoped after launch metrics are collected.
```


