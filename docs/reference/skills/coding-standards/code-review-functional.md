---
title: code-review-functional
description: Review assigned snapshot evidence for behavioral defects and regressions. Use for the functional perspective of Code Review.
sidebar_position: 4
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-functional
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | skill                                                    |
| Source      | `.github/skills/coding-standards/code-review-functional` |
| Invocation  | Loaded on demand by referencing agents                   |
| Interactive | No                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned snapshot evidence for behavioral defects and regressions. Use for the functional perspective of Code Review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill for the functional perspective, inline for small or tightly coupled work or through the Code Review Functional subagent. It looks for changed behavior that breaks an intended contract or causes a regression.
At the assigned depth, it traces the callers and callees needed to check success and failure paths, boundary inputs, concurrency, resource ownership, persistence, and compatibility. When Code Review assigns acceptance criteria to it, the skill records each one as Implemented, Partial, Not found, or Not assessed.

General style belongs to the standards perspective, and PR deliverable metadata belongs to readiness.

## Example usage

Code Review assigns the hunks that change a retry loop in `src/importer/client.ts` at `standard` depth, with the result path for that work item. The skill traces the loop's callers and error paths, reads the existing tests, and reports a finding if a timeout now escapes the retry limit, anchored to the changed lines with its consequence and a remediation.
The result also lists the covered files and hunks and notes any tests whose results weren't available.
