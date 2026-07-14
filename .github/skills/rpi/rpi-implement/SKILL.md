---
name: rpi-implement
description: "Execute an approved RPI plan, preserve amendments, and record evidence-led changes. Use when implementation is ready to begin or resume."
argument-hint: "[plan=...] [phase=...] [task=...]"
license: MIT
user-invocable: true
---

# RPI Implement

## Goal

Deliver the approved outcome using the plan and phase details as evidence, while keeping task completion, changes, divergences, amendments, and validation evidence trustworthy for review.

## Flow

1. Resolve the exact plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`, its phase details, relevant evidence, critique disposition, and any prior changes record. Use markers and headings to locate `Pxx` and `Pxx-Txx`, not line positions.
2. Create or continue `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` using [templates/changes-log.md](templates/changes-log.md). Record material work with `CHG-xxx` entries.
3. Execute the approved tasks with judgment. Work directly when the task is coupled or small. Use a generic bounded subagent only when isolated execution materially improves the outcome, and provide the exact phase or task, evidence, allowed write boundary, and expected return.
4. Mark completed tasks and phases in the plan after their completion evidence is available. Update the changes log with affected files, validation evidence, blockers, and remaining work.
5. When a significant divergence is necessary, create a linked `DIV-xxx` record in the changes log, create or request its `AM-xxx` amendment in the plan, and update the affected plan and phase details before returning the material amendment to planning.
6. For each significant divergence, return the changed plan, phase details, and supplied evidence to the planning parent. The planning parent dispatches a fresh generic subagent that activates `rpi-plan-critique` for the material amendment and applies the existing critique disposition and planning decision logic. Pass permits affected dependent work to resume, Revise returns to planning for correction, and Blocked stops affected dependent work. Preserve unrelated completed work and evidence.
7. Run the validation expected by the plan or by completed changed behavior without treating it as permission to resume affected dependent work. Record executed checks, results, and explicit skip reasons in the changes log.
8. When the implementation scope is ready for review and no affected dependent work awaits critique, hand off the plan, phase details, critique disposition, amendments, and changes record to `rpi-review`.

## Inputs

* Approved plan path or task context
* Optional exact `Pxx` phase or `Pxx-Txx` task scope
* Phase details, supplied evidence, critique disposition, and prior amendments when available

## Success criteria

* The implementation follows the approved plan or records its material divergence explicitly.
* Completed `Pxx-Txx` tasks and `Pxx` phases are checked off only after completion evidence exists.
* The changes log uses `CHG-xxx` for material changes and `DIV-xxx` only for significant divergence.
* Each `DIV-xxx` links to an `AM-xxx` amendment in the plan, matching phase-detail updates when applicable, and its critique disposition through a stable `PC-xxx` ID or critique-artifact pointer.
* Affected dependent work resumes only after an explicit Pass disposition. Revise returns the amendment to planning, and Blocked stops the affected work.
* Validation evidence or an explicit skip reason is available for changed behavior.
* The review handoff identifies the current execution status and any unresolved work.

## Constraints

* Use [references/implementation.md](references/implementation.md) for the tracking and amendment protocol.
* Do not expand scope without an evidence-backed amendment or an explicit follow-up item.
* Apply the fresh critique gate only to significant divergence. Ordinary local judgment and non-material divergence remain implementation decisions.
* Do not use line numbers, separate legacy log artifacts, or retired dedicated RPI execution workers.
* Keep `.copilot-tracking/` references out of production code, code comments, documentation strings, and commit messages.

## Stop rules

* Stop as Blocked when the approved plan, required details, or a dependency prevents credible execution.
* Stop and return to planning when a material change cannot be supported by an `AM-xxx` amendment.
* Pause affected dependent work after recording a significant divergence, amendment, and phase-detail update. Return the amended artifacts to planning for fresh critique, and do not resume that work unless the disposition is Pass.
* Stop after a caller-bounded phase or task once its plan state and changes evidence are current.

## Handoff

For an unreviewed significant amendment, return the changed plan, phase details, linked `DIV-xxx` and `AM-xxx` records, supplied evidence, and affected dependent scope to the planning parent. Otherwise return the changes path, completed and remaining `Pxx` or `Pxx-Txx` items, validation status, linked divergences and amendments, and the recommended `rpi-review` handoff.


