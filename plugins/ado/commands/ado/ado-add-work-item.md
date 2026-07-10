---
description: "Create a single Azure DevOps work item with conversational field collection and parent validation"
agent: ADO Backlog Manager
argument-hint: "project=... [type={Epic|Feature|UserStory|Bug|Task}] [title=...]"
---

# Add ADO Work Item

Create a single work item through conversational field collection, validate parent hierarchy, and log the result. Use interaction templates from #file:../../instructions/ado/ado-interaction-templates.instructions.md for description formatting.

Follow all instructions from #file:../../instructions/ado/ado-wit-planning.instructions.md for field definitions and shared conventions.
Follow all instructions from #file:../../instructions/ado/ado-interaction-templates.instructions.md for work item description and comment templates.

## Inputs

* `${input:project}`: (Required) Azure DevOps project name.
* `${input:type}`: (Optional) Work item type: Epic, Feature, User Story, Bug, Task. When not provided, present options during field collection.
* `${input:title}`: (Optional) Work item title. When not provided, prompt during field collection.
* `${input:parentId}`: (Optional) Parent work item ID for hierarchy linking.
* `${input:areaPath}`: (Optional) Area Path for the new work item.
* `${input:iterationPath}`: (Optional) Iteration Path for the new work item.
* `${input:contentFormat:Markdown}`: (Optional) Content format for rich-text fields. Use `Markdown` for Azure DevOps Services (dev.azure.com) or `Html` for Azure DevOps Server (on-premises). Defaults to Markdown.

## Required Steps

The workflow proceeds through five steps: resolve project context, select work item type, collect fields conversationally, validate parent hierarchy, then create the work item and log the result.

### Step 1: Resolve Project Context

Establish the target project and verify access before proceeding.

1. Call `mcp_ado_core_get_identity_ids` to establish authenticated user context.
2. Verify `${input:project}` is accessible. When inaccessible, report the error and prompt for correction.
3. When `${input:areaPath}` or `${input:iterationPath}` is not provided, retrieve available paths via `mcp_ado_work_list_team_iterations` or similar retrieval calls for context.

### Step 2: Select Work Item Type

Determine the work item type for creation.

1. When `${input:type}` matches a valid type (Epic, Feature, User Story, Bug, Task), use it directly.
2. When `${input:type}` is not provided, present the available types and ask the user to select one.
3. Record the selected type for field collection in the next step.

### Step 3: Collect Fields

Gather field values through conversation using the interaction template for the selected work item type.

1. When `${input:title}` is not provided, prompt the user for a title.
2. Collect the description using the appropriate interaction template format for the selected type. Select the Markdown or HTML template variant from #file:../../instructions/ado/ado-interaction-templates.instructions.md based on `${input:contentFormat}`.
3. For optional fields not provided through inputs (Priority, Severity for bugs, Tags, Assigned To), ask the user whether they want to supply values.
4. Merge provided inputs with conversationally collected values.

### Step 4: Validate Parent Hierarchy

Verify parent-child relationships are valid before creation.

1. When `${input:parentId}` is provided, fetch the parent work item via `mcp_ado_wit_get_work_item` and verify the hierarchy is valid:
   * Features require an Epic parent.
   * User Stories require a Feature parent.
   * Tasks and Bugs can be children of User Stories or Features.
2. When the hierarchy is invalid, warn the user and suggest corrections or alternative parent items.
3. When `${input:parentId}` is not provided and the selected type is Feature, User Story, Task, or Bug, ask the user if they want to link to a parent item.

### Step 5: Create and Log

Submit the work item to Azure DevOps and record the result.

1. When `${input:parentId}` is provided and valid, call `mcp_ado_wit_add_child_work_items` to create the item as a child of the parent.
2. When no parent is specified, call `mcp_ado_wit_create_work_item` with the collected fields (title, description, type, Area Path, Iteration Path, Priority, Tags, and any additional fields). Set the `format` parameter to `${input:contentFormat}` for Description, Acceptance Criteria, and Repro Steps fields.
3. On success, extract the work item ID and URL from the response and confirm creation with the user.
4. Create or append to a tracking artifact in `.copilot-tracking/workitems/execution/{{YYYY-MM-DD}}/` with the work item ID, URL, type, title, applied fields, and parent relationship.
5. On failure, report the error and suggest corrections or a retry.

## Success Criteria

* Project context is resolved and access is verified before field collection.
* The work item type is selected before collecting type-specific fields.
* Required fields are validated before creation.
* Parent hierarchy is validated when a parent ID is provided.
* The work item is created with correct metadata and interaction template formatting matching `${input:contentFormat}`.
* A tracking artifact exists in `.copilot-tracking/workitems/execution/{{YYYY-MM-DD}}/`.

## Error Handling

* Project inaccessible: display the error and prompt for correction.
* Invalid parent hierarchy: warn the user and suggest valid parent options.
* Required field missing after prompting: re-prompt until a value is provided.
* Creation failure: display the error message and suggest corrections.
* Parent work item not found: inform the user and offer to proceed without linking.

---

Proceed with creating the Azure DevOps work item following the Required Steps.
