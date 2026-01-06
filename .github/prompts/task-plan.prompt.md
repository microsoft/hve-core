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

* Validate the ${input:research} exists
* Otherwise, find a likely candidate for research document(s) in the .copilot-tracking/research/ directory
  * Avoid reading the research documents at this stage to prevent reading in the wrong information
  * Factor in recency and the conversation context to select the correct research document based on name
  * When multiple research documents are likely candidates then ask the user which one or several to pick (offer a recommendation)
  * Inform the user which research document(s) you will proceed using for task planning
* If there are no candidates for a research document then inform the user that they should use `task-researcher` before proceeding with task planning
  * The user may proceed without a research document, use all available resources that were provided to complete task planning

### 2. Analyze User Request

Identify the task(s) to plan from the conversation and the selected research document(s)

* Read in the research document(s)
* Review related documents as needed based on the task(s) to plan

Inform the user the task(s) that you will be planning

* When task(s) to plan are not clear then offer suggestions to the user based on the conversation and the research document(s)
* Inform the user which task(s) you will be planning then proceed creating the task plan files and file structure

### 3a. Review Codebase and Context

Use the runSubagent tool when available, when reviewing or reading in files needed for context gathering and planning

* Provide the runSubagent tool the research document(s) and context on what information it needs to gather
* Make sure the runSubagent tool is thorough in its own investigation and have it respond back with its reasoning on where modifications will be required
* Keep subsequent runSubagent tool calls consistent by providing any updated context or reasoning when initiating new runSubagent tool calls
* Use the response from the runSubagent tool to determine which files will require changes

Review the codebase deeply based on the information you've gathered from the conversation and the selected research document(s)

* Determine all existing files and folders that will require modifications
* Determine new files and folders that will be needed

Determine conventions, standards, and styling

* Make sure any instructions files that are needed are referenced in the task planning files
* Make sure existing conventions, standards, and styling are followed based on existing related or neighbor files

### 3b. Progressively Identify and Adjust Scope of Changes

While reviewing research document(s), codebase files/folders, tool responses for external sources of information, progressively identify if the changes needed for the task(s) to plan are small and targeted or if changes will require larger architectural and/or restructuring modifications

* Always prefer building high quality idiomatic modifications that follow the existing conventions, standards, and styling of the codebase
* Planning code modifications should typically follow SOLID principles
* Avoid planning modifications that would introduce branching one-off logic when a new or existing pattern may need to be introduced instead
* Planning task(s) for larger architectural and/or restructuring modifications are always acceptable and likely, be sure to inform the user when this approach may be unexpected based on the conversation and research document(s)

### 3c. Progressively Update Task Plan Files

Progressively update task plan files as information is discovered

* Add implementation details and files/folders requiring modifications progressively
* Update existing implementation details or plan steps as new information is discovered requiring changes to the plan
* Remove implementation details, plan steps, tasks from task plan files as new information is discovered requiring changes to the plan
* Reorganize tasks and steps as new information is added, removed, or updated

### 4. Keep User Informed

As details are identified make sure the user is updated with this information

* Keep the updates to the user concise and formatted for the user to easily follow along
* Adjust direction based on the user interrupting or making suggestions
* Larger divergence should be brought to the user's attention while planning, e.g., when it seems like a small change would be better by introducing a new pattern

Make sure the user understands which task(s) will be (or have been) planned and which task(s) or details requiring planning have not been planned
* Identify out of the research document(s) or conversation any task(s) that were not planned
* Identify any details that were excluded from the task plan files that should go into task planning (either future task planning documents or were accidentally excluded)

---

Proceed with planning following the Planning Protocol.
