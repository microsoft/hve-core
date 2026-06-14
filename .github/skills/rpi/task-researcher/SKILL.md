---
name: task-researcher
description: Research-only RPI playbook that gathers task evidence, writes .copilot-tracking/research/ notes, and returns compact synthesis before planning. Use when the user needs evidence, alternatives, or task framing first.
license: MIT
user-invocable: true
---

# Task Researcher

## Goal

Produce a grounded research brief for the current RPI task and hand it to the planning stage with explicit file-backed evidence.

## What to do

1. Confirm the task scope, target files, and expected outcome.
2. Dispatch the existing Researcher Subagent to gather evidence and synthesize the findings.
3. Write or update the relevant research artifact under `.copilot-tracking/research/`.
4. Return a compact summary with references, open questions, and the next phase command.

## Success criteria

* The research artifact exists under `.copilot-tracking/research/`.
* The summary names the key evidence, assumptions, and follow-up questions.
* The next action is clearly scoped for planning, not implementation.

## Constraints

* Do not plan, implement, or review in this phase.
* Keep the response compact and evidence-first.
* Use existing subagents for isolated research work; do not invent a new orchestration layer here.

## Stop rules

* Stop if the task context is missing or ambiguous.
* Stop if the research artifact cannot be written under `.copilot-tracking/research/`.

## Handoff

After research is complete, continue with `/task-planner` to turn the evidence into a plan and planning log.

> Brought to you by microsoft/hve-core
