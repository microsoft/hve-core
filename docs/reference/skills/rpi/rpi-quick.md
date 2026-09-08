---
title: rpi-quick
description: "Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle."
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-quick
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                       |
|-------------|-----------------------------------------------------------------------------|
| Kind        | skill                                                                       |
| Source      | `.github/skills/rpi/rpi-quick`                                              |
| Invocation  | Invoked directly as `/rpi-quick`, or loaded on demand by referencing agents |
| Interactive | No                                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `/rpi-quick` when one invocation should carry a task through research readiness, planning, implementation, review, and follow-up without you issuing each phase command. It is an explicit parent: after each stage's gates pass it continues to the next eligible stage, and it stops only for a blocker, a required confirmation, or a user-owned decision.

It reuses adequate evidence rather than repeating research, records the Research disposition (`executed`, `reused`, or `satisfied-and-skipped`), runs the single plan critique through [rpi-plan](rpi-plan), and uses agent-owned Review decisions unless you ask for the Review item walkthrough.

Choose between the two lifecycle entry surfaces:

| Surface                                      | Prefer it when                                                                                                          |
|----------------------------------------------|-------------------------------------------------------------------------------------------------------------------------|
| `/rpi-quick`                                 | You want a lightweight, skill-based pass over one task in the current conversation                                      |
| [RPI Agent](../../agents/hve-core/rpi-agent) | You want manual phase control, a persisted state record, an explicit automatic mode, and ranked follow-ups after Review |

Reach for a direct phase skill when the next responsible action is already clear, such as [rpi-implement](rpi-implement) for an approved plan.

## Example usage

```text
/rpi-quick task="Add retry with backoff to blob uploads" evidence=.copilot-tracking/research/2026-09-04/blob-storage-research.md
```

The skill assesses the supplied research, records `reused` when it is adequate, and continues:

```text
* Research: reused; Planning Readiness Ready from the supplied artifact
* Plan: created; critique standard, verdict Pass
* Implement: Complete; P01-P02 checked, validation passed
* Review: Complete; outcome Residual work; RV-001 (Low) routed to a distinct follow-up

| Artifact                                                                                                                                       | Description    |
|------------------------------------------------------------------------------------------------------------------------------------------------|----------------|
| [.copilot-tracking/plans/2026-09-04/blob-upload-retry-plan.md](.copilot-tracking/plans/2026-09-04/blob-upload-retry-plan.md)                   | Plan           |
| [.copilot-tracking/changes/2026-09-04/blob-upload-retry-changes.md](.copilot-tracking/changes/2026-09-04/blob-upload-retry-changes.md)         | Changes record |
| [.copilot-tracking/reviews/logs/2026-09-04/blob-upload-retry-review.md](.copilot-tracking/reviews/logs/2026-09-04/blob-upload-retry-review.md) | Review record  |

## Next Steps

No user action is required; the follow-up item is recorded for later planning.
```

Use `continue=...` to resume the task from its artifacts, or `followUp=...` to start a distinct review follow-up item.
