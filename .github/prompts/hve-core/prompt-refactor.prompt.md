---
description: "Refactors and cleans up prompt engineering artifacts through iterative improvement - Brought to you by microsoft/hve-core"
argument-hint: "[promptFiles=...] [requirements=...]"
agent: Prompt Builder
---

# Prompt Refactor

## Inputs

* (Optional) promptFiles - ${input:promptFiles}: Existing target prompt file(s) for creation or modification. Defaults to the current open file or attached file.
* (Optional) requirements - ${input:requirements}: Additional requirements or objectives.

## Prompt File(s) Requirements

1. Refactor the promptFiles with a focus on cleaning up instructions, consolidating instructions, removing confusing instructions, removing duplicate instructions or examples when they are not needed.
2. If user provided additional requirements in the conversation then be sure to also consider all of their requirements as well.

## Required Protocol

Follow all instructions in Required Phases, iterate and repeat Required Phases until promptFiles or related prompt file(s) meet the requirements.
