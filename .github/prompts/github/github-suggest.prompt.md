---
description: "Resume GitHub backlog management workflow after session restore - Brought to you by microsoft/hve-core"
agent: GitHub Backlog Manager
argument-hint: "[optional: description of restored session context]"
---

# GitHub Suggest

Review the restored session context from the memory agent and propose the next workflow step for the current backlog management task.

## Instructions

1. Inspect the conversation history and any memory files referenced in context.
2. Identify the last completed backlog workflow step (Discovery, Triage, Sprint Planning, or Execution).
3. Summarize what was completed and what planning artifacts exist.
4. Propose the next logical workflow step with a ready-to-use prompt.

If no prior backlog context is found, recommend starting with Discovery and provide a sample prompt.
