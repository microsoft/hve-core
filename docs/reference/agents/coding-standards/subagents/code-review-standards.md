---
title: Code Review Standards
description: Review assigned evidence against applicable project criteria and return the shared worker result.
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-09
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-standards
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/coding-standards/subagents/code-review-standards.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)   |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned evidence against applicable project criteria and return the shared worker result.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Standards to check assigned changes against applicable repository instructions and matching skills. It preloads `code-review-core` and `code-review-standards`, and every finding cites the instruction or exact skill name and criterion behind it. Functional correctness stays with the functional perspective.

## Example usage

The parent supplies the work item, assigned files and hunks, depth, applicable criteria, and the result path. The worker selects each matching skill with its origin, applies instruction precedence, and writes a shared result whose observations list every criteria source it used.
If no instructions or skills apply, it records standards evidence as unavailable and returns that gap without inventing project rules.
