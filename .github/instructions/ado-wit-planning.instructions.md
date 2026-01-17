---
name: 'ADO Work Item Planning'
description: 'Reference specification for Azure DevOps work item planning files, templates, field definitions, and search protocols'
applyTo: '**/.copilot-tracking/workitems/**'
maturity: stable
---

# Azure DevOps Work Items Planning File Instructions

## Purpose and Scope

This file is a reference specification that defines templates, field conventions, and search protocols for work item planning files. Workflow files consume this specification by including a cross-reference at the top of their content.

Cross-reference pattern for consuming files:

```markdown
Follow all instructions from #file:./ado-wit-planning.instructions.md while executing this workflow.
```

Inline reference pattern when citing specific sections:

```markdown
per templates in #file:./ado-wit-planning.instructions.md
using the matrix from #file:./ado-wit-planning.instructions.md
```

## MCP ADO Tools

Work item operations reference these MCP ADO tools:

Discovery and retrieval:

* `mcp_ado_search_workitem`: Search work items by text, project, type, or state. Key params: `searchText` (required), `project`, `workItemType`, `state`, `top`, `skip`.
* `mcp_ado_wit_get_work_item`: Retrieve a single work item. Key params: `id` (required), `project` (required), `expand`, `fields`.
* `mcp_ado_wit_get_work_items_batch_by_ids`: Retrieve multiple work items. Key params: `ids` (required), `project` (required), `fields`.

Creation and updates:

* `mcp_ado_wit_create_work_item`: Create a new work item. Key params: `project` (required), `workItemType` (required), `fields` (required array of name/value pairs).
* `mcp_ado_wit_add_child_work_items`: Add child items to a parent. Key params: `parentId` (required), `project` (required), `workItemType` (required), `items` (required array).
* `mcp_ado_wit_update_work_item`: Update a single work item. Key params: `id` (required), `updates` (required array with path/value).
* `mcp_ado_wit_update_work_items_batch`: Batch update multiple items. Key params: `updates` (required array with id/path/value).

Relationships and linking:

* `mcp_ado_wit_work_items_link`: Link work items together. Key params: `project` (required), `updates` (required array with id/linkToId/type).
* `mcp_ado_wit_link_work_item_to_pull_request`: Link to a PR. Key params: `workItemId`, `projectId` (GUID), `repositoryId` (GUID), `pullRequestId`.
* `mcp_ado_wit_add_artifact_link`: Add artifact links (branch, commit, build). Key params: `workItemId` (required), `project` (required), `linkType`.

History and comments:

* `mcp_ado_wit_list_work_item_revisions`: Get revision history. Key params: `workItemId` (required), `project` (required), `top`.
* `mcp_ado_wit_add_work_item_comment`: Add a comment. Key params: `workItemId` (required), `project` (required), `comment` (required).

## Planning File Definitions & Directory Conventions

Root planning workspace structure:

```plain
.copilot-tracking/
  workitems/
    <planning-type>/
      <artifact-normalized-name>/
        artifact-analysis.md                    # Human-readable table + recommendations
        work-items.md                           # Human/Machine-readable plan (source of truth)
        handoff.md                              # Handoff for workitem execution
        planning-log.md                         # Structured operational & state log (routinely updated sections)
```

Valid `<planning-type>` values:

* `discovery`: Work item discovery from artifacts, PRDs, or user requests
* `pr`: Pull request work item linking and validation
* `sprint`: Sprint planning and work item organization
* `backlog`: Backlog refinement and prioritization

Normalization rules for `<artifact-normalized-name>`:

* Use lower-case, hyphenated base filename without extension (for example, `docs/Customer Onboarding PRD.md` becomes `docs--customer-onboarding-prd`).
* Replace spaces and punctuation with hyphens.
* Choose the primary artifact when multiple artifacts and documents are provided.

## Planning File Requirements

Planning markdown files start with:

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
```

Planning markdown files end with (before the final newline):

```markdown
<!-- markdown-table-prettify-ignore-end -->
```

## artifact-analysis.md

Create artifact-analysis.md when beginning work item discovery from PRDs, user requests, or codebase artifacts. This file captures the human-readable analysis of planned work items before finalizing in work-items.md.

Populate sections by extracting requirements from referenced artifacts, searching ADO for related items, and incorporating user feedback. Update the file iteratively as discovery progresses.

### Template

````markdown
# [Planning Type] Work Item Analysis - [Summarized Title]
* **Artifact(s)**: [e.g., relative/path/to/artifact-a.md, relative/path/to/artifact-b.md]
  * [(Optional) Inline Artifacts (e.g., User provided the following: [markdown block follows])]
* **Project**: [Project Name]
* **Area Path**: [(Optional) Area Path]
* **Iteration Path**: [(Optional) Iteration Path]

## Planned Work Items

### WI[Reference Number (e.g., 001)] - [one of, Create|Update|No Change] - [Summarized Work Item Title]
* **Working Title**: [Single line value (e.g., As a <persona>, I want <capability> so that <outcome>)]
* **Working Type**: [Supported Work Item Type]
* **Key Search Terms**: [Keyword groups (e.g., "primary term", "secondary term", "tertiary")]
* **Working Description**:
  ```markdown
  [Evolving description content constructed from artifacts and discovery]
  ```
* **Working Acceptance Criteria**:
  ```markdown
  * [Acceptance criterion 1 from artifacts and discovery]
  * [Acceptance criterion 2 from artifacts and discovery]
  ```
* **Found Work Item Field Values**:
  * [Work Item Field (e.g., System.Priority)]: [Value (e.g., 2, 3)]
* **Suggested Work Item Field Values**:
  * [Work Item Field (e.g., System.Priority)]: [Value (e.g., 2, 3)]

#### WI[Reference Number (e.g., 001)] - Related & Discovered Information
* [(Optional) zero or more Functional and Non-Functional Requirements blocks (e.g., Related Functional Requirements from relative/path/to/artifact-a.md)]
  * [(Optional) one or more Functional Requirement line items (e.g., FR-001: details of requirement)]
* [one or more Key Details blocks (e.g., Related Key Details from relative/path/to/artifact-b.md)]
  * [one or more Key Details line items (e.g., `Section 2.3` references dependency on data ingestion workflow)]
* [(Optional) zero or more Related Codebase blocks (e.g., Related Codebase Items Mentioned from User)]
  * [(Optional) one or more Related Codebase line items (e.g., src/components/example.ts: needs to be updated with related functionality, WidgetClass: needs IRepository)]

## Notes
* [(Optional) Notes worth mentioning (e.g., PRD specifically included two Epics (WI001, WI002))]
````

## work-items.md

work-items.md is the source of truth for planned work item operations. Capture the `System.State` field for every referenced work item, highlighting `Resolved` items. When a `Resolved` User Story satisfies the requirement without updates, keep the action as `No Change` and add a `Related` link from any new stories back to that item.

### Template

````markdown
# Work Items
* **Project**: [`projects` field for mcp ado tool]
* **Area Path**: [(Optional) `areaPath` field for mcp ado tool]
* **Iteration Path**: [(Optional) `iterationPath` field for mcp ado tool]
* **Repository**: [(Optional) `repository` field for mcp ado tool]

## WI[Reference Number (e.g, 002)] - [Action (one of, Create|Update|No Change)] - [Summarized Title (e.g., Update Component Functionality A)]
[1-5 Sentence Explanation of Change (e.g., Adding user story for functionality A called out in Section 2.3 of the referenced document)]

[(Optional) WI[Reference Number] - Similarity: [System.Id=Category (e.g., ADO-1024=Similar, ADO-901=Match, ADO-1071=Distinct)]]

* WI[Reference Number] - [Work Item Type Fields for single-line values (e.g., System.Id, System.WorkItemType, System.Title, System.Tags)]: [Single Line Value (e.g., As a user, I want functionality A in Component)]

### WI[Reference Number] - [Work Item Type Fields for multi-line values (e.g., System.Description, Microsoft.VSTS.Common.AcceptanceCriteria)]
```[Format (e.g., markdown, html, json)]
[Multi Line Value]
```

### WI[Reference Number] - Relationships
* WI[Reference Number] - [is-a Link Type (e.g., Child, Predecessor, Successor, Related)] - [Relation ID (either, WI[Related Reference Number], System.Id: [Work Item ID from mcp ado tool])]: [Single Line Reason (e.g., New user story for feature around component)]
````

### Example

````markdown
# Work Items
* **Project**: Project Name
* **Area Path**: Project Name\\Area\\Path
* **Repository**: project-repo

## WI002 - Update - Update Component Functionality A
Updating existing user story for functionality A from Section 2.3.

WI002 - Similarity: ADO-901=Match, ADO-1071=Similar (titles align on functionality A; ADO-1071 has broader scope)

* WI002 - System.Id: 1071
* WI002 - System.State: Active
* WI002 - System.WorkItemType: User Story
* WI002 - System.Title: As a user, I want functionality A with functionality B

### WI002 - System.Description
```markdown
## User Goal
As a user, I want to update component with functionality A and B.

## Requirements
* Functionality A becomes possible
* Functionality B becomes possible
```

### WI002 - Relationships
* WI002 - Child - WI001: Functionality A needed for Feature WI001
````

## planning-log.md

planning-log.md is a living document with sections that are routinely added, updated, extended, and removed in-place.

Phase tracking applies when the consuming workflow file defines phases (see the workflow file's Required Phases section for phase definitions):

* Track all new, in-progress, and completed steps for each phase.
* Update the Status section with in-progress review of completed and proposed steps.
* Update Previous Phase when moving to any other phase (phases can repeat based on discovery needs).
* Update Current Phase and Previous Phase when transitioning phases.

### Template

````markdown
# [Planning Type] - Work Item Planning Log
* **Project**: [`projects` field for mcp ado tool]
* **Repository**: [(Optional) `repository` field for mcp ado tool]
* **Previous Phase**: [(Optional) (e.g., Phase-1, Phase-2, N/A, Just Started) (Only if instructions use phases)]
* **Current Phase**: [(e.g., Phase-1, Phase-2, N/A, Just Started) (Only if instructions use phases)]

## Status
[e.g., 1/20 docs reviewed, 0/10 codefiles reviewed, 2/5 ado wit searched]

**Summary**: [e.g., Searching for ADO Work Items based on keywords]

## Discovered Artifacts & Related Files
* AT[Reference Number (e.g., 001)] [relative/path/to/file (identified from referenced artifacts, discovered in artifacts, conversation, codebase)] - [one of, Not Started|In-Progress|Complete] - [Processing|Related|N/A]

## Discovered ADO Work Items
* ADO-[ADO Work Item ID (identified from mcp_ado_search_workitem, discovered in artifacts, conversation) (e.g., 1023)] - [one of, Not Started|In-Progress|Complete] - [Processing|Related|N/A]

## Work Items
### **WI[Reference Number]** - [WorkItemType (e.g., User Story)] - [one of, In-Progress|Complete]
* WI[Reference Number] - Work Item Section (see artifact-analysis.md)
* Working Search Keywords: [Working Keywords (e.g., "the keyword OR another keyword")]
* Related ADO Work Items - Similarity: [System.Id=Category (Rationale) (e.g., ADO-1023=Similar (overlapping scope), ADO-102=Match (same user goal))]
* Suggested Action: [one of, Create|Update|No Change]

[Collected & Discovered Information]

[Possible Work Item Field Values (Refer to Work Item Fields)]

## Doc Analysis - artifact-analysis.md
### [relative/path/to/referenced/doc.ext]
* WI[Reference Number] - Work Item Section (see artifact-analysis.md): [Summary of what was done (e.g., New section made)]
### [relative/path/to/another/referenced/doc.ext]
* WI[Reference Number] - Work Item Section (see artifact-analysis.md): [Summary of what was done (e.g., Section was updated)]

## ADO Work Items
### ADO-[ADO Work Item ID]
[All content from mcp_ado_wit_get_work_item]
````

### Field Value Example

````markdown
* Working **System.Title**: As a user, I want a title that can be updated
* Working **System.Description**:
  ```markdown
  As a user, I want to update component with functionality A.
  ```
````

## handoff.md

Handoff file requirements:

* Include a reference to each work item defined in work-items.md.
* Order entries with Create actions first, Update actions second, and No Change entries last. When operating in discovery-only mode, list the No Change entries while noting that no modifications are planned.
* Include a markdown checkbox next to each work item with a summary.
* Include project-relative paths to all planning files (handoff.md, work-items.md, planning-log.md).
* Update the Summary section whenever the Work Items section changes.

### Template

```markdown
# Work Item Handoff
* **Project**: [`projects` field for mcp ado tool]
* **Repository**: [(Optional) `repository` field for mcp ado tool]

## Planning Files:
  * .copilot-tracking/workitems/<planning-type>/<artifact-normalized-name>/handoff.md
  * .copilot-tracking/workitems/<planning-type>/<artifact-normalized-name>/work-items.md
  * .copilot-tracking/workitems/<planning-type>/<artifact-normalized-name>/planning-log.md

## Summary
* Total Items: 3
* Actions: create 1, update 1, no change 1
* Types: User Story 3

## Work Items - work-items.md
* [ ] (Create) [(Optional) **Needs Review**] WI[Reference Number (e.g., 003)] [Work Item Type (e.g., Epic)]
  * [(Optional) all WI[Reference Number] Relationships as individual line items]
  * [Summary (e.g., New user story for functionality C)]
* [ ] (Update) [(Optional) **Needs Review**] WI[Reference Number (e.g., 001)] [Work Item Type (e.g., User Story)] - System.Id [ADO Work Item ID, (e.g., 1071)]
  * [(Optional) all WI[Reference Number] Relationships as individual line items]
  * [Summary (e.g., Update existing user story for functionality A)]
* [ ] (No Change) WI[Reference Number (e.g., 005)] [Work Item Type (e.g., User Story)] - System.Id [ADO Work Item ID]
  * [(Optional) all WI[Reference Number] Relationships as individual line items]
  * [Summary (e.g., Existing story covers telemetry tasks requested; no updates required)]
```

## Work Item Fields

Track field usage explicitly so downstream automation can rely on consistent data. When discovering existing items, capture the current values for every field planned for modification and preserve any organization-specific custom fields that already exist on the work item.

Relative Work Item Type Fields:

* Core: "System.Id", "System.WorkItemType", "System.Title", "System.State", "System.Reason", "System.Parent", "System.AreaPath", "System.IterationPath", "System.TeamProject", "System.Description", "System.AssignedTo", "System.CreatedBy", "System.CreatedDate", "System.ChangedBy", "System.ChangedDate", "System.CommentCount"
* Board: "System.BoardColumn", "System.BoardColumnDone", "System.BoardLane"
* Classification / Tags: "System.Tags"
* Common Extensions: "Microsoft.VSTS.Common.AcceptanceCriteria", "Microsoft.VSTS.TCM.ReproSteps", "Microsoft.VSTS.Common.Priority", "Microsoft.VSTS.Common.StackRank", "Microsoft.VSTS.Common.ValueArea", "Microsoft.VSTS.Common.BusinessValue", "Microsoft.VSTS.Common.Risk", "Microsoft.VSTS.Common.TimeCriticality", "Microsoft.VSTS.Common.Severity"
* Estimation & Scheduling: "Microsoft.VSTS.Scheduling.StoryPoints", "Microsoft.VSTS.Scheduling.OriginalEstimate", "Microsoft.VSTS.Scheduling.RemainingWork", "Microsoft.VSTS.Scheduling.CompletedWork", "Microsoft.VSTS.Scheduling.Effort"

**Work Item Types and Available Fields:**
| Type       | Key Fields                                                                                                                                                                                                                                                             |
|------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Epic       | System.Title, System.Description, System.AreaPath, System.IterationPath, Microsoft.VSTS.Common.BusinessValue, Microsoft.VSTS.Common.ValueArea, Microsoft.VSTS.Common.Priority, Microsoft.VSTS.Scheduling.Effort                                                        |
| Feature    | System.Title, System.Description, System.AreaPath, System.IterationPath, Microsoft.VSTS.Common.ValueArea, Microsoft.VSTS.Common.BusinessValue, Microsoft.VSTS.Common.Priority                                                                                          |
| User Story | System.Title, System.Description, Microsoft.VSTS.Common.AcceptanceCriteria, Microsoft.VSTS.Scheduling.StoryPoints, Microsoft.VSTS.Common.Priority, Microsoft.VSTS.Common.ValueArea                                                                                     |
| Bug        | System.Title, Microsoft.VSTS.TCM.ReproSteps, Microsoft.VSTS.Common.Severity, Microsoft.VSTS.Common.Priority, Microsoft.VSTS.Common.StackRank, Microsoft.VSTS.Common.ValueArea, Microsoft.VSTS.Scheduling.StoryPoints (optional), System.AreaPath, System.IterationPath |

Rules:

* Feature requires Epic parent.
* User Story requires Feature parent.
* Bug links are optional; add relationships when they provide helpful traceability, but do not create placeholder links just to satisfy this checklist.

## Search Keyword & Search Text Protocol

Goal: Deterministic, resumable discovery of existing work items.

### Step 1: Maintain Active Keyword Groups

Build an ordered list where each group contains 1-4 specific terms (multi-word phrases allowed) joined by OR.

### Step 2: Compose Search Text

Format the `searchText` parameter:

* Single group: `(term1 OR "multi word")`
* Multiple groups: `(group1) AND (group2)`

### Step 3: Execute Search and Process Results

Execute `mcp_ado_search_workitem` with a page size of 50.

Filter results to identify candidates for similarity assessment:

* Search highlights contain terms matching the planned item's core concepts
* Work item type is the same or one level above/below (for example, User Story results when planning a User Story, or Feature/Task results)
* Work item is not already linked to the planned item

Assess the candidates by relevance. For each candidate:

1. Fetch full work item using `mcp_ado_wit_get_work_item` and update planning-log.md.
2. Perform similarity assessment (see guidance below).
3. Assign action using the Similarity Categories table.
4. Record the assessment in planning-log.md under the Discovered Work Items section.

### Similarity Assessment

Analyze the relationship between the planned work item and each discovered item through aspect-by-aspect comparison:

1. **Title comparison**: Identify the core intent of each title. Determine whether they describe the same goal or outcome.
2. **Description comparison**: Examine whether they address the same problem or user need. Note any scope differences.
3. **Acceptance criteria comparison**: Evaluate whether completing one item would satisfy the requirements of the other.

When a field is absent from the discovered item:

* Missing acceptance criteria: Compare against scope and deliverables mentioned in the description. Capabilities and Epics typically lack acceptance criteria.
* Missing description: Use title and any linked child items to infer scope. Apply the Uncertain category when insufficient information remains.
* Different work item types: A User Story and Capability at different abstraction levels cannot be a Match. Evaluate whether the planned item should become a child of the discovered item.

Based on the analysis, classify the relationship using the Similarity Categories table.

### Similarity Categories

| Category | Meaning | Action |
|----------|---------|--------|
| Match | Same work item; creating both would duplicate effort | Update existing item |
| Similar | Related enough that consolidation may be appropriate | Review with user before deciding |
| Distinct | Different items with minimal overlap | Create new item |
| Uncertain | Insufficient information or conflicting signals | Request user guidance |

### Human Review Triggers

Request user guidance when:

* Either item lacks a title or description
* Discovered item lacks acceptance criteria and is a different work item type than the planned item
* Title suggests alignment but acceptance criteria diverge significantly
* Work item types differ by more than one abstraction level (for example, User Story compared to Epic)
* Domain-specific terminology requires expert interpretation
* The relationship is genuinely ambiguous after analysis

### Recording Similarity Assessments

Record each assessment in planning-log.md under a Discovered Work Items section with:

* ADO ID and title of the discovered item
* Category assigned (Match, Similar, Distinct, or Uncertain)
* Brief rationale explaining the classification
* Recommended action based on the category

Format: `ADO-{id}: {Category} - {rationale}`

Example:

```markdown
## Discovered Work Items

* ADO-1019: Similar - Edge inferencing framework overlaps with model validation goals; scope is broader (framework vs specific validation feature)
* ADO-1176: Similar - Cloud training capability addresses model lifecycle; planned item focuses on edge validation subset
* ADO-1179: Distinct - MLOps toolchain is infrastructure-level; planned item is user-facing validation feature
```

## State Persistence Protocol

Update planning-log.md as information is discovered to ensure continuity when context is summarized.

### Pre-Summarization Capture

Before summarization occurs, capture in planning-log.md:

* Full paths to all working files with a summary of each file's purpose
* Any uncaptured information that belongs in planning files
* Work item IDs already reviewed
* Work item IDs pending review
* Current phase and remaining steps
* Outstanding search criteria

### Post-Summarization Recovery

When context contains `<summary>` with only one tool call, recover state before continuing:

1. List the working folder with `list_dir` under `.copilot-tracking/workitems/<planning-type>/<artifact-normalized-name>/`.
2. Read planning-log.md to rebuild context.
3. Notify the user that context is being rebuilt and confirm the approach before proceeding.

Recovery notification format:

```markdown
## Resuming After Context Summarization

Context history was summarized. Rebuilding from planning files:

📋 **Analyzing**: [planning-log.md summary]

Next steps:
* [Planned actions]

Proceed with this approach?
```
