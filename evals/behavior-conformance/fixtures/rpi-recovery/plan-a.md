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
* Write `fixture-pending` followed by one LF to the result.
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

Not ready until assessment coverage and finding closure are established.

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

No assessment is asserted by this candidate. Use the supplied task-bound history
for reconciliation; it is scenario evidence, not execution authority.

## Artifact Self-Check

* [ ] Agent-owned consistency check.

## Follow-Up Items

None.

## Handoff

Planning owns readiness. Implementation owns the output and changes record.
