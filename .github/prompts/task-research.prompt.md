---
description: "Initiates research for task implementation based on user requirements and conversation context - Brought to you by microsoft/hve-core"
agent: 'task-researcher'
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include the full chat conversation context for research analysis
* ${input:topic}: (Required) Primary topic or focus area for research, provided by user prompt or inferred from conversation

## Research Steps

### 1. Analyze User Request

Extract from the user's prompt:

* **Primary Objective**: What the user is trying to accomplish
* **Key Requirements**: Specific features, behaviors, or constraints mentioned
* **Scope Boundaries**: What is explicitly in or out of scope

### 2. Synthesize Conversation Context

If `${input:chat}` is true (default), extract from the conversation history:

* **Prior Decisions**: Directions already established
* **Rejected Approaches**: Approaches the user has ruled out
* **Referenced Resources**: Files, URLs, or tools mentioned
* **Technical Constraints**: Technology or architecture constraints discussed

### 3. Identify Research Targets

From steps 1-2, compile:

* **Files to Analyze**: Explicit and implicit file references from context
* **External Sources**: URLs, documentation, or APIs to investigate
* **Instruction Files**: Applicable `*.instructions.md` or `copilot/` files for the topic
* **Research Questions**: Specific questions that must be answered

### 4. Begin Deep Research

Proceed with the Task Researcher protocol:

* Create or update the research document at `.copilot-tracking/research/YYYYMMDD-<topic>-research.md`
* Populate **Task Implementation Requests** with the synthesized objectives
* Add identified research targets to **Potential Next Research**
* Execute deep research using `runSubagent` for all tool-based investigation

---

Proceed with research initiation following the Research Steps.
