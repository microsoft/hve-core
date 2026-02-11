---
description: "Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core"
agent: 'rpi-agent'
maturity: stable
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

Invoke rpi-agent mode to complete the task autonomously through the 5-phase workflow:

* Research - Gather context, discover applicable instructions and skills, identify patterns
* Plan - Create implementation plan referencing discovered instructions and skills
* Implement - Execute plan following all referenced instructions and skills
* Review - Validate against instructions compliance and iterate until complete
* Discover - Identify next work items through parallel subagent research and continue or present options

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
