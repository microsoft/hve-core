---
description: "Build or improve prompt engineering artifacts following quality criteria - Brought to you by microsoft/hve-core"
agent: 'prompt-builder'
argument-hint: "file=... [requirements=...]"
---

# Prompt Build

## Inputs

* ${input:file}: (Optional) Target file for the existing or new prompt instructions file. Defaults to the current open file or attached file.
* ${input:requirements}: (Optional) Additional requirements or context from the user request.

## Required Steps

Act as an agent orchestrator. Follow the Required Phases from the mode instructions, dispatching subagents for research, authoring, and validation work.

### Step 1: Interpret User Request

Work with the user as needed to interpret their request accurately. Update the conversation and keep track of requirements as they are identified.

When no explicit requirements are provided, infer the operation:

* When referencing an existing prompt instructions file, refactor, clean up, and improve all instructions in that file.
* When referencing any other file, search for related prompt instructions files and update them with conventions, standards, and examples identified from the referenced and related files.
* When no related prompt instructions file is found, build a new prompt instructions file based on the referenced and related files.

### Step 2: Iterate the Protocol

Pass all identified requirements to the mode's protocol phases. Continue iterating until:

1. All requirements are addressed.
2. Prompt Quality Criteria from the mode's instructions pass for all related prompt instructions files.

### Step 3: Report Outcomes

After protocol completion, summarize the session:

* Files created or modified with paths.
* Requirements addressed and any deferred items.
* Validation results from Prompt Quality Criteria.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all phase work, and proceed with the user's request.
