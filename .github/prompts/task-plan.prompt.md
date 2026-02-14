---
description: "Initiates implementation planning based on user context or research documents - Brought to you by microsoft/hve-core"
agent: 'task-planner'
---

# Implementation Plan

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for planning analysis
* ${input:research}: (Optional) Research file path from user prompt, open file, or conversation

## Required Steps

* Prioritize thoroughness and accuracy throughout planning.
* Run additional research subagents when uncertain about any detail.
* When remaining unclear after research, return findings to the parent agent for escalation.
* Refactor the plan documents as needed when discovering new details.
* Ensure the plan documents are complete and accurate.
* Repeat steps as needed to achieve thoroughness and accuracy.

### Step 1: Gather Context

Collect context from available sources:

* Use ${input:research} when provided; otherwise check `.copilot-tracking/research/` for relevant files.
* Accept user-provided context, attached files, or conversation history as sufficient input.
* Run `codebase-researcher` agents as subagents when additional codebase analysis is needed. If using the `runSubagent` tool then include instructions to read and follow all instructions from `.github/agents/**/codebase-researcher.agent.md`.

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
