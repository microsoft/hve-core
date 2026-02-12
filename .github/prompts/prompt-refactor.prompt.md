---
description: "Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core"
argument-hint: "file=... [requirements=...]"
agent: 'prompt-builder'
maturity: stable
---

# Prompt Refactor

Refactor and clean up the specified prompt engineering artifact.

## Inputs

* ${input:file}: (Required) Target prompt file to refactor. Accepts `.prompt.md`, `.agent.md`, or `.instructions.md` files.
* ${input:requirements}: (Optional) Additional refactoring focus areas.

## Mode

Operate in **refactor** mode — run the full workflow (Phases 1 through 5) with refactoring emphasis.

Refactor mode behavior:

* Remove or condense redundant instructions while preserving intent.
* Replace verbose examples with concise instruction lines where examples are not essential.
* Update outdated patterns to follow current authoring standards.
* Correct any schema, API, SDK, or tool call instructions based on research.
* Compress templates and structure to match current file type guidelines.

---

Proceed with refactoring the target file.
