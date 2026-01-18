---
description: 'Work item creation and update protocol using MCP ADO tools with handoff tracking'
applyTo: '**/.copilot-tracking/workitems/**/handoff-logs.md'
maturity: stable
---

# Azure DevOps Work Item Update Instructions

Follow all instructions from #file:./ado-wit-planning.instructions.md for work item planning, templates, and field definitions.

## Scope

**Inputs**:

* `${input:handoffFile}`: Path to handoff.md containing work items to process (required)
* `${input:project}`: Azure DevOps project name (inferred from handoff.md if not provided)
* `${input:areaPath}`: Area path for work items (optional, uses handoff.md value)
* `${input:iterationPath}`: Iteration path for work items (optional, uses handoff.md value)

**Outputs**:

* handoff-logs.md created next to ${input:handoffFile} containing processing status and results
* Work items created or updated in Azure DevOps

**Trigger conditions**: These instructions apply when processing work items from a handoff.md file through MCP ADO tool calls.

## Work Item Type Hierarchy

Work items follow this parent-child hierarchy:

1. Epic (top level)
2. Feature (child of Epic)
3. User Story (child of Feature)
4. Task or Bug (child of User Story)

Process work items in hierarchy order: create parent items before children to ensure relationship links resolve correctly.

## Required Steps

### Step 1: Initialize or Resume

When handoff-logs.md exists:

* Read handoff-logs.md and ${input:handoffFile}
* Identify work items with unchecked `[ ]` status
* Continue from the first unchecked item

When handoff-logs.md does not exist:

* Create handoff-logs.md using the template in the Templates section
* Populate the Work Items section from ${input:handoffFile}
* Record all inputs in the Inputs section

### Step 2: Process Work Items

Determine processing order:

1. Work item type hierarchy (Epic → Feature → User Story → Task/Bug)
2. Operation type (Create before Update)
3. Relationship dependencies (parent before child)

For each work item:

* Map temporary WI[Reference Number] to ADO System.Id after creation
* Include `format: "Markdown"` for Description, Acceptance Criteria, and Repro Steps fields
* Copy field values verbatim from planning artifacts
* Use `mcp_ado_wit_update_work_items_batch` for Acceptance Criteria fields

Tool sequence:

1. `mcp_ado_wit_create_work_item` for new top-level items
   * Parameters: `project`, `workItemType`, `fields[]` with `name`, `value`, and optional `format` ("Html" or "Markdown")
2. `mcp_ado_wit_add_child_work_items` for creating child items under an existing parent
   * Parameters: `parentId`, `project`, `workItemType`, `items[]` with `title`, `description`, optional `format`, `areaPath`, `iterationPath`
3. `mcp_ado_wit_update_work_items_batch` for field updates including Acceptance Criteria
   * Parameters: `updates[]` with `id`, `path` (e.g., "/fields/System.Title"), `value`, `op` ("Add", "Replace", "Remove"), optional `format`
4. `mcp_ado_wit_work_items_link` for relationship links between work items
   * Parameters: `project`, `updates[]` with `id`, `linkToId`, `type`, optional `comment`
   * Link types: "parent", "child", "related", "predecessor", "successor", "duplicate", "duplicate of", "tested by", "tests", "affects", "affected by"
5. `mcp_ado_wit_add_artifact_link` for linking to repositories, branches, commits, or builds
   * Parameters: `workItemId`, `project`, `linkType`, plus artifact-specific parameters (`branchName`, `commitId`, `buildId`, `pullRequestId`)

After each item completes:

* Update checkbox to `[x]` in handoff-logs.md
* Record the ADO System.Id, URL, and any notes
* Notify the user with a brief status update

When a work item has no pending changes:

* Mark checkbox as `[x]` with note "No changes required"
* Skip API calls for that item
* Continue to the next item in the processing queue

### Step 3: Finalize and Report

* Re-read handoff-logs.md and compare against ${input:handoffFile}
* Process any missed work items
* Provide a summary listing all items with ADO URLs, System.Ids, and titles

## Error Handling

**Authentication and permissions**: When API calls fail with 401 or 403 errors, notify the user and pause processing. Do not retry authentication errors.

**Rate limits**: When encountering 429 responses, wait and retry with exponential backoff. Note the delay in handoff-logs.md.

**Item already exists**: Mark as `[x]` in handoff-logs.md with a note, then continue to the next item.

**Missing field or invalid property**: Verify the field path and retry. If the field is unsupported, note it in handoff-logs.md with `[ ]` status and reprocess without that field.

**Missing parent work item**: A relationship cannot be created because the target does not exist. Leave `[ ]` status, add "Pending: parent" to notes, and revisit after processing remaining items. Track these items separately in the Processing Summary under "Pending revisit: [count]".

**Network or transient failures**: Retry up to three times with backoff. If failures persist, note the error and continue with remaining items.

## Conversation Guidance

Keep the user informed during processing:

* Use markdown formatting with proper paragraph spacing
* Use emojis sparingly to indicate status (✅ success, ⚠️ warning, ❌ error)
* Provide brief updates after each work item completes
* Avoid overwhelming the user with verbose output

## Templates

### handoff-logs.md

````markdown
# Work Item Processing Log

## Inputs
* **Handoff File**: [path to handoff.md]
* **Project**: [project name]
* **Area Path**: [area path if provided]
* **Iteration Path**: [iteration path if provided]

## Work Items
* [ ] (Create) WI[Reference Number] [Work Item Type] - [Title Summary]
  * [Relationship entries from handoff.md]
  * Notes: [processing notes, System.Id after creation, URL, errors]
* [ ] (Update) WI[Reference Number] [Work Item Type] - System.Id [ID] - [Title Summary]
  * [Relationship entries from handoff.md]
  * Notes: [processing notes, URL, errors]

## Processing Summary
* Started: [ISO 8601 timestamp, e.g., 2026-01-16T14:30:00Z]
* Completed: [ISO 8601 timestamp]
* Total: [count] items
* Created: [count]
* Updated: [count]
* Errors: [count]
* Pending revisit: [count]
````

### Create Work Item Example

```json
{
  "project": "edge-ai",
  "workItemType": "User Story",
  "fields": [
    { "name": "System.Title", "value": "As a user, I want feature X" },
    { "name": "System.Description", "value": "## User Goal\nDescription content here.", "format": "Markdown" },
    { "name": "System.AreaPath", "value": "edge-ai\\Team" },
    { "name": "System.IterationPath", "value": "edge-ai\\Sprint 1" }
  ]
}
```

### Batch Update Example

```json
{
  "updates": [
    {
      "id": 1234,
      "path": "/fields/System.Description",
      "value": "## User Goal\nAs a user, I want to update component functionality.",
      "op": "Add",
      "format": "Markdown"
    },
    {
      "id": 1234,
      "path": "/fields/Microsoft.VSTS.Common.AcceptanceCriteria",
      "value": "* Criterion one from planning artifacts\n* Criterion two from planning artifacts",
      "op": "Add",
      "format": "Markdown"
    }
  ]
}
```

### Link Work Items Example

```json
{
  "project": "edge-ai",
  "updates": [
    { "id": 1234, "linkToId": 1000, "type": "parent" },
    { "id": 1235, "linkToId": 1234, "type": "child", "comment": "Adding subtask" },
    { "id": 1234, "linkToId": 1236, "type": "related" }
  ]
}
```

<!-- Brought to you by microsoft/hve-core -->
