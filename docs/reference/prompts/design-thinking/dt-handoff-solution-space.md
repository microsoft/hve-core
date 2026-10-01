---
title: Dt Handoff Solution Space
description: Compiles DT Methods 4-6 into research-ready input for rpi-research at the Solution Space exit
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-handoff-solution-space
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                 |
|-------------|-----------------------------------------------------------------------|
| Kind        | prompt                                                                |
| Source      | `.github/prompts/design-thinking/dt-handoff-solution-space.prompt.md` |
| Invocation  | Slash command `/dt-handoff-solution-space`                            |
| Interactive | Yes                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compiles DT Methods 4-6 into research-ready input for rpi-research at the Solution Space exit
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when Methods 4 through 6 have enough observed evidence to form a Solution Space handoff for RPI research. Continue concept or prototype work when key artifacts still contain gaps or hypothetical results.

## How to use it

Provide the completed `project-slug`. The prompt checks the solution-space artifacts, preserves evidence labels and gap markers, and compiles a handoff without treating simulated results as validation.

## Example usage

```text
/dt-handoff-solution-space project-slug=factory-floor-maintenance
```

The prompt produces a traceable Methods 4 through 6 handoff or identifies the evidence still needed.
