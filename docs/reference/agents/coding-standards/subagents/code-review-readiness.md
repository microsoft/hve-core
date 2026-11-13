---
title: Code Review Readiness
description: "Review change packaging, captured PR metadata, validation evidence, and changed documentation."
sidebar_position: 5
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-readiness
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/coding-standards/subagents/code-review-readiness.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)   |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review change packaging, captured PR metadata, validation evidence, and changed documentation.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Readiness to check change packaging, validation evidence, PR metadata, and changed documentation. It preloads `code-review-core` and `code-review-readiness`. PR checks use only the metadata captured in the snapshot, so missing PR context is recorded as an unavailable check.
Code correctness, standards, accessibility, and security stay with their own perspectives.

## Example usage

For a PR, the parent supplies the work item, assigned files and hunks, available validation, and the result path, and the snapshot holds the captured PR metadata. The worker compares the description and validation claims with the actual change and anchors packaging findings to the exact metadata field, such as an unchecked required checklist item.
It returns the result path, execution status, and any unavailable delivery checks, and it never checks a human-review box.
