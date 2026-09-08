---
title: rpi-plan-critique
description: Independently critique an RPI implementation plan once against supplied evidence without editing the plan. Use when planning credibility needs a read-only assessment.
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-04
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
Independently critique an RPI implementation plan once against supplied evidence without editing the plan. Use when planning credibility needs a read-only assessment.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`rpi-plan-critique` is the one-time readiness gate inside planning. [rpi-plan](rpi-plan) dispatches it after the planner judges the plan implementation-ready, and the critique writes one artifact under `.copilot-tracking/reviews/plans/` without editing the plan. Any returned status (`Complete`, `Partial`, or `Blocked`) consumes the task's single invocation; the planner disposes every `PC-xxx` finding and finalizes without a second critique.

Invoke it directly only when you want an independent, evidence-bounded read of an existing plan and no critique has run for that task yet. A `Pass`, `Revise`, or `Blocked` verdict is advisory: confirmed user direction outranks critique advice, and a `Revise` verdict means the planner revises or asks for a decision, not that the critique loops.

| Depth      | When                       | Behavior                                                                                        |
|------------|----------------------------|-------------------------------------------------------------------------------------------------|
| `standard` | Default                    | Assesses the complete supplied boundary once, prioritizing blockers and omitting cosmetic notes |
| `deep`     | Explicit user request only | Traces evidence more broadly and includes substantive lower-severity concerns                   |

Reach for a different asset when:

* The plan does not exist yet. Run [rpi-plan](rpi-plan), which runs the critique for you.
* A critique already exists for the task. Revise the plan from its findings rather than requesting another.
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
* Highest impact: PC-001 [High] P02-T02 cites NFR-002 but no task states the retry ceiling it requires
* Action owner: planning parent; smallest next action: add the ceiling to P02-T02 Requirements
* User response required: no

## Next Steps

Apply the correction in the plan through `/rpi-plan`; do not request another critique.
```
