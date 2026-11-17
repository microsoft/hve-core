---
title: rpi-tracking-audit
description: "Read-only audit of the RPI tracking artifacts under .copilot-tracking/ that reports where each task stands, the next /rpi or /rpi-* command, a resume or handover brief, and whether plans, critiques, changes records, reviews, and RPI session state still agree. Use when checking where RPI work stands before resuming or handing it over, or when an RPI phase redoes work or cannot find its evidence."
sidebar_position: 7
author: Microsoft
ms.date: 2026-11-11
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-tracking-audit
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | skill                                                                                |
| Source      | `.github/skills/rpi/rpi-tracking-audit`                                              |
| Invocation  | Invoked directly as `/rpi-tracking-audit`, or loaded on demand by referencing agents |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Read-only audit of the RPI tracking artifacts under .copilot-tracking/ that reports where each task stands, the next /rpi or /rpi-* command, a resume or handover brief, and whether plans, critiques, changes records, reviews, and RPI session state still agree. Use when checking where RPI work stands before resuming or handing it over, or when an RPI phase redoes work or cannot find its evidence.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-tracking-audit` when you return to RPI work after a break, hand a task to a teammate, or see an RPI phase misbehave, such as `/rpi-implement` redoing a finished task or `/rpi-review` finding no evidence. The skill runs a read-only, standard-library Python audit over `.copilot-tracking/` and reports each task's state, the next `/rpi` or `/rpi-*` command with its arguments, and the places where the plan, critique, changes record, review, and RPI session state no longer agree.

It needs Python 3.11 or later, writes a report, and changes no tracking file. Credential-shaped values found in the folder are redacted from the report and named by file and line. Detection covers common token shapes only, so read a report before you paste it into a chat or a handover.

Reach for a different asset when:

* You want to follow a live session phase by phase in a host that shows canvases. Open the [RPI Workflow canvas](../../../rpi/rpi-workflow-canvas).
* You want to continue a paused session and keep its state current. Use [rpi](rpi); the audit only reads the session state and names `/rpi task=<slug>` as the way to resume.
* You want to understand what a plan or change does. Use [rpi-walkthrough](rpi-walkthrough).
* You want to fix what the audit found. Use [rpi-plan](rpi-plan), [rpi-implement](rpi-implement), or [rpi-review](rpi-review) for the phase the finding names.

## Example usage

```text
/rpi-tracking-audit task=report-export brief
```

The skill runs its script on the repository and answers from the report. In this example the plan marks `P01-T02` done, but the changes record has no entry for it. The excerpt shortens the paths and the finding text:

```text
| Task          | State                     | Plan      | Next action                                         |
|---------------|---------------------------|-----------|-----------------------------------------------------|
| report-export | implemented, not reviewed | 2/2 tasks | /rpi-review task=report-export plan=... changes=... |

| #  | Artifact                                                 | Finding                                                          |
|----|----------------------------------------------------------|------------------------------------------------------------------|
| F1 | .copilot-tracking/plans/2026-10-20/report-export-plan.md | PL6 `P01-T02` is checked; the changes record has no entry for it |
```

The answer recommends recording the `P01-T02` changes entry, or unchecking the task, before running the review, so the review has implementation evidence for every checked task.
