---
description: "Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner — references framework skills as the comparison source."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 4 — Gap Analysis

Compare the repository's current supply chain security posture (Phase 2 capability inventory) against the desired state (Phase 3 standards mapping). Framework controls and capability data are loaded from the skills under `.github/skills/security/` per the consumer contract; this file does not encode framework-specific check lists or check-to-implementation mappings inline.

## Inputs

* `state.frameworks[]` — the registered framework references and their per-control YAML (loaded in Phase 3).
* `state.capabilityInventory[]` — current posture per capability (loaded in Phase 2).
* `state.gates[]` — open gates with `status: pending`.

For every framework control referenced below, read the per-control `items/<id>.yml` from the source skill (`state.frameworks[i].skillPath`). Use the control's own `riskTier`, `evidenceHints`, and `mapsTo` fields to drive comparison and prioritization. Do not invent or paraphrase framework data.

## Gap Table Format

Produce a prioritized gap table sorted by `riskTier` descending, then by adoption type, then by effort:

| Gap           | Source Framework | Control ID   | Risk Tier          | Current State          | Target State | Adoption Type    | Effort     | Reference                       |
|---------------|------------------|--------------|--------------------|------------------------|--------------|------------------|------------|---------------------------------|
| {description} | {framework_id}   | {control_id} | {from controlYAML} | {from capabilityEntry} | {target}     | {category below} | {S/M/L/XL} | {evidenceHint or workflow path} |

Cite the source `items/<id>.yml` path for each row. Include any open `gates[]` whose `status` is `pending` after Phase 3. Format the Reference cell as the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md); never emit a bare workflow path for `verified` or `partial` rows.

## Six Adoption Categories

Classify each gap into one of six adoption categories based on the required implementation effort. The category is independent of framework — it describes *how* the gap is closed, not which check it satisfies. Map specific controls to categories by inspecting the control's `mapsTo[]` and `evidenceHints[]` fields.

1. **Reusable Workflow Adoption** — target repo adds a workflow file that calls an existing `workflow_call` workflow from hve-core or physical-ai-toolchain. Lowest effort.
2. **Workflow Copy/Modify** — copy a workflow and adapt it to the target repository's stack. Medium effort.
3. **Reusable Workflow + Script Adoption** — adopt both a reusable workflow and its supporting PowerShell or Python scripts.
4. **Platform Configuration** — GitHub or Azure DevOps settings configured via web UI or API. Variable effort depending on org policy.
5. **New Capability** — build something not available in either reference repository. Highest effort.
6. **N/A / Organic** — not actionable as a backlog item; improves through normal project activity.

Use the capability inventory skills' `mapsTo[]` data to determine which adoption category applies to each control. Do not maintain a hard-coded check-to-category table in this file.

## Effort Sizing

Assign T-shirt sizes:

| Size | Criteria                                           | Typical Duration |
|------|----------------------------------------------------|------------------|
| S    | Single file addition or configuration change       | < 1 day          |
| M    | Multiple files or workflow customization required  | 1–3 days         |
| L    | Cross-cutting changes across CI/CD pipeline        | 3–5 days         |
| XL   | New capability build or major architectural change | 1+ weeks         |

## Gap Prioritization

Within the gap table, sort by:

1. `riskTier` (from the source control YAML) — highest first.
2. Open gates before satisfied controls.
3. Within the same risk tier — adoption category from lowest effort (Reusable Workflow Adoption) to highest (New Capability).
4. Within the same adoption type — lower effort before higher effort.

## Output

Write the analysis to `.copilot-tracking/sssc-plans/{project-slug}/gap-analysis.md`.

Structure as:

```markdown
# Gap Analysis — {project-slug}

## Summary
- Total gaps: {count}
- By risk tier: critical {n} | high {n} | medium {n} | low {n} | info {n}
- By adoption type: reusable {n} | copy/modify {n} | workflow+script {n} | platform {n} | new {n} | organic {n}

## Gap Table
{prioritized gap table with source skill citations}

## Adoption Recommendations
{per-category recommendations citing the source framework skill and capability inventory skill}
```

Update `state.json`:

* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Update `gates[]` entries whose status changed (still `pending`, now `failed`, or now `passed` based on user-confirmed evidence).
* Set `phase` to `backlog-generation` once gap analysis is complete and user-confirmed.
