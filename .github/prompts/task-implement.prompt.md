---
description: "Locates and executes implementation plans using task-implementor mode - Brought to you by microsoft/hve-core"
agent: 'task-implementor'
maturity: stable
---

# Task Implementation

## Inputs

* ${input:plan}: (Optional) Implementation plan file, could be determined come from the conversation or prompt
* ${input:phaseStop:false}: (Optional, defaults to false) Stop after each phase for user review
* ${input:stepStop:false}: (Optional, defaults to false) Stop after each step for user review

## Required Steps

**Important requirements**, repeat to yourself these important requirements:

* **Important**, always be thorough and accurate.
* Whenever unsure about anything then have runSubagent collect more research with any of the tools that you have available.
* When remaining unclear after research, return findings to the parent agent for escalation to deeper research.
* Update the changes document whenever discovering or identifying new details.
* Make sure the changes document is complete and accurate.
* Repeat steps and phases as needed to be thorough and accurate.

### Step 1: Locate Implementation Plan

Find the implementation plan using this priority:

1. Use ${input:plan} when provided.
2. Check the currently open file for plan, details, or changes content.
3. Extract plan reference from an open changes log.
4. Select the most recent file in `.copilot-tracking/plans/`.

Dispatch a subagent via `runSubagent` for file discovery when the plan location is unclear. The subagent returns the plan file path and associated details/changes paths.

### Step 2: Determine Resume Point

Inspect the implementation plan for completion status:

* Identify checked checkboxes (`[x]`) as completed steps.
* Read the changes log to understand current implementation state.
* Resume from the first uncompleted phase or step.

### Step 3: Execute Implementation

Invoke task-implementor mode with the located plan:

* Follow stop controls: pause after each phase when ${input:phaseStop} is true; pause after each step when ${input:stepStop} is true.
* Dispatch subagents for inline research when context is missing. Subagents return findings to `.copilot-tracking/subagent/{{YYYY-MM-DD}}/<topic>-research.md`.
* Update the changes log as steps complete.

### Step 4: Report Progress

Summarize implementation progress, without leaving off important details:

* List phases and steps completed in this session.
* Note any blockers or clarification requests.
* Provide the next resumption point when pausing.

---

Invoke task-implementor mode and proceed with the Required Steps.
