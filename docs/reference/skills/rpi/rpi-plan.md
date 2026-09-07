---
title: rpi-plan
description: "Create one evidence-based RPI implementation plan from supplied context, research, drafts, and decisions. Use when implementation planning is needed."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-04
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-plan
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                      |
|-------------|----------------------------------------------------------------------------|
| Kind        | skill                                                                      |
| Source      | `.github/skills/rpi/rpi-plan`                                              |
| Invocation  | Invoked directly as `/rpi-plan`, or loaded on demand by referencing agents |
| Interactive | No                                                                         |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Create one evidence-based RPI implementation plan from supplied context, research, drafts, and decisions. Use when implementation planning is needed.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-plan` when adequate evidence exists and the work needs a sequenced, verifiable plan before implementation. The skill writes one plan under `.copilot-tracking/plans/` with a stable task ID, `Pxx` phases, and `Pxx-Txx` tasks. The plan leads with an executive summary and a diagrammed Phase Checklist; each task carries `Goals:`, `Requirements:`, `Details:`, `References:`, and `Dependencies:` blocks.

Planning owns two internal gates. It activates [rpi-research](rpi-research) only for a demonstrated readiness gap, and it dispatches [rpi-plan-critique](rpi-plan-critique) at most once, after the planner judges the plan implementation-ready. Confirmed user direction outranks critique advice.

Two inputs shape how the work is done:

| Input        | Values                                  | Effect                                                                                                                                  |
|--------------|-----------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------|
| `delegation` | `adaptive` (default), `never`, `always` | Whether large, independent phases are drafted by a planning subagent such as [RPI Planner](../../agents/hve-core/subagents/rpi-planner) |
| `critique`   | `standard` (default), `deep`            | How broadly the single critique traces evidence; `deep` requires an explicit request                                                    |

Reach for a different asset when:

* Evidence is missing or contradictory. Run [rpi-research](rpi-research) first.
* The plan already exists and is approved. Run [rpi-implement](rpi-implement).
* You only want an independent read of an existing plan. Run [rpi-plan-critique](rpi-plan-critique) directly.

## Example usage

```text
/rpi-plan task=blob-storage research=.copilot-tracking/research/2026-09-04/blob-storage-research.md delegation=adaptive
```

The skill sends one `RPI Plan` opening with the interpreted goal, starting evidence, and decision state, drafts the phases, adds the Phase Checklist diagrams, and dispatches the critique once the plan is ready. Its final response summarizes readiness rather than restating the plan:

```text
* Planning execution: Complete; Planning Readiness: Ready
* Critique: standard, verdict Pass; PC-001 (Medium) resolved by adding the retry test to P02-T02 Requirements
* Decisions: managed identity for production confirmed; connection string limited to local development
* Delegation: adaptive; P02 drafted by RPI Planner, P01 and P03 inline

| Artifact                                                                                                                                             | Description          |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|
| [.copilot-tracking/plans/2026-09-04/blob-storage-plan.md](.copilot-tracking/plans/2026-09-04/blob-storage-plan.md)                                   | Task-centered plan   |
| [.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md](.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md) | Independent critique |

## Next Steps

Run `/rpi-implement plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md`.
```

Inside an automatic `RPI Agent` session the parent continues to Implement without waiting for that command.
