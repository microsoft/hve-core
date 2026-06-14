---
name: task-planner
description: Planning-only RPI playbook that turns research into a concrete plan, details notes, and planning log, then validates the plan before implementation. Use when the user needs scope, sequencing, and validation evidence.
license: MIT
user-invocable: true
---

# Task Planner

## Goal

Convert validated research into a bounded plan and supporting details that are ready for implementation.

## What to do

1. Confirm the research artifact and the current task scope.
2. Create or update the plan, details, and planning log under `.copilot-tracking/plans/` and `.copilot-tracking/details/`.
3. Dispatch the existing Plan Validator to review the planning output for completeness and feasibility.
4. Return a compact summary with the accepted plan, risks, and the next phase command.

## Success criteria

* The plan and details artifacts exist under `.copilot-tracking/plans/` and `.copilot-tracking/details/`.
* The Plan Validator report is captured and any blocking issues are named.
* The implementation handoff is explicit and bounded.

## Constraints

* Do not implement code in this phase.
* Keep the plan evidence-oriented and short.
* Use the existing planning validator instead of duplicating plan logic in the skill.

## Stop rules

* Stop if the research artifact is missing or incomplete.
* Stop if the Plan Validator reports blocking issues that must be resolved first.

## Handoff

After the plan is validated, continue with `/task-implementor` for the bounded implementation phase.

> Brought to you by microsoft/hve-core
