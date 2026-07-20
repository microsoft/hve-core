---
description: "Deeper implementation protocol and tracking templates for the task-implementor RPI skill"
---

# Task Implementor Reference

Use this reference for the detailed implementation protocol, templates, and subagent contracts.

## Plan Discovery and Artifact Path Derivation

1. Discover the implementation plan using this priority order: (1) the explicit `plan` input when provided; (2) plan content in the currently open file; (3) a plan reference extracted from an open changes log; (4) the most recent `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`.
2. Derive the canonical task slug and phase tokens before execution:
   * `task_slug = lower-kebab-case(primary task/target)`
   * `task_date = YYYY-MM-DD` at execution time
   * `phase = <phase>` or `phase-<n>` consistently across all outputs
   * When the plan is provided as request text rather than as a file, derive `task_slug` from the plan title or the user request summary and derive `task_date` from the current execution date.
3. Derive the dated task path from the plan file path:
   * plan: `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task>-plan.instructions.md`
   * details: `.copilot-tracking/details/{{YYYY-MM-DD}}/<task>-details.md`
   * research: `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`
   * planning log: `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md`
   * changes log: `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`
4. Verify the plan and details exist before phase execution. Read research and the planning log when available.
5. Create or update the changes log immediately when the implementation begins, using the project or plan's required tracking-file header and metadata conventions.

## Phase 1 / 2 / 3 Execution Contract

1. Phase 1: Read the implementation plan, details, research, and current tracking files. Derive artifact paths from the plan filename and date, verify required files exist, and create the changes log when needed.
2. Phase 2: Prefer `Phase Implementor` for each phase in the plan order, using `runSubagent` or `task`. Use `Implementation Validator` when the phase plan includes `Validation:` or `required`, when blockers or deviations appear, or when the user asks for review evidence. Use `Researcher Subagent` as the fallback when context is missing. If dispatch tooling is unavailable, perform the equivalent work inline and record it.
3. Phase 3: Review the full plan, confirm every required phase is complete or explicitly blocked, verify validation evidence, and prepare the review handoff summary.
4. Bounded run rule: if the user asks for one phase only or one bounded step, stop after that phase or step, update the implementation plan checklist, the changes log, and the planning log, capture validation evidence when available, and hand off the current status with blockers or follow-on work and the next review command only. Do not require all phases to be complete before a bounded handoff.

## Pause and resumption contract

1. When `phaseStop` is true, pause after each completed phase and present progress before continuing.
2. When `stepStop` is true, pause after each completed step within a phase and present progress before continuing.
3. When execution pauses or stops, summarize completed phases and steps, blockers or clarification requests, and the next resumption point.

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
* validation, linting, and testing checks extracted from the plan or target project's local tooling.

Expect a completion report with:

* status: Complete, Partial, or Blocked;
* executive details;
* steps completed and not completed;
* files changed;
* issues, suggested additional steps, validation results, and clarifying questions.

Use the completion report to update the implementation plan checklist, the changes log, and the planning log before starting the next phase.

## Researcher Subagent Fallback Contract

Use `runSubagent` or `task` when the plan is ambiguous, the phase requires missing context, or Phase Implementor returns clarifying questions.

Provide:

* the research question or topic;
* the target research artifact path `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`;
* the related plan, details, or implementation files needed to ground the search.

Return:

* the research artifact path;
* the current status;
* important findings;
* recommended next research items;
* clarifying questions when the answer is incomplete.

Stop and ask the user only when the research cannot resolve the blocker or subagent dispatch is unavailable.

## Implementation Validator Input / Output Contract

Run `Implementation Validator` when:

* the phase plan includes a `Validation:` command or the word `required`;
* a phase report includes blockers or deviations;
* plan-to-change coverage is uncertain before review handoff;
* the user asks for validation.

Do not dispatch `Implementation Validator` when validation is explicitly optional and the current phase has no blockers, deviations, or review evidence to confirm.

Provide:

* plan path;
* changes log path;
* research path when available;
* the phase number to validate; and
* the validation output path `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-<phase>-validation.md`.

Treat the result as Pass only when no open Critical or High findings remain.

## Changes-Log Template

Use [../templates/changes-log.md](../templates/changes-log.md) for `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md`.

## Planning Log Updates

Update the planning log at `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task>-log.md` when discrepancies, follow-on work, or user decisions appear. Keep the current planning-log structure unchanged and record the source phase and step for each follow-on item.

## Dependency and Iteration Rules

* Defer dependent phases when an upstream phase is incomplete or blocked.
* Revisit blocked phases after the blocker is resolved or after the user provides clarification.
* Stop and ask the user when the blocker affects scope, validation, or required approvals.
* Use the completion report to decide whether to continue, add follow-on work, or return to Phase 1 for a new plan section.

## Progressive Tracking Rules

* Update the implementation plan checklist after each completed phase or bounded step, marking completed steps as `[x]` as they finish.
* Append changes-log entries after each completed phase or significant step.
* Update the planning log with discrepancies, follow-on work, and user decisions as they appear.
* Evaluate suggested additional steps before adding them to the plan or details files.

## Resumption and Review Handoff

When resuming work, read the current changes log and plan, continue from the next unchecked phase, and name `/rpi-review` as the next review command in the handoff.

## Final Response and Review Handoff Contract

Present the completion summary in this order:

* phase execution results with files changed and validation status;
* additional work items added to the planning files;
* suggested follow-on work from the planning log;
* blockers or clarifying questions that require user input;
* the next review command and the links to the changes log and planning log.

Use the changes log and planning log as the evidence base for the review handoff.

## Code Comments and Documentation References

* Follow the exact file paths, schemas, and instruction documents cited in the plan, details, and research references for implementation logic; produced code comments must not reference those internal artifacts.
* Keep code comments and documentation strings self-contained; they may cite public materials such as RFCs, published specifications, official documentation, or open-source library docs with appropriate citations.
* Code comments may reference code or documentation in this codebase or related codebases when the reference is durable and accessible to future maintainers.
* Do not include internal planning, research, or implementation artifact references, including `.copilot-tracking/` paths, in code comments, production code, or documentation strings. This rule governs produced and shipped code and documentation; it does not apply to `.copilot-tracking/` tracking artifacts or the review handoff, which reference those paths by design.

## Telemetry, Commit Messages, and Review Compatibility

* If implementation touches observable production behavior, follow the target project's telemetry guidance and consult the `telemetry-foundations` skill when available.
* When you output a commit message, follow the target project's commit-message conventions and exclude internal tracking files from the commit scope.
* Keep the final handoff evidence-first and brief for `/rpi-review`.
