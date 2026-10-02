---
title: Code Review
description: "Code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report with human-gated or explicitly preauthorized emission"
sidebar_position: 1
author: Microsoft
ms.date: 2026-10-02
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                  |
|-------------|--------------------------------------------------------|
| Kind        | agent                                                  |
| Source      | `.github/agents/coding-standards/code-review.agent.md` |
| Invocation  | Selected from the chat agent picker as `Code Review`   |
| Interactive | Yes                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Code review orchestrator that bootstraps change context, scopes hotspots, picks perspectives and depth, and merges skill-backed perspective findings into one report with human-gated or explicitly preauthorized emission
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Code Review for a pull request, an explicit branch comparison, or local working-tree changes when you want to steer the scope and depth of the assessment. It builds a factual orientation before dispatching selected functional, standards, readiness, security, or accessibility perspectives. Use a standalone specialist reviewer for a broader domain audit.

## How to use it

1. Select `Code Review` and identify the PR, base and head references, or local changes. The checked-out HEAD must match a resolved PR or branch target.
2. By default, read the change brief and orientation, then confirm scope, perspectives, and depth. Choosing every perspective does not itself choose a deeper assessment.
3. Bookmark areas to explore or request the selected review sweep. To accept the recommended scope and depth and preauthorize normalized external emission for this invocation, explicitly set `autoApprove=true`; it does not force an `APPROVE` verdict.
4. The agent consolidates evidence-backed findings into a local review draft. Default external submission requires explicit confirmation. Preauthorized submission skips that pause, but both paths require a fresh provider, target, ref, and reviewed-head check.
5. Complete required human-review checkboxes yourself. Invocation preauthorization permits emission but does not claim that a qualified human validated the generated review.

## Example usage

Ask: "Review my local changes to `src/importer` and its tests. Start with an orientation, recommend perspectives and depth, and let me confirm before the sweep. Keep the review local."

Expect a dispatch board followed by a consolidated draft with findings, evidence, limitations, and suggested next actions. Success means the report covers the confirmed change surface and does not publish comments or confuse unchecked areas with reviewed code.
