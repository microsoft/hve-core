---
description: "Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core"
agent: task-planner
argument-hint: "[research=...] [chat={true|false}]"
---

# Task Plan

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for planning analysis.
* ${input:research}: (Optional) Research file path from user prompt, open file, or conversation.

## Requirements

1. Use `${input:research}` when provided; otherwise check `.copilot-tracking/research/` for relevant files.
2. Accept user-provided context, attached files, or conversation history as sufficient input for planning.
3. Summarize planning outcomes including implementation plan files created and scope items deferred for future planning.
