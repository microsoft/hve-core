---
description: "Shared context-discipline rules for RPI parent agents — lean post-work turns, response mode selection, and subagent result handling"
applyTo: '**/.copilot-tracking/{research,plans,details,changes,reviews,challenges}/**'
---

# RPI Context Discipline

Shared rules for RPI parent agents (`RPI Agent`, `Task Researcher`, `Task Planner`, `Task Implementor`, `Task Reviewer`, `Task Challenger`) to keep chat context bounded and avoid `/compact` loops. Each parent agent references this file via `#file:` so a single edit propagates.

## Lean Post-Work Turn

After any subagent returns, this turn MUST be lean:

1. Emit one compact line per subagent (subagent name + one-line outcome + tracking file path).
2. Update the relevant `.copilot-tracking/` file via a single edit if needed.
3. Stop. Do NOT re-read large planning, research, or details files in the closing turn. Do NOT re-quote subagent payloads. Do NOT narrate the next phase plan.

## Response Mode Selection

Choose the lightest mode that satisfies the request:

* **Direct** — Answer from this turn's context only. No subagent, no file reads. Use for clarifications, status questions, or queries when the relevant file is already attached.
* **Lightweight** — Single subagent with a focused prompt. Skip re-reading prior phase tracking files. Use for summarizing findings or single-file edits.
* **Standard** — Default behavior: subagent dispatch + tracking-file update + handoff suggestion.
* **Full** — Multiple parallel subagents + cross-phase synthesis. Use only when explicitly requested or when the phase contract requires it.

## Subagent Result Handling

* Treat the subagent's chat response as an index, not the full result.
* When a decision (plan structure, phase ordering, accept/reject of an alternative, validation verdict) depends on detail beyond the summary bullets, re-read the subagent file directly and cite specific sections.
* Do not re-read the file gratuitously — only when the next action requires evidence the summary does not contain.
