---
description: 'Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name.'
applyTo: '**/.copilot-tracking/pr/*-build-*.md'
maturity: stable
---

# Azure DevOps Build Info Instructions

These instructions define the protocol for retrieving Azure DevOps (ADO) build information including status, logs, changes, and stage details. The protocol supports both conversational responses and persistent tracking file output.

## Scope

This protocol applies when:

* Retrieving build status, logs, or changes from Azure DevOps pipelines.
* Investigating build failures or issues for a pull request or branch.
* Saving build information to tracking files for later reference.

## Tooling

<!-- <pipeline-tools> -->
### Pipeline Tools

**mcp_ado_pipelines_get_builds** - Retrieve builds list

* `project` (string, required): Project ID or name.
* `branchName` (string): Filter by branch name (for example, `refs/pull/{{prNumber}}/merge`).
* `top` (number): Maximum builds to return.
* `queryOrder` (string): Sort order (`queueTimeDescending`, `queueTimeAscending`, `startTimeDescending`, `startTimeAscending`, `finishTimeDescending`, `finishTimeAscending`).
* `statusFilter` (string): Filter by status (`all`, `cancelling`, `completed`, `inProgress`, `none`, `notStarted`, `postponed`).
* `resultFilter` (string): Filter by result (`canceled`, `failed`, `none`, `partiallySucceeded`, `succeeded`).
* `buildNumber` (string): Filter by build number.
* `requestedFor` (string): Filter by user who requested the build.

**mcp_ado_pipelines_get_build_status** - Get build status by ID

* `project` (string, required): Project ID or name.
* `buildId` (number, required): ID of the build.

**mcp_ado_pipelines_get_build_log** - Get build log entries

* `project` (string, required): Project ID or name.
* `buildId` (number, required): ID of the build.

**mcp_ado_pipelines_get_build_log_by_id** - Get specific log by ID

* `project` (string, required): Project ID or name.
* `buildId` (number, required): ID of the build.
* `logId` (number, required): ID of the log to retrieve.
* `startLine` (number): Starting line number.
* `endLine` (number): Ending line number.

**mcp_ado_pipelines_get_build_changes** - Get changes in a build

* `project` (string, required): Project ID or name.
* `buildId` (number, required): ID of the build.
* `top` (number, default 100): Number of changes to retrieve.
* `includeSourceChange` (boolean): Include source changes in results.

**mcp_ado_pipelines_update_build_stage** - Update build stage status

* `project` (string, required): Project ID or name.
* `buildId` (number, required): ID of the build.
* `stageName` (string, required): Name of the stage to update.
* `status` (string, required): New status (`Cancel`, `Retry`, `Run`).
* `forceRetryAllJobs` (boolean, default false): Force retry all jobs in the stage.

**mcp_ado_pipelines_get_build_definitions** - Get pipeline definitions

* `project` (string, required): Project ID or name.
* `name` (string): Filter by definition name.
* `path` (string): Filter by definition path.
* `top` (number): Maximum definitions to return.
* `includeLatestBuilds` (boolean): Include latest builds for each definition.

**mcp_ado_pipelines_get_build_definition_revisions** - Get definition revision history

* `project` (string, required): Project ID or name.
* `definitionId` (number, required): ID of the build definition.

**mcp_ado_pipelines_get_run** - Get a specific pipeline run

* `project` (string, required): Project ID or name.
* `pipelineId` (number, required): ID of the pipeline.
* `runId` (number, required): ID of the run.

**mcp_ado_pipelines_list_runs** - List pipeline runs (up to 10,000)

* `project` (string, required): Project ID or name.
* `pipelineId` (number, required): ID of the pipeline.
<!-- </pipeline-tools> -->

### Supporting Tools

**mcp_ado_repo_list_pull_requests_by_repo_or_project** - Find PR numbers when not provided

* `project` (string): Project ID or name.
* `repositoryId` (string): Repository ID (optional, filters to specific repo).
* `created_by_me` (boolean, default false): Filter to PRs created by the current user.
* `status` (string, default `Active`): Filter by status (`NotSet`, `Active`, `Abandoned`, `Completed`, `All`).
* `top` (number, default 100): Maximum PRs to return.

## Deliverables

**Conversational response**: Summarize build status, errors, and actionable information directly in conversation.

**Tracking file** (when requested): Create or update `.copilot-tracking/pr/{{YYYY-MM-DD}}-build-{{buildId}}.md` with structured build information.

## Conversation Guidelines

Keep the user informed while processing build information:

* Use markdown styling with double newlines between sections.
* Apply **bold** for key terms and *italics* for emphasis.
* Use `*` for unordered lists.
* Include emojis to indicate status (✅ success, ❌ failure, ⚠️ warning).
* Focus on actionable information: errors, stack traces, and steps to resolve issues.
* Avoid overwhelming detail; summarize and offer to provide more on request.

## Summarization Rules

When summarizing conversation context, retain:

* Exact user inputs and their values ({{prNumber}}, {{buildId}}, {{branchName}}).
* Derived values identified during the protocol.
* Full paths to files being edited or read.

After context summarization, read these instructions, regain context from referenced files, determine the current protocol step, and resume.

## Required Steps

Follow these steps in order to retrieve and present Azure DevOps build information.

### Step 1: Determine Output Mode

Identify whether the user requests persistent tracking or conversational output.

**Tracking file requested** (save, output, persist keywords):

* Create file at `.copilot-tracking/pr/{{YYYY-MM-DD}}-build-{{buildId}}.md`.
* If a tracking file is already attached or referenced, read and continue updating it.

**Conversational output** (get, tell, check, what keywords):

* Provide information directly in conversation without creating a tracking file.

### Step 2: Identify Build Information Type

Determine what information to retrieve based on user keywords:

* **Status keywords** (status, state, summary, error, information, issue): Retrieve build status using `mcp_ado_pipelines_get_build_status`.
* **Log keywords** (logs, stack trace, detailed, output): Retrieve logs using `mcp_ado_pipelines_get_build_log` and `mcp_ado_pipelines_get_build_log_by_id`.
* **Changes keywords** (changes, commits, what changed): Retrieve changes using `mcp_ado_pipelines_get_build_changes`.

### Step 3: Locate the Target Build

Determine the build to query based on user input:

**Explicit identifiers**:

* PR reference (pullrequest {{prNumber}}, PR {{prNumber}}): Derive branch as `refs/pull/{{prNumber}}/merge`.
* Build ID (build {{buildId}}): Use directly with status and log tools.

**Generic references**:

* Current context (my pull request, this branch, current branch): Derive {{prNumber}} from the current git branch, then construct the branch name.
* Latest build (latest, current, failing, recent): Use `mcp_ado_pipelines_get_builds` with `top` set to 1 and `queryOrder` set to `queueTimeDescending`.

**Query parameters**:

* Set `top` to 1 for singleton requests (latest, most recent).
* Set `top` to 5 or less for filtered queries.
* Set `queryOrder` based on recency (descending for latest, ascending for earliest).
* Apply `statusFilter` or `resultFilter` based on user keywords (failing → `resultFilter: failed`).

### Step 4: Gather Build Information

Collect information iteratively:

1. Retrieve initial data using `mcp_ado_pipelines_get_build_status` or `mcp_ado_pipelines_get_build_log`.
2. If using a tracking file, update it with gathered information after each retrieval.
3. For detailed logs, iterate through log entries using `mcp_ado_pipelines_get_build_log_by_id` with appropriate `startLine` and `endLine` values.
4. Continue until all requested information is collected.

### Step 5: Present Results

Follow conversation guidelines to deliver actionable information:

* Summarize overall build status and result.
* Highlight errors, failures, and stack traces.
* Provide specific line numbers and log references for debugging.
* Suggest next steps for resolving issues when applicable.

## Tracking File Template

Use this template when creating build tracking files:

```markdown
---
type: build-info
buildId: {{buildId}}
prNumber: {{prNumber}}
branchName: {{branchName}}
status: {{status}}
result: {{result}}
created: {{YYYY-MM-DD}}
---

# Build {{buildId}} Information

<!-- <build-summary> -->
## Summary

* **Status**: {{status}}
* **Result**: {{result}}
* **Branch**: {{branchName}}
* **PR**: {{prNumber}}
<!-- </build-summary> -->

<!-- <build-errors> -->
## Errors

(Add error details and stack traces here)
<!-- </build-errors> -->

<!-- <build-logs> -->
## Log Excerpts

(Add relevant log excerpts here)
<!-- </build-logs> -->
```
