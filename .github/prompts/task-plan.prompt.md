---
description: "Initiates planning for task implementation based on validated research documents - Brought to you by microsoft/hve-core"
agent: 'task-planner'
---

# Task Plan

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include the full chat conversation context for planning analysis
* ${input:research}: (Optional) Research file path that is either, provided by user prompt, the current file the user has open, or inferred through conversation

## Planning Protocol

### 1. Identify Research Document(s)

Locate a research document before reading any content:

* If ${input:research} is provided, validate the file exists and use it
* If not provided, search `.copilot-tracking/research/` for files matching `YYYYMMDD-*-research.md`
  * Select candidates based on filename and recency—do not read content yet
  * Factor in conversation context to identify the most relevant match
  * When multiple candidates exist, present a ranked list with your recommendation and ask the user to confirm
* If no candidates exist, inform the user that `task-researcher` should be used first
  * The user may choose to proceed without a research document; use all available context to complete planning

Confirm with the user which research document(s) will be used before proceeding.

### 2. Analyze User Request

Read the confirmed research document(s) and identify the task(s) to plan:

* Extract objectives, requirements, and scope from the research findings
* Review documents referenced in the research as needed for additional context
* When the task(s) to plan are unclear, offer specific suggestions based on the research and conversation

Inform the user which task(s) you will be planning before proceeding to codebase review.

### 3. Review Codebase and Build Plan

Use the runSubagent tool when available to parallelize context gathering:

* Provide runSubagent with the research document(s) and specific questions about file locations, patterns, and modification targets
* Have runSubagent respond with reasoning on where modifications will be required
* Keep subsequent runSubagent calls consistent by including updated context from prior responses

Based on gathered context, determine:

* All existing files and folders requiring modifications
* New files and folders to create
* Instruction files to reference in the planning files
* Conventions, standards, and styling from neighbor files to follow

### 4. Assess and Adjust Scope

Evaluate whether changes are targeted or require broader architectural work:

* Prefer idiomatic modifications that follow existing codebase conventions
* Apply SOLID principles when planning code modifications
* When a one-off change would introduce inconsistency, propose a pattern-based approach instead
* Architectural or restructuring changes are acceptable—inform the user when this diverges from expectations

### 5. Update Plan Files Iteratively

As information is discovered, update the task plan files:

* Add implementation details and file targets as they are identified
* Revise or remove plan steps when new information changes the approach
* Reorganize tasks and phases to maintain logical flow

### 6. Keep User Informed

Provide concise updates as planning progresses:

* Format updates for the user to easily follow along
* Adjust direction based on user interruptions or suggestions
* Flag larger divergences for user attention, such as when a small change would benefit from introducing a new pattern

At completion, ensure the user understands:

* Which task(s) were planned and are ready for implementation
* Any task(s) or details from the research that were not included in this planning cycle

---

Proceed with planning following the Planning Protocol.
