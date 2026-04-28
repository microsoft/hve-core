---
description: 'RAI security model analysis for Phase 4: dual threat IDs, threat-table assembly, and security model merge protocol - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Security Model Analysis

AI-specific security model analysis for Phase 4 of the RAI Planner. The threat catalog (STRIDE extensions, element types, trust boundaries, data-flow patterns, ML STRIDE matrix, and bucket concentration estimates) is provided by Framework Skills loaded earlier. This contract defines the planner mechanics: dual threat ID convention, threat-table assembly, audience and detail-level adaptation, and merge protocol for `from-security-plan` mode.

## Source-of-Truth Resolution

Threat-catalog content is not inlined here. Read it from the Framework Skills enumerated in `state.frameworks[]`:

* **STRIDE extensions, element types, trust boundaries, data-flow patterns, ML STRIDE matrix, bucket concentration estimates** — the `rai-threat-catalog` skill (default) or any framework skill that exposes items with `itemKind` of `stride-extension`, `element`, `trust-boundary`, `data-flow`, `stride-matrix`, or `bucket-concentration`. Aggregate matrices and data-flow patterns may also appear under the skill index `globals` (for example `globals.strideMatrix`, `globals.dataFlows`); when present, use the `globals` payload as the authoritative aggregate.
* **Threat-table output formats and addendum/catalog templates** — the `rai-output-formats` skill. Phase 4 artifacts render from `itemKind: output-format` items keyed by `phase-4-security-model`.

Record every consulted skill in `state.skillsLoaded[]` and every emitted artifact in `state.referencesProcessed[]` with `skillId` and `skillVersion`.

## Dual Threat ID Convention

RAI security model analysis uses a dual ID system that enables independent tracking within the RAI plan and cross-referencing with Security Planner operational buckets.

### ID Formats

* `T-RAI-{NNN}`: Sequential RAI-specific threat identifier starting at `T-RAI-001`. Every RAI threat receives this ID.
* `T-{BUCKET}-AI-{NNN}`: Cross-reference ID mapping to Security Planner bucket terminology. Assigned when a threat overlaps with a Security Planner operational bucket.

### Rules

1. All RAI threats receive a `T-RAI-{NNN}` ID in sequential order.
2. When a threat overlaps with a Security Planner bucket, also assign a `T-{BUCKET}-AI-{NNN}` ID.
3. Cross-reference both IDs in threat tables so each threat is traceable across both plans.
4. Bucket names match Security Planner operational buckets supplied by the active capability inventory or default to: DATA, BUILD, WEBUI, IDENTITY, INFRA.
5. The `T-RAI-{NNN}` sequence is independent of the `T-{BUCKET}-AI-{NNN}` sequence within each bucket.

### Example

A training data poisoning threat might carry:

* RAI ID: `T-RAI-003`
* Security cross-reference: `T-DATA-AI-001`

Both IDs appear in the extended threat table, linking the RAI assessment to the security plan's data bucket analysis.

## Threat Table Assembly

Phase 4 produces an extended threat table whose schema is defined by the active `rai-output-formats` skill (Phase 4 output-format item). The planner is responsible for populating each row with content drawn from the loaded threat catalog and session evidence. Evidence row formatting for every threat-row citation defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.

### Required Per-Row Inputs

For each identified threat, populate at minimum:

* `T-RAI-{NNN}` ID and, when applicable, the `T-{BUCKET}-AI-{NNN}` cross-reference ID.
* STRIDE category, sourced from a `stride-extension` item in the active threat-catalog skill.
* NIST characteristic (or equivalent characteristic id surfaced by the active control-surface skill).
* AI element, sourced from an `element` item in the active threat-catalog skill.
* Trust boundary, sourced from a `trust-boundary` item in the active threat-catalog skill.
* Data-flow stage, sourced from a `data-flow` item in the active threat-catalog skill (when threat concentrates at an identifiable stage).
* Suggested threat origin: Data Pipeline, Model, Interface, Infrastructure, or Cross-cutting.
* Concern Level (see below).
* Mitigation, drawn from the active control-surface skill or session evidence.

### Concern Level Assessment

Suggest a qualitative concern level for each identified threat based on contextual judgment:

| Concern Level    | Criteria                                                                                |
|------------------|-----------------------------------------------------------------------------------------|
| Low Concern      | Threat is theoretical or mitigated by existing controls; no immediate action suggested. |
| Moderate Concern | Threat is plausible and partially mitigated; additional controls recommended.           |
| High Concern     | Threat is likely or unmitigated; priority mitigation suggested.                         |

The concern level is a suggested assessment for the team's consideration, not a definitive risk rating.

### Threat Origin Grouping

After populating the threat table, present a summary grouped by Suggested Threat Origin. This helps the team identify which system components carry the most threats and prioritize architectural mitigations. Present AI-specific threats (Data Pipeline, Model) first, then Interface threats, then Infrastructure and Cross-cutting threats.

### Coverage Validation

When the active threat-catalog skill exposes a `bucket-concentration` item or `globals.bucketConcentration` aggregate, compare actual per-bucket threat counts against the expected baseline. When the actual count is significantly lower than expected for a bucket, surface the discrepancy to the user and revisit the bucket for analysis gaps before exiting Phase 4.

### Output Detail Level

Adjust threat-table column visibility based on `userPreferences.outputDetailLevel`:

| Level         | Visible Columns                                                                                                                           |
|---------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| summary       | RAI ID, STRIDE, Concern Level, Suggested Threat Origin.                                                                                   |
| standard      | All columns (default).                                                                                                                    |
| comprehensive | All columns plus a "Detailed Rationale" column with per-threat analysis explaining the concern level assignment and mitigation reasoning. |

### Audience Adaptation

Adjust ML STRIDE matrix presentation based on `userPreferences.audienceProfile`:

| Profile   | Presentation                                                                                    |
|-----------|-------------------------------------------------------------------------------------------------|
| technical | Include the full ML STRIDE matrix from the active threat-catalog skill.                         |
| executive | Summarize ML-specific threats in narrative prose; omit the matrix.                              |
| mixed     | Include the matrix with regulatory cross-references and contextual notes for diverse audiences. |

## Merge Protocol

When a Security Planner assessment already exists (`from-security-plan` entry mode), the merge protocol prevents duplication and ensures consistent cross-referencing between security and RAI security models.

### Steps

1. Read the existing security plan security model from the path in `state.json` `securityPlanRef`.
2. Extract the highest `T-{BUCKET}-AI-{NNN}` ID for each bucket to establish cross-reference continuity.
3. Start new RAI threat IDs at `T-RAI-001` (independent sequence from the security plan).
4. For overlapping threats (threats already identified in the security plan that also have RAI dimensions), cross-reference using dual IDs rather than duplicating the threat entry.
5. Produce an addendum document whose template is supplied by the active `rai-output-formats` skill (Phase 4 addendum output-format item) with a merge header identifying the source security plan.
6. Use the extended threat-table format with both ID columns to maintain traceability.
7. Include a cross-reference section listing security `T-{BUCKET}-AI-{NNN}` IDs and their RAI `T-RAI-{NNN}` counterparts.

### Addendum Header Fields

The addendum header (rendered by the active output-format item) includes at minimum:

* Source security plan path.
* Security plan date.
* Highest existing security threat ID.
* RAI threat ID range (`T-RAI-001` through `T-RAI-{NNN}`).

## Artifact Emission

Phase 4 emits the RAI threat addendum and any companion artifacts (cross-reference section, threat-concentration summary). Render each artifact from the corresponding `itemKind: output-format` item in `rai-output-formats` keyed by `phase-4-security-model`. Do not inline templates in this contract — when the active output-formats skill is missing or does not provide a Phase 4 template, halt and surface the gap to the user before writing files.

Each emitted artifact records its source skill id and version in `state.referencesProcessed[]`.
