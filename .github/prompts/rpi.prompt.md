---
description: "Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core"
agent: rpi-agent
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

## Requirements

1. When `${input:task}` is provided, use it as the primary task description. When absent, infer the task from conversation context, attached files, or the currently open file.
2. Map `${input:auto}` to the agent's autonomy modes: `true` activates Full-Autonomous mode, `partial` activates Autonomous mode, and `false` restricts autonomous continuation.
3. When `${input:continue}` is provided, proceed directly to Phase 1 with the referenced suggested work items from the prior Phase 5 output.
4. When `${input:suggest}` is provided, proceed directly to Phase 5 to discover and present next work items.
5. Summarize completion with phases completed, iteration count, artifacts created, and final validation status.
