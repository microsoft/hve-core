---
title: Dt Method 05 Concepts
description: Concept articulation for Design Thinking Method 5b from brainstorming themes
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-05-concepts
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                             |
|-------------|-------------------------------------------------------------------|
| Kind        | prompt                                                            |
| Source      | `.github/prompts/design-thinking/dt-method-05-concepts.prompt.md` |
| Invocation  | Slash command `/dt-method-05-concepts`                            |
| Interactive | Yes                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Concept articulation for Design Thinking Method 5b from brainstorming themes
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 5b to turn selected brainstorming themes into coherent user concepts. Return to convergence when themes have not yet been selected or remain too broad.

## How to use it

Provide the `project-slug` and optionally identify `selectedThemes`. The prompt uses the recorded ideas and themes to articulate concepts without adding unsupported user needs.

## Example usage

```text
/dt-method-05-concepts project-slug=factory-floor-maintenance selectedThemes="shift handoff, visibility"
```

The prompt turns the selected themes into reviewable concept statements grounded in project evidence.
