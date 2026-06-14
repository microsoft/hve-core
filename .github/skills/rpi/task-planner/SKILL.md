---
name: task-planner
description: Planning-only RPI playbook that turns research into a concrete plan, details notes, and planning log, then validates the plan before implementation. Use when the user needs scope, sequencing, and validation evidence.
license: MIT
user-invocable: true
---

# Task Planner

Use [references/planning.md](references/planning.md) for the compact planning template and deeper protocol detail.

## Goal

Convert validated research into an implementation-ready plan, supporting details, and a dated planning log with explicit validation evidence.

## What to do

1. Confirm the task scope and the current research state. Prefer a completed `/task-researcher` artifact when available.
2. If research is missing or incomplete, create or extend lightweight research at `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`. When deeper gaps remain, dispatch the existing Researcher Subagent with `runSubagent` or `task` to `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`.
3. Create or update the dated planning artifacts for this phase:
   * `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`
   * `.copilot-tracking/details/{{YYYY-MM-DD}}/<task>-details.md`
   * `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`
   * `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`
   Derive `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md` as the downstream implementation handoff path, but do not create or update it during planning.
4. Add `<!-- markdownlint-disable-file -->` to generated `.copilot-tracking/**` markdown artifacts. The implementation plan also includes `applyTo: '.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md'` frontmatter.
5. Dispatch the existing Plan Validator with the research path, plan path, details path, planning log path, and a concise user-requirements summary when `runSubagent` or `task` is available.
6. If neither `runSubagent` nor `task` is available for required research or validation, stop and tell the user that subagent dispatch must be enabled before planning can be completed.
7. Fix critical and major findings in the planning artifacts, respect that the validator updates only the Planning Log Discrepancy Log, and re-run validation until only non-blocking minor findings remain.
8. Resume existing dated artifacts by updating them in place, preserving completed work, refreshing line references, and re-running validation after material edits.

## Success criteria

* The dated planning artifact set exists under `.copilot-tracking/plans/`, `.copilot-tracking/details/`, `.copilot-tracking/plans/logs/`, and `.copilot-tracking/research/`.
* The validator result is captured and any critical or major findings are resolved before handoff.
* The plan includes a final validation phase for full project validation and fix iteration.
* The implementation handoff names `/task-implementor` and the dated artifact set for the next phase.

## Constraints

* Do not implement code in this phase.
* Write only to `.copilot-tracking/plans/`, `.copilot-tracking/plans/logs/`, `.copilot-tracking/details/`, and `.copilot-tracking/research/` in this phase, except for workflow tracking files explicitly required by the current execution.
* Keep the output evidence-oriented and compact; use existing subagents instead of duplicating plan logic in the skill.

## Stop rules

* Stop if the research artifact is missing or incomplete and deeper research is not available.
* Stop if `runSubagent` or `task` is unavailable when research or validation dispatch is required.
* Stop if the Plan Validator reports critical or major findings that must be resolved before implementation.

## Handoff

After the plan is validated, continue with `/task-implementor` and hand off the dated artifact set. `/task-implement` remains the legacy prompt alias; use `/task-implementor` for the skill-forward flow.

* `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/<task>-details.md`
* `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`
* `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`

> Brought to you by microsoft/hve-core
