---
description: 'Phase loop, sandbox contract, subagent dispatch matrix, artifact paths, and cleanup contract for the Prompt Builder skill.'
---

# Prompt Builder Orchestration Reference

Use this reference to keep the phase loop, sandbox contract, subagent dispatch matrix, artifact paths, and cleanup contract available during execution.

## Phase loop and return-to-Phase-1 behavior

The loop builds, tests, evaluates, and updates the prompt artifacts, repeating until the evaluation log shows no remaining issues. Build and modification edits follow the Prompt Design Principles and the Prompt Quality Criteria in `prompt-builder.instructions.md`.

1. Execution and evaluation: run `Prompt Tester`, then `Prompt Evaluator` in a sandbox folder and inspect the evaluation log. Test the target prompt files individually, together, or both: test a file on its own when it is meant to run standalone, and test the files together when they are meant to operate in concert (for example, an agent with its instructions and subagents).
2. Research: create or update the primary research file and run `Researcher Subagent` in parallel when topics are independent. Consolidate findings into the primary research document and clean and finalize it before moving to the modification phase.
3. Modifications: run `Prompt Updater` in parallel when prompt files are independent, review all updater tracking files, and return to Phase 1 to execute and evaluate the updated artifacts again.

Repeat each subagent dispatch, answering any clarifying questions it returns, until the subagent reports the step is finished. If the prompt file(s) do not yet exist, move to Phase 2 first; once they exist, return to this phase and repeat it. If the evaluation log shows no remaining issues, finalize the run; otherwise continue the loop from the earliest affected phase instead of finishing early.

## Caller-provided evidence roots

When the caller supplies a run folder, evidence root, tracking root, or similar orchestration-owned path, treat that path as the evidence root for the run. Store or mirror research, updater tracking, sandbox execution logs, and evaluation logs under that root so the caller can trace the complete workflow.

Normalize and validate caller-provided roots before writing. Accept workspace-relative paths under `.copilot-tracking/` by default, or an explicitly trusted run root named by the caller. Reject paths with `..` traversal, source artifact directories, existing non-evidence files, and absolute paths unless the caller explicitly identifies the absolute path as a trusted run root. Record the resolved evidence root in the run log before creating or mirroring artifacts.

Treat research, updater tracking, sandbox execution logs, evaluation logs, and analysis reports as internal evidence. Redact secrets, tokens, credentials, and sensitive prompt outputs before mirroring logs outside canonical tracking paths, and confirm the resolved destination and evidence categories before writing durable evidence outside approved roots.

Use the canonical `.copilot-tracking/research`, `.copilot-tracking/prompts`, and `.copilot-tracking/sandbox` paths when no caller-specific location is supplied. When mirroring canonical paths under a caller-owned root, preserve the same relative shapes, such as `research/...`, `prompts/...`, and `sandbox/...`, unless the caller supplied more specific subpaths.

## Sandbox contract and cross-run continuity

* Default sandbox root: `.copilot-tracking/sandbox/`.
* Caller-owned sandbox root: when the caller supplies a run folder, evidence root, tracking root, or sandbox path, place or mirror the sandbox under that location only after the caller-root validation rules pass. Use a `sandbox/` child folder unless the caller supplied a more specific sandbox path.
* Folder name pattern: `{{YYYY-MM-DD}}-{{topic}}-{{run-number}}`.
* Use today's date as `{{YYYY-MM-DD}}`.
* When multiple target files are supplied, use the lexically first entry as the primary artifact.
* Derive `{{topic}}` from the primary target artifact: if the target is a `SKILL.md`, use the parent folder name; otherwise use the artifact's base name with the suffix stripped (`.prompt.md`, `.instructions.md`, `.agent.md`), in kebab-case.
* Run-number discovery: inspect existing `{{selected-sandbox-root}}/{{YYYY-MM-DD}}-{{topic}}-*` folders and choose the next available `-001`, `-002`, and so on before starting a new iteration.
* Test subagents create and edit only inside the assigned sandbox folder.
* The sandbox mirrors the target folder structure.
* Reuse the prior run's sandbox so later runs build on earlier artifacts and compare results across repeated evaluations.
* Sandbox mirroring: when the test phase is sandbox constrained, mirror runtime paths such as `.copilot-tracking/research/...` and `.copilot-tracking/prompts/...` under the selected sandbox or caller-owned evidence root. Keep real source edits outside the sandbox only when the modification phase intentionally changes target files.

## Subagent dispatch matrix

Use `runSubagent` or `task` whenever those tools are available; the named subagent should still be the primary dispatch target.

Generated prompt-engineering workflows that call `Prompt Tester` or `Prompt Evaluator` must carry the exact dispatch payload fields from this matrix instead of compressing them into generic context. Include target files, run number, sandbox path, purpose, requirements, expectations, prior run paths, execution log path, and prior evaluation logs as applicable. If a field does not apply, mark it as not applicable when deterministic replay or comparison matters.

| Subagent              | Inputs                                                                                                                                                                 | Outputs                                                                                                                                |
|-----------------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------|
| `Prompt Tester`       | target files, run number, sandbox path, purpose, requirements, expectations, prior run paths when iterating                                                            | sandbox folder path, execution-log path, execution status, literal execution findings, clarifying questions                            |
| `Prompt Evaluator`    | target files, run number, sandbox path, execution log path, purpose, requirements, expectations, prior evaluation logs when iterating                                  | evaluation-log path, evaluation status, severity-graded checklist, clarifying questions                                                |
| `Researcher Subagent` | research topic or question, subagent research path to create or update                                                                                                 | subagent research path, research status, key findings, suggested next research, clarifying questions                                   |
| `Prompt Updater`      | prompt files to create or modify, requirements/objectives, evaluation findings and research results, updater tracking path, sandbox/evaluation-log paths when relevant | updater tracking path, changed prompt file paths, related file paths, modification status, outstanding checklist, clarifying questions |
| `Vally Test Author`   | `mode=from-artifact`, `files=` finalized target artifact path(s), `kind=auto` unless specified                                                                         | routed eval file path, stimuli-appended count, dedupe skips, JSON report path                                                          |

## Research and update artifact paths

When a caller-specific evidence root is present, map the default evidence paths under that root unless the caller provided more specific phase paths:

* Primary research: `{{evidence-root}}/research/{{YYYY-MM-DD}}/{{topic}}-research.md`
* Subagent research: `{{evidence-root}}/research/subagents/{{YYYY-MM-DD}}/{{topic}}-research.md`
* Prompt updater tracking: `{{evidence-root}}/prompts/{{YYYY-MM-DD}}/{{prompt-filename}}-updates.md`
* Sandbox execution and evaluation evidence: `{{evidence-root}}/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}/`

When no caller-specific evidence root is present, use these canonical defaults:

* Primary research: `.copilot-tracking/research/{{YYYY-MM-DD}}/{{topic}}-research.md`
* Subagent research: `.copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{{topic}}-research.md`
* Prompt updater tracking: `.copilot-tracking/prompts/{{YYYY-MM-DD}}/{{prompt-filename}}-updates.md`

## Generated workflow guardrails

When generating bounded agents, include handoffs only when the user asks for them or when the workflow cannot complete without them. Avoid adding convenience handoffs to `Prompt Builder`, `/prompt-refactor`, or other follow-on workflows for bounded creation tasks unless that behavior is part of the requested outcome.

Generated audit-style workflows, or generated modes that distinguish audit from improvement, must state source-edit authority on each relevant surface: prompt inputs, agent protocol, instruction constraints, and skill-support references. The `/prompt-builder` default remains create, update, and improve. Use `/prompt-analyze` for read-only review, and use `/prompt-refactor` for cleanup or scoped refactor work.
In generated audit/improvement workflows, make read-only audit behavior explicit with a field such as `mode=audit`, and make source edits explicit with `mode=improve` or `applyChanges=true`.

Pair source-edit authority with evidence-root authority. Generated workflows that accept caller-owned evidence, tracking, report, or sandbox roots must state the approved root policy, normalized destination logging, disclosure boundary, and rejection behavior for untrusted paths.

## Cleanup rules before final response

* Clean up all sandbox folders and files created for this request before the final response, unless the user asked to keep the sandbox artifacts.
* Do not return the final answer until the cleanup pass is complete.

## User conversation expectations

* Announce the current phase before starting work.
* Summarize outcomes when each phase completes and explain how the next phase will proceed.
* Share important findings and clarifying questions as work unfolds instead of operating silently.
* Limit the summary to the key outcomes and the next step.
