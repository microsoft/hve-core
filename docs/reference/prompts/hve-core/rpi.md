---
title: Rpi
description: "Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow"
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - rpi
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                    |
|-------------|------------------------------------------|
| Kind        | prompt                                   |
| Source      | `.github/prompts/hve-core/rpi.prompt.md` |
| Invocation  | Slash command `/rpi`                     |
| Interactive | Yes                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `/rpi` to start or resume [RPI Agent](../../agents/hve-core/rpi-agent) from a slash command with the task stated up front. It is the prompt entry point to the same agent; choose it when you already know the task and want to skip selecting the agent from the picker. The agent begins with research readiness, so supplied evidence is reused when adequate rather than researched again.

Reach for a different asset when:

* You want the skill-based sequencer without a persisted state record. Use [rpi-quick](../../skills/rpi/rpi-quick).
* You want one phase only. Invoke `/rpi-research`, `/rpi-plan`, `/rpi-implement`, or `/rpi-review` directly.

## How to use it

1. Type `/rpi` in Copilot Chat and supply `task=` with the task description or target outcome. This input is required.
2. Add `continue=` with a task slug, artifact path, or issue reference to resume an existing task from its recorded state and phase artifacts.
3. Add `followUp=` to start a child task for a distinct follow-up item from a prior review. It begins at Research unless the prerequisites for a later phase are supplied.
4. Continue in the agent: advance phases manually with the phase handoffs, or select **Full Auto** to request an automatic session.

Full Auto requires explicit mode confirmation. Required confirmations, blockers, and human review still apply. After Review, the agent presents evidence-grounded follow-up choices before starting another task.

## Example usage

```text
/rpi task="Add Azure Blob Storage output to the pipeline writers"
```

Resume a task later in a new conversation:

```text
/rpi task="blob storage writers" continue=blob-storage
```

The agent loads the matching state record and reports where it is:

```text
* Mode: manual; phase: Implement; task: blob-storage
* Completed markers: P01-T01, P01-T02; remaining: P02-T01, P03-T01

## Next Steps

Run `/rpi-implement` to continue with P02-T01.
```
