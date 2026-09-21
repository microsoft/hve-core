---
title: Dt Method 06 Planning
description: Concept analysis and prototype approach design for Design Thinking Method 6a
sidebar_position: 11
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-06-planning
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                             |
|-------------|-------------------------------------------------------------------|
| Kind        | prompt                                                            |
| Source      | `.github/prompts/design-thinking/dt-method-06-planning.prompt.md` |
| Invocation  | Slash command `/dt-method-06-planning`                            |
| Interactive | Yes                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Concept analysis and prototype approach design for Design Thinking Method 6a
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 6a to select a low-fidelity prototype approach for one or more evaluated concepts. Return to concept evaluation when the team has not yet chosen what needs to be tested.

## How to use it

Provide the `project-slug` and optionally name `selectedConcepts`. The prompt identifies assumptions, chooses a proportionate prototype format, and defines what evidence the prototype should expose.

## Example usage

```text
/dt-method-06-planning project-slug=factory-floor-maintenance selectedConcepts="shift-summary"
```

The prompt proposes a low-fidelity prototype plan centered on the concept's highest-risk assumption.
