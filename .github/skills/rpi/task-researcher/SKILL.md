---
name: task-researcher
description: Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.
license: MIT
user-invocable: true
---

# Task Researcher

## Goal

Produce a planning-ready research brief under `.copilot-tracking/research/` and hand it to the planning phase with explicit, dated evidence.

## Execution

Use [references/RESEARCH.md](references/RESEARCH.md) for the research template and deeper protocol detail.

1. Confirm the task scope, target files, and expected outcome.
2. Create or update the primary research artifact at `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`.
3. Dispatch the existing Researcher Subagent with `runSubagent` or `task` when available: provide the research topic or questions and a dated subagent output path at `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/<topic>-research.md`. Parallelize independent topics when useful.
4. Consolidate subagent return values into the primary research document, capture key discoveries, technical scenarios, alternatives, and unresolved gaps, and repeat research if material gaps remain.
5. Finish with a compact summary and the planning handoff to `/task-planner` using the dated research artifact path.

## Success criteria

* The primary research artifact exists under `.copilot-tracking/research/{{YYYY-MM-DD}}/`.
* The document covers scope, evidence, key discoveries, technical scenarios or alternatives, open questions, and planning guidance.
* The handoff names `/task-planner` and the dated research artifact path for planning.

## Constraints

* Do not plan, implement, or review in this phase.
* Do not write files outside `.copilot-tracking/research/` for this phase, except subagent outputs or workflow tracking files explicitly required by the current execution.
* Keep the response compact and evidence-first.
* Prefer `runSubagent` or `task` for deeper research and use existing subagents rather than inventing a new orchestration layer.

## Stop rules

* Stop if the task context is missing or ambiguous.
* Stop if the research artifact cannot be written under `.copilot-tracking/research/`.
* Re-enter deeper research when significant gaps remain.

## Handoff

After research is complete, continue with `/task-planner` and attach the dated primary research artifact at `.copilot-tracking/research/{{YYYY-MM-DD}}/<task>-research.md`. If material gaps remain, re-invoke this skill for deeper research before planning.

> Brought to you by microsoft/hve-core
