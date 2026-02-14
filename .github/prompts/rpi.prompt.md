---
description: "Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core"
agent: 'rpi-agent'
argument-hint: "task=... [auto={true|partial|false}] [continue={1|2|3|all}] [suggest]"
---

# RPI

## Inputs

These inputs provide explicit signals to the agent. When not provided, the agent infers intent from conversation context.

* ${input:task}: (Required) Task description from user prompt or conversation context.
* ${input:auto:partial}: (Optional) Controls autonomous continuation.
  * `true` - Full autonomy. Continue with all next work items automatically.
  * `partial` - (Default) Continue with obvious items. Present options when unclear.
  * `false` - Always present options for user selection.
* ${input:continue}: (Optional) Continue with suggested work items. Accepts a number (1, 2, 3), multiple numbers (1,2), or "all".
* ${input:suggest}: (Optional) Trigger Phase 5 to discover and suggest next work items.

## Required Steps

### Step 1: Execute RPI Workflow

Act as an agent orchestrator, dispatching all phase work through subagents. Follow the Required Phases from the mode instructions, using the `runSubagent` or `task` tool for each phase step. Pass the user's task and autonomy inputs to the phase workflow.

### Step 2: Return Results

Summarize completion:

* Phases completed and iteration count.
* Artifacts created in `.copilot-tracking/`.
* Final validation status.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all phase work, and proceed with the user's task.
