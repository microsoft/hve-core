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

The plan critique is present only when one ran. Read research when it is relevant to an evidence or decision gap. Use markers and stable IDs rather than line references.

## Review document contract

Use `templates/review-log.md` for one record that a person can review and a later RPI stage can act on. Lead with Executive Summary, What You May Not Know, Findings and Proposed Routes, and Parent Decision Record. Put validation, risks, and the detailed Review Record afterward.

* Keep the Executive Summary concise and explicit about its assessed scope, assessed outcome, material findings, validation, and limits. Label the assessed outcome and routes as proposals until Parent Decision Record records the decisions.
* Use What You May Not Know for a material behavior change, justified divergence, or evidence limit that changes the reader's interpretation. State `None` rather than manufacturing additional concerns.
* Order findings by severity and impact. Give each a descriptive heading and plain-language explanation, then keep its requirement, expected behavior, observed evidence, consequence, resolution condition, and proposed route together. State when behavior is unassessed rather than implying a demonstrated defect.
* Describe the outcome or evidence needed to resolve a finding, not a mandatory patch recipe. Preserve local implementation judgment unless an accepted requirement or interface fixes the solution. Label non-binding examples as illustrative.
* Record acceptance and change coverage once in the Review Record. Group related markers only when each remains identifiable and shares the evidence and assessment. Assess material plan updates and confirmed decisions without duplicating the changes record or the finding body.
* Use prose and short lists for explanation, tables for compact coverage and decisions, and backticks for code, commands, and symbols. Keep paths plain-text and workspace-relative under the shared tracking convention. Include a Mermaid diagram only when it clarifies a material relationship or drift, distinguishing intended from observed behavior.
* When no substantive findings exist, say so within the assessed boundary. Retain validation limits and residual work without inventing `RV-xxx` entries or implying unassessed scope passed.

## Review method

The skill's Flow step 6 runs one comparison pass. The parent compares the portions it keeps itself and reconciles lane returns for the rest. The comparison pass:

1. Compare plan requirements and each task's `Requirements:` block with completed `Pxx` and `Pxx-Txx` evidence.
2. Reconcile implementation-time plan updates with current phase and task Goals, Requirements, Details, Guidance, References, triggering evidence, user decisions, and critique state.
3. Check critique finding dispositions when a critique ran, and whether significant changes preserved confirmed intent before affected work continued.
4. Assess every `## Follow-Up Items` entry for scope separation, rationale, owner, and changes-record parity.
5. Evaluate completed-work summaries, validation, blockers, remaining work, and intended behavior for material drift. When business sources are cited or Business Alignment entries exist, include the comparison in `business-alignment.md`.
6. Write one complete substantive `RV-xxx` finding set, assessed outcome, and proposed routes in the review record.

## Optional helpers

The review parent owns the comparison. A subagent is never required, and no review gate depends on one. Use subagents only under the subagent-use rule in the skill's Flow; otherwise do the whole comparison yourself.

Use subagents to keep the review fast and your context focused. Give each context-heavy, independent portion of the comparison its own narrow lane, such as one task's requirements, scoped from the plan's phase, task, and requirement IDs and the changed-file list; a lane's time grows with how much it reads. Dispatch the lanes in one parallel batch right after you initialize the record, before you read the evidence they cover, and compare the portions you keep while they run, so their work does not repeat yours. Good lanes include comparing one phase's `Requirements:` blocks against the changes record and diff, tracing one requirement through source and validation output, checking a long critique's dispositions against the current plan, and, for a large review, the tool checks below. Keep tightly coupled or low-volume comparison yourself, including a check that takes only a few tool calls.

Prefer a helper whose description says it is used during review, such as `RPI Reviewer`; a general-purpose subagent given the same instructions also works. Assign each lane one bounded question or comparison in your own words, its purpose (which acceptance decision depends on it), the evidence paths to read, the acceptance basis to compare against when the lane needs one, the scope, and what to exclude or ignore. Name the requirement, finding, or change to compare without stating the outcome you expect, so the lane compares rather than confirms. Tell a general-purpose helper not to dispatch other agents. It does not need an `RV-xxx` ID, a `Pxx` or `Pxx-Txx` boundary, or the full review context. Expect candidate findings with expected behavior, observed evidence and location, why each may matter, and suggested severity and route, plus the evidence location for each requirement it found consistent and what it could not assess. `RPI Reviewer` runs on `Claude Haiku 5.5 (copilot)` from its frontmatter; give a general-purpose helper the same model when the dispatch tool accepts it, and pass a different model only when the user names one.

### Lane reasoning effort

Select each lane's reasoning effort when you dispatch it, from what the lane must judge:

* `low` when a tool answers the check completely: every checked `Pxx-Txx` marker has a changes-record entry, the recorded status of each validation check, the changed files against the plan's targets, or requirement-ID cross-references.
* `high` when the lane compares work against a written acceptance basis, such as `Requirements:` blocks, implementation-time plan updates, follow-up items, or critique dispositions, or checks written guidance for consistency across files.
* `max` when the lane must judge behavior that no written requirement states, such as runtime behavior, security, destructive or irreversible changes, or contracts across code files, such as callers, types, or data formats. When one lane does both kinds of judgment, use `max`. In `deep` depth, use `max` for every lane that is not a tool check.
* When the user or caller sets an effort, for every lane or for lanes identified by kind or topic, use it instead.

Pass the level through the dispatch tool's reasoning-effort parameter, such as `reasoning_effort`. `RPI Reviewer` declares `max` in its frontmatter, so a dispatch that sets no effort runs at `max` where the host applies agent frontmatter; give a general-purpose helper its level explicitly. When the tool has no such parameter, dispatch without one and record the effort as host default. If a dispatch fails because its model does not support the selected effort, retry it once with `reasoning_effort` set to `medium`, and record the lane's effort as `medium` with that reason.

### Using lane returns

Treat each return as suggestions. Read the cited evidence yourself, go deeper on any candidate that needs it, record an `RV-xxx` finding only when you confirm it, and assign IDs, execution status, outcome, and routes yourself. Count a requirement as consistent only when the lane cites where it is met, and read that location yourself before a material requirement supports a conformant outcome. Treat a requirement reported consistent without a location as not assessed, and compare it yourself. Helpers do not write the review record, ask the user, or decide anything. Record each lane in Scope and Evidence with its question, its reasoning effort and that effort's source (selected, user- or caller-set, frontmatter default, or host default), and what was verified.

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

Each `RV-xxx` finding names severity, the binding requirement or accepted direction, expected versus observed behavior, evidence, impact, a checkable resolution condition, and proposed destination. Missing evidence is an explicit limitation or evidence gap, not proof of a defect. The review parent records one disposition for each route: accepted, rejected, deferred, or changed, with rationale and next action.

* Route implementation defects that fit the current accepted direction to a later `rpi-implement` invocation.
* Route significant or divergent decisions or invalid plan assumptions to `rpi-plan`.
* Route material evidence gaps to `rpi-research`.
* Route non-blocking residual work to a distinct follow-up item with a clear owner or next action.

Route an unresolved plan follow-up item to its distinct follow-up work owner or next action. It is not a defect or a new active plan task merely because review found it still open. Do not convert residual work into a defect merely to force implementation, and do not create a new active plan revision during review. When findings fall into more than one category, state each distinct destination rather than selecting one aggregate route.

## Validation evidence

Record relevant validation as passed, failed, skipped, or unavailable. Failed checks are review evidence, and skipped or unavailable checks need a reason. Do not claim unrun validation passed.

## Conversation protocol

The opening state that the skill's Flow step 5 persists records the interpreted review goal, scope, depth and provenance, evidence readiness, acceptance basis, comparison boundary, decision authority, and initial blockers. After persisting it, send one opening message:

```markdown
## RPI Review: [Task] | [Full task, Pxx, or Pxx-Txx scope]

[Interpreted review goal.]

* Review scope: [full task, Pxx, or Pxx-Txx scope]
* Evidence set and readiness: [available compared artifacts and readiness]
* Acceptance basis: [requirements, acceptance criteria, critique dispositions, or other review basis]
* Review depth: [standard default or explicit-user deep]
* Comparison boundary: [evidence comparison and its limit]
* Authority: [review parent compares evidence, writes findings, and owns outcome, routes, and continuation]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

This is the starting review state and may evolve only through the existing evidence-comparison, finding, validation, and routing rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent readiness, acceptance support, links, or an outcome before comparison supports one.

Do not narrate comparison internals. In standard mode, send no continual review updates unless execution is Partial or Blocked, a decision is required, or the final record is ready. In deep mode, the same materiality gate applies. Persist outcome and route dispositions before projecting them in conversation.

Send a continual update only when the item changes review direction, execution status or outcome, a material finding or artifact state, a blocker or decision need, validation state, routing or handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw helper returns, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted:

```markdown
### [Marker when useful] [Review state]: [Short item]

Evidence: [comparison basis and relevant Markdown links]

Review consequence: [effect on execution status, outcome, RV finding, validation coverage, or routing]

Next review action: [next comparison, validation assessment, focused question, route, closeout, or stop]
```

Use `✅` only for evidence-backed conformance, a completed comparison, or passed validation. Use `⚠️` for a substantive finding, residual work, failed, skipped, or unavailable validation, or a decision or evidence gap. Use `⛔` when review progress is blocked. Markers are optional and must be paired with text.

## Parent decision protocol

Give each Decision History event a stable `RD-xxx` ID and subject; the latest event for a subject is current. Record each route's disposition as accepted, rejected, deferred, or changed. Do not redo the comparison or rewrite findings to fit a preferred outcome.

Current Disposition shows final execution, outcome and reason, finding dispositions and next actions, pending decisions, and the event IDs that support them. Before decisions exist, say `pending`; do not substitute the assessed proposal. Append events first, then refresh Current Disposition before closeout or handoff.

Parent Decision Record is the recovery authority. On recovery, rebuild stale or missing state projections from its events; when state conflicts, the record governs and the corrected projection must persist before transition.

## Review Item Walkthrough

For each user-owned or user-retained `RV-xxx`, first persist the pending item. Then present the review record and cited evidence as Markdown links and explain in approachable language:

* What the review found and what scope it affects
* Why it matters and what could happen if it is not addressed
* The proposed destination and the suggested answer
* Material uncertainty and whether more evidence could change the decision

Use the host's question tool, such as `vscode_askQuestions`, when available, with one finding per turn. Configure freeform input and offer:

* `Use suggested action: [plain-language action]`, marked recommended
* `Gather more information`
* `Skip this item`
* `Finish review decisions`

The freeform box lets the user provide another route, owner, rationale, constraint, or evidence request. When the question tool is unavailable, present the same choices in chat and wait.

For an alignment finding routed as residual work, offer to draft a note to the source owner only when the finding records meaningful drift or a confirmed divergence. Do not offer a note for a stale-source or source-gap alert without a separate demonstrated drift result. `business-alignment.md` defines the action text, how the user keeps the follow-up without the note, and what an accepted note contains.

Append each response as an `RD-xxx` event with its finding, route, owner, rationale, evidence need, and outcome effect before continuing. Suggested action accepts or changes the route as described. Gather more information defers the decision, or changes the route to the appropriate evidence owner, and assigns the smallest evidence action. Skip rejects the proposed route but preserves the finding and its final-outcome consequence. Finish stops the walkthrough and appends deferred events for all undecided findings. If a response is ambiguous, ask one clarification about that item rather than moving forward. Do not ask for acknowledgment when no actionable findings exist.

Record whether the walkthrough completed, finished early, or was skipped automatically, including decided and remaining finding IDs.
