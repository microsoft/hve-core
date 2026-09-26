---
title: System Architecture Reviewer
description: "System architecture reviewer for design trade-offs, ADR creation, and well-architected alignment"
sidebar_position: 8
author: Microsoft
ms.date: 2026-09-25
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
3. After scope confirmation, the agent loads the `architecture-review` skill and creates an Architecture Review Record under `.copilot-tracking/reviews/architecture/` before evaluating frameworks.
4. When a recommendation depends on a demonstrated current-service, cost, licensing, compatibility, or prior-art gap, the agent may activate `rpi-research` in convergence mode. It records the resulting evidence and each recommendation's disposition in the review record.
5. Compare the evidenced alternatives, tradeoffs, and recommended decisions; retain unknowns as assumptions to revisit.
6. Review the completed record, resulting ADRs, and escalation points. ADR Creation and RPI Plan handoffs receive the record's workspace-relative path instead of relying on chat context. Security-specific concerns route to Security Planner instead of being treated as settled by this review.

## Example usage

Ask: "Review `design/reporting.md` for reliability and operational complexity. Compare our batch and queue-based options against the stated scale and support constraints, and capture significant decisions as ADRs."

Expect a scoped design assessment with alternatives, rationale, and documented consequences captured progressively in an Architecture Review Record. If current-fact gaps block a recommendation, expect bounded Research with evidence-backed dispositions. Success means recommendations follow confirmed constraints, unresolved decisions are assigned for human judgment, and any ADR Creation or RPI Plan handoff names the completed record path.
