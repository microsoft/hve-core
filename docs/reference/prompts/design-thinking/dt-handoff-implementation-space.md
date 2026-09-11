---
title: Dt Handoff Implementation Space
description: Compiles DT Methods 7-9 into research-ready input for rpi-research at the Implementation Space exit
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-10
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

Provide the `project-slug` after choosing a lateral handoff. The prompt verifies that choice before changing coaching state or creating handoff files, then checks completion across the project lineage and compiles available implementation evidence.

When critical gaps are found and the follow-up question receives no response, the prompt continues only if the earlier handoff choice was verified. Otherwise, its response includes the handoff decision question and stops without writing the transition or handoff files. Proceeding preserves every gap as an RPI Research priority; it does not certify production readiness.

## Example usage

```text
/dt-handoff-implementation-space project-slug=factory-floor-maintenance
```

The prompt creates a research-ready implementation handoff with recorded gaps and lineage only after handoff approval is established.
