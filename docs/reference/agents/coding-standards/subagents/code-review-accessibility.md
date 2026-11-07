---
title: Code Review Accessibility
description: Review assigned accessibility evidence and distinguish static findings from runtime method limits.
sidebar_position: 1
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-accessibility
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                          |
|-------------|--------------------------------------------------------------------------------|
| Kind        | agent                                                                          |
| Source      | `.github/agents/coding-standards/subagents/code-review-accessibility.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)       |
| Interactive | No                                                                             |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned accessibility evidence and distinguish static findings from runtime method limits.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this worker for the accessibility perspective when that work runs independently in parallel; small or tightly coupled reviews apply the same skill inline. It preloads `code-review-core` and `code-review-accessibility` and reviews only the assigned change. A broader accessibility audit is a separate follow-up.

## Example usage

For a dialog change, the parent supplies the review root, review and snapshot IDs, the work item, assigned files and hunks, depth, applicable criteria, and the exact result path. The worker writes a shared result with findings that cite the WCAG criterion or ARIA pattern, the files and hunks it covered, and the methods it used.
It returns the result path, its execution status, and method limitations, such as screen reader behavior that source inspection can't prove. It doesn't publish, edit source, or turn a missing runtime check into a conformance claim.
