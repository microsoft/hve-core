---
title: pull-request
description: "Prepare, create, update, or sync a GitHub pull request with targeted local checks and repair commits. Supports optional stacked pull requests through the gh stack extension. Routes Azure DevOps to backlog-management."
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-12
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
Prepare, create, update, or sync a GitHub pull request with targeted local checks and repair commits. Supports optional stacked pull requests through the gh stack extension. Routes Azure DevOps to backlog-management.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill when a branch is ready for a pull request. It writes a short description from the repository template, runs focused local checks for the changed areas, and can create, update, or sync the pull request on GitHub. Use the code review workflow instead when an existing pull request needs a correctness, security, or standards review.

The skill publishes only when you ask. A clear request such as `action=create`, `action=update`, `action=sync`, or "push this and open a pull request" runs without a confirmation prompt. When the request is unclear, the skill writes the description and asks one question that lists each branch it would push, the title, the target branch, and the draft state.

`action=prepare` never publishes. A failed local check, sensitive text the skill can't remove, or a branch that has diverged from its copy on GitHub stops the run before anything is published. A branch that is only behind its GitHub copy also stops a create or update, while a sync brings it up to date.

When you ask it to fix a failed check, the skill reruns the affected checks and commits only that fix under the repository's commit conventions. Your other working-tree changes stay unstaged.

If you use the `gh stack` extension, the skill detects when the checked-out branch belongs to a stack. In a stack, it writes one description per branch that covers only that branch's changes.

A create in a stack opens pull requests for your branch and the branches below it that don't have one yet, using `gh stack link`, and opens none above yours. If a branch in scope is behind its GitHub copy or needs a rebase, the create syncs the stack first; if one was rewritten locally, it pushes the stack with `gh stack push` first. Ask for the whole stack to use `gh stack submit --auto` instead. Updates push the stack with `gh stack push`, and syncs use `gh stack sync`.

Before any push in a stack, the skill fetches each branch and stops before a push would drop commits that exist only on GitHub, so a collaborator's work isn't overwritten. It also asks first when a run would push stack branches you didn't mention.

Stacks stay optional. Without the extension, or with `stack=off`, the skill uses the ordinary flow. The skill doesn't create or reshape stacks; use `gh stack init` or the gh-stack agent skill for that.

When the push remote is on Azure DevOps, the skill follows the `backlog-management` pull request steps and maps `base` and `draft` to `baseBranch` and `isDraft`. `action=prepare` writes only the local description, `action=create` runs the full Azure DevOps steps with their own approvals, and `action=update` and `action=sync` stop because Azure DevOps doesn't support them here.

## Example usage

```text
/pull-request base=origin/main action=prepare
```

The skill compares the current branch with the local base ref, applies the repository template, writes `.copilot-tracking/pr/pr.md`, and runs focused checks for the changed areas. Nothing is pushed or published.

```text
/pull-request action=create draft=true
```

The skill writes the description, runs the checks, pushes the branch when it needs a push, and opens a draft pull request.

```text
/pull-request action=sync
```

On an ordinary branch with an open pull request, the skill runs `gh pr update-branch` to bring the pull request up to date with its base, then fast-forwards your local branch, even when it was behind its GitHub copy. On a stacked branch, it runs `gh stack sync`, which rebases each branch onto its updated parent and pushes the stack. A sync doesn't write a description or run local checks.
