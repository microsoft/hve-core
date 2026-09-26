---
title: rpi-plan
description: Create or resume an evidence-based RPI implementation plan with parent-owned finding closure and recoverable critique evidence.
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-25
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
Create or resume an evidence-based RPI implementation plan with parent-owned finding closure and recoverable critique evidence.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-plan` when adequate evidence exists and the work needs a sequenced, verifiable plan before implementation. The skill writes one plan under `.copilot-tracking/plans/` with a stable task ID, `Pxx` phases, and `Pxx-Txx` tasks. The plan leads with an executive summary and a diagrammed Phase Checklist; each task carries `Goals:`, `Requirements:`, `Details:`, `References:`, and `Dependencies:` blocks.

The Phase Checklist opens with **Before** and **After** Mermaid diagrams comparing the
evidence-backed starting state with the intended result of all phases. Each phase highlights its
changes within the After view, including labeled removal context when needed. Diagrams inherit the
renderer's light or dark theme, use readable sans-serif labels, and pair custom highlight fills
with explicit contrasting text colors.

Planning owns two internal gates. It activates [rpi-research](rpi-research) only for a demonstrated
readiness gap, and runs [rpi-plan-critique](rpi-plan-critique) once the plan is implementation-ready.
Completed coverage is reused rather than replayed for a more favorable verdict. The planner closes
ordinary supported corrections directly and commissions assessment for missing or materially changed
coverage. Recovery within authorized scope needs no fresh consent or task-lifetime retry allowance.
Confirmed user direction outranks critique advice; actual human attestations remain separate.

The planner drafts every phase itself. Before drafting, it looks for skills and subagents whose descriptions say they are used during planning or with `rpi-plan` and follows each description's guidance on when and how to use it; no subagent is required.

One input shapes how the critique is done:

| Input      | Values                       | Effect                                                                                     |
|------------|------------------------------|--------------------------------------------------------------------------------------------|
| `critique` | `standard` (default), `deep` | How broadly the initial full critique traces evidence; `deep` requires an explicit request |

Reach for a different asset when:

* Evidence is missing or contradictory. Run [rpi-research](rpi-research) first.
* The plan already exists and is approved. Run [rpi-implement](rpi-implement).
* You only want an independent read of an existing plan. Run [rpi-plan-critique](rpi-plan-critique) directly.

## Example usage

### Verify a plan's assessed-content hash

Resolve the installed `rpi-plan` skill root, then run its self-contained PowerShell 7.4 helper:

```powershell
pwsh -NoProfile -File "<resolved-rpi-plan-root>\scripts\Get-PlanAssessmentHash.ps1" -PlanPath "<absolute-plan-path>"
```

The JSON contains `projection_version`, `projection` and `sha256`. The hash covers the projection's
UTF-8 bytes without BOM, with LF line endings. Retain that projection with each attempt to make the
digest independently verifiable. The helper excludes bookkeeping sections, normalizes marked
phase/task status and removes task-local pointer-only Guidance; other assessed text remains intact.
It preserves other whitespace and ignores syntax-like text inside code fences and comments.

The planner, critic and implementer run the same helper. A missing helper, failed invocation,
version mismatch or unverifiable recorded identity blocks the gate rather than falling back to an
agent-generated algorithm. A matching hash does not substitute for a Complete assessment or
authorize substantive changes in excluded Guidance.

### Resume an interrupted critique

If planning reports `started` but no result survived, resume the same task through `rpi-plan`. It reconciles evidence, confirms that no competing run is active, verifies the saved candidate, and records the repaired prerequisite or missing assessment scope. Within existing authorization it can continue without another consent prompt, preserving original records and using a distinct output.

A preflight failure with no assessment is Deferred, with no verdict about the plan. Substantive findings remain binding even when their output file is missing. A status label alone does not prove coverage; the planner accounts for surviving evidence and missing work before authorizing recovery. Missing evidence is never Pass.

### Close findings after a plan correction

The planner preserves the original assessment and findings, records predecessor and current hashes,
and verifies the exact correction against resolving evidence. When assessed requirements,
architecture, capability, safety and evidence boundaries are unchanged, this parent closure needs
no routine second critique. A historical Revise can remain in the record while the corrected plan
becomes Ready.

A material boundary change needs assessment of its affected scope and dependencies, or a full
assessment when impact cannot be bounded. Partial coverage is never silently promoted to complete.
Before implementation, current identity, complete combined coverage, parent closure and blocking
finding dispositions must agree.

### When recovery pauses

Recovery pauses when run activity, saved identity or required evidence cannot be established, or
the same failure recurs without a changed prerequisite or concrete resolving action. The planner
identifies the diagnostic owner and smallest clearing evidence. It does not use a historical
attempt count, missing counter field or interruption to require human assessment.

Human review applies only when a named source requires it for the affected artifact or action.
Agent self-checks are not human attestations, and a genuine human signature remains human-owned.
Manual phase boundaries and unresolved material user decisions still apply.

### Preserve evidence when resuming

For example, an editor-visible plan that is absent on disk must be saved or synchronized and verified before recovery. Preserve reservations and identify a reconstructed candidate honestly. Ask only for a material decision that existing direction does not resolve, not a routine signature on the recovered plan.

Use a consistently updated workflow before resuming: edits to this checkout do not replace loaded instructions or update an installed plugin snapshot. Retain the original evidence and reconcile it under the active contract. Policy adoption alone does not prove readiness; authorized recovery still needs its identity, inactivity and progress checks.

### Create a plan

```text
/rpi-plan task=blob-storage research=.copilot-tracking/research/2026-09-04/blob-storage-research.md
```

The skill sends one `RPI Plan` opening with the interpreted goal, starting evidence, and decision state, drafts the phases, adds the Phase Checklist diagrams, and runs the initial critique once the plan is ready. Its final response summarizes readiness rather than restating the plan:

```text
* Planning execution: Complete; Planning Readiness: Ready
* Critique: standard, initial Revise; PC-001 corrected in P02-T02 Requirements and verified by parent closure with current identity and resolving evidence
* Decisions: managed identity for production confirmed; connection string limited to local development

| Artifact                                                                                                                                             | Description          |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|
| [.copilot-tracking/plans/2026-09-04/blob-storage-plan.md](.copilot-tracking/plans/2026-09-04/blob-storage-plan.md)                                   | Task-centered plan   |
| [.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md](.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md) | Independent critique |

## Next Steps

Run `/rpi-implement plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md`.
```

Inside an automatic `RPI Agent` session the parent continues to Implement without waiting for that command.
