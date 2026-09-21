---
title: System Architecture Reviewer
description: "System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment"
sidebar_position: 8
author: Microsoft
ms.date: 2026-08-12
ms.topic: reference
keywords:
  - agent
  - project-planning
  - system-architecture-reviewer
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                   |
|-------------|-------------------------------------------------------------------------|
| Kind        | agent                                                                   |
| Source      | `.github/agents/project-planning/system-architecture-reviewer.agent.md` |
| Invocation  | Selected from the chat agent picker as `System Architecture Reviewer`   |
| Interactive | Yes                                                                     |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use System Architecture Reviewer to evaluate a design's tradeoffs against its scale, operating constraints, and business priorities. It selects relevant framework areas rather than applying every pattern. Use ADR Creator when a single decision is already framed and needs a durable record.

## How to use it

1. Select `System Architecture Reviewer` and supply design documents, requirements, existing ADRs, and the concern motivating the review.
2. Clarify scale, team capacity, budget, and operational constraints, then confirm the proposed review scope.
3. Compare the evidenced alternatives, tradeoffs, and recommended decisions; retain unknowns as assumptions to revisit.
4. Review the resulting ADRs and escalation points. Security-specific concerns route to Security Planner instead of being treated as settled by this review.

## Example usage

Ask: "Review `design/reporting.md` for reliability and operational complexity. Compare our batch and queue-based options against the stated scale and support constraints, and capture significant decisions as ADRs."

Expect a scoped design assessment with alternatives, rationale, and documented consequences. Success means recommendations follow confirmed constraints and unresolved decisions are assigned for human judgment.
