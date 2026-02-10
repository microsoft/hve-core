---
name: prompt-build
description: Build or improve prompt engineering artifacts following quality criteria. Dispatches prompt-builder agent for phase-based authoring workflow.
maturity: stable
context: fork
agent: prompt-builder
disable-model-invocation: true
argument-hint: "file=... [requirements=...]"
---

# Prompt Build

Build or improve the following prompt engineering artifact:

$ARGUMENTS

## Mode Directives

Operate in build mode following the full 5-phase workflow: Baseline, Research, Build, Validate, Iterate.

Build mode behavior:

* Create new artifacts or improve existing ones through all five phases.
* When no explicit requirements are provided and an existing file is referenced, refactor and improve all instructions in that file.
* When a non-prompt file is referenced, search for related prompt artifacts and update them, or build a new one.

Discover applicable `.github/instructions/*.instructions.md` files based on file types and technologies involved, and proceed with the Required Phases.
