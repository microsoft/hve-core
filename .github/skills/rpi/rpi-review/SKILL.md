---
name: rpi-review
description: "Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review."
argument-hint: "[task=...] [plan=...] [details=...] [changes=...]"
license: MIT
user-invocable: true
---

# RPI Review

## Goal

Write one evidence-based review record after implementation finishes. Assess the supplied task once, keep execution separate from outcome, and route each finding to the stage or later work that can resolve it.

## Flow

1. Resolve one task artifact set: current plan, phase details, latest plan critique, changes record, and relevant research. Use the supplied paths or the stable task slug and date. Stop if multiple unrelated sets remain ambiguous.
2. Create one record at `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md` using [templates/review-log.md](templates/review-log.md). Do not create review modes or plan a second review pass.
3. Confirm plan markers, phase details, changes evidence, handoff prose, blockers, remaining work, follow-up items, and validation state are reconciled. Then compare the complete supplied boundary: requirements, acceptance criteria, phase and task completion evidence, critique dispositions, descriptive implementation-time updates and decisions, validation, blockers, remaining work, and plan `## Follow-Up Items`. Confirm significant or divergent implementation decisions preserve confirmed user intent and are reflected in the current plan. Navigate by markers and headings, not line numbers.
4. Use generic bounded subagents for independent lenses only when they reduce a specific review uncertainty. Give each a narrow question, exact read boundary, and no source-write authority. Do not use a dedicated RPI review worker or fixed review-worker allowlist.
5. Record one complete set of substantive, severity-graded `RV-xxx` entries. Keep execution status separate from outcome: execution is Complete, Partial, or Blocked; outcome is Conformant, Conformant with justified divergence, Defects found, Residual work, or Not accepted.
6. Route each actionable gap once: defects suitable for later implementation to `rpi-implement`, significant or divergent decision gaps to `rpi-plan`, material evidence gaps to `rpi-research`, and residual work to a distinct follow-up item. Route unresolved plan follow-up items distinctly without treating them as defects or adding them to active plan scope. A later `rpi-implement` invocation does not require this Review to run again.
7. Return the review record, separate execution status and outcome, validation evidence, findings, and recommended destinations.

## Success criteria

* One review record exists at the canonical review path and includes all compared artifacts.
* One Review records the complete finding set for the supplied task boundary.
* The record separates execution state from outcome verdict.
* Findings are substantive, evidence-grounded, severity-graded `RV-xxx` records with an explicit destination.
* Defects, decision gaps, research gaps, and residual work are routed to distinct destinations.
* Descriptive implementation-time plan and detail updates, their rationale and evidence, material revision readiness, and plan follow-up items are explicitly assessed.
* Validation evidence is recorded or explicitly unavailable or skipped with a reason.
* Findings are routed clearly without creating closure, correction, full, targeted, or amended review modes.

## Constraints

* Do not implement fixes or mutate the plan, phase details, critique, research, or changes record in this stage. Review may create or update only its one canonical review record.
* Do not create per-phase review-worker outputs or depend on retired dedicated RPI review workers.
* Use plain-text workspace-relative paths in the review record.
* Use [references/review.md](references/review.md) for the review method, outcome vocabulary, routing detail, and conversation protocol.

## Conversation guidance

Use [references/review.md](references/review.md) as the authority for the state-first opening, materiality gate, continual-update template, marker meanings, pre-question context, and closeout behavior. Persist review-owned state before an opening or potential material update; chat is a concise projection, never a second history or delivery log. Preserve the read-only boundary, separate execution status from outcome, standalone versus parent continuation, conditional compaction, and final Markdown table. Every file or artifact entry in that table must use a workspace-relative Markdown link in the form `[descriptive label](path/to/file.md)`, with a line or section fragment when useful; do not substitute a plain file name, artifact type, or inline-code path. Give each entry a short description and keep the table as the final response element.

## Stop rules

* Stop as Blocked if a reviewable artifact set cannot be formed or evidence is insufficient for a credible verdict.
* Stop as Not accepted when material defects or unaccepted decision gaps remain.
* Complete a partial review only when the record names the evidence boundary and routes the missing work.

## Handoff

Return the review record, execution status, outcome, severity summary, validation coverage, and the next recommended RPI stage or distinct follow-up item. A standalone review advises the exact `/rpi-*` command only when a finding needs that destination and does not invoke it. In `rpi-quick` or confirmed automatic RPI Agent mode, return the review record to the parent for automatic continuation.

## Final response

Return review execution status separately from outcome, findings, validation coverage, blockers or open items, routed follow-up, and conditional compaction advice when warranted. Follow Conversation guidance for standalone or parent-orchestrated continuation and the final linked artifact table.


