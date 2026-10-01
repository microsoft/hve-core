---
title: Code Review Readiness
description: "Reviews pull-request packaging, deliverable readiness, validation evidence, and changed documentation as structured findings"
sidebar_position: 5
author: Microsoft
ms.date: 2026-08-25
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-readiness
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/coding-standards/subagents/code-review-readiness.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)   |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Reviews pull-request packaging, deliverable readiness, validation evidence, and changed documentation as structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Readiness to examine change packaging, validation evidence, follow-ups, and changed documentation. PR-specific checks require supplied PR context; the worker does not infer remote state. Code logic and specialist findings stay with their respective perspectives.

## Example usage

The parent supplies the change brief, diff, full changed guides, optional `prContext`, and `task.outputs.readiness`. The worker checks whether the description and validation claims match the actual change and writes structured findings citing code or specific metadata fields. It returns the output path and coverage summary, never checking human-review boxes or submitting the review itself.
