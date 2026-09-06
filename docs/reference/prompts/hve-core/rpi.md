---
title: Rpi
description: "Coordinate one task through the Research, Plan, Implement, Review, and Follow-up RPI workflow"
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-02
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

Use this prompt when one task should move through evidence gathering, planning, implementation, review, and explicit follow-up. Invoke a phase-specific RPI skill when you need only one bounded stage.

## How to use it

Provide the `task`, or use `continue` with a matching durable task identity. The prompt records phase artifacts and state, respects blockers and required confirmations, and presents evidence-grounded follow-up choices after Review.

## Example usage

```text
/rpi task="complete prompt reference guidance"
```

The prompt establishes one task identity and coordinates the remaining eligible RPI phases with durable evidence.
