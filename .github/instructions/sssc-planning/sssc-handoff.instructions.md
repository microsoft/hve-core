---
description: "Phase 6 backlog handoff protocol with Scorecard projections and dual-format output for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 6 — Review and Handoff

Validate the complete SSSC plan, generate improvement projections, and produce platform-specific handoff files for backlog managers.

## Handoff Protocol

1. Read `sssc-backlog.md` (the neutral work item list from Phase 5).
2. Validate completeness: every gap from Phase 4 has a corresponding work item.
3. Generate improvement projections (see below).
4. Present the complete plan to the user for final review.
5. On confirmation, generate platform-specific handoff files.
6. Update `state.json` handoff flags.

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
* Set `phases.6-handoff.status` to `✅`
* Update `handoffGenerated` flags for each platform written
* Clear `nextActions` (or populate with post-handoff recommendations)

Present the user with next steps:
* For ADO: invoke the ADO Backlog Manager to create work items from the handoff file
* For GitHub: invoke the GitHub Backlog Manager to create issues from the handoff file
* If cross-agent artifacts exist: note the links for continuity across security domains
