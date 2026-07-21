---
description: "Reference protocol for evidence-based RPI review, outcome separation, and follow-up routing."
---

# RPI Review Reference

## Artifact set

Review one task set using these paths:

* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

Read research when it is relevant to an evidence or decision gap. Use markers and stable IDs rather than line references.

## Review method

1. Compare plan requirements and acceptance criteria with completed `Pxx` and `Pxx-Txx` evidence.
2. Reconcile every descriptive implementation-time plan or phase-detail update with the current plan and details. Verify affected `Pxx`, `Pxx-Txx`, or `Follow-Up Items`; what changed and why; triggering evidence; user decision when present; reconciliation performed; and planning and critique state when material. Confirm immediately relevant updates preserve approved intent and received current-state reconciliation.
3. Check whether critique findings have a recorded disposition. For each material revision, confirm the changes record captures the discovery and paused dependent work, the plan and details were reconciled, a fresh planning and critique pass completed, relevant `PC-xxx` evidence is available when present, and affected dependent work did not resume early.
4. Assess every plan `## Follow-Up Items` entry. Confirm it states why it is outside immediate scope and an owner or next action, remains outside active `Pxx` and `Pxx-Txx` implementation, completion, and acceptance claims, and is mirrored in the changes record when implementation discovered it.
5. Evaluate completed-work summaries, validation evidence, blockers, remaining work, and intended behavior for material drift.
6. Use generic bounded subagents only for independent questions that cannot be answered cleanly in the review context. Give each worker a narrow question and read-only source boundary.
7. Write all review conclusions into one review record using `RV-xxx` finding IDs.

## Separate execution from outcome

Execution status says whether planned work ran:

* `Complete`
* `Partial`
* `Blocked`

Outcome says whether the result is acceptable:

* `Conformant`
* `Conformant with justified divergence`
* `Defects found`
* `Residual work`
* `Not accepted`

Do not use one vocabulary as a substitute for the other. A complete execution may have defects, and partial execution may still have conformant evidence for completed scope.

## Finding and routing rules

Each `RV-xxx` finding names severity, evidence, impact, and destination.

* Route implementation defects to `rpi-implement`.
* Route unresolved decisions or invalid plan assumptions to `rpi-plan`.
* Route material evidence gaps to `rpi-research`.
* Route non-blocking residual work to a distinct follow-up item with a clear owner or next action.

Route an unresolved plan follow-up item to its distinct follow-up work owner or next action. It is not a defect or a new active plan task merely because review found it still open. Do not convert residual work into a defect merely to force implementation, and do not create a new active plan revision during review.

## Validation evidence

Record relevant validation as passed, failed, skipped, or unavailable. Failed checks are review evidence, and skipped or unavailable checks need a reason. Do not claim unrun validation passed.

## Conversation and closeout

During material review work, give concise updates at evidence-comparison boundaries. State the comparison and reason, findings, decisions, blockers, validation results, relevant artifact links, and one important point the user might otherwise miss. Before a user question, state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

At closeout, report review execution status separately from outcome. Include results, material findings, decisions, and blockers or open items. Advise `/compact` only when stale output, superseded reasoning, or completed comparison detail outweighs current context and the review record and compared artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For standalone review, advise the exact `/rpi-implement`, `/rpi-plan`, or `/rpi-research` command only when an actionable finding needs that destination. Do not invoke it. Otherwise state the no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the record to the parent for automatic continuation after gates and required confirmations pass. End the closeout with a Markdown table linking every relevant existing artifact and a short description. Keep the table as the final response element.
