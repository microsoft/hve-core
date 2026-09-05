---
title: Pull Request
description: Generate pull request descriptions from branch diffs
sidebar_position: 9
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - pull-request
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                             |
|-------------|---------------------------------------------------|
| Kind        | prompt                                            |
| Source      | `.github/prompts/hve-core/pull-request.prompt.md` |
| Invocation  | Slash command `/pull-request`                     |
| Interactive | Yes                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Generate pull request descriptions from branch diffs
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt to generate a pull request description from branch changes and optionally create the pull request. Use the review prompt when a pull request already exists and needs assessment instead of authoring.

## How to use it

Optionally provide the comparison branch and choose whether to exclude Markdown files. Leave `createPullRequest=false` for description-only work; external creation occurs only when explicitly requested and required repository checks pass.

## Example usage

```text
/pull-request branch=origin/main createPullRequest=false
```

The prompt analyzes the branch diff and drafts a pull request description without publishing it.
