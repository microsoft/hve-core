---
description: "Locates and executes implementation plans using task-implementor mode - Brought to you by microsoft/hve-core"
agent: 'task-implementor'
---

# Task Implementation

## Inputs

* ${input:plan}: (Optional) Implementation plan file, determined from the conversation, prompt, or attached files
* ${input:phaseStop:false}: (Optional, defaults to false) Stop after each phase for user review
* ${input:stepStop:false}: (Optional, defaults to false) Stop after each step for user review

## Required Steps

* Prioritize thoroughness and accuracy throughout implementation.
* Run additional research subagents when uncertain about any detail.
* When remaining unclear after research, return findings to the parent agent for escalation.
* Update the changes document when discovering new details.
* Ensure the changes document is complete and accurate.
* Repeat steps as needed to achieve thoroughness and accuracy.

### Step 1: Locate Implementation Plan

Find the implementation plan using this priority:

1. Use ${input:plan} when provided.
2. Check the currently open file for plan, details, or changes content.
3. Extract plan reference from an open changes log.
4. Select the most recent file in `.copilot-tracking/plans/`.

Run a `codebase-researcher` agent as a subagent for file discovery when the plan location is unclear. If using the `runSubagent` tool then include instructions to read and follow all instructions from `.github/agents/codebase-researcher.agent.md`. The subagent returns the plan file path and associated details/changes paths.

### Step 2: Determine Resume Point

Inspect the implementation plan for completion status:

* Identify checked checkboxes (`[x]`) as completed steps.
* Read the changes log to understand current implementation state.
* Resume from the first uncompleted phase or step.

### Step 3: Execute Implementation

Invoke task-implementor mode with the located plan:

* Follow stop controls: pause after each phase when ${input:phaseStop} is true; pause after each step when ${input:stepStop} is true.
* Run `codebase-researcher` agents as subagents for inline research when context is missing. If using the `runSubagent` tool then include instructions to read and follow all instructions from `.github/agents/codebase-researcher.agent.md`. Subagents return findings to `.copilot-tracking/subagent/{{YYYY-MM-DD}}/<topic>-research.md`.
* Update the changes log as steps complete.

### Step 4: Report Progress

Summarize implementation progress, without leaving off important details:

* List phases and steps completed in this session.
* Note any blockers or clarification requests.
* Provide the next resumption point when pausing.

---

Invoke task-implementor mode and proceed with the Required Steps.
