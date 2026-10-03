---
title: rpi-plan-critique
description: Independently assess an RPI plan without editing it. Use when an implementation-ready plan needs a credibility check or a revised plan needs its earlier findings reconciled.
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-28
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
Independently assess an RPI plan without editing it. Use when an implementation-ready plan needs a credibility check or a revised plan needs its earlier findings reconciled.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`rpi-plan-critique` is the optional readiness check inside planning. [rpi-plan](rpi-plan) runs it by
default once the plan is implementation-ready, unless you skip it, and the critique writes its
assigned artifact under `.copilot-tracking/reviews/plans/` without editing the plan. A run that
produces no assessment has no verdict and never counts as a pass.

You can also invoke it directly for an independent, evidence-bounded read of an existing plan; it
needs no planning parent. A `Pass`, `Revise`, or `Blocked` verdict is advisory: confirmed user
direction outranks critique advice, and a `Revise` verdict means the planner revises the plan or
asks for a decision.

After corrections, a follow-up critique is optional. When one runs, it receives the earlier
critique, marks each earlier finding resolved, still open, or superseded, and adds findings only for
new gaps. It writes to a numbered output path, such as `blob-storage-plan-critique-2.md`, so earlier
critiques stay intact.

The critique considers requirements across the supplied plan. Tasks need not repeat established requirements solely for restatement, and an abbreviated excerpt does not prove the full plan omits a detail. Explicitly missing tests, conflicting task instructions and material evidence gaps still warrant findings; stating a requirement does not by itself prove implementation coverage.

| Depth      | When                       | Behavior                                                                                        |
|------------|----------------------------|-------------------------------------------------------------------------------------------------|
| `standard` | Default                    | Assesses the complete supplied boundary once, prioritizing blockers and omitting cosmetic notes |
| `deep`     | Explicit user request only | Traces evidence more broadly and includes substantive lower-severity concerns                   |

Reach for a different asset when:

* The plan does not exist yet. Run [rpi-plan](rpi-plan), which runs the critique for you unless you skip it.
* A critique already exists for the task. Revise the plan from its findings through [rpi-plan](rpi-plan), which decides whether a follow-up critique is warranted.
* You want to assess implementation rather than the plan. Run [rpi-review](rpi-review).

## Example usage

```text
/rpi-plan-critique plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md output=.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md depth=standard
```

The critique writes the artifact and returns a compact verdict:

```text
* Critique execution: Complete; depth standard (default)
* Verdict: Revise
* Findings: 1 High, 1 Medium, 0 Low
* Highest impact: PC-001 [High] P02-T02 specifies unbounded retries, contradicting NFR-002's three-attempt limit
* Action owner: planning parent; smallest next action: align P02-T02 with the confirmed limit
* User response required: no

## Next Steps

Apply the correction in the plan through `/rpi-plan`.
```

To re-check a revised plan against earlier findings, pass the earlier critique and a numbered output path:

```text
/rpi-plan-critique plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md prior=.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md output=.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique-2.md
```
