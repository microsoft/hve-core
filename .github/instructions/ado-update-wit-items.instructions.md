---
description: "Required instructions for work item updating and creation leveraging mcp ado tool calls."
applyTo: '**/.copilot-tracking/workitems/**/handoff-logs.md'
---

# Azure DevOps Work Item Creation Update

Follow all instructions from #file:../instructions/ado-wit-planning.instructions.md for work item planning and planning files.
Do not make any edits to any planning files.
All edits and tracking will go into handoff-logs.md next to ${input:handoffFile}

## General User Conversation Guidance

Keep the user up-to-date while processing work items.

Follow these guidelines whenever interacting with the user through conversation:

* Utilize markdown styling whenever interacting with the user.
* Provide double newlines for each paragraph or new section.
* Use bolding for title words and italics for emphasis.
* For all unordered lists use markdown `*` instead of only using newlines.
* Use emojis to help get your point across.
* Avoid giving the user an overwhelming amount of information.

## handoff-logs.md

handoff-logs.md is a living document: sections are routinely added, updated, and extended in-place

* Add all provided inputs to the handoff-logs.md (e.g., ${input:handoffFile}, ${input:project}, ${input:areaPath}, ${input:iterationPath})
* Update handoff-logs.md from work-items.md and ${input:handoffFile} with:
  * List of checklist work items from ${input:handoffFile} (e.g., `1. [ ] (Create) WI001 Feature`)
  * All relationships for each work item (under each work item as an unordered list)
  * Line items of notes as items are processed (e.g., Resulting System.Id after creation, ADO Work Item URL, Errors unsuccessful operations, etc.)

## 1. Required Protocol

Resuming protocol:

* Read handoff-logs.md entirely if exists
* Review ${input:handoffFile} and determine where to continue processing
* Resume processing protocol after updating task list

Processing protocol:

* Create handoff-logs.md (if not already created)
* Read ${input:handoffFile} document entirely and update handoff-logs.md
* Determine order to process work items based on Determine Work Item Process Order
* Update task list with `[ ]` work items from handoff-logs.md
* Iteratively process remaining work items in work-items.md based on Process Work Items
  * Update handoff-logs.md work items checkbox `[x]` after completing mcp ado tool calls and making updates
  * Update handoff-logs.md with notes about processing work items
  * Update task list after completing processing each work item
  * Provide conversational updates to the user after processing each work item
* Final review of all of handoff-logs.md by reading in file again, reviewing with ${input:handoffFile}, address any issues or process any missed work items
* Finish by providing a review of handoff-logs.md through a conversational summary of completed work to the user (include all items in unordered list with ADO Work Item URLs, ADO System.Id's, Titles)

## 2. Determine Work Item Process Order

1. Work Item Type hierarchy
2. Operation (Create|Update)
3. Relationship is-a mapping (WI002 - Child - WI001, WI002 is-a Child of WI001)

## 3. Process Work Items

* Mandatory: must continually map temporary WI[Reference Number] to ADO System.Id for relationships
* Mandatory: when a field must store Markdown content, include the `format` parameter and set it to `Markdown`
* Mandatory: use `mcp_ado_wit_update_work_items_batch` to add or update any Acceptance Criteria fields; other tools must not be used for this purpose
* Mandatory: payloads must mirror the content in `work-items.md` and related planning files exactly—do not revise wording, structure, or Markdown beyond formatting required by Azure DevOps

### MCP Tool Parameter Guidance

Always source parameter values from the active planning artifacts (`work-items.md`, `handoff.md`, `planning-log.md`) before issuing a tool call. Confirm the latest `System.Id` for every WI reference prior to constructing payloads, and keep field text identical to the planning content.

**`mcp_ado_wit_create_work_item`**

* `project`: use the `Project` value from `work-items.md`.
* `workItemType`: use the Work Item Type recorded for the WI reference.
* `fields`: supply an array of objects with `name` and `value`; include `format: "Markdown"` for multi-line fields such as `System.Description` or `Microsoft.VSTS.Common.AcceptanceCriteria`. Preserve existing organization-specific fields when provided, and copy values verbatim from planning artifacts.

**`mcp_ado_wit_add_child_work_items`**

* `parentId`: resolved `System.Id` of the parent work item (usually sourced from a previously created item or an Update entry).
* `project`: same value used for the parent.
* `workItemType`: child type (e.g., `User Story`, `Bug`).
* `items`: each child must include `title` and `description`; set `format: "Markdown"` whenever the description block is Markdown. Apply `areaPath` and `iterationPath` only when explicitly provided in planning artifacts. Do not modify the text captured in planning.

**`mcp_ado_wit_update_work_items_batch`**

* Each entry in `updates` must include `id` (resolved ADO `System.Id`), `path` (e.g., `/fields/System.Description`), and `value`. The `value` must match the planning document content exactly.
* Choose `op` (`add`, `replace`, or `remove`) based on whether the field is new, changed, or cleared. Default `add` is acceptable when replacing entire field content.
* Set `format: "Markdown"` on updates for Markdown-backed fields (Acceptance Criteria, Description, Repro Steps, etc.).
* Batch related field edits together to minimize tool calls while keeping payloads readable in `handoff-logs.md`.

**`mcp_ado_wit_work_items_link`**

* Provide `project` from `work-items.md`.
* Each item in `updates` must declare `id` (source work item), `linkToId` (target `System.Id`), and `type` (e.g., `Child`, `Parent`, `Related`). Add a `comment` when the planning documents capture rationale that should appear in ADO history. Use the note text exactly as written in planning files.

````markdown
<!-- <example-ado-wit-update-batch> -->
```json
{
  "project": "hve-core",
  "updates": [
    {
      "id": 1234,
      "path": "/fields/Microsoft.VSTS.Common.AcceptanceCriteria",
      "value": "* Acceptance criterion pulled from handoff-logs.md",
      "op": "add",
      "format": "Markdown"
    }
  ]
}
```
<!-- </example-ado-wit-update-batch> -->
````

1. **Create Top Level Work Items**: mcp_ado_wit_create_work_item
2. **Create Child Work Items**: mcp_ado_wit_add_child_work_items
3. **Update Existing Work Items**: mcp_ado_wit_update_work_items_batch
4. **Create Additional Relationship Links**: mcp_ado_wit_work_items_link

**Error Handling**:

* Failed creation because item already exists: Likely already created, note it in handoff-logs.md `[x]` work item and move to next work item
* Failed update because item is missing property: Verify the field and tool call then re-process if different, otherwise note it in handoff-logs.md leave `[ ]` and re-process work item without field
* Failed adding relationship because work item doesn't exist: Likely order mistake, note it in handoff-logs.md leave `[ ]` and come back to it later
