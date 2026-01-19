---
description: "Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core"
agent: 'task-researcher'
maturity: stable
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for research analysis
* ${input:topic}: (Required) Primary topic or focus area, from user prompt or inferred from conversation

## Required Steps

### Step 1: Define Research Scope

Identify what the user wants to accomplish:

* Extract the primary objective from user prompt and conversation context.
* Note features, behaviors, constraints, and exclusions.
* Formulate specific questions the research must answer.

### Step 2: Locate or Create Research Document

Check `.copilot-tracking/research/` for existing files matching `YYYYMMDD-*-research.md`:

* Extend an existing document when relevant to the topic.
* Create a new document at `.copilot-tracking/research/YYYYMMDD-<topic>-research.md` otherwise.

### Step 3: Execute Research

Use `runSubagent` to parallelize investigation:

* Dispatch subagents with specific questions, targets, and conversation context.
* Have subagents write findings to `.copilot-tracking/subagent/YYYYMMDD/<topic>-research.md`.
* Synthesize findings into the main research document continuously.

Update the research document as findings emerge:

* Add objectives to **Task Implementation Requests**.
* Record leads in **Potential Next Research**.
* Remove or revise content when new findings contradict earlier assumptions.

### Step 4: Return Findings

Summarize research outcomes:

* Highlight key discoveries and their implementation impact.
* List remaining alternatives needing decisions.
* Provide the research document path for handoff to implementation planning.

---

Invoke task-researcher mode and proceed with the Required Steps.
