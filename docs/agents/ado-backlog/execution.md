---
title: Execution Workflow
description: Apply triage and planning recommendations to Azure DevOps work items through structured handoff consumption
author: Microsoft
ms.date: 2026-02-26
ms.topic: tutorial
keywords:
  - azure devops backlog manager
  - work item execution
  - handoff
  - github copilot
estimated_reading_time: 5
sidebar_position: 7
---

The Execution workflow consumes handoff files from triage, sprint planning, and PRD planning, applying approved changes to Azure DevOps work items. It tracks progress through checkbox-based handoff logs and produces operation reports for audit and recovery.

## When to Use

* ✅ Triage, sprint planning, or PRD planning handoff files are ready for application
* 🏷️ Applying field changes, iteration assignments, or state transitions in bulk
* 🔗 Creating work item hierarchies with parent-child links
* 📝 Updating work item metadata across multiple items in a single session

## What It Does

1. Reads handoff files from upstream workflows (triage, sprint planning, PRD planning)
2. Validates each recommended operation against current work item state
3. Applies content sanitization to strip internal tracking references before API calls
4. Applies approved changes (field assignments, state transitions, comments) via ADO MCP tools
5. Marks each handoff checkbox as complete after successful application
6. Produces an operation log documenting what changed and what was skipped

> [!NOTE]
> Execution only processes checked items in the handoff file. Uncheck any recommendation you want to skip before starting the execution workflow.

## Content Sanitization

Before any ADO API call, the execution workflow strips internal tracking references:

* `.copilot-tracking/` file paths are removed from outbound content
* Planning reference IDs (such as `WI[NNN]`) are stripped from descriptions and comments
* Internal planning metadata never reaches Azure DevOps work item fields

This sanitization ensures clean, professional work item content regardless of the planning artifacts used during earlier phases.

## Content Format Detection

The execution workflow automatically selects the correct template format for your Azure DevOps environment:

| Environment           | Format   | Templates Used                               |
|-----------------------|----------|----------------------------------------------|
| Azure DevOps Services | Markdown | Markdown variants from interaction templates |
| Azure DevOps Server   | HTML     | HTML variants from interaction templates     |

Format detection happens automatically based on your MCP server URL. No manual configuration is required.

## Handoff Consumption

The execution workflow uses checkbox-based progress tracking in handoff files:

```markdown
## Pending Operations

- [x] WI 42 - Assign Area Path: Components/Auth (applied)
- [x] WI 42 - Set Priority: 1 (applied)
- [ ] WI 57 - Change State: New → Active (skipped - unchecked)
- [x] WI 63 - Add Tags: security, api (applied)
```

Each line represents one atomic operation. The workflow processes checked items sequentially, validating current work item state before each change. If a work item has been modified since triage (fields changed, state transitioned), the workflow flags the conflict and skips that operation rather than overwriting recent changes.

## Operation Logging

Every execution session produces a structured log:

* Operations attempted with timestamps
* Success and failure counts with error details
* Work items skipped due to state conflicts
* Remaining unprocessed items for recovery

This log supports recovery when execution is interrupted. Re-running execution on the same handoff file picks up where it left off because completed items are already checked.

## Output Artifacts

```text
.copilot-tracking/workitems/execution/<YYYY-MM-DD>/
└── handoff-logs.md    # Per-operation processing status
```

The consumed handoff file is updated in place as operations complete, marking checkboxes for processed items. The handoff log records per-operation results with processing status, supporting recovery when execution is interrupted.

## How to Use

### Option 1: Prompt Shortcut

```text
Execute the triage handoff for my Azure DevOps project
```

```text
Apply sprint planning assignments from my latest planning session
```

### Option 2: Handoff Button

Click the "Execute" handoff button in the ADO Backlog Manager agent after completing triage or sprint planning. The agent reads the pending operations and begins processing checked items.

### Option 3: Direct Agent

Reference the handoff file when starting an execution conversation:

```text
Execute the handoff at .copilot-tracking/workitems/triage/2026-02-26/work-items.md
```

## Example Prompts

Execute a triage handoff by file reference:

```text
Execute the handoff at
.copilot-tracking/workitems/triage/2026-02-26/work-items.md
Apply all checked operations. Write an operation log so I can verify
what changed.
```

Execute sprint planning assignments with safety filters:

```text
Execute the sprint planning handoff. Apply all checked operations and
skip any work items that have been modified in the last 24 hours. Use
partial autonomy so I can approve field changes before they are written.
```

Selective execution of specific operation types:

```text
Execute only the Area Path assignments from the triage handoff. Skip
priority changes and duplicate resolution for now. Log any items that
were skipped because of field conflicts.
```

**Output artifacts:** Execution writes an operation log to `.copilot-tracking/workitems/` recording each applied change, skipped items, and conflicts. Review the log for any unexpected skips or field conflict warnings.

## Tips

* ✅ Review handoff files before execution and uncheck operations you want to skip
* ✅ Run execution in a clean session (use `/clear` after triage or planning)
* ✅ Check the operation log after execution to verify all changes applied correctly
* ✅ Re-run execution if interrupted; completed checkboxes prevent duplicate operations
* ❌ Do not execute handoffs without reviewing the recommendations first
* ❌ Do not modify the checkbox format in handoff files (the workflow depends on the `- [ ]` / `- [x]` syntax)
* ❌ Do not run execution while other team members are actively editing the same work items
* ❌ Do not combine triage and planning handoffs in a single execution session

## Common Pitfalls

| Pitfall                              | Solution                                                                 |
|--------------------------------------|--------------------------------------------------------------------------|
| Autonomy level mismatches            | Set the expected autonomy level before execution (full, partial, manual) |
| Stale handoff data                   | Re-run discovery and triage if the handoff is more than a few days old   |
| Partial execution after interruption | Re-run execution on the same handoff; completed items are skipped        |
| Content sanitization gaps            | Verify internal references are stripped by checking the operation log    |
| Wrong content format                 | Confirm MCP server URL matches your ADO environment (Services vs Server) |

## Next Steps

1. Review the execution log for any skipped operations or conflicts
2. See [Using Workflows Together](using-together.md) for iterating through the full pipeline after execution

> [!TIP]
> For large handoffs with many operations, consider executing in batches by checking only a subset of items at a time. This makes review easier and reduces the blast radius of any unexpected changes.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
