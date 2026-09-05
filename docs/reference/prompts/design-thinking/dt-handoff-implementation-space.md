---
title: Dt Handoff Implementation Space
description: Compiles DT Methods 7-9 into research-ready input for rpi-research at the Implementation Space exit
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-handoff-implementation-space
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                       |
|-------------|-----------------------------------------------------------------------------|
| Kind        | prompt                                                                      |
| Source      | `.github/prompts/design-thinking/dt-handoff-implementation-space.prompt.md` |
| Invocation  | Slash command `/dt-handoff-implementation-space`                            |
| Interactive | Yes                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compiles DT Methods 7-9 into research-ready input for rpi-research at the Implementation Space exit
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when Methods 7 through 9 and their earlier lineage are ready for an Implementation Space handoff to RPI research. Continue Design Thinking work when the implementation evidence or exit tier is incomplete.

## How to use it

Provide the `project-slug`. The prompt checks completion across the project lineage and compiles available implementation evidence; the resulting exit tier informs research but does not bypass it or certify production readiness.

## Example usage

```text
/dt-handoff-implementation-space project-slug=factory-floor-maintenance
```

The prompt creates a research-ready implementation handoff with recorded gaps and lineage.
