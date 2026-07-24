---
description: 'Create or improve prompt-engineering artifacts through the HVE Builder lifecycle'
agent: Prompt Builder
argument-hint: "[promptFiles=...] [files=...] [requirements=...]"
---

# Prompt Build

## Inputs

* `${input:promptFiles}`: approved target prompt, instruction, agent, subagent, skill, reference, or template files; defaults to current open or attached files
* `${input:files}`: reference artifacts that inform requirements and remain read-only unless explicitly added to the write boundary
* `${input:requirements}`: objectives, constraints, and acceptance criteria

## Requirements

1. Route missing targets to `hve-builder` create mode and existing targets to improve mode.
2. Treat `promptFiles` as the source-write boundary and `files` as reference context unless the user explicitly says otherwise.
3. Complete independent static review, behavior testing at the intended profile and fidelity, and host validation before reporting Pass.
4. Return the HVE Builder overall outcome and evidence links without running the retired Prompt Builder phase loop.
