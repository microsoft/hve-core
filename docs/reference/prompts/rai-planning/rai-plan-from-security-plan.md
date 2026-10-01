---
title: Rai Plan From Security Plan
description: Start responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended)
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - rai-planning
  - rai-plan-from-security-plan
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                |
|-------------|----------------------------------------------------------------------|
| Kind        | prompt                                                               |
| Source      | `.github/prompts/rai-planning/rai-plan-from-security-plan.prompt.md` |
| Invocation  | Slash command `/rai-plan-from-security-plan`                         |
| Interactive | Yes                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start responsible AI assessment planning from a completed Security Plan using the RAI Planner agent in from-security-plan mode (recommended)
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a completed security plan provides the starting evidence for a Responsible AI assessment. Use PRD or capture mode when no current security plan exists.

## How to use it

Provide the `project-slug`. The RAI Planner reads the security plan as source evidence, identifies RAI-specific gaps that security planning does not resolve, and keeps the result subject to qualified review.

## Example usage

```text
/rai-plan-from-security-plan project-slug=customer-support-assistant
```

The prompt creates a draft RAI assessment plan that traces reusable security evidence and asks for missing RAI context.
