---
title: Hve Core/Git Merge
description: "Git integration and explicit ordinary-push authorization. Use when merging, rebasing, resolving conflicts, or pushing a branch."
sidebar_position: 4
author: Microsoft
ms.date: 2026-10-20
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
Git integration and explicit ordinary-push authorization. Use when merging, rebasing, resolving conflicts, or pushing a branch.
<!-- END AUTO-GENERATED: overview -->

## When to use it

The agent loads these conventions on demand for integration, conflict resolution, or an ordinary
branch push, because the file has a `description` and no `applyTo`. Integration steps cover workspace
preparation, operation commands, conflict rationale, and finishing or aborting. Push-only requests
use the authorization, account-change, and execution-evidence rules without starting integration.
Run `/git-merge` for guided integration with explicit inputs and optional review pauses.

## Example usage

Ask in chat:

```text
Merge origin/main into this branch and resolve the conflicts.
```

The agent loads these conventions, confirms a clean working tree, runs `git merge --no-edit origin/main`,
resolves each conflicted file with a recorded rationale, and finishes with `git status --short` and a
summary. The result remains local because this request does not authorize publishing.

To publish the intended committed branch, explicitly request it:

```text
Push this branch to origin, branch feature/example.
```

When the source and effective destination are clear, that request authorizes the ordinary push
without another approval question. The agent asks only for genuinely missing destination or account
information. It reports what actually ran and whether the ref changed; rejection never authorizes
a force-push or account switch. A requested temporary account switch includes restoring and
verifying the original account, including after failure.
