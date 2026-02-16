---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: prompt-builder
argument-hint: "[files=...] [promptFiles=...] [requirements=create or update based on target files otherwise improve and cleanup existing promptFiles]"
---

# Prompt Build

## Inputs

* (Optional) files - ${input:files}: Target file(s) to use as reference for creating or modifying prompt file(s). Defaults to the current open file or attached file(s).
* (Optional) promptFiles - ${input:promptFiles}: New or existing target prompt file(s) for creation or modification. Defaults to the current open file or attached file.
* (Optional) requirements - ${input:requirements:create or update based on target files otherwise improve and cleanup existing promptFiles}: Requirements or objectives.

## Prompt File(s) Requirements

When the user provides `files`, unless otherwise indicated, requirements should be updated to include:

1. Identify prompt instruction file(s) that relate to the target files.
2. Prompt instruction file(s) should be updated or created to be able to produce target files.

## Required Protocol

Follow all instructions in Required Phases, iterate and repeat Required Phases until promptFiles or related prompt file(s) meet the requirements.
