---
name: rpi-plan
description: Create implementation-ready planning artifacts and validation evidence for RPI tasks.
argument-hint: "[research=...] [chat]"
license: MIT
user-invocable: true
---

# RPI Plan

Use [references/planning.md](references/planning.md) for the planning template and protocol detail.

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Convert validated research into an implementation-ready plan, supporting details, and a dated planning log with explicit validation evidence.

Derive `{{task_slug}}` from the primary task or target with lower-kebab-case, and use the current date in `YYYY-MM-DD` for the dated folders and files.

## What to do

1. Confirm the task scope and the current research state. Prefer a completed `/rpi-research` artifact when available.
2. Follow the four phases in order: Context Assessment, Planning, Plan Validation, Completion.
3. If research is missing or incomplete, create or extend `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`. When deeper gaps remain, prefer the Researcher Subagent at `.github/agents/hve-core/subagents/researcher-subagent.agent.md` via `runSubagent` or `task`, writing subagent evidence under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`.
4. Create or update the dated planning artifacts for this phase:
   * `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.instructions.md`
   * `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md`
   * `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md`
   * `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
   Derive `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` as the downstream implementation handoff path, but do not create or update it during planning.
5. Add `<!-- markdownlint-disable-file -->` to generated `.copilot-tracking/**` markdown artifacts. The implementation plan also includes `applyTo: '.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md'` frontmatter.
6. Prefer the Plan Validator at `.github/agents/hve-core/subagents/plan-validator.agent.md` via `runSubagent` or `task`, providing the research path, plan path, details path, planning log path, and a concise user-requirements summary. If neither dispatch tool is available, perform the equivalent validation inline and record the findings in the Planning Log Validator Findings section instead of dead-stopping on tooling alone.
7. Fix Critical and High findings in the planning artifacts, update the Planning Log Discrepancy Log and Validator Findings section, and rerun validation until only non-blocking findings remain.
8. Re-enter dated artifacts in place, keep completed work, refresh line references, and rerun validation after material edits.
9. Complete the run by summarizing the implementation plan artifacts created and any scope items deferred for future planning, drawing the deferred items from the planning log.

## Success criteria

* The dated planning artifact set exists under `.copilot-tracking/plans/`, `.copilot-tracking/details/`, `.copilot-tracking/plans/logs/`, and `.copilot-tracking/research/`.
* The Plan Validator result is captured and any Critical and High findings are resolved before handoff.
* The plan includes a final validation phase for full project validation and fix iteration.
* The completion summary names the implementation plan files created and any scope items deferred for future planning.
* For normal progression, the completion summary may include an implementation handoff to `/rpi-implement` and the dated artifact set for the next phase.
* For planning-only, comparison, audit, analysis, or explicitly no-handoff invocations, return validated planning artifacts and next-step guidance without presenting `/rpi-implement` as an immediate handoff.

## Constraints

* Do not implement code in this phase.
* Write only to `.copilot-tracking/plans/`, `.copilot-tracking/plans/logs/`, `.copilot-tracking/details/`, and `.copilot-tracking/research/` in this phase, except for workflow tracking files explicitly required by the current execution.
* Keep the output evidence-oriented; use subagents for research and validation instead of repeating planning logic in the skill.

## Stop rules

* Stop if the research artifact is missing or incomplete and deeper research is not available.
* Stop only for genuine blockers, such as missing task context, an unwritable research path, or unresolved validation findings that materially affect implementation readiness.
* Stop if the Plan Validator reports Critical and High findings that must be resolved before implementation.

## Handoff

After the plan is validated, continue with `/rpi-implement` only when the caller expects normal progression.

* Return the plan file path, details file path, planning log path, validation status, and next implementation steps.
* When the request is planning-only, comparison, audit, analysis, or explicitly no-handoff, return the validated planning artifacts and next-step guidance without presenting `/rpi-implement` as an immediate handoff.
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.instructions.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-details.md`
* `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/{{task_slug}}-log.md`
* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`


