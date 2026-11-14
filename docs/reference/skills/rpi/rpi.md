---
title: rpi
description: "Coordinate a resumable RPI session through Research, Plan, Implement, Review, and Follow-up with durable session state and RPI Workflow canvas integration. Use when a task needs multi-phase RPI lifecycle coordination."
sidebar_position: 9
author: Microsoft
ms.date: 2026-11-11
ms.topic: reference
keywords:
  - skill
  - rpi
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                 |
|-------------|-----------------------------------------------------------------------|
| Kind        | skill                                                                 |
| Source      | `.github/skills/rpi/rpi`                                              |
| Invocation  | Invoked directly as `/rpi`, or loaded on demand by referencing agents |
| Interactive | No                                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coordinate a resumable RPI session through Research, Plan, Implement, Review, and Follow-up with durable session state and RPI Workflow canvas integration. Use when a task needs multi-phase RPI lifecycle coordination.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi` (invoked directly as `/rpi`, discovered by the model when a task needs multi-phase RPI coordination, or preloaded by [RPI Agent](../../agents/hve-core/rpi-agent)) when one task should move through Research, Plan, Implement, Review, and Follow-up with a durable state record and one stable task identity.
The skill activates the matching phase skills ([rpi-research](rpi-research), [rpi-plan](rpi-plan), [rpi-implement](rpi-implement), [rpi-review](rpi-review)) rather than duplicating their protocols.

It persists mode, active phase, artifact pointers, decisions, blockers, and ranked follow-ups in one JSON state record per task so a later conversation can resume from the recorded phase. Every task a conversation works on keeps its state in one session folder, `.copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json`, named after the session, and parent and child state files link to each other. Research, plans, critiques, changes, and reviews stay in their own dated folders.

When the host offers the RPI Workflow canvas (`hve-core-rpi-workflow`), the skill opens it once per conversation to show the session, the canvas follows each new loop in the same panel, and what you send from the canvas reaches the session as your direction. The [RPI Workflow Canvas](../../../rpi/rpi-workflow-canvas) guide shows how to use it. When the host can rename chats, the skill names the chat after the session.

Child tasks inherit your participation preferences and unresolved work, but own fresh phase artifacts. They skip the plan critique and Review unless you ask for them on follow-up work. If a state write fails, progression pauses; recovery reconciles the recorded transition before starting work, without creating a duplicate child.

It offers two modes:

| Mode        | Behavior                                                                                                                                                                                                                                                                                                                    |
|-------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `manual`    | Walks you through the active phase's artifacts and waits for an explicit next-phase request or a `/rpi-*` command. You own every material decision.                                                                                                                                                                         |
| `automatic` | An explicit automatic request, such as "full auto", starts automatic progression without another mode question. The session makes ordinary decisions and runs required in-scope follow-ups through new RPI loops until the requested outcome is complete. Explicitly retained decisions and progression limits still apply. |

Both modes stop for blockers, required human review, and destructive, hard-to-reverse, or externally visible actions.

The plan critique and Review each run once per session by default, in the first task, in both modes; plan changes and review-driven follow-ups do not start another unless you ask. Ask to skip either one, and the skill records the skip and moves to the next step: Planning finishes without the critique, and a skipped Review moves from Implement to Follow-up.

When neither your request nor recovered state sets how to proceed, `rpi` asks "How would you like us to work on this?":

* Handle it end to end: makes decisions and runs all RPI phases and needed follow-ups until your request is complete.
* Keep going, but check with me: progresses automatically and asks when decisions or direction need clarification throughout the workflow, including Review and follow-up selection.
* Research and plan with me: researches and plans with questions where needed, then explains the artifacts and stops before Implementation so you can refine the research and plan together.
* Work through each phase with me: asks about unclear decisions, explains each phase's artifacts, and waits for you to choose when to advance.

You can also set the reasoning effort of research or review helper lanes, or of the plan critique's lenses, as one level or for specific lane kinds, topics, or lenses. Subagents stay optional in every phase: say how phases should use them, including not at all, and the skill records that direction and passes it to each phase.

Reach for a different asset when:

* The next action is already clear. Invoke the phase skill directly (`/rpi-research`, `/rpi-plan`, `/rpi-implement`, or `/rpi-review`).
* You want to understand or challenge something before committing to work. Use [rpi-walkthrough](rpi-walkthrough) or [rpi-challenger](rpi-challenger).

## Example usage

### Start a manual RPI session

```text
/rpi Work through each phase with me to add Azure Blob Storage output to the pipeline writers.
```

The skill uses manual mode, opens the RPI Workflow canvas when available, walks you through the Research findings, and asks whether to refine them or advance:

```text
Research is complete. Use the azure-storage-blob async client with managed identity in production, as you confirmed. Nothing else is waiting on you, so Planning can start whenever you're ready.

Session: manual mode, Research phase, task blob-storage

| Artifact                                                                                                                         | Description               |
|----------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| [.copilot-tracking/research/2026-09-04/blob-storage-research.md](.copilot-tracking/research/2026-09-04/blob-storage-research.md) | Primary research artifact |

## Next Steps

Would you like to refine the research or move to Planning? You can also enter a different next step.
To continue, request Planning in your answer or run `/rpi-plan`.
```

### Run an automatic end-to-end RPI session

```text
/rpi mode=automatic Make the decisions and keep iterating through RPI loops until the storage output and its required tests are complete.
```

After Review identifies a required test gap, the skill records the decision and continues without a follow-up question:

```text
* Mode: automatic; session: running; task blob-storage: completed; phase: Follow-up
* Review: Complete; outcome Residual work; RV-001 routed to follow-up

Selected required follow-up:
1. Add integration tests against the storage emulator (required by the acceptance criteria; RV-001).

Starting child task blob-storage-integration-tests from Research, reusing the existing storage findings; the session's one critique and Review have run, so the child skips both.
Optional retry-helper cleanup remains unselected.
```

Once required work has passing validation, with the session's Review for the first task and implementation evidence for child work, the skill stops the automatic session and reports completion, naming any child changes that were validated but not reviewed.
