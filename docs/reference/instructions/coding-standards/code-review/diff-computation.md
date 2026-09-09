---
title: Coding Standards/Code Review/Diff Computation
description: "Code review diff computation: branch detection, scope locking, large-diff handling, and non-source filtering"
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - coding-standards
  - coding-standards/code-review/diff-computation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                |
|-------------|--------------------------------------------------------------------------------------|
| Kind        | instruction                                                                          |
| Source      | `.github/instructions/coding-standards/code-review/diff-computation.instructions.md` |
| Invocation  | Applied automatically                                                                |
| Interactive | No                                                                                   |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Code review diff computation: branch detection, scope locking, large-diff handling, and non-source filtering
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this protocol at the start of a code review to select the correct diff for
a feature branch, uncommitted work, selected code, or a specific commit. It
locks findings to changed lines and filters non-source output; use ordinary
repository exploration instead when the task is not a review.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
