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

Use `rpi-review` once, after implementation finishes, to compare the plan, critique, changes record, and validation evidence against the accepted requirements. The skill initializes one record under `.copilot-tracking/reviews/logs/`, compares the evidence in one marker-driven pass, and writes the findings itself.

A helper such as [RPI Review Builder](../../agents/hve-core/subagents/rpi-review-builder) is optional: the review parent may ask it for candidate findings with evidence locations, then verifies each one before recording an `RV-xxx`. The review parent owns the final outcome and every route in `## Parent Decision Record`.

The record keeps execution status (`Complete`, `Partial`, `Blocked`) separate from outcome (`Conformant`, `Conformant with justified divergence`, `Defects found`, `Residual work`, `Not accepted`). Each accepted finding routes once: defects to a later `rpi-implement`, decision gaps to `rpi-plan`, evidence gaps to `rpi-research`, residual work to a distinct follow-up. A later fix does not trigger another review.

In a standalone review you walk through each actionable finding with a suggested action, gather-more-information, skip, and finish choices. Inside an automatic `RPI Agent` session the parent decides routes from evidence unless you explicitly retain Review decisions. Pass `depth=deep` only when you want broader evidence tracing; `standard` completely assesses the material boundary by default.

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
