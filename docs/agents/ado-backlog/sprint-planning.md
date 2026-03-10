---
title: Sprint Planning Workflow
description: Organize triaged work items into Azure DevOps iterations with coverage analysis, capacity tracking, and gap detection
author: Microsoft
ms.date: 2026-02-26
ms.topic: tutorial
keywords:
  - azure devops backlog manager
  - sprint planning
  - iterations
  - capacity tracking
  - github copilot
estimated_reading_time: 6
sidebar_position: 5
---

The Sprint Planning workflow organizes triaged work items into Azure DevOps iterations, analyzes coverage across area paths, tracks capacity utilization, and detects gaps in work item decomposition hierarchies.

## When to Use

* 📅 Starting a new sprint or iteration and need to assign work items
* 🎯 Work items have been triaged but lack Iteration Path assignments
* 🔄 Rebalancing work across iterations after scope changes or team adjustments
* 📊 Analyzing hierarchy coverage to find orphaned stories or features without decomposition
* 📋 Checking team capacity against planned effort for an upcoming sprint

## What It Does

1. Discovers available iterations and identifies the current, next, and future sprints
2. Retrieves work items already assigned to the target iteration
3. Retrieves unplanned backlog items not assigned to any iteration
4. Checks triage prerequisite (flags when over 50% of items are still in `New` state)
5. Builds area path and hierarchy coverage matrices
6. Analyzes capacity utilization when team capacity data is provided
7. Cross-references requirements documents against the backlog for gap detection
8. Produces sprint plan recommendations and execution-ready handoff files

> [!NOTE]
> Sprint planning coordinates Discovery and Triage inline when needed. If the target iteration contains many unclassified items, the workflow recommends running triage before finalizing the plan.

## Coverage Analysis

### Area Path Coverage

The workflow builds a coverage matrix showing which area paths are represented in the sprint:

| Area Path      | Items | Story Points | Status      |
|----------------|-------|--------------|-------------|
| Components     | 5     | 21           | Covered     |
| Infrastructure | 0     | 0            | Not Covered |

Area paths with active backlog items but no representation in the sprint are flagged as coverage gaps.

### Hierarchy Coverage

A hierarchy coverage matrix shows decomposition completeness at each level:

| Level   | Total | With Children | Orphaned | Completeness |
|---------|-------|---------------|----------|--------------|
| Epic    | 3     | 3             | 0        | 100%         |
| Feature | 8     | 6             | 2        | 75%          |
| Story   | 15    | 12            | 3        | 80%          |
| Task    | 24    | N/A           | N/A      | N/A          |

The matrix identifies orphaned stories (no parent Feature), features without parent Epics, and stories lacking Task decomposition. This four-level hierarchy analysis is a capability that flat issue trackers cannot provide.

## Capacity Analysis

When team capacity is provided, the workflow compares planned effort against available capacity:

| Metric         | Value  |
|----------------|--------|
| Planned Effort | 42 pts |
| Team Capacity  | 55 pts |
| Utilization    | 76%    |
| Remaining      | 13 pts |

Burndown metrics appear when `CompletedWork` data is available, showing original estimates, completed work, remaining work, and the burndown ratio.

## Output Artifacts

```text
.copilot-tracking/workitems/sprint/<iteration-kebab>/
├── planning-log.md     # Progress tracking and analysis results
├── work-items.md       # Iteration mapping and capacity review
└── handoff.md          # Execution-ready assignments
```

## How to Use

### Option 1: Prompt Shortcut

```text
Plan the next sprint for my Azure DevOps project using my latest triage results
```

```text
Analyze capacity and coverage for the current iteration
```

### Option 2: Handoff Button

Click the "Sprint" handoff button in the ADO Backlog Manager agent to launch sprint planning with the standard prompt.

### Option 3: Direct Agent

Start a conversation with the ADO Backlog Manager agent and describe your sprint planning goal. The agent classifies your intent and begins iteration discovery automatically.

## Example Prompts

Full sprint plan with capacity analysis:

```text
Plan sprint assignments for the Sprint 24 iteration. Analyze:
- Area path coverage gaps across all triaged items
- Hierarchy decomposition completeness (Epics to Stories to Tasks)
- Capacity utilization against our team capacity of 55 story points
- Priority sequencing within the iteration
```

Coverage gap analysis without assignments:

```text
Analyze the current backlog for Sprint 25 readiness. Show which area
paths have no planned work, identify orphaned items missing parent
links, and flag Stories without Task decomposition. Do not assign
items to the iteration yet.
```

Reassignment of items from a closed iteration:

```text
Find all work items still assigned to Sprint 22 that are not in the
Closed state. Recommend reassignment to Sprint 24 or Sprint 25 based
on priority and remaining capacity.
```

**Output artifacts:** Sprint planning creates a handoff file with iteration assignments and a coverage matrix. Review capacity utilization warnings and coverage gaps before passing the handoff to execution.

## Tips

* ✅ Run triage before sprint planning so work items have consistent fields and priorities
* ✅ Review coverage matrices to identify underrepresented areas before finalizing
* ✅ Provide team capacity data for utilization calculations
* ✅ Use hierarchy coverage to find orphaned items that need parent links
* ❌ Do not plan sprints without triaged items (items lacking classification produce unreliable plans)
* ❌ Do not ignore capacity warnings for iterations approaching their end date
* ❌ Do not assume the workflow sees all projects (verify MCP token permissions)
* ❌ Do not skip the triage prerequisite check when many items remain in `New` state

## Common Pitfalls

| Pitfall                                  | Solution                                                                   |
|------------------------------------------|----------------------------------------------------------------------------|
| Work items assigned to closed iterations | The workflow flags these for reassignment; review before execution         |
| Iteration names do not match project     | Verify iteration names in the handoff match existing iterations exactly    |
| Priority conflicts within an iteration   | Review the sequencing recommendations and adjust priority values first     |
| Too many items for a single iteration    | Split across iterations or re-prioritize lower-priority items out          |
| Over 50% of items still in New state     | Run triage first; sprint planning proceeds but notes that fields may shift |

## Next Steps

1. Review the sprint plan and handoff file for accuracy
2. Proceed to the [Execution workflow](execution.md) to apply iteration assignments

> [!TIP]
> For teams with fixed sprint cadences, create iterations in advance through Azure DevOps project settings. Sprint planning works best when it maps to existing iterations rather than recommending new ones.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
