---
title: pull-request
description: "Drafts or opens a GitHub pull request, runs changed-area preflight checks, and commits validated preflight repairs. Use when a user asks to prepare, create, or update a pull request."
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - skill
  - hve-core
  - pull-request
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | skill                                                                          |
| Source      | `.github/skills/hve-core/pull-request`                                         |
| Invocation  | Invoked directly as `/pull-request`, or loaded on demand by referencing agents |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Drafts or opens a GitHub pull request, runs changed-area preflight checks, and commits validated preflight repairs. Use when a user asks to prepare, create, or update a pull request.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a branch is ready for a concise pull request description, targeted preflight
checks, or GitHub pull request creation. Use the code review workflow when an existing pull request
needs correctness, security, or standards assessment instead of authoring. When you ask the skill to
repair a local preflight failure, it reruns the affected checks and commits only that repair under the
repository's commit-message rules. Existing working-tree changes remain unstaged.

## Example usage

```text
/pull-request base=origin/main action=prepare
```

The skill compares the current branch with the local base ref, applies the repository template,
writes `.copilot-tracking/pr/pr.md`, and runs focused checks for the changed areas. Set
`action=create` to request one final approval before the branch is pushed and the GitHub pull request
is opened. If you ask it to fix a reported failure, the skill validates and commits the isolated
repair, refreshes the pull request context, and includes the new commit in the final approval summary.
