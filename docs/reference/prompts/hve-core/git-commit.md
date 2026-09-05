---
title: Git Commit
description: "Stage all changes, generate a conventional commit message, and commit"
sidebar_position: 5
author: Microsoft
ms.date: 2026-09-02
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
Stage all changes, generate a conventional commit message, and commit
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when all intended working-tree changes are ready to be staged and committed together. Use git-commit-message when you want message guidance without changing repository history.

## How to use it

Review the working tree before invoking the command. The prompt checks ignored and sensitive paths, stages the intended changes, generates a Conventional Commit message, and creates the commit; it does not push it.

## Example usage

```text
/git-commit
```

The prompt stages the reviewed repository changes and creates one local commit with a generated Conventional Commit message.
