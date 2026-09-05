---
title: Pr Review
description: Review a pull request or local change set by routing to the consolidated Code Review agent
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-02
ms.topic: reference
keywords:
  - prompt
  - hve-core
  - pr-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                          |
|-------------|------------------------------------------------|
| Kind        | prompt                                         |
| Source      | `.github/prompts/hve-core/pr-review.prompt.md` |
| Invocation  | Slash command `/pr-review`                     |
| Interactive | Yes                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review a pull request or local change set by routing to the consolidated Code Review agent
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this prompt for a structured review of a pull request or local change set across applicable code-review perspectives. Use a focused explanation request when you only need help understanding one symbol or change.

## How to use it

Provide a pull request number or a base and head range, then optionally narrow the review `scope`. The prompt routes the boundary to the consolidated Code Review agent and keeps any external review submission human-gated.

## Example usage

```text
/pr-review pr=123 scope="docs/reference/prompts"
```

The prompt reviews the sample pull request with emphasis on the prompt reference documentation boundary.
