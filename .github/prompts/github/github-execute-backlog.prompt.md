---
description: 'Execute a GitHub backlog plan by creating, updating, linking, closing, and commenting on issues from a handoff file'
agent: GitHub Backlog Manager
argument-hint: "handoff=... [autonomy={full|partial|manual}] [dryRun={true|false}]"
---

# Execute GitHub Backlog Plan

Process a handoff plan file to execute planned issue operations against the GitHub API. The workflow initializes (or resumes) execution state, processes operations in hierarchy order, and produces a completion report with issue numbers.

Follow all instructions from #file:../instructions/github-backlog-update.instructions.md while executing this workflow.
Follow all instructions from #file:../instructions/github-backlog-planning.instructions.md for shared conventions.

## Inputs

* `${input:handoff}`: (Required) Path to the handoff plan file (handoff.md or triage-plan.md).
* `${input:autonomy:partial}`: (Optional, defaults to partial) Autonomy tier controlling confirmation gates. Values: `full`, `partial`, `manual`.
* `${input:dryRun:false}`: (Optional, defaults to false) When true, simulate all operations without modifying state.

## Required Steps

The workflow proceeds through three steps: initialize or resume execution state, process operations in fixed hierarchy order, then finalize and present a completion report.

### Step 1: Initialize or Resume

Establish execution context and determine whether this is a new run or a resumption.

1. Call `mcp_github_get_me` to verify repository access and determine the authenticated user.
2. Read the handoff plan from `${input:handoff}`. When the file is not found, ask the user for the correct path before continuing.
3. Resolve the repository owner and name from the handoff file header or the active workspace context.
4. Call `mcp_github_list_issue_types` with the owner parameter to determine whether the repository supports issue types and confirm valid type values before processing.
5. Check whether handoff-logs.md already exists next to `${input:handoff}`:
   * When it exists, rebuild the `{{TEMP-N}}` mapping from completed Create entries and resume from the first unchecked operation per the Initialize or Resume instructions in the update instructions.
   * When it does not exist, create handoff-logs.md using the template from the planning specification and populate it from the handoff file.
6. Validate the handoff per the validation checks in the update instructions. Skip `{{TEMP-N}}` placeholders during numeric reference validation since those issues do not exist yet. Abort on critical failures (missing repository, authentication error); warn and continue on non-critical failures (invalid label, unknown milestone).
7. Present an execution summary to the user for confirmation before proceeding.

### Step 2: Process Operations

Execute operations in the fixed order defined by the update instructions: Create (parents first, then children), Update, Link, Close, Comment.

1. Process each operation category in sequence, following the Supported Operations table and checkpoint protocol in the update instructions.
2. After each Create, resolve the corresponding `{{TEMP-N}}` placeholder to the actual issue number and record the mapping in handoff-logs.md.
3. Apply confirmation gates per the Three-Tier Autonomy Model in the planning specification based on `${input:autonomy}`. When the user declines a gated operation, mark it as `Skipped` in handoff-logs.md and continue.
4. When `${input:dryRun}` is true, simulate operations per the Dry Run Mode section of the update instructions without executing state-modifying calls.
5. Update checkboxes in the handoff file and append entries to handoff-logs.md after each operation per the checkpoint protocol. On failure, log the error and continue processing remaining operations.

### Step 3: Finalize and Report

Verify results and present a completion report.

1. Re-read handoff-logs.md and compare against the original handoff plan.
2. Process any missed operations that were blocked by dependency failures and have since been unblocked. Limit this retry pass to one additional iteration per the finalization instructions.
3. Cross-check that all `{{TEMP-N}}` placeholders resolved to actual issue numbers.
4. Generate a completion summary with counts for issues created, updated, linked, closed, failed, and skipped. Present the summary with issue numbers.
5. When failures occurred, list each failed operation with its error message and suggest corrective actions.

## Success Criteria

* All planned operations from the handoff file are executed or logged with a final status in handoff-logs.md.
* All `{{TEMP-N}}` placeholders are resolved to actual issue numbers or logged as failed.
* handoff-logs.md next to `${input:handoff}` contains an entry for every operation.
* A completion report with issue numbers has been presented to the user.

## Error Handling

* Handoff file not found: ask the user for the correct path rather than failing silently.
* Authentication or permission error (401/403): abort processing and notify the user.
* Rate limit (429): pause and retry with exponential backoff per the error handling in the update instructions.
* Invalid issue references: skip the operation, log a warning in handoff-logs.md, and continue per the error handling in the update instructions.
* Missing parent for sub-issue link: defer the link operation and revisit during the Step 3 retry pass per the dependency resolution in the update instructions.
* API or transient failures: log the error, continue with remaining operations, and report all failures in the final summary per the error handling in the update instructions.
* Context summarization: when conversation history is compressed, recover state from handoff-logs.md per the State Persistence Protocol in the planning specification before continuing.

---

Proceed with executing the backlog plan from `${input:handoff}` following the Required Steps.
