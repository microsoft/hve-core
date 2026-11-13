---
title: code-review-investigation
description: Resolve one evidence gap or deeper question about a captured change. Use for bounded Code Review walkbacks without restarting the review.
sidebar_position: 5
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-investigation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                       |
|-------------|-------------------------------------------------------------|
| Kind        | skill                                                       |
| Source      | `.github/skills/coding-standards/code-review-investigation` |
| Invocation  | Loaded on demand by referencing agents                      |
| Interactive | No                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Resolve one evidence gap or deeper question about a captured change. Use for bounded Code Review walkbacks without restarting the review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill, through the Code Review Walkback subagent, for one bounded question that its review evidence doesn't answer yet. The skill reuses captured evidence and follows the missing call path, contract, or dependency directly, without repeating unrelated review work.
It reports what the evidence establishes, the cited locations, counter-evidence, and any remaining gap.

A possible defect comes back as an observation for Code Review to verify and grade in the owning perspective. When the question turns into open-ended research, the skill stops and recommends an `rpi-research` escalation; only an explicit Code Review decision starts that broader workflow.

## Example usage

Code Review asks whether every caller added by the change passes the cancellation token to the retry loop, with the assigned snapshot and a success condition. The skill follows the two new callers and writes a result with `findings: []`.
Its observations show that one caller passes the token and the other drops it, cite both locations, and name anything it couldn't resolve. Code Review then verifies the dropped token and grades it under the functional perspective.
