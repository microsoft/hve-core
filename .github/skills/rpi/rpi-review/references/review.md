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

The primary parent resolves scope, acceptance basis, depth, and artifact readiness, initializes the canonical review record, and dispatches one `RPI Review Builder`. The builder owns the evidence comparison and review-document body. The parent owns only final outcome and route decisions in `## Parent Decision Record`, parent state, conversation, and continuation.

The builder performs one marker-driven pass:

1. Compare plan requirements and acceptance criteria with completed `Pxx` and `Pxx-Txx` evidence.
2. Reconcile implementation-time plan or phase-detail updates with current planning state, triggering evidence, user decisions, and critique state.
3. Check critique finding dispositions and whether significant changes preserved confirmed intent before affected work continued.
4. Assess every `## Follow-Up Items` entry for scope separation, rationale, owner, and changes-record parity.
5. Evaluate completed-work summaries, validation, blockers, remaining work, and intended behavior for material drift.
6. Write one complete substantive `RV-xxx` finding set, proposed outcome, and proposed routes in the review record.

Do not dispatch other review workers. The builder cannot delegate. Before comparison, the parent confirms reconciliation is sufficient for a credible boundary and inspects the review path and parent state. A `started`, Complete, Partial, or Blocked builder execution consumes the one invocation. When no execution exists, the parent initializes the record and persists Scope and Evidence, Opening Review State, builder candidate identity, depth, provenance, and `started` before dispatch. On resume, reconcile existing evidence instead of dispatching a replacement. When `started` has no trusted terminal record or return, the parent records final Review Blocked and the exact condition for a later new Review after the ambiguity or path problem is resolved.

## Review depth

| Depth     | Selection rule        | Builder behavior                                                                                                                                                                                          |
|-----------|-----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `focused` | Default               | Thoroughly cover every material acceptance contract once, prefer speed, follow markers and direct evidence, and omit restatement, cosmetics, exhaustive strengths, low-impact suggestions, and narration. |
| `deep`    | Explicit user request | Trace the same supplied boundary more broadly and include substantive lower-severity concerns without open-ended research, nested workers, or another pass.                                               |

Do not infer deep review from task size, complexity, uncertainty, or risk. Focused review changes prioritization and presentation, not required coverage of material acceptance evidence.

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

Each builder-authored `RV-xxx` finding names severity, evidence, impact, and proposed destination. The primary parent records one disposition for each route: accepted, rejected, deferred, or changed, with rationale and next action.

* Route implementation defects that fit the current accepted direction to a later `rpi-implement` invocation.
* Route significant or divergent decisions or invalid plan assumptions to `rpi-plan`.
* Route material evidence gaps to `rpi-research`.
* Route non-blocking residual work to a distinct follow-up item with a clear owner or next action.

Route an unresolved plan follow-up item to its distinct follow-up work owner or next action. It is not a defect or a new active plan task merely because review found it still open. Do not convert residual work into a defect merely to force implementation, and do not create a new active plan revision during review.

## Validation evidence

Record relevant validation as passed, failed, skipped, or unavailable. Failed checks are review evidence, and skipped or unavailable checks need a reason. Do not claim unrun validation passed.

## Conversation protocol

Before builder dispatch, initialize the one review record and persist its canonical opening state in Scope and Evidence plus Opening Review State. Record the interpreted review goal, scope, depth and provenance, evidence readiness, acceptance basis, comparison boundary, builder write authority, parent decision authority, and initial blockers. Then send one opening message:

```markdown
## RPI Review: [Task] | [Full task, Pxx, or Pxx-Txx scope]

[Interpreted review goal.]

* Review scope: [full task, Pxx, or Pxx-Txx scope]
* Evidence set and readiness: [available compared artifacts and readiness]
* Acceptance basis: [requirements, acceptance criteria, critique dispositions, or other review basis]
* Review depth: [focused default or explicit-user deep]
* Comparison boundary: [evidence comparison and its limit]
* Authority: [builder writes the review body; parent owns outcome, routes, and continuation]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

This is the starting review state and may evolve only through the existing evidence-comparison, finding, validation, and routing rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent readiness, acceptance support, links, or an outcome before comparison supports one.

The parent does not narrate builder internals. In focused mode, send no continual review updates unless builder execution is Partial or Blocked, a parent decision is required, or the final record is ready. In deep mode, the same materiality gate applies. Persist parent-owned outcome and route dispositions before projecting them in conversation.

Send a continual update only when the item changes review direction, execution status or outcome, a material finding or artifact state, a blocker or decision need, validation state, routing or handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw worker returns, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted:

```markdown
### [Marker when useful] [Review state]: [Short item]

Evidence: [comparison basis and relevant Markdown links]

Review consequence: [effect on execution status, outcome, RV finding, validation coverage, or routing]

Next review action: [next comparison, validation assessment, focused question, route, closeout, or stop]
```

Use `✅` only for evidence-backed conformance, a completed comparison, or passed validation. Use `⚠️` for a substantive finding, residual work, failed, skipped, or unavailable validation, or a decision or evidence gap. Use `⛔` when review progress is blocked. Markers are optional and must be paired with text.

The builder never asks the user questions. When its finding exposes a user-owned decision, the parent persists the decision context, then states viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links before asking.

At closeout, report review execution status separately from outcome. Include results, material findings, decisions, blockers or open items, and anything the user might otherwise miss. Advise `/compact` only when stale output, superseded reasoning, or completed comparison detail outweighs current context and the review record and compared artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For standalone review, remain read-only and advise the exact `/rpi-implement`, `/rpi-plan`, or `/rpi-research` command only when an actionable finding needs that destination. Do not invoke it and do not require a second Review after later implementation. Otherwise state the no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the record to the parent as the task's one Review result. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, follow-up choice, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Parent decision protocol

After the builder returns, the primary parent reads the review record once and decides:

* Final review execution status and outcome
* Accepted, rejected, deferred, or changed disposition for every proposed route
* Whether a significant decision returns to `rpi-plan`, an evidence gap returns to `rpi-research`, a defect becomes later `rpi-implement`, or residual work enters the follow-up queue
* Standalone advisory or parent-orchestrated continuation

Record those decisions only in `## Parent Decision Record` and parent state when present. Preserve builder findings and comparison tables as evidence. Do not redo the review, rewrite findings to fit a preferred outcome, dispatch another builder, or let the builder transition phases.

## Review Closeout Projection

At closeout, project builder execution, final review execution status, final outcome, validation coverage, blockers, and the parent disposition for every actionable finding. Keep Complete, Partial, or Blocked execution separate from Conformant, Conformant with justified divergence, Defects found, Residual work, or Not accepted outcome.

Preserve the four-destination matrix: implementation defects go to `rpi-implement`; decision gaps and invalid assumptions go to `rpi-plan`; material evidence gaps go to `rpi-research`; and non-blocking residual work goes to a distinct follow-up owner. Do not describe residual work as a defect. When more than one category occurs, state each distinct destination rather than selecting one aggregate route.

For standalone use, provide only the eligible advisory command or no-handoff reason. In parent contexts, return the same projection to the parent, which owns continuation. The linked-artifact table follows this projection, immediately before the final `## Next Steps` section.
