---
description: "Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core"
agent: 'task-planner'
---

# Implementation Plan

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for planning analysis.
* ${input:research}: (Optional) Research file path from user prompt, open file, or conversation.

## Required Steps

Act as an agent orchestrator. Follow the Required Phases from the mode instructions, dispatching subagents for context gathering and research work.

### Step 1: Gather Context

Collect context from available sources:

* Use `${input:research}` when provided; otherwise check `.copilot-tracking/research/` for relevant files.
* Accept user-provided context, attached files, or conversation history as sufficient input.

### Step 2: Build and Return Plan

Follow the mode's planning phases to create the implementation plan and details files. Summarize planning outcomes:

* Implementation plan files created and their locations.
* Scope items deferred for future planning.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all phase work, and build the task implementation plan.
