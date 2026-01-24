---
description: "Initiates implementation review based on user context or automatic artifact discovery - Brought to you by microsoft/hve-core"
agent: 'task-reviewer'
maturity: stable
---

# Task Review

## Inputs

* ${input:chat:true}: (Optional, defaults to true) Include conversation context for review analysis
* ${input:plan}: (Optional) Implementation plan file path
* ${input:changes}: (Optional) Changes log file path
* ${input:research}: (Optional) Research file path
* ${input:scope}: (Optional) Time-based scope such as "today", "this week", or "since last review"

## Tool Availability

This workflow dispatches subagents for all validation activities using the runSubagent tool.

* When runSubagent is available, proceed with subagent dispatch as described in each step.
* When runSubagent is unavailable, inform the user that subagent dispatch is required for this workflow and stop.

## Required Steps

**Important requirements**, repeat to yourself these important requirements:

* **Important**, always be thorough and precise.
* Subagents investigate thoroughly and return evidence for all findings.
* When context is insufficient, dispatch additional research subagents rather than asking the user.
* Update the review log continuously as validation progresses.
* Repeat validation steps as needed to be thorough and accurate.

### Step 1: Determine Review Scope

Identify artifacts to review using this priority:

1. Use explicitly provided inputs (${input:plan}, ${input:changes}, ${input:research}).
2. Use attached files or currently open files when they match artifact patterns.
3. Apply time-based filtering when ${input:scope} is provided:
   * "today" - artifacts with today's date prefix.
   * "this week" - artifacts from the past 7 days.
   * "since last review" - artifacts created after the most recent review log.
4. Default to reviewing all artifacts since the last review log when no scope is specified.

Check `.copilot-tracking/reviews/` for existing review logs to determine the baseline.

### Step 2: Locate Related Artifacts

Find all related artifacts for the review scope.

For each changes log identified:

* Extract the **Related Plan** reference to locate the plan file.
* Check the plan file for research references in the **Context Summary** section.
* Build a complete set of related artifacts (research, plan, details, changes).

Dispatch a subagent via `runSubagent` for artifact discovery when file locations are unclear. The subagent returns paths to all related artifacts.

### Step 3: Create or Update Review Log

Create a new review log in `.copilot-tracking/reviews/` or update an existing one:

* Use `{{YYYY-MM-DD}}-task-description-review.md` naming.
* Initialize the review structure with artifact references.
* Begin populating the implementation checklist.

### Step 4: Execute Review

Invoke task-reviewer mode to validate the implementation:

* Extract checklist items from research and plan documents.
* Dispatch validation subagents for file changes, convention compliance, and command execution.
* Dispatch additional research subagents when context is insufficient.
* Update the review log continuously as validation progresses.

### Step 5: Report Findings

Summarize the review outcome:

* List critical and major findings requiring attention.
* Summarize missing work items with source references.
* Summarize follow-up work items with recommendations.
* Provide the review log file path.
* Recommend next steps based on overall status.

---

Invoke task-reviewer mode and proceed with the Required Steps.
