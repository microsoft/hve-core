---
name: rpi
description: Umbrella RPI playbook that sequences research, planning, implementation, and review for one-shot task execution with explicit stop rules and phased handoffs.
license: MIT
user-invocable: true
---

# RPI

## Goal

Run the full RPI flow in order for a single task when the user wants one-shot sequencing instead of phase-by-phase commands.

## Flow

1. Run the research phase and capture evidence under `.copilot-tracking/research/`.
2. Run the planning phase and validate the plan under `.copilot-tracking/plans/` and `.copilot-tracking/details/`.
3. Run the implementation phase and record changes under `.copilot-tracking/changes/`.
4. Run the review phase and capture validation evidence before closing.

## Success criteria

* Research, planning, implementation, and review artifacts are all produced in the expected tracking locations.
* Each phase stops on a blocking condition instead of silently continuing.
* The user can still choose the granular `/task-researcher`, `/task-planner`, `/task-implementor`, and `/task-reviewer` path when needed.

## Constraints

* Keep the umbrella skill as a sequencing playbook, not a full orchestration engine.
* Use the existing subagents for research, validation, and review work.
* Do not replace the current top-level RPI agents in this increment.

## Stop rules

* Stop if research evidence is missing before planning begins.
* Stop if the Plan Validator reports blocking issues.
* Stop if implementation is blocked by a dependency or validation failure.
* Stop if review validation fails or the evidence trail is incomplete.

## Handoff

Use the granular phase skills for more controlled execution: `/task-researcher`, `/task-planner`, `/task-implementor`, and `/task-reviewer`.

> Brought to you by microsoft/hve-core
