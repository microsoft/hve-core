---
title: Execution Workflow
description: Apply triage and planning recommendations to GitHub issues through structured handoff consumption
author: Microsoft
ms.date: 2026-02-12
ms.topic: tutorial
keywords:
  - github backlog manager
  - issue execution
  - handoff
  - github copilot
estimated_reading_time: 5
---

The Execution workflow consumes handoff files from triage and sprint planning, applying approved changes to GitHub issues. It tracks progress through checkbox-based handoff logs and produces operation reports for audit and recovery.

## When to Use

* ✅ Triage or sprint planning handoff files are ready for application
* 🏷️ Applying label changes, milestone assignments, or issue closures in bulk
* 🔗 Linking duplicate issues and closing the redundant copies
* 📝 Updating issue metadata across multiple issues in a single session

## What It Does

1. Reads handoff files from triage or sprint planning workflows
2. Validates each recommended operation against current issue state
3. Applies approved changes (labels, milestones, closures, comments) via GitHub MCP tools
4. Marks each handoff checkbox as complete after successful application
5. Produces an operation log documenting what changed and what was skipped

> [!NOTE]
> Execution only processes checked items in the handoff file. Uncheck any recommendation you want to skip before starting the execution workflow.

## Handoff Consumption

The execution workflow uses checkbox-based progress tracking in handoff files:

```markdown
## Pending Operations

- [x] #42 - Add label: bug (applied)
- [x] #42 - Assign milestone: v2.1 (applied)
- [ ] #57 - Close as duplicate of #42 (skipped - unchecked)
- [x] #63 - Add label: documentation (applied)
```

Each line represents one atomic operation. The workflow processes checked items sequentially, validating current issue state before each change. If an issue has been modified since triage (new labels added, milestone changed, issue closed), the workflow flags the conflict and skips that operation rather than overwriting recent changes.

## Operation Logging

Every execution session produces a structured log:

* Operations attempted with timestamps
* Success and failure counts with error details
* Issues skipped due to state conflicts
* API rate limit status at session end

This log supports recovery when execution is interrupted. Re-running execution on the same handoff file picks up where it left off because completed items are already checked.

## Output Artifacts

```text
.copilot-tracking/github-issues/<planning-type>/<scope-name>/
└── handoff-logs.md    # Per-operation processing status (created next to consumed handoff)
```

The consumed handoff file is updated in place as operations complete, marking checkboxes for processed items. The handoff log records per-operation results with processing status, supporting recovery when execution is interrupted.

## How to Use

### Option 1: Prompt Shortcut

```text
Execute the triage handoff for microsoft/hve-core
```

```text
Apply sprint planning assignments from my latest planning session
```

### Option 2: Direct Agent

Attach or reference the handoff file when starting an execution conversation. The agent reads the pending operations and begins processing checked items.

## Example Prompt

```text
Execute the triage handoff at .copilot-tracking/github-issues/triage/2026-02-10/triage-plan.md.
Skip any operations on issues that have been updated in the last 24 hours.
```

## Tips

✅ Do:

* Review handoff files before execution and uncheck operations you want to skip
* Run execution in a clean session (use `/clear` after triage or planning)
* Check the operation log after execution to verify all changes applied correctly
* Re-run execution if interrupted; completed checkboxes prevent duplicate operations

❌ Don't:

* Execute handoffs without reviewing the recommendations first
* Modify the checkbox format in handoff files (the workflow depends on the `- [ ]` / `- [x]` syntax)
* Run execution while other team members are actively editing the same issues
* Combine triage and planning handoffs in a single execution session

## Common Pitfalls

| Pitfall                              | Solution                                                                 |
|--------------------------------------|--------------------------------------------------------------------------|
| Autonomy level mismatches            | Set the expected autonomy level before execution (full, partial, manual) |
| Stale handoff data                   | Re-run discovery and triage if the handoff is more than a few days old   |
| Partial execution after interruption | Re-run execution on the same handoff; completed items are skipped        |
| Rate limiting during bulk operations | The workflow pauses automatically and resumes; check the operation log   |

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
