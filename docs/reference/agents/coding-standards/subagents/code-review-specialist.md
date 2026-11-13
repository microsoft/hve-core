---
title: Code Review Specialist
description: Review assigned changes through one added non-functional lens and return the shared worker result.
sidebar_position: 7
author: Microsoft
ms.date: 2026-11-09
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-specialist
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                       |
|-------------|-----------------------------------------------------------------------------|
| Kind        | agent                                                                       |
| Source      | `.github/agents/coding-standards/subagents/code-review-specialist.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)    |
| Interactive | No                                                                          |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Review assigned changes through one added non-functional lens and return the shared worker result.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this worker for an added non-functional reviewer: privacy, performance, supply chain, or responsible AI. It preloads `code-review-core` and `code-review-specialist` and reviews only its assignment, through the lens the dispatch names. For a standalone audit, use the deeper reviewer the skill names; this worker doesn't start one.

## Example usage

When a reviewer adds Privacy from the Code Review canvas, the parent schedules a privacy work item for each area and dispatches this worker with the lens, the assigned hunks, depth, and the result path. The worker checks how changed code collects, logs, stores, or keeps personal data against `privacy-by-design`, describes any personal data by type, and writes findings anchored to the changed lines.
It returns the path, execution status, and unresolved evidence, and it doesn't alter source.
