---
name: rpi-review
description: "Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review."
argument-hint: "[task=...] [plan=...] [changes=...] [depth={standard|deep}]"
license: MIT
user-invocable: true
---

# RPI Review

## Goal

Produce one complete, human-readable, evidence-based review record after implementation finishes. Lead with the scoped assessment and material findings, keep evidence and resolution conditions with each finding, and make the parent's final decisions easy to distinguish from worker proposals.

Use one selected review worker to compare the complete supplied acceptance boundary as quickly as the evidence permits. The primary review parent owns the final outcome, every route disposition, continuation, and user conversation.

Read [references/review.md](references/review.md) for the review document contract, method, outcome vocabulary, routing, and conversation protocol. Use [templates/review-log.md](templates/review-log.md) as the canonical record skeleton.

## Flow

1. Resolve one task artifact set: current task-centered plan, latest plan critique, changes record, and relevant research. Use supplied paths or the stable task slug and date. Stop if multiple unrelated sets remain ambiguous.
2. Resolve review depth. Use `standard` by default. Use `deep` only when the user explicitly requests a deep review; do not infer it from task size, complexity, uncertainty, or risk. Record depth and provenance.
3. Resolve candidate decision participation: `user-owned` for standalone and manual RPI, `agent-owned` by default for confirmed automatic RPI Agent or rpi-quick, and `user-retained` only when an automatic-session user explicitly keeps Review decisions. If the review record already exists, use only its latest Parent Decision Record participation event and ignore pre-record preference state. Record provenance.
4. Confirm plan markers and task-local Goals, Requirements, Details, References, changes evidence, handoff prose, blockers, remaining work, and follow-up items are reconciled enough to form a credible review boundary. Inspect the review path and parent state when present. An existing builder execution of `started`, Complete, Partial, or Blocked consumes the one builder invocation; reconcile that record and do not dispatch a replacement. If an existing builder execution has no canonical participation event, stop final Review execution Blocked and outcome Not accepted rather than restoring a stale preference.
5. Before creating a worker reservation, inspect available skills and subagents. A candidate's stable name contains `review` or `reviewer`, or its description explicitly says it is used during review; select it only when its description fits evidence comparison and review-document construction for this task. Exclude this skill and other RPI lifecycle phase entrypoints from helper selection. Activate useful matching skills as scoped review criteria. Prefer one matching subagent. When none fits, select an unnamed general-purpose subagent by omitting the agent selection. Retain the selected worker identity or `general-purpose` and dispatch availability without writing `started` or dispatching.
6. When no builder execution exists, create the canonical record skeleton at `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md` using [templates/review-log.md](templates/review-log.md). Persist Scope and Evidence and Opening Review State, append one stable participation event to Parent Decision Record, then, when parent state exists, require one successful state write that removes pre-record preference and stores only the record pointer/revision. Do not continue if any write fails.
   * When subagent dispatch is unavailable, set builder execution metadata to `Blocked (not dispatched: unavailable)`, append final Review execution Blocked and outcome Not accepted with the exact later-new-review condition, and persist only the record pointer and derived projections in parent state. Do not write `started` or compare evidence inline. These terminal records consume the current Review even if availability changes later.
   * When availability passes, persist builder candidate identity, depth and provenance, and builder execution `started` before dispatch. Do not dispatch if this write fails.
7. Dispatch exactly one selected review worker with the stable task identity, review purpose, review depth and provenance, exact scope, acceptance basis, complete artifact set, exact read boundary, canonical template, review-record path, compact return, and write authority limited to the review record except `## Parent Decision Record`. For an unnamed general-purpose worker, explicitly prohibit source, plan, critique, research, changes-record, parent-state, and Parent Decision Record edits; user questions; final outcome or route decisions; destination invocation; and nested delegation.
   * In standard depth, require complete coverage of every material contract in the supplied boundary while minimizing elapsed work: one marker-driven comparison, all directly relevant supplied evidence, concise findings, and no restatement, cosmetic feedback, exhaustive strengths, low-impact suggestions, continual narration, or additional workers.
   * In deep depth, require broader cross-evidence tracing, stress-test alternatives and boundaries, and include substantive lower-severity concerns within the same supplied boundary. Deep does not permit open-ended research, nested workers, or a second review pass.
   * The builder writes the evidence body, one complete `RV-xxx` finding set, proposed execution status and outcome, validation coverage, limitations, and proposed routes. The builder does not ask the user, mutate parent state, select continuation, or invoke a destination.
8. Read the completed review record and compact builder return once. Do not redo the evidence comparison or dispatch another worker. A Partial or Blocked builder result is terminal and must name the unassessed boundary or blocker. On recovery, stranded `started` is also terminal: record final Review execution Blocked and outcome Not accepted, preserve the evidence, and name the exact condition for a later new Review.
9. Resolve every actionable `RV-xxx` according to decision participation. Treat Decision History within `## Parent Decision Record` as the append-only canonical decision log. Append a stable event for each participation, walkthrough, execution, outcome, and route decision; never rewrite an earlier event. Refresh the section's Current Disposition from those events as a reader-facing projection, not an independent decision authority.
   * For `user-owned` or `user-retained`, present one finding at a time. Before asking, link the review record and cited evidence, then explain in plain language what was found, why it matters, the proposed route, consequences, uncertainty, and a suggested answer.
   * Use `vscode_askQuestions` when available. Offer `Use suggested action: [plain-language action]` as the recommended option, `Gather more information`, `Skip this item`, and `Finish review decisions`; allow freeform input so the user also has an empty response box. When unavailable, present the same choices in chat and wait.
   * Append each answer and its finding, route, owner, rationale, evidence need, and outcome effect before asking about the next item. `Gather more information` defers or changes the route to the appropriate evidence owner. `Skip this item` rejects the proposed route without erasing the finding. `Finish review decisions` stops questions and appends deferred events for every undecided item. Material skipped or deferred findings prevent a conformant final outcome.
   * For `agent-owned`, skip all per-item questions, record the walkthrough as `skipped-auto`, and decide every proposal from evidence. Do not treat the later automatic follow-up selection as this walkthrough.
10. Decide final execution and outcome from builder evidence and resolved or deferred findings. Append those events only to `## Parent Decision Record`; preserve builder-authored evidence and findings. When parent state exists, store only the record path and revision plus derived `next_action` and follow-up projections.
11. Route each accepted gap once: implementation defects to later `rpi-implement`, decision gaps to `rpi-plan`, evidence gaps to `rpi-research`, and residual work to a distinct follow-up. A later implementation does not require another Review.
12. Return the record, builder execution, final review execution and outcome, validation evidence, findings, decision participation and walkthrough status, route dispositions, and next action.

## Inputs

* Stable task identity and requested review scope: full task, `Pxx`, or `Pxx-Txx`
* Current task-centered plan, latest plan critique, changes record, relevant research, validation, blockers, remaining work, and follow-up items
* Review depth and provenance: `standard` by default or `deep` only from explicit user direction
* Decision participation: `user-owned`, `agent-owned`, or `user-retained`, with orchestration context and provenance
* Canonical review-record path and parent orchestration context when present

## Success criteria

* One review record exists at the canonical path and includes all compared artifacts, review depth and provenance, builder execution, and parent decisions.
* Exactly one selected review-worker invocation builds the evidence body and complete finding set for the supplied task boundary; no fan-out to additional review workers or nested worker runs. A suitable phase-matched specialist is preferred, with an unnamed general-purpose fallback when none exists.
* Builder execution `started` is persisted before dispatch; started and terminal records prevent another builder invocation on resume.
* A stranded `started` record resolves to final Review execution Blocked and outcome Not accepted with a later-new-review condition and never causes replacement dispatch.
* Standard depth is the default and completely assesses the material acceptance boundary while omitting low-value review work. Deep occurs only from explicit user direction.
* The record separates execution state from outcome verdict.
* Findings are substantive, evidence-grounded, severity-graded `RV-xxx` records with expected versus observed behavior, a checkable resolution condition, and an explicit destination. Supporting detail stays with its finding rather than becoming a separate implementation recipe.
* The document leads with its scoped assessment, material findings, and parent decisions; acceptance coverage is recorded once and missing evidence is not reported as a demonstrated defect.
* Defects, decision gaps, research gaps, and residual work are routed to distinct destinations.
* Descriptive implementation-time plan updates, their rationale and evidence, material revision readiness, and plan follow-up items are explicitly assessed.
* Validation evidence is recorded or explicitly unavailable or skipped with a reason.
* Findings are routed clearly without creating closure, correction, full, targeted, or amended review modes.
* The primary parent records the final outcome and each accepted, rejected, deferred, or changed route without rewriting builder evidence.
* Decision History within Parent Decision Record is append-only and canonical. Its Current Disposition is a synchronized reader-facing projection. Parent state stores only the record's path/revision pointer and derived active-route and follow-up projections; recovery rebuilds projections from the events.
* User-owned and user-retained Review present each actionable finding separately with linked, plain-language context and the required suggested, gather, skip, finish, and freeform choices. Agent-owned automatic Review records decisions without the walkthrough.

## Constraints

* Do not implement fixes or mutate the plan, critique, research, or changes record in this stage. Review may create or update only its one canonical review record.
* Use only the one selected review worker for assessment and document construction. Do not dispatch per-phase workers or another review worker. A named RPI worker is optional: use a phase-and-task-matched subagent when available, otherwise use the unnamed general-purpose fallback. If subagent dispatch itself is unavailable, stop Blocked and name the rerun condition rather than building the evidence body inline.
* Treat builder findings, proposed outcome, and routes as advisory evidence. The primary parent owns final decisions, parent state, user conversation, continuation, and follow-up selection.
* Use plain-text workspace-relative paths in the review record.
* Use [references/review.md](references/review.md) for the review method, outcome vocabulary, routing detail, and conversation protocol.

## Conversation guidance

Use [references/review.md](references/review.md) as the authority for the state-first opening, materiality gate, continual-update template, marker meanings, pre-question context, and closeout behavior. Persist review-owned state before an opening or potential material update; chat is a concise projection, never a second history or delivery log. Preserve the read-only boundary, separate execution status from outcome, standalone versus parent continuation, conditional compaction, and linked Markdown table. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, follow-up choice, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Stop rules

* Stop as Blocked if a reviewable artifact set cannot be formed, subagent dispatch is unavailable, or evidence is insufficient for a credible verdict. Use final outcome Not accepted for Blocked Review execution.
* Do not use Conformant or Conformant with justified divergence while material skipped, deferred, or unresolved findings remain. Use Defects found for a credible review with implementation defects, Residual work for distinct non-blocking work, and Not accepted when blocked evidence or unresolved critical boundaries prevent acceptance.
* Complete a partial review only when the record names the evidence boundary and routes the missing work.
* Do not dispatch the builder again after Complete, Partial, or Blocked. Parent decisions and later remediation do not create a review loop.
* Do not replace a stranded `started` builder. End the current Review as Blocked and state the exact condition for a later new Review.

## Handoff

Return the review record, builder execution, final review execution status, final outcome, severity summary, validation coverage, parent route dispositions, and next RPI stage or distinct follow-up. A standalone review advises the exact `/rpi-*` command only when an accepted finding needs that destination and does not invoke it. In `rpi-quick` or confirmed automatic RPI Agent mode, return the record and parent decisions to the orchestrator.

## Final response

Return review execution status separately from outcome, findings, validation coverage, blockers or open items, routed follow-up, and conditional compaction advice when warranted. Follow Conversation guidance for standalone or parent-orchestrated continuation, the linked artifact table, and final next steps.


