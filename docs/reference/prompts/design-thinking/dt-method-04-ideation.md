---
title: Dt Method 04 Ideation
description: Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation
sidebar_position: 7
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-04-ideation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                             |
|-------------|-------------------------------------------------------------------|
| Kind        | prompt                                                            |
| Source      | `.github/prompts/design-thinking/dt-method-04-ideation.prompt.md` |
| Invocation  | Slash command `/dt-method-04-ideation`                            |
| Interactive | Yes                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 4b when the team needs broad, constraint-informed solution ideas. Use the convergence prompt after a sufficient divergent set exists and the team is ready to cluster it.

## How to use it

Provide the `project-slug`, then optionally supply constraint context and a numeric divergent target. The prompt uses current project evidence to facilitate ideation without selecting a winner prematurely.

## Example usage

```text
/dt-method-04-ideation project-slug=factory-floor-maintenance divergentTarget=15
```

The prompt facilitates at least 15 solution ideas informed by the project's recorded constraints.
