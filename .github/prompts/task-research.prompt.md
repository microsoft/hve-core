---
description: "Initiates research for task implementation based on user requirements and conversation context - Brought to you by microsoft/hve-core"
agent: 'task-researcher'
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include the full chat conversation context for research analysis
* ${input:topic}: (Required) Primary topic or focus area for research, provided by user prompt or inferred from conversation

## Research Protocol

### 1. Analyze User Request

Identify what the user wants to accomplish from their prompt:

* Determine the primary objective that will drive the research focus
* Note any specific features, behaviors, or constraints the user has mentioned
* Clarify what is explicitly in scope and what should be excluded

### 2. Synthesize Conversation Context

If `${input:chat}` is true (default), review the conversation history for relevant context:

* Identify directions already established that should not be revisited
* Note any approaches the user has explicitly ruled out
* Collect files, URLs, or tools that were mentioned as relevant
* Understand any technology or architecture constraints that apply

### 3. Identify Research Targets

Compile what needs to be researched based on the user request and conversation context:

* List files to analyze, including those explicitly referenced and others likely relevant to the topic
* Identify external sources such as documentation, APIs, or reference implementations to investigate
* Find applicable instruction files (`*.instructions.md`) that define conventions for the topic area
* Formulate specific questions that the research must answer

Confirm the research scope and targets with the user before proceeding to deep research.

### 4. Locate or Create Research Document

Check for existing research before starting a new document:

* Search `.copilot-tracking/research/` for files matching `YYYYMMDD-*-research.md` that relate to the topic
* If a relevant document exists, confirm with the user whether to extend it or start fresh
* If no relevant document exists, create one at `.copilot-tracking/research/YYYYMMDD-<topic>-research.md` using the topic from `${input:topic}` or derived from the primary objective

### 5. Execute Deep Research

Use `runSubagent` when available to parallelize investigation across research targets:

* Provide runSubagent with the specific questions and targets identified in step 3, along with any relevant context from the conversation
* Have runSubagent respond with detailed findings and reasoning about what was discovered
* Keep subsequent runSubagent calls consistent by including key findings from prior responses
* Have runSubagent write detailed findings to subagent research files for reference

Synthesize runSubagent responses into the main research document as findings emerge:

* Add synthesized objectives to the **Task Implementation Requests** section
* Record new research leads in the **Potential Next Research** section
* Incorporate findings, code examples, and references as they are discovered
* Remove or revise information when new findings contradict earlier assumptions

### 6. Keep User Informed

Communicate progress and discoveries throughout the research:

* Summarize significant findings and explain their impact on the task
* Flag when research reveals the scope is larger or more complex than expected
* Pause for user input when multiple viable approaches emerge with different trade-offs

When pausing or at natural stopping points, provide the user with:

* A summary of what has been researched and the key findings so far
* Any research targets that were identified but not yet explored

---

Proceed with research initiation following the Research Protocol.
