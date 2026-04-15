---
description: 'Execution workflow for Jira backlog management that consumes planning handoffs and applies sequential Jira operations - Brought to you by microsoft/hve-core'
applyTo: '**/.copilot-tracking/jira-issues/**/handoff-logs.md'
---

# Jira Backlog Update Instructions

Follow all instructions from #file:./jira-backlog-planning.instructions.md for planning file templates, field definitions, content sanitization, and state persistence.

## Purpose and Scope

The execution protocol processes a handoff plan file to create, update, transition, and comment on Jira issues in sequence. The workflow consumes `handoff.md` or `triage-plan.md` and executes planned Jira commands through the documented Jira skill.

All operations execute sequentially. Parallel execution is not supported because create operations may establish `{{TEMP-N}}` mappings used by later steps.

### Outputs

* `handoff-logs.md` created next to the handoff file, containing per-operation processing status and results
* Jira issues created, updated, transitioned, or commented on in the target project

## Issue Processing Order

Process operations in this fixed order:

1. Create
2. Update
3. Transition
4. Comment

## Required Steps

### Step 1: Initialize or Resume

When `handoff-logs.md` exists next to `handoff.md`:

* Read `handoff-logs.md` and `handoff.md`.
* Identify operations with unchecked `[ ]` status.
* Rebuild the temporary ID mapping from previously completed Create entries.
* Resume processing in priority order from the first unchecked operation.

When `handoff-logs.md` does not exist:

* Create `handoff-logs.md` using the template from #file:./jira-backlog-planning.instructions.md.
* Populate the operation log skeleton from `handoff.md`.
* Record all inputs in the execution summary section.

Validate the handoff before processing:

* Confirm the project is set for create actions.
* Confirm each referenced existing issue can be read with `get`.
* Skip `{{TEMP-N}}` placeholders during read validation.
* When create payloads include issue types or field names that are not yet validated, call `fields <project>` before executing.
* Apply the Content Sanitization Guards to all Jira-bound fields.
* Abort on critical failures such as missing project scope for create operations. Warn and continue on non-critical failures.

### Step 2: Process Operations

Use the Jira skill through `.github/skills/jira/jira/scripts/jira.py`.

1. Create issues with `create` using the JSON payload from the handoff plan.
2. Update existing issues with `update <ISSUE-KEY> '<json>'`.
3. Transition issues with `transition <ISSUE-KEY> '<name-or-id>'`.
4. Add comments with `comment <ISSUE-KEY> '<body>'`.

Checkpoint after each operation completes:

* Check the autonomy tier to determine whether a confirmation gate is required.
* When `dryRun` is `true`, simulate the operation and log it as `dry-run` without executing.
* After each Create, resolve the `{{TEMP-N}}` placeholder to the actual Jira issue key returned by the command.
* When a `{{TEMP-N}}` reference appears in a later Update, Transition, or Comment operation, resolve it from the mapping table before execution.
* Update the checkbox to `[x]` in `handoff.md` after each operation completes.
* Append an entry to `handoff-logs.md` recording the issue key, action taken, and any notes.
* On failure, log the error and continue processing remaining operations.

When an operation has no pending changes:

* Mark the checkbox as `[x]` in `handoff.md` with a note: `No changes required.`
* Skip the Jira command.
* Continue to the next operation.

### Step 3: Finalize and Report

* Re-read `handoff-logs.md` and compare against `handoff.md`.
* Retry operations once when they were blocked only by a missing `{{TEMP-N}}` mapping that has since been resolved.
* Cross-check created issues against the plan to confirm all `{{TEMP-N}}` placeholders resolved.
* Generate a handoff summary with counts for created, updated, transitioned, commented, failed, and skipped operations.
* Provide a completion report listing all processed items with Jira issue keys.

## Supported Operations

| Operation  | Jira Command | Required Fields                              |
|------------|--------------|----------------------------------------------|
| Create     | `create`     | `project`, `summary`, `issuetype`            |
| Update     | `update`     | Existing issue key and valid JSON payload    |
| Transition | `transition` | Existing issue key and transition name or ID |
| Comment    | `comment`    | Existing issue key and comment body          |

Do not assume issue-linking, sprint-planning, or board-capacity APIs are available in this MVP workflow.

## Error Handling

### Failed Create

Log the error in `handoff-logs.md` with `Failed` status. Skip dependent operations that reference the unresolved `{{TEMP-N}}` placeholder.

### Failed Update

Log the error in `handoff-logs.md` with `Failed` status and continue.

### Issue Not Found

When an Update, Transition, or Comment operation targets an issue that no longer exists, log the error in `handoff-logs.md` with `Failed` status and continue.

### Transition Not Found

Log the error in `handoff-logs.md` with `Failed` status. Capture the available transitions from the Jira command output when possible.

### Authentication or Permission Error

Abort processing and notify the user.

### Invalid Field Payload

Log a warning in `handoff-logs.md`. Skip the invalid operation and continue processing remaining items.

### Transient Network Failure

Retry up to three times with backoff. If failures persist, log the error and continue with remaining operations.

## Autonomy Levels

The autonomy model controls confirmation gates during execution. Defaults to Partial autonomy when `autonomy` is not specified.

When the user declines a gated operation, mark it as `Skipped` in `handoff-logs.md` and continue.

## Dry Run Mode

When `dryRun` is `true`:

* Simulate all operations without executing Jira mutations.
* Read-only validation calls still execute to verify references.
* Generate `handoff-logs.md` with operations marked as `dry-run` status.
* Present the execution summary for user review.

## Success Criteria

Execution is complete when:

* All planned operations from `handoff.md` are either executed or logged with a final status.
* All `{{TEMP-N}}` placeholders are resolved to actual issue keys or logged as failed.
* `handoff-logs.md` contains an entry for every operation in the plan.
* A completion report has been presented to the user with Jira issue keys.

---

Brought to you by microsoft/hve-core