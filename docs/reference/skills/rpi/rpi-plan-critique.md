---
title: rpi-plan-critique
description: "Independently assess an RPI plan without editing it. Use for an initial critique, revision-bound closure, or planner-authorized recovery including infrastructure retry."
sidebar_position: 3
author: Microsoft
ms.date: 2026-09-24
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
Independently assess an RPI plan without editing it. Use for an initial critique, revision-bound closure, or planner-authorized recovery including infrastructure retry.
<!-- END AUTO-GENERATED: overview -->

## When to use it

`rpi-plan-critique` is the readiness gate inside planning. [rpi-plan](rpi-plan) runs it after the
plan is implementation-ready, and the critique writes its assigned artifact under
`.copilot-tracking/reviews/plans/` without editing the plan. Substantive `Complete`, `Partial` or
`Blocked` assessments cannot be replayed for the same candidate. After a required correction, the
planner preserves the earlier findings and may commission a distinct revision-bound closure for the
new hash. A transport failure with no assessment has no verdict and cannot establish readiness.

The current run may execute its own verified initial, revision-closure, recovery or
infrastructure-retry reservation. A saved `started` record alone does not authorize a replacement
run. Only `rpi-plan` can authorize revision closure of a required correction, the single
initial-attempt generic recovery, or either of the two task-wide infrastructure retries, including
recovery from a failed closure. Recovery requires fresh consent, positive failure evidence,
ended-run proof and evidence reconciliation. The critic cannot authorize retries or reset
counters.

For an unchanged assessment boundary, targeted closure checks the recorded correction delta and
affected requirements against its immediate predecessor and the uninterrupted Complete chain back
to a full assessment. Changes to requirements, architecture, capability, safety or evidence
boundaries require a fresh full assessment. Partial or Blocked coverage cannot be extended by
targeted closure. Implementation remains gated until a Complete result covers the delivered
assessed-content hash and all blocking findings are closed.

After verified infrastructure exhaustion, `rpi-plan` may commission an independent human-authored complete critique with specific consent. Exhausted counts alone do not permit it: active/unknown runs, substantive results for the current candidate and unresolved assessment fragments remain in reconciliation. Earlier assessments for a different candidate remain binding. This skill cannot generate or attest that human report. See [the exhaustion guidance](rpi-plan#when-infrastructure-retries-are-exhausted).

Invoke it directly only when you want an independent, evidence-bounded read of an existing plan and no critique has run for that task yet. A `Pass`, `Revise`, or `Blocked` verdict is advisory: confirmed user direction outranks critique advice, and a `Revise` verdict means the planner revises or asks for a decision before considering revision-bound closure.

The critique considers requirements across the supplied plan. Tasks need not repeat established requirements solely for restatement, and an abbreviated excerpt does not prove the full plan omits a detail. Explicitly missing tests, conflicting task instructions and material evidence gaps still warrant findings; stating a requirement does not by itself prove implementation coverage.

Standalone first use also requires `rpi-plan` for its canonical PowerShell hashing helper and
identity contract. The critic recomputes the saved plan's projection, version and SHA-256 before
reserving or assessing, rather than trusting a caller-reported hash.

Critiques run from `rpi-plan` read the canonical planning reference and helper supplied by the parent,
or locate the available `rpi-plan` skill by name when no pointer is supplied. The skills need not be
sibling directories. An unavailable reference/helper, failed command or unverifiable identity stops
that run without a standalone fallback. An existing standalone reservation still requires planner
reconciliation; installing only the critique skill does not permit a retry.

| Depth      | When                       | Behavior                                                                                        |
|------------|----------------------------|-------------------------------------------------------------------------------------------------|
| `standard` | Default                    | Assesses the complete supplied boundary once, prioritizing blockers and omitting cosmetic notes |
| `deep`     | Explicit user request only | Traces evidence more broadly and includes substantive lower-severity concerns                   |

Reach for a different asset when:

* The plan does not exist yet. Run [rpi-plan](rpi-plan), which runs the critique for you.
* A critique already exists for the task. Revise the plan from its findings through [rpi-plan](rpi-plan); the planner owns any needed revision-bound closure.
* A critique was interrupted and its result is unavailable. Resume the same task with [rpi-plan](rpi-plan#resume-an-interrupted-critique) for evidence reconciliation and recovery eligibility, not a direct standalone rerun.
* You want to assess implementation rather than the plan. Run [rpi-review](rpi-review).

## Example usage

```text
/rpi-plan-critique plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md output=.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md depth=standard
```

The critique first checks the plan's Critique Disposition and the output path; if a critique already ran for the same candidate it returns that result without reassessing. Otherwise it writes the artifact and returns a compact verdict:

```text
* Critique execution: Complete; depth standard (default)
* Verdict: Revise
* Findings: 1 High, 1 Medium, 0 Low
* Highest impact: PC-001 [High] P02-T02 specifies unbounded retries, contradicting NFR-002's three-attempt limit
* Action owner: planning parent; smallest next action: align P02-T02 with the confirmed limit
* User response required: no

## Next Steps

Apply the correction in the plan through `/rpi-plan`; the planner checks whether revision-bound closure is required.
```
