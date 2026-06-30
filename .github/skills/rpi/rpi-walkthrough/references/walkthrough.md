---
description: Full walkthrough protocol for the rpi-walkthrough skill, covering target resolution, deep subagent review, the segment explanation loop, the reference-table format, the change-capture format, and RPI handoff.
---

# RPI Walkthrough Protocol

This reference expands the `rpi-walkthrough` SKILL with the operational detail for a guided, conversational walkthrough. Use [../templates/walkthrough.md](../templates/walkthrough.md) as the structure for the session artifact at `.copilot-tracking/walkthroughs/{{YYYY-MM-DD}}/{{task_slug}}-walkthrough.md`.

Follow the shared conventions in `copilot-tracking.instructions.md`. References inside `.copilot-tracking` artifacts use plain workspace-relative paths; references shown to the user in the conversation use markdown links with line numbers.

## Target resolution

Resolve the walkthrough target before any review or explanation:

* Prefer an explicit `target=...`, then attached or open files, then the most recent relevant `.copilot-tracking` artifact, then conversation context.
* Classify the target so the right review path and segment ordering apply:
  * Code or feature: source files, a feature flow, or a library or API surface.
  * UI or UX: components, routes, state wiring, styles, and the user-facing flow that connects them.
  * Prompt-engineering artifact: a prompt, instructions, agent, or skill file under `.github/`.
  * Artifact or document: a `.copilot-tracking` research, plan, details, changes, review, or log document, or another project document such as an architecture or planning record.
* Set `detail` to `brief`, `normal`, or `deep` (default `normal`). The user can change it at any segment boundary.
* When no target can be formed, stop and ask. When several unrelated targets match, ask the user to choose one before proceeding.

## Deep review before explaining

Always understand the target through subagents before narrating it, and capture what you learn so the explanation stays accurate and grounded.

* Create the walkthrough artifact from [../templates/walkthrough.md](../templates/walkthrough.md) at the dated path before recording anything, so the session can resume if interrupted.
* Dispatch a generic exploration subagent (`Explore`, or `runSubagent` with no named agent) to trace how the code, UI, UX, feature, or artifact actually works: entry points, call paths, data flow, connected files, and the decisions or evidence recorded inside `.copilot-tracking` artifacts.
* Dispatch `Researcher Subagent` when the explanation depends on an external library, framework, standard, or anything that benefits from web or repository research with citations.
* Scale the review to `detail`: a focused single pass for `brief`, a normal pass for `normal`, and a thorough multi-pass review with cross-references for `deep`.
* Record the results in the walkthrough artifact as the evidence map and system of record: for each planned segment capture the target reference (file and line range or artifact section), what it does, why it is this way, and the supporting evidence paths and lines. Keep lightweight working notes in session memory with the `memory` tool, and use `resolve_memory_file_uri` to resolve a memory file's URI when you need to reference it.
* When dispatch tooling is unavailable, perform the equivalent review inline and record the fallback and its reason in the walkthrough artifact.

## Segment planning

Turn the reviewed target into an ordered list of segments that each cover one coherent idea:

* Code or feature: order from entry point through the main flow to the key blocks and lines, grouping tightly-coupled lines into one segment.
* UI or UX: order along the user-facing flow, connecting each view or component to the state, events, and styles that drive it.
* Artifact: follow the document's own section order, pairing each decision with its rationale and evidence.

Record the segment list in the walkthrough artifact before starting segment one so the session can resume if interrupted.

## Segment explanation loop

Run this loop once per segment, and never advance more than one segment per turn:

1. Explain the segment in the conversation. Lead with what it does, then how it connects to the rest of the target, then why it is this way. Match the depth to `detail`. Keep the writing scannable: short paragraphs, a tight bullet list when it helps, and bold only for the few terms that carry the idea. Do not paste large code blocks; describe the code and point to it.
2. Render the reference table for the segment (see Reference table format) so the user can navigate to every place being discussed.
3. Call `vscode_askQuestions` with one or two clear questions. The first offers more detail or a why on the current segment; the second continues to the next segment. Always render the reference table before this call and before yielding control.

Render the reference table immediately before every `vscode_askQuestions` call and before any hand back of control, including mid-segment pauses.

## Reference table format

Present references as a compact markdown table near the bottom of the message, before the questions. Use workspace-relative markdown links with line numbers, never inline code for file names, and never combine non-contiguous lines into one link.

| Reference | What to look at |
|-----------|-----------------|
| [path/to/file.ext](path/to/file.ext#L10-L24) | One-line description of this block |
| [path/to/other.ext](path/to/other.ext#L5) | One-line description of this line |

For a `.copilot-tracking` artifact walkthrough, link the artifact section being explained and any codebase files it references so the user can move between the decision and the code.

## Handling feedback

Interpret the user's `vscode_askQuestions` answer and respond in kind:

* More detail or why: repeat the deep review with subagents and tools as needed, extend the evidence map, then re-explain the same segment at greater depth before offering to continue.
* Less detail or a depth change: adjust `detail` and continue.
* Continue: advance to the next segment and run the loop again.
* A change request: capture it (see Capturing requested changes) and continue, unless the user asks for the change immediately.
* A new or refined target: re-resolve the target, re-review, and re-plan the segments.

## Capturing requested changes

The walkthrough is read-only by default. When the user requests a change while explaining:

* Append it to the Requested Changes section of the walkthrough artifact with the file and line reference, the requested change, the reason the user gave, and the relevant evidence path.
* Do not modify source files, and do not stage edits to the codebase.
* The only exception is an explicit request to make the change immediately: confirm scope, apply the change, then record what was applied in the artifact and resume the walkthrough.

## Closing the walkthrough

When every planned segment is covered, or when the user declines another segment, asks for a summary, or ends the session:

* Mark the walkthrough artifact complete or partial, and record any uncovered segments so the session can resume later.
* Review the captured Requested Changes with the user in the conversation.
* Recommend `/rpi-quick` for a one-shot pass, or the full `/rpi-research`, `/rpi-plan`, `/rpi-implement`, and `/rpi-review` sequence for larger work, seeded with the walkthrough artifact. Keep these as recommendations unless the user asks to proceed.

## Final response contract

Close with a concise summary that contains:

* The walkthrough artifact path.
* The segments covered and the detail level used.
* The count of captured change requests.
* A markdown table linking the walkthrough artifact and its Requested Changes section alongside the recommended next command.

| Artifact | Next step |
|----------|-----------|
| [.copilot-tracking/walkthroughs/{{YYYY-MM-DD}}/{{task_slug}}-walkthrough.md](.copilot-tracking/walkthroughs/{{YYYY-MM-DD}}/{{task_slug}}-walkthrough.md) | Run `/rpi-quick` with this artifact, or run the full RPI sequence |

## Re-entry

When the user returns to an existing walkthrough, read the walkthrough artifact and session memory, resume at the next uncovered segment, and re-review only the segments whose depth or target the user changed.

> Brought to you by microsoft/hve-core
