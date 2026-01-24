---
description: "Autonomous Research-Plan-Implement-Review workflow for completing tasks - Brought to you by microsoft/hve-core"
agent: 'rpi-agent'
maturity: stable
---

# RPI

## Inputs

* ${input:task}: (Required) Task description from user prompt or conversation context

## Required Steps

### Step 1: Execute RPI Workflow

Invoke rpi-agent mode to complete the task autonomously through the 4-phase workflow:

* Research - Gather context and identify patterns
* Plan - Create implementation plan with success criteria
* Implement - Execute plan and update tracking artifacts
* Review - Validate and iterate until complete

The agent dispatches specialized subagents for each phase and iterates until all success criteria are satisfied.

### Step 2: Return Results

Summarize completion:

* Phases completed and iteration count
* Artifacts created in `.copilot-tracking/`
* Final validation status

---

Invoke rpi-agent mode and proceed with the user's task.
