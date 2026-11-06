---
title: git-commit
description: "Stage user-selected paths, confirm the exact staged set, and create one local Conventional Commit, or generate a commit message for staged changes without committing. Use when you want a guarded commit or a ready-to-paste message."
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - hve-core
  - git-commit
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                     |
|-------------|-------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                     |
| Source      | `.github/skills/hve-core/git-commit`                                                      |
| Invocation  | Invoked directly as `/git-commit`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Stage user-selected paths, confirm the exact staged set, and create one local Conventional Commit, or generate a commit message for staged changes without committing. Use when you want a guarded commit or a ready-to-paste message.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `git-commit` when you want to select whole changed paths, inspect the exact staged set, and create one local Conventional Commit. Use `mode=message-only` when you want a message for already staged changes without changing the index or history. Use `pull-request` when the work is committed and ready for review.

## How to use it

Run `/git-commit` in the target repository, select the whole paths intended for the commit, and confirm the exact staged set. The skill preserves paths you staged earlier, stops on partially staged paths, generates the message from the commit-message instructions, and creates one local commit. It never pushes. Ask to change the message or undo the commit immediately afterward to use the adjustment flow.

## Example usage

```text
/git-commit
```

The skill lists candidate paths, waits for your selection, stages only those paths, asks you to confirm the staged set, and then commits once and shows the message.

```text
/git-commit mode=message-only
```

The skill reads the staged diff and returns a Conventional Commit message in a code block without staging or committing.
