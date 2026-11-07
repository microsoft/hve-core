---
title: code-review
description: "Review a PR, branch comparison, commit, local changes, or selected code using shared evidence and focused perspectives, with an optional Code Review canvas."
sidebar_position: 9
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                         |
|-------------|-------------------------------------------------------------------------------|
| Kind        | skill                                                                         |
| Source      | `.github/skills/coding-standards/code-review`                                 |
| Invocation  | Invoked directly as `/code-review`, or loaded on demand by referencing agents |
| Interactive | No                                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review a PR, branch comparison, commit, local changes, or selected code using shared evidence and focused perspectives, with an optional Code Review canvas.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to review a PR or MR, a named branch comparison, a commit, staged or unstaged local changes, or selected code. Run it as `/code-review` or through the Code Review agent.
A clear request runs as a sweep: Code Review shows a compact scope summary and continues. Add `mode=guided` to choose areas, perspectives, or depth at each decision point.

The `standard` profile selects functional, standards, and readiness, and adds accessibility or security when the change touches those surfaces. `full` runs all five perspectives, and `custom` runs the ones you name. Depth (`basic`, `standard`, or `comprehensive`) is a separate choice that sets how far each perspective traces the change.

Each review captures one immutable snapshot. Small or tightly coupled work runs inline, and independent work goes to parallel workers that return the shared result contract with coverage. When the Code Review canvas is available, Code Review opens it to show coverage and findings and to collect your feedback; the review works the same without it.
Review keeps source and Git state read-only. Fix accepted findings in an implementation workflow, and expect Code Review to ask for your explicit consent before it stages or posts anything to a PR.

## Example usage

Run `/code-review feature/search compared with main profile=full` and describe what the change should do. Code Review resolves both revisions, captures the snapshot, shows the scope summary, and reviews with all five perspectives at `standard` depth.
Expect a `review.md` under `.copilot-tracking/reviews/code-reviews/<date>/<review-id>/` that leads with findings and their consequences, reports execution and outcome separately, and lists incomplete coverage and limitations.

For local changes, say whether to review staged, unstaged, or combined changes. A successful review is a traceable report with explicit coverage limits. It still needs your review before you act on it, and it doesn't claim tests passed unless their results were captured.
