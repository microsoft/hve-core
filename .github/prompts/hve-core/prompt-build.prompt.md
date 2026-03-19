---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: Prompt Builder
argument-hint: "[files=...] [promptFiles=...] [create or update based on target files otherwise improve and cleanup existing promptFiles]"
---

# Prompt Build

## Inputs

* (Optional) files - ${input:files}: Target file(s) to use as reference for creating or modifying prompt file(s). Defaults to the current open file or attached file(s).
* (Optional) promptFiles - ${input:promptFiles}: New or existing target prompt file(s) for creation or modification. Defaults to the current open file or attached file.

## Prompt File(s) Requirements

Thoroughly and accurately create, modify, improve, clean up, and refactor promptFiles based on the user provided requirements.

When the user provides files and/or promptFiles, with no other requirements then the requirements should be:

1. Identify prompt instruction file(s) that relate to the target files if provided.
2. Prompt instruction file(s) should be modified or created to be able to produce target files.
3. The promptFiles should be improved and cleaned up.

## Required Protocol

Follow all instructions in Required Phases, iterate and repeat Required Phases until promptFiles or related prompt file(s) meet the requirements.
