---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "file=... [requirements=...]"
maturity: stable
---

# Prompt Build

This prompt delegates to the *prompt-builder* agent, which provides the phase-based protocol for authoring prompt engineering artifacts. The steps below prepare inputs and track progress while the mode handles research, authoring, and validation phases.

## Inputs

* ${input:file}: (Optional) Target file for the existing or new prompt instructions file. Defaults to the current open file or attached file.
* ${input:requirements}: (Optional) Additional requirements or context from the user request.

## Required Steps

**Important requirements**:

* **Important**, always be thorough and accurate.
* Analyze the user request and conversation context to determine the operation and requirements.
* Avoid reading prompt instructions files, relying on subagents to read and modify them unless validation or required instructions call for direct access.
* Leverage subagents for all research including reading and discovering related files and folders.
* Use the runSubagent tool when dispatching subagents. When the tool is unavailable, follow the subagent instructions directly or stop if the task requires runSubagent.
* Follow all of the below steps and follow all instructions from the Required Phases section.
* Avoid overly verbose instructions and examples.
* Refactor instructions and examples continually.

### Step 1: Interpret User Request

* Work with the user as needed to interpret their request accurately.
* Update the conversation and keep track of requirements as they're identified.

When no explicit requirements are provided, infer the operation:

* When referencing an existing prompt instructions file, refactor, clean up, and improve all instructions in that file.
* When referencing any other file, search for related prompt instructions files and update them with conventions, standards, and examples identified from the referenced and related files.
* When no related prompt instructions file is found, build a new prompt instructions file based on the referenced and related files.

### Step 2: Iterate the Protocol

Pass all identified requirements to the prompt-builder mode's protocol phases. Continue iterating until:

1. All requirements are addressed.
2. Prompt Quality Criteria from the mode's instructions pass for all related prompt instructions files.

When dispatching subagents for research or editing tasks:

* Use the runSubagent tool to dispatch each subagent. When it is unavailable, follow the subagent instructions directly or stop if the task requires runSubagent.
* Specify which instructions files or agents the subagent follows.
* Provide a structured response format or target file for subagent output.
* Allow subagents to respond with clarifying questions rather than guessing.

### Step 3: Report Outcomes

After protocol completion, summarize the session:

* Files created or modified with paths.
* Requirements addressed and any deferred items.
* Validation results from Prompt Quality Criteria.

## Required Phases

* Follow the prompt-builder agent Required Phases in order. Use the agent to manage phase transitions and validation criteria.

---

Proceed with the user's request following the Required Steps.
