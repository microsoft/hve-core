---
title: rpi
description: "Coordinate a resumable RPI session through Research, Plan, Implement, Review, and Follow-up with durable session state and RPI Workflow canvas integration. Use when a task needs multi-phase RPI lifecycle coordination."
sidebar_position: 9
author: Microsoft
ms.date: 2026-11-12
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
The skill activates the matching phase skills ([rpi-research](rpi-research), [rpi-plan](rpi-plan), [rpi-implement](rpi-implement), [rpi-review](rpi-review), and [rpi-refine](rpi-refine)) rather than duplicating their protocols.

It persists mode, active phase, artifact pointers (`research`, `plan`, `critique`, `changes`, `review`, and `refinement`), decisions, blockers, and ranked follow-ups in one JSON state record per task so a later conversation can resume from the recorded phase.
Every task a conversation works on keeps its state in one session folder, `.copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json`, named after the session. Research, plans, critiques, changes, acceptance reviews, and refinement reviews stay in their own dated folders.

When the host offers the RPI Workflow canvas (`hve-core-rpi-workflow`), the skill opens it once per conversation to show the session, the canvas follows each loop in the same panel, and both `rpi-review` and `rpi-refine` appear together in the Review view. What you send from the canvas reaches the session as your direction. The [RPI Workflow Canvas](../../../rpi/rpi-workflow-canvas) guide shows how to use it.

It offers two modes:

| Mode        | Behavior                                                                                                                                                                                                                                                                                                                         |
|-------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `manual`    | Walks you through the active phase's artifacts and waits for an explicit next-phase request or a `/rpi-*` command. You own every material decision.                                                                                                                                                                              |
| `automatic` | An explicit automatic request, such as "full auto", starts automatic progression without another mode question. The session makes ordinary decisions and runs required in-scope follow-ups through repeated RPI loops until the requested outcome is complete. Explicitly retained decisions and progression limits still apply. |

Both modes stop for blockers, required human review, and destructive, hard-to-reverse, or externally visible actions.

On the session's initial pass, Planning runs `rpi-plan-critique` and Review runs both [rpi-review](rpi-review) (acceptance verification) and [rpi-refine](rpi-refine) (subtractive refinement); you or a coordinating Project can also select a single review skill (`review=rpi-review` or `review=rpi-refine`) or skip a step.
When another session (such as a Project coordinator) coordinates the session and the completed changes are significant enough to benefit from coordinator-managed review across dedicated sessions, `rpi` sends a `handoff` report with the state, plan, and changes paths so the coordinator can run or delegate the reviews and provide the resulting records back.

Accepted findings from `rpi-review` (`RV-xxx`) and `rpi-refine` (`RF-xxx`) either feed into `rpi-plan` as new `Pxx` planning phases on the active plan for a repeated loop in the same session, or start a separate RPI session with standard RPI rules.
To avoid review-and-implement ping-pong in the same session, follow-up loops after the session's first Review skip another review when fixes stay localized to accepted finding targets, run a `surface`-depth check when the loop introduced significant architectural, contract, domain, or cross-cutting changes, and run another full review only when you explicitly ask for one.

When neither your request nor recovered state sets how to proceed, `rpi` asks "How would you like us to work on this?":

* Handle it end to end: makes decisions and runs all RPI phases and needed follow-ups until your request is complete.
* Keep going, but check with me: progresses automatically and asks when decisions or direction need clarification throughout the workflow, including Review and follow-up selection.
* Research and plan with me: researches and plans with questions where needed, then explains the artifacts and stops before Implementation so you can refine the research and plan together.
* Work through each phase with me: asks about unclear decisions, explains each phase's artifacts, and waits for you to choose when to advance.

You can also set the reasoning effort of research or review helper lanes, or of the plan critique's lenses, as one level or for specific lane kinds, topics, or lenses. Subagents stay optional in every phase: say how phases should use them, including not at all, and the skill records that direction and passes it to each phase.

Reach for a different asset when:

* The next action is already clear. Invoke the phase skill directly (`/rpi-research`, `/rpi-plan`, `/rpi-implement`, `/rpi-review`, or `/rpi-refine`).
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

After `rpi-review` and `rpi-refine` identify a missing emulator test and a duplicate retry helper, the session feeds both into `rpi-plan` as a new `Pxx` follow-up phase:

```text
* Mode: automatic; session: running; task blob-storage: active; phase: Follow-up
* Acceptance review: Complete (Defects found, RV-001); Refinement review: Complete (Refinements identified, RF-001)

Selected required follow-up:
1. Add emulator integration test (RV-001) and replace custom retry loop with shared backoff helper (RF-001).

Transitioning to Plan to append P04 for RV-001 and RF-001; localized fixes in P04 will be validated without repeating full Review.
```

Once required work has passing validation, the skill stops the automatic session and reports completion, noting when follow-up changes after the initial Review were validated without a repeat review.
