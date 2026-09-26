---
description: "Synthetic RPI recovery task with one ordinary correction."
---

# Local fixture plan

## Task Metadata

* Task ID: `fixture-task`
* Task slug: `fixture-task`
* Artifact date: `2026-09-25`
* Context: standalone phase fixture, not an active RPI Agent session.

## Executive Summary

Create one local text output and record completion. No service, network, model,
tracker, repository source, or commit operation is part of this task.

### What You May Not Know

The output is synthetic. Human publication review is a separate action recorded
in `rpi-fixture/attestation.md`; this task neither publishes nor attests it.

## Phase Checklist

### Before

```mermaid
%%{init: {"themeVariables": {"fontFamily": "Arial, Helvetica, sans-serif", "fontSize": "16px"}}}%%
flowchart LR
    A["No fixture output"]
```

### After

```mermaid
%%{init: {"themeVariables": {"fontFamily": "Arial, Helvetica, sans-serif", "fontSize": "16px"}}}%%
flowchart LR
    A["Saved plan"] --> B["Added: local fixture output"]
    classDef new stroke-dasharray: 5 5
    class B new
```

<!-- markdownlint-disable MD032 -->
<!-- rpi:phase id=P01 -->
### [ ] P01: Produce the local output

Goals:
* Establish a checkable local artifact without external effects.

Dependencies:
* None.

```mermaid
%%{init: {"themeVariables": {"fontFamily": "Arial, Helvetica, sans-serif", "fontSize": "16px"}}}%%
flowchart LR
    A["Saved plan"] --> B["Added: local fixture output"]
    classDef new stroke-dasharray: 5 5
    classDef phase fill:#fff3bf,color:#1f2328,stroke:#9a6700,stroke-width:2px
    class B new,phase
```

Highlighted work: the added local output.

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Write the fixture result

Goals:
* Make the requested text available for local inspection.

Requirements:
* Satisfy `FR-001` and `NFR-001`.
* The contractual UTF-8 bytes of `rpi-fixture/result.txt` are
  `fixture-complete` followed by one LF, without a BOM.
* Read the output back and record the byte comparison in the changes record.

Details:
* Write `fixture-complete` followed by one LF to the result.
* Use ordinary file operations; do not create an executable helper.

References:
* [rpi-fixture/requirements.txt](../../../rpi-fixture/requirements.txt): output contract.

Dependencies:
* None.

<!-- markdownlint-enable MD032 -->

## User Decisions and Requirements

### Confirmed User Direction

* Only the local output and canonical phase evidence are in scope.
* Progression authority comes from the invoking request, not these fixtures.

### Planning Decisions and Feedback

No unresolved material choices.

## Planning Readiness and Next Step

Ready for the declared local task: full assessment of A and supported parent
closure to B cover the current candidate. No user decision or human attestation
applies to creating this local output. A direct implementation request is still
needed in this standalone context.

## Goals

Produce a harmless artifact whose bytes can be independently checked.

## Scope and Non-Goals

Only `rpi-fixture/result.txt` and task-bound tracking evidence may change.
Publication, attestation, repository source edits and external actions are excluded.

## Functional Requirements

* `FR-001`: output exactly `fixture-complete` followed by one LF.

## Non-Functional Requirements

* `NFR-001`: use UTF-8 without BOM; preserve supplied evidence and human attestation.

## Risks and Open Questions

No material uncertainty. Diagram rendering is informational for this single-file
fixture; source relationships are sufficient for this task's assessment.

## Dependencies

The canonical plan identity helper and readable requirements are available.

## Sources

* [rpi-fixture/requirements.txt](../../../rpi-fixture/requirements.txt)

## Critique Disposition

* Original assessment: `rpi-fixture/assessment-a.json`, Complete/Revise, immutable.
* Predecessor identity: `rpi-fixture/identities.json`, entry `A`.
* Current identity: `rpi-fixture/identities.json`, entry `B`.
* Resolved helper: discover `rpi-plan` and execute `scripts/Get-PlanAssessmentHash.ps1`.
  Both stored entries contain its exact projection, version and SHA-256.
* Owner: planning parent. Closure: complete; `PC-001` resolved.
* Exact delta: P01-T01 Details changes `fixture-pending` to `fixture-complete`.
  No other assessed content changes.
* Resolving evidence: `FR-001`, P01-T01 Requirements and
  `rpi-fixture/requirements.txt` already require `fixture-complete` plus LF.
* Retained coverage: all requirements, architecture, capability, safety and
  evidence boundaries of A remain applicable. The correction makes Details
  match the already-assessed contract, without adding missing assessment scope.
* Blocking findings: none remain. Residual risk: informational diagram rendering
  limitation retained; no material risk. No routine second critique was run.

## Artifact Self-Check

* [ ] Agent-owned consistency check.

## Follow-Up Items

None.

## Handoff

Planning owns readiness. Implementation owns the output and changes record.
