---
title: code-review-readiness
description: "Review change packaging, validation evidence, PR metadata, and changed documentation. Use for the readiness perspective of Code Review."
sidebar_position: 6
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-readiness
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                   |
|-------------|---------------------------------------------------------|
| Kind        | skill                                                   |
| Source      | `.github/skills/coding-standards/code-review-readiness` |
| Invocation  | Loaded on demand by referencing agents                  |
| Interactive | No                                                      |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review change packaging, validation evidence, PR metadata, and changed documentation. Use for the readiness perspective of Code Review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill for the readiness perspective. It checks whether the change is accurately described and supported by its delivery evidence: the stated purpose against the captured changes, the validation results, the follow-up items, and changed documentation against the implementation.
For a PR or MR with captured metadata, it also checks the description, linked-issue intent, required checklist items, open state, conflicts, merge state, and required checks.

Code correctness, standards, accessibility, and security belong to their own perspectives.

## Example usage

For a PR with an unchecked required checklist item and a required check that's still pending, the skill reports the checklist item as at least Medium, anchored to the captured metadata field and naming the action that clears it.
It treats the pending check as not passing and never checks a human-review box. On a local-changes review, it skips the PR-only checks without inventing a PR.
