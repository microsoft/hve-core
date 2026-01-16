---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "file=... [requirements=...]"
maturity: stable
---

# Prompt Build

## Inputs

* ${input:file}: (Optional) Target file for the existing or new prompt instructions file. Defaults to the current open file or attached file.
* ${input:requirements}: (Optional) Additional requirements or context from the user request.

## Required Steps

* Think hard and analyze the user request and conversation context to determine the operation and requirements.
* Always avoid reading in prompt instructions files, instead rely on subagents to read and modify prompt instructions files.
* Leverage subagents for all research including reading and discovering related files and folders.
* Follow all of the below steps and be sure to follow all instructions from the Required Phases section.

### Step 1: Interpret the user request

* Work with the user as needed to interpret their request accurately.
* Update the conversation and keep track of requirements as they're identified.

When no requirements are provided then use the following:

* When referencing an existing prompt instructions file then refactor, cleanup, and improve all instructions in the prompt instructions file.
* When referencing any other file then first search for any related prompt instructions files and update them with the conventions, standards, examples, identified from the referenced and related files.
* When no other prompt instructions file is found then assume the user wants to build a new prompt instructions file based on the referenced and related files.

### Step 2: Iterate the Required Protocol

* Pass all requirements while iterating on the Required Protocol.
* Continue to iterate until all requirements are met and all of the Prompt Quality Criteria passes for all related prompt instructions files.

### Step 3: Reprot outcomes

* Report outcomes after iterating the protocol to completion

---

Proceed with the user's request following the Required Steps.
