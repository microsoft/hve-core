---
title: Using RPI Together
description: Complete walkthrough of an evidence-led RPI lifecycle from research readiness through Follow-up
sidebar_position: 4
author: Microsoft
ms.date: 2026-11-12
ms.topic: tutorial
keywords:
  - rpi workflow
  - rpi agent
  - rpi research
  - rpi plan
  - rpi implement
  - rpi review
  - rpi refine
  - complete workflow
  - follow-up
  - automatic mode
estimated_reading_time: 8
---

This guide walks through an evidence-led RPI lifecycle for a complex task. `RPI Agent` is a user-selected lifecycle wrapper. It activates the phase skills, uses one task identity, and does not require an autonomous pipeline of specialized task workers.

## The Complete Workflow

```text
┌────────────────────┐     ┌─────────────────────┐     ┌────────────────────┐     ┌──────────────────────┐
│ Research readiness │ ──→ │ Plan                │ ──→ │ Implement          │ ──→ │ Review               │
│                    │     │ rpi-plan            │     │ rpi-implement      │     │ rpi-review +         │
│ Reuse evidence or  │     │ Goals, task context,│     │ Direct execution,  │     │ rpi-refine           │
│ research a gap     │     │ critique            │     │ changes, validation│     │ Acceptance + refine  │
└────────────────────┘     └─────────────────────┘     └────────────────────┘     └──────────────────────┘
     │                                                                    │
     │ demonstrated gap                                                   │ routes open work
     ▼                                                                    ▼
   rpi-research                                                         Follow-up
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

> [!NOTE]
> The examples use the short command names. With the plugin installed in VS Code, the same skills carry the plugin name as a prefix, such as `/hve-core:rpi-research`.

### Research Readiness

1. Assess the available task context, acceptance criteria, decisions, dependencies, and completed research. For this Azure Blob Storage example, external SDK choices, authentication, and large-file streaming demonstrate a research gap.

2. Use `/rpi-research` for that bounded gap:

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

1. `/rpi-research` will:

   * Search your codebase for existing patterns
   * Research Azure SDK documentation
   * Evaluate authentication options
   * Create a research document with recommendations

2. Review the output:

```text
## 🔬 Research: Azure Blob Storage Integration

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

4. Review the output. `/rpi-plan` creates one task-centered plan and an independent critique:

   ```text
   .copilot-tracking/plans/2025-01-28/blob-storage-plan.md
   .copilot-tracking/reviews/plans/2025-01-28/blob-storage-plan-critique.md
   ```

5. Verify the plan structure. The plan opens with an executive summary and a `## Phase Checklist` that starts with the change map: an After diagram of the result, grouped by where changes land, with each change tagged by its phases, and a Before only when the plan changes how parts connect. Supporting sections such as decisions, readiness, requirements, and sources follow it:

````markdown
## Phase Checklist

### After

```mermaid
flowchart LR
    accTitle: After: pipeline output streams to Azure Blob Storage
    accDescr: The factory builds a blob writer that uploads through a new storage client, beside the file writer it already builds.
    subgraph pipeline["`<code>src/pipeline/</code>`"]
        factory["`**<code>factory.py</code>**
        builds the configured writer
        changed · P03`"]
        files["`<code>writers/file_writer.py</code>`"]
        writer["`**<code>writers/blob_writer.py</code>**
        streams output to blobs
        new · P02`"]
    end
    subgraph storage["`<code>src/storage/blob_client.py</code>
    new file · P01`"]
        client["`**<code>BlobStorageClient</code>**
        uploads to a container
        new · P01`"]
    end
    factory -->|constructs| files
    factory -->|constructs| writer
    writer -->|uploads through| client
    classDef new stroke-dasharray: 6 4,stroke-width:2px
    classDef changed stroke-width:3px
    class storage,client,writer new
    class factory changed
```

Key: arrows point from a part to what it uses; dashed border, new; thick border, changed; each tag names the phases that make the change.

The factory now builds the writer the configuration names (P03): the existing file writer or a new blob writer (P02), which uploads through the new `BlobStorageClient` (P01). The plan removes nothing, so the map has no Before.

<!-- rpi:phase id=P01 -->
### [ ] P01: Storage Client Setup

Goals:
* Establish a storage boundary that can upload pipeline output through the supported Azure Blob interface.

Dependencies:
* None

Changes in the map: the new `src/storage/blob_client.py` file and its `BlobStorageClient`.

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Create BlobStorageClient class

Goals:
* Pipeline code can stream content to Azure Blob Storage without depending directly on SDK client construction.

Requirements:
* FR-001, NFR-002
* Upload failures surface as the pipeline's existing error types, not raw SDK exceptions.
* A caller can upload a stream through the storage boundary and receive a clear success or failure result.

Details:
* Research found no existing storage abstraction; `WriterBase` is the only contract writers share today.
* Follow the async client pattern already used by the queue integration rather than introducing a second style.
* Add unit tests for successful upload and SDK error translation alongside the existing writer tests.

References:
* [src/pipeline/writers/base.py](../../../src/pipeline/writers/base.py): existing writer contract
* [.copilot-tracking/research/2025-01-28/blob-storage-research.md](../../research/2025-01-28/blob-storage-research.md):
  * Q1 under `## Findings` recommends `azure.storage.blob.aio.BlobClient.upload_blob` for streaming uploads.

Dependencies:
* None

<!-- rpi:phase id=P02 -->
### [ ] P02: Writer Implementation

<!-- rpi:task id=P02-T01 -->
#### [ ] P02-T01: Create BlobWriter extending WriterBase

<!-- rpi:phase id=P03 -->
### [ ] P03: Integration
````

Use `Pxx` and `Pxx-Txx` IDs, headings, and markers to navigate the plan. They remain stable when surrounding text changes. Code, commands, and symbols use backticks, and existing files are Markdown links relative to the plan so you can open them from the editor.

`/rpi-plan` owns the complete plan and drafts every phase itself. Skills and subagents whose descriptions say they are used during planning extend it as their descriptions direct; no subagent is required.
Every RPI phase uses subagents only when a dispatch tool is available and your direction allows them, and runs independent subagent work in parallel; pass `subagents=none` to any phase to work without them. `rpi-plan-critique` independently assesses the complete plan by default; skip it with `critique=skip` or by asking.

### Implement

1. Open or reference the plan and critique artifacts. Use a fresh context only when accumulated conversation detail would impede the approved work.
2. Use `/rpi-implement` to execute directly and flexibly within the approved scope:

   ```text
   /rpi-implement plan=.copilot-tracking/plans/2025-01-28/blob-storage-plan.md task=P01-T01
   ```

3. Review change evidence as each approved task completes. The changes record uses descriptive headings tied to plan markers rather than per-entry IDs. After `P01` completes:

```text
### Add BlobStorageClient behind the writer contract

* Related phase or task: P01-T01
* Files: src/storage/blob_client.py
* Validation: Passed

P01-T01 and P01-T02 have completion evidence; P01 is checked.
```

Check the code and validation evidence, then continue to the next approved `Pxx` or `Pxx-Txx` item.

If implementation requires a significant departure from the approved plan, record the discovery in the changes record, obtain any required decision, and update the affected plan tasks before dependent work resumes. Preserve the existing critique as historical evidence; a follow-up critique runs only when you ask for one. Ordinary local judgment and non-material updates remain in Implement.

When a completed task creates something a later task needs, such as a new class or contract path the plan did not name, implementation adds a `Guidance:` block to that later task so the next agent does not have to rediscover it.

1. When the in-scope implementation is ready for review, hand off the plan, critique disposition, and changes record:

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
2. Use `/rpi-review` and `/rpi-refine` to evaluate acceptance conformance and subtractive simplification:

   ```text
   /rpi-review task=blob-storage
   /rpi-refine task=blob-storage
   ```

3. `/rpi-review` creates the acceptance record (`-review.md`), while `/rpi-refine` creates the subtractive refinement record (`-refinement.md`):

   * `/rpi-review` compares each `Pxx` and `Pxx-Txx` item against completion, business alignment, and validation evidence, recording severity-graded `RV-xxx` findings and `RD-xxx` parent decisions
   * `/rpi-refine` inspects touched code, tests, docs, domain language, SDKs, assumptions, error boundaries, performance, language versions, and configuration through fresh-context `RPI Refiner` lenses to identify what can be removed, consolidated, or redesigned (`RF-xxx` findings and `FD-xxx` parent decisions)
   * Both records appear together in the RPI Workflow canvas Review view and route accepted work into `rpi-plan` (as new `Pxx` follow-up phases or a separate RPI session), `rpi-implement`, `rpi-research`, or follow-up

4. Review the findings:

```text
## ✅ Review: Blob Storage Integration

| Summary           |                                                                  |
|-------------------|------------------------------------------------------------------|
| Review Record     | .copilot-tracking/reviews/logs/2025-01-28/blob-storage-review.md |
| Execution Status  | Complete                                                         |
| Outcome           | Defects found                                                    |
| Critical Findings | 0                                                                |
| Medium Findings   | 1                                                                |
| Low Findings      | 1                                                                |
| Residual Work     | 1                                                                |

RV-001 [Medium]: Missing docstring on BlobStorageClient.upload_stream().
Destination: rpi-implement

RV-002 [Low]: Consider adding retry count to configuration schema.
Destination: distinct follow-up

Follow-up item:
- Add performance benchmarks for large file uploads (deferred from research)

Return RV-001 to a later `rpi-implement` invocation.
```

1. Address findings through their recorded next owner:

   * Address each `RV-xxx` finding through its recorded next owner
   * Return the implementation defect in `RV-001` to a later `rpi-implement` invocation
   * Resolve or explicitly accept material findings before committing
   * Track residual work as a distinct follow-up item

### Follow-up

Review routes work rather than silently looping it through a generic chain:

* Defects return to `rpi-implement`.
* Decision gaps return to `rpi-plan`.
* Evidence gaps return to `rpi-research`.
* Residual work becomes a distinct next item.

## Artifact Summary

After completing RPI, you have:

| Artifact               | Location                                                                        | Purpose                                                             |
|------------------------|---------------------------------------------------------------------------------|---------------------------------------------------------------------|
| Research, when it runs | `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`           | Evidence and recommendations                                        |
| Plan                   | `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`                  | Goals, task context, requirements, decisions, and status            |
| Plan critique          | `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md` | Independent planning credibility assessment                         |
| Changes                | `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`             | Implementation, validation, and handoff evidence                    |
| Acceptance review      | `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`         | Requirement reconciliation, `RV-xxx` findings, outcome, and routing |
| Refinement review      | `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-refinement.md`     | Subtractive simplification, `RF-xxx` findings, outcome, and routing |
| Code                   | Your source directories                                                         | Working implementation                                              |

## Common Patterns

### Returning to Research

If implementation or review reveals a demonstrated evidence gap:

1. Record the gap and its affected task scope.
2. Return to `/rpi-research` for the bounded investigation.
3. Update planning only when the evidence changes the approved scope, decision, or acceptance criteria.
4. Resume the earliest affected lifecycle concept from the durable artifacts.

### Handling Complex Tasks

For very large tasks:

1. Break work into distinct task identities where the outcomes are independently reviewable.
2. Reuse adequate research from prior work rather than repeat it.
3. Keep each plan, critique, changes, and review artifact set dated and task-specific.
4. Build incrementally.

### Team Handoffs

RPI artifacts support handoffs:

* Research doc explains decisions
* The task-centered plan shows remaining `Pxx` and `Pxx-Txx` work and the context needed to implement it
* Changes record shows completed work, validation, and implementation-time plan updates with their rationale
* Review record shows separate execution status, outcome, findings, and routing

## Review Routing

The Review concept routes findings to the earliest responsible lifecycle concept or a distinct Follow-up item.

### Iteration Paths

| Review result        | Action                             | Target phase or owner |
|----------------------|------------------------------------|-----------------------|
| Conformant           | Commit changes                     | Done                  |
| Defects found        | Fix implementation issues          | Implement             |
| Research-gap finding | Investigate missing context        | Research              |
| Decision-gap finding | Revise supported scope or decision | Plan                  |
| Residual work        | Create distinct follow-up work     | Follow-up owner       |

### Defect Flow

When `/rpi-review` or `/rpi-refine` identifies implementation findings:

1. Open the review or refinement log in your editor.
2. Feed accepted findings into `/rpi-plan` (as a new `Pxx` follow-up phase) or `/rpi-implement` for localized fixes.
3. Preserve the implementation and validation evidence; localized fixes do not start another review unless you request one or introduce significant cross-cutting changes (`surface` depth).

### Research and Planning Flow

When `/rpi-review` or `/rpi-refine` identifies research or planning gaps:

1. Open the review log and the referenced task artifacts.
2. Choose the appropriate direct phase skill:
   * `/rpi-research` for a demonstrated missing-evidence gap.
   * `/rpi-plan` for a decision gap or unsupported plan assumption.
3. Resume from the earliest affected lifecycle concept.

## Quick Reference

| Lifecycle concept     | Direct skill                    | Output                                                                |
|-----------------------|---------------------------------|-----------------------------------------------------------------------|
| Research, when needed | `/rpi-research`                 | `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md` |
| Plan                  | `/rpi-plan`                     | Task-centered plan and critique                                       |
| Implement             | `/rpi-implement`                | Source changes and changes evidence                                   |
| Review                | `/rpi-review` and `/rpi-refine` | Acceptance (`RV-xxx`) and refinement (`RF-xxx`) records and routing   |
| Follow-up             | Routed from review              | New `Pxx` plan phases, a separate RPI session, or a distinct item     |

> [!TIP]
> `RPI Agent` is a lifecycle entry surface for the phase skills. It uses research readiness and does not require fresh research or every lifecycle concept in one conversation.

For a long lifecycle, resume with the stable task ID, `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers in the durable artifacts.

## RPI Entry Surfaces

Choose the entry surface that best fits the task.

| Entry surface       | Use it when                                              | Contract                                                                                             |
|---------------------|----------------------------------------------------------|------------------------------------------------------------------------------------------------------|
| `/rpi`              | You want multi-phase RPI session coordination            | User-invocable and model-discoverable skill that manages session state, phase skills, and the canvas |
| `RPI Agent`         | You want a user-selected lifecycle wrapper in the picker | Preloads the `rpi` skill to coordinate applicable phase skills from research readiness               |
| Direct phase skills | The next responsible action is already known             | Bounded Research, Plan, Implement, or Review work                                                    |

### Manual and Automatic Mode in RPI Agent

When neither your request nor a resumed session sets how to proceed, `RPI Agent` asks "How would you like us to work on this?" and offers four choices:

| Choice                          | How the agent proceeds                                                                                                 |
|---------------------------------|------------------------------------------------------------------------------------------------------------------------|
| Handle it end to end            | Makes the decisions and works through every phase and needed follow-up until your request is complete                  |
| Keep going, but check with me   | Works through every phase and needed follow-up automatically, and asks you when a decision or the direction is unclear |
| Research and plan with me       | Researches and plans with your input, walks you through both, and stops before Implementation                          |
| Work through each phase with me | Manual mode: asks about unclear decisions, walks you through each phase's artifacts, and waits for you to move on      |

You can also type your own answer, for example to keep only the Plan decisions or to choose follow-up work yourself. A clear request such as "use automatic mode" or "full auto" selects automatic mode without the question.

In manual mode, the agent stays in the active phase until you ask for the next phase or run its command, such as `/rpi-plan`. When a phase finishes, the agent walks you through its artifacts and asks whether to refine the work or move on, and an answer that names the next phase is enough to advance.

In automatic mode, the agent moves through the phases without routine approval prompts, up to the boundary you chose. It still stops for blockers and required human review, and it asks before destructive, hard-to-reverse, shared-system, or externally visible actions.

On the session's initial pass, Planning runs `rpi-plan-critique` and Review runs both `/rpi-review` and `/rpi-refine` (unless you or a coordinating Project select one review skill or skip a step). When a Project coordinates the session and the changes are significant enough to benefit from dedicated review sessions, the session sends a `handoff` report so the coordinator can run or delegate the reviews across its sessions.

After Review, an automatic session reconciles `RV-xxx` and `RF-xxx` findings. Accepted work that continues in the same session feeds into `rpi-plan` as new `Pxx` planning phases on the active plan and runs `rpi-implement`; broader redesigns can start a separate RPI session with standard RPI rules. When you retain follow-up selection, the session shows the ranked choices alongside **Stop automatic session** and **Switch to manual mode**.

To prevent back-and-forth looping between Review and Implement in the same session, follow-up loops after the session's first Review skip another review when fixes stay localized to accepted finding targets, run a bounded `surface`-depth check when the loop introduced significant architectural, contract, domain, or cross-cutting changes, and run another full review only when you ask for one.

Both modes persist one JSON state record with the task identity, mode, active phase, artifact pointers, decisions, blockers, and ranked follow-ups, so a later conversation can resume from the recorded phase.

When your host shows canvases, the agent also opens the [RPI Workflow canvas](rpi-workflow-canvas) on the session. In either mode, you can read each phase there as it is written, answer the decisions the agent leaves to you, and queue input for its next checkpoint.

## Resuming a Long Lifecycle

A long lifecycle can accumulate context. Resume from the durable RPI artifact set rather than relying on a conversation transcript:

1. Open or reference the dated artifact that establishes the next action.
2. Use the stable task ID, `Pxx`, `Pxx-Txx`, headings, and `<!-- rpi:... -->` markers to find the affected scope.
3. Start a fresh chat or use `/compact` only when it will improve the next responsible action.
4. Treat the durable artifact set, rather than the conversation transcript, as the source of truth.

> [!TIP]
> For the full explanation of how context affects the lifecycle, see [Context Engineering](context-engineering).

See the [rpi skill reference](../reference/skills/rpi/rpi.md) and [RPI Agent reference](../reference/agents/hve-core/rpi-agent) for the session state contract and modes.

## Related Guides

* [RPI Overview](./) - Understand the workflow
* [Why the RPI Workflow Works](why-rpi) - Understand the rationale for phase separation
* [Context Engineering](context-engineering) - Why context management matters
* [RPI Workflow Canvas](rpi-workflow-canvas) - Follow and steer a session phase by phase beside the chat

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
