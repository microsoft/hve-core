---
title: rpi-plan
description: "Create or resume an evidence-based RPI implementation plan. Use for planning, interrupted critiques, or bounded critique infrastructure recovery."
sidebar_position: 4
author: Microsoft
ms.date: 2026-09-24
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
Create or resume an evidence-based RPI implementation plan. Use for planning, interrupted critiques, or bounded critique infrastructure recovery.
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
Substantive assessments are not replayed for an unchanged candidate. Required corrections and
material implementation-time plan changes receive revision-bound closure. The planner can authorize
one generic interruption recovery for the initial assessment; two infrastructure-only retries are
shared across the task, including failed closure runs, with separate consent and evidence checks.
Confirmed user direction outranks critique advice.

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

If planning reports `started` but no result survived, resume the same task through `rpi-plan`. It checks recorded evidence, confirms the original critique run has ended, and verifies the saved plan and state. When eligible, it asks for your approval of one recovery for the identified task and candidate, preserving original records and writing a separate recovery result.

A substantive `Complete`, `Partial` or `Blocked` result remains binding for its candidate even if its file is missing. A saved reservation cannot be replayed. Missing evidence is not a pass: implementation requires an actual Complete assessment covering the delivered plan hash, closed blocking findings and explicit residual-risk dispositions.

### Close findings after a plan correction

For a required correction, the planner preserves the first assessment and findings, records the
original and revised plan hashes, the exact change and affected requirements, and reserves a
distinct revision-closure result. If requirements, architecture, capability, safety or evidence
boundaries change, the revised plan needs a fresh full assessment. Otherwise, an independent
targeted closure verifies the correction against the immediately preceding Complete result and
every intervening result back to the Complete full assessment. A Partial or Blocked assessment
cannot be extended by targeted closure.

Repeated hashes, oscillating corrections or no material progress stop as Revise or Blocked. Before
handing off to implementation, the planner compares the delivered assessed-content hash with a
Complete full assessment or a valid Complete targeted closure chain and verifies every blocking
finding is closed. Checked task markers and implementation-only `Guidance:` pointers do not change
that hash; changes to assessed plan content do. Changing candidates does not reset
infrastructure-retry reservations.

If both the initial attempt and generic recovery ended in verified infrastructure failures without an
assessment, the planner may request up to two additional infrastructure retries. A failed
revision-closure invocation may use remaining slots from the same task-wide allowance without a
generic recovery. Each needs confirmed ended runs, reconciled saved and late evidence, an
identified candidate hash and fresh consent. A network-looking error or absent file alone is
insufficient. Every reservation consumes its slot, even if interrupted; changing sessions,
candidates or hosts does not reset the task's budget.

For example, two host-recorded connection failures with confirmed completion and no assessment may qualify for another consent request. A substantive critique of the same candidate, an unknown run status, or unresolved assessment fragments do not qualify. Earlier findings on a different corrected candidate remain binding and must be reconciled, but do not themselves disqualify recovery of the failed closure.

If a closure is interrupted without positive host or transport failure evidence, the planner
checks the saved candidate, attempt history and available results, then confirms every originating
run ended. A user cancellation, closed window or session timeout alone does not establish that
status. With no substantive result or unresolved fragments for the revised candidate, the planner
routes directly to independent human-assessment eligibility checks, even when infrastructure retry
slots remain. It preserves unknown outcomes, prior findings, hashes and actual reservation counts;
it neither retries automatically nor marks unused slots exhausted. Specific consent is still
required, and implementation stays blocked until a qualifying full human assessment is reconciled.

Older plans may not have an infrastructure reservation count. The planner reconstructs it from the
original task's attempt records, parent state, critique outputs and available originating run
evidence, counting interrupted reservations even without output. It preserves the task, candidates
and findings. If the complete history cannot be established, the count remains unknown, automated
retries stay blocked, and the planner requests the specific missing evidence rather than treating
the field as zero or exhausting the budget by default.

### When infrastructure retries are exhausted

The planner stops automated critique calls and prepares sanitized diagnostics: attempt IDs, candidate hashes, evidence locations, failure and lifecycle status, and the host/network support owner and evidence needed. Repairing the transport does not replenish retry slots.

Exhaustion alone does not authorize another assessment. Active or unknown runs must be reconciled
first; substantive results for the current candidate follow their existing finding dispositions.
Either verified infrastructure exhaustion or an eligible ended closure interruption can permit a
specifically authorized independent human critique, with no substantive result or unresolved
fragments for the current candidate. If the interrupted attempt was a closure, that human must
assess the full revised plan and reconcile prior findings.

The human supplies a complete assessment of the saved candidate, including assessor provenance, independence, coverage, verdict and findings. The agent verifies that report against the candidate and all surviving evidence; it cannot write or sign the human's assessment. Approval alone or a mismatched candidate remains blocked. Late results are retained and reconciled, never discarded in favor of a passing report.

### Preserve evidence when resuming

For example, an editor-visible plan that is absent on disk must be saved or synchronized and verified before recovery. Do not delete the reservation to restart. A reconstructed candidate must be identified and approved as current, not represented as the lost original.

Use a consistently updated workflow before resuming: edits to this checkout do not replace instructions already loaded in a conversation or update an installed plugin snapshot. Start a fresh session with the updated repository workflow, or update the installed distribution you use. Choosing this recovery policy or enabling automatic mode does not authorize a specific task's recovery.

### Create a plan

```text
/rpi-plan task=blob-storage research=.copilot-tracking/research/2026-09-04/blob-storage-research.md
```

The skill sends one `RPI Plan` opening with the interpreted goal, starting evidence, and decision state, drafts the phases, adds the Phase Checklist diagrams, and runs the initial critique once the plan is ready. Its final response summarizes readiness rather than restating the plan:

```text
* Planning execution: Complete; Planning Readiness: Ready
* Critique: standard, initial Revise; PC-001 (Medium) corrected in P02-T02 Requirements and verified by Complete targeted closure of the delivered hash
* Decisions: managed identity for production confirmed; connection string limited to local development

| Artifact                                                                                                                                             | Description          |
|------------------------------------------------------------------------------------------------------------------------------------------------------|----------------------|
| [.copilot-tracking/plans/2026-09-04/blob-storage-plan.md](.copilot-tracking/plans/2026-09-04/blob-storage-plan.md)                                   | Task-centered plan   |
| [.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md](.copilot-tracking/reviews/plans/2026-09-04/blob-storage-plan-critique.md) | Independent critique |

## Next Steps

Run `/rpi-implement plan=.copilot-tracking/plans/2026-09-04/blob-storage-plan.md`.
```

Inside an automatic `RPI Agent` session the parent continues to Implement without waiting for that command.
