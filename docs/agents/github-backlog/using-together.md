---
title: Using Workflows Together
description: Connect discovery, triage, sprint planning, and execution into a complete backlog management pipeline
author: Microsoft
ms.date: 2026-02-12
ms.topic: tutorial
keywords:
  - github backlog manager
  - workflow pipeline
  - github copilot
  - backlog management
estimated_reading_time: 8
---

Each backlog manager workflow handles one phase of issue management. Connecting them creates a pipeline that takes issues from discovery through execution, with structured handoffs ensuring nothing falls through the cracks.

## The Pipeline

```text
┌───────────┐    ┌────────┐    ┌─────────────────┐    ┌───────────┐
│ Discovery │ ──→│ Triage │ ──→│ Sprint Planning │ ──→│ Execution │
└───────────┘    └────────┘    └─────────────────┘    └───────────┘
      ↑                                                      │
      └──────────────── Iterate ─────────────────────────────┘
```

The pipeline is linear but not rigid. Skip sprint planning when you only need to apply labels. Return to discovery after execution when new issues surface. Each workflow reads its predecessor's output files, so the pipeline works as long as the handoff artifacts exist.

## Clear Context Between Workflows

Each workflow operates within its own session context. Mixing workflows in a single session produces unreliable results because the agent carries forward assumptions from the previous workflow.

Between each workflow:

1. Type `/clear` to reset the conversation context
2. Attach or reference the output files from the previous workflow
3. Start the next workflow with a fresh prompt

This is the single most important practice for reliable pipeline execution. The `/clear` step takes seconds and prevents hours of debugging misapplied labels or incorrect milestone assignments.

> [!IMPORTANT]
> The `/clear` step between workflows is not optional. Each workflow loads specific instruction files and planning artifacts. Stale context from a previous workflow interferes with the current workflow's classification logic.

All GitHub-facing comments (issue replies, label rationale, duplicate explanations) follow the voice and tone rules defined in `community-interaction.instructions.md`. This instruction file loads automatically when the backlog manager agents operate, so you do not need to configure it separately.

## End-to-End Walkthrough

This walkthrough covers a realistic pipeline run for a repository with accumulated issues that have not been reviewed.

### Step 1: Discover Issues

Start with a scoped discovery pass:

```text
Discover all open issues in microsoft/hve-core that are unassigned
and don't have a milestone. Include issues labeled "needs-triage".
```

Discovery produces analysis files in `.copilot-tracking/github-issues/discovery/hve-core/`. Review the issue analysis to confirm the scope is correct before proceeding.

### Step 2: Clear and Triage

```text
/clear
```

Then start triage:

```text
Triage the issues from my latest discovery session for microsoft/hve-core.
Flag duplicates with confidence scores and suggest labels using the
standard taxonomy.
```

Review the triage plan at `.copilot-tracking/github-issues/triage/<YYYY-MM-DD>/triage-plan.md`. Adjust any label suggestions or duplicate flags before continuing.

### Step 3: Clear and Plan

```text
/clear
```

Then plan the sprint:

```text
Plan sprint assignments for microsoft/hve-core using the triage results.
Assign high-priority bugs to the v2.1 milestone and enhancements to v2.2.
```

Review the sprint plan and handoff file. Adjust milestone assignments for any issues where the automatic mapping doesn't fit.

### Step 4: Clear and Execute

```text
/clear
```

Then execute:

```text
Execute the sprint planning handoff for microsoft/hve-core. Apply all
checked operations in the handoff file.
```

Check the execution log for any skipped operations or state conflicts.

### Step 5: Iterate

Review the execution results. If new issues were discovered during the process, or if some operations were skipped due to conflicts, return to discovery or triage for another pass.

## Planning File Lifecycle

Planning files move through three states during the pipeline:

| State         | Location                                  | Created By      | Consumed By |
|---------------|-------------------------------------------|-----------------|-------------|
| Analysis      | `discovery/<scope>/issue-analysis.md`     | Discovery       | Triage      |
| Triage Plan   | `triage/<YYYY-MM-DD>/triage-plan.md`      | Triage          | Execution   |
| Sprint Plan   | `sprint/<milestone-kebab>/handoff.md`     | Sprint Planning | Execution   |
| Execution Log | `<planning-type>/<scope>/handoff-logs.md` | Execution       | User review |

Files are created once and updated in place. The execution workflow marks checkboxes in handoff files as it processes each operation, providing a built-in audit trail.

## Iteration Model

Most backlogs require multiple passes through the pipeline. The iteration model supports this with three patterns:

* Full cycle: Run all four workflows when starting a new sprint or onboarding a new repository
* Triage-execute: Skip sprint planning when applying label corrections or closing duplicates
* Discovery-only: Run discovery periodically to monitor for new issues without immediate action

Each pass produces independent output files scoped by date and target, so previous results are preserved for comparison.

## Artifact Summary

| Workflow        | Input            | Output                                | Key File            |
|-----------------|------------------|---------------------------------------|---------------------|
| Discovery       | Repository scope | Issue inventory and recommendations   | `issue-analysis.md` |
| Triage          | Discovery output | Label suggestions and duplicate flags | `triage-plan.md`    |
| Sprint Planning | Triage output    | Milestone assignments and sequencing  | `handoff.md`        |
| Execution       | Handoff files    | Applied changes and operation log     | `handoff-logs.md`   |

## Quick Reference

| Task                        | Workflow           | Prompt Example                                   |
|-----------------------------|--------------------|--------------------------------------------------|
| Survey open issues          | Discovery          | "Discover open issues assigned to me"            |
| Assign labels to new issues | Triage             | "Triage issues from my latest discovery"         |
| Find and close duplicates   | Triage + Execution | "Check for duplicates and close confirmed ones"  |
| Plan the next sprint        | Sprint Planning    | "Plan sprint assignments for the v2.1 milestone" |
| Apply all recommendations   | Execution          | "Execute the triage handoff"                     |
| Full backlog review         | All four workflows | Run each in sequence with `/clear` between them  |

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
