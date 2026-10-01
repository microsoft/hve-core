---
title: Git Merge
description: "Coordinate Git merge, rebase, and rebase --onto workflows with conflict handling"
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - git-merge
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                          |
|-------------|------------------------------------------------|
| Kind        | prompt                                         |
| Source      | `.github/prompts/hve-core/git-merge.prompt.md` |
| Invocation  | Slash command `/git-merge`                     |
| Interactive | Yes                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coordinate Git merge, rebase, and rebase --onto workflows with conflict handling
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to coordinate a Git merge, rebase, or rebase-onto operation with explicit conflict handling. Use ordinary Git inspection when you only need to compare branches or view history.

## How to use it

Choose the `operation`, identify the branch and any upstream or onto target, and set `conflictStop=true` when conflicts must return control immediately. Review history-changing operations carefully; the prompt does not push automatically.

## Example usage

```text
/git-merge operation=rebase branch=origin/main conflictStop=true
```

The prompt rebases the current work onto the named branch and stops for user-directed conflict resolution if needed.
