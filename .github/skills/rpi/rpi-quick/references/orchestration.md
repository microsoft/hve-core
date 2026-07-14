---
description: "Orchestration reference for the Research, Plan, Implement, Review, and Follow-up RPI lifecycle."
---

# RPI Orchestration Reference

## Lifecycle

1. Research starts with a readiness assessment of caller-supplied research, task details, decisions, and plan inputs. Activate `rpi-research` only when evidence is missing, stale, contradictory, insufficient for planning, or when complexity, uncertainty, dependencies, risk, or a decision-critical question warrants investigation. If evidence is adequate, record why Research is reused or satisfied-and-skipped, then continue to Plan.
2. Plan creates or revises marker-addressed plan and phase-detail artifacts, then records independent critique disposition.
3. Implement completes approved `Pxx` and `Pxx-Txx` tasks and records changes, validation, divergences, and amendments. A material amendment returns the changed plan, phase details, and evidence to planning for fresh `rpi-plan-critique`; Pass permits affected dependent work to resume, Revise returns to planning for correction, and Blocked stops affected dependent work.
4. Review compares all planning and execution evidence, then separates execution status from outcome.
5. Follow-up routes open work to research, planning, implementation, or a distinct future item.

## Artifact path matrix

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

Reuse the dated task artifacts in place. Use plain-text workspace-relative paths and the stable task, phase, task, change, divergence, amendment, critique, and review IDs.

## Follow-up routing

* Defect: return to `rpi-implement`.
* Decision gap or unsupported plan assumption: return to `rpi-plan`.
* Evidence gap: return to `rpi-research`.
* Residual work outside accepted scope: create a distinct follow-up item.

## Lifecycle discipline

Do not create a phase for ceremonial completeness. Research may be reused or satisfied-and-skipped when the readiness assessment finds adequate evidence, and must not be reported as executed in that case. A material implementation amendment re-enters Plan and does not resume affected dependent work before Pass. Re-enter only the earliest affected stage, retain durable evidence, and report validation truthfully as passed, failed, skipped, or unavailable.
