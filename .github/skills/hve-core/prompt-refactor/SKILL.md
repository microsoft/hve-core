---
name: prompt-refactor
description: Refactor existing prompt artifacts against explicit requirements through the full prompt-builder loop.
argument-hint: "[promptFiles=...] [requirements=...]"
license: MIT
user-invocable: true
---

# Prompt Refactor Skill

This skill runs the full phase loop of the `prompt-builder` skill—test, evaluate, research, and update—focused on refactoring existing artifacts. Use the `prompt-builder` skill's orchestration reference for the phase loop, the sandbox contract, the `Prompt Tester`, `Prompt Evaluator`, `Researcher Subagent`, and `Prompt Updater` dispatch matrix, the artifact paths, and the cleanup contract. This skill adds only the refactor scope, the cleanup heuristics in [references/refactor-checklist.md](references/refactor-checklist.md), and the validation-selection guidance in [references/validation-matrix.md](references/validation-matrix.md).

## Goal

Refactor existing prompt-engineering artifacts by simplifying, consolidating, and removing confusion while preserving functional intent. When no explicit requirements are supplied, run a baseline evaluation first and derive refactoring objectives from the evaluation findings plus the standard cleanup checklist.

## Flow

1. Confirm the target existing artifacts and any explicit requirements. Derive the sandbox path from the primary target artifact using the deterministic pattern `.copilot-tracking/sandbox/{{YYYY-MM-DD}}-{{topic}}-{{run-number}}`, where `{{YYYY-MM-DD}}` is today's date and `{{topic}}` is the primary artifact's base name with the suffix stripped, or the parent folder name when the target is a `SKILL.md`, in kebab-case. When multiple `promptFiles` are supplied, use the lexically first entry as the primary artifact. See the `prompt-builder` skill's orchestration reference for the full sandbox and dispatch contract.
2. Run one baseline execution and evaluation in the sandbox with `Prompt Tester` and `Prompt Evaluator`, then inspect the evaluation log. When `requirements` were omitted, derive the refactor objectives from this baseline evaluation plus the standard cleanup checklist.
3. Review the artifacts for clarity problems, duplication, confusing structure, and unnecessary examples by using [references/refactor-checklist.md](references/refactor-checklist.md).
4. Apply focused refactor edits that align to the requirements or derived objectives and the Prompt Quality Criteria through `Prompt Updater`, preserving functional intent unless a requirement changes it.
5. Select and run the narrowest relevant validation from [references/validation-matrix.md](references/validation-matrix.md), including changed-file scope checks and any artifact-specific validation available in the repository. Record skipped validations with reasons.
6. Re-enter the execution and evaluation loop until the requirements or derived objectives are satisfied, the evaluation log shows no remaining issues, and the selected validations pass or are documented as skipped.

## Inputs

* `promptFiles`: (Optional) Existing prompt artifact(s) to refactor. Defaults to the current open or attached file(s).
* `requirements`: (Optional) Explicit refactoring objectives, constraints, or acceptance criteria. When omitted, derive the objectives from a baseline evaluation and the standard cleanup checklist.

## Success criteria

* The target artifacts are cleaner, more consistent, and easier to follow.
* Duplication and confusing structure are consolidated or removed.
* The baseline and follow-up execution and evaluation loops complete, selected validations are reported, and the stated requirements or derived refactor objectives are met.
* The sandbox files created for the run are cleaned up before the final response unless the user asked to keep them.

## Constraints

* Focus on existing artifacts; do not create new prompt artifacts as the primary outcome.
* Use the execution and evaluation loop rather than a one-pass edit.
* Preserve functional intent unless a requirement explicitly changes it.
* Keep sandbox edits inside the assigned sandbox folder and clean them up before the final response unless the user asked to keep them.
* When requirements are omitted, run a baseline evaluation first and derive the refactor objectives from the evaluation findings plus the standard cleanup checklist.

## Stop rules

* Finalize when the requirements or derived refactor objectives are satisfied and the loop is complete.
* Re-enter the loop when the evaluation log or evaluator findings show remaining issues.
* Stop and ask when the request or requirements are too vague to act on safely.

## Handoff

If the request needs a deeper read-only review, recommend `/prompt-analyze`. For broader create or update work, recommend `/prompt-builder`.

## Final response contract

Report the changed files, refactor rationale, evaluation or validation status, skipped validations with reasons, and any remaining issues.

> Brought to you by microsoft/hve-core
