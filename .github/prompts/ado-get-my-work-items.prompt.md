---
description: "Retrieve user's current Azure DevOps work items and organize them into planning file definitions"
maturity: stable
---

# Get My Work Items and Create Planning Files

Follow all instructions from #file:../instructions/ado-wit-planning.instructions.md for work item planning and planning file definitions.

You WILL retrieve all work items assigned to the current user (`@Me`) within the specified Azure DevOps project using Azure DevOps tools, then organize them into the standardized planning file structure. This creates a foundation for future work item planning and execution.

## General User Conversation Guidance

Keep the user up-to-date while processing work items.

Follow these guidelines whenever interacting with the user through conversation:

* Utilize markdown styling whenever interacting with the user.
* Provide double newlines for each paragraph or new section.
* Use bolding for title words and italics for emphasis.
* For all unordered lists use markdown `*` instead of only using newlines.
* Use emojis to help get your point across.
* Avoid giving the user an overwhelming amount of information.

## Inputs

* ${input:project}: (Required) Azure DevOps project name or ID
* ${input:areaPath}: (Optional) Area Path filter for work items
* ${input:iterationPath}: (Optional) Iteration Path filter for work items
* ${input:types:Bug, Task, User Story}: Comma-separated Work Item Types to fetch (case-insensitive). Default: Bug, Task, User Story.
* ${input:states:Active, New, Resolved}: (Optional) Comma-separated workflow states to include. Default: Active, New, Resolved.
* ${input:planningType:current-work}: Planning type for organizing retrieved work items. Default: current-work.

## 1. Required Protocol

Processing protocol:

* Create planning file structure in `.copilot-tracking/workitems/${input:planningType}/my-assigned-work-items/`
* Retrieve all assigned work items using mcp ado tool calls
* Hydrate each work item with complete field information
* Organize work items into planning file definitions:
  * `artifact-analysis.md` - Human-readable analysis and recommendations
  * `work-items.md` - Machine-readable work item definitions
  * `planning-log.md` - Operational log tracking progress and discoveries
* Provide conversational summary of retrieved work items with planning file locations

## 2. Search and Retrieval Phase

**Search Strategy:**

1. Use `mcp_ado_wit_my_work_items` with specified parameters
2. For each discovered work item, call `mcp_ado_wit_get_work_item` to get complete field information
3. Organize work items by type and priority for planning structure

**Error Handling:**

* Failed retrieval: Surface error and continue with remaining work items
* Missing fields: Note missing information in planning files
* Empty results: Create planning structure with note about no assigned work items

## 3. Planning File Generation

### 3.1 Create Planning Directory Structure

Create directory (if not already exist): `.copilot-tracking/workitems/${input:planningType}/my-assigned-work-items/`

Replace the `artifact-analysis.md`, `work-items.md`, `planning-log.md` if already exist

* Use the list_dir tool to identify if these planning files already exist for my-assigned-work-items
* Confirm with the user on replacing these files
* If confirmed, delete the files without reading them and proceed onto the next steps, otherwise attempt to work in the existing files.

### 3.2 Generate artifact-analysis.md

Follow template structure from planning instructions:

* Document all retrieved work items with analysis
* Include work item summaries and key field values
* Provide recommendations for work item organization
* Reference original Azure DevOps work item URLs

### 3.3 Generate work-items.md

Follow template structure from planning instructions:

* Create WI reference numbers for each retrieved work item
* Map all relevant Azure DevOps fields to planning format
* Include work item relationships and dependencies
* Use markdown format for multi-line fields

### 3.4 Generate planning-log.md

Follow template structure from planning instructions:

* Track retrieval progress and discoveries
* Document any issues or missing information
* Log work item processing status
* Include links to Azure DevOps work items

## 4. Field Mapping Requirements

Map all Azure DevOps Work Item fields outlined in planning file format instructions

## 5. Output Requirements

**Planning Files Created:**

1. `.copilot-tracking/workitems/${input:planningType}/my-assigned-work-items/artifact-analysis.md`
2. `.copilot-tracking/workitems/${input:planningType}/my-assigned-work-items/work-items.md`
3. `.copilot-tracking/workitems/${input:planningType}/my-assigned-work-items/planning-log.md`

**Conversation Summary:**

* Total count of work items retrieved and organized
* Breakdown by work item type
* Planning file locations
* Summary table with key work item information
* Any issues or recommendations for work item management

## 6. Planning File Content Requirements

### artifact-analysis.md Content

* **Artifact(s)**: "Azure DevOps assigned work items retrieval"
* **Project**: `${input:project}`
* **Area Path**: `${input:areaPath}` if provided
* **Iteration Path**: `${input:iterationPath}` if provided
* Individual work item analysis sections for each retrieved item
* Working titles and descriptions derived from System.Title and System.Description
* Key search terms extracted from titles and descriptions
* Suggested field values based on current Azure DevOps state

### work-items.md Content

* Project, Area Path, Iteration Path metadata
* WI reference number assignment for each work item
* Complete field mapping from Azure DevOps to planning format
* Action designation (typically "Update" for existing work items)
* Relationship mapping between connected work items
* Proper markdown formatting for multi-line content

### planning-log.md Content

* Processing status tracking
* Discovery log of work items found
* Field mapping and content organization progress
* Any errors or missing information encountered
* Links to original Azure DevOps work items
* Recommendations for future work item management

---

Proceed with work item retrieval and planning file generation by following all phases in order
