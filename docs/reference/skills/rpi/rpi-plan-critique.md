---
title: rpi-plan-critique
description: Independently assess an RPI plan against supplied evidence without editing it. Use for a current initial or planner-authorized recovery critique dispatch.
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-10
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-plan-critique
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                               |
|-------------|-------------------------------------------------------------------------------------|
| Kind        | skill                                                                               |
| Source      | `.github/skills/rpi/rpi-plan-critique`                                              |
| Invocation  | Invoked directly as `/rpi-plan-critique`, or loaded on demand by referencing agents |
| Interactive | No                                                                                  |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Independently assess an RPI plan against supplied evidence without editing it. Use for a current initial or planner-authorized recovery critique dispatch.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`rpi-plan-critique` is the readiness gate inside planning. [rpi-plan](rpi-plan) dispatches it after the planner judges the plan implementation-ready, and the critique writes its assigned artifact under `.copilot-tracking/reviews/plans/` without editing the plan. Any terminal status (`Complete`, `Partial`, or `Blocked`) consumes the assessment; the planner disposes every `PC-xxx` finding without a closure critique.

The current worker may execute its own verified initial or recovery reservation. A saved `started` record alone does not authorize a replacement worker. Only `rpi-plan` can authorize one task-specific, user-confirmed recovery after an interruption without a terminal result; the critique worker cannot grant that exception or reset a consumed recovery.

Invoke it directly only when you want an independent, evidence-bounded read of an existing plan and no critique has run for that task yet. A `Pass`, `Revise`, or `Blocked` verdict is advisory: confirmed user direction outranks critique advice, and a `Revise` verdict means the planner revises or asks for a decision, not that the critique loops.

The critique considers requirements across the supplied plan. Tasks need not repeat established requirements solely for restatement, and an abbreviated excerpt does not prove the full plan omits a detail. Explicitly missing tests, conflicting task instructions and material evidence gaps still warrant findings; stating a requirement does not by itself prove implementation coverage.

You can install only the complete `rpi-plan-critique` skill for standalone first use; it checks and saves its initial reservation without requiring planner files.

Parent-dispatched critiques instead read the canonical planning reference supplied by the parent, or locate the available `rpi-plan` skill by name when no pointer is supplied. The skills need not be sibling directories. An unavailable parent reference stops that dispatch without a standalone fallback. An existing standalone reservation still requires planner reconciliation; installing only the critique skill does not permit a retry.

| Depth      | When                       | Behavior                                                                                        |
|------------|----------------------------|-------------------------------------------------------------------------------------------------|
| `standard` | Default                    | Assesses the complete supplied boundary once, prioritizing blockers and omitting cosmetic notes |
| `deep`     | Explicit user request only | Traces evidence more broadly and includes substantive lower-severity concerns                   |

Reach for a different asset when:

* The plan does not exist yet. Run [rpi-plan](rpi-plan), which runs the critique for you.
* A critique already exists for the task. Revise the plan from its findings rather than requesting another.
* A critique was interrupted and its result is unavailable. Resume the same task with [rpi-plan](rpi-plan#resume-an-interrupted-critique) for evidence reconciliation and recovery eligibility, not a direct standalone rerun.
* You want to assess implementation rather than the plan. Run [rpi-review](rpi-review).

## Example usage

```text
/rpi-plan-critique plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md output=.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md depth=standard
```

The critique first checks the plan's Critique Disposition and the output path; if a critique already ran it returns that result without reassessing. Otherwise it writes the artifact and returns a compact verdict:

```text
* Critique execution: Complete; depth standard (default)
* Verdict: Revise
* Findings: 1 High, 1 Medium, 0 Low
* Highest impact: PC-001 [High] P02-T02 specifies unbounded retries, contradicting NFR-002's three-attempt limit
* Action owner: planning parent; smallest next action: align P02-T02 with the confirmed limit
* User response required: no

## Next Steps

Apply the correction in the plan through `/rpi-plan`; do not request another critique.
```
