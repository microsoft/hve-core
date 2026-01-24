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

* Research - Gather context, discover applicable instructions and skills, identify patterns
* Plan - Create implementation plan referencing discovered instructions and skills
* Implement - Execute plan following all referenced instructions and skills
* Review - Validate against instructions compliance and iterate until complete

The agent discovers and applies:

* `.github/instructions/*.instructions.md` - Technology and workflow conventions
* `.github/agents/*.agent.md` - Specialized agent patterns
* `.github/skills/*/SKILL.md` - Executable skill packages

Subagents reference discovered artifacts throughout all phases.

### Step 2: Return Results

Summarize completion:

* Phases completed and iteration count
* Artifacts created in `.copilot-tracking/`
* Final validation status

---

Invoke rpi-agent mode and proceed with the user's task.
