---
title: architecture-review
description: "Create a durable Architecture Review Record from a confirmed System Architecture Reviewer scope, evidence, pillar analysis, trade-offs, and dispositions"
sidebar_position: 2
author: Microsoft
ms.date: 2026-09-21
ms.topic: reference
keywords:
  - skill
  - project-planning
  - architecture-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                 |
|-------------|-------------------------------------------------------|
| Kind        | skill                                                 |
| Source      | `.github/skills/project-planning/architecture-review` |
| Invocation  | Loaded on demand by referencing agents                |
| Interactive | No                                                    |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create a durable Architecture Review Record from a confirmed System Architecture Reviewer scope, evidence, pillar analysis, trade-offs, and dispositions
<!-- END AUTO-GENERATED: overview -->

## When to use it

System Architecture Reviewer loads this skill after the user confirms review scope. Use it when the review must survive beyond chat and supply evidence to ADR Creation or RPI planning.

The skill records analysis, findings, non-findings, trade-offs, recommendations, and limits. It does not make architecture decisions or replace an ADR. Linked ADRs and their human decision owners remain authoritative for significant decisions.

## Example usage

After confirming reliability and cost as the review focus, System Architecture Reviewer creates:

```text
.copilot-tracking/reviews/architecture/2026-09-21/order-routing-architecture-review.md
```

The record binds the confirmed scope and evidence, documents the finding or non-finding for each focus area, dispositions any Research recommendation, and links significant accepted decisions to their ADRs. The reviewer then passes this record path to ADR Creation or RPI Plan instead of relying on chat history.
