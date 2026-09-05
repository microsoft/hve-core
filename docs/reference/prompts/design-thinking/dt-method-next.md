---
title: Dt Method Next
description: Assess DT project state and recommend next method with sequencing validation
sidebar_position: 13
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-next
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                      |
|-------------|------------------------------------------------------------|
| Kind        | prompt                                                     |
| Source      | `.github/prompts/design-thinking/dt-method-next.prompt.md` |
| Invocation  | Slash command `/dt-method-next`                            |
| Interactive | Yes                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Assess DT project state and recommend next method with sequencing validation
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when a Design Thinking project needs an evidence-based recommendation for its next method. Invoke a specific method prompt instead when the next step is already confirmed.

## How to use it

Provide `project-slug` when the active project cannot be inferred safely. The prompt checks project state and sequencing evidence, recommends the next method, and waits for confirmation before changing coaching state.

## Example usage

```text
/dt-method-next project-slug=factory-floor-maintenance
```

The prompt assesses completed artifacts and proposes the next eligible method for the user to confirm.
