---
name: rpi-quick
description: Umbrella RPI playbook that sequences Research, Plan, Implement, Review, and Discover for one-shot task execution with quality gates.
argument-hint: "[task=...] [continue={1|1,2|all}] [suggest]"
license: MIT
user-invocable: true
---

# RPI

Use [references/orchestration.md](references/orchestration.md) for the orchestration contract, artifact-path matrix, and validator dispatch rules.

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Run the full RPI flow as the primary umbrella entry point for one-shot task execution, and delegate each phase to the matching task skill.

## Flow

1. Research: establish task scope, evidence, and difficulty.
2. Plan: create or refresh the plan and supporting notes when the task needs them.
3. Implement: apply the current plan and update the changes log.
4. Review: validate the result and record the review outcome.
5. Discover: run before completion, pause, escalation, or handoff to produce Suggested Next Work.

If Review or Discover reveals more work on the active task, restart from the earliest affected phase of that task.

## Delegation crosswalk

* Research -> /rpi-research, which uses its internal Researcher Subagent path.
* Plan -> /rpi-plan, which uses its internal Plan Validator path.
* Implement -> /rpi-implement, which uses its internal Phase Implementor and Implementation Validator path.
* Review -> /rpi-review, which uses its internal RPI Validator and Implementation Validator path.
* Discover -> handled by the orchestrator in its own context, with no separate sub-skill.

When sub-skill dispatch is unavailable, run the phase inline by dispatching that phase's listed subagent(s) or validator(s) directly via `runSubagent` or `task`; when those are also unavailable, perform the equivalent work inline and record it.

## Inputs

* `task=...`: primary task description or inferred intent from the conversation, attached files, or current file when no explicit task input is provided.
* `continue={1|1,2|all}`: select one or more saved Discover suggestions; each selected suggestion starts a new RPI cycle at Research (Phase 1); `all` processes every saved suggestion in listed priority order.
* `suggest`: run Discover directly to refresh next-work suggestions.
* `task_slug`: lower-kebab-case derived from the primary task or target; use the current date in `YYYY-MM-DD` for dated artifacts.

## Success criteria

* For Simple and Medium work, the orchestrator may keep phases in its own context and skip durable artifacts; for Medium-hard and Challenging work, use the dated `.copilot-tracking/` artifact set and carry it forward.
* Dated artifacts share one `task_slug` and `YYYY-MM-DD` date across every phase of a task.
* Research, planning, implementation, review, and Discover run in order and stop on blocking findings.
* The umbrella skill delegates detailed phase work to `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review`.
* Review selects validation from the changed artifacts and affected behaviors, records considered checks, and distinguishes run, skipped, unavailable, and out-of-scope checks.
* When no explicit `task`, `continue`, or `suggest` input is present, infer the next intent from the conversation, attached files, or the current file.
* When `continue={1|1,2|all}` selects saved suggestions, each selection starts a new RPI cycle at Research (Phase 1); `all` processes every saved suggestion in the saved priority order.
* The final response includes phase status, iteration count, artifact paths, validation coverage, review outcome, and Suggested Next Work.
* When review outcome is Complete, include a commit message in a markdown code block following `.github/instructions/hve-core/commit-message.instructions.md`, excluding `.copilot-tracking` files.
* Still run Discover before any user-facing finish, pause, escalation, or handoff.

## Conversation-history summary contract

When the run ends or conversation history is compacted, include:

* confirmation that state is managed through `.copilot-tracking/` files;
* the tracking artifact paths with percent complete;
* the last completed phase and current step;
* recent Review findings; and
* recent Discover follow-up work items in order.

## Constraints

* Keep the umbrella skill as the sequencing layer, not as a full duplicate of every granular phase playbook.
* Dispatch each phase to its sub-skill; each sub-skill owns its internal validator or quality gate, and the orchestrator does not add a separate validator layer.
* If dispatch tooling is unavailable, run the phase inline by dispatching the listed subagent(s) or validator(s) directly via `runSubagent` or `task`; when those are also unavailable, perform the equivalent work inline and record it.
* Ensure delegated phases keep `.copilot-tracking/` paths and other internal planning, research, or implementation artifact references out of production code, code comments, documentation strings, and commit messages; internal artifacts still guide implementation logic.
* Stop only when a real product decision or acceptance criterion cannot be responsibly inferred and requires user input.
* Retry failed subagent calls with a more specific prompt, and run an additional research subagent when missing context is blocking.
* Fall back to direct tool usage only after subagent retries fail, and only for the smallest safe scope that still maintains the required quality gate.
* Genuine blockers remain hard stops: missing required inputs or an unresolvable task.

## Quality gates

* Treat task difficulty as dynamic: Simple, Medium, Medium-hard, or Challenging, and escalate to the document-backed path when findings increase the scope or risk.
* Critical and major validation findings block advancement until fixed and revalidated.
* Minor findings may remain only when they are explicitly documented as non-blocking.

## Stop rules

* Stop if research evidence is missing before planning begins.
* Stop if Plan Validator reports blocking findings.
* Stop if implementation is blocked by a dependency or validation failure.
* Stop if review validation fails or the evidence trail is incomplete.
* Stop when required inputs are missing for the current task.
* Stop only when a real product decision or acceptance criterion cannot be responsibly inferred and requires user input.
* Stop if the dated artifact set cannot be discovered or resumed for the current task when the workflow uses durable artifacts.

## Handoff

Use the granular phase skills for the detailed execution path: `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review`.

## Final response contract

Return a brief summary that includes:

* phase status and iteration count,
* the dated artifact paths used or updated,
* validation coverage, including checks considered, run, passed, failed, skipped, unavailable, and out of scope,
* the current review outcome, and
* Suggested Next Work from Discover.


