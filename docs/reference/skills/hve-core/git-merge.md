---
title: git-merge
description: "Integrate branches with merge or rebase, resolve conflicts, and execute an ordinary push when explicitly authorized. Use for guided integration with optional conflict-review pauses."
sidebar_position: 5
author: Microsoft
ms.date: 2026-10-20
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
Integrate branches with merge or rebase, resolve conflicts, and execute an ordinary push when explicitly authorized. Use for guided integration with optional conflict-review pauses.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `git-merge` to run a merge, rebase, or `rebase --onto` locally with explicit conflict handling and a summary of every resolution. Use ordinary Git inspection when you only need to compare branches or read history, and use `pull-request` once the integrated branch is ready for review.

## How to use it

Choose the `operation`, name the `branch`, and add `onto` and `upstream` for `rebase-onto`.
Set `conflict-stop=true` to review conflict fixes before continuing. The skill stashes local changes
first and restores them at the end. Integration remains local unless you explicitly request or
approve an ordinary branch push. That consent is reused for the same action, including the
requested integration result. A rejected normal push does not authorize force-pushing.

## Example usage

```text
/git-merge operation=rebase branch=origin/main conflict-stop=true
```

The skill rebases the current branch onto `origin/main`, pauses for conflict review, and summarizes
the resolutions. No push is authorized by this merge/rebase request alone.

```text
/git-merge operation=merge branch=origin/main
After integrating, push this feature branch to its established origin upstream.
```

The second request includes ordinary-push consent for the expected integration result. When the
destination is settled, no repeated push approval is needed. The summary distinguishes local
completion, successful publication, an already-current ref, and a failed or unattempted push.
