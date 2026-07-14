---
title: Task Implementor Guide
description: Use the Task Implementor custom agent to execute implementation plans with precision and tracking
sidebar_position: 6
author: Microsoft
ms.date: 2026-07-13
ms.topic: tutorial
keywords:
  - task implementor
  - rpi workflow
  - implementation phase
  - github copilot
estimated_reading_time: 4
---

The Task Implementor custom agent transforms an approved plan and matching phase-details artifact into working code. It executes approved tasks directly, records trustworthy change evidence, and prepares the artifact set for review.

## When to Use Task Implementor

Use Task Implementor after completing planning when you need:

* ⚡ **Precise execution** following approved `Pxx` and `Pxx-Txx` work
* 📝 **Change tracking** documenting all modifications
* ↔️ **Divergence handling** for evidence-backed plan amendments
* ✅ **Verification** that success criteria are met

## What Task Implementor Does

1. **Resolves** the dated plan, matching phase details, critique disposition, and prior changes by stable IDs and markers
2. **Implements** approved work directly for the requested `Pxx` phase or `Pxx-Txx` task
3. **Tracks** material work with `CHG-xxx` entries in the changes record
4. **Verifies** success criteria before marking completed phases and tasks
5. **Records** a significant divergence as linked `DIV-xxx` and `AM-xxx` evidence, with a matching phase-details update
6. **Runs** expected validation and hands the complete evidence set to review when no affected dependent work awaits critique

> [!NOTE]
> **Why the constraint matters:** Task Implementor follows approved evidence while keeping actual work, validation, and material divergence visible. A significant divergence receives an amendment and fresh critique before affected dependent work resumes, so review can distinguish justified change from unsupported scope drift.

## Output Artifacts

Task Implementor creates working code and a changes record:

```text
.copilot-tracking/
└── changes/
  └── {{YYYY-MM-DD}}/
    └── {{task_slug}}-changes.md    # Changes, divergences, validation, and handoff evidence
```

Plus all the actual code files created or modified during implementation.

## How to Use Task Implementor

### Step 1: Clear Context and Open the Plan

🔴 **Start with `/clear` or a new chat** after Task Planner completes.

After clearing, open the plan and matching phase-details artifact before invoking Task Implementor:

```text
.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md
.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md
```

Use the matching `Pxx` and `Pxx-Txx` headings and markers to locate the requested work. Include the plan critique when a prior amendment or residual risk matters.

> [!TIP]
> Context management is an engineering practice, not a ritual. Clearing context removes accumulated tokens that cause the model to ignore its instructions. See [Context Engineering](context-engineering.md) for the full explanation.

### Step 2: Select the Custom Agent

1. Open GitHub Copilot Chat (`Ctrl+Alt+I`)
2. Click the agent picker dropdown
3. Select **Task Implementor**

### Step 3: Reference Your Plan

Use `/task-implement` or `/rpi-implement` to start execution. Provide the plan, phase-details artifact, and an optional exact `Pxx` phase or `Pxx-Txx` task when you want to bound the work.

### Step 4: Set the Execution Scope

Use a stable phase or task identifier with matching headings and markers to focus execution:

* `P01` executes the approved work in Phase 1
* `P01-T02` executes only Task 2 in Phase 1
* Omit the scope only when the complete approved plan is ready to execute

### Step 5: Record Evidence and Continue

As work completes:

1. Record each material change as `CHG-xxx` in the changes record
2. Mark a `Pxx-Txx` task or `Pxx` phase complete only after completion evidence exists
3. Run the validation expected by the plan or changed behavior, and record results or an explicit skip reason
4. Hand off to review when the approved scope is complete and no affected dependent work awaits a critique disposition

## Example Prompt

```text
/task-implement
```

Or provide a bounded artifact set:

```text
/task-implement plan=.copilot-tracking/plans/2025-01-28/blob-storage-plan.md details=.copilot-tracking/details/2025-01-28/blob-storage-phase-details.md task=P01-T01
```

## Changes, Divergences, and Amendments

Record a material implementation change with a `CHG-xxx` identifier tied to the affected `Pxx-Txx` task. The changes record also captures files, completion evidence, validation, blockers, and remaining work.

A significant divergence is different from ordinary local judgment. When a material departure from the approved plan is necessary:

1. Add a `DIV-xxx` entry in `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`.
2. Link it to an `AM-xxx` amendment in `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`.
3. Update the affected section in `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`.
4. Return the amended evidence to planning for a fresh `rpi-plan-critique` assessment.
5. Do not resume affected dependent work until the new critique disposition is `Pass`. Preserve unrelated completed work and evidence.

Fresh critique is required only for significant divergence. Ordinary local implementation judgment and non-material divergence remain implementation decisions.

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

## The Changes Record

Task Implementor maintains a changes record with stable identifiers:

```markdown
## Changes

<!-- rpi:change id=CHG-001 -->
### CHG-001: Add Blob Storage client

* Related task: P01-T01
* Files: src/storage/blob_client.py
* Completion evidence: BlobStorageClient is available to the writer
* Validation: Passed

## Divergences

<!-- rpi:divergence id=DIV-001 -->
### DIV-001: Add retry configuration

* Related task: P01-T02
* Linked amendment: AM-001
* Critique disposition: Pass after fresh critique
```

## At Completion

When all phases are complete, Task Implementor provides:

1. **Summary** of completed and remaining `Pxx` and `Pxx-Txx` work from the changes record
2. **Validation** evidence, explicit skips, and linked `CHG-xxx`, `DIV-xxx`, and `AM-xxx` records
3. **Recommendation** to proceed to `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md` when no significant amendment awaits critique

## Common Pitfalls

| Pitfall                 | Solution                                                                        |
|-------------------------|---------------------------------------------------------------------------------|
| Plan or details not found        | Provide the dated plan and matching phase-details paths                                      |
| Ambiguous scope                  | Specify the exact `Pxx` phase or `Pxx-Txx` task                                             |
| Significant divergence           | Record linked `DIV-xxx` and `AM-xxx`, update details, and wait for fresh critique           |
| Not running validations          | Record the executed validation or an explicit skip reason                                    |
| Context issues                   | Use `/clear` before starting; see [Context Engineering](context-engineering.md)             |

## Next Steps

After Task Implementor completes:

1. If a significant amendment awaits critique, return the plan, phase-details artifact, and evidence to Task Planner before continuing affected dependent work.
2. Otherwise, **clear context** using `/clear` or starting a new chat.
3. **Review** using `/task-review` to switch to [Task Reviewer](task-reviewer.md), providing the plan, phase details, critique, and changes record.
4. **Address** review findings through the routed owner before committing.
5. **Commit** your changes with a descriptive message when the review outcome supports it.

> [!TIP]
> Use the **✅ Review** handoff button when available to transition directly to Task Reviewer with context.

For your next task, you can start the RPI workflow again with Task Researcher.

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
