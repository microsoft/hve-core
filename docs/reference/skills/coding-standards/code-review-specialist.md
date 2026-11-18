---
title: code-review-specialist
description: "Review assigned changes through one added non-functional lens: privacy, performance, supply chain, or responsible AI. Use for the added reviewers in Code Review."
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-09
ms.topic: reference
keywords:
  - skill
  - coding-standards
  - code-review-specialist
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                    |
|-------------|----------------------------------------------------------|
| Kind        | skill                                                    |
| Source      | `.github/skills/coding-standards/code-review-specialist` |
| Invocation  | Loaded on demand by referencing agents                   |
| Interactive | No                                                       |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned changes through one added non-functional lens: privacy, performance, supply chain, or responsible AI. Use for the added reviewers in Code Review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review uses this skill when a review adds one of four non-functional reviewers that run only on request: privacy, performance, supply chain, or responsible AI. A reviewer is added through a `custom` profile, a request in chat, or the Code Review canvas's Add buttons. The skill reviews the assigned change through that one lens, using the matching HVE skill as its criteria: `privacy-by-design`, the project's stated budgets with `performance-slo-planner`, `supply-chain-security`, or `rai-standards`.

For a full audit beyond the captured change, use the deeper reviewer the skill names: the Privacy Reviewer, the SSSC Reviewer, the RAI Reviewer, or budget and load planning with `performance-slo-planner`. Security and accessibility have their own Code Review skills.

## Example usage

For a change that adds a dependency and a GitHub Actions workflow step, Code Review adds the supply chain reviewer. The skill checks whether the new action is pinned to a commit SHA, whether the workflow's permissions widened, and whether a downloaded tool is checked against a published checksum. It anchors each finding to the changed lines and cites the `supply-chain-security` criterion it relies on.
An area without dependencies or workflows completes as not applicable, with a reason that says what was checked.
