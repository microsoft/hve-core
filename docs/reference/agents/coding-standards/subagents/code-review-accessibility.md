---
title: Code Review Accessibility
description: Thin skill-backed perspective subagent that reviews a precomputed diff for accessibility conformance and writes structured findings
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-12
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
Thin skill-backed perspective subagent that reviews a precomputed diff for accessibility conformance and writes structured findings
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this perspective after the user selects accessibility review. It assesses the supplied diff against loaded accessibility guidance and applicable criteria, not a standalone whole-system audit. Users select Code Review rather than this delegated worker.

## Example usage

The parent supplies a `perspective_batch` task, the serialized diff, changed files, depth, exclusions, and `task.outputs.accessibility` for a dialog change. The worker returns structured accessibility findings traceable to the loaded skill and criterion, or clarification when evidence is insufficient. It does not publish a review, alter source, or replace missing runtime evidence with a conformance claim.
