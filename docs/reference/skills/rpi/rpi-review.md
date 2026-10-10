---
title: rpi-review
description: "Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review."
sidebar_position: 6
author: Microsoft
ms.date: 2026-09-11
ms.topic: reference
keywords:
  - skill
  - rpi
  - rpi-review
---

<!-- BEGIN AUTO-GENERATED: metadata -->
| Field       | Value                                                                        |
|-------------|------------------------------------------------------------------------------|
| Kind        | skill                                                                        |
| Source      | `.github/skills/rpi/rpi-review`                                              |
| Invocation  | Invoked directly as `/rpi-review`, or loaded on demand by referencing agents |
| Interactive | No                                                                           |
<!-- END AUTO-GENERATED: metadata -->

## What it does

<!-- BEGIN AUTO-GENERATED: overview -->
Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review.
<!-- END AUTO-GENERATED: overview -->

## When to use it

Use `rpi-review` after implementation finishes when you want an acceptance review; the review is optional. It compares the plan, the critique when one ran, the changes record, and validation evidence against the accepted requirements. The skill initializes one record under `.copilot-tracking/reviews/logs/`, compares the evidence in one marker-driven pass, and writes the findings itself. If a session ends mid-review, run it again and it continues from the saved record.

A helper such as [RPI Reviewer](../../agents/hve-core/subagents/rpi-reviewer) is optional: the review parent may assign it one bounded, context-heavy comparison and receive candidate findings with evidence locations, then verifies each one, or investigates further itself, before recording an `RV-xxx`. The review parent owns the final outcome and every route in `## Parent Decision Record`.

The record keeps execution status (`Complete`, `Partial`, `Blocked`) separate from outcome (`Conformant`, `Conformant with justified divergence`, `Defects found`, `Residual work`, `Not accepted`). Each accepted finding routes once: defects to a later `rpi-implement`, decision gaps to `rpi-plan`, evidence gaps to `rpi-research`, residual work to a distinct follow-up. A later fix does not require another review; when you ask for a new review, it writes a separate record with a numbered suffix.

In a standalone review you walk through each actionable finding with a suggested action, gather-more-information, skip, and finish choices. Inside an automatic `RPI Agent` session the parent decides routes from evidence unless you explicitly retain Review decisions. Pass `depth=deep` only when you want broader evidence tracing; `standard` completely assesses the material boundary by default.

When the plan cites a BRD, PRD, or ADR, or the changes log has Business Alignment entries, the review also checks delivered work against those sources.
Severity depends on what is at stake and on whether the source's owner knows, not on the document type.
Business stake comes from the priority of the goals a requirement traces to; business rules, non-negotiable constraints, and accepted ADRs with security, compliance, or availability triggers count as MUST.
Drift on a MUST item that nobody recorded is Critical, a divergence only you approved is High, and once the owner acknowledges it the drift drops to Low; SHOULD and COULD items rate lower.
Owner acknowledgment has to come from the owner: a decision record that names the owner and where they agreed, or a new owner signoff in the updated document. Editing the document yourself doesn't count.
Anything above Medium needs a changed outcome or acceptance criterion, and MUST-level drift from a BRD is flagged as possible misalignment with business objectives.
The review also alerts you when a cited document is stale (medium), naming its successor, or when no document covers what was delivered (low), suggesting a new ADR or a BRD or PRD revision.
An unconfirmed divergence routes like any defect or decision gap.
A divergence you already approved becomes a follow-up to update the source through its owning workflow: a BRD or PRD revision, or a new ADR that supersedes the original.
Any drift also adds a follow-up for an architecture review, so the architecture record and diagrams stay current.
For an approved divergence, the walkthrough suggests creating the follow-up and drafting a note to the source owner, such as your TPM or architect; you can keep the follow-up and skip the note.
If you accept the note, the review adds it to its record and shows it ready to copy.
Nothing is sent or posted for you.

Reach for a different asset when:

* You are reviewing a pull request rather than RPI artifacts. Use the [Code Review](../../agents/coding-standards/code-review) agent.
* You want to assess a plan before implementation. Use [rpi-plan-critique](rpi-plan-critique).

## Example usage

```text
/rpi-review task=blob-storage
```

The skill sends one `RPI Review` opening with scope, evidence readiness, and acceptance basis, compares the evidence, then presents each finding for a decision:

```text
### RV-001 [Medium]: upload_stream has no docstring describing the retry contract

The changes record shows the retry behavior was implemented and tested, but the public method does not document it, so callers cannot tell that partial uploads are retried. Suggested route: later rpi-implement.
```

After the walkthrough, the final response separates status from outcome and lists the routed work:

```text
* Review execution: Complete; Outcome: Defects found
* RV-001 (Medium) accepted -> rpi-implement; RV-002 (Low) deferred -> follow-up
* Validation: pytest passed; integration suite skipped (no storage emulator)

## Next Steps

Run `/rpi-implement` for RV-001 when ready. No second review is required.
```
