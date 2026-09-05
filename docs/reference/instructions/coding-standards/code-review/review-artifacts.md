---
title: Coding Standards/Code Review/Review Artifacts
description: "Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules"
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - coding-standards
  - coding-standards/code-review/review-artifacts
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | instruction                                                                          |
| Source      | `.github/instructions/coding-standards/code-review/review-artifacts.instructions.md` |
| Invocation  | Applied automatically to `**/.copilot-tracking/reviews/code-reviews/**`              |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Code review artifact persistence: folder structure, metadata schema, verdict normalization, and writing rules
<!-- END AUTO-GENERATED: overview -->

## When to use it

Apply these rules when a code-review workflow writes durable review evidence
under `.copilot-tracking/reviews/code-reviews/`. They define the canonical
files, normalized verdicts, and human-review controls; skip artifact creation
for selected-code reviews or an empty diff as the source protocol directs.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
