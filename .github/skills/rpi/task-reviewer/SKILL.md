---
name: task-reviewer
description: Review-only RPI playbook that validates implementation evidence, checks phase completion, and closes the loop with explicit next steps. Use when the user needs review coverage or acceptance evidence.
license: MIT
user-invocable: true
---

# Task Reviewer

## Goal

Confirm the implementation is complete, evidence-backed, and ready for handoff or follow-up.

## What to do

1. Review the implementation and change-log evidence for the current phase.
2. Dispatch the existing Implementation Validator for review coverage.
3. Dispatch RPI Validator when the review must confirm plan-to-changes alignment.
4. Return a concise verdict with blockers, follow-up work, and the next command if more work is needed.

## Success criteria

* The review summary names the verified outcome and any remaining issues.
* The validation path uses the existing RPI validators rather than duplicating review logic.
* The next command is explicit for the user.

## Constraints

* Do not re-implement the fix in this phase.
* Keep the review result compact and actionable.
* Use the existing validation subagents for evidence-based review.

## Stop rules

* Stop if the implementation evidence is missing.
* Stop if the validation result shows unresolved blocking issues.

## Handoff

If the review passes, return to the user with the validated outcome; if follow-up is required, continue with the next phase command or the existing plan.

> Brought to you by microsoft/hve-core
