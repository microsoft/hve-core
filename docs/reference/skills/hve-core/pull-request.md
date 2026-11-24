---
title: pull-request
description: "Prepare, create, or update a GitHub pull request with targeted preflight, repair commits, scoped push consent, and separate PR-write approval. Route Azure DevOps to backlog-management."
sidebar_position: 8
author: Microsoft
ms.date: 2026-10-20
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
Prepare, create, or update a GitHub pull request with targeted preflight, repair commits, scoped push consent, and separate PR-write approval. Route Azure DevOps to backlog-management.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a branch is ready for a concise pull request description, targeted preflight
checks, or GitHub pull request creation. Use the code review workflow when an existing pull request
needs correctness, security, or standards assessment instead of authoring. When you ask the skill to
repair a local preflight failure, it reruns the affected checks and commits only that repair under the
repository's commit-message rules. Existing working-tree changes remain unstaged.

When the push remote is on Azure DevOps, the skill follows the `backlog-management` pull request
protocol and maps `base` and `draft` to that protocol's `baseBranch` and `isDraft` inputs.
`action=prepare` writes only the local description, `action=create` runs the full protocol with its
destination and approval gates, and `action=update` stops because updating an existing Azure DevOps
pull request is not supported.

## Example usage

```text
/pull-request base=origin/main action=prepare
```

The skill compares the current branch with the local base ref, applies the repository template,
writes `.copilot-tracking/pr/pr.md`, and runs focused checks for the changed areas. Set
`action=create` to prepare for final PR-write approval. A needed ordinary push requires its own
consent; an explicit request or approval for that same push is reused, not requested again.
Push consent does not approve opening or updating the PR. If a required push fails or cannot run,
the dependent PR write stops with the actual result or restriction.

If you ask it to fix a reported failure, the skill validates and commits the isolated repair,
refreshes the pull request context, and includes the new commit in the final approval summary.

For example, after approving an identified ordinary push, you can still leave the prepared PR
unpublished. The remaining approval is for the PR write alone, not another approval of that push.
