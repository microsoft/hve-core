---
title: Code Review Orientation
description: "Build a factual, evidence-linked area overview for a captured Code Review surface."
sidebar_position: 4
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-orientation
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | agent                                                                        |
| Source      | `.github/agents/coding-standards/subagents/code-review-orientation.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)     |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Build a factual, evidence-linked area overview for a captured Code Review surface.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Orientation to build a factual overview of assigned areas. It can run alongside the review perspectives and never holds them back. It preloads `code-review-core` and `code-review-context` and follows the skill's overview path. It assigns no severity, and its work doesn't count as review coverage.

## Example usage

For an importer change, the parent supplies the review root, snapshot ID, work item, assigned areas, and the result path. The worker groups the surface by responsibility and explains intent, before and after behavior, entry points, data flow, and affected consumers, linking each relationship to source evidence.
It writes a shared result with `findings: []`, and Code Review uses the observations to update area descriptions and impact relationships.
