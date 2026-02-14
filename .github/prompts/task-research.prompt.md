---
description: "Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core"
agent: 'task-researcher'
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for research analysis.
* ${input:topic}: (Required) Primary topic or focus area, from user prompt or inferred from conversation.

## Required Steps

Act as an agent orchestrator. Follow the Required Phases from the mode instructions, dispatching `codebase-researcher` and `external-researcher` subagents for all research activities.

### Step 1: Define Research Scope

Identify what the user wants to accomplish:

* Extract the primary objective from user prompt and conversation context.
* Note features, behaviors, constraints, and exclusions.

### Step 2: Execute Research

Follow the mode's research phases to run subagents, synthesize findings, and produce the research document.

### Step 3: Return Findings

Summarize research outcomes:

* Key discoveries and their implementation impact.
* Remaining alternatives needing decisions.
* Research document path for handoff to implementation planning.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all research work, and proceed with the user's topic.
