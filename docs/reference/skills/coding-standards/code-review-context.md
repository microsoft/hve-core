---
title: code-review-context
description: "Explain captured changes, affected areas, or a specific symbol without grading findings. Shared by Code Review Orientation and Explainer."
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-context
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | skill                                                 |
| Source      | `.github/skills/coding-standards/code-review-context` |
| Invocation  | Loaded on demand by referencing agents                |
| Interactive | No                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Explain captured changes, affected areas, or a specific symbol without grading findings. Shared by Code Review Orientation and Explainer.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill to explain a change and its affected consumers with evidence. The Code Review Orientation subagent uses its overview path to group assigned areas by responsibility and describe intent, before and after behavior, entry points, control and data flow, and affected consumers.
The Code Review Explainer subagent uses its question path to answer one question about a symbol or area.

Neither path assigns severity, grades findings, or counts as review coverage. A question that needs missing evidence or a deeper judgment goes to `code-review-investigation`.

## Example usage

Code Review asks the Explainer how cancellation reaches the importer in an assigned area. The skill traces the immediate call path with symbol tools or bounded file reads and writes a result with `findings: []`.
Its observations link each step to source evidence, suggest follow-on symbols, and state any relationship it couldn't verify as an open question. Code Review uses those observations to update the area description.
