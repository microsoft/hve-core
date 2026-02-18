---
description: "Locates and executes implementation plans using task-implementor - Brought to you by microsoft/hve-core"
agent: task-implementor
argument-hint: "[plan=...] [phaseStop={true|false}] [stepStop={true|false}]"
---

# Task Implementation

## Inputs

* ${input:plan}: (Optional) Implementation plan file, determined from the conversation, prompt, or attached files.
* ${input:phaseStop:false}: (Optional, defaults to false) Stop after each phase for user review.
* ${input:stepStop:false}: (Optional, defaults to false) Stop after each step for user review.

## Requirements

1. Locate the implementation plan using this priority: use `${input:plan}` when provided, check the currently open file for plan content, extract a plan reference from an open changes log, or select the most recent file in `.copilot-tracking/plans/`.
2. When `${input:phaseStop}` is true, pause after completing each phase and present progress before continuing.
3. When `${input:stepStop}` is true, pause after completing each step within a phase and present progress before continuing.
4. Summarize implementation progress when pausing: phases and steps completed, blockers or clarification requests, and next resumption point.

## Required Protocol

Follow the agent's Required Phases for plan analysis, iterative execution, and consolidation. Apply stop controls from the inputs to govern pause behavior between phases and steps.
