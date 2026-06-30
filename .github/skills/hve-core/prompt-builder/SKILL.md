---
name: prompt-builder
description: 'Create or update prompt artifacts through the full prompt-builder phase loop, routing refactor and analyze requests to the specialized skills.'
argument-hint: "[promptFiles=...] [files=...] [requirements=...]"
license: MIT
user-invocable: true
---

# Prompt Builder Skill

Primary entry point for prompt-engineering work. Create or update prompt, instruction, agent, and skill artifacts through the full execution, evaluation, research, and modification loop, and route refactor or analyze requests to the specialized skills.
[references/orchestration.md](references/orchestration.md) is the canonical reference for the phase loop, sandbox contract, caller-owned evidence roots, subagent dispatch matrix, artifact paths, and cleanup contract; the specialized skills reference it, mirroring only the parts they need.

Follow the shared `.copilot-tracking` conventions. When the caller supplies a run folder, evidence root, tracking root, or similar orchestration-owned path, use or mirror that location for research, update, execution, and evaluation evidence. Preserve the canonical `.copilot-tracking/research`, `.copilot-tracking/prompts`, and `.copilot-tracking/sandbox` defaults when no caller-specific location is supplied.

## Goal

Create or update prompt-engineering artifacts through the full execution, evaluation, research, and modification loop until the evaluation log shows no remaining issues. Use this skill for new prompt artifacts, improvements, cleanup, and related instruction updates. Route scoped cleanup against requirements to `/prompt-refactor` and read-only review to `/prompt-analyze`.

## Flow

1. Confirm the target prompt artifacts, reference files, requirements, and any caller-provided evidence root. When the request does not already name the artifacts, decide which artifact types it needs using the Choosing the Right Artifact Type section in `prompt-builder.instructions.md`, propose the breakdown, and confirm scope with the user. Then derive the sandbox topic, evidence root, and next run number using the deterministic contract in
   [references/orchestration.md](references/orchestration.md).
2. When the target prompt files already exist, run the execution and evaluation phase (dispatch `Prompt Tester`, then `Prompt Evaluator`) to establish their current state and inspect the evaluation log; when that baseline shows no unresolved issues, skip to the final response. When the target files do not exist yet, skip to step 3.
3. Research: create or update the primary research artifact at the resolved evidence path, defaulting to `.copilot-tracking/research/{{YYYY-MM-DD}}/{{topic}}-research.md`, and delegate to `Researcher Subagent` when the topics are independent.
4. Modify: dispatch `Prompt Updater` to create or update the prompt files and related instruction files from the evaluation findings and research, then review the updater tracking.
5. Run the execution and evaluation phase, then repeat steps 3-5 until the evaluation log shows no unresolved issues or until the remaining issues are documented explicitly.

## Routing

Handle create or update work in this skill. Route the other modes to their specialized skill:

| Request                                                                   | Routed skill       |
|---------------------------------------------------------------------------|--------------------|
| Create or update a prompt artifact, or apply fixes from a prior analysis  | this skill         |
| Refactor, simplify, or clean up an existing artifact against requirements | `/prompt-refactor` |
| Read-only analysis or quality report with no changes                      | `/prompt-analyze`  |

When a "clean up" request is ambiguous, keep substantial create-or-change work in this skill and route scoped simplification of an existing artifact to `/prompt-refactor`.

## Inputs

* `promptFiles=...`: the prompt, instruction, agent, or skill artifacts to create or modify; infer from the current open or attached files when not provided.
* `files=...`: reference artifacts the target prompt should be able to produce, used by create or update work.
* `requirements=...`: explicit objectives or constraints.
* `runFolder=...`, `evidenceRoot=...`, or `trackingRoot=...`: optional caller-owned evidence location for research, updater tracking, sandbox execution logs, and evaluation logs.
* When `files` or `promptFiles` are supplied without explicit requirements, identify the related instruction file(s), create or update the instruction and prompt artifacts so they can produce the target files, and improve and clean up the prompt files.

## Success criteria

* The requested prompt artifacts or related instruction files exist or were updated.
* The artifacts meet the stated requirements and prompt-builder quality criteria.
* The evaluation loop completed with no unresolved issues, or any remaining issues are documented explicitly.

## Constraints

* Keep sandbox edits inside the assigned sandbox folder and reuse prior runs for continuity.
* Do not skip the evaluator step or finalize early.
* Maintain the repository's prompt-builder quality standard.
* When generating bounded agents, include handoffs only when the user asks for them or they are essential to the workflow's completion path.
* When generating audit-style workflows or modes that distinguish audit from improvement, state source-edit authority explicitly without weakening this skill's default create, update, and improve behavior.
* Clean up the sandbox files and folders created for this request before the final response unless the user asked to keep them.
* When the request is too vague to act on safely, pause and ask for clarification before proceeding.

## Stop rules

* Stop after the loop completes when the targets meet the requirements and evaluation is complete.
* Re-enter the loop when the evaluator identifies outstanding issues.
* Hard stop and ask for clarification when the target artifacts or intent are too ambiguous to create or update safely.

## Vally conformance authoring (optional)

After the build loop converges and the artifact documents stable behaviors worth pinning, optionally dispatch `Vally Test Author` to author conformance stimuli. Pass `mode=from-artifact`, `files=` the finalized artifact path(s), and `kind=auto` unless the user specifies a kind. The subagent owns its routing, safety self-check, dedupe, and append-only writes; surface its routed eval file, appended-stimuli count, and any refusals. See the `Vally Test Author` row in [references/orchestration.md](references/orchestration.md). Skip this step when the user declines or the changes are too exploratory to pin.

## Handoff

After the build loop completes, hand off to `/prompt-analyze` for a deeper read-only review when more evaluation coverage is useful, or to `/prompt-refactor` when the remaining work is primarily cleanup-focused. Do not add these as convenience handoffs to generated bounded agents unless the user requested them or the workflow cannot complete without them.

## Final response contract

Return a concise summary that includes the artifacts changed, the evaluation status and iteration count, the key decisions or issues surfaced, and the next recommended step.


