---
title: Dt Handoff Problem Space
description: Compiles DT Methods 1-3 into research-ready input for rpi-research at the Problem Space exit
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-handoff-problem-space
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                |
|-------------|----------------------------------------------------------------------|
| Kind        | prompt                                                               |
| Source      | `.github/prompts/design-thinking/dt-handoff-problem-space.prompt.md` |
| Invocation  | Slash command `/dt-handoff-problem-space`                            |
| Interactive | Yes                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compiles DT Methods 1-3 into research-ready input for rpi-research at the Problem Space exit
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when Methods 1 through 3 are ready to be compiled into a Problem Space handoff for RPI research. Continue coaching instead when required artifacts or evidence are incomplete.

## How to use it

Provide the completed `project-slug`. The prompt checks method completion, surfaces gaps, and writes a research-ready handoff only from available project evidence.

## Example usage

```text
/dt-handoff-problem-space project-slug=factory-floor-maintenance
```

The prompt compiles Methods 1 through 3 into a traceable handoff or reports the smallest missing evidence.
