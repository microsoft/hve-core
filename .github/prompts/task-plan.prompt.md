---
description: "Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core"
agent: 'task-planner'
maturity: stable
---

# Implementation Plan

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for planning analysis
* ${input:research}: (Optional) Research file path from user prompt, open file, or conversation

## Required Steps

**Important requirements**, repeat to yourself these important requirements:

* **Important**, always be thorough and accurate.
* Whenever unsure about anything then have runSubagent collect more research with any of the tools that you have available.
* When remaining unclear after research, return findings to the parent agent for escalation to deeper research.
* Refactor the plan documents as needed whenever discovering or identifying new details.
* Make sure the plan documents are complete and accurate.
* Repeat steps and phases as needed to be thorough and accurate.

### Step 1: Gather Context

Collect context from available sources:

* Use ${input:research} when provided; otherwise check `.copilot-tracking/research/` for relevant files.
* Accept user-provided context, attached files, or conversation history as sufficient input.
* Dispatch subagents via `runSubagent` when additional codebase analysis is needed.

### Step 2: Analyze and Scope

Extract objectives, requirements, and scope from gathered context:

* Identify files and folders requiring modification or creation.
* Reference applicable instruction files and codebase conventions.
* Prefer idiomatic changes; propose pattern-based approaches when one-off changes would introduce inconsistency.

### Step 3: Build Plan

Create implementation plan and implementation details files:

* Add details and file targets as they are identified.
* Revise steps when new information changes the approach.
* Include phase-level validation and a final validation phase.

### Step 4: Return Results

Summarize planning outcomes:

* List implementation plan files created and their locations.
* Note any scope items deferred for future planning.

---

Build the task implementation plan following the Required Steps.
