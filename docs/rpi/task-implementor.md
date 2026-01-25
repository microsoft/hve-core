---
title: Task Implementor Guide
description: Use the Task Implementor custom agent to execute implementation plans with precision and tracking
author: Microsoft
ms.date: 2026-01-24
ms.topic: tutorial
keywords:
  - task implementor
  - rpi workflow
  - implementation phase
  - github copilot
estimated_reading_time: 4
---

The Task Implementor custom agent transforms planning files into working code. It executes plans task by task, tracks all changes, and supports stop controls for review between phases.

## When to Use Task Implementor

Use Task Implementor after completing planning when you need:

* ⚡ **Precise execution** following the plan exactly
* 📝 **Change tracking** documenting all modifications
* ⏸️ **Stop controls** for review between phases
* ✅ **Verification** that success criteria are met

## What Task Implementor Does

1. **Reads** the plan phase by phase, task by task
2. **Loads** only needed details using line ranges
3. **Implements** code following workspace conventions
4. **Tracks** changes in a changes log
5. **Verifies** success criteria before marking complete
6. **Pauses** at stop points for your review

> [!NOTE]
> **Why the constraint matters:** Task Implementor has one job: execute the plan using patterns documented in research. No time wasted rediscovering conventions, no "creative" decisions that break existing patterns—just verified facts applied methodically.

## Output Artifacts

Task Implementor creates working code and a changes log:

```text
.copilot-tracking/
└── changes/
    └── {{YYYY-MM-DD}}-<topic>-changes.md    # Log of all changes made
```

Plus all the actual code files created or modified during implementation.

## How to Use Task Implementor

### Step 1: Clear Context

🔴 **Start with `/clear` or a new chat** after Task Planner completes.

### Step 2: Select the Custom Agent

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Select **Task Implementor**

### Step 3: Reference Your Plan

Use `/task-implement` to start execution. The prompt automatically locates the plan and switches to Task Implementor. Alternatively, provide the path to your plan file directly.

### Step 4: Set Stop Controls

Choose your review cadence:

* `phaseStop=true` (default): Pause after each phase
* `taskStop=true`: Pause after each task
* Both false: Run to completion

### Step 5: Review and Continue

At each stop point:

1. Review the changes made
2. Verify code compiles and lints
3. Approve or request adjustments
4. Continue to next phase/task

## Example Prompt

```text
/task-implement
```

Or reference a specific generated prompt:

```text
/implement-blob-storage
```

## Understanding Stop Controls

### Phase Stop (Default: true)

Pauses after completing all tasks in a phase:

```text
Phase 1: [x] Task 1.1, [x] Task 1.2 → STOP for review
Phase 2: [ ] Task 2.1, [ ] Task 2.2
```

### Task Stop (Default: false)

Pauses after each individual task:

```text
Phase 1: [x] Task 1.1 → STOP
         [ ] Task 1.2
```

## Tips for Better Implementation

✅ **Do:**

* Review changes at each stop point
* Run linters and validators
* Check that success criteria are met
* Ask for adjustments before continuing

❌ **Don't:**

* Skip reviewing changes
* Ignore failing tests or lints
* Rush through all phases without checking

## The Changes Log

Task Implementor maintains a changes log with sections:

```markdown
## Changes

### Added
* src/storage/blob_client.py - Azure Blob Storage client class

### Modified
* src/pipeline/config.py - Added blob storage configuration

### Removed
* (none this implementation)
```

## At Completion

When all phases are complete, Task Implementor provides:

1. **Summary** of all changes from the changes log
2. **Links** to planning files for reference
3. **Recommendation** to proceed to review

## Common Pitfalls

| Pitfall                 | Solution                                 |
|-------------------------|------------------------------------------|
| Plan not found          | Complete Task Planner first              |
| Skipping reviews        | Use phaseStop=true for important changes |
| Not running validations | Check lint/test after each phase         |

## Next Steps

After Task Implementor completes:

1. **Clear context** using `/clear` or starting a new chat
2. **Review** using `/task-review` to switch to [Task Reviewer](task-reviewer.md)
3. **Address findings** from the review before committing
4. **Commit** your changes with a descriptive message
5. **Clean up** planning files if no longer needed

> [!TIP]
> Use the **✅ Review** handoff button when available to transition directly to Task Reviewer with context.

For your next task, you can start the RPI workflow again with Task Researcher.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
