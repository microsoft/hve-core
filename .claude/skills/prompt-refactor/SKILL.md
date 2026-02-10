---
name: prompt-refactor
description: Refactor and compress prompt engineering artifacts through iterative improvement.
maturity: stable
context: fork
agent: prompt-builder
disable-model-invocation: true
argument-hint: "file=... [requirements=...]"
---

# Prompt Refactor

Refactor and compress the following prompt engineering artifact:

$ARGUMENTS

## Mode Directives

Operate in refactor mode following the full 5-phase workflow: Baseline, Research, Build, Validate, Iterate.

Refactor mode behavior:

* Remove or condense redundant instructions while preserving intent.
* Replace verbose examples with concise instruction lines where examples are not essential.
* Update outdated patterns to follow current writing style conventions.
* Emphasize compression and cleanup throughout all phases.

Discover applicable `.github/instructions/*.instructions.md` files based on file types and technologies involved, and proceed with the Required Phases.
