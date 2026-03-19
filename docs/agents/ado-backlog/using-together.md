---
title: Using Workflows Together
description: Connect discovery, triage, sprint planning, and execution into a complete Azure DevOps backlog management pipeline
author: Microsoft
ms.date: 2026-02-26
ms.topic: tutorial
keywords:
  - azure devops backlog manager
  - workflow pipeline
  - github copilot
  - backlog management
estimated_reading_time: 8
sidebar_position: 11
---

Each backlog manager workflow handles one phase of work item management. Connecting them creates a pipeline that takes work items from discovery through execution, with structured handoffs ensuring nothing falls through the cracks.

## The Pipeline

```text
┌───────────┐    ┌────────┐    ┌─────────────────┐    ┌───────────┐
│ Discovery │ ──→│ Triage │ ──→│ Sprint Planning │ ──→│ Execution │
└───────────┘    └────────┘    └─────────────────┘    └───────────┘
      ↑                                                      │
      └──────────────── Iterate ─────────────────────────────┘
```

The pipeline is linear but not rigid. Skip sprint planning when you only need to apply field assignments. Return to discovery after execution when new items surface. Each workflow reads its predecessor's output files, so the pipeline works as long as the handoff artifacts exist.

## Clear Context Between Workflows

Each workflow operates within its own session context. Mixing workflows in a single session produces unreliable results because the agent carries forward assumptions from the previous workflow.

Between each workflow:

1. Type `/clear` to reset the conversation context
2. Reference the output files from the previous workflow
3. Start the next workflow with a fresh prompt

This is the single most important practice for reliable pipeline execution. The `/clear` step takes seconds and prevents hours of debugging misapplied fields or incorrect iteration assignments.

> [!IMPORTANT]
> The `/clear` step between workflows is not optional. Each workflow loads specific instruction files and planning artifacts. Stale context from a previous workflow interferes with the current workflow's classification logic.

## Interaction Templates

All work item descriptions and comments follow the templates defined in `ado-interaction-templates.instructions.md`. Templates exist in both Markdown and HTML variants, and the correct format is selected automatically based on content format detection. This instruction file loads automatically when the backlog manager operates, so no separate configuration is needed.

## End-to-End Walkthrough

This walkthrough covers a realistic pipeline run for a project with accumulated work items that have not been reviewed.

### Step 1: Discover Work Items

Start with a scoped discovery pass:

```text
Discover all work items in my project that are in the New state
and don't have an iteration assigned. Include items with missing
Area Path classification.
```

Discovery produces analysis files in `.copilot-tracking/workitems/discovery/<scope-name>/`. Review the analysis to confirm the scope is correct before proceeding.

### Step 2: Clear and Triage

```text
/clear
```

Then start triage:

```text
Triage the work items from my latest discovery session. Assign Area Paths,
reclassify priorities, and flag duplicates with confidence scores.
```

Review the triage results at `.copilot-tracking/workitems/triage/<YYYY-MM-DD>/work-items.md`. Adjust any classification suggestions before continuing.

### Step 3: Clear and Plan Sprint

```text
/clear
```

Then plan the sprint:

```text
Plan sprint assignments using the triage results. Show area path coverage,
hierarchy completeness, and capacity analysis for the upcoming iteration.
```

Review the sprint plan and handoff file. Adjust iteration assignments for any items where the automatic mapping does not fit.

### Step 4: Clear and Execute

```text
/clear
```

Then execute:

```text
Execute the sprint planning handoff. Apply all checked operations.
```

Check the execution log for any skipped operations or state conflicts.

### Step 5: Iterate

Review the execution results. If new items were discovered during the process, or if some operations were skipped due to conflicts, return to discovery or triage for another pass.

## Alternative Pipelines

Not every situation requires the full pipeline. Common variations:

### PRD-to-Execution

Convert a requirements document directly to work items:

```text
┌──────────────┐    ┌───────────┐
│ PRD Planning │ ──→│ Execution │
└──────────────┘    └───────────┘
```

Use when building an initial backlog from a specification. Skip discovery and triage because the PRD planning workflow handles decomposition and field assignment.

### Triage-Execute

Apply field corrections without sprint planning:

```text
┌───────────┐    ┌────────┐    ┌───────────┐
│ Discovery │ ──→│ Triage │ ──→│ Execution │
└───────────┘    └────────┘    └───────────┘
```

Use for backlog cleanup sessions focused on field consistency and duplicate resolution.

### Discovery Only

Survey the backlog without making changes:

```text
┌───────────┐
│ Discovery │
└───────────┘
```

Run discovery periodically to monitor for new items without immediate action.

## Planning File Lifecycle

Planning files move through states during the pipeline:

| State          | Location                                 | Created By      | Consumed By    |
|----------------|------------------------------------------|-----------------|----------------|
| Analysis       | `discovery/<scope>/planning-log.md`      | Discovery       | Triage         |
| Classification | `triage/<YYYY-MM-DD>/work-items.md`      | Triage          | Sprint/Execute |
| Sprint Plan    | `sprint/<iteration-kebab>/handoff.md`    | Sprint Planning | Execution      |
| PRD Hierarchy  | `prds/<name>/handoff.md`                 | PRD Planning    | Execution      |
| Execution Log  | `execution/<YYYY-MM-DD>/handoff-logs.md` | Execution       | User review    |

Files are created once and updated in place. The execution workflow marks checkboxes in handoff files as it processes each operation, providing a built-in audit trail.

## Handoff Buttons

The ADO Backlog Manager provides handoff buttons for quick workflow transitions:

| Button   | Action                                             |
|----------|----------------------------------------------------|
| Discover | Start a discovery session with the standard prompt |
| Triage   | Begin triage using latest discovery output         |
| Sprint   | Launch sprint planning with latest triage results  |
| Execute  | Process pending handoff operations                 |
| Add      | Quick-add a single work item                       |
| Plan     | Prioritize current assigned work                   |
| PRD      | Delegate to PRD-to-WIT conversion                  |
| Build    | Check pipeline status                              |
| PR       | Create an Azure DevOps pull request                |
| Save     | Save session state for later resumption            |

## Artifact Summary

| Workflow         | Input            | Output                                      | Key File          |
|------------------|------------------|---------------------------------------------|-------------------|
| Discovery        | Project scope    | Work item inventory and recommendations     | `planning-log.md` |
| Triage           | Discovery output | Field suggestions and duplicate flags       | `work-items.md`   |
| PRD Planning     | Requirements doc | Work item hierarchy with parent-child links | `handoff.md`      |
| Sprint Planning  | Triage output    | Iteration assignments and capacity analysis | `handoff.md`      |
| Execution        | Handoff files    | Applied changes and operation log           | `handoff-logs.md` |
| Task Planning    | Assigned items   | Prioritized task list with reasoning        | `task-list.md`    |
| Build Monitoring | PR or branch     | Pipeline status, logs, and failure details  | `build-status.md` |
| PR Creation      | Local changes    | Pull request with work item links           | `pr-details.md`   |

## Quick Reference

| Task                        | Workflow           | Prompt Example                                       |
|-----------------------------|--------------------|------------------------------------------------------|
| Survey open work items      | Discovery          | "Discover work items assigned to me"                 |
| Classify unreviewed items   | Triage             | "Triage items from my latest discovery"              |
| Find and resolve duplicates | Triage + Execution | "Check for duplicates and resolve confirmed ones"    |
| Plan the next sprint        | Sprint Planning    | "Plan sprint assignments for the upcoming iteration" |
| Apply all recommendations   | Execution          | "Execute the triage handoff"                         |
| Convert a PRD to work items | PRD Planning       | "Convert this requirements doc to work items"        |
| Create a single bug quickly | Quick Add          | "Add a bug: login page crashes on empty password"    |
| Check pipeline status       | Build Info         | "Get build status for PR 1234"                       |
| Prioritize your task list   | Task Planning      | "Plan my tasks for today"                            |
| Create a pull request       | PR Creation        | "Create a PR for my current branch"                  |
| Full backlog review         | All workflows      | Run each in sequence with `/clear` between them      |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
