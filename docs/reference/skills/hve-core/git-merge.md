---
title: git-merge
description: "Coordinate Git merge, rebase, and rebase --onto workflows with conflict resolution, optional review pauses, and a completion summary. Use when integrating a branch locally and resolving conflicts without pushing."
sidebar_position: 5
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - skill
  - hve-core
  - git-merge
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                                    |
|-------------|------------------------------------------------------------------------------------------|
| Kind        | skill                                                                                    |
| Source      | `.github/skills/hve-core/git-merge`                                                      |
| Invocation  | Invoked directly as `/git-merge`; model invocation is disabled, so agents do not load it |
| Interactive | No                                                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coordinate Git merge, rebase, and rebase --onto workflows with conflict resolution, optional review pauses, and a completion summary. Use when integrating a branch locally and resolving conflicts without pushing.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `git-merge` to run a merge, rebase, or `rebase --onto` locally with explicit conflict handling and a summary of every resolution. Use ordinary Git inspection when you only need to compare branches or read history, and use `pull-request` once the integrated branch is ready for review.

## How to use it

Choose the `operation`, name the `branch`, and add `onto` and `upstream` for `rebase-onto`. Set `conflict-stop=true` when you want to review each set of conflict fixes before the operation continues. The skill stashes local changes first, restores them at the end, and never pushes.

## Example usage

```text
/git-merge operation=rebase branch=origin/main conflict-stop=true
```

The skill rebases the current branch onto `origin/main`, pauses after each set of conflict fixes for your confirmation, and finishes with a summary of the resolutions and a reminder to publish the branch yourself.
