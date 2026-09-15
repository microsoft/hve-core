---
title: rpi-plan
description: Create or resume an evidence-based RPI implementation plan. Use for planning from supplied context or reconciling an interrupted planning critique.
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-10
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
Create or resume an evidence-based RPI implementation plan. Use for planning from supplied context or reconciling an interrupted planning critique.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-plan` when adequate evidence exists and the work needs a sequenced, verifiable plan before implementation. The skill writes one plan under `.copilot-tracking/plans/` with a stable task ID, `Pxx` phases, and `Pxx-Txx` tasks. The plan leads with an executive summary and a diagrammed Phase Checklist; each task carries `Goals:`, `Requirements:`, `Details:`, `References:`, and `Dependencies:` blocks.

The Phase Checklist opens with **Before** and **After** Mermaid diagrams comparing the evidence-backed starting state with the intended result of all phases. Each phase highlights its changes within the After view, including labeled removal context when needed. Diagrams inherit the renderer's light or dark theme, use readable sans-serif labels, and pair custom highlight fills with explicit contrasting text colors.

Planning owns two internal gates. It activates [rpi-research](rpi-research) only for a demonstrated readiness gap, and it dispatches an initial [rpi-plan-critique](rpi-plan-critique) after the planner judges the plan implementation-ready. A terminal assessment is not repeated. The only additional attempt is one explicitly confirmed recovery of an interrupted reservation without a terminal result. Confirmed user direction outranks critique advice.

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

### Resume an interrupted critique

If planning reports `started` but no result survived, resume the same task through `rpi-plan`. It checks recorded evidence, confirms the original worker has ended, and verifies the saved plan and state. When eligible, it asks for your approval of one recovery for the identified task and candidate, preserving original records and writing a separate recovery result.

A terminal `Complete`, `Partial`, or `Blocked` result remains binding even if its file is missing. An already-reserved recovery cannot be repeated. Missing evidence is not a pass, and implementation remains gated on an actual assessment and resolved findings.

For example, an editor-visible plan that is absent on disk must be saved or synchronized and verified before recovery. Do not delete the reservation to restart. A reconstructed candidate must be identified and approved as current, not represented as the lost original.

Use a consistently updated workflow before resuming: edits to this checkout do not replace instructions already loaded in a conversation or update an installed plugin snapshot. Start a fresh session with the updated repository workflow, or update the installed distribution you use. Choosing this recovery policy or enabling automatic mode does not authorize a specific task's recovery.

### Create a plan

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
