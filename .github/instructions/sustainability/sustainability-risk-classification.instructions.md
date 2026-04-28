---
description: "Sustainability risk classification model — binary/categorical/continuous indicators with tier-up rule for Sustainability Planner."
applyTo: '**/.copilot-tracking/sustainability-plans/**'
---

# Sustainability Risk Classification (Cross-Phase Reference)

This file defines the indicators and tier-up rule the Sustainability Planner uses to choose assessment depth. It is referenced by Phase 2 ([`#file:./sustainability-workload-assessment.instructions.md`](./sustainability-workload-assessment.instructions.md)) for capability sweep depth, by Phase 4 ([`#file:./sustainability-gap-analysis.instructions.md`](./sustainability-gap-analysis.instructions.md)) for prioritization weight, and by Phase 5 ([`#file:./sustainability-backlog.instructions.md`](./sustainability-backlog.instructions.md)) for default work item priority.

The sustainability state schema does not define a dedicated `state.riskClassification` slice. The output of this rule is **informational depth-tier guidance** that flows into Phases 2-5 through the planner's working context; it is not persisted to a separate state field. The triggers and tier the agent decided on are surfaced in `handoff.md` under "Risk classification context" so reviewers can audit the choice.

## Gate Protocol

When entering Phase 2 — and at the start of any later phase the user re-enters via session recovery — the agent evaluates every indicator below in order. The agent records each indicator answer in its working notes (one line per indicator: `indicator-id | result | evidence-pointer`) and uses the [Tier-Up Rule](#tier-up-rule) to assign `risk-tier`.

Indicator answers come from the Phase 1 workload manifest (`state.workloadManifest`). When an indicator cannot be answered from the manifest, the agent asks the user a single batched question covering all unresolved indicators rather than serializing.

## Assessment Method Dispatch

| Indicator class | Method                                                               |
|-----------------|----------------------------------------------------------------------|
| Binary          | Single yes/no answer with evidence pointer.                          |
| Categorical     | Single-select from the surface mix enum.                             |
| Continuous      | Numeric comparison of estimated SCI vs declared per-workload budget. |

## Risk Indicators

### Binary triggers

| Id                     | Trigger                                                                           |
|------------------------|-----------------------------------------------------------------------------------|
| `high-traffic`         | Sustained traffic above 10 requests/second on any web-surface capability.         |
| `always-on`            | Any cloud-surface capability runs 24×7 with no autoscale-to-zero behaviour.       |
| `large-fleet`          | Fleet surface manages ≥ 1000 devices.                                             |
| `ml-training-at-scale` | Any ML training job exceeds 1 GPU-hour OR processes a dataset larger than 100 GB. |

### Categorical indicator

| Id            | Values                                                      |
|---------------|-------------------------------------------------------------|
| `surface-mix` | `cloud-only`, `web-only`, `ml-only`, `fleet-only`, `mixed`. |

`mixed` indicates the workload manifest declares two or more distinct surfaces.

### Continuous indicator

| Id                | Trigger                                                                             |
|-------------------|-------------------------------------------------------------------------------------|
| `sci-over-budget` | Estimated SCI for any workload exceeds that workload's declared SCI budget by ≥25%. |

The `sci-over-budget` evaluation uses the highest-precedence measurement class available per the precedence rule in [`#file:./sustainability-gap-analysis.instructions.md`](./sustainability-gap-analysis.instructions.md). When no SCI estimate exists yet (Phase 2 first pass), the indicator answer is `unknown` and the agent re-evaluates after Phase 4.

## Risk Tiers

| Tier       | Meaning                                                                                 |
|------------|-----------------------------------------------------------------------------------------|
| `standard` | Representative-sample assessment depth; default work item priorities per Phase 5 table. |
| `high`     | Exhaustive assessment depth; one-band priority promotion in Phase 5.                    |

## Tier-Up Rule

Assign `risk-tier`:

* `high` when **any** binary trigger evaluates TRUE **OR** `sci-over-budget` evaluates TRUE.
* `standard` when **all** binary triggers evaluate FALSE **AND** (`sci-over-budget` evaluates FALSE OR `unknown`).

The `surface-mix` categorical indicator does not by itself trigger tier-up; it informs Phase 2 capability sweep ordering and Phase 5 grouping.

## Depth Tier Assignment

| Tier       | Phase 2 sweep depth                                                         | Phase 5 priority modifier                                             |
|------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------------|
| `standard` | Representative sample of capabilities per surface.                          | Use the table in `sustainability-backlog.instructions.md` as written. |
| `high`     | Exhaustive — every discovered capability with `appliesTo` ∋ active surface. | Promote every work item one band (P3→P2, P2→P1, P1→P0; P0 unchanged). |

## Gate Model

| Gate state | Meaning                                                                                             |
|------------|-----------------------------------------------------------------------------------------------------|
| `pending`  | Indicator answers not yet collected (Phase 1 incomplete).                                           |
| `pass`     | All indicators evaluated; tier assigned via the [Tier-Up Rule](#tier-up-rule).                      |
| `fail`     | Workload manifest declares a surface not in the enum (`cloud|web|ml|fleet`); halt and re-scope.     |
| `waived`   | User explicitly waives a binary trigger; record waiver evidence and proceed at `standard` tier.     |
| `blocked`  | User refuses to answer or required evidence is missing for any binary trigger; halt the assessment. |

The `waived` state requires the user to record a brief reason in their reply; the agent persists it under `state.frameworksDisabled[]` only when the waiver disables a whole framework, otherwise it is captured in the agent's per-turn assessment notes referenced from `handoff.md`.

## Classification Output Template

After running the gate, the agent writes a short block at the top of its Phase 2 working notes (and re-emits it in `handoff.md`):

```markdown
### Risk classification context

* Tier: <standard|high>
* Triggers fired: <comma-separated indicator ids, or `none`>
* Surface mix: <cloud-only|web-only|ml-only|fleet-only|mixed>
* SCI vs budget: <within|over-by-N-percent|unknown>
* Waivers: <comma-separated indicator ids with reasons, or `none`>
```

This block is the only persistent record of the classification; subsequent phases consult it directly rather than reading a state field.
