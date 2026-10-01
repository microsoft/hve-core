---
title: Git Commit Message
description: Generate a conventional commit message from all branch changes
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - git-commit-message
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                   |
|-------------|---------------------------------------------------------|
| Kind        | prompt                                                  |
| Source      | `.github/prompts/hve-core/git-commit-message.prompt.md` |
| Invocation  | Slash command `/git-commit-message`                     |
| Interactive | Yes                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Generate a conventional commit message from all branch changes
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt when you need a Conventional Commit message derived from the current branch changes without creating a commit. Use the git-commit prompt only when the changes are also ready to stage and commit.

## How to use it

Invoke the prompt in the target repository and optionally set `useTerminal=false` when supplied context should replace terminal inspection. Review the generated subject and body before using them in Git.

## Example usage

```text
/git-commit-message useTerminal=false
```

The prompt drafts a Conventional Commit message from the supplied change context and does not create a commit.
