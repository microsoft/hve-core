---
title: code-review
description: "Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output."
sidebar_position: 1
author: Microsoft
ms.date: 2026-09-09
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
Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use this skill to review a PR, an explicit branch comparison, or local changes
across functional, standards, accessibility, security, and readiness perspectives.
It establishes the complete change surface and an orientation before findings.
Use implementation workflows to fix accepted findings; requesting a review alone
does not authorize source edits or publishing comments.

Target, profile, and depth are separate choices. The standard profile recommends
core perspectives plus security/accessibility when signaled; comprehensive depth
increases verification rigor without automatically changing the selected lanes.

## Example usage

Ask: `/code-review Review this checked-out feature branch against origin/main,
with the standard profile. Start with orientation and recommend a depth; keep
source unchanged and do not publish review comments.` Provide the intended change
and available test evidence.

Expect target/head binding, a change brief based on the full diff, a walkthrough,
and independent confirmation of perspectives and depth before the findings sweep.
A useful result ties normalized findings to files and locations, separates
observations from conclusions, and identifies validation gaps and follow-up work.

For local changes, name staged or unstaged scope explicitly rather than implying
a PR exists. A PR review additionally needs the provider-resolved reviewed head
SHA; changed target identity blocks emission until refreshed. Success is a
traceable review with honest coverage limits, not human approval or proof that
unrun tests passed.
