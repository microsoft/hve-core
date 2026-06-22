---
description: "Initiate research for implementation planning from user requirements"
agent: Task Researcher
argument-hint: "topic=... [chat={true|false}] [mode={auto|focused|lanes}] [subagents={auto|true|false}]"
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for research analysis.
* ${input:topic}: (Required) Primary topic or focus area, from user prompt or inferred from conversation.
* ${input:mode:auto}: (Optional, defaults to auto) Research mode. Use `auto` for trigger-based selection, `focused` for direct or one-subagent research, and `lanes` for lane-enabled research.
* ${input:subagents:auto}: (Optional, defaults to auto) Subagent fan-out preference. Use `true` to request all applicable research lanes, `false` to avoid lane fan-out unless required, and `auto` to let Task Researcher apply its trigger matrix.

## Requirements

1. When chat is enabled, incorporate conversation context to refine research scope and identify implicit constraints.
2. Scope research to the provided topic, including related files, patterns, and external references.
3. Select direct, focused, or lane-enabled research using Task Researcher's trigger matrix and any explicit `mode` or `subagents` input.
4. Evaluate implementation alternatives and select a recommended approach with evidence-based rationale.
5. Produce a consolidated research document at the standard tracking location for handoff to implementation planning.
