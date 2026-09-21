---
title: pr-reference
description: "Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries."
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-09
ms.topic: reference
keywords:
  - skill
  - shared
  - pr-reference
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | skill                                                                          |
| Source      | `.github/skills/shared/pr-reference`                                           |
| Invocation  | Invoked directly as `/pr-reference`, or loaded on demand by referencing agents |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Generates PR reference XML with commit history and unified diffs between branches, with extension and path filtering. Use when creating pull request descriptions, preparing code reviews, analyzing branch changes, discovering work items from diffs, or generating structured diff summaries.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to prepare structured commit history and unified diffs for a PR
description, code review, or work-item analysis. It needs Git and commits diverging
from the chosen base; it does not create a PR or assess the changes itself.
Choose an explicit base and filters so the resulting evidence matches the review
scope. PowerShell and Bash entry points are available.

## Example usage

Ask: `/pr-reference Generate XML for this feature branch against origin/main using
the merge base. Exclude png and jpg diffs; keep source and Markdown changes. Save
to a confirmed local review output path.` The branch and base must exist locally.

On Windows, the expected flow uses `scripts/generate.ps1` inside the skill with
`-BaseBranch origin/main`, `-MergeBase`, `-ExcludeExt png,jpg`, and the selected
`-OutputPath`. Success is a linked XML file containing commit metadata and the
bounded diff, not a published PR. The list-changed-files and read-diff helpers can
then extract paths or chunks for a consumer without loading the whole diff.

An empty comparison or missing base is a prerequisite issue to resolve, not a
successful review. Inspect generated diffs for sensitive content before sharing
them; excluding an extension is a scope filter, not a secret-sanitization guarantee.
