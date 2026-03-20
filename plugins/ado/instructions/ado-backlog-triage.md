---
description: "Triage workflow for Azure DevOps work items with field classification, iteration assignment, and duplicate detection - Brought to you by microsoft/hve-core"
applyTo: '**/.copilot-tracking/workitems/triage/**'
---

# ADO Work Item Triage

Triage new or unclassified Azure DevOps work items by assigning Area Path, Priority, Severity (bugs only), Tags, and Iteration Path, while detecting duplicates. Follow all instructions from #file:ado-wit-planning.md while executing this workflow.

Use interaction templates from #file:ado-interaction-templates.md when posting triage results as work item comments.

## Autonomy Behavior for Triage Operations

| Operation                   | Full         | Partial      | Manual       |
|-----------------------------|--------------|--------------|--------------|
| Area Path assignment        | Auto-execute | Auto-execute | Gate on user |
| Priority assignment         | Auto-execute | Auto-execute | Gate on user |
| Tag assignment              | Auto-execute | Auto-execute | Gate on user |
| Iteration assignment        | Auto-execute | Gate on user | Gate on user |
| Duplicate resolution        | Auto-execute | Gate on user | Gate on user |
| State change (New → Active) | Auto-execute | Gate on user | Gate on user |

## Triage Trigger Criteria

Work items qualify for triage when they meet any of these conditions:

* `System.State` is `New` and `System.AreaPath` equals the project root (no sub-path assigned)
* `System.State` is `New` and `Microsoft.VSTS.Common.Priority` remains at the default value of 2 without explicit user assignment
* `System.State` is `New` and `System.Tags` is empty

Retrieve candidates by searching for work items in the `New` state via `mcp_ado_search_workitem` with `state: ["New"]` and filtering results for incomplete classification.

## Required Phases

### Phase 1: Analyze

Fetch and analyze work items to build a triage assessment. Proceed to Phase 2 when all fetched items have been analyzed and recorded.

#### Step 1: Discover Area Paths and Iterations

Before analyzing work items, discover available classification structures.

1. Call `mcp_ado_search_workitem` with broad terms to sample existing Area Path patterns across the project. Record discovered Area Paths in planning-log.md.
2. Call `mcp_ado_work_list_team_iterations` to enumerate available iterations. Identify the current iteration (dates containing today) and the next iteration.
3. Record iteration names, date ranges, and capacity information in planning-log.md.

#### Step 2: Fetch Candidate Work Items

Search for work items meeting the triage trigger criteria:

```text
mcp_ado_search_workitem with state: ["New"], project: ["{{project}}"]
```

Paginate using `top` and `skip` parameters, limiting to `maxItems` total work items.

When no candidates are found, inform the user and end the workflow.

#### Step 3: Hydrate Work Item Details

For each candidate, fetch full details using `mcp_ado_wit_get_work_items_batch_by_ids` to retrieve all field values including Area Path, Priority, Severity, Tags, Iteration Path, and Description.

#### Step 4: Classify Each Work Item

For each work item, perform the following classification across five dimensions.

##### Area Path

Analyze title and description content to identify component, feature area, or team references. Map to the closest matching Area Path from the patterns discovered in Step 1. When no clear match exists, flag for manual review.

##### Priority

Reset from the default value of 2 based on content analysis.

| Priority | Criteria                                                          |
|----------|-------------------------------------------------------------------|
| 1        | Critical or blocking: production outage, data loss, security flaw |
| 2        | Default or unclassified: requires content analysis to reclassify  |
| 3        | Standard: functional improvement, moderate impact                 |
| 4        | Nice-to-have: cosmetic, minor convenience, low impact             |

##### Severity (Bugs Only)

Apply only when `System.WorkItemType` is `Bug`.

| Severity | Criteria                                                    |
|----------|-------------------------------------------------------------|
| 1        | System crash, data loss, or complete feature unavailability |
| 2        | Major feature broken with no workaround                     |
| 3        | Minor impact with viable workaround                         |
| 4        | Cosmetic or trivial issue                                   |

##### Tags

Extract keywords from title and description. Cross-reference against existing tags discovered via search results. Assign tags that align with the project's established taxonomy.

##### Iteration

Assign to the current or next iteration based on priority and capacity. Priority 1 items target the current iteration; Priority 3-4 items target the next iteration. Priority 2 items require content analysis before assignment.

#### Step 5: Detect Duplicates

For each work item, search for potential duplicates using `mcp_ado_search_workitem` with keyword groups extracted from the title.

1. Extract 2-4 keyword groups from the work item title and description.
2. Execute searches for each keyword group scoped to the project.
3. Apply the Similarity Assessment Framework from #file:ado-wit-planning.md to evaluate each candidate.

Classify results using the Similarity Categories:

| Category  | Score Range | Action                                                             |
|-----------|-------------|--------------------------------------------------------------------|
| Match     | > 0.8       | Suggest closing as duplicate with a reference to the original item |
| Similar   | 0.5 - 0.8   | Flag both items for user review with a comparison summary          |
| Distinct  | < 0.5       | Proceed with classification                                        |
| Uncertain | N/A         | Request user guidance before taking action                         |

#### Step 6: Record Analysis

Create planning-log.md in `.copilot-tracking/workitems/triage/{{YYYY-MM-DD}}/` to track progress. Update the log as each work item is analyzed, recording:

* Work item ID and title
* Current field values
* Suggested Area Path, Priority, Severity, Tags, Iteration Path
* Duplicate candidates with similarity category
* Classification rationale

### Phase 2: Plan and Execute

Produce a triage plan for user review and execute confirmed recommendations.

#### Step 1: Generate Triage Plan

Create triage-plan.md in `.copilot-tracking/workitems/triage/{{YYYY-MM-DD}}/` with a recommendation row per work item. Use the triage plan template defined in the Output section.

#### Step 2: Present for Review

Present the triage plan to the user, highlighting:

* Work items with high-confidence classification suggestions
* Work items flagged as potential duplicates
* Work items requiring manual review (ambiguous content, conflicting signals, uncertain similarity)

When `autonomy` is `full`, proceed directly to Step 3 without waiting for user confirmation. When `partial`, gate on iteration assignment and duplicate resolution. When `manual`, wait for user confirmation of the entire plan.

#### Step 3: Execute Confirmed Recommendations

On user confirmation (or immediately under full autonomy), apply the approved recommendations.

For classified non-duplicate work items, use `mcp_ado_wit_update_work_items_batch` to apply field updates:

* `System.AreaPath`: suggested Area Path
* `Microsoft.VSTS.Common.Priority`: reclassified Priority
* `Microsoft.VSTS.Common.Severity`: reclassified Severity (bugs only)
* `System.Tags`: computed tag set (existing tags merged with suggested tags)
* `System.IterationPath`: assigned iteration
* `System.State`: transition from `New` to `Active` when classification is complete

For confirmed duplicates:

1. Post a comment using `mcp_ado_wit_add_work_item_comment` with the B3 (Duplicate Closure) template from #file:./ado-interaction-templates.instructions.md, filling the original work item ID.
2. Link the duplicate to the original using `mcp_ado_wit_work_items_link` with link type `Duplicate Of`.
3. Update `System.State` to `Resolved` with `System.Reason` set to `Duplicate` via `mcp_ado_wit_update_work_item`.

Update planning-log.md checkboxes as each operation completes.

## Error Handling

Handle API failures and edge cases during triage execution:

* When a field update fails due to a validation error (invalid Area Path, unsupported Iteration Path), log the error, skip the affected work item, and flag it for manual review in the triage plan.
* When `mcp_ado_search_workitem` returns no results for a duplicate search query, record "no duplicates found" and proceed with classification.
* When a work item has been modified between analysis and execution (state changed externally), re-fetch the work item details before applying updates.
* When the comment step of a duplicate resolution fails, log the failure and proceed with the link and state change. The link carries the authoritative relationship; the comment provides team context.

## Output

The triage workflow produces output files in `.copilot-tracking/workitems/triage/{{YYYY-MM-DD}}/`.

### triage-plan.md Template

Planning markdown files must start and end with the directives defined in the planning specification.

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
# Triage Plan - {{YYYY-MM-DD}}

* **Project**: {{project}}
* **Items Analyzed**: {{count}}
* **Date**: {{YYYY-MM-DD}}

## Summary

| Action           | Count               |
| ---------------- | ------------------- |
| Classify + Assign | {{classify_count}}  |
| Close Duplicate   | {{duplicate_count}} |
| Manual Review     | {{review_count}}    |

## Triage Recommendations

| Work Item | Title | Area Path | Priority | Severity | Tags | Iteration | Duplicates | Action |
| --------- | ----- | --------- | -------- | -------- | ---- | --------- | ---------- | ------ |
| {{id}} | {{title}} | {{area_path}} | {{priority}} | {{severity}} | {{tags}} | {{iteration}} | {{duplicate_refs}} | {{action}} |

## Items Requiring Manual Review

### {{id}}: {{title}}

* **Reason**: {{reason for manual review}}
* **Current Fields**: {{existing field values}}
* **Suggested Fields**: {{suggested field values}}
* **Notes**: {{additional context}}

## Duplicate Pairs

### {{untriaged_id}} duplicates {{original_id}}

* **Similarity Category**: Match
* **Rationale**: {{explanation}}
* **Recommended Action**: Close {{untriaged_id}} as duplicate of {{original_id}}
<!-- markdown-table-prettify-ignore-end -->
```

### planning-log.md

Use the planning-log.md template from the planning specification. Set the planning type to `Triage` and track each work item through analysis, planning, and execution.

## Success Criteria

Triage is complete when:

* All fetched work items meeting the trigger criteria have been analyzed for Area Path, Priority, Severity, Tags, Iteration, and duplicate candidates.
* A triage-plan.md exists with a recommendation row for every analyzed work item.
* The user has reviewed and confirmed (or adjusted) the triage plan, respecting the active autonomy tier.
* Confirmed recommendations have been executed via batch API calls (fields assigned, duplicates linked and resolved).
* planning-log.md reflects the final state with checkboxes marking completion.
* Any failed operations have been logged and either retried or flagged for manual follow-up.

---

Brought to you by microsoft/hve-core
