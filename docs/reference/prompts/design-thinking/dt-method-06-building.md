---
title: Dt Method 06 Building
description: Scrappy prototype building with fidelity enforcement for Design Thinking Method 6b
sidebar_position: 10
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-06-building
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                             |
|-------------|-------------------------------------------------------------------|
| Kind        | prompt                                                            |
| Source      | `.github/prompts/design-thinking/dt-method-06-building.prompt.md` |
| Invocation  | Slash command `/dt-method-06-building`                            |
| Interactive | Yes                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Scrappy prototype building with fidelity enforcement for Design Thinking Method 6b
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 6b to build a deliberately rough prototype that tests one important assumption. Use the planning prompt first when the concept, assumption, or prototype format is not settled.

## How to use it

Provide the `project-slug` and optionally choose `prototypeFormats`. The prompt creates only the fidelity needed for learning and avoids turning the exercise into production implementation.

## Example usage

```text
/dt-method-06-building project-slug=factory-floor-maintenance prototypeFormats="paper, markdown stubs"
```

The prompt builds rough prototype materials for testing the selected assumption.
