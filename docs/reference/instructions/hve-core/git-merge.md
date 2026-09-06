---
title: Hve Core/Git Merge
description: "Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls"
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-27
ms.topic: reference
keywords:
  - instruction
  - hve-core
  - hve-core/git-merge
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                     |
|-------------|-----------------------------------------------------------|
| Kind        | instruction                                               |
| Source      | `.github/instructions/hve-core/git-merge.instructions.md` |
| Invocation  | Applied automatically                                     |
| Interactive | No                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Git merge, rebase, and rebase --onto workflows with conflict handling and stop controls
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this protocol when coordinating a merge, rebase, or `rebase --onto`
operation, especially when conflicts or a review pause are possible. Start
from a clean, identified workspace, preserve unrelated work through stashing,
and never use this workflow as authorization to push or rewrite remote history.

## Example usage

<!-- asset-docs:stub -->
Provide a concrete example that shows the asset in action, including representative input and the resulting output.
