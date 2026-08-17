---
title: Data Workstream Coach
description: "Coach a persistent data-science and data-engineering workstream through explicit jobs, durable state, routed skill authority, and safe customer-artifact writes."
sidebar_position: 1
author: Microsoft
ms.date: 2026-08-14
ms.topic: reference
keywords:
  - agent
  - data-science
  - data-workstream-coach
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                          |
|-------------|----------------------------------------------------------------|
| Kind        | agent                                                          |
| Source      | `.github/agents/data-science/data-workstream-coach.agent.md`   |
| Invocation  | Selected from the chat agent picker as `Data Workstream Coach` |
| Interactive | Yes                                                            |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Coach a persistent data-science and data-engineering workstream through explicit jobs, durable state, routed skill authority, and safe customer-artifact writes.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use Data Workstream Coach when a data scientist or data engineer needs one
persistent engagement context across cataloging, feasibility, pipelines,
analysis, experiments, tests, and observability. It is especially useful when
work will pause, detour into another job, or resume in a later session without
losing artifact and gate context.

Select a specialist agent directly when you need only one isolated output, such
as a notebook or dashboard, and do not need workstream state, transitions, or
durable customer-artifact safety gates.

## How to use it

1. Select **Data Workstream Coach** from the agent picker.
2. Provide a kebab-case project slug. The coach creates or resumes the
   project-scoped session state.
3. Choose a job from the offered registry. The coach never selects one
   silently.
4. Confirm any proposed transition. Bounded work is paused with its phase and
   gates, while completed episodic work remains in invocation history.
5. Review the scan result before any durable customer-artifact write.
6. At completion, choose whether to resume paused work, enrich continuous
   catalog context, select another job, or close.

## Example usage

> Start a data workstream for `retail-demand-forecasting`. I need to assess
> feasibility first, but I may need a data model diagram once we understand the
> sources.

The coach initializes or resumes state, displays the data-science disclaimer
when required, asks you to confirm `feasibility`, and records that bounded job.
If you later request the diagram, it proposes pausing feasibility, confirms the
transition to `model-diagram`, runs that episodic job, then offers to resume the
saved feasibility phase rather than advancing automatically.
