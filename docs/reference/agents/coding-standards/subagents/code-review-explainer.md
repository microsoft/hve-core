---
title: Code Review Explainer
description: Thin skill-backed Register 1 explainer subagent that answers factual symbol or function questions and persists an explanation artifact
sidebar_position: 2
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - coding-standards
  - code-review-explainer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | agent                                                                      |
| Source      | `.github/agents/coding-standards/subagents/code-review-explainer.agent.md` |
| Invocation  | Delegated subagent, dispatched by a parent agent (not selected directly)   |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Thin skill-backed Register 1 explainer subagent that answers factual symbol or function questions and persists an explanation artifact
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this worker for a factual question about a selected board item's symbol or function. It produces an evidence-linked explanation without severity, verdicts, or recommendations. Deeper investigative questions belong to Code Review Walkback; this worker is not a direct picker entry.

## Example usage

The parent supplies the board item, `targetPath`, `targetSymbol`, and the question "How does cancellation reach the importer?" through review state. The worker reads the relevant code, writes an explanation in the assigned review folder, and returns its path with follow-on symbols. If the symbol cannot be resolved, it reports that gap rather than inventing a call path.
