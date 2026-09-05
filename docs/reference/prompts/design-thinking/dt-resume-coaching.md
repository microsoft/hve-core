---
title: Dt Resume Coaching
description: Resume a Design Thinking coaching session - reads coaching state and re-establishes context
sidebar_position: 14
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-resume-coaching
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| Kind        | prompt                                                         |
| Source      | `.github/prompts/design-thinking/dt-resume-coaching.prompt.md` |
| Invocation  | Slash command `/dt-resume-coaching`                            |
| Interactive | Yes                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Resume a Design Thinking coaching session - reads coaching state and re-establishes context
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to continue a Design Thinking coaching session that already has saved project state. Use the start-project prompt when no durable state exists yet.

## How to use it

Provide the existing `project-slug`. The prompt reads the saved coaching state, summarizes the recovered context, and asks you to confirm it before coaching continues.

## Example usage

```text
/dt-resume-coaching project-slug=factory-floor-maintenance
```

The prompt restores the saved method, decisions, and open coaching context for confirmation.
