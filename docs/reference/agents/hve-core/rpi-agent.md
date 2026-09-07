---
title: RPI Agent
description: "User-selected RPI workflow wrapper for Research, Plan, Implement, Review, and Follow-up. Use when one task needs lifecycle coordination."
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
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

Select `RPI Agent` when one task should move through Research, Plan, Implement, Review, and Follow-up with a durable state record and one stable task identity. The agent activates the matching skills ([rpi-research](../../skills/rpi/rpi-research), [rpi-plan](../../skills/rpi/rpi-plan), [rpi-implement](../../skills/rpi/rpi-implement), [rpi-review](../../skills/rpi/rpi-review)) rather than duplicating their protocols.

It persists mode, active phase, artifact pointers, decisions, blockers, and ranked follow-ups in one JSON state record so a later conversation can resume from the recorded phase.

It offers two modes:

| Mode        | Behavior                                                                                                                                                                                                                                                               |
|-------------|------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `manual`    | Default. Stays in the active phase until you invoke the next `/rpi-*` command or select a phase handoff. You own every material decision.                                                                                                                              |
| `automatic` | Entered only after you confirm the **Full Auto** request. Completes the remaining phases through Review without routine approval prompts, resolving ordinary Research and Plan decisions itself unless you chose to retain them, then offers ranked follow-up choices. |

Both modes stop for blockers, required human review, and destructive, hard-to-reverse, or externally visible actions.

Reach for a different asset when:

* You want a lighter, single-conversation pass with no persisted state. Use [rpi-quick](../../skills/rpi/rpi-quick).
* The next action is already clear. Invoke the phase skill directly.
* You want to understand or challenge something before committing to work. Use [rpi-walkthrough](../../skills/rpi/rpi-walkthrough) or [rpi-challenger](../../skills/rpi/rpi-challenger).

## How to use it

1. Select **RPI Agent** from the chat agent picker, or run the [/rpi](../../prompts/hve-core/rpi) prompt.
2. Describe the task, or supply an issue or PR reference, a task slug, or an existing artifact path. An explicit anchor identifies the task; a new conversation alone does not resume earlier work.
3. In manual mode, use the **Research**, **Plan**, **Implement**, and **Review** handoffs, or the matching `/rpi-*` commands, to advance one phase at a time.
4. To switch modes, select **Full Auto** and answer the confirmation: enter automatic mode, retain research decisions, retain planning decisions, retain both, or remain in manual mode.
5. When a retained decision or exceptional confirmation pauses the session, answer the question; the session resumes automatically.
6. After Review in automatic mode, choose a ranked follow-up (the **1️⃣**, **2️⃣**, and **3️⃣** handoffs), **Stop automatic session**, or **Switch to manual mode**. A selected follow-up starts a child task from Research.

## Example usage

```text
Research, plan, implement, and review adding Azure Blob Storage output to the pipeline writers.
```

In manual mode the agent runs Research and waits:

```text
* Mode: manual; session: n/a; phase: Research; task: blob-storage
* Research: executed; Planning Readiness Ready
* Decisions: managed identity for production (confirmed)

| Artifact                                                                                                                         | Description               |
|----------------------------------------------------------------------------------------------------------------------------------|---------------------------|
| [.copilot-tracking/research/2026-09-04/blob-storage-research.md](.copilot-tracking/research/2026-09-04/blob-storage-research.md) | Primary research artifact |

## Next Steps

Run `/rpi-plan` or select the Plan handoff to continue.
```

After **Full Auto** is confirmed with agent-owned decisions, the agent continues through Plan, Implement, and Review, then presents the follow-up checkpoint:

```text
* Mode: automatic; session: running; task blob-storage: completed; phase: Follow-up
* Review: Complete; outcome Residual work; RV-001 routed to follow-up

Ranked follow-ups:
1. Add integration tests against the storage emulator (small, unblocks CI coverage)
2. Extract the retry policy into a shared helper (reduces duplication across writers)
3. Document the managed identity setup for operators

Choose 1, 2, or 3, Stop automatic session, or Switch to manual mode.
```
