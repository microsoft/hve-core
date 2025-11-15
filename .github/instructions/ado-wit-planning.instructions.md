---
description: "Required instructions for work item planning and creation or updating leveraging mcp ado tool calls."
applyTo: '**/.copilot-tracking/workitems/**'
---

# Azure DevOps Work Items Planning File Instructions

ADO Work Item Project: hve-core

<!-- <planning-folder-structure> -->
## Planning File Definitions & Directory Conventions

Root planning workspace structure:

```plain
.copilot-tracking/
  workitems/
    <planning-type>/
      <artifact-normalized-name>/
        artifact-analysis.md                    # Human-readable table + recommendations
        work-items.md                           # Human/Machine-readable plan (source of truth)
        handoff.md                              # Handoff for workitem execution (optionally references work-items.json if JSON variant produced)
        planning-log.md                         # Structured operational & state log (routinely updated sections)
```
**Normalization:**
* Lower-case, hyphenated base filename without extension (e.g. `docs/Customer Onboarding PRD.md` → `docs--customer-onboarding-prd`).
* Avoid spaces and punctuation besides hyphens (replace with hyphens).
* Choose primary artifact when multiple artifacts and documents are provided or best effort.
<!-- </planning-folder-structure> -->

## Planning File Requirements

* Planning markdown files MUST start with:
  ```
  <!-- markdownlint-disable-file -->
  <!-- markdown-table-prettify-ignore-start -->
  ```
* Planning markdown files MUST end with (before last newline):
  ```
  <!-- markdown-table-prettify-ignore-end -->
  ```

<!-- <artifact-analysis-md> -->
## artifact-analysis.md

**Detailed Template:**
<!-- <template-artifact-analysis-md> -->
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
<!-- </template-artifact-analysis-md> -->
<!-- </artifact-analysis-md> -->

<!-- <work-items-md> -->
## work-items.md

**Detailed Template:**
<!-- <template-work-items-md> -->
````markdown
# Work Items
* **Project**: [`projects` field for mcp ado tool]
* **Area Path**: [(Optional) `areaPath` field for mcp ado tool]
* **Iteration Path**: [(Optional) `iterationPath` field for mcp ado tool]
* **Repository**: [(Optional) `repository` field for mcp ado tool]

## WI[Reference Number (e.g, 002)] - [Action (one of, Create|Update|No Change)] - [Summarized Title (e.g., Update Component Functionality A)]
[1-5 Sentence Explanation of Change (e.g., Adding user story for functionality A called out in Section 2.3 of the referenced document)]

[(Optional) WI[Reference Number] - Similarity: [System.Id Similarity Score (e.g., ADO-1024=0.5, ADO-901=0.8, ADO-1071=0.9)]]

* WI[Reference Number] - [Work Item Type Fields for single-line values (e.g., System.Id, System.WorkItemType, System.Title, System.Tags)]: [Single Line Value (e.g., As a user, I want functionality A in Component)]

### WI[Reference Number] - [Work Item Type Fields for multi-line values (e.g., System.Description, Microsoft.VSTS.Common.AcceptanceCriteria)]
```[Format (e.g., markdown, html, json)]
[Multi Line Value]
```

### WI[Reference Number] - Relationships
* WI[Reference Number] - [is-a Link Type (e.g., Child, Predecessor, Successor, Related)] - [Relation ID (either, WI[Related Reference Number], System.Id: [Work Item ID from mcp ado tool])]: [Single Line Reason (e.g., New user story for feature around component)]
````
<!-- </template-work-items-md> -->

* Capture the `System.State` field for every referenced work item in `work-items.md`, highlighting `Resolved` items that remain unchanged.
* When a `Resolved` User Story satisfies the requirement without updates, keep the action as `No Change` and ensure any new or updated stories include a `Related` link back to that item.

**Detailed Example:**
<!-- <example-work-items-md> -->
````markdown
# Work Items
* **Project**: Project Name
* **Area Path**: Project Name\\Area\\Path
* **Iteration Path**: Project Name\\Sprint 1
* **Repository**: project-repo

## WI002 - Update - Update Component Functionality A
Updating existing user story to add functionality A captured in Section 2.3 of the provided document. Found User Story Title (https://dev.azure.com/Organization/Project%20Name/_workitems/edit/1071/) through conversation with the user and agreed to update. User agreed System.Title should be updated as well.

WI002 - Similarity: ADO-901=0.8, ADO-1071=0.9

* WI002 - System.Id: 1071
* WI002 - System.WorkItemType: User Story
* WI002 - System.Title: As a user, I want to update component and include functionality A with functionality B

### WI002 - System.Description
```markdown
## As a user (continue to match existing style and tone)
As a user, I want to update component with new functionality B and new functionality A. So I can do this specific thing that I want with this component.

## Functional Requirements
* Functionality A becomes possible
* Functionality B becomes possible
* Side-effect is then something
* Existing requirement from workitem that should stay in

## Non-Functional Requirements
* Non-functional requirement from parent feature
* Non-functional requirement from document.md
* Non-functional requirement mentioned by user
* Existing non-functional requirement that should stay in
```

### WI002 - Microsoft.VSTS.Common.AcceptanceCriteria
```markdown
* Able to do specific thing
* Able to do something else for verification
* Existing acceptance criteria that should stay in
```

### WI002 - Relationships
* WI002 - Predecessor - WI003: Functionality A required in Component before able to add Functionality C in new User Story WI003
* WI002 - Child - WI001: Functionality A needed for Feature WI001
````
<!-- </example-work-items-md> -->
<!-- </work-items-md> -->

<!-- <planning-log-md> -->
## planning-log.md

* planning-log.md is a living document: sections are routinely added, updated, extended, and removed in-place.
* Iterating on any planning files requires updates to planning-log.md in order to track progress.
* Track all new, in-progress, and completed steps for Phases routinely.
* Update Status section with in-progress review of completed and proposed steps.
* Update Previous Phase when moving onto any other Phase (not required to be in-order (meaning, Phase-1 could be repeated after Phase-2 due to discovery)).
* Update Current Phase and Previous Phase when transitioning phases.

**Detailed Template:**
<!-- <template-planning-log-md> -->
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
* Related ADO Work Items - Similarity: [System.Id Similarity Score (e.g., ADO-1023=0.5, ADO-102=0.7, ADO-103=0.8)]
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
<!-- </template-planning-log-md> -->

**Example Possible Work Item Field Value**:
<!-- <example-planning-log-md-field-values> -->
````markdown
* Working **System.Title**: As a user, I want a title that can be updated as new information is discovered
* Working **System.Description**:
  ```markdown
  ## As a user (updated to match style and tone from mcp ado searched work items)
  As a user, I want to update component with new functionality A. So I can do this specific thing that I want with this component that was called out in the document.

  ## Requirements
  * Functionality A becomes possible
  ```
* Working **Microsoft.VSTS.Common.AcceptanceCriteria**:
  ```markdown
  * Able to do specific thing
  ```
````
<!-- </example-planning-log-md-field-values> -->
<!-- </planning-log-md> -->

<!-- <handoff-md> -->
#### handoff.md

* Must have a reference to each work item in work-items.md for proper handoff.
* Create work items must always be before Update work items, and any `No Change` entries must follow Updates. When operating in discovery-only mode, list the `No Change` entries while noting that no modifications are planned.
* Must have a markdown checkbox next to each work item and include summary.
* Must have a project relative path to planning files (handoff.md, work-items.md, planning-log.md).
* Must update Summary section when Work Items section is updated.

Template:
<!-- <template-handoff-md> -->
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
<!-- </template-handoff-md> -->
<!-- </handoff-md> -->

<!-- <work-item-fields> -->
## Work Item Fields

Track field usage explicitly so downstream automation can rely on consistent data. When discovering existing items, capture the current values for every field you plan to modify and preserve any organization-specific custom fields that already exist on the work item.

**Relative Work Item Type Fields:**
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
<!-- </work-item-fields> -->

## Search Keyword & Search Text Protocol

Goal: Deterministic, resumable discovery of existing work items.

<!-- <search-keyword-protocol> -->
Steps:
1. Maintain ACTIVE KEYWORD GROUPS: ordered list, each group = 1-4 specific terms (multi‑word allowed) joined by OR.
2. Compose `searchText`:
  * Single group → `(term1 OR "multi word")`
  * Multiple groups → `(group1) AND (group2)` etc.
3. Execute search (page size suggested: 50). For every related result ID:
  * Fetch full work item immediately and update planning-log.md.
  * Compute similarity (semantic intent focus, not token count).
  * Assign action via matrix.

Similarity Computation Guidance:
* Use combined semantic representation of (title + description + acceptance).
* Boost for aligned outcome/goal verbs; penalize scope or persona mismatch.
* Store raw float, round to 2 decimals for `similarity` field.
<!-- </search-keyword-protocol> -->

<!-- <similarity-decision-matrix> -->
| Similarity | Action | Interpretation                                 |
|------------|--------|------------------------------------------------|
| ≥ 0.70     | update | Strong alignment with existing item intent     |
| 0.50-0.69  | review | Potential alignment; needs manual confirmation |
| < 0.50     | create | No sufficiently aligned existing item          |
<!-- </similarity-decision-matrix> -->

<!-- <state-persistence-protocol> -->
## Routine State Persistence & Summarization Tool Call Protocol

* Must maintain planning-log.md routinely by keeping it up to date as information is discovered.

### Required Pre-Summarization
Summarization must also include the following (or else you will likely cause breaking changes):
* Full paths to all working files with a summary describing each file and its purpose
* Anything that was not captured into the planning-log.md file or other planning files that should have been captured before summarization
  * Specifically state exactly what needs to be done again (e.g., use the mcp_ado_wit_get_work_item tool with ID ### again, etc)
* Exact work item IDs that were already reviewed
* Exact work item IDs that are left to be reviewed
* Exact work item IDs that were already reviewed but likely not captured into the planning-log.md file or other planning files
* Exact planning steps that you were previously on (must repeat if data was not captured into planning files)
* Exact planning steps that are still required
* Any potential work item search criteria that is still required

### Required Post-Summarization Recovery
If context has `<summary>` and only one tool call, then immediately do the following protocol before any additional edits/decisions:

1. **State File Validation**:
  * It's likely you've lost valuable information and you are now required to recover your context to avoid broken changes
  * Use the `list_dir` tool under the `.copilot-tracking/workitems/<planning-type>/<artifact-normalized-name>` working folder
  * Use the `read_file` tool to read back in all of the planning-log.md to build back context

2. **Context Reconstruction User Update**:
  Let the user know that you are working on rebuilding your context:

  ```markdown
  ## Resuming After Context Summarization

  I notice our conversation history was summarized. Let me rebuild context:

  📋 **[Analyzing Title]**: [Analyze planning-log.md and current work item content]

  To ensure continuity, I'll do the following:
  * [List protocol that you plan to follow next]

  Would you like me to proceed with this approach?
  ```
<!-- </state-persistence-protocol> -->
