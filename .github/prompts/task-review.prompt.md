---
description: "Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core"
agent: 'task-reviewer'
---

# Task Review

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for review analysis.
* ${input:plan}: (Optional) Implementation plan file path.
* ${input:changes}: (Optional) Changes log file path.
* ${input:research}: (Optional) Research file path.
* ${input:scope}: (Optional) Time-based scope such as "today", "this week", or "since last review".

## Required Steps

Act as an agent orchestrator. Follow the Required Phases from the mode instructions, dispatching `artifact-validator` and `codebase-researcher` subagents for all validation work.

### Step 1: Determine Review Scope

Identify artifacts to review using this priority:

1. Use explicitly provided inputs (`${input:plan}`, `${input:changes}`, `${input:research}`).
2. Use attached files or currently open files.
3. Apply `${input:scope}` when provided.
4. Default to artifacts since the last review log.

### Step 2: Execute Review

Follow the mode's review phases to validate the implementation against the identified artifacts.

### Step 3: Report Findings

Summarize the review outcome:

* Critical and major findings requiring attention.
* Missing work items with source references.
* Follow-up work items with recommendations.
* Review log file path.
* Recommended next steps based on overall status.

---

Follow the Required Phases from the mode instructions, dispatching subagents for all validation work, and proceed with the review.
