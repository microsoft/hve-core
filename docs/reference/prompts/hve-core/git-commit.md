---
title: Git Commit
description: "Stage selected paths, confirm the staged set, and create a conventional commit"
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - git-commit
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                           |
|-------------|-------------------------------------------------|
| Kind        | prompt                                          |
| Source      | `.github/prompts/hve-core/git-commit.prompt.md` |
| Invocation  | Slash command `/git-commit`                     |
| Interactive | Yes                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Stage selected paths, confirm the staged set, and create a conventional commit
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when you want to select whole changed paths, inspect the exact staged set, and create one local commit. Use git-commit-message when you want message guidance without changing repository history.

## How to use it

Invoke the command, select the whole paths intended for the commit, and confirm the exact staged set. The prompt preserves pre-existing index intent, generates a Conventional Commit message, and creates one local commit; it does not push it.

## Example usage

```text
/git-commit
```

The prompt stages only the selected whole paths and creates one local commit after exact staged-set confirmation.
