---
title: rpi-plan
description: Create or resume an evidence-based RPI implementation plan with an optional independent critique. Use when a task needs an implementation plan or an existing plan needs revision.
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-28
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
Create or resume an evidence-based RPI implementation plan with an optional independent critique. Use when a task needs an implementation plan or an existing plan needs revision.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-plan` when adequate evidence exists and the work needs a sequenced, verifiable plan before implementation. The skill writes one plan under `.copilot-tracking/plans/` with a stable task ID, `Pxx` phases, and `Pxx-Txx` tasks. The plan leads with an executive summary and a diagrammed Phase Checklist; each task carries `Goals:`, `Requirements:`, `Details:`, `References:`, and `Dependencies:` blocks.

The Phase Checklist opens with **Before** and **After** Mermaid diagrams comparing the
evidence-backed starting state with the intended result of all phases. Each phase highlights its
changes within the After view, including labeled removal context when needed. Diagrams inherit the
renderer's light or dark theme, use readable sans-serif labels, and pair custom highlight fills
with explicit contrasting text colors.

Planning owns two internal steps. It activates [rpi-research](rpi-research) only for a demonstrated
readiness gap, and runs [rpi-plan-critique](rpi-plan-critique) by default once the plan is
implementation-ready. You can skip the critique; the planner records it as skipped rather than
failed. A follow-up critique after corrections is optional, and the planner runs one when
corrections substantially change requirements, scope, or architecture, or when you ask. Confirmed
user direction outranks critique advice.

The planner drafts every phase itself. Before drafting, it looks for skills and subagents whose descriptions say they are used during planning or with `rpi-plan` and follows each description's guidance on when and how to use it; no subagent is required.

One input shapes the critique:

| Input      | Values                               | Effect                                                                                            |
|------------|--------------------------------------|---------------------------------------------------------------------------------------------------|
| `critique` | `standard` (default), `deep`, `skip` | How broadly the critique traces evidence; `deep` requires an explicit request and `skip` omits it |

Reach for a different asset when:

* Evidence is missing or contradictory. Run [rpi-research](rpi-research) first.
* The plan already exists and is approved. Run [rpi-implement](rpi-implement).
* You only want an independent read of an existing plan. Run [rpi-plan-critique](rpi-plan-critique) directly.

## Example usage

### Create a plan

```text
/rpi-plan task=blob-storage research=.copilot-tracking/research/2026-09-04/blob-storage-research.md
```

The skill sends one `RPI Plan` opening with the interpreted goal, starting evidence, and decision state, drafts the phases, adds the Phase Checklist diagrams, and runs the critique once the plan is ready. Its final response summarizes readiness rather than restating the plan:

```text
* Planning execution: Complete; Planning Readiness: Ready
* Critique: standard, Revise; PC-001 (Medium) corrected in P02-T02 Requirements
* Decisions: managed identity for production confirmed; connection string limited to local development

| Artifact                                                                                                                                             | Description          |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|
| [.copilot-tracking/plans/2026-09-04/blob-storage-plan.md](.copilot-tracking/plans/2026-09-04/blob-storage-plan.md)                                   | Task-centered plan   |
| [.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md](.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md) | Independent critique |

## Next Steps

Run `/rpi-implement plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md`.
```

Inside an automatic `RPI Agent` session the parent continues to Implement without waiting for that command.

### Skip the critique

```text
/rpi-plan task=blob-storage research=.copilot-tracking/research/2026-09-04/blob-storage-research.md critique=skip
```

The planner finalizes the plan without running `rpi-plan-critique` and records the critique as skipped in Critique Disposition. You can also ask to skip the critique at any point during planning, or move straight to `/rpi-implement`; implementation does not require a critique.

### Resume an interrupted critique

Critique Disposition records the critique status. If a session ends while the status is `started` and no critique result was saved, resume the task through `rpi-plan` and the critique runs again. A saved result is reused as is. A critique that returned no result never counts as a pass: the planner reruns it once the cause is resolved, or continues without it when you say so.
