---
description: "Locates and executes implementation plans using task-implementor mode - Brought to you by microsoft/hve-core"
agent: 'task-implementor'
---

# Task Implementation

## Inputs

* ${input:plan}: (Optional) Implementation plan file, determined from the conversation, prompt, or attached files.
* ${input:phaseStop:false}: (Optional, defaults to false) Stop after each phase for user review.
* ${input:stepStop:false}: (Optional, defaults to false) Stop after each step for user review.

## Required Steps

Act as an agent orchestrator. Follow the Required Phases from the mode instructions, dispatching `phase-implementor` subagents for each plan phase and `codebase-researcher` subagents for inline research.

### Step 1: Locate Implementation Plan

Find the implementation plan using this priority:

1. Use `${input:plan}` when provided.
2. Check the currently open file for plan, details, or changes content.
3. Extract plan reference from an open changes log.
4. Select the most recent file in `.copilot-tracking/plans/`.

### Step 2: Execute Implementation

Follow the mode's phases to execute the plan. Apply stop controls: pause after each phase when `${input:phaseStop}` is true; pause after each step when `${input:stepStop}` is true.

### Step 3: Report Progress

Summarize implementation progress:

* Phases and steps completed in this session.
* Blockers or clarification requests.
* Next resumption point when pausing.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all phase work, and proceed with implementation.
