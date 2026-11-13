---
title: RPI Agent
description: "User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination."
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-04
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
User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Select `RPI Agent` from the chat agent picker when you want a dedicated agent entry point that preloads the [rpi](../../skills/rpi/rpi) skill to coordinate Research, Plan, Implement, Review, and Follow-up with a durable state record and one stable task identity.
You can also invoke the [rpi](../../skills/rpi/rpi) skill directly as `/rpi` or let the model load it on demand without switching agents.
Both entry surfaces follow the `rpi` skill instructions, activate the matching phase skills ([rpi-research](../../skills/rpi/rpi-research), [rpi-plan](../../skills/rpi/rpi-plan), [rpi-implement](../../skills/rpi/rpi-implement), [rpi-review](../../skills/rpi/rpi-review), and [rpi-refine](../../skills/rpi/rpi-refine)), and open and use the RPI Workflow canvas (`hve-core-rpi-workflow`) when available.

It persists mode, active phase, artifact pointers (`research`, `plan`, `critique`, `changes`, `review`, and `refinement`), decisions, blockers, and ranked follow-ups in one JSON state record per task so a later conversation can resume from the recorded phase.
Every task a conversation works on keeps its state in one session folder, `.copilot-tracking/rpi-sessions/<date>/<session>/<task>-state.json`, named after the session. Research, plans, critiques, changes, acceptance reviews, and refinement reviews stay in their own dated folders.

When the host offers the RPI Workflow canvas, the agent opens it once per conversation to show the session, the canvas follows each loop in the same panel, and both `rpi-review` and `rpi-refine` appear together in the Review view. What you send from the canvas reaches the agent as your direction. The [RPI Workflow Canvas](../../../rpi/rpi-workflow-canvas) guide shows how to use it.

It offers two modes:

| Mode        | Behavior                                                                                                                                                                                                                                                                                                                       |
|-------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `manual`    | Walks you through the active phase's artifacts and waits for an explicit next-phase request or a `/rpi-*` command. You own every material decision.                                                                                                                                                                            |
| `automatic` | An explicit automatic request, such as "full auto", starts automatic progression without another mode question. The agent makes ordinary decisions and runs required in-scope follow-ups through repeated RPI loops until the requested outcome is complete. Explicitly retained decisions and progression limits still apply. |

Both modes stop for blockers, required human review, and destructive, hard-to-reverse, or externally visible actions.

On the session's initial pass, Planning runs `rpi-plan-critique` and Review runs both [rpi-review](../../skills/rpi/rpi-review) and [rpi-refine](../../skills/rpi/rpi-refine); you or a coordinating Project can also select one review skill or skip a step.
When another session (such as a Project coordinator) coordinates the session and the completed changes are significant enough to benefit from coordinator-managed review across dedicated sessions, the agent sends a `handoff` report with the state, plan, and changes paths so the coordinator can run or delegate the reviews and provide the resulting records back.

Accepted findings from `rpi-review` (`RV-xxx`) and `rpi-refine` (`RF-xxx`) either feed into `rpi-plan` as new `Pxx` planning phases on the active plan for a repeated loop in the same session, or start a separate RPI session with standard RPI rules.
After the session's first Review completes, follow-up loops in the same session skip another review when fixes stay localized to accepted finding targets, run a `surface`-depth check when the loop introduced significant architectural, contract, domain, or cross-cutting changes, and run another full review only when you explicitly ask for one.

You can also set the reasoning effort of research or review helper lanes, or of the plan critique's lenses, as one level or for specific lane kinds, topics, or lenses. Subagents stay optional in every phase: say how phases should use them, including not at all, and the agent records that direction and passes it to each phase.

Reach for a different asset when:

* The next action is already clear. Invoke the phase skill directly.
* You want to understand or challenge something before committing to work. Use [rpi-walkthrough](../../skills/rpi/rpi-walkthrough) or [rpi-challenger](../../skills/rpi/rpi-challenger).

## How to use it

1. Select **RPI Agent** from the chat agent picker.
2. Describe the task, or supply an issue or PR reference, a task slug, or an existing artifact path. An explicit anchor identifies the task; a new conversation alone does not resume earlier work.
3. In manual mode, the agent walks you through each phase's artifacts and asks whether to refine the work or advance. Request the next phase in your answer or invoke the matching `/rpi-*` command.
4. To switch to automatic mode, ask for "full auto" or ask the agent to automatically iterate through RPI until the work is finished. No second confirmation is needed. When intent is unspecified, choose one of the four options below. Every question includes freeform input.
5. When a retained decision or exceptional confirmation pauses the session, answer the question; the session resumes automatically.
6. In automatic mode, the agent feeds required in-scope follow-ups into `rpi-plan` as new `Pxx` planning phases (or into a separate RPI session when broader rework warrants it), honoring your decision preferences. Optional improvements stay unselected. The session stops when acceptance criteria are met, or pauses when a blocker prevents progress.

The opening question is "How would you like us to work on this?":

* Handle it end to end: the agent makes decisions and runs all RPI phases and needed follow-ups until your request is complete.
* Keep going, but check with me: the agent progresses automatically and asks when decisions or direction need clarification throughout the workflow, including Review and follow-up selection.
* Research and plan with me: the agent researches and plans with questions where needed, then explains the artifacts and stops before Implementation so you can refine the research and plan together.
* Work through each phase with me: the agent asks about unclear decisions, explains each phase's artifacts, and waits for you to choose when to advance.

You can retain follow-up selection through the second option or a custom answer. Answer the follow-up question; you can also stop or switch to manual mode at any time. Resuming automatic mode preserves explicitly retained decisions and a stop-before-Implementation boundary unless you change them.

With the stop-before-Implementation option, the agent completes Planning, including its critique unless you skipped it and its decision gates, then returns to manual mode in Plan. It walks you through the research and plan, including trade-offs and readiness, and offers refinement or an explicit Implementation request. Iteration preserves the task and its planning decisions. Resuming the conversation alone does not start Implementation.

If a critique is interrupted before it saves a result, resuming the task reruns it; a missing result is never a pass. Resuming does not remove your stop-before-Implementation boundary.

## Example usage

```text
Work through each phase with me to add Azure Blob Storage output to the pipeline writers.
```

The agent uses manual mode, walks you through the Research findings, and asks whether to refine them or advance:

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

To delegate progression and ordinary decisions explicitly:

```text
Use automatic mode. Make the decisions and keep iterating through RPI loops until the storage output and its required tests are complete.
```

After `rpi-review` and `rpi-refine` identify a missing emulator test and a duplicate retry helper, the agent appends a follow-up planning phase without a prompt:

```text
* Mode: automatic; session: running; task blob-storage: active; phase: Follow-up
* Acceptance review: Complete (Defects found, RV-001); Refinement review: Complete (Refinements identified, RF-001)

Selected required follow-up:
1. Add emulator integration test (RV-001) and replace custom retry loop with shared backoff helper (RF-001).

Transitioning to Plan to append P04 for RV-001 and RF-001; localized fixes in P04 will be validated without repeating full Review.
```

Once required work has passing validation, the agent stops the automatic session and reports completion, noting when follow-up changes after the initial Review were validated without a repeat review.
A repeated unresolved finding without measurable progress or a materially different evidence-backed corrective approach pauses as a no-progress blocker; file changes alone do not justify another loop.
