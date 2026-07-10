---
description: "Orchestration reference for the umbrella RPI skill"
---

# RPI Orchestration Reference

Use this reference for the orchestration contract, artifact-path matrix, and validator dispatch rules.

## Phase and continuation contract

1. Research: establish scope, evidence, task difficulty, and the task slug.
2. Plan: create or refresh the plan and supporting notes when the task needs them.
3. Implement: apply the current plan and update the changes log.
4. Review: run validation, capture review evidence, and determine whether the work is Complete, Iterate, or Escalate.
5. Discover: always run before completion, pause, escalation, or handoff to produce Suggested Next Work and continuation routing.

If Review or Discover reveals more work on the active task, restart from the earliest affected phase of that task.

## Task slug and artifact contract

* `task_slug` is lower-kebab-case derived from the primary task or target.
* Source precedence is the named target artifact when the task references one, otherwise the primary task description; normalize to lower-kebab-case by joining alphanumeric tokens with hyphens and dropping filler words; keep it concise.
* Keep dated folders and files under `.copilot-tracking/.../{{YYYY-MM-DD}}/` as the required cross-phase artifact convention when the workflow uses durable artifacts.
* Resume by updating the dated files in place instead of creating duplicate artifact sets.
* For Simple and Medium work, the orchestrator may keep phases in its own context and skip durable artifacts; for Medium-hard and Challenging work, use the dated `.copilot-tracking/` artifact set and carry it forward.

## Artifact path matrix

* `.copilot-tracking/research/{{YYYY-MM-DD}}/<task_slug>-research.md`: Research consumes the task and produces evidence and scope.
* `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`: Researcher Subagent outputs add deeper evidence when needed.
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/<task_slug>-plan.instructions.md`: Plan consumes the research artifact and produces the implementation plan.
* `.copilot-tracking/details/{{YYYY-MM-DD}}/<task_slug>-details.md`: Plan consumes research context and produces the detailed execution notes.
* `.copilot-tracking/plans/logs/{{YYYY-MM-DD}}/<task_slug>-log.md`: Plan and Review record validation findings and follow-up work.
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/<task_slug>-changes.md`: Implement consumes the plan and details and produces the change log.
* `.copilot-tracking/reviews/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-review.md`: Review consumes the changes log and validation evidence and produces the review outcome.
* `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-<NNN>-validation.md`: Review and Discover capture validation evidence and next-work suggestions.

Define `<plan-file-name-without-instructions-md>` as the plan artifact name with the trailing `.instructions.md` removed.

## Delegation crosswalk and fallback

* Research -> `/rpi-research` (internally uses Researcher Subagent).
* Plan -> `/rpi-plan` (internally uses Plan Validator).
* Implement -> `/rpi-implement` (internally uses Phase Implementor and Implementation Validator).
* Review -> `/rpi-review` (internally uses RPI Validator and Implementation Validator).
* Discover -> handled by the orchestrator in its own context, with no sub-skill.

The orchestrator delegates each phase to the listed sub-skill. Each sub-skill owns its internal validator or quality gate; the orchestrator does not add a separate validator layer. When sub-skill dispatch is unavailable, run the phase inline by dispatching that phase's listed subagent(s) or validator(s) directly via `runSubagent` or `task`; when those are also unavailable, perform the equivalent work inline and record it.

## Checkpoint and continuation policy

* Stop only when a real product decision or acceptance criterion cannot be responsibly inferred and requires user input.
* Current-task iteration: when Review or Discover reveals more work on the active task, restart from the earliest affected phase of that task.
* Saved-suggestion resume: `continue={1|1,2|all}` selects one or more saved Discover suggestions; each selected suggestion starts a new RPI cycle at Research (Phase 1); `all` processes every saved suggestion in listed priority order. Saved suggestions do not carry an earliest affected phase.
* Continue through Discover before yielding control back to the user for completion, pause, escalation, or handoff.

## Discover protocol

* Gather session history and `.copilot-tracking/` context, including prior Suggested Next Work selections and skips.
* Reason about direct next steps, related missing features, codebase-discovered gaps, refactoring, and newly learned patterns.
* Select 3-5 high-value actionable items when meaningful candidates exist, with brief priority and effort rationale.
* Continue automatically only when exactly one unambiguous next step remains that requires no product decision; otherwise present the suggestion list for selection.
* Present the result in the required high-level shape: `## Suggested Next Work`, numbered items, and a blockquote quick-reference line mapping option numbers to titles.

Input modes:

* `task=...`: primary task description or inferred task intent.
* `continue={1|1,2|all}`: select one or more saved Discover suggestions; each selected suggestion starts a new RPI cycle at Research (Phase 1); `all` processes every saved suggestion in listed priority order.
* `suggest`: run Discover directly to refresh next-work suggestions.
* When no explicit `task`, `continue`, or `suggest` input is given, infer the intent from the conversation, attached files, or the current file.

## Iteration, fallback, and final response rules

* Treat difficulty as dynamic: Simple, Medium, Medium-hard, or Challenging. Escalate to the heavier document-backed path when later findings show more complexity.
* Re-enter the earliest affected phase when validation reveals blocking issues or when Discover suggests additional work.
* During Review, build a changed-artifact validation decision matrix before selecting checks. For each changed artifact category, record the likely affected behavior, the relevant local validation or equivalent inspection, whether the check is required for this task, and the status as considered, run, skipped, unavailable, or out of scope.
* Use the matrix to choose the narrowest validation that can falsify the change, then broaden only when shared behavior, cross-artifact contracts, generated outputs, configuration, or release readiness is affected.
* For readiness tasks, review affected-behavior coverage before finalizing. Identify the behaviors or contracts touched by the changes, map each to an existing check or equivalent evidence, add or update coverage when it is in scope, and document any deferred coverage with the reason and risk.
* Retry failed subagent calls with a more specific prompt before changing approach.
* Run an additional research subagent when missing context is blocking the next gate.
* Fall back to direct tool usage only after subagent retries fail, and only for the smallest safe scope that still maintains the required validation gate.
* Keep the response brief and evidence-first: phase status, iteration count, artifact paths, validation coverage, review outcome, and Suggested Next Work.
* Report validation coverage with enough detail to audit omissions: checks considered, checks run, pass or fail results, skipped checks with rationale, unavailable checks with the blocking condition, and out-of-scope checks with the boundary that excluded them.
* If review outcome is Complete, include a commit message in a markdown code block following `.github/instructions/hve-core/commit-message.instructions.md`, excluding `.copilot-tracking` files.
* If review outcome is Iterate or Escalate, continue from the earliest affected phase and still complete Discover before handing off.
* Do not end a run without completing Discover, even when the next action is obvious.

## Conversation-history summary contract

When the run ends or conversation history is compacted, include:

* confirmation that state is managed through `.copilot-tracking/` files;
* the relevant tracking artifact paths with percent complete;
* the last completed phase and current step;
* recent Review findings; and
* recent Discover follow-up work items in order.
