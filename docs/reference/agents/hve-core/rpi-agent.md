---
title: RPI Agent
description: "Coordinate one task through Research, Plan, Implement, Review, and Follow-up with resumable evidence and explicit phase authority."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-25
ms.topic: reference
keywords:
  - agent
  - hve-core
  - rpi-agent
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                              |
|-------------|----------------------------------------------------|
| Kind        | agent                                              |
| Source      | `.github/agents/hve-core/rpi-agent.agent.md`       |
| Invocation  | Selected from the chat agent picker as `RPI Agent` |
| Interactive | Yes                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coordinate one task through Research, Plan, Implement, Review, and Follow-up with resumable evidence and explicit phase authority.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Select `RPI Agent` when one task should move through Research, Plan, Implement, Review, and Follow-up with a durable state record and one stable task identity. The agent activates the matching skills ([rpi-research](../../skills/rpi/rpi-research), [rpi-plan](../../skills/rpi/rpi-plan), [rpi-implement](../../skills/rpi/rpi-implement), [rpi-review](../../skills/rpi/rpi-review)) rather than duplicating their protocols.

It persists mode, active phase, artifact pointers, decisions, blockers, and ranked follow-ups in one JSON state record so a later conversation can resume from the recorded phase.

Child tasks inherit your participation preferences and unresolved work, but own fresh phase artifacts and critique/Review execution records. If a state write fails, progression pauses; recovery reconciles the recorded transition before starting work, without creating a duplicate child.

It offers two modes:

| Mode        | Behavior                                                                                                                                                                                                                                                                                                                       |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `manual`    | Walks you through the active phase's artifacts and waits for an explicit next-phase request, a `/rpi-*` command, or a phase handoff. You own every material decision.                                                                                                                                                          |
| `automatic` | An explicit automatic request or **Full Auto** selection starts automatic progression without another mode question. The agent makes ordinary decisions and runs required in-scope follow-ups through new RPI loops until the requested outcome is complete. Explicitly retained decisions and progression limits still apply. |

Both modes preserve actual evidence blockers, applicable human attestations, and required confirmation for risky actions. An ordinary plan self-check or critique interruption does not create a human-review gate.

Reach for a different asset when:

* The next action is already clear. Invoke the phase skill directly.
* You want to understand or challenge something before committing to work. Use [rpi-walkthrough](../../skills/rpi/rpi-walkthrough) or [rpi-challenger](../../skills/rpi/rpi-challenger).

## How to use it

1. Select **RPI Agent** from the chat agent picker, or run the [/rpi](../../prompts/hve-core/rpi) prompt.
2. Describe the task, or supply an issue or PR reference, a task slug, or an existing artifact path. An explicit anchor identifies the task; a new conversation alone does not resume earlier work.
3. In manual mode, the agent walks you through each phase's artifacts and asks whether to refine the work or advance. Request the next phase in your answer, use the **Research**, **Plan**, **Implement**, and **Review** handoffs, or invoke the matching `/rpi-*` command.
4. To switch to automatic mode, select **Full Auto** or ask the agent to automatically iterate through RPI until the work is finished. No second confirmation is needed. When intent is unspecified, choose one of the four options below. Every question includes freeform input.
5. When a retained decision or exceptional confirmation pauses the session, answer the question; the session resumes automatically.
6. In automatic mode, the agent continues required in-scope follow-ups from Research in a child task, honoring your decision preferences. Each child has its own plan, implementation, and Review evidence. Optional improvements stay unselected. The session stops when acceptance criteria are met, or pauses when a blocker prevents progress.

The opening question is "How would you like us to work on this?":

* Handle it end to end: the agent makes decisions and runs all RPI phases and needed follow-ups until your request is complete.
* Keep going, but check with me: the agent progresses automatically and asks when decisions or direction need clarification throughout the workflow, including Review and follow-up selection.
* Research and plan with me: the agent researches and plans with questions where needed, then explains the artifacts and stops before Implementation so you can refine the research and plan together.
* Work through each phase with me: the agent asks about unclear decisions, explains each phase's artifacts, and waits for you to choose when to advance.

You can retain follow-up selection through the second option or a custom answer. Use the ranked handoffs or answer the follow-up question; you can also stop or switch to manual mode at any time. Resuming automatic mode preserves explicitly retained decisions and a stop-before-Implementation boundary unless you change them.

With the stop-before-Implementation option, the agent completes Planning and its applicable evidence and decision gates, then returns to manual mode in Plan. It explains trade-offs and readiness and offers refinement or an explicit Implementation request. Iteration preserves task identity and assessment evidence. Resuming the conversation alone does not start Implementation.

If critique is interrupted or deferred, `rpi-plan` reconciles saved evidence, verifies no competing run is active, and records a concrete resolving action before continuing missing assessment work. Recovery within authorized scope needs no fresh consent and has no lifetime retry cap. Parent-owned closure handles ordinary corrections; actual assessment covers missing or materially changed scope. Neither recovery nor a Ready result removes your stop-before-Implementation boundary.

## Example usage

```text
Work through each phase with me to add Azure Blob Storage output to the pipeline writers.
```

The agent uses manual mode, walks you through the Research findings, and asks whether to refine them or advance:

```text
* Mode: manual; session: n/a; phase: Research; task: blob-storage
* Research: executed; Planning Readiness Ready
* Decisions: managed identity for production (confirmed)

| Artifact                                                                                                                         | Description               |
|----------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| [.copilot-tracking/research/2026-09-04/blob-storage-research.md](.copilot-tracking/research/2026-09-04/blob-storage-research.md) | Primary research artifact |

## Next Steps

Would you like to refine the research or move to Planning? You can also enter a different next step.
To continue, request Planning in your answer, run `/rpi-plan`, or select the Plan handoff.
```

To delegate progression and ordinary decisions explicitly:

```text
Use automatic mode. Make the decisions and keep iterating through full RPI loops until the storage output and its required tests are complete.
```

After Review identifies a required test gap, the agent records the decision and continues without a follow-up question:

```text
* Mode: automatic; session: running; task blob-storage: completed; phase: Follow-up
* Review: Complete; outcome Residual work; RV-001 routed to follow-up

Selected required follow-up:
1. Add integration tests against the storage emulator (required by the acceptance criteria; RV-001).

Starting child task blob-storage-integration-tests from Research, reusing the existing storage findings.
Optional retry-helper cleanup remains unselected.
```

Once required work has passing validation and completed Review evidence applicable to the current implementation, the agent stops the automatic session and reports completion. A child's changes must account for affected earlier acceptance checks. A repeated unresolved finding without measurable progress or a materially different evidence-backed corrective approach pauses as a no-progress blocker; file changes alone do not justify another loop.
