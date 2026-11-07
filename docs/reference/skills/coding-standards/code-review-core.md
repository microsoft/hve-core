---
title: code-review-core
description: "Shared snapshot, finding, coverage, and result contracts for Code Review and its workers. Use when capturing review evidence, producing worker results, or resuming a review."
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-core
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                              |
|-------------|----------------------------------------------------|
| Kind        | skill                                              |
| Source      | `.github/skills/coding-standards/code-review-core` |
| Invocation  | Loaded on demand by referencing agents             |
| Interactive | No                                                 |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Shared snapshot, finding, coverage, and result contracts for Code Review and its workers. Use when capturing review evidence, producing worker results, or resuming a review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review and its workers load this skill so they share one contract. It defines the review folder, the immutable snapshot, the parent-owned review state, the worker result, finding anchors, coverage, and the outcome rules.
It also ships `scripts/review.mjs`, a Node.js helper that captures snapshots, updates state, merges results, and renders `review.md`. The helper doesn't review code or contact a hosting provider.

Reach for this skill when you capture review evidence, write a worker result, or resume a review. To run a review, use the `code-review` skill, which activates this one.

## Example usage

Code Review captures a branch comparison by running `node scripts/review.mjs capture --repo <repository>` from this skill's installation directory with the request `{ "kind": "branch", "base": "main", "head": "feature/search" }`.
The helper returns the workspace-relative review root, the review and snapshot IDs, and revision `0`. Workers then write their results under `results/<snapshot-id>/`, and `render` writes `review.md`. If you've edited the report since the last render, `render` stops with a `draft_conflict` error and leaves your edits in place.
