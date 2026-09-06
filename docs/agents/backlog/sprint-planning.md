---
title: Sprint Planning Workflow
description: Organize work into iterations, milestones, or sprints with coverage, capacity, and gap analysis
author: Microsoft
ms.date: 2026-08-07
ms.topic: tutorial
keywords:
  - backlog management
  - sprint planning
  - iteration planning
  - milestone
  - github copilot
estimated_reading_time: 5
sidebar_position: 4
---

The Sprint Planning workflow organizes work into the platform's iteration container with coverage analysis, capacity tracking, dependency review, and gap detection. It is read-only: it produces a plan, not tracker changes.

Run it with `/backlog-plan sprint`.

## When to Use

* 📅 Preparing an upcoming iteration
* 📊 Assessing whether planned scope fits available capacity
* 🕳️ Checking a hierarchy for decomposition gaps
* 🔗 Reviewing dependencies before committing to scope

## What It Does

1. Resolves the backing tracker and its iteration container
2. Discovers the target iteration and derives its window
3. Analyzes coverage across hierarchy levels
4. Assesses planned scope against capacity signals
5. Flags dependencies, gaps, and items that do not fit
6. Produces an iteration plan for review

Sprint planning coordinates discovery and triage inline when the backlog is not already prepared: discovery produces the candidate set, then triage classifies it, then planning organizes the result.

## The Iteration Container

This is the single largest platform difference in the workflow.

| Binding             | Azure DevOps                     | GitHub                       | Jira                                      | GitHub capability status |
|---------------------|----------------------------------|------------------------------|-------------------------------------------|--------------------------|
| Container           | Iteration Path                   | Milestone                    | Sprint                                    | Supported                |
| Window              | Start and end dates on iteration | Due date only, start derived | Start and end dates on sprint             | Configuration required   |
| Effort field        | Story Points                     | None native                  | Story Points (instance-specific field ID) | Capability gap           |
| Container discovery | Team iteration list              | Repository milestone list    | Board sprint list                         | Supported                |

### GitHub capability gaps

Two gaps are real and are handled explicitly rather than silently approximated:

* **No native effort field.** Capacity analysis reports item counts instead of effort totals, unless you supply a size-label convention such as `size/S`, `size/M`, `size/L`. When you do, the mapping is recorded in the planning file.
* **A milestone has no start date.** The window start is derived, and the derivation basis is written into the planning file so the assumption is visible rather than buried.

### Jira field discovery

Story points, sprint, and burndown are instance-assigned custom fields whose IDs differ per Jira instance. The workflow confirms them through field discovery before use. A hardcoded field name would work on one instance and silently mis-read on another.

### Azure DevOps hydration

Azure DevOps requires a hydration step: the iteration query returns identifiers, and full field values are retrieved in a follow-up batch. Skipping it produces a plan built on partial data.

## Coverage Analysis

A hierarchy coverage matrix analyzes decomposition completeness across levels, surfacing where a parent has no children, where children do not sum to the parent's scope, and where items sit at a level their content does not match.

## Output Artifacts

Coverage and capacity are sections inside the plan, not separate files.

```text
<tracking-root>/sprint/<iteration-name>/
├── planning-log.md       # Iteration discovery, derivation basis, dependency chains, and phase tracking
└── sprint-plan.md        # Reviewed iteration plan: Summary, Coverage, Capacity, Dependencies, Grooming Recommendations, Open Questions
```

`sprint-plan.md` is the reviewable contract that `backlog-execute` consumes.

## Next Steps

* [Execution](execution.md): Apply the reviewed iteration plan
* [Task Planning](task-planning.md): Turn your slice of the iteration into an ordered plan
* [Using Workflows Together](using-together.md): End-to-end pipeline walkthrough

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
