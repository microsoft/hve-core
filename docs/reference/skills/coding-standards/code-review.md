---
title: code-review
description: "Prioritize functional code review for a PR, branch comparison, commit, local changes, or selected code using one immutable snapshot, parallel general-purpose tasks, vector-tagged findings, strictly opt-in non-functional vectors, and an optional Code Review canvas."
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-17
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
Prioritize functional code review for a PR, branch comparison, commit, local changes, or selected code using one immutable snapshot, parallel general-purpose tasks, vector-tagged findings, strictly opt-in non-functional vectors, and an optional Code Review canvas.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to review a PR or MR, a named branch comparison, a commit, staged or unstaged local changes, or selected code. Run it as `/code-review` or through the Code Review agent.
A clear request runs as a sweep: Code Review shows a compact scope summary and continues. Add `mode=guided` to choose areas, vectors, or depth at each decision point.

Code Review runs functional review by default, covering codebase requirements, code quality and standards, unintended behaviors and side effects, refactored code paths, missed APIs/SDKs, missed abstractions, and unneeded edge-case branches. Non-functional vectors (`security`, `rai`, `sssc`, `performance`, `privacy`, `accessibility`) and BRD/PRD/ADR alignment remain strictly unloaded unless you request them for specific areas or the whole review.

Each review captures one immutable snapshot. Small diffs run inline, and larger multi-area or multi-vector reviews orchestrate parallel `general-purpose` tasks (or report recommended session breakdowns to a Project coordinator). When the Code Review canvas is available, Code Review opens it to display vector-tagged findings and comments and to collect area-scoped reviewer requests and feedback.
Review keeps source and Git state read-only. Fix accepted findings in an implementation workflow, and expect Code Review to ask for your explicit consent before it stages or posts anything to a PR.

## Example usage

Run `/code-review feature/search compared with main` and describe what the change should do. Code Review resolves both revisions, captures the snapshot, runs the functional review at `standard` depth, and leaves non-functional vectors unloaded unless asked.
Expect a `review.md` under `.copilot-tracking/reviews/code-reviews/<date>/<review-id>/` that leads with vector-tagged findings and their consequences, reports execution and outcome separately, and lists incomplete coverage and limitations.

For local changes, say whether to review staged, unstaged, or combined changes. A successful review is a traceable report with explicit coverage limits. It still needs your review before you act on it, and it doesn't claim tests passed unless their results were captured.
