---
title: Dt Method 04 Convergence
description: Theme discovery for Design Thinking Method 4c through philosophy-based clustering
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-04-convergence
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                |
|-------------|----------------------------------------------------------------------|
| Kind        | prompt                                                               |
| Source      | `.github/prompts/design-thinking/dt-method-04-convergence.prompt.md` |
| Invocation  | Slash command `/dt-method-04-convergence`                            |
| Interactive | Yes                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Theme discovery for Design Thinking Method 4c through philosophy-based clustering
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 4c to discover themes in an existing divergent idea set. Return to ideation when the set is too small or narrow for meaningful clustering.

## How to use it

Provide the `project-slug` and optionally the number of ideas to evaluate. The prompt groups ideas by shared philosophy and helps participants name themes without silently discarding outliers.

## Example usage

```text
/dt-method-04-convergence project-slug=factory-floor-maintenance ideaCount=15
```

The prompt clusters the recorded ideas and returns candidate themes for team review.
