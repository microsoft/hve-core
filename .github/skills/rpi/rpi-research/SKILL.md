---
name: rpi-research
description: Research-only RPI playbook that gathers task evidence, writes dated research artifacts under .copilot-tracking/research/, and hands off planning-ready findings. Use when the user needs evidence, alternatives, or task framing first.
argument-hint: "[topic=...] [chat]"
license: MIT
user-invocable: true
---

# RPI Researcher

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Produce a planning-ready research brief with dated evidence for RPI research.

Derive `{{task_slug}}` from the primary research target with lower-kebab-case, and use the current date in `YYYY-MM-DD`. Write to .copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md, or mirror research/YYYY-MM-DD/{{task_slug}}-research.md under a trusted sandbox or caller-owned evidence root and record the resolved root.

## Execution

Use [references/research.md](references/research.md) for the research template and deeper protocol detail.

1. Confirm the task scope, target files, and expected outcome. Use the supplied topic when available; when it is not, infer an initial topic from the conversation context. When chat context is enabled, incorporate it to refine scope before drafting the research brief.
2. Create or update the primary research artifact at the resolved research path.
3. Use `Researcher Subagent` via `runSubagent` or `task` when available; otherwise perform equivalent inline research and record the fallback reason. Parallelize dispatch across independent topics: when the research question decomposes into separable subtopics (for example repo overview, existing-capability status, external pattern research), dispatch one `Researcher Subagent` call per subtopic in parallel, each writing its own file under `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/` named for its subtopic, rather than one sequential call accumulating into a single file.
4. Move through research and analysis, then re-enter research while material gaps remain.
5. Consolidate findings into the primary research document, capture key discoveries, evidence logs, technical scenarios, alternatives, potential next research, and unresolved gaps, and update the dated artifact before any handoff.
6. Finish with the Final Response contract.

## Context Discipline

Treat each `Researcher Subagent` chat response as an index, not the full result. Re-read a subagent file only when the next action (consolidating findings, resolving a contradiction, evaluating an alternative) needs evidence the chat summary does not contain. After every subagent return, keep the turn lean: update the primary research artifact, emit a compact one-line-per-subagent status, and stop — do not re-quote subagent payloads or narrate the remaining plan.

## Success criteria

* The primary research artifact exists at the resolved research path.
* The document covers scope, task requests, evidence, key discoveries, technical scenarios or alternatives, potential next research, open questions, and handoff guidance.
* When no direct topic is supplied, the initial topic is inferred from the conversation context, and enabled chat context is incorporated to refine scope before the research artifact is drafted.
* The final response follows the Final Response contract.
* Next-step behavior follows the Next Step Policy section.

## Constraints

* Do not plan, implement, or review in this phase.
* Do not write files outside the resolved research root for this phase, except subagent outputs or workflow tracking files explicitly required by the current execution.
* Accept alternate research roots only when the caller or test harness explicitly provides a trusted sandbox or evidence root. Reject traversal paths, source artifact directories, and unrelated output locations.
* Research artifacts may cite .copilot-tracking/ evidence, but never instruct embedding those paths or other internal planning, research, or implementation artifact references into production code, code comments, documentation strings, or commit messages.
* Do not invoke `/rpi-plan` or any other follow-on skill. Follow-on skill invocation belongs to the user or rpi-quick.
* Keep responses concise and evidence-first, and do not repeat large subagent output in the closing turn.

## Stop rules

* Hard stop if the task context is missing or ambiguous.
* Hard stop if the research artifact cannot be written at the resolved research path.
* Hard stop if the task is unresolvable from the provided inputs.
* Re-enter deeper research when significant gaps remain.

## Next Step Policy

After normal RPI research is complete, report an advisory recommendation for `/rpi-plan` with the dated primary research artifact at .copilot-tracking/research/YYYY-MM-DD/{{task_slug}}-research.md. The user or rpi-quick owns acting on that recommendation. If material gaps remain, recommend deeper rpi-research before planning.

When the caller requests research-only, no handoff, analysis, audit, or comparison output, state why no planning recommendation is made.

## Final Response

Return a concise, evidence-first summary with:

* Open with a `## 🔬 RPI Researcher: [Topic]` header.
* Research artifact path.
* Selected approach and rationale.
* Rejected alternatives or lower-ranked options.
* Key evidence with workspace-relative paths.
* Open questions and risks.
* Constraint status, including whether planning and implementation were avoided.
* Artifact self-check status, listing required sections checked when no executable validation ran.
* Advisory next-step recommendation, either `/rpi-plan` with the dated artifact path or an explicit no-planning reason.
* Close with a structured summary table (Research Artifact / Selected Approach / Key Discoveries / Alternatives Evaluated / Open Questions / Advisory Next Step).


