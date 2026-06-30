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

Produce a planning-ready research brief under `.copilot-tracking/research/` with explicit, dated evidence. Hand it to the planning phase when the caller asks for normal RPI progression, and stop after the research summary when the caller explicitly requests research-only, no handoff, analysis, audit, or comparison output.

Derive `{{task_slug}}` from the primary research target with lower-kebab-case, and use the current date in `YYYY-MM-DD` for the dated folder.

## Execution

Use [references/research.md](references/research.md) for the research template and deeper protocol detail.

1. Confirm the task scope, target files, and expected outcome. Use the supplied topic when available; when it is not, infer an initial topic from the conversation context. When chat context is enabled, incorporate it to refine scope before drafting the research brief.
2. Create or update the primary research artifact at `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`.
3. Delegate research to `Researcher Subagent` via `runSubagent` or `task` when either dispatch tool is available. If neither dispatch tool is available, perform the equivalent research inline and record the fallback reason in the same research artifact.
4. Move through research and analysis, then re-enter research while material gaps remain.
5. Consolidate findings into the primary research document, capture key discoveries, evidence logs, technical scenarios, alternatives, potential next research, and unresolved gaps, and update the dated artifact before any handoff.
6. Finish with a concise summary, constraint status, artifact self-check, and handoff status. Include the planning handoff to `/rpi-plan` only when the caller has not requested research-only, no handoff, analysis, audit, or comparison output.

## Success criteria

* The primary research artifact exists under `.copilot-tracking/research/YYYY-MM-DD/`.
* The document covers scope, task requests, evidence, key discoveries, technical scenarios or alternatives, potential next research, open questions, and handoff guidance.
* When no direct topic is supplied, the initial topic is inferred from the conversation context, and enabled chat context is incorporated to refine scope before the research artifact is drafted.
* The final response names the dated research artifact path, selected approach, rejected alternatives, key evidence, open questions, risks, constraint status, artifact self-check, and handoff status.
* For normal RPI progression, the handoff names `/rpi-plan` and the dated research artifact path for planning. For research-only, no-handoff, analysis, audit, or comparison requests, the handoff status states that planning was intentionally skipped.

## Constraints

* Do not plan, implement, or review in this phase.
* Do not write files outside `.copilot-tracking/research/` for this phase, except subagent outputs or workflow tracking files explicitly required by the current execution.
* Research artifacts may cite `.copilot-tracking/` evidence, but never instruct embedding those paths or other internal planning, research, or implementation artifact references into production code, code comments, documentation strings, or commit messages.
* Honor explicit caller constraints that suppress planning handoff, including research-only, no handoff, analysis, audit, and comparison requests.
* Keep responses concise and evidence-first, and do not repeat large subagent output in the closing turn.
* Delegate deeper research to `Researcher Subagent` instead of adding another orchestration layer.

## Stop rules

* Hard stop if the task context is missing or ambiguous.
* Hard stop if the research artifact cannot be written under `.copilot-tracking/research/`.
* Hard stop if the task is unresolvable from the provided inputs.
* Use `Researcher Subagent` when available, but do not dead-stop solely because dispatch tooling is unavailable; perform the research inline if needed.
* Re-enter deeper research when significant gaps remain.

## Handoff

After normal RPI research is complete, continue with `/rpi-plan` and attach the dated primary research artifact at `.copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md`. If material gaps remain, re-invoke this skill for deeper research before planning.

When the caller explicitly requests research-only, no handoff, analysis, audit, or comparison output, stop after the research summary and state that `/rpi-plan` was intentionally skipped.

## Final Response

Return a concise, evidence-first summary with:

* Research artifact path.
* Selected approach and rationale.
* Rejected alternatives or lower-ranked options.
* Key evidence with workspace-relative paths.
* Open questions and risks.
* Constraint status, including whether planning and implementation were avoided.
* Artifact self-check status, listing required sections checked when no executable validation ran.
* Handoff status, either `/rpi-plan` with the dated artifact path or an explicit no-handoff reason.


