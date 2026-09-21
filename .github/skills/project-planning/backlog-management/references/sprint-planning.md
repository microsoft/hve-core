---
description: 'Platform-neutral sprint and iteration planning workflow with an iteration container binding table and per-platform deltas'
---

<!-- markdownlint-disable-file -->
# Sprint and Iteration Planning

Platform-agnostic protocol for planning a time-boxed delivery window by analyzing coverage, capacity, dependencies, and gaps. Read this alongside the [core conventions](../SKILL.md), the [workflow protocols](workflows.md), and the active platform reference. Every command, field, and container name below is a platform binding; resolve it through the platform reference before use rather than assuming a literal name.

## Iteration Container Binding

Each platform expresses a time-boxed window through its own container. The workflow is identical across them; only the container and its retrieval differ.

| Binding                 | Resolve through the platform reference                              |
|-------------------------|---------------------------------------------------------------------|
| Iteration container     | The platform's sprint, iteration, or milestone concept              |
| Enumerate containers    | The command that lists available containers with their date ranges  |
| Retrieve planned items  | The command that returns items assigned to a container              |
| Retrieve unplanned work | The command that returns backlog items assigned to no container     |
| Effort field            | The platform's estimate or points field, when the platform has one  |
| Grouping field          | The platform's area, component, or label used for coverage analysis |
| Assignment field        | The platform's assignee field                                       |
| Tracking root           | The platform tracking root, with planning type `sprint`             |

A platform lacking a native effort field reports item counts instead of effort totals and states that substitution in the plan rather than silently omitting the section.

## Required Phases

### Phase 1: Discover and Retrieve

Gather container metadata and the items in scope.

#### Step 1: Discover iterations

Enumerate the available containers. Identify the current one (the date range containing today), the next, and any future containers within the planning horizon.

Record in `planning-log.md`:

* Container name and path or identifier
* Start date and end date
* Whether it is current, next, or future

When the caller names a specific container, use it. Otherwise default to the current one.

#### Step 2: Retrieve planned items

Retrieve every item assigned to the target container, then hydrate the results with an explicit field list so state, grouping, type, priority, effort, and assignment are available for analysis. Hydration matters because most platforms return sparse items from a container query.

#### Step 3: Retrieve unplanned work

Retrieve backlog items assigned to no container. These candidates feed the grooming recommendations in Phase 3.

### Phase 2: Analyze

Evaluate the container across four dimensions: coverage, capacity, gaps, and dependencies.

#### Step 1: Triage prerequisite check

Count items in the platform's initial or unrefined state. When more than half of the items in the container sit in that state, recommend running the Triage workflow before continuing. Log the recommendation and inform the user.

Planning can continue alongside a triage recommendation, but the plan notes that classifications may shift once triage completes.

#### Step 2: Coverage analysis

Build a grouping coverage matrix showing which groups are represented and which are missing.

| Group       | Items | Effort     | Status      |
|-------------|-------|------------|-------------|
| {{group}}   | {{n}} | {{effort}} | Covered     |
| {{missing}} | 0     | 0          | Not Covered |

Identify groups with active backlog work but no representation in the container, and flag them as coverage gaps.

When the platform has a parent-child hierarchy, also build a hierarchy coverage matrix showing decomposition completeness by level. Use the levels defined in [story-quality.md](story-quality.md) and the platform's mapping onto them.

| Level      | Total | With children | Orphaned | Completeness |
|------------|-------|---------------|----------|--------------|
| Epic       | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |
| Feature    | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |
| User story | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |
| Task       | {{n}} | {{n}}         | {{n}}    | {{pct}}%     |

Identify orphaned stories, features without parents, and stories lacking decomposition. Report only the levels the platform actually models; a platform with a flat issue model reports what its grouping mechanism supports rather than fabricating levels.

#### Step 3: Capacity analysis

Sum planned effort using the platform's effort field for each item type that carries one.

When the caller supplies team capacity, compare planned effort against it:

| Metric         | Value           |
|----------------|-----------------|
| Planned effort | {{total}}       |
| Team capacity  | {{capacity}}    |
| Utilization    | {{percentage}}% |
| Remaining      | {{remaining}}   |

Include burndown metrics when the platform tracks completed and remaining work separately:

| Metric            | Value                                        |
|-------------------|----------------------------------------------|
| Original estimate | Sum of the original estimate across items    |
| Completed work    | Sum of completed work across items           |
| Remaining work    | Sum of remaining work across items           |
| Burndown ratio    | Completed divided by original estimate, as % |

When capacity is not supplied, report planned effort totals and recommend that the user supply capacity data for utilization. Break effort down by assignee when assignment data is available.

#### Step 4: Gap analysis

Cross-reference requirements documents, PRDs, or other planning artifacts against the container contents when such documents are supplied. Identify requirements with no matching item.

When no documents are supplied, skip this step and note that gap analysis requires reference documents. Do not infer requirements from item titles.

#### Step 5: Dependency detection

Examine item links for parent-child and predecessor-successor relationships:

* Items with predecessors outside the container (external blockers).
* Items with successors inside the container (internal chains).
* Items with unresolved parent links or missing children.

Record dependency chains in `planning-log.md`. Relationship semantics vary by platform; resolve them through the platform reference, which also states whether the platform models ordered dependencies at all.

### Phase 3: Plan

Produce the plan and grooming recommendations.

#### Step 1: Backlog grooming recommendations

From the unplanned work retrieved in Phase 1, identify candidates to pull in. Evaluate by:

* Priority — higher-priority items first.
* Capacity — remaining capacity after planned items.
* Dependencies — items whose predecessors are complete or already in the container.
* Coverage — items that fill an identified coverage gap.
* Readiness — items satisfying the Completeness Dimensions in [story-quality.md](story-quality.md). An item failing them is recommended for grooming rather than for the container.

Rank the candidates and present the top recommendations.

#### Step 2: Generate the plan

Create `sprint-plan.md` under the platform tracking root with planning type `sprint` and the container name normalized per the core scope-name rules.

#### Step 3: Present for review

Present the plan, highlighting capacity utilization and over- or under-commitment, coverage gaps, external dependencies and blockers, and grooming candidates ranked by fit.

Sprint planning is read-only. Moving an item into a container is a mutation and belongs to the Execution workflow under its autonomy gate; this workflow recommends and never reassigns.

## Output

### sprint-plan.md template

Planning markdown files start and end with the directives defined in the Planning File Requirements section of the core skill.

```markdown
<!-- markdownlint-disable-file -->
<!-- markdown-table-prettify-ignore-start -->
# Sprint Plan - {{container_name}}

* **Platform**: {{platform}}
* **Project or repository**: {{project}}
* **Container**: {{container_path_or_id}}
* **Dates**: {{start_date}} to {{end_date}}
* **Team capacity**: {{capacity}} (when provided)
* **Date generated**: {{YYYY-MM-DD}}

## Summary

| Metric              | Value              |
| ------------------- | ------------------ |
| Planned items       | {{n}}              |
| Planned effort      | {{effort_or_n_a}}  |
| Capacity            | {{capacity_or_n_a}}|
| Utilization         | {{pct_or_n_a}}     |
| Coverage gaps       | {{n}}              |
| External blockers   | {{n}}              |

## Coverage

{{grouping_coverage_matrix}}

{{hierarchy_coverage_matrix_when_supported}}

## Capacity

{{capacity_tables}}

## Dependencies

{{dependency_chains_and_external_blockers}}

## Grooming Recommendations

{{ranked_candidates_with_rationale}}

## Open Questions

{{unresolved_items}}
<!-- markdown-table-prettify-ignore-end -->
```
