---
title: prompt-refactor
description: Compatibility alias for behavior-preserving prompt artifact cleanup. Routes refactoring to hve-builder refactor mode.
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - hve-core
  - prompt-refactor
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | skill                                                                             |
| Source      | `.github/skills/hve-core/prompt-refactor`                                         |
| Invocation  | Invoked directly as `/prompt-refactor`, or loaded on demand by referencing agents |
| Interactive | No                                                                                |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compatibility alias for behavior-preserving prompt artifact cleanup. Routes refactoring to hve-builder refactor mode.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this compatibility alias to simplify existing customization artifacts while
preserving their triggers, outputs, safety boundaries, and required behavior.
It maps `promptFiles` to HVE Builder's `refactor` mode and shares its quality gates.
Use `prompt-builder` when behavior must intentionally change or a new artifact is
needed; use `prompt-analyze` when source must remain read-only.

## Example usage

Ask: `/prompt-refactor promptFiles=.github/prompts/sample/report.prompt.md
requirements=Consolidate repeated output instructions while preserving section
order, citation requirements, missing-data handling, and approval gates. Edit only
this file.` Supply the actual existing prompt and its consumers as context.

Expect the baseline contract to guide a coherent cleanup, followed by HVE Builder
validation and independent static review. The current workflow contract resolves
the behavior gate, including a supported skip for eligible Minor/Medium changes;
the alias does not add another sandbox or testing loop.

Success is less duplication without lost capabilities, with changed files,
rationale, verdicts, and evidence reported separately. A proposed artifact split,
type change, or new support file requires renewed scope approval. Shorter prose
alone is not success if it removes a stop condition or required behavior.
