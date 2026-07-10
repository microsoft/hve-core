---
name: rpi-walkthrough
description: Guided, conversational walkthrough that explains code, UI, UX, features, or .copilot-tracking artifacts one line or block at a time with navigable evidence links, deep subagent review, and captured change requests for RPI handoff. Use when the user wants to understand how something works or why it was changed.
argument-hint: "[target=...] [detail={brief|normal|deep}] [chat]"
license: MIT
user-invocable: true
---

# RPI Walkthrough

Use [references/walkthrough.md](references/walkthrough.md) for the full walkthrough protocol, segment loop, reference-table format, change-capture format, and subagent dispatch.

Follow the shared conventions in `copilot-tracking.instructions.md`.

## Goal

Walk the user through a target one segment at a time, explaining what each line or block does and why, with navigable evidence links, then capture any requested changes for an RPI handoff without editing the codebase.

A target is source code, UI or UX wiring, a library or feature, a prompt-engineering artifact such as a prompt, instructions, agent, or skill, or a `.copilot-tracking` artifact such as a research, plan, changes, review, or log document.

Derive `{{task_slug}}` in lower-kebab-case from the primary target's main subject, such as the primary file's base name without its extension or the feature or area name, use the current date in `YYYY-MM-DD`, and record session notes in `.copilot-tracking/walkthroughs/{{YYYY-MM-DD}}/{{task_slug}}-walkthrough.md` with `<!-- markdownlint-disable-file -->`.

## Execution

1. Resolve the walkthrough target and detail level from explicit input, attached or open files, then conversation context. Default `detail` to `normal`. When chat context is enabled, incorporate it to refine scope. If no target can be formed, stop and ask; if multiple unrelated targets match, ask the user to choose one.
2. Deep review before explaining. First create the walkthrough file from [templates/walkthrough.md](templates/walkthrough.md) at the dated path. Dispatch a generic exploration subagent (`Explore`, or `runSubagent` with no named agent) to trace the codebase, UI, UX, feature flow, prompt-engineering artifact, or `.copilot-tracking` artifact, and, when the explanation depends on an external library, framework, or standard, dispatch `Researcher Subagent` for cited evidence; scale the review depth to `detail`. Record the evidence map, the segment plan, and the what, why, and evidence paths and lines for each segment in the walkthrough file, which is the single durable record for the session; keep working and scratch notes in that same file so the walkthrough can resume after an interruption.
3. Plan the segments into a meaningful order, entry point through flow and key blocks for code, or section order for artifacts, and record the segment list in the walkthrough file.
4. Explain one segment at a time in the conversation: write a clear, scannable explanation of what it does, how it connects, and why it is this way, and follow the human-voice writing guidance in the reference. Start each segment with a segment header, include the overview diagram before the first segment, include a zoomed mermaid diagram for each segment, include inline markdown links beside the explanatory prose for any file, block, or artifact discussed, then render a reference table of file and line links for that segment, then call `vscode_askQuestions` with one or two questions that offer more detail on this segment or continue to the next. Render the full segment turn as visible chat text before every `vscode_askQuestions` call and before yielding control: the segment header, diagrams, inline links, and reference table appear in the response first, and the one or two questions come last in that same turn.
5. Refine or capture on feedback. When the user asks for more depth or why, repeat the deep review with subagents and tools, deepen the evidence map, and re-explain. When the user requests changes, append them to the Requested Changes section of the walkthrough file and do not edit the codebase, unless the user asks for the change immediately.
6. Close the loop once all segments are covered, or when the user declines another segment or ends the walkthrough early: mark the walkthrough file complete or partial, record any uncovered segments, review the captured Requested Changes with the user, recommend the RPI follow-on, and return the Final response.

## Inputs

* `target=...`: the files, feature, UI or UX area, library, or `.copilot-tracking` artifact to walk through; infer from attached or open files when not provided.
* `detail={brief|normal|deep}`: technical depth of the explanation; default `normal`; the user can change it mid-session.
* `chat`: incorporate conversation context to refine scope before the walkthrough begins.
* `task_slug`: lower-kebab-case from the primary target; use the current date in `YYYY-MM-DD` for the dated artifact.

## Conversation format requirements

* Use well-formatted markdown in every walkthrough turn. Each segment must begin with a segment header such as `### Segment 1: ...` before any narrative explanation.
* Before the first segment explanation, render an overview mermaid diagram that shows the overall flow or structure of the target and the planned segment sequence. Color-code its nodes with the same state classes as the zoom diagram (done green, current gold, upcoming blue), marking the first segment current and the rest upcoming, and render it once as a map. The per-segment zoom diagram tracks progress as the walkthrough advances.
* For each segment, render a compact zoomed mermaid diagram that shows only the prior segment, the current segment, and the next segment, using the same state colors so the current node stands out: the prior done node in green, the current node in gold, and the next upcoming node in blue.
* Keep the explanation scannable. Each sentence or paragraph that discusses a specific file, line range, block, or artifact must include a nearby markdown link to that reference, rather than relying only on the reference table.
* Keep the reference table requirement. Render it near the bottom of each segment turn, immediately before the questions.

## Success criteria

* The target, detail level, and segment plan are resolved before any explanation begins.
* A deep review through subagents precedes explanation, and the evidence map and working notes are captured in the walkthrough file as the single durable record.
* Each segment is explained in the conversation with a segment header, a zoomed mermaid diagram, inline markdown links beside the explanatory prose, and a reference table of workspace-relative file and line markdown links rendered before every `vscode_askQuestions` call and before yielding control.
* Each `vscode_askQuestions` turn carries at most one or two clear questions that offer more detail on the current segment or continue to the next.
* Requested changes are recorded under `.copilot-tracking/walkthroughs/` and are not applied to the codebase unless the user asks for an immediate change.
* The final response recommends `/rpi-quick` or the full RPI sequence and links the walkthrough file and its Requested Changes section in a markdown table.

## Constraints

* Read-only by default: explain and capture, and never modify source files unless the user explicitly asks for an immediate change.
* Deep-review the target with subagents before explaining, and re-review when the user asks for more depth or why before re-explaining.
* Put the explanation in the conversation window, keep it scannable and easy to follow, and do not present more than one segment at a time.
* Write every walkthrough explanation, including the question text, in a plain human voice: lead with the point, keep each turn short, avoid em dashes, and avoid filler, promotional or inflated wording, formulaic openers and recaps, over-signposting, decorative formatting, sycophancy, and self-referential asides. Follow the fuller guidance in [references/walkthrough.md](references/walkthrough.md) under "Writing the explanation for human eyes" and "Shape of a segment message".
* Render file references in the conversation as workspace-relative markdown links with line numbers, not as inline code, and keep `.copilot-tracking/` references out of production code, code comments, documentation strings, and commit messages.
* Keep at most one or two questions per `vscode_askQuestions` turn.
* Do not over-condense the walkthrough. When the target is large or nuanced, use more segments rather than forcing a compact summary, and 25 or more segments is acceptable when needed.
* Reuse existing subagents for review and research rather than duplicating their full work inline; when dispatch tooling is unavailable, perform the equivalent review inline and record the fallback reason.

## Stop rules

* Stop and ask when no walkthrough target can be resolved from the inputs.
* Stop and ask the user to choose when multiple unrelated targets match.
* Pause for the user's direction at each segment boundary through `vscode_askQuestions` before continuing.
* Conclude the walkthrough when the user declines another segment, asks for a summary, or ends the session: mark the walkthrough file partial, record any uncovered segments, then run the closing review and Final response.
* Hard stop and ask for clarification when the user requests an immediate code change that is unsafe or ambiguous.

## Handoff

After the walkthrough completes, review the captured Requested Changes with the user and recommend `/rpi-quick` for a one-shot pass or the full `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` sequence. Keep these as recommendations unless the user asks to proceed.

## Final response

Return a concise summary with the walkthrough file path, the segments covered and the detail level, the count of captured change requests, and a markdown table that links the walkthrough file and its Requested Changes section alongside the recommended next command. Use the Requested Changes section wording in the walkthrough artifact as the anchor for that part of the response.
