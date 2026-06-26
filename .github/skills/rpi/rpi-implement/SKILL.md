---
name: rpi-implement
description: Execute approved implementation phases, update tracking artifacts, and hand off review-ready results.
argument-hint: "[plan=...] [phaseStop] [stepStop]"
license: MIT
user-invocable: true
---

# Task Implementor

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Execute an approved implementation plan with phase-by-phase tracking, validation evidence, and review-ready handoff.

## What to do

1. Discover the implementation plan by priority: use the explicit `plan` input when provided; otherwise inspect the currently open file for plan content, extract a plan reference from an open changes log, or select the most recent file in `.copilot-tracking/plans/`.
2. Discover the details, research, and current tracking files from `.copilot-tracking/plans/**`, `.copilot-tracking/details/**`, and `.copilot-tracking/changes/**`.
3. Prefer `Phase Implementor` via `runSubagent` or `task`; use `Implementation Validator` when the phase plan includes `Validation:` or `required`, when blockers or deviations appear, or when review evidence is requested. Use `Researcher Subagent` as the fallback for missing context.
4. If `runSubagent` or `task` is unavailable, perform the equivalent work inline and record the result; do not dead-stop solely because dispatch tooling is missing.
5. Derive the canonical task slug as `lower-kebab-case(primary task/target) + '-' + YYYY-MM-DD + '-' + <phase>`; when the plan is provided as request text rather than a file, derive the slug from the plan title or the user request summary and keep the same tokens.
6. When `phaseStop` is true, pause after each completed phase and present progress before continuing; when `stepStop` is true, pause after each completed step within a phase and present progress before continuing.
7. When execution pauses or stops, summarize completed phases and steps, blockers or clarification requests, and the next resumption point.
8. Continue from the next unchecked phase when work resumes, update the implementation plan checklist, changes log, and planning log after each completed phase or bounded step, and stop when dependencies or blockers require user clarification.
9. Return a brief status summary with the next review command and the tracked files.

## Inputs

* `plan` (optional): path to the approved implementation plan; when omitted, discover it using the priority order in step 1 of What to do.
* `phaseStop` (optional, default `false`): when `true`, pause after each completed phase and present progress before continuing.
* `stepStop` (optional, default `false`): when `true`, pause after each completed step within a phase and present progress before continuing.

## Success criteria

* The plan and details are available before implementation starts.
* The implementation plan is discovered using the priority order of explicit `plan` input, open file, open changes log, or the most recent plan under `.copilot-tracking/plans/`.
* The implementation plan checklist, changes log, and planning log are updated after each phase or bounded step and remain review-ready.
* Optional `phaseStop` and `stepStop` pause controls are honored, and pause summaries capture completed phases and steps, blockers or clarifications, and the next resumption point.
* `Phase Implementor`, `Researcher Subagent`, and `Implementation Validator` use `runSubagent` or `task` when available; if they are not available, the work is performed inline and recorded.
* Validation evidence is captured when the phase plan says `Validation:` or `required`, or when blockers, deviations, or review evidence are present.
* Planned validation, linting, and testing checks have completed before handoff, or skipped checks are recorded with the reason.
* The canonical task slug and phase tokens are applied consistently across the handoff and changes log.
* The next review command is `/rpi-review`.

## Constraints

* Do not expand scope beyond the approved phase.
* Use [references/implementation.md](references/implementation.md) for the detailed protocol, subagent contracts, dependency rules, and template guidance.
* Keep `.copilot-tracking/` paths and other internal planning, research, or implementation artifact references out of produced code, code comments, documentation strings, and commit messages; see [references/implementation.md](references/implementation.md) for the comment-reference rule.
* Stop when required artifacts or subagent dispatch are unavailable.

## Stop rules

* Stop if the plan or details file is missing or invalid.
* Stop if a genuine blocker prevents the current phase from proceeding, even when subagent dispatch is unavailable.
* For a bounded run such as one phase or one step, stop after that phase or step, update the changes log and planning log, capture validation evidence when available, and hand off the current status with blockers or follow-on work and the next review command; do not require all phases to complete before a bounded handoff.
* Stop if validation finds blocking Critical or High issues that must be resolved before review handoff.

## Handoff

* End with a brief bullet list of phase status, files changed, validation status, and the next review command.
* Name `/rpi-review` as the next review command when review evidence is requested.

> Brought to you by microsoft/hve-core
