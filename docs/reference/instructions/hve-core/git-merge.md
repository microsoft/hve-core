---
title: Hve Core/Git Merge
description: "Git merge, rebase, and rebase --onto conventions for workspace preparation, conflict resolution, and no-push guardrails. Use when merging or rebasing a branch or resolving Git conflicts."
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-07
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
Git merge, rebase, and rebase --onto conventions for workspace preparation, conflict resolution, and no-push guardrails. Use when merging or rebasing a branch or resolving Git conflicts.
<!-- END AUTO-GENERATED: overview -->

## When to use it

The agent loads these conventions on demand whenever a request involves merging, rebasing, or
resolving Git conflicts, because the file has a `description` and no `applyTo`. They cover preparing
a clean workspace, the operation commands, resolving each conflict with a documented rationale,
finishing or aborting, and never pushing on your behalf. Run the `/git-merge` skill when you want the
same conventions as a guided workflow with explicit inputs, optional review pauses, and a completion
summary.

## Example usage

Ask in chat:

```text
Merge origin/main into this branch and resolve the conflicts.
```

The agent loads these conventions, confirms a clean working tree, runs `git merge --no-edit origin/main`,
resolves each conflicted file with a recorded rationale, and finishes with `git status --short` and a
summary. Pushing the branch stays with you.
