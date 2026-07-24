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
3. Check whether critique findings have a recorded disposition. Confirm the planner applied compatible findings, preserved confirmed user intent, and obtained a user decision for any significant or divergent change before affected work continued.
4. Assess every plan `## Follow-Up Items` entry. Confirm it states why it is outside immediate scope and an owner or next action, remains outside active `Pxx` and `Pxx-Txx` implementation, completion, and acceptance claims, and is mirrored in the changes record when implementation discovered it.
5. Evaluate completed-work summaries, validation evidence, blockers, remaining work, and intended behavior for material drift.
6. Use generic bounded subagents only for independent questions that cannot be answered cleanly in the review context. Give each worker a narrow question and read-only source boundary.
7. Write all review conclusions into one review record using `RV-xxx` finding IDs.

Before comparison, confirm plan markers, phase details, changes evidence, handoff prose, blockers, remaining work, follow-up items, and validation state are current. Stop as Blocked when stale or missing evidence prevents a credible task boundary.

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

* Route implementation defects that fit the current accepted direction to a later `rpi-implement` invocation.
* Route significant or divergent decisions or invalid plan assumptions to `rpi-plan`.
* Route material evidence gaps to `rpi-research`.
* Route non-blocking residual work to a distinct follow-up item with a clear owner or next action.

Route an unresolved plan follow-up item to its distinct follow-up work owner or next action. It is not a defect or a new active plan task merely because review found it still open. Do not convert residual work into a defect merely to force implementation, and do not create a new active plan revision during review.

## Validation evidence

Record relevant validation as passed, failed, skipped, or unavailable. Failed checks are review evidence, and skipped or unavailable checks need a reason. Do not claim unrun validation passed.

## Conversation protocol

Before substantive evidence comparison or delegation, create or update the one review record and persist its canonical opening state in `## Opening Review State`. Record the interpreted review goal, review scope, evidence readiness, acceptance basis, first comparison boundary, active read-only boundaries, and initial blockers. Then send one opening message:

```markdown
## RPI Review: [Task] | [Full task, Pxx, or Pxx-Txx scope]

[Interpreted review goal.]

* Review scope: [full task, Pxx, or Pxx-Txx scope]
* Evidence set and readiness: [available compared artifacts and readiness]
* Acceptance basis: [requirements, acceptance criteria, critique dispositions, or other review basis]
* Initial comparison boundary: [first evidence comparison and its limit]
* Active read-only boundaries: [review record and evidence-only authority]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

This is the starting review state and may evolve only through the existing evidence-comparison, finding, validation, and routing rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent readiness, acceptance support, links, or an outcome before comparison supports one.

Before each potential continual update, persist the item in the review-record section that owns it, including reconciliation, completed-work assessment, implementation-time update assessment, critique and material revision assessment, follow-up assessment, findings, blockers and remaining work, validation evidence, outcome, or next owner. Chat is a concise projection of that state, never a second history or delivery log.

Send a continual update only when the item changes review direction, execution status or outcome, a material finding or artifact state, a blocker or decision need, validation state, routing or handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw worker returns, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted:

```markdown
### [Marker when useful] [Review state]: [Short item]

Evidence: [comparison basis and relevant Markdown links]

Review consequence: [effect on execution status, outcome, RV finding, validation coverage, or routing]

Next review action: [next comparison, validation assessment, focused question, route, closeout, or stop]
```

Use `✅` only for evidence-backed conformance, a completed comparison, or passed validation. Use `⚠️` for a substantive finding, residual work, failed, skipped, or unavailable validation, or a decision or evidence gap. Use `⛔` when review progress is blocked. Markers are optional and must be paired with text.

Before a user question, persist its decision context and state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

At closeout, report review execution status separately from outcome. Include results, material findings, decisions, blockers or open items, and anything the user might otherwise miss. Advise `/compact` only when stale output, superseded reasoning, or completed comparison detail outweighs current context and the review record and compared artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For standalone review, remain read-only and advise the exact `/rpi-implement`, `/rpi-plan`, or `/rpi-research` command only when an actionable finding needs that destination. Do not invoke it and do not require a second Review after later implementation. Otherwise state the no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the record to the parent as the task's one Review result. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, follow-up choice, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Review Closeout Projection

At closeout, project execution status, outcome, validation coverage, blockers, and the destination for every actionable finding. Keep Complete, Partial, or Blocked execution separate from Conformant, Conformant with justified divergence, Defects found, Residual work, or Not accepted outcome.

Preserve the four-destination matrix: implementation defects go to `rpi-implement`; decision gaps and invalid assumptions go to `rpi-plan`; material evidence gaps go to `rpi-research`; and non-blocking residual work goes to a distinct follow-up owner. Do not describe residual work as a defect. When more than one category occurs, state each distinct destination rather than selecting one aggregate route.

For standalone use, provide only the eligible advisory command or no-handoff reason. In parent contexts, return the same projection to the parent, which owns continuation. The linked-artifact table follows this projection, immediately before the final `## Next Steps` section.
