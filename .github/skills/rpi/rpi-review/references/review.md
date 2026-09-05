---
description: "Reference protocol for evidence-based RPI review, outcome separation, and follow-up routing."
---

# RPI Review Reference

## Artifact set

Review one task set using these paths:

* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

Read research when it is relevant to an evidence or decision gap. Use markers and stable IDs rather than line references.

## Review document contract

Use `templates/review-log.md` for one record that a person can review and a later RPI stage can act on. Lead with Executive Summary, What You May Not Know, Findings and Proposed Routes, and Parent Decision Record. Put validation, risks, and the detailed Review Record afterward.

* Keep the Executive Summary concise and explicit about its assessed scope, proposed outcome, material findings, validation, and limits. Label builder conclusions as proposals; final decisions belong to the parent.
* Use What You May Not Know for a material behavior change, justified divergence, or evidence limit that changes the reader's interpretation. State `None` rather than manufacturing additional concerns.
* Order findings by severity and impact. Give each a descriptive heading and plain-language explanation, then keep its requirement, expected behavior, observed evidence, consequence, resolution condition, and proposed route together. State when behavior is unassessed rather than implying a demonstrated defect.
* Describe the outcome or evidence needed to resolve a finding, not a mandatory patch recipe. Preserve local implementation judgment unless an accepted requirement or interface fixes the solution. Label non-binding examples as illustrative.
* Record acceptance and change coverage once in the Review Record. Group related markers only when each remains identifiable and shares the evidence and assessment. Assess material plan updates and confirmed decisions without duplicating the changes record or the finding body.
* Use prose and short lists for explanation, tables for compact coverage and decisions, and backticks for code, commands, and symbols. Keep paths plain-text and workspace-relative under the shared tracking convention. Include a Mermaid diagram only when it clarifies a material relationship or drift, distinguishing intended from observed behavior.
* When no substantive findings exist, say so within the assessed boundary. Retain validation limits and residual work without inventing `RV-xxx` entries or implying unassessed scope passed.

The parent maintains Current Disposition inside Parent Decision Record as a readable projection of the latest Decision History events. Show final execution, outcome and reason, finding dispositions and next actions, pending decisions, and the event IDs that support them. Before decisions exist, say `pending`; do not substitute the builder's proposal.

Append events first, then refresh the projection before closeout or handoff. On recovery, events govern any stale projection. The entire Parent Decision Record remains outside worker write authority.

## Review method

The primary parent resolves scope, acceptance basis, depth, artifact readiness, and one review worker, initializes the canonical review record, and dispatches that worker. The worker owns the evidence comparison and review-document body. The parent owns only final outcome and route decisions in `## Parent Decision Record`, parent state, conversation, and continuation.

The selected review worker performs one marker-driven pass:

1. Compare plan requirements and each task's `Requirements:` block with completed `Pxx` and `Pxx-Txx` evidence.
2. Reconcile implementation-time plan updates with current phase and task Goals, Requirements, Details, Guidance, References, triggering evidence, user decisions, and critique state.
3. Check critique finding dispositions and whether significant changes preserved confirmed intent before affected work continued.
4. Assess every `## Follow-Up Items` entry for scope separation, rationale, owner, and changes-record parity.
5. Evaluate completed-work summaries, validation, blockers, remaining work, and intended behavior for material drift.
6. Write one complete substantive `RV-xxx` finding set, proposed outcome, and proposed routes in the review record.

Do not dispatch other review workers. The selected worker cannot delegate. Inspect existing review state first; `started`, Complete, Partial, or Blocked consumes the invocation. An existing record uses its latest participation event and never restores pre-record preference state. If existing builder execution lacks a canonical participation event, stop final execution Blocked and outcome Not accepted.

For a new Review, inspect available skills and subagents. A candidate is phase-matched when its stable name contains `review` or `reviewer`, or its description explicitly says it is used during review; use it only when its description also fits evidence comparison and review-document construction for the current task. Exclude `rpi-review` itself and other RPI lifecycle phase entrypoints. Activate useful matching skills as scoped review criteria. Prefer one matching subagent, but do not require a named RPI worker. When none fits, select an unnamed general-purpose subagent by omitting the agent selection and prompt it with the review purpose, exact evidence, output path, compact return, write boundary, and review restrictions. Check the selected dispatch path before reservation and retain that result. Initialize the record, persist opening state, append the participation event, and replace pre-record preference with the record pointer before any `started` reservation or unavailable terminal event. When subagent dispatch is unavailable, record builder metadata as `Blocked (not dispatched: unavailable)` plus final execution Blocked and outcome Not accepted with the exact later-new-review condition; do not write `started` or compare inline. Those terminal records consume the current Review. When available, persist worker identity, candidate identity, depth, provenance, and `started` before dispatch. A stranded `started` resolves to final execution Blocked and outcome Not accepted with a later-new-review condition.

## Review depth

| Depth      | Selection rule        | Builder behavior                                                                                                                                                                                                            |
|------------|-----------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `standard` | Default               | Completely assess every material acceptance contract once as quickly as evidence permits, follow markers and direct evidence, and omit restatement, cosmetics, exhaustive strengths, low-impact suggestions, and narration. |
| `deep`     | Explicit user request | Trace the same supplied boundary more broadly, stress-test alternatives and boundaries, and include substantive lower-severity concerns without open-ended research, nested workers, or another pass.                       |

Do not infer deep review from task size, complexity, uncertainty, or risk. Standard review minimizes elapsed work without reducing complete coverage of material acceptance evidence.

Before comparison, confirm plan markers and task-local context, changes evidence, handoff prose, blockers, remaining work, follow-up items, and validation state are current. Stop as Blocked when stale or missing evidence prevents a credible task boundary.

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

Each builder-authored `RV-xxx` finding names severity, the binding requirement or accepted direction, expected versus observed behavior, evidence, impact, a checkable resolution condition, and proposed destination. Missing evidence is an explicit limitation or evidence gap, not proof of a defect. The primary parent records one disposition for each route: accepted, rejected, deferred, or changed, with rationale and next action.

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
* Review depth: [standard default or explicit-user deep]
* Comparison boundary: [evidence comparison and its limit]
* Authority: [selected review worker writes the review body; parent owns outcome, routes, and continuation]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

This is the starting review state and may evolve only through the existing evidence-comparison, finding, validation, and routing rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent readiness, acceptance support, links, or an outcome before comparison supports one.

The parent does not narrate review-worker internals. In standard mode, send no continual review updates unless worker execution is Partial or Blocked, a parent decision is required, or the final record is ready. In deep mode, the same materiality gate applies. Persist parent-owned outcome and route dispositions before projecting them in conversation.

Send a continual update only when the item changes review direction, execution status or outcome, a material finding or artifact state, a blocker or decision need, validation state, routing or handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw worker returns, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted:

```markdown
### [Marker when useful] [Review state]: [Short item]

Evidence: [comparison basis and relevant Markdown links]

Review consequence: [effect on execution status, outcome, RV finding, validation coverage, or routing]

Next review action: [next comparison, validation assessment, focused question, route, closeout, or stop]
```

Use `✅` only for evidence-backed conformance, a completed comparison, or passed validation. Use `⚠️` for a substantive finding, residual work, failed, skipped, or unavailable validation, or a decision or evidence gap. Use `⛔` when review progress is blocked. Markers are optional and must be paired with text.

The selected review worker never asks the user questions. The parent uses the Review Item Walkthrough below when decision participation is user-owned or user-retained. Confirmed automatic RPI Agent and rpi-quick use agent-owned decisions by default and skip the walkthrough unless the user explicitly retains Review decisions.

At closeout, report review execution status separately from outcome. Include results, material findings, decisions, blockers or open items, and anything the user might otherwise miss. Advise `/compact` only when stale output, superseded reasoning, or completed comparison detail outweighs current context and the review record and compared artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For standalone review, remain read-only and advise the exact `/rpi-implement`, `/rpi-plan`, or `/rpi-research` command only when an actionable finding needs that destination. Do not invoke it and do not require a second Review after later implementation. Otherwise state the no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the record to the parent as the task's one Review result. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, follow-up choice, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Parent decision protocol

After the builder returns, the primary parent reads the review record once and decides:

* Final review execution status and outcome
* Accepted, rejected, deferred, or changed disposition for every proposed route
* Whether a significant decision returns to `rpi-plan`, an evidence gap returns to `rpi-research`, a defect becomes later `rpi-implement`, or residual work enters the follow-up queue
* Standalone advisory or parent-orchestrated continuation

Append those decisions only to Decision History within `## Parent Decision Record`, then refresh its Current Disposition from the latest events. Preserve builder findings and comparison tables as evidence. When parent state exists, store one pointer containing the review path, latest decision event ID, and record revision or hash, plus derived `next_action` and accepted follow-up projections.

Do not duplicate decision payloads in state, redo the review, rewrite findings to fit a preferred outcome, dispatch another builder, or let the builder transition phases.

Parent Decision Record is the recovery authority. Give each event a stable `RD-xxx` ID and subject, and never rewrite or remove prior events. The latest event for a subject is current. On recovery, rebuild stale or missing state projections from the record; when state conflicts, the record governs and the corrected projection must persist before transition.

## Review Item Walkthrough

Resolve decision participation before route disposition:

| Context                                                     | Mode            | Behavior                                                                                                           |
|-------------------------------------------------------------|-----------------|--------------------------------------------------------------------------------------------------------------------|
| Standalone or manual RPI Review                             | `user-owned`    | Walk through each actionable finding separately and persist the answer before the next item.                       |
| Confirmed automatic RPI Agent                               | `agent-owned`   | Skip item questions and decide proposed routes from evidence before the separate post-Review follow-up checkpoint. |
| Automatic RPI Agent with explicit retained Review decisions | `user-retained` | Keep the session automatic, walk through findings, then resume after decisions are recorded.                       |
| rpi-quick                                                   | `agent-owned`   | Skip the walkthrough unless the user explicitly requested Review decisions.                                        |

For each user-owned or user-retained `RV-xxx`, first persist the pending item. Then present the review record and cited evidence as Markdown links and explain in approachable language:

* What the review found and what scope it affects
* Why it matters and what could happen if it is not addressed
* The builder's proposed destination and the parent's suggested answer
* Material uncertainty and whether more evidence could change the decision

Use `vscode_askQuestions` when available with one finding per turn. Configure freeform input and offer:

* `Use suggested action: [plain-language action]`, marked recommended
* `Gather more information`
* `Skip this item`
* `Finish review decisions`

The freeform box lets the user provide another route, owner, rationale, constraint, or evidence request. When the tool is unavailable, show the same options in chat and wait.

Append each response as an `RD-xxx` event before continuing. Suggested action accepts or changes the route as described. Gather more information defers the decision and assigns the smallest evidence action to the appropriate owner. Skip rejects the proposed route but preserves the finding and its final-outcome consequence. Finish stops the walkthrough and appends deferred events for all undecided findings. If a response is ambiguous, ask one clarification about that item rather than moving forward. Do not ask for acknowledgment when no actionable findings exist.

Material skipped or deferred findings prevent `Conformant` and `Conformant with justified divergence`. A credible completed review may still use Defects found or Residual work; reserve Not accepted for blocked evidence or unresolved critical boundaries that prevent acceptance. Record whether the walkthrough completed, finished early, or was skipped automatically, including decided and remaining finding IDs.

## Review Closeout Projection

At closeout, project builder execution, final review execution status, final outcome, validation coverage, blockers, and the parent disposition for every actionable finding. Keep Complete, Partial, or Blocked execution separate from Conformant, Conformant with justified divergence, Defects found, Residual work, or Not accepted outcome.

Preserve the four-destination matrix: implementation defects go to `rpi-implement`; decision gaps and invalid assumptions go to `rpi-plan`; material evidence gaps go to `rpi-research`; and non-blocking residual work goes to a distinct follow-up owner. Do not describe residual work as a defect. When more than one category occurs, state each distinct destination rather than selecting one aggregate route.

For standalone use, provide only the eligible advisory command or no-handoff reason. In parent contexts, return the same projection to the parent, which owns continuation. The linked-artifact table follows this projection, immediately before the final `## Next Steps` section.
