---
description: "Phase 4 gap comparison, adoption categorization, and effort sizing for Accessibility Planner — references framework skills as the comparison source."
applyTo: '**/.copilot-tracking/accessibility-plans/**'
---

# Accessibility Planner Phase 4 — Gap Analysis

Compare the project's current accessibility posture (Phase 2 surface assessment) against the desired state (Phase 3 standards mapping). Framework criteria and surface data are loaded from the skills under `.github/skills/accessibility/` per the consumer contract; this file does not encode framework-specific success criteria or criterion-to-implementation mappings inline.

Cross-reference [`#file:./accessibility-standards.instructions.md`](./accessibility-standards.instructions.md), [`#file:./accessibility-surface-assessment.instructions.md`](./accessibility-surface-assessment.instructions.md), and [`#file:./accessibility-risk-classification.instructions.md`](./accessibility-risk-classification.instructions.md) for the inputs consumed and the risk model applied here.

## Inputs

* `state.frameworks[]` — the registered framework references and their per-criterion YAML (loaded in Phase 3).
* `state.surfaceAssessment[]` — current posture per surface (loaded in Phase 2).
* `state.gates[]` — open gates with `status: pending`.

For every framework criterion referenced below, read the per-criterion `items/<id>.yml` from the source skill (`state.frameworks[i].skillPath`). Use the criterion's own `riskTier`, `evidenceHints`, and `mapsTo` fields to drive comparison and prioritization. Do not invent or paraphrase framework data.

## Gap Table Format

Produce a prioritized gap table sorted by `riskTier` descending, then by adoption status, then by effort:

| Gap           | Source Framework | Criterion ID   | Risk Tier          | Current State       | Target State | Status           | Effort        | Reference                       |
|---------------|------------------|----------------|--------------------|---------------------|--------------|------------------|---------------|---------------------------------|
| {description} | {framework_id}   | {criterion_id} | {from controlYAML} | {from surfaceEntry} | {target}     | {category below} | {XS/S/M/L/XL} | {evidenceHint or artifact path} |

Cite the source `items/<id>.yml` path for each row. Include any open `gates[]` whose `status` is `pending` after Phase 3. Evidence row formatting (path, line span, kind qualifiers) defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.

## Five Adoption Categories

Classify each gap into one of five status categories based on the evidence collected in Phase 2 against the criterion's expected state in Phase 3. The category describes the *current conformance state* of the surface against the criterion, not which remediation closes the gap.

1. **Conformant** — criterion fully met with evidence. No remediation required; record the supporting `evidenceHints` reference.
2. **Partial** — criterion partially met; identified gaps remain. Document which sub-requirements are met and which are outstanding.
3. **Non-conformant** — criterion not met; no evidence of conformance. Full remediation required.
4. **Not-applicable** — criterion does not apply to the surface. Must record `applicabilityRationale` justifying the exclusion (for example, no audio content, no input fields, surface excluded from declared scope).
5. **Pending** — assessment incomplete. Outstanding evidence collection, expert review, or assistive-technology testing required before status can be assigned.

Use the surface assessment entries' captured evidence and the criterion YAML's `evidenceHints[]` to determine which status applies. Do not maintain a hard-coded criterion-to-status table in this file.

## Effort Sizing

Assign T-shirt sizes per gap, accounting for accessibility-specific factors including design changes, content rewrites, ARIA refactors, and assistive-technology testing cycles:

| Size | Criteria                                                                                                | Typical Duration |
|------|---------------------------------------------------------------------------------------------------------|------------------|
| XS   | Single attribute, label, or contrast tweak with no design or copy change                                | < 0.5 day        |
| S    | Single component or page-level fix; copy or markup change with one assistive-tech smoke test            | < 1 day          |
| M    | Multiple components, ARIA refactor, or content rewrite across a small surface set                       | 1–3 days         |
| L    | Cross-cutting design-system change, broad ARIA reauthor, or full assistive-tech regression cycle        | 3–5 days         |
| XL   | New capability, design overhaul, structural rebuild, or multi-AT regression with end-user usability run | 1+ weeks         |

## Gap Prioritization

Derive priority per gap from three factors and sort the gap table accordingly:

1. **Severity of user impact** — `full-block` (criterion failure prevents task completion for affected users), `partial-block` (degrades but does not prevent completion), or `inconvenience` (friction without functional loss). Drawn from the criterion `riskTier` and the surface assessment evidence.
2. **Tier multiplier** — Tier 3 criteria (per [`#file:./accessibility-risk-classification.instructions.md`](./accessibility-risk-classification.instructions.md)) boost priority above lower tiers at the same impact level.
3. **Regulated-jurisdiction flag** — when EAA, Section 508, AODA, or any other regulated jurisdiction is active for the surface per [`#file:./accessibility-surface-assessment.instructions.md`](./accessibility-surface-assessment.instructions.md), boost priority for criteria that map to that jurisdiction.

Within the gap table, sort by:

1. Priority (derived above) — highest first.
2. Open gates before satisfied criteria.
3. Within the same priority — `Non-conformant` before `Partial` before `Pending` before `Conformant` before `Not-applicable`.
4. Within the same status — lower effort before higher effort.

## Output

Write the analysis to `.copilot-tracking/accessibility-plans/{project-slug}/gap-analysis.md`.

Structure as:

```markdown
# Gap Analysis — {project-slug}

## Summary
- Total gaps: {count}
- By risk tier: critical {n} | high {n} | medium {n} | low {n} | info {n}
- By status: conformant {n} | partial {n} | non-conformant {n} | not-applicable {n} | pending {n}

## Gap Table
{prioritized gap table with source skill citations}

## Adoption Recommendations
{per-status recommendations citing the source framework skill and surface assessment skill}
```

Update `state.json`:

* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Update `gates[]` entries whose status changed (still `pending`, now `failed`, or now `passed` based on user-confirmed evidence).
* Populate `state.gapAnalysis[]` with one entry per gap using the shape:

```json
{
  "frameworkId": "{framework_id}",
  "controlId": "{criterion_id}",
  "status": "conformant | partial | non-conformant | not-applicable | pending",
  "gapDescription": "{short description; required unless status is conformant}",
  "effortSize": "XS | S | M | L | XL",
  "priority": "critical | high | medium | low | info",
  "dependencies": ["{frameworkId}:{controlId}", "..."],
  "applicabilityRationale": "{required when status is not-applicable; otherwise omit}"
}
```

* Set `phase` to `backlog-generation` once gap analysis is complete and user-confirmed.
