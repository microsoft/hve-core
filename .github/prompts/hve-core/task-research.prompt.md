---
description: "Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core"
agent: task-researcher
argument-hint: "topic=... [chat={true|false}]"
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for research analysis.
* ${input:topic}: (Required) Primary topic or focus area, from user prompt or inferred from conversation.

## Requirements

1. When chat is enabled, incorporate conversation context to refine research scope and identify implicit constraints.
2. Scope research to the provided topic, including related files, patterns, and external references.
3. Evaluate implementation alternatives and select a recommended approach with evidence-based rationale.
4. Produce a consolidated research document at the standard tracking location for handoff to implementation planning.
