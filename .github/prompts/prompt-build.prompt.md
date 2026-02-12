---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "file=... [requirements=...]"
maturity: stable
---

# Prompt Build

Build or improve the specified prompt engineering artifact.

## Inputs

* ${input:file}: (Optional) Target file path. Defaults to the current open file or attached file.
* ${input:requirements}: (Optional) Additional requirements or context.

## Mode

Operate in **build** mode — run the full workflow (Phases 1 through 5).

Build mode behavior:

* Create new artifacts or improve existing ones through all phases.
* When no explicit requirements are provided, refactor and improve all instructions in the referenced file.
* When a non-prompt file is referenced, search for related prompt artifacts and update them, or build a new one.

---

Proceed with building or improving the target file.
