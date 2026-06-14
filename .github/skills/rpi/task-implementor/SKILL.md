---
name: task-implementor
description: Implementation-only RPI playbook that applies the approved plan, updates .copilot-tracking/changes/, and dispatches validation when the phase is blocked or needs review. Use when the user needs bounded code changes.
license: MIT
user-invocable: true
---

# Task Implementor

Use [references/implementation.md](references/implementation.md) for the deeper implementation protocol, templates, and subagent contracts.

## Goal

Execute the approved implementation phase with dated tracking evidence, bounded subagent dispatch, and review-ready handoff behavior equivalent to the legacy implementor workflow.

## What to do

1. Discover the implementation plan from the user request, the current open file, or the most recent `.copilot-tracking/plans/**/<task>-plan.instructions.md`. Derive the task date and artifact paths from that plan path.
2. Verify the plan and details are present; read the research and planning log when available. Create or update `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task>-changes.md` and start it with `<!-- markdownlint-disable-file -->`.
3. Catalog phases from the plan with phase identifiers, details line ranges, dependencies, validation commands, and parallelization eligibility.
4. Use `runSubagent` or `task` to dispatch Phase Implementor for each bounded phase, and use Researcher Subagent when context is missing or clarification is needed. Dispatch independent phases in parallel only when the plan marks them parallelizable and dependencies allow it.
5. Update the implementation plan checklist, the changes log, and the planning log progressively as each phase completes; preserve existing work when resuming.
6. Run RPI Validator when the plan requires validation, a phase report reports blockers or deviations, plan-to-change coverage is uncertain before review handoff, or the user explicitly asks for validation.
7. Apply telemetry guidance when implementation touches observable production behavior, and follow commit-message guidance when you summarize the completed work.
8. Return a compact status summary and the next handoff command.

## Success criteria

* The plan and details are available before implementation starts.
* The changes log and planning log are updated progressively and remain review-ready.
* Phase Implementor and Researcher Subagent dispatch happen through `runSubagent` or `task` when available.
* Validation evidence is captured when required, and the review handoff names `/task-reviewer`.

## Constraints

* Do not expand scope beyond the approved phase.
* Keep the skill compact; use [references/implementation.md](references/implementation.md) for deeper protocol details and templates.
* Stop and ask the user only when required subagent dispatch is unavailable or research cannot resolve a blocking clarification.

## Stop rules

* Stop if the plan or details file is missing or invalid.
* Stop if required subagent dispatch is unavailable and the phase cannot proceed.
* Stop if validation finds blocking Critical or High issues that must be resolved before review handoff.

## Handoff

After implementation is complete, continue with `/task-reviewer` to validate the result and capture review evidence. `/task-review` remains the legacy prompt alias; the skill-forward path is `/task-reviewer`.

> Brought to you by microsoft/hve-core
