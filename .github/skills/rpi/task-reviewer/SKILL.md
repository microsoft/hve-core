---
name: task-reviewer
description: Review-only RPI playbook that validates implementation evidence, checks phase completion, and closes the loop with explicit next steps. Use when the user needs review coverage or acceptance evidence.
license: MIT
user-invocable: true
---

# Task Reviewer

Use [references/review.md](references/review.md) for the deeper review protocol, templates, and validator contracts.

## Goal

Produce an evidence-backed review result with review-log synthesis, validator dispatch, and explicit follow-up guidance.

## What to do

1. Discover the task plan, changes log, and research artifact from the user request, the current open file, or the most recent dated `.copilot-tracking/` artifacts. Derive the task date and review paths from the discovered plan path. If multiple unrelated artifact sets match, present the candidate sets and stop until the user chooses one.
2. Create or update `.copilot-tracking/reviews/{{YYYY-MM-DD}}/<plan-file-name-without-instructions-md>-review.md` and start it with `<!-- markdownlint-disable-file -->`.
3. Dispatch `Implementation Validator` with changed file paths, validation scope, implementation log path, and research context when available; fold returned severity findings into the review log.
4. Dispatch `RPI Validator` for each plan phase when a plan is present or plan-to-change alignment matters, using one validation file per phase under `.copilot-tracking/reviews/rpi/{{YYYY-MM-DD}}/`. Run independent phases in parallel when useful.
5. Discover and run applicable validation commands for changed files when available, including lint, build, tests, type checks, and diagnostics; record command, scope, exit status, and pass/fail summary in the review log. Do not mark the review `Complete` unless validation commands pass or are explicitly recorded as not applicable.
6. Resume from the existing review log and any completed phase validation files when the user re-enters this review; preserve completed work and continue from the earliest incomplete phase.
7. Use `Researcher Subagent` with `runSubagent` or `task` when context is missing or findings remain ambiguous. Write subagent research outputs to `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md` and stop only when research cannot resolve the gap or dispatch is unavailable.
8. Aggregate findings by severity and return `Complete`, `Needs Rework`, or `Blocked` with the review log path and the next handoff command.

## Success criteria

* The review log exists under `.copilot-tracking/reviews/` and starts with `<!-- markdownlint-disable-file -->`.
* The review covers artifact discovery, validator dispatch, phase validation, validation commands, severity aggregation, and follow-up synthesis.
* The final response includes the review log path, overall status, severity counts, follow-up count, and next-step command.
* The handoff stays compact and names `/task-reviewer` when another review pass is needed.

## Constraints

* Do not re-implement the fix in this phase.
* Keep the reviewer output compact; use [references/review.md](references/review.md) for detailed protocol, templates, and validator contracts.
* Stop and ask the user only when required subagent dispatch is unavailable or research cannot resolve a blocking ambiguity.

## Stop rules

* Stop if the plan or changes log cannot be discovered and no review artifact can be formed.
* Stop when multiple unrelated artifact sets match and the user has not selected one.
* Stop if validator dispatch is unavailable and the review would be based on guesswork.
* Stop when unresolved Critical or High findings block completion and the user needs to fix the implementation before handoff.

## Handoff

After review is complete, continue with the next phase command or the existing plan.

> Brought to you by microsoft/hve-core
