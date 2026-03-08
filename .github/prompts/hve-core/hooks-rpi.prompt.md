---
description: "Autonomous Research-Plan-Implement-Review-Discover workflow for completing tasks - Brought to you by microsoft/hve-core"
agent: Hooks - RPI Agent
argument-hint: "task=... [continue={1|2|3|all}] [suggest]"
---

# RPI

## Inputs

These inputs provide explicit signals to the agent. When not provided, the agent infers intent from conversation context.

* ${input:task}: (Required) Task description from user prompt or conversation context.
* ${input:continue}: (Optional) Continue with suggested work items. Accepts a number (1, 2, 3), multiple numbers (1,2), or "all".
* ${input:suggest}: (Optional) Trigger Phase 5 to discover and suggest next work items.

## Requirements

1. When `${input:task}` is provided, use it as the primary task description. When absent, infer the task from conversation context, attached files, or the currently open file.
2. When `${input:continue}` is provided, proceed directly to Phase 1 with the referenced suggested work items from the prior Phase 5 output.
3. When `${input:suggest}` is provided, proceed directly to Phase 5 to discover and present next work items.
4. Summarize completion with phases completed, iteration count, artifacts created, and final validation status.

## Conversation History Summarization and Compaction Requirements

The following must be included in the response from summarization and compaction.

* Make sure summarization includes that all state is managed through the .copilot-tracking folder files.
* Always include file paths for all of the Tracking Artifacts for this session.
* Indicate percent complete for each of the artifacts.
* Include the last Phase before compaction, steps of phase completed, in-progress step of phase, remaining steps of phase.
* Be sure to include executive details for each of the most recent findings from `Phase 4: Review`, assume these details are not stored anywhere.
* Must include all of the most recent follow up work items and their numbered order from `Phase 5: Discover`, assume these details are not stored anywhere.
