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
2. Check whether critique findings have a recorded disposition and whether accepted `AM-xxx` amendments support all linked `DIV-xxx` records.
3. Evaluate change and validation evidence for the intended behavior and any material drift.
4. Use generic bounded subagents only for independent questions that cannot be answered cleanly in the review context. Give each worker a narrow question and read-only source boundary.
5. Write all review conclusions into one review record using `RV-xxx` finding IDs.

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

Do not convert residual work into a defect merely to force implementation, and do not create a new plan amendment during review.

## Validation evidence

Record relevant validation as passed, failed, skipped, or unavailable. Failed checks are review evidence, and skipped or unavailable checks need a reason. Do not claim unrun validation passed.
