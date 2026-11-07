---
title: Code Review Walkback
description: Resolve a bounded evidence gap for Code Review and return findings candidates as factual observations.
sidebar_position: 8
author: Microsoft
ms.date: 2026-11-06
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-walkback
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                     |
|-------------|---------------------------------------------------------------------------|
| Kind        | agent                                                                     |
| Source      | `.github/agents/coding-standards/subagents/code-review-walkback.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)  |
| Interactive | No                                                                        |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Resolve a bounded evidence gap for Code Review and return findings candidates as factual observations.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches Walkback for one bounded question that its review evidence doesn't answer yet. It preloads `code-review-core` and `code-review-investigation`, reuses captured evidence, and follows the missing call path, contract, or dependency directly. It can run alongside unrelated review work.
When the question becomes an open research problem, the worker stops and recommends full RPI research to Code Review. It doesn't start nested work.

## Example usage

The parent supplies the snapshot, prior observations, the question "Does every new caller pass the cancellation token?", a success condition, and the result path. The worker writes a shared result with `findings: []` and observations that cite each caller, the counter-evidence it checked, and any unresolved gap.
A dropped token comes back as an observation for Code Review to verify and grade under the functional perspective.
