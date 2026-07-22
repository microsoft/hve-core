---
name: rpi-walkthrough
description: Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts with navigable evidence links, deep subagent review, and a reconciled decisions-and-changes ledger. Use when the user wants to understand how something works or why it was changed.
argument-hint: "[target=...] [detail={brief|normal|deep}] [chat]"
license: MIT
user-invocable: true
---

# RPI Walkthrough

Use [references/walkthrough.md](references/walkthrough.md) for the full walkthrough protocol, segment loop, reference-table format, decisions-and-changes ledger format, and subagent dispatch.

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Walk the user through a target one segment at a time, explaining what each line or block does and why with navigable evidence links. Keep target refinement, detail, pacing, current position, and follow-up depth in the conversation. Capture a material user decision or requested change in a narrow ledger only when one occurs, then reconcile it with the user without editing source by default.

A target is source code, UI or UX wiring, a library or feature, a prompt-engineering artifact such as a prompt, instructions, agent, or skill, or a `.copilot-tracking` artifact such as a research, plan, changes, review, or log document.

When a ledger is needed, derive `{{task_slug}}` in lower-kebab-case from the primary target's main subject, such as the primary file's base name without its extension or the feature or area name. Use the current date in `YYYY-MM-DD` and create `.copilot-tracking/walkthroughs/{{YYYY-MM-DD}}/{{task_slug}}-decisions.md` from [templates/walkthrough.md](templates/walkthrough.md).

## Execution

1. Resolve the walkthrough target and detail level from explicit input, attached or open files, then conversation context. Default `detail` to `normal`. When chat context is enabled, incorporate it to refine scope. If no target can be formed, stop and ask; if multiple unrelated targets match, ask the user to choose one. When prior conversation context is unavailable, ask the user for the target and desired starting point instead of reconstructing progress from a ledger.
2. Deep review before explaining. Dispatch a generic exploration subagent (`Explore`, or `runSubagent` with no named agent) to trace the codebase, UI, UX, feature flow, prompt-engineering artifact, or `.copilot-tracking` artifact. When the explanation depends on an external library, framework, or standard, activate `rpi-research` with the walkthrough topic, purpose, audience, questions, evidence criteria, scope, constraints, supplied evidence, requested outputs, and analysis output mode. Read its primary artifact before explaining and scale the review depth to `detail`. Keep review results in the active conversation and subagent returns.
3. Plan coherent segments in the conversation: entry point through flow and key blocks for code, or section order for artifacts. Keep their order, pacing, and coverage in conversation context.
4. Explain one segment at a time in the conversation: write a clear, scannable explanation of what it does, how it connects, and why it is this way, and follow the human-voice writing guidance in the reference. Start each segment with a segment header; before the first segment, render an overview Mermaid diagram when the target has meaningful structure or flow; add a compact focus diagram only when it adds information beyond the overview and prose. Include inline markdown links beside the explanatory prose for any file, block, or artifact discussed, then render a reference table of file and line links for that segment. Render the full segment turn as visible chat text before every `vscode_askQuestions` call and before yielding control: the segment header, any useful diagrams, inline links, and reference table appear first, and one or two questions come last in that same turn.
5. Refine or capture on feedback. When the user asks for more depth or why, repeat the deep review with subagents and tools as needed, then re-explain. When the user makes a material decision or requests a change, lazily create the decisions-and-changes ledger from the template, append the entry, and offer immediate reconciliation or continuing with the entry open within the existing one-or-two-question cadence. Do not edit the codebase unless the user explicitly chooses immediate reconciliation and the change is safely scoped.
6. Close once all segments are covered or the user ends early. If a ledger exists, review open entries and ask whether to reconcile them now or leave them for later, then return the Final response. Do not persist segment coverage, completion status, or resumption data.

## Inputs

* `target=...`: the files, feature, UI or UX area, library, or `.copilot-tracking` artifact to walk through; infer from attached or open files when not provided.
* `detail={brief|normal|deep}`: technical depth of the explanation; default `normal`; the user can change it mid-session.
* `chat`: incorporate conversation context to refine scope before the walkthrough begins.
* `task_slug`: lower-kebab-case from the primary target; use it with the current date in `YYYY-MM-DD` only when creating the dated decisions-and-changes ledger.

## Conversation format requirements

* Use well-formatted markdown in every walkthrough turn. Each segment must begin with a segment header such as `### Segment 1: ...` before any narrative explanation.
* Before the first segment, render an overview Mermaid diagram when the target has meaningful architecture, control or data flow, section relationships, or a user journey. Show that actual target structure and add segment numbers only as navigation cues.
* During a segment, include a compact focus diagram only when it clarifies real inbound or outbound relationships beyond the overview and prose. Omit it rather than inventing or repeating decorative boxes.
* Use short labels, meaningful relationship labels where useful, semantic role colors rather than progress colors, and one sentence that states the diagram's takeaway. The labels and prose carry the meaning independently of color. Follow the contrast-safe pattern in [references/walkthrough.md](references/walkthrough.md).
* Keep the explanation scannable. Each sentence or paragraph that discusses a specific file, line range, block, or artifact must include a nearby markdown link to that reference, rather than relying only on the reference table.
* Keep the reference table requirement. Render it near the bottom of each segment turn, immediately before the questions.

## Conversation guidance

* During material walkthrough work, provide concise updates at meaningful boundaries through the target-resolution summary, each segment, ledger update, and closeout. Explain what is being covered and why, what changed or was learned, key decisions, blockers, relevant inline links and reference tables, and one important point the user might otherwise miss. Do not narrate low-level actions.
* Before a user question, render the segment or decision context first. State viable choices and consequences, an evidence-backed recommendation when available, blockers, and relevant Markdown links, then keep the existing one-or-two-question cadence.
* Do not use status emojis in walkthrough headings or bullets. The existing prose, headings, inline links, diagrams, and reference tables provide the visual structure.
* At closeout, separate walkthrough session status from decisions-and-changes ledger state. Summarize covered segments, important updates, decisions, blockers or open entries, and anything the user might otherwise miss.
* Advise `/compact` only when stale tool output, superseded reasoning, or completed-segment detail outweighs useful current context and the target and any ledger are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* In a standalone walkthrough, state `/rpi-quick` or the exact applicable `/rpi-*` command only when a ledger entry needs downstream work. Otherwise state the explicit no-handoff reason. In an active `rpi-quick` or confirmed automatic RPI Agent context, return the relevant ledger and evidence to the parent and state that it selects eligible continuation.
* End the user-facing closeout with a Markdown table that links the walked target and every relevant existing artifact. Every file or artifact entry must use a workspace-relative Markdown link in the form `[descriptive label](path/to/file.md)`, with a line or section fragment when useful; do not substitute a plain file name, artifact type, or inline-code path. Give each entry a short description. Include a ledger row only when a ledger exists. The table is the final response element.

## Success criteria

* The target, detail level, and segment plan are resolved before any explanation begins.
* A deep review through subagents precedes explanation, and its results ground the active conversation.
* Each segment is explained in the conversation with a segment header, useful target-derived diagrams where they clarify the target, inline markdown links beside the explanatory prose, and a reference table of workspace-relative file and line markdown links rendered before every `vscode_askQuestions` call and before yielding control.
* Each `vscode_askQuestions` turn carries at most one or two clear questions that offer more detail on the current segment or continue to the next.
* A decisions-and-changes ledger exists only after a material user decision or requested change. Each entry records its reconciliation disposition and outcome or handoff evidence.
* The final response names covered segments and detail level from conversation context. It reports no artifact when no ledger was needed, or links the ledger and its Reconciliation section with counts and open entries when one exists.

## Constraints

* Read-only by default: explain and capture, and never modify source files unless the user explicitly asks for an immediate change.
* Deep-review the target with subagents before explaining, and re-review when the user asks for more depth or why before re-explaining.
* Put the explanation in the conversation window, keep it scannable and easy to follow, and do not present more than one segment at a time.
* Write every walkthrough explanation, including the question text, in a plain human voice: lead with the point, keep each turn short, avoid em dashes, and avoid filler, promotional or inflated wording, formulaic openers and recaps, over-signposting, decorative formatting, sycophancy, and self-referential asides. Follow the fuller guidance in [references/walkthrough.md](references/walkthrough.md) under "Writing the explanation for human eyes" and "Shape of a segment message".
* Render file references in the conversation as workspace-relative markdown links with line numbers, not as inline code, and keep `.copilot-tracking/` references out of production code, code comments, documentation strings, and commit messages.
* Keep at most one or two questions per `vscode_askQuestions` turn.
* Do not over-condense the walkthrough. When the target is large or nuanced, use more segments rather than forcing a compact summary, and 25 or more segments is acceptable when needed.
* Reuse existing subagents for review and research rather than duplicating their full work inline; when dispatch tooling is unavailable, perform the equivalent review inline and state the fallback reason in the conversation.
* Reconcile an open ledger entry with the user as applied now, handed off to an RPI follow-on, deferred for later, or declined. Record the choice and any outcome or evidence pointer. A later request can read the ledger to reconcile open entries, but it does not resume the walkthrough.

## Stop rules

* Stop and ask when no walkthrough target can be resolved from the inputs.
* Stop and ask the user to choose when multiple unrelated targets match.
* Pause for the user's direction at each segment boundary through `vscode_askQuestions` before continuing.
* Conclude the walkthrough when the user declines another segment, asks for a summary, or ends the session. Review open ledger entries when a ledger exists, then run the closing review and Final response.
* Hard stop and ask for clarification when an immediate source change is unsafe, ambiguous, destructive, externally visible, or out of scope.

## Handoff

For a standalone walkthrough, recommend `/rpi-quick` or the exact applicable `/rpi-research`, `/rpi-plan`, `/rpi-implement`, or `/rpi-review` command only for a ledger entry handed off to RPI work or still requiring downstream work. Do not invoke it. State the no-handoff reason when no entry needs downstream work. Return the evidence to `rpi-quick` or a confirmed automatic RPI Agent parent when one owns continuation.

## Final response

Return walkthrough session status, covered segments, detail level, important updates, blockers or open entries, and conditional compaction advice when warranted. If no ledger exists, state that no decisions-and-changes artifact was needed and do not invent a link. If a ledger exists, report its counts of material decisions and requested changes, remaining open entries, and a Markdown link to its Reconciliation section. Recommend RPI follow-on work only for entries handed off or still requiring downstream work. End with the linked target and artifact table required by Conversation guidance.
