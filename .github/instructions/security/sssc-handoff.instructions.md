---
description: "Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 6 — Review and Handoff

Validate the complete SSSC plan, generate improvement projections, and produce platform-specific handoff files for backlog managers.

Attach the SSSC Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every handoff artifact written by this phase.

Before writing handoff files, run `Validate-PlannerArtifacts.ps1 -Scope sssc -PlanRoot .copilot-tracking/sssc-plans/{project-slug}` to confirm the plan satisfies the schema and skill-loading contract. After writing, run `Sign-PlannerArtifacts.ps1 -Scope sssc -PlanRoot .copilot-tracking/sssc-plans/{project-slug}` to produce the artifact manifest.

## Handoff Protocol

1. Read `sssc-backlog.md` (the neutral work item list from Phase 5).
2. Validate completeness: every gap from Phase 4 has a corresponding work item.
3. Generate improvement projections (see below).
4. Render the [Excluded Frameworks and Controls](#excluded-frameworks-and-controls) audit appendix.
5. Present the complete plan to the user for final review.
6. On confirmation, generate platform-specific handoff files.
7. Update `state.json` handoff flags.

## Evidence Citation Format

Every file or endpoint reference emitted in the handoff audit appendices, Coverage Disclosure rows, and Scorecard projection notes follows the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md). Bare paths are not permitted in `verified` or `partial` contexts; use a `(Lines N-M)` span or an explicit `kind:` qualifier (`file-presence`, `live-endpoint`, `external-doc`).

## Excluded Frameworks and Controls

Render an audit appendix in `sssc-handoff.md` (and at the bottom of every platform-specific handoff file) summarizing every framework and control the user opted out of during the session. The data source is `state.json`:

* **Frameworks** — every entry in `state.frameworks[]` where `disabled === true`. Render `id`, `version`, `disabledReason`, and `disabledAtPhase`.
* **Controls** — every entry in `state.frameworks[<id>].suppressedControls[]` (across all frameworks, including frameworks that are otherwise enabled). Render the parent framework `id`, the control `id`, `reason`, and `suppressedAtPhase`.

Use this layout:

```markdown
## Excluded Frameworks and Controls

The following frameworks and controls were intentionally excluded from this assessment. Each exclusion is recorded with the user-supplied reason and the workflow phase at which it was applied.

### Disabled Frameworks

| Framework | Version | Reason | Excluded at Phase |
|-----------|---------|--------|-------------------|
| {id}      | {ver}   | {why}  | {phase}           |

### Suppressed Controls

| Framework | Control | Reason | Suppressed at Phase |
|-----------|---------|--------|---------------------|
| {fw-id}   | {ctrl}  | {why}  | {phase}             |
```

Omit either subsection when its source array is empty. When both arrays are empty, render the heading and a single line: `_No frameworks or controls were excluded from this assessment._`

## Coverage Disclosure

Render `state.controlTracker[]` as a table so reviewers can distinguish what was assessed from what was skipped. This section is always rendered (never collapsed):

```markdown
## Coverage Disclosure

The following table records every control referenced during this assessment. Controls with `mappedInPhase3 = false` were not read in Phase 3 standards-mapping and therefore have no gap-analysis evidence; their `suggestedStatus` reflects only structural defaults, not assessment.

| Framework | Control     | Mapped in Phase 3 | Suggested Status                                                  | Notes |
|-----------|-------------|-------------------|-------------------------------------------------------------------|-------|
| {fw-id}   | {controlId} | {true|false}      | {addressed|partial|not-addressed|deferred|not-applicable}         | {why} |
```

When `state.controlTracker[]` is empty, render a single line: `_No controls were tracked during this assessment._` and proceed.

## Scorecard Improvement Projection

For each of the 20 Scorecard checks, project the score improvement if all related work items are completed:

| #   | Check        | Risk   | Current Score | Projected Score | Work Items           |
|-----|--------------|--------|---------------|-----------------|----------------------|
| {n} | {check_name} | {risk} | {current}/10  | {projected}/10  | {WI-SSSC-{NNN}, ...} |

Include a summary row with the estimated overall Scorecard score improvement.

## SLSA Level Assessment

Project the SLSA Build level that the repository would achieve after completing all relevant work items:

* **Current level**: Build L{N}
* **Projected level**: Build L{N}
* **Remaining steps**: {list of what would still be needed}

## Best Practices Badge Readiness

Assess which Badge tier the repository would qualify for after completing all work items:

* **Current readiness**: {Passing|Silver|Gold|Not enrolled}
* **Projected readiness**: {Passing|Silver|Gold}
* **Missing criteria** (if any): {list}

## ADO Handoff

Write ADO-formatted work items to `.copilot-tracking/workitems/backlog/{project-slug}-sssc/work-items.md`.

Apply the ADO work item template from `sssc-backlog.instructions.md` with:

* HTML-formatted description fields
* `WI-SSSC-{NNN}` sequential IDs
* Type hierarchy: Epic → Feature → User Story → Task
* Tags: `supply-chain`, `ossf`, plus per-check and per-category tags
* Priority derived from Scorecard risk level

Set `state.json` field `handoffGenerated.ado` to `true` after writing.

## GitHub Handoff

Write GitHub-formatted issues to `.copilot-tracking/github-issues/discovery/{project-slug}-sssc/issues-plan.md`.

Apply the GitHub issue template from `sssc-backlog.instructions.md` with:

* YAML metadata blocks
* `{{SSSC-TEMP-N}}` temporary IDs
* Markdown-formatted body
* Labels: `supply-chain`, `ossf`, plus per-check and per-category labels
* Milestone assignment if one exists

Set `state.json` field `handoffGenerated.github` to `true` after writing.

## Handoff Summary

After generating handoff files, produce a summary covering:

* Total items by type and platform
* Items by Scorecard check
* Items by adoption category
* Items by risk level
* Estimated total effort (sum of T-shirt sizes)
* Cross-references to Security Planner and RAI Planner artifacts (if `securityPlannerLink` or `raiPlannerLink` is populated)

## Final State Update

Update `state.json`:

* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Update `handoffGenerated` flags for each platform written.
* Set `phase` to `complete` and clear `nextActions` (or populate with post-handoff recommendations).

Present the user with next steps:
* For ADO: invoke the ADO Backlog Manager to create work items from the handoff file
* For GitHub: invoke the GitHub Backlog Manager to create issues from the handoff file
* If cross-agent artifacts exist: note the links for continuity across security domains
