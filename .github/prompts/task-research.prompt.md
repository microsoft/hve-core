---
description: "Initiates research for implementation planning based on user requirements - Brought to you by microsoft/hve-core"
agent: 'task-researcher'
---

# Task Research

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for research analysis
* ${input:topic}: (Required) Primary topic or focus area, from user prompt or inferred from conversation

## Tool Availability

This workflow dispatches subagents for all research activities. Prefer the task tool for subagent dispatch when available, specifying the agent type (`codebase-researcher` or `external-researcher`) and execution mode. Fall back to the `runSubagent` tool, instructing the subagent to read and follow the corresponding `.github/agents/` file.

* When the task tool or runSubagent is available, proceed with subagent dispatch as described in each step.
* When neither is available, inform the user that subagent dispatch is required for this workflow and stop.

## Required Steps

**Important requirements**, repeat to yourself these important requirements:

* **Important**, always be thorough and accurate.
* Avoid making the research document overly verbose when not required.
* Make sure the research document is complete and provides evidence.
* Whenever unsure about anything then have runSubagent collect more research with any of the tools that you have available.
* Repeat steps and phases as needed to be thorough and accurate.

### Step 1: Define Research Scope

Identify what the user wants to accomplish:

* Extract the primary objective from user prompt and conversation context.
* Note features, behaviors, constraints, and exclusions.
* Formulate specific questions the research must answer.

### Step 2: Locate or Create Research Document

Check `.copilot-tracking/research/` for existing files matching `{{YYYY-MM-DD}}-*-research.md`:

* Extend an existing document when relevant to the topic.
* Create a new document at `.copilot-tracking/research/{{YYYY-MM-DD}}-<topic>-research.md` otherwise.

### Step 3: Dispatch Research Subagents

Dispatch `codebase-researcher` and `external-researcher` agents for all research activities. Use the task tool (preferred) or `runSubagent` to dispatch. Subagents can run in parallel when investigating independent topics using parallel execution mode.

#### Subagent Instructions

For `codebase-researcher` agents (workspace investigation):

* Read and follow `.github/instructions/` files relevant to the research topic.
* Assign a specific research question or investigation target.
* Search the workspace for patterns, implementations, and conventions.
* Write findings to `.copilot-tracking/subagent/{{YYYY-MM-DD}}/<topic>-research.md`.
* Include source references, file paths with line numbers, and evidence.

For `external-researcher` agents (external documentation):

* Assign documentation targets (SDKs, APIs, URLs).
* Use your MCP tools for external documentation, SDK, API, and code sample research.
* Use your HTTP and GitHub tools to search official repositories for patterns and examples.
* Write findings to `.copilot-tracking/subagent/{{YYYY-MM-DD}}/<topic>-research.md`.
* Include source URLs and documentation excerpts.

#### Subagent Response Format

Each subagent returns a structured response:

```markdown
## Research Summary

**Question:** {{research_question}}
**Status:** Complete | Incomplete | Blocked
**Output File:** {{file_path}}

### Key Findings

* {{finding_1}}
* {{finding_2}}

### Clarifying Questions (if any)

* {{question_for_parent}}
```

Subagents may respond with clarifying questions when instructions are ambiguous.

### Step 4: Synthesize Findings

Consolidate subagent outputs into the main research document:

* Add objectives to **Task Implementation Requests**.
* Record leads in **Potential Next Research**.
* Remove or revise content when new findings contradict earlier assumptions.
* Dispatch additional subagents when gaps are identified.

### Step 5: Return Findings

Summarize research outcomes:

* Highlight key discoveries and their implementation impact.
* List remaining alternatives needing decisions.
* Provide the research document path for handoff to implementation planning.

---

Invoke task-researcher mode and proceed with the Required Steps.
