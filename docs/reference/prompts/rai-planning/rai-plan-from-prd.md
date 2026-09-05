---
title: Rai Plan From Prd
description: Start responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - rai-planning
  - rai-plan-from-prd
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                      |
|-------------|------------------------------------------------------------|
| Kind        | prompt                                                     |
| Source      | `.github/prompts/rai-planning/rai-plan-from-prd.prompt.md` |
| Invocation  | Slash command `/rai-plan-from-prd`                         |
| Interactive | Yes                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Start responsible AI assessment planning from PRD/BRD artifacts using the RAI Planner agent in from-prd mode
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a confirmed PRD or BRD should seed Responsible AI assessment planning. Use capture mode when requirements evidence cannot be found or does not describe the AI system adequately.

## How to use it

Provide the `project-slug`. The RAI Planner discovers the requirements artifact, extracts relevant evidence, asks only for missing AI-risk context, and preserves qualified-review ownership of the assessment.

## Example usage

```text
/rai-plan-from-prd project-slug=customer-support-assistant
```

The prompt initializes a draft RAI plan from the available requirements or falls back to focused capture questions.
