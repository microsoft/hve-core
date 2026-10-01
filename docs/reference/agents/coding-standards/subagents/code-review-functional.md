---
title: Code Review Functional
description: Thin skill-backed perspective subagent that reviews a precomputed diff for functional correctness and writes structured findings
sidebar_position: 3
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-functional
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                       |
|-------------|-----------------------------------------------------------------------------|
| Kind        | agent                                                                       |
| Source      | `.github/agents/coding-standards/subagents/code-review-functional.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)    |
| Interactive | No                                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Thin skill-backed perspective subagent that reviews a precomputed diff for functional correctness and writes structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this perspective for logic, edge cases, error handling, concurrency, and behavioral contracts in a precomputed diff. It leaves naming and formatting rules to the Standards perspective. Users invoke the parent review workflow, not this delegated worker.

## Example usage

For a retry-loop change, the parent supplies a `perspective_batch` task, diff and untracked-file evidence, depth, hotspots, exclusions, and `task.outputs.functional`. The worker returns JSON findings with exact code evidence and suggested fixes, plus severity counts and the output path. It does not modify the implementation or turn cosmetic preferences into functional defects.
