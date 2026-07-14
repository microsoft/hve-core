---
name: rpi-review
description: "Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review."
argument-hint: "[task=...] [plan=...] [details=...] [changes=...]"
license: MIT
user-invocable: true
---

# RPI Review

## Goal

Write one evidence-based review record that compares the plan, phase details, critique dispositions, amendments, and changes, then routes each finding to the stage that can resolve it.

## Flow

1. Resolve one task artifact set: plan, phase details, plan critique, changes, relevant research, and amendments. Use the supplied paths or the stable task slug and date. Stop if multiple unrelated sets remain ambiguous.
2. Create or update one record at `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md` using [templates/review-log.md](templates/review-log.md).
3. Compare requirements, acceptance criteria, phase and task completion evidence, critique dispositions, `AM-xxx` amendments, `CHG-xxx` changes, `DIV-xxx` divergences, and validation evidence. Navigate by markers and headings, not line numbers.
4. Use generic bounded subagents for independent lenses only when they reduce a specific review uncertainty. Give each a narrow question, exact read boundary, and no source-write authority. Do not use a dedicated RPI review worker or fixed review-worker allowlist.
5. Record substantive findings as severity-graded `RV-xxx` entries. Keep execution status separate from outcome: execution is Complete, Partial, or Blocked; outcome is Conformant, Conformant with justified divergence, Defects found, Residual work, or Not accepted.
6. Route each actionable gap: defects to `rpi-implement`, decision gaps to `rpi-plan`, research gaps to `rpi-research`, and residual work to a distinct follow-up item. Do not silently merge residual work into a defect or a planning decision.
7. Return the review record, separate status and outcome, validation evidence, findings, and recommended destination.

## Success criteria

* One review record exists at the canonical review path and includes all compared artifacts.
* The record separates execution state from outcome verdict.
* Findings are substantive, evidence-grounded, severity-graded `RV-xxx` records with an explicit destination.
* Defects, decision gaps, research gaps, and residual work are routed to distinct destinations.
* Validation evidence is recorded or explicitly unavailable or skipped with a reason.

## Constraints

* Do not implement fixes or mutate the plan, phase details, critique, research, or changes record in this stage.
* Do not create per-phase review-worker outputs or depend on retired dedicated RPI review workers.
* Use plain-text workspace-relative paths in the review record.
* Use [references/review.md](references/review.md) for outcome vocabulary and routing detail.

## Stop rules

* Stop as Blocked if a reviewable artifact set cannot be formed or evidence is insufficient for a credible verdict.
* Stop as Not accepted when material defects or unaccepted decision gaps remain.
* Complete a partial review only when the record names the evidence boundary and routes the missing work.

## Handoff

Return the review record, execution status, outcome, severity summary, validation coverage, and the next recommended RPI stage or distinct follow-up item.


