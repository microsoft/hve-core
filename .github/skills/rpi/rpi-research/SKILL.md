---
name: rpi-research
description: Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.
argument-hint: "[topic=...] [chat]"
license: MIT
user-invocable: true
---

# Task Researcher

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Produce a planning-ready research brief under `.copilot-tracking/research/` and hand it to the planning phase with explicit, dated evidence.

Derive `{{task_slug}}` from the primary research target with lower-kebab-case, and use the current date in `YYYY-MM-DD` for the dated folder.

## Execution

Use [references/research.md](references/research.md) for the research template and deeper protocol detail.

1. Confirm the task scope, target files, and expected outcome. Use the supplied topic when available; when it is not, infer an initial topic from the conversation context. When chat context is enabled, incorporate it to refine scope before drafting the research brief.
2. Create or update the primary research artifact at `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`.
3. Prefer delegating research to `Researcher Subagent` via `runSubagent` or `task` when available. If neither dispatch tool is available, perform the equivalent research inline and record it in the same research artifact.
4. Move through research and analysis, then re-enter research while material gaps remain.
5. Consolidate findings into the primary research document, capture key discoveries, technical scenarios, alternatives, and unresolved gaps, and update the dated artifact before the planning handoff.
6. Finish with a concise summary and the planning handoff to `/rpi-plan` using the dated research artifact path.

## Success criteria

* The primary research artifact exists under `.copilot-tracking/research/YYYY-MM-DD/`.
* The document covers scope, evidence, key discoveries, technical scenarios or alternatives, open questions, and planning guidance.
* When no direct topic is supplied, the initial topic is inferred from the conversation context, and enabled chat context is incorporated to refine scope before the research artifact is drafted.
* The handoff names `/rpi-plan` and the dated research artifact path for planning.

## Constraints

* Do not plan, implement, or review in this phase.
* Do not write files outside `.copilot-tracking/research/` for this phase, except subagent outputs or workflow tracking files explicitly required by the current execution.
* Research artifacts may cite `.copilot-tracking/` evidence, but never instruct embedding those paths or other internal planning, research, or implementation artifact references into production code, code comments, documentation strings, or commit messages.
* Keep responses concise and evidence-first, and do not repeat large subagent output in the closing turn.
* Delegate deeper research to `Researcher Subagent` instead of adding another orchestration layer.

## Stop rules

* Hard stop if the task context is missing or ambiguous.
* Hard stop if the research artifact cannot be written under `.copilot-tracking/research/`.
* Hard stop if the task is unresolvable from the provided inputs.
* Use `Researcher Subagent` when available, but do not dead-stop solely because dispatch tooling is unavailable; perform the research inline if needed.
* Re-enter deeper research when significant gaps remain.

## Handoff

After research is complete, continue with `/rpi-plan` and attach the dated primary research artifact at `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`. If material gaps remain, re-invoke this skill for deeper research before planning.

> Brought to you by microsoft/hve-core
