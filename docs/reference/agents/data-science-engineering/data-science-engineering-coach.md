---
title: Data Science and Engineering Coach
description: "Coach a persistent data science and data engineering workstream through explicit jobs, durable state, routed skill authority, and safe customer-artifact writes."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - agent
  - data-science-engineering
  - data-science-engineering-coach
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                             |
|-------------|-----------------------------------------------------------------------------------|
| Kind        | agent                                                                             |
| Source      | `.github/agents/data-science-engineering/data-science-engineering-coach.agent.md` |
| Invocation  | Selected from the chat agent picker as `Data Science and Engineering Coach`       |
| Interactive | Yes                                                                               |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coach a persistent data science and data engineering workstream through explicit jobs, durable state, routed skill authority, and safe customer-artifact writes.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Data Science and Engineering Coach when a data scientist or data engineer needs one
persistent engagement context across cataloging, feasibility, pipelines,
analysis, experiments, tests, and observability. It is especially useful when
work will pause, detour into another job, or resume in a later session without
losing artifact and gate context.

Select a specialist agent directly when you need only one isolated output, such
as a notebook or dashboard, and do not need workstream state, transitions, or
durable customer-artifact safety gates.

## How to use it

1. Select **Data Science and Engineering Coach** from the agent picker.
2. Provide a kebab-case project slug. The coach creates or resumes the
   project-scoped session state.
3. Choose a job from the offered registry. The coach never selects one
   silently.
4. Confirm any proposed transition. Bounded work is paused with its phase and
   gates, while completed episodic work remains in invocation history.
5. Review the scan result before any durable customer-artifact write.
6. At completion, choose whether to resume paused work, enrich continuous
   catalog context, select another job, or close.

## RPI depth matrix and execution loops

The coach can, per job and only on explicit user confirmation, activate a bounded `rpi-research` Research segment for a demonstrated evidence gap, or a full Plan/Implement/Review loop for substantial delivery work.

Bounded Research: When the owning skill identifies an eligible evidence gap, the coach presents the eligible segment with its purpose, expected artifact, expected interaction cost, limits, and direct path. The coach waits for explicit user confirmation before each Research, Plan, Implement, or Review segment; it never changes the active job implicitly.

Substantial Delivery: For substantial delivery work (multi-step code or artifact production), the coach begins Plan only after the owning skill and user accept the domain design. Plan, Implement, and Review use canonical RPI artifacts and return their pointers to the active job's artifact list.

Boundaries: Activating an RPI segment does not change the active job, lifecycle class, owning skill, or durable-write gate. Before every proposed customer-artifact write from direct or RPI execution, the existing durable-write gate is applied. When an RPI segment returns, control returns to the active job without auto-transitioning.

## Example usage

> Start a data workstream for `retail-demand-forecasting`. I need to assess
> feasibility first, but I may need a data model diagram once we understand the
> sources.

The coach initializes or resumes state, displays the data-science disclaimer
when required, asks you to confirm `feasibility`, and records that bounded job.
If you later request the diagram, it proposes pausing feasibility, confirms the
transition to `model-diagram`, runs that episodic job, then offers to resume the
saved feasibility phase rather than advancing automatically.
