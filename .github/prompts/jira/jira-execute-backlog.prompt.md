---
description: 'Execute a Jira backlog plan by creating, updating, transitioning, and commenting on issues from a handoff file'
agent: Jira Backlog Manager
argument-hint: "handoff=... [autonomy={full|partial|manual}] [dryRun={true|false}]"
---

# Execute Jira Backlog Plan

Execute planned Jira operations from a reviewed handoff file.

Follow all instructions from #file:../../instructions/jira/jira-backlog-update.instructions.md while executing this workflow.
Follow all instructions from #file:../../instructions/jira/jira-backlog-planning.instructions.md for shared conventions.

## Inputs

* `${input:handoff}`: (Required) Path to the handoff plan file (`handoff.md` or `triage-plan.md`).
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates. Values: `full`, `partial`, `manual`.
* `${input:dryRun:false}`: (Optional, defaults to false) When true, simulate all operations without modifying Jira state.

## Requirements

1. Require `${input:handoff}` as the execution source and ask the user for the correct path before proceeding when the file is missing.
2. Validate and execute the handoff using the delegated Jira backlog execution workflow, processing operations in Create, Update, Transition, then Comment order.
3. Resume from existing `handoff-logs.md` state when present; otherwise initialize `handoff-logs.md` next to `${input:handoff}` from the handoff contents.
4. Respect `${input:autonomy}` for confirmation gates and `${input:dryRun}` for simulation-only execution.
5. Update handoff checkboxes, resolve `{{TEMP-N}}` placeholders to actual issue keys or logged failures, and return a completion summary with counts, issue keys, and corrective actions when needed.