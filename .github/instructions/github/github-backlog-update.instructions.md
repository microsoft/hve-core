---
description: 'Execution workflow for GitHub issue backlog management - consumes planning handoffs and executes issue operations'
applyTo: '**/.copilot-tracking/github-issues/**/handoff-logs.md'
---

# GitHub Backlog Update Instructions

Follow all instructions from #file:./github-backlog-planning.instructions.md for planning file templates, field definitions, search protocols, and state persistence.

Follow community interaction guidelines from #file:./community-interaction.instructions.md when posting comments visible to external contributors.

## Purpose and Scope

The execution protocol processes a handoff plan file to create, update, link, and close GitHub issues in batch. The workflow consumes handoff.md (or triage-plan.md) produced by the discovery or triage workflows and executes planned operations against the GitHub API via MCP tools.

All operations MUST execute sequentially. Parallel execution is not supported due to dependency chains between Create, Link, and Update operations.

### Outputs

* handoff-logs.md created next to `handoff` containing per-operation processing status and results
* Issues created, updated, linked, or closed in the target GitHub repository

### Trigger Conditions

These instructions apply when processing issue operations from a handoff.md or triage-plan.md file through MCP GitHub tool calls.

## Issue Hierarchy

Issues follow a parent-child hierarchy via sub-issue relationships:

1. Epic or tracking issue (top level)
2. Individual issues (children of tracking issue)
3. Sub-tasks (children of individual issues)

Parent issues MUST be created before children to ensure sub-issue linking resolves correctly.

## Required Steps

### Step 1: Initialize or Resume

When handoff-logs.md exists next to `handoff`:

* Read handoff-logs.md and `handoff`.
* Identify operations with unchecked `[ ]` status.
* Rebuild the temporary ID mapping from previously completed Create entries (the Issue Number field in each completed log entry records the `{{TEMP-N}}` to `#actual` mapping).
* Resume processing in priority order: Create → Update → Link → Close → Comment, starting from the first unchecked operation in that sequence.

When handoff-logs.md does not exist:

* Create handoff-logs.md using the template from #file:./github-backlog-planning.instructions.md.
* Populate the Operations section from `handoff`.
* Record all inputs in the Execution Summary section.

Validate the handoff before processing:

* Confirm `owner` and `repo` are set (from inputs or parsed from the handoff file header).
* Verify all numeric issue references exist by calling `mcp_github_issue_read` with method `get` for each number. Skip `{{TEMP-N}}` placeholders during this validation since those issues do not exist yet.
* Verify label names are valid by calling `mcp_github_get_label` for each unique label in the plan.
* Call `mcp_github_list_issue_types` to confirm whether the organization supports issue types before using the `type` field.
* Map `{{TEMP-N}}` placeholders to execution order so parent issues are created before children that reference them.
* Apply the Content Sanitization Guards from #file:./github-backlog-planning.instructions.md to all GitHub-bound fields (issue titles, bodies, comments, and other text fields) to resolve `.copilot-tracking/` paths and planning reference IDs (`IS[NNN]`) before execution.
* When validation fails for a non-critical field (invalid label, unknown milestone), log a warning and continue. When validation fails for a critical field (missing repository, authentication error), abort with a message.

### Step 2: Process Operations

Process operations in this fixed order, matching the handoff.md template sections:

1. Create all issues (parents first, then children) via `mcp_github_issue_write` with method `create`. Each Create MUST include title, body, and at least one label per the Issue Field Matrix in #file:./github-backlog-planning.instructions.md.
2. Update existing issues via `mcp_github_issue_write` with method `update`.
3. Link sub-issues via `mcp_github_sub_issue_write` with method `add`, using `issue_number` for the parent and `sub_issue_id` for the child.
4. Close duplicate or resolved issues via `mcp_github_issue_write` with `state: 'closed'` and the appropriate `state_reason`.
5. Add comments for context via `mcp_github_add_issue_comment`.

Checkpoint after each operation completes:

* Check the autonomy tier to determine whether a confirmation gate is required. Refer to the Three-Tier Autonomy Model in #file:./github-backlog-planning.instructions.md for gate definitions. When the user declines a gated operation, mark it as `Skipped` in handoff-logs.md and continue.
* When `dryRun` is `true`, simulate the operation and log it as `dry-run` without executing (see the Dry Run Mode section).
* After each Create, resolve the `{{TEMP-N}}` placeholder to the actual issue number returned by `mcp_github_issue_write`. Record the mapping in handoff-logs.md.
* When a `{{TEMP-N}}` reference appears in a Link or Update operation, resolve it from the mapping table before calling the MCP tool.
* Before each API call, re-apply the Planning Reference ID Guard from #file:./github-backlog-planning.instructions.md to catch planning reference IDs (such as `IS002`) that became resolvable after new `{{TEMP-N}}` mappings were established.
* Update the checkbox to `[x]` in handoff.md after each operation completes.
* Append an entry to handoff-logs.md recording the issue number, action taken, and any notes.
* On failure, log the error and continue processing remaining operations. Do not abort the batch for a single failure.

When an operation has no pending changes:

* Mark the checkbox as `[x]` in handoff.md with a note: "No changes required."
* Skip API calls for that item.
* Continue to the next operation in the processing queue.

### Step 3: Finalize and Report

* Re-read handoff-logs.md and compare against `handoff`.
* Process any missed operations that were skipped due to dependency failures and have since been unblocked. Limit this retry pass to one additional iteration; log any operations still blocked after the retry as `Failed`.
* Cross-check created issues against the plan to confirm all `{{TEMP-N}}` placeholders resolved.
* Generate a handoff summary with counts: issues created, updated, closed, linked, failed, and skipped.
* Provide a completion report listing all processed items with issue numbers.

## Supported Operations

| Operation        | MCP Tool                       | Method   | Required Fields                                  |
|------------------|--------------------------------|----------|--------------------------------------------------|
| Create           | `mcp_github_issue_write`       | `create` | owner, repo, title, body, labels                 |
| Update           | `mcp_github_issue_write`       | `update` | owner, repo, issue_number                        |
| Close            | `mcp_github_issue_write`       | `update` | owner, repo, issue_number, state, state_reason   |
| Add Labels       | `mcp_github_issue_write`       | `update` | owner, repo, issue_number, labels                |
| Set Milestone    | `mcp_github_issue_write`       | `update` | owner, repo, issue_number, milestone             |
| Add Sub-issue    | `mcp_github_sub_issue_write`   | `add`    | owner, repo, issue_number, sub_issue_id          |
| Add Comment      | `mcp_github_add_issue_comment` | N/A      | owner, repo, issue_number, body                  |
| Set PR Milestone | `mcp_github_issue_write`       | `update` | owner, repo, issue_number (PR number), milestone |
| Set PR Labels    | `mcp_github_issue_write`       | `update` | owner, repo, issue_number (PR number), labels    |
| Set PR Assignees | `mcp_github_issue_write`       | `update` | owner, repo, issue_number (PR number), assignees |

Pull request field operations use `mcp_github_issue_write` because GitHub treats pull requests as a superset of issues sharing the same number space. Pass the PR number as `issue_number` to set milestones, labels, or assignees on a pull request. The `mcp_github_update_pull_request` tool does not support these fields.

When an operation produces community-visible output (closing issues, requesting information, acknowledging contributions), follow the scenario templates in #file:./community-interaction.instructions.md. Apply the comment-before-closure pattern: call `mcp_github_add_issue_comment` with the appropriate scenario template before any state-changing call such as `mcp_github_issue_write` with closure.

Refer to the Issue Field Matrix and Pull Request Field Operations sections in #file:./github-backlog-planning.instructions.md for complete field requirements per operation type.

## Error Handling

Each error scenario describes the expected behavior. Unrecognized errors SHOULD be logged and processing SHOULD continue with remaining operations.

### Failed Create

Log the error in handoff-logs.md with `Failed` status. Skip dependent child issues and sub-issue links that reference the failed parent. Continue processing remaining operations.

### Failed Update

Log the error in handoff-logs.md with `Failed` status. Continue processing remaining operations.

### Issue Not Found (404)

When an Update, Close, or Link operation targets an issue that no longer exists, log the error in handoff-logs.md with `Failed` status and continue. This can occur when an issue is deleted between planning and execution.

### Rate Limit (429)

Pause and retry up to three times with exponential backoff. Note the delay in handoff-logs.md. If retries are exhausted, log the error and continue with remaining operations.

### Authentication or Permission Error (401/403)

Abort processing and notify the user. Do not retry authentication errors.

### Invalid Label

Log a warning in handoff-logs.md. Skip the invalid label and continue applying other field changes.

### Invalid Milestone

Log a warning in handoff-logs.md. Skip the milestone assignment and continue applying other field changes.

### Missing Parent for Sub-issue Link

Leave the Link operation unchecked with a `Pending: parent` note. Revisit during the Step 3 retry pass.

### Transient Network Failure

Retry up to three times with exponential backoff. If failures persist, log the error and continue with remaining operations.

## Conversation Guidance

### Internal Operator Updates

Keep the user informed during processing:

* Use markdown formatting with proper paragraph spacing.
* Use emojis sparingly to indicate status (success, warning, error).
* Provide brief updates after each operation completes.
* Avoid overwhelming the user with verbose output; summarize progress at natural checkpoints (after all Creates, after all Updates, and so on).

### Community-Facing Comments

Comments posted to GitHub issues or pull requests are visible to external contributors. These comments follow a different voice and tone than internal operator updates.

* Apply the scenario templates from #file:./community-interaction.instructions.md for all community-visible comments.
* Match the Tone Calibration Matrix in that file. Tone ranges from warm and genuine for acknowledgments to respectful and direct for scope closures to constructive and specific for information requests.
* Fill all template placeholders with specific, actionable details rather than generic language.

## Autonomy Levels

The autonomy model controls confirmation gates during execution. Defaults to Partial Autonomy when `autonomy` is not specified. Refer to the Three-Tier Autonomy Model in #file:./github-backlog-planning.instructions.md for the full specification and gate definitions.

When the user declines a gated operation, mark it as `Skipped` in handoff-logs.md and continue to the next operation.

## Dry Run Mode

When `dryRun` is `true`:

* Simulate all operations without calling MCP tools that modify state.
* Read-only validation calls (`mcp_github_issue_read`, `mcp_github_get_label`) still execute to verify references.
* Generate handoff-logs.md with all operations marked as `dry-run` status.
* Present the execution summary for user review.
* Re-invoke with `dryRun` set to `false` to execute the plan.

## Handoff File Format

The execution workflow consumes handoff.md and produces handoff-logs.md. Both templates are defined in #file:./github-backlog-planning.instructions.md.

### handoff.md (consumed)

Read the Issues section of handoff.md. Each checkbox entry represents one operation. Checked entries (`[x]`) are already complete (from a prior execution run); unchecked entries (`[ ]`) are pending.

### handoff-logs.md (produced)

Create handoff-logs.md next to the handoff file. Append an entry after each operation completes. Use the template and field definitions from #file:./github-backlog-planning.instructions.md. The `dry-run` status value extends the template's defined values (`Success`, `Failed`, `Skipped`) for dry run mode operations.

## Success Criteria

Execution is complete when:

* All planned operations from handoff.md are either executed or logged with a final status.
* All `{{TEMP-N}}` placeholders are resolved to actual issue numbers (or logged as failed).
* handoff-logs.md contains an entry for every operation in the plan.
* The Execution Summary in handoff-logs.md reflects accurate counts for succeeded, failed, and skipped operations.
* A completion report has been presented to the user with issue numbers.

---

Brought to you by microsoft/hve-core
