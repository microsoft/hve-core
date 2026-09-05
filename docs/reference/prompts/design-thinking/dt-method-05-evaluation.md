---
title: Dt Method 05 Evaluation
description: Stakeholder alignment and three-lens evaluation for Design Thinking Method 5c
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - design-thinking
  - dt-method-05-evaluation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                               |
|-------------|---------------------------------------------------------------------|
| Kind        | prompt                                                              |
| Source      | `.github/prompts/design-thinking/dt-method-05-evaluation.prompt.md` |
| Invocation  | Slash command `/dt-method-05-evaluation`                            |
| Interactive | Yes                                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Stakeholder alignment and three-lens evaluation for Design Thinking Method 5c
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt during Method 5c when stakeholders need to compare concepts through desirability, feasibility, and viability. Use concept articulation first when candidate concepts are not yet clear enough to evaluate.

## How to use it

Provide the `project-slug` and optionally name the stakeholder groups that should participate. The prompt facilitates evidence-based evaluation and records alignment or disagreement rather than inventing consensus.

## Example usage

```text
/dt-method-05-evaluation project-slug=factory-floor-maintenance stakeholderGroups="operators, managers, IT"
```

The prompt compares current concepts across the three lenses and records stakeholder perspectives.
