---
description: "Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core"
argument-hint: "file=... [requirements=...]"
agent: 'prompt-builder'
maturity: stable
---

# Prompt Refactor

Refactor and clean up the specified prompt engineering artifact.

## Inputs

* ${input:files}: (Optional) Target prompt file(s) to refactor. Defaults to the current open file or attached files.
* ${input:requirements}: (Optional) Additional refactoring focus areas.

## Mode

Operate in **refactor** mode for all Required Phases.

Refactor mode behavior:

* Remove or condense redundant instructions while preserving intent.
* Replace verbose examples with concise instruction lines where examples are not essential.
* Update outdated patterns to follow current authoring standards.
* Correct any schema, API, SDK, or tool call instructions based on research.
* Compress templates and structure to match current file type guidelines.

---

Proceed with refactoring the target file(s).
