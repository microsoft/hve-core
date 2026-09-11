---
title: rpi-plan
description: "Create one evidence-based RPI implementation plan from supplied context, research, drafts, and decisions. Use when implementation planning is needed."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-11
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

The Phase Checklist opens with **Before** and **After** Mermaid diagrams comparing the evidence-backed starting state with the intended result of all phases. Each phase highlights its changes within the After view, including labeled removal context when needed. Diagrams inherit the renderer's light or dark theme, use readable sans-serif labels, and pair custom highlight fills with explicit contrasting text colors.

Planning owns two internal gates. It activates [rpi-research](rpi-research) only for a demonstrated readiness gap, and it runs [rpi-plan-critique](rpi-plan-critique) at most once, after the planner judges the plan implementation-ready. Confirmed user direction outranks critique advice.

The planner drafts every phase itself. Before drafting, it looks for skills and subagents whose descriptions say they are used during planning or with `rpi-plan` and follows each description's guidance on when and how to use it; no subagent is required.

One input shapes how the critique is done:

| Input      | Values                       | Effect                                                                               |
|------------|------------------------------|--------------------------------------------------------------------------------------|
| `critique` | `standard` (default), `deep` | How broadly the single critique traces evidence; `deep` requires an explicit request |

Reach for a different asset when:

* Evidence is missing or contradictory. Run [rpi-research](rpi-research) first.
* The plan already exists and is approved. Run [rpi-implement](rpi-implement).
* You only want an independent read of an existing plan. Run [rpi-plan-critique](rpi-plan-critique) directly.

## Example usage

```text
/rpi-plan task=blob-storage research=.copilot-tracking/research/2026-09-04/blob-storage-research.md
```

The skill sends one `RPI Plan` opening with the interpreted goal, starting evidence, and decision state, drafts the phases, adds the Phase Checklist diagrams, and runs the critique once the plan is ready. Its final response summarizes readiness rather than restating the plan:

```text
* Planning execution: Complete; Planning Readiness: Ready
* Critique: standard, verdict Pass; PC-001 (Medium) resolved by adding the retry test to P02-T02 Requirements
* Decisions: managed identity for production confirmed; connection string limited to local development

| Artifact                                                                                                                                             | Description          |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|
| [.copilot-tracking/plans/2026-09-04/blob-storage-plan.md](.copilot-tracking/plans/2026-09-04/blob-storage-plan.md)                                   | Task-centered plan   |
| [.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md](.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md) | Independent critique |

## Next Steps

Run `/rpi-implement plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md`.
```

Inside an automatic `RPI Agent` session the parent continues to Implement without waiting for that command.
