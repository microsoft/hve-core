---
title: Using RPI Agents Together
description: Complete walkthrough of an evidence-led RPI lifecycle from research readiness through Follow-up
sidebar_position: 8
author: Microsoft
ms.date: 2026-07-14
ms.topic: tutorial
keywords:
  - rpi workflow
  - task researcher
  - task planner
  - task implementor
  - task reviewer
  - complete workflow
   - follow-up
estimated_reading_time: 5
---

This guide walks through an evidence-led RPI lifecycle for a complex task. `RPI Agent` is a user-selected lifecycle wrapper, and `/rpi-quick` is a skill-based full-flow entry point. They activate the same phase skills, use one task identity, and do not require an autonomous pipeline of specialized task workers.

## The Complete Workflow

```text
┌────────────────────┐     ┌─────────────────────┐     ┌────────────────────┐     ┌────────────────────┐
│ Research readiness │ ──→ │ Plan                │ ──→ │ Implement          │ ──→ │ Review             │
│                    │     │ rpi-plan            │     │ rpi-implement      │     │ rpi-review         │
│ Reuse evidence or  │     │ Parent-owned plan,  │     │ Direct execution,  │     │ One reconciliation │
│ research a gap     │     │ details, critique   │     │ changes, validation│     │ record and routing │
└────────────────────┘     └─────────────────────┘     └────────────────────┘     └────────────────────┘
     │                                                                    │
     │ demonstrated gap                                                   │ routes open work
     ▼                                                                    ▼
   rpi-research or Task Researcher                                      Follow-up
   research/{{YYYY-MM-DD}}/{{task_slug}}-research.md                    earliest stage or next item
```

## Critical Rule: Manage Context Deliberately

Use `/clear` or start a new chat when a long lifecycle has accumulated context, when switching tasks, or when a fresh context will improve the next responsible action. A reset does not require new research or a full lifecycle restart.

Why this matters:

* Accumulated context can obscure evidence, decisions, and the next owner.
* Durable task artifacts carry context through a reset or a later session.
* Stable IDs and markers locate the relevant scope when surrounding prose changes.

For the deeper explanation of how LLM context affects agent behavior, see [Context Engineering](context-engineering).

## Walkthrough: Adding Azure Blob Storage

Let's walk through adding Azure Blob Storage to a Python data pipeline.

### Research Readiness

1. Assess the available task context, acceptance criteria, decisions, dependencies, and completed research. For this Azure Blob Storage example, external SDK choices, authentication, and large-file streaming demonstrate a research gap.

2. Use `/rpi-research` or select Task Researcher for that bounded gap:

```text
/rpi-research Azure Blob Storage integration for Python data pipeline
```

1. Provide additional context in your message:

```text
I need to add Azure Blob Storage integration to our Python data pipeline.
The pipeline currently writes to local disk in src/pipeline/writers/.

Research:
- Azure SDK for Python blob storage options
- Authentication approaches (managed identity vs connection string)
- Streaming uploads for files > 1GB
- Error handling and retry patterns

Focus on approaches that match our existing patterns in the codebase.
```

1. Task Researcher will:

   * Search your codebase for existing patterns
   * Research Azure SDK documentation
   * Evaluate authentication options
   * Create a research document with recommendations

1. Review the output:

```text
## 🔬 Task Researcher: Azure Blob Storage Integration

✅ Research document created at:
.copilot-tracking/research/2025-01-28/blob-storage-research.md

Key findings:
- Recommended: azure-storage-blob SDK with async streaming
- Authentication: Managed identity for production, connection string for dev
- Existing pattern: WriterBase class in src/pipeline/writers/base.py
```

### Plan

1. Open or reference the research artifact. If the conversation has accumulated unrelated detail, begin a fresh context.
2. Use `/rpi-plan` with the available evidence:

   ```text
   /rpi-plan
   ```

3. Provide additional planning guidance:

   ```text
   /rpi-plan
   Focus on:
   - The streaming upload approach recommended in the research
   - Phased rollout: storage client first, then writer class, then integration
   - Include error handling and retry logic
   ```

4. Review the output. The planning parent creates a plan, matching phase-details artifact, and independent critique:

   ```text
   .copilot-tracking/plans/2025-01-28/blob-storage-plan.md
   .copilot-tracking/details/2025-01-28/blob-storage-phase-details.md
   .copilot-tracking/reviews/plans/2025-01-28/blob-storage-plan-critique.md
   ```

5. Verify the plan structure:

```markdown
<!-- rpi:phase id=P01 -->
### [ ] P01: Storage Client Setup

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Create BlobStorageClient class

<!-- rpi:task id=P01-T02 -->
#### [ ] P01-T02: Add configuration schema

<!-- rpi:phase id=P02 -->
### [ ] P02: Writer Implementation

<!-- rpi:task id=P02-T01 -->
#### [ ] P02-T01: Create BlobWriter extending WriterBase

<!-- rpi:phase id=P03 -->
### [ ] P03: Integration
```

Use `Pxx` and `Pxx-Txx` IDs, headings, and markers to navigate between the plan and phase-details artifact. They remain stable when surrounding text changes.

The planning parent owns the overall checklist and phase details. It may use `RPI Planner` only for a bounded one-phase authoring task, while `rpi-plan-critique` independently assesses the complete plan and details.

### Implement

1. Open or reference the plan, phase-details, and critique artifacts. Use a fresh context only when accumulated conversation detail would impede the approved work.
2. Use `/rpi-implement` or select Task Implementor to execute directly and flexibly within the approved scope:

   ```text
   /rpi-implement plan=.copilot-tracking/plans/2025-01-28/blob-storage-plan.md details=.copilot-tracking/details/2025-01-28/blob-storage-phase-details.md task=P01-T01
   ```

3. Review change evidence as each approved task completes. After `P01` completes:

```text
CHG-001: Add BlobStorageClient
Related task: P01-T01
Files: src/storage/blob_client.py
Validation: Passed

P01-T01 and P01-T02 have completion evidence.
```

Check the code and validation evidence, then continue to the next approved `Pxx` or `Pxx-Txx` item.

If implementation requires a significant departure from the approved plan, record a linked `DIV-xxx` in the changes record and `AM-xxx` amendment in the plan, then update the affected phase-details section. Return those records for a fresh `rpi-plan-critique` assessment before affected dependent work resumes. Ordinary local judgment and non-material divergence do not require this gate.

1. When the in-scope implementation is ready for review, hand off the plan, phase details, critique disposition, amendments, and changes record:

```text
Implementation complete!

Changes record: .copilot-tracking/changes/2025-01-28/blob-storage-changes.md

Files created (3):
- src/storage/blob_client.py
- src/pipeline/writers/blob_writer.py
- tests/integration/test_blob_writer.py

Files modified (2):
- src/config/schema.py
- src/pipeline/factory.py

Ready for review.
```

### Review

1. Open or reference the complete evidence set. Begin a fresh context only when it will help evidence reconciliation.
2. Use `/rpi-review` or select Task Reviewer to reconcile the implementation:

   ```text
   /rpi-review task=blob-storage
   ```

3. Task Reviewer creates or updates one review record:

   * Locates research, plan, phase details, plan critique, amendments, changes, and validation evidence
   * Reconciles each `Pxx` and `Pxx-Txx` item with completion and change evidence
   * Assesses `AM-xxx` amendments and `DIV-xxx` divergences
   * Uses an optional generic bounded lens only when it reduces a specific review uncertainty
   * Records severity-graded `RV-xxx` findings, separate execution status and outcome, validation evidence or `Unavailable`, and next-owner routing

4. Review the findings:

```text
## ✅ Task Reviewer: Blob Storage Integration

| Summary              |                                                                            |
|----------------------|----------------------------------------------------------------------------|
| Review Record        | .copilot-tracking/reviews/logs/2025-01-28/blob-storage-review.md          |
| Execution Status     | Complete                                                                   |
| Outcome              | Defects found                                                              |
| Critical Findings    | 0                                                                          |
| Medium Findings      | 1                                                                          |
| Low Findings         | 1                                                                          |
| Residual Work        | 1                                                                          |

RV-001 [Medium]: Missing docstring on BlobStorageClient.upload_stream().
Destination: rpi-implement

RV-002 [Low]: Consider adding retry count to configuration schema.
Destination: distinct follow-up

Follow-up item:
- Add performance benchmarks for large file uploads (deferred from research)

Return RV-001 to `rpi-implement`, then review it again before committing.
```

1. Address findings through their recorded next owner:

   * Address each `RV-xxx` finding through its recorded next owner
   * Return the implementation defect in `RV-001` to `rpi-implement`, then review it again with `rpi-review` before committing
   * Resolve or explicitly accept material findings before committing
   * Track residual work as a distinct follow-up item

### Follow-up

Review routes work rather than silently looping it through a generic worker chain:

* Defects return to `rpi-implement`.
* Decision gaps return to `rpi-plan`.
* Evidence gaps return to `rpi-research`.
* Residual work becomes a distinct next item.

## Artifact Summary

After completing RPI, you have:

| Artifact      | Location                                                                                 | Purpose                                               |
|---------------|------------------------------------------------------------------------------------------|-------------------------------------------------------|
| Research, when it runs | `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`                   | Evidence and recommendations                          |
| Plan          | `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`                           | Checkboxes, requirements, decisions, and amendments   |
| Phase details | `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`                | Evidence-based context for `Pxx` and `Pxx-Txx` work   |
| Plan critique | `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`          | Independent planning credibility assessment            |
| Changes       | `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`                      | `CHG-xxx`, `DIV-xxx`, validation, and handoff evidence |
| Review        | `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`                  | Reconciliation, `RV-xxx` findings, outcome, and routing |
| Code          | Your source directories                                                                  | Working implementation                                |

## Common Patterns

### Returning to Research

If implementation or review reveals a demonstrated evidence gap:

1. Record the gap and its affected task scope.
2. Return to Task Researcher or `/rpi-research` for the bounded investigation.
3. Update planning only when the evidence changes the approved scope, decision, or acceptance criteria.
4. Resume the earliest affected lifecycle concept from the durable artifacts.

### Handling Complex Tasks

For very large tasks:

1. Break work into distinct task identities where the outcomes are independently reviewable.
2. Reuse adequate research from prior work rather than repeat it.
3. Keep each plan, phase-details, changes, and review artifact set dated and task-specific.
4. Build incrementally.

### Team Handoffs

RPI artifacts support handoffs:

* Research doc explains decisions
* Plan and phase details show remaining `Pxx` and `Pxx-Txx` work
* Changes record shows completed work, validation, and linked changes or divergences
* Review record shows separate execution status, outcome, findings, and routing

## Review Routing

The Review concept routes findings to the earliest responsible lifecycle concept or a distinct Follow-up item.

### Iteration Paths

| Review result          | Action                              | Target phase or owner |
|------------------------|-------------------------------------|-----------------------|
| Conformant             | Commit changes                      | Done                  |
| Defects found          | Fix implementation issues           | Implement             |
| Research-gap finding   | Investigate missing context         | Research              |
| Decision-gap finding   | Revise supported scope or decision  | Plan                  |
| Residual work          | Create distinct follow-up work      | Follow-up owner       |

### Defect Flow

When Task Reviewer identifies Critical or High findings:

1. Open the review log in your editor.
2. Use `/rpi-implement` or Task Implementor to address implementation findings.
3. Preserve the relevant changes and validation evidence.
4. Return to review with `/rpi-review` when the evidence is ready.

### Research and Planning Flow

When Task Reviewer identifies research or planning gaps:

1. Open the review log and the referenced task artifacts.
2. Choose the appropriate direct phase skill:
   * `/rpi-research` for a demonstrated missing-evidence gap.
   * `/rpi-plan` for a decision gap or unsupported plan assumption.
3. Resume from the earliest affected lifecycle concept.

## Quick Reference

| Lifecycle concept      | Direct skill       | User-selected agent, when applicable | Output                                                                 |
|------------------------|--------------------|--------------------------------------|------------------------------------------------------------------------|
| Research, when needed  | `/rpi-research`    | Task Researcher                      | `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md` |
| Plan                   | `/rpi-plan`        | Task Planner                         | Plan, phase details, and critique                                     |
| Implement              | `/rpi-implement`   | Task Implementor                     | Code and changes evidence                                             |
| Review                 | `/rpi-review`      | Task Reviewer                        | One review record with status, outcome, and routing                   |
| Follow-up              | Routed from review | `RPI Agent` or the next owner        | Earliest responsible stage or a distinct next item                    |

> [!TIP]
> `RPI Agent` and `/rpi-quick` are alternative lifecycle entry surfaces for the same phase skills. They use research readiness and do not require fresh research or every lifecycle concept in one conversation.

For a long lifecycle, resume with the stable task ID, `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers in the durable artifacts.

## RPI Entry Surfaces

Choose the entry surface that best fits the task. Both `RPI Agent` and `/rpi-quick` activate the same phase skills.

| Entry surface       | Use it when                                             | Contract                                                     |
|---------------------|---------------------------------------------------------|--------------------------------------------------------------|
| `RPI Agent`         | You want a user-selected lifecycle wrapper              | Activates applicable phase skills from research readiness    |
| `/rpi-quick`        | You want a skill-based full-flow entry point            | Same lifecycle contract and one task identity                |
| Direct phase skills | The next responsible action is already known            | Bounded Research, Plan, Implement, or Review work            |

## Resuming a Long Lifecycle

A long lifecycle can accumulate context. Resume from the durable RPI artifact set rather than relying on a conversation transcript:

1. Open or reference the dated artifact that establishes the next action.
2. Use the stable task ID, `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers to find the affected scope.
3. Start a fresh chat or use `/compact` only when it will improve the next responsible action.
4. Keep a memory or checkpoint record as a supplement, not a replacement, for plan, details, changes, or review evidence.

> [!TIP]
> For the full explanation of how context affects the lifecycle, see [Context Engineering](context-engineering).

See [Agents Reference](https://github.com/microsoft/hve-core/blob/main/.github/CUSTOM-AGENTS.md) for RPI Agent details.

## Related Guides

* [RPI Overview](./) - Understand the workflow
* [Context Engineering](context-engineering) - Why context management matters
* [Task Researcher](task-researcher) - Deep research phase
* [Task Planner](task-planner) - Create actionable plans
* [Task Implementor](task-implementor) - Execute with precision
* [Task Reviewer](task-reviewer) - Validate implementations

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
