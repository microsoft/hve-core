---
title: Task Implementor Guide
description: Use the Task Implementor chat mode to execute implementation plans with precision and tracking
author: Microsoft
ms.date: 2025-01-28
ms.topic: tutorial
keywords:
  - task implementor
  - rpi workflow
  - implementation phase
  - github copilot
estimated_reading_time: 4
---

The Task Implementor chat mode transforms planning files into working code. It executes plans task by task, tracks all changes, and supports stop controls for review between phases.

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

## Output Artifacts

Task Implementor creates working code and a changes log:

```text
.copilot-tracking/
└── changes/
    └── YYYYMMDD-<topic>-changes.md    # Log of all changes made
```

Plus all the actual code files created or modified during implementation.

## How to Use Task Implementor

### Step 1: Clear Context

🔴 **Start with `/clear` or a new chat** after Task Planner completes.

### Step 2: Select the Chat Mode

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the chat mode dropdown
3. Select **Task Implementor**

### Step 3: Reference Your Plan

Provide the path to your plan file or use the generated implementation prompt.

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
2. **Links** to planning files for cleanup
3. **Recommendation** to review and commit

## Common Pitfalls

| Pitfall                 | Solution                                 |
|-------------------------|------------------------------------------|
| Plan not found          | Complete Task Planner first              |
| Skipping reviews        | Use phaseStop=true for important changes |
| Not running validations | Check lint/test after each phase         |

## Next Steps

After Task Implementor completes:

1. **Review** the changes log and all modified files
2. **Run** any validation commands (lint, test, build)
3. **Commit** your changes with a descriptive message
4. 🔴 **Delete prompt file** - Prompt cleanup is MANDATORY after implementation
5. **Clean up** other planning files if no longer needed

For your next task, you can start the RPI workflow again with Task Researcher.

> ⚠️ **Important**: Task Implementor requires deleting the implementation prompt file (`.copilot-tracking/prompts/implement-*.prompt.md`) after completion. This is enforced by the chatmode to prevent stale prompts from accumulating.

---

🤖 *Crafted with precision by ✨Copilot using the RPI workflow*
