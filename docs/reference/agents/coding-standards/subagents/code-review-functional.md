---
title: Code Review Functional
description: Review assigned snapshot evidence for behavioral defects and return the shared worker result.
sidebar_position: 3
author: Microsoft
ms.date: 2026-11-06
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
Review assigned snapshot evidence for behavioral defects and return the shared worker result.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this worker for the functional perspective when that work runs independently in parallel. It preloads `code-review-core` and `code-review-functional` to find behavioral defects and regressions in the assigned hunks and to record acceptance-criteria coverage when Code Review assigns it. Naming and formatting stay with the standards perspective.

## Example usage

For a retry-loop change, the parent supplies the work item, assigned files and hunks, depth and rationale, applicable acceptance criteria, available validation, and the result path. The worker writes a shared result with anchored findings, each with its consequence and a remediation, plus the covered files and hunks, observations, and limitations.
It returns the path, execution status, and remaining gaps without editing the implementation or reporting cosmetic preferences as defects.
