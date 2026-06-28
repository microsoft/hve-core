---
name: rpi-review
description: Review-only RPI playbook that validates implementation evidence, checks phase completion, and closes the loop with explicit next steps. Use when the user needs review coverage or acceptance evidence.
argument-hint: "[task=...] [plan=...] [changes=...]"
license: MIT
user-invocable: true
---

# Task Reviewer

Use [references/review.md](references/review.md) for the full review protocol, templates, and validator contracts.

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Produce an evidence-backed review result with validator dispatch, review-log synthesis, and explicit follow-up guidance.

## What to do

1. Resolve the review scope from explicit paths, attached or open files, task slug, time-based scope, then recent matching `.copilot-tracking` artifacts. If no reviewable artifact set can be formed, stop and ask for the task context. If multiple unrelated artifact sets match, stop and ask the user to choose one.
2. Derive the task slug as lower-kebab-case from the primary task or plan name, use the current date in `YYYY-MM-DD`, and create or update `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/<task-slug>-review.md` with `<!-- markdownlint-disable-file -->`.
3. Prefer `RPI Validator` and `Implementation Validator` with `runSubagent` or `task`; use `Researcher Subagent` only when context is missing or findings remain unclear. If dispatch tooling is unavailable, perform the equivalent review or validation inline, record it, and continue without dead-stopping on the dispatcher alone.
4. Run one `RPI Validator` pass per plan phase and one implementation-quality pass, then run validation commands for changed files when available, record command, scope, status, and summary, and mark the review `Complete` only when commands pass or the skip reason is explicit.
5. Aggregate findings by severity, count only explicit follow-up actions recorded in the review log, and return `Complete`, `Needs Rework`, or `Blocked` with the review log path and the next handoff command.

## Success criteria

* The review log exists under `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/` and starts with `<!-- markdownlint-disable-file -->`.
* The review covers artifact discovery, task-slug derivation, validator dispatch, one `RPI Validator` pass per phase, validation commands, severity aggregation, plan-to-research alignment, and explicit follow-up counts.
* The final response starts with a Task Reviewer style status header, includes the validation activities completed, the review log path, overall status, severity counts, follow-up count, and next-step command, and keeps handoff commands as recommendations unless the user asked for them.
* Name `/rpi-review` in the handoff when another review pass is required.

## Constraints

* Do not re-implement the fix in this phase.
* Prefer `RPI Validator` and `Implementation Validator` with `runSubagent` or `task`; use `Researcher Subagent` as the fallback when context is missing. If dispatch tooling is unavailable, perform the equivalent review or validation inline and record it instead of dead-stopping on the dispatcher alone.
* Keep the review summary brief; use [references/review.md](references/review.md) for the detailed protocol, templates, and validator contracts.
* Stop and ask the user only when required subagent dispatch is unavailable or research cannot resolve a blocking ambiguity.

## Stop rules

* Stop if no reviewable artifact set can be formed.
* Stop when multiple unrelated artifact sets match and the user has not selected one.
* Stop if validator dispatch is unavailable and the review would be based on guesswork.
* Stop when unresolved Critical or High findings block completion and the user needs to fix the implementation before handoff.

## Handoff

After the review completes, offer the next phase command as a recommendation unless the user explicitly requested a handoff.

> Brought to you by microsoft/hve-core
