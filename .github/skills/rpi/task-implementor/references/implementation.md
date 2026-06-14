---
description: "Deeper implementation protocol and tracking templates for the task-implementor RPI skill"
---

# Task Implementor Reference

Use this reference for the deeper implementation protocol that the compact skill entry point points to.

## Plan Discovery and Artifact Path Derivation

1. Discover the implementation plan from the user request, attached files, the current open file, or the most recent `.copilot-tracking/plans/**/<task>-plan.instructions.md`.
2. Derive the dated task path from the plan file path:
   * plan: `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`
   * details: `.copilot-tracking/details/{{YYYY-MM-DD}}/<task>-details.md`
   * research: `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`
   * planning log: `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`
   * changes log: `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`
3. Verify the plan and details exist before phase execution. Read research and the planning log when available.
4. Create or update the changes log immediately when the implementation begins; begin the file with `<!-- markdownlint-disable-file -->`.

## Phase Implementor Input / Output Contract

Before dispatch, catalog each phase with:

* phase identifier and title;
* details file line ranges for the phase;
* dependencies on prior phases or shared files;
* validation commands for the phase;
* parallelization eligibility from the plan.

Dispatch independent phases in parallel only when the plan marks them parallelizable and no incomplete dependency, shared state mutation, or shared validation scope would cause conflicts.

When dispatching `Phase Implementor` with `runSubagent` or `task`, provide:

* phase identifier and step list from the plan;
* plan path and details path with exact line ranges;
* research path when available;
* relevant instruction files and convention references;
* related context files or docs pointers;
* validation commands extracted from the plan or relevant `npm run` scripts.

Expect a completion report with:

* status: Complete, Partial, or Blocked;
* executive details;
* steps completed and not completed;
* files changed;
* issues, suggested additional steps, validation results, and clarifying questions.

## Researcher Subagent Fallback Contract

Use `runSubagent` or `task` when the plan is ambiguous, the phase requires missing context, or Phase Implementor returns clarifying questions.

Write the output to `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md` when the parent needs a deeper research artifact. Stop and ask the user only when the research cannot resolve the question or subagent dispatch is unavailable.

## RPI Validator Input / Output Contract

Run RPI Validator when:

* the plan explicitly requires validation;
* a phase report includes blockers or deviations;
* plan-to-change coverage is uncertain before review handoff;
* the user asks for validation.

Provide:

* plan path;
* changes log path;
* research path when available;
* phase number; and
* validation output path `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-<phase>-validation.md`.

Treat the result as Pass only when no open Critical or High findings remain.

## Changes-Log Template

Use [../templates/changes-log.md](../templates/changes-log.md) for `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`.

## Planning-Log Template

Use [../templates/planning-log.md](../templates/planning-log.md) for `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`.

## Progressive Tracking Rules

* Mark completed implementation plan steps as `[x]` as they finish.
* Append changes-log entries after each completed phase or significant step.
* Update the planning log with discrepancies, follow-on work, and user decisions as they appear.
* Evaluate suggested additional steps before adding them to the plan or details files.

## Resumption and Review Handoff

When resuming, read the existing changes log and plan, preserve completed work, and continue from the next unchecked phase. Hand off review work with `/task-reviewer`.

## Telemetry, Commit Messages, and Review Compatibility

* If implementation touches observable production behavior, apply the telemetry overlay in `.github/instructions/hve-core/task-implementor-telemetry.instructions.md` and consult the `telemetry-foundations` skill.
* When you output a commit message, follow `.github/instructions/hve-core/commit-message.instructions.md` and exclude `.copilot-tracking/` files from the commit scope.
* Keep the final handoff evidence-first and compact for `/task-reviewer`.
