---
title: Code Review Explainer
description: Answer a factual symbol or area question against captured Code Review evidence.
sidebar_position: 2
author: Microsoft
ms.date: 2026-11-06
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
Answer a factual symbol or area question against captured Code Review evidence.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Code Review dispatches this worker for a factual question about a symbol or area in the captured change. It preloads `code-review-core` and `code-review-context` and follows the skill's question path. Its answer carries no severity, verdict, or recommendation.
A simple explanation that existing evidence covers can stay inline, and a question that needs missing evidence or a deeper judgment goes to Code Review Walkback.

## Example usage

The parent supplies the review and snapshot IDs, the work item, the symbol or area, the question "How does cancellation reach the importer?", and the result path. The worker traces the immediate context and writes a shared result with `findings: []` and observations linked to source evidence.
It returns the path with follow-on symbols. If it can't resolve the symbol, it names the missing evidence and doesn't invent a call path.
