---
description: "Reference protocol for marker-based RPI implementation, amendments, divergence records, and evidence-led handoff."
---

# RPI Implement Reference

## Artifact contract

Read the plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md` and phase details at `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`. Create or update `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` for implementation evidence.

Navigate plan and detail content through `<!-- rpi:phase id=Pxx -->`, `<!-- rpi:task id=Pxx-Txx -->`, and their headings. Do not create or maintain line-number references or separate legacy log artifacts.

## Execution and tracking

1. Read the applicable plan phase, matching details, critique disposition, accepted amendments, and relevant evidence before changing source.
2. Perform the planned work, using a generic bounded subagent only when its isolated scope, write boundary, and expected result are clear.
3. Mark a task or phase complete only after its stated completion evidence is available.
4. Record material work in the changes log as `CHG-xxx` entries. Include affected files, purpose, completion evidence, and validation status.
5. Record validation as run, passed, failed, skipped, or unavailable, with the relevant reason or output summary.

## Significant divergence

A divergence is significant when it changes planned scope, architecture, target selection, dependency assumptions, acceptance criteria, validation strategy, or the implementation approach. Before resuming affected dependent work after such a divergence:

1. Add `DIV-xxx` to the changes log with the triggering evidence, affected `Pxx` or `Pxx-Txx`, actual change, and impact.
2. Create or request linked `AM-xxx` in the plan amendment register with the rationale and affected scope.
3. Amend the relevant phase details so subsequent execution follows the revised evidence-backed path.
4. Return the changed plan, phase details, and supplied evidence to the planning parent. The planning parent dispatches a fresh generic subagent that activates `rpi-plan-critique` for the material amendment and applies the existing critique disposition and planning decision logic. Record the resulting Pass, Revise, or Blocked disposition in the linked `DIV-xxx` entry using a stable `PC-xxx` ID or critique-artifact pointer.
5. Resume affected dependent work only after Pass. Revise returns the amendment to planning for correction, and Blocked stops the affected dependent work. Retain unrelated completed work and evidence.

Minor clarification, ordinary local judgment, or non-material divergence that does not alter the plan need not create a divergence record or fresh critique. Do not silently drift.

## Resumption and handoff

On resumption, continue from the first unchecked applicable task or phase and read prior `CHG-xxx` and `DIV-xxx` records. Do not resume a task dependent on a material amendment until its linked `DIV-xxx` records an explicit Pass disposition. Hand off the plan, details, critique disposition, amendments, changes record, execution status, and unresolved work to `rpi-review`.

## Production-reference hygiene

Tracking paths guide implementation but do not belong in production code, code comments, documentation strings, or commit messages. Keep shipped references durable and self-contained.
