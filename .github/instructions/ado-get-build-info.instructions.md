---
description: "Required instructions for anything related to Azure Devops or ado build information including status, logs, or details from provided pullrequest (PR), build Id, or branch name."
applyTo: '**/.copilot-tracking/pr/*-build-*.md'
---

# Azure DevOps Build Info Instructions

Required Azure DevOps (azdo or ado) tooling usage for Required Protocol:

* Set `project` parameter to current project
* If not already provided and needed, get [PR number] by using `mcp_ado_repo_list_pull_request_by_project` tool and setting `created_by_me` to `true` and `status` to `Active`
* [branch name] is `refs/pull/[PR number]/merge` (if provided or identified from below protocol)
* Get [build ID] by using `mcp_ado_build_get_builds` tool
  * Set `branchName` to [branch name] if provided
  * Set `top` to 1 if getting based on [PR Number] from [branch name] or any prompt for "most recent", "latest", "current", etc. singleton style prompting
  * Otherwise, set `top` to at most 5 for any other prompt requesting filtering of builds
  * Set `[type]Filter` parameters as needed based on prompt
  * Set `queryOrder` based on prompt, e.g., "latest build" would be `[scheduling]Descending`, "earliest build" would be `[scheduling]Ascending`
* Get build status by using `mcp_ado_build_get_status` tool
* Get build logs, only if requested or identified from below protocol, by using `mcp_ado_build_get_log` to get high-level information and the [log ID]'s
  * Get actual logs by using `mcp_ado_build_get_log_by_id` tool and setting `logId` to discovered [log ID] and be sure to correctly set `startLine` and `endLine`

## Required Summarization Rules

When summarizing the user's conversation context:

* Must always keep exact inputs and their exact values provided by prompt in summary
* Must retain derived values and identified values (such as [PR number], [branch name], [build ID], etc) in summary
* Must provide full paths to all files being edited or read in (this instruction file, the prompt that kicked off the process, the tracking file if used)

After summarizing the user's conversation context:

* Must read in and follow all of these instructions
* Must regain entire context, read-in files, figure out exactly where left off
* Must then resume protocol and continue to collect information and write out relevant information as requested

## General User Conversation Guidance

Keep the user up-to-date while processing ado build information.

Follow these guidelines whenever interacting with the user through conversation:

* Utilize markdown styling whenever interacting with the user.
* Provide double newlines for each paragraph or new section.
* Use bolding for title words and italics for emphasis.
* For all unordered lists use markdown `*` instead of only using newlines.
* Use emojis to help get your point across.
* Avoid giving the user an overwhelming amount of information.
* Provide all actionable information into the conversation, identified issues, problems, stack traces, any relevant build information that the user would need to fix the build, etc.

## Required Protocol

Follow the required protocol in order

### 1. Determine if tracking file was requested

* If tracking file will be needed, create under `.copilot-tracking/pr/[YYYYMMDD]-build-[build id].md`
* If tracking file provided (as attachment or referenced by user), read in the file and continue updating it

User will indicate if they want information saved into tracking file:

* e.g., "Output the stack traces from the build logs for pr [PR number]"
* e.g., "Save the relevant information for the most recent build"

User may ask to just get the build information, DO NOT save to tracking file:

* e.g., "get the build status for pullrequest [PR number]"
* e.g., "Tell me what's wrong with my most recent build in azdo"

### 2. Correctly identify requested ado build information to retrieve

User will indicate what type of information to retrieve:

* e.g., "build status", "status", "state of the build", "build summary", "error", "information", "build issue", etc.
  * Must get build status using `mcp_ado_build_get_status` tool
* e.g., "build logs", "logs", "stack trace", "detailed", etc.
  * Must get build logs using `mcp_ado_build_get_log` and `mcp_ado_build_get_log_by_id` tools

### 3. Correctly find requested ado build

User may indicate where to find build information:

* e.g., "pullrequest [PR number]", "PR [PR number]", "pr [PR number]", etc.
* e.g., "build [build ID]"

User may use generic terms:

* e.g., "my pull request", "My branch", "Current branch", "This branch"
  * Must derive [PR number] to get [branch name] from current git branch
* e.g., "latest build", "failing build, "current build"
  * Must derive [build ID] using `mcp_ado_build_get_builds` and
    set parameters based on the user's prompt.

### 3. Iterate gathering ado build info (update tracking file if requested)

* Gather information from `mcp_ado_build_get_status` or `mcp_ado_build_get_log`
* If using tracking file, update tracking file with gathered information
* If all information gathered move on to the next protocol step
* Otherwise, iterate using `mcp_ado_build_get_log_by_id` and updating the tracking file after each log until complete

### 4. Provide accurate information and summary to user

Follow the General User Conversation Guidance and provide all actionable information
