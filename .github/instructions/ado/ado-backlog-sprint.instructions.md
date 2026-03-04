---
description: "Sprint planning workflow for Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/workitems/sprint/**'
---

# ADO Sprint Planning

Plan Azure DevOps iterations by analyzing work item coverage, capacity, dependencies, and gaps. Follow all instructions from #file:./ado-wit-planning.instructions.md while executing this workflow.

## Required Phases

### Phase 1: Discover and Retrieve

Gather iteration metadata and work items for the target sprint.

#### Step 1: Discover Iterations

Call `mcp_ado_work_list_team_iterations` to enumerate available iterations. Identify the current iteration (date range containing today), the next iteration, and any future iterations within the planning horizon.

Record iteration details in planning-log.md:

* Iteration name and path
* Start date and end date
* Whether the iteration is current, next, or future

When a specific iteration is provided as input, use that iteration. Otherwise, default to the current iteration.

#### Step 2: Retrieve Sprint Work Items

Call `mcp_ado_wit_get_work_items_for_iteration` with the target iteration ID to retrieve all work items assigned to the sprint.

Hydrate results via `mcp_ado_wit_get_work_items_batch_by_ids` to retrieve full field details including `System.State`, `System.AreaPath`, `System.WorkItemType`, `Microsoft.VSTS.Common.Priority`, `Microsoft.VSTS.Scheduling.StoryPoints`, `Microsoft.VSTS.Scheduling.OriginalEstimate`, `Microsoft.VSTS.Scheduling.RemainingWork`, and `Microsoft.VSTS.Scheduling.CompletedWork`.

#### Step 3: Retrieve Backlog Items

Call `mcp_ado_wit_list_backlog_work_items` to retrieve unplanned backlog items not assigned to any iteration. These candidates feed backlog grooming recommendations in Phase 2.

### Phase 2: Analyze

Evaluate the sprint across four dimensions: coverage, capacity, gaps, and dependencies.

#### Step 1: Triage Prerequisite Check

Count work items in the `New` state. When more than 50% of sprint items are in `New` state, recommend running triage via `ado-backlog-triage.instructions.md` before continuing sprint planning. Log the recommendation in planning-log.md and inform the user.

Sprint planning can continue alongside a triage recommendation, but the plan should note that classifications may shift after triage completes.

#### Step 2: Coverage Analysis

Build an Area Path coverage matrix showing which areas are represented in the sprint and which are missing.

| Area Path        | Items | Story Points | Status      |
|------------------|-------|--------------|-------------|
| {{area_path}}    | {{n}} | {{points}}   | Covered     |
| {{missing_area}} | 0     | 0            | Not Covered |

Identify Area Paths with active work items in the backlog but no representation in the sprint. Flag these as coverage gaps.

Build a hierarchy coverage matrix showing decomposition completeness at each work item type level:

| Level   | Total | With Children | Orphaned | Completeness |
|---------|-------|---------------|----------|--------------|
| Epic    | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |
| Feature | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |
| Story   | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |
| Task    | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |

Identify orphaned stories (no parent Feature), features without parent Epics, and stories lacking Task decomposition. ADO's 4-level hierarchy enables coverage analysis that flat issue trackers cannot provide.

#### Step 3: Capacity Analysis

Sum planned effort using `Microsoft.VSTS.Scheduling.StoryPoints` for User Stories or `Microsoft.VSTS.Scheduling.OriginalEstimate` for Tasks and Bugs.

When team capacity is provided as input, compare planned effort against capacity:

| Metric         | Value            |
|----------------|------------------|
| Planned Effort | {{total_points}} |
| Team Capacity  | {{capacity}}     |
| Utilization    | {{percentage}}%  |
| Remaining      | {{remaining}}    |

Include burndown metrics when `CompletedWork` data is available:

| Metric         | Value                                   |
|----------------|-----------------------------------------|
| Original Est.  | Sum of `OriginalEstimate` across items  |
| Completed Work | Sum of `CompletedWork` across items     |
| Remaining Work | Sum of `RemainingWork` across items     |
| Burndown Ratio | `CompletedWork / OriginalEstimate` as % |

When capacity is not provided, report planned effort totals and recommend that the user supply capacity data for utilization calculations.

Break down effort by team member when `System.AssignedTo` data is available.

#### Step 4: Gap Analysis

Cross-reference requirements documents, PRDs, or other planning artifacts against the iteration backlog when documents are provided. Identify requirements with no matching work items in the sprint.

When no documents are provided, skip this step and note that gap analysis requires reference documents.

#### Step 5: Dependency Detection

Examine work item links for parent-child relationships and predecessor/successor dependencies:

* Identify items with predecessors outside the current sprint (external blockers).
* Identify items with successors in the current sprint (internal chains).
* Flag items with unresolved parent links or missing child items.

Record dependency chains in planning-log.md.

### Phase 3: Plan

Produce sprint plan and grooming recommendations.

#### Step 1: Backlog Grooming Recommendations

From the unplanned backlog retrieved in Phase 1, identify items that could be pulled into the sprint. Evaluate candidates by:

* Priority: higher-priority items first
* Capacity: remaining capacity after planned items
* Dependencies: items whose predecessors are complete or in the current sprint
* Coverage: items that fill identified Area Path gaps

Rank candidates and present the top recommendations.

#### Step 2: Generate Sprint Plan

Create sprint-plan.md in `.copilot-tracking/workitems/sprint/{{iteration-kebab}}/` using the template in the Output section.

#### Step 3: Present for Review

Present the sprint plan to the user, highlighting:

* Capacity utilization and over/under-commitment
* Coverage gaps by Area Path
* External dependencies and blockers
* Backlog grooming candidates ranked by fit

## Output

The sprint planning workflow produces output files in `.copilot-tracking/workitems/sprint/{{iteration-kebab}}/`.

### sprint-plan.md Template

Planning markdown files must start and end with the directives defined in the planning specification.

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
# Sprint Plan - {{iteration_name}}

* **Project**: {{project}}
* **Iteration**: {{iteration_path}}
* **Dates**: {{start_date}} to {{end_date}}
* **Team Capacity**: {{capacity}} (if provided)
* **Date Generated**: {{YYYY-MM-DD}}

## Summary

| Metric              | Value              |
| ------------------- | ------------------ |
| Total Items         | {{item_count}}     |
| Story Points        | {{total_points}}   |
| Capacity            | {{capacity}}       |
| Utilization         | {{utilization}}%   |
| Items in New State  | {{new_count}}      |
| External Blockers   | {{blocker_count}}  |
| Burndown Ratio      | {{burndown_pct}}%  |

## Work Items by Priority

### Priority 1 - Critical

| ID | Title | Type | State | Story Points | Assigned To | Area Path |
| -- | ----- | ---- | ----- | ------------ | ----------- | --------- |
| {{id}} | {{title}} | {{type}} | {{state}} | {{points}} | {{assignee}} | {{area}} |

### Priority 2

| ID | Title | Type | State | Story Points | Assigned To | Area Path |
| -- | ----- | ---- | ----- | ------------ | ----------- | --------- |
| {{id}} | {{title}} | {{type}} | {{state}} | {{points}} | {{assignee}} | {{area}} |

### Priority 3-4

| ID | Title | Type | State | Story Points | Assigned To | Area Path |
| -- | ----- | ---- | ----- | ------------ | ----------- | --------- |
| {{id}} | {{title}} | {{type}} | {{state}} | {{points}} | {{assignee}} | {{area}} |

## Coverage Matrix

### Area Path Coverage

| Area Path | Items | Story Points | Status |
| --------- | ----- | ------------ | ------ |
| {{area_path}} | {{count}} | {{points}} | {{status}} |

### Hierarchy Coverage

| Level | Total | With Children | Orphaned | Completeness |
| ----- | ----- | ------------- | -------- | ------------ |
| Epic | {{n}} | {{n}} | {{n}} | {{pct}}% |
| Feature | {{n}} | {{n}} | {{n}} | {{pct}}% |
| Story | {{n}} | {{n}} | {{n}} | {{pct}}% |
| Task | {{n}} | {{n}} | {{n}} | {{pct}}% |

## Dependencies

### External Blockers

| Sprint Item | Blocked By | External Iteration | Status |
| ----------- | ---------- | ------------------ | ------ |
| {{id}} | {{blocker_id}} | {{iteration}} | {{status}} |

### Internal Chains

| Predecessor | Successor | Relationship |
| ----------- | --------- | ------------ |
| {{pred_id}} | {{succ_id}} | {{link_type}} |

## Gap Analysis

{{gap_analysis_results or "No reference documents provided for gap analysis."}}

## Backlog Grooming Candidates

| ID | Title | Priority | Story Points | Rationale |
| -- | ----- | -------- | ------------ | --------- |
| {{id}} | {{title}} | {{priority}} | {{points}} | {{rationale}} |

## Recommended Actions

* {{action_item}}
<!-- markdown-table-prettify-ignore-end -->
```

### planning-log.md

Use the planning-log.md template from the planning specification. Set the planning type to `Sprint` and track each analysis step through discovery, analysis, and planning.

## Success Criteria

Sprint planning is complete when:

* The target iteration has been identified and its work items retrieved.
* Coverage, capacity, dependency, and (optionally) gap analyses have been performed.
* A sprint-plan.md exists with all analysis sections populated.
* Backlog grooming candidates have been identified and ranked when capacity permits.
* The user has reviewed the plan and any recommended actions.
* planning-log.md reflects the final state of all analysis steps.

---

Brought to you by microsoft/hve-core
