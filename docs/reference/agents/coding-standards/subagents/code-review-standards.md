---
title: Code Review Standards
description: Thin skill-backed perspective subagent that reviews a precomputed diff against project coding standards and writes structured findings
sidebar_position: 7
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-standards
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/coding-standards/subagents/code-review-standards.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)   |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Thin skill-backed perspective subagent that reviews a precomputed diff against project coding standards and writes structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Standards to check a precomputed diff against applicable coding-standards skills. Findings must trace to a loaded skill, not the worker's stylistic preferences. Functional correctness stays with the Functional perspective; users invoke Code Review rather than this worker directly.

## Example usage

The parent supplies changed extensions and files, depth, exclusions, the diff, and `task.outputs.standards`. The worker loads matching skills, records each finding's skill provenance, and writes JSON results. If no skill matches, it returns the normal empty findings structure with the coverage limitation instead of inventing project rules.
