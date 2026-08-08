---
title: Task Planning Workflow
description: Retrieve your assigned work and enrich it into an implementation-ready handoff
author: Microsoft
ms.date: 2026-08-06
ms.topic: tutorial
keywords:
  - backlog management
  - task planning
  - my work
  - prioritization
  - github copilot
estimated_reading_time: 4
sidebar_position: 5
---

Task planning turns your assigned work into an ordered, implementation-ready plan. It runs in two stages, and the split is deliberate: retrieval is cheap and repeatable, enrichment is expensive and worth reviewing.

Run `/backlog-plan my-work` to retrieve, then `/backlog-plan task-plan` to enrich.

## When to Use

* 🌅 Starting your day and deciding what to pick up
* 🧭 Holding several assigned items and needing an order
* 📋 Turning an assigned item into an implementation plan

## Stage 1: Retrieve

Retrieval queries the tracker for work assigned to you, captures each item's current field values, and writes them to a planning file. Re-running retrieval refreshes the file without discarding enrichment already recorded against items that still exist.

## Stage 2: Enrich

Enrichment reads the retrieved set and builds an implementation handoff:

1. Hydrates each item with full field values and its comment history
2. Establishes parent and child context so an item is not planned in isolation
3. Orders items by priority, state, blocking relationships, and iteration proximity
4. Selects a top recommendation and records why it ranks first
5. Writes an implementation-ready handoff

Comment history is retained rather than summarized away. A decision recorded in a comment three weeks ago is frequently the reason an item is shaped the way it is.

## Platform Differences

| Aspect            | Azure DevOps                       | GitHub                 | Jira                           |
|-------------------|------------------------------------|------------------------|--------------------------------|
| Assignment query  | `wit_my_work_items`                | `assignee:@me`         | JQL `assignee = currentUser()` |
| Hydration         | **Required batch follow-up**       | Included in issue read | Included in issue read         |
| Comment retrieval | Work item comments API             | Issue comments         | Issue comments                 |
| Ordering inputs   | Priority, Severity, Iteration Path | Labels, Milestone      | Priority, Sprint, Rank         |

> [!NOTE]
> Azure DevOps returns identifiers from the assignment query and requires a second batched call for field values. The other platforms return fields in the initial read.

## Output Artifacts

```text
<tracking-root>/task-planning/<scope-name>/
├── planning-log.md      # Retrieval results and phase tracking
├── enriched-items.md    # Hydrated items with context and comment history
└── handoff.md           # Ordered plan with the top recommendation and reasoning
```

## Next Steps

* [Sprint Planning](sprint-planning.md): See how your slice fits the wider iteration
* [Using Workflows Together](using-together.md): End-to-end pipeline walkthrough

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
