---
name: rpi-plan
description: "Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed."
argument-hint: "[task=...] [research=...] [context=...] [draft=...] [decisions=...]"
license: MIT
user-invocable: true
---

# RPI Plan

## Goal

Produce an implementation-ready, ordinary Markdown plan with a concise user-facing executive summary, and a separate phase-details artifact that preserve the caller's requirements, evidence, decisions, and acceptance criteria. The planning parent owns the overall checklist and final readiness decision.

Read [references/planning.md](references/planning.md) for the readiness, executive-summary, and artifact protocol.

## Flow

1. Establish the task identity and synthesize the caller-supplied task context, completed research, draft plan material, and decisions deeply enough to distinguish evidence, assumptions, and open choices. Treat supplied evidence as the starting point, not as a reason to repeat investigation.
2. Assess supplied and completed evidence against requirements, acceptance criteria, dependencies, material risks, complexity, uncertainty, and decision-critical choices. Reuse adequate evidence and orchestrate only the applicable skills or bounded subagents needed to close a demonstrated gap. Activate `rpi-research` only when one of those dimensions reveals a demonstrated planning gap.
3. Create or revise these artifacts with one stable task ID, `Pxx` phase IDs, and `Pxx-Txx` task IDs:
   * `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
   * `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
4. Use [templates/implementation-plan.md](templates/implementation-plan.md) for the overall plan and [templates/implementation-details.md](templates/implementation-details.md) for evidence-based phase detail. Follow the executive-summary protocol, placing the summary after task metadata and before sources, and keep it synchronized with every material plan change. Put contextual phase and task markers immediately before their headings.
5. Create an independent critique at `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`. Dispatch a fresh generic native critique worker through `runSubagent`, instruct it to activate `rpi-plan-critique`, and provide the exact task context, caller requirements, supplied research and evidence pointers, current plan and details paths, decisions, dependencies, acceptance criteria, and this one critique output path. Give that worker read access to supplied evidence and write access only to the critique output. Do not use a fixed critique-worker allowlist.
6. Act on the critique with judgment. Choose the smallest suitable next action: revise the plan directly, dispatch `RPI Planner` for one exact phase, ask a small decision-critical question set, rerun the critique after material changes, or finalize. Synchronize the executive summary before rerunning critique or finalizing. Do not iterate for ceremony.
7. Record critique dispositions and hand off the plan, phase details, critique, and downstream changes path. Treat executive-summary synchronization as a readiness condition, not optional polish. The implementation phase owns creation of `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`.

## Inputs

* Task context and caller requirements
* Completed or supplied research and evidence pointers
* Draft plan details, decisions, dependencies, and acceptance criteria when available
* Existing plan and phase-details artifacts when resuming

## Success criteria

* The plan and phase-details artifacts use the prescribed plain Markdown paths and contain no `applyTo` metadata.
* The plan has one stable task ID, a near-top user-facing executive summary, phase and task IDs, contextual markers, requirements, acceptance criteria, dependencies, decisions, amendments, critique disposition, and a clear handoff.
* Details provide evidence-based context and completion expectations for every planned task without prescribing unsupported choreography.
* Research is activated only for a demonstrated readiness gap.
* A critique result is recorded with a Pass, Revise, or Blocked verdict before finalization.

## Constraints

* Keep planning evidence-based. State assumptions and unresolved items when evidence does not support a local choice.
* The parent may delegate one exact phase to `RPI Planner`, but retains ownership of the complete plan and phase checklist.
* Do not create separate legacy log artifacts, line-number references, line-refresh work, or detail-line verification.
* Do not implement production changes in this phase.
* Use plain-text workspace-relative paths in tracking artifacts.

## Stop rules

* Stop as Blocked when the task, required acceptance criteria, or a decision-critical evidence gap cannot be resolved responsibly.
* Stop as Revise when critique findings require plan changes that remain open.
* Finalize when the plan is credible for implementation and the critique disposition explains any accepted residual risk.

## Handoff

Return a concise user-facing version of the executive summary, covering the implementation outcome, important decisions and consequences, information the user may not immediately know, and unresolved decisions or blockers. Then return the plan, phase-details, and critique paths; planning readiness; and the next recommended RPI stage. For normal progression, hand off to `rpi-implement` with `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` as its changes-record path.


