---
title: rpi-challenger
description: "Challenge a confirmed task, decision, plan, or artifact through adaptive skeptical questions. Use when you need to expose assumptions before acting."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-challenger
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                            |
|-------------|----------------------------------------------------------------------------------|
| Kind        | skill                                                                            |
| Source      | `.github/skills/rpi/rpi-challenger`                                              |
| Invocation  | Invoked directly as `/rpi-challenger`, or loaded on demand by referencing agents |
| Interactive | No                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Challenge a confirmed task, decision, plan, or artifact through adaptive skeptical questions. Use when you need to expose assumptions before acting.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-challenger` before committing to a task, decision, plan, or artifact when you want its assumptions exposed rather than confirmed. The skill first proposes a factual scope and waits for your confirmation, then asks one open-ended, non-leading question per turn, following your answers to the most material remaining uncertainty.

It records the exchange, coverage, and unresolved items in `.copilot-tracking/challenges/{{YYYY-MM-DD}}/{{task_slug}}-challenge.md` and leaves every other artifact untouched.

During the active exchange it does not solve, review, validate, or recommend. At closeout it summarizes coverage and unresolved items and may name an `/rpi-*` command as an advisory next step, without invoking it.

Reach for a different asset when:

* You want an evidence-backed assessment of a plan. Use [rpi-plan-critique](rpi-plan-critique).
* You want to understand how something works. Use [rpi-walkthrough](rpi-walkthrough).
* You want new evidence gathered. Use [rpi-research](rpi-research).

## Example usage

```text
/rpi-challenger subject="Move all pipeline writers to the async storage client" artifacts=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md focus="rollout risk"
```

The skill states the candidate scope and asks you to confirm it, then begins:

```text
Scope: the P02 writer migration in the blob-storage plan, focused on rollout risk. Confirm to begin.
```

```text
What evidence tells you the existing synchronous writers can be switched without changing
their callers' error handling?
```

After you end the session, the closeout separates session status from what remains open:

```text
* Session: Complete; 4 angles explored, 2 unresolved
* Unresolved: caller error-handling contract (needs code evidence); rollback path if the async client fails in production (needs a decision)
* Advisory next option: `/rpi-research` for the caller contract before P02 begins
```
