---
name: rpi-review
description: "Compare RPI planning and implementation evidence, record review findings, and route follow-up work. Use when an implementation needs acceptance review."
argument-hint: "[task=...] [plan=...] [details=...] [changes=...] [depth={focused|deep}]"
license: MIT
user-invocable: true
---

# RPI Review

## Goal

Produce one focused, evidence-based review record after implementation finishes. Use one `RPI Review Builder` to compare the complete supplied acceptance boundary and build the review document quickly. The primary review parent owns the final outcome, every route disposition, continuation, and user conversation.

## Flow

1. Resolve one task artifact set: current plan, phase details, latest plan critique, changes record, and relevant research. Use supplied paths or the stable task slug and date. Stop if multiple unrelated sets remain ambiguous.
2. Resolve review depth. Use `focused` by default. Use `deep` only when the user explicitly requests a deep review; do not infer it from task size, complexity, uncertainty, or risk. Record depth and provenance.
3. Confirm plan markers, phase details, changes evidence, handoff prose, blockers, remaining work, follow-up items, and validation state are reconciled enough to form a credible review boundary. Inspect the review path and parent state when present. An existing builder execution of `started`, Complete, Partial, or Blocked consumes the one builder invocation; reconcile that record and do not dispatch a replacement.
4. When no builder execution exists, create only the canonical record skeleton at `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md` using [templates/review-log.md](templates/review-log.md). Persist Scope and Evidence, Opening Review State, builder candidate identity, depth and provenance, and builder execution `started` before dispatch. Do not dispatch if this write fails.
5. Dispatch exactly one `RPI Review Builder` with the stable task identity, review depth and provenance, exact scope, acceptance basis, complete artifact set, exact read boundary, canonical template, review-record path, and write authority limited to the review record except `## Parent Decision Record`.
	* In focused depth, require thorough coverage of every material contract in the supplied boundary while preferring speed: one marker-driven comparison, directly relevant reads only, concise findings, and no restatement, cosmetic feedback, exhaustive strengths, low-impact suggestions, continual narration, or additional workers.
	* In deep depth, permit broader cross-evidence tracing and substantive lower-severity concerns within the same supplied boundary. Deep does not permit open-ended research, nested workers, or a second review pass.
	* The builder writes the evidence body, one complete `RV-xxx` finding set, proposed execution status and outcome, validation coverage, limitations, and proposed routes. The builder does not ask the user, mutate parent state, select continuation, or invoke a destination.
6. Read the completed review record and compact builder return once. Do not redo the evidence comparison or dispatch another review worker. A Partial or Blocked builder result is terminal for this Review and must name the unassessed boundary or blocker. On recovery, `started` without a trusted terminal record or return is also terminal: record final Review Blocked in Parent Decision Record, preserve the stranded-attempt evidence, and name the exact condition for a later new Review after the ambiguity or path problem is resolved.
7. As the primary review parent, decide the final execution status and outcome and accept, reject, defer, or reroute every builder proposal from evidence. Update only the review record's `## Parent Decision Record`; preserve the builder-authored summary, evidence, findings, and proposed routes. Record the same decisions in parent state when present.
8. Route each accepted actionable gap once: implementation defects to a later `rpi-implement`, significant or divergent decision gaps to `rpi-plan`, material evidence gaps to `rpi-research`, and residual work to a distinct follow-up. Keep unresolved plan follow-ups distinct from defects and active scope. A later implementation does not require another Review.
9. Return the record, builder execution, final review execution status and outcome, validation evidence, findings, parent route dispositions, and next action.

## Inputs

* Stable task identity and requested review scope: full task, `Pxx`, or `Pxx-Txx`
* Current plan, phase details, latest plan critique, changes record, relevant research, validation, blockers, remaining work, and follow-up items
* Review depth and provenance: `focused` by default or `deep` only from explicit user direction
* Canonical review-record path and parent orchestration context when present

## Success criteria

* One review record exists at the canonical path and includes all compared artifacts, review depth and provenance, builder execution, and parent decisions.
* Exactly one `RPI Review Builder` invocation builds the evidence body and complete finding set for the supplied task boundary; no generic lens fan-out or nested worker runs.
* Builder execution `started` is persisted before dispatch; started and terminal records prevent another builder invocation on resume.
* A stranded `started` record resolves to final Review Blocked with a later-new-review condition and never causes replacement dispatch.
* Focused depth is the default and remains thorough over the material acceptance boundary while omitting low-value review work. Deep occurs only from explicit user direction.
* The record separates execution state from outcome verdict.
* Findings are substantive, evidence-grounded, severity-graded `RV-xxx` records with an explicit destination.
* Defects, decision gaps, research gaps, and residual work are routed to distinct destinations.
* Descriptive implementation-time plan and detail updates, their rationale and evidence, material revision readiness, and plan follow-up items are explicitly assessed.
* Validation evidence is recorded or explicitly unavailable or skipped with a reason.
* Findings are routed clearly without creating closure, correction, full, targeted, or amended review modes.
* The primary parent records the final outcome and each accepted, rejected, deferred, or changed route without rewriting builder evidence.

## Constraints

* Do not implement fixes or mutate the plan, phase details, critique, research, or changes record in this stage. Review may create or update only its one canonical review record.
* Use only `RPI Review Builder` for review assessment and document construction. Do not dispatch generic lenses, per-phase workers, or another review builder. If the required builder is unavailable, stop Blocked and name the rerun condition rather than building the evidence body inline.
* Treat builder findings, proposed outcome, and routes as advisory evidence. The primary parent owns final decisions, parent state, user conversation, continuation, and follow-up selection.
* Use plain-text workspace-relative paths in the review record.
* Use [references/review.md](references/review.md) for the review method, outcome vocabulary, routing detail, and conversation protocol.

## Conversation guidance

Use [references/review.md](references/review.md) as the authority for the state-first opening, materiality gate, continual-update template, marker meanings, pre-question context, and closeout behavior. Persist review-owned state before an opening or potential material update; chat is a concise projection, never a second history or delivery log. Preserve the read-only boundary, separate execution status from outcome, standalone versus parent continuation, conditional compaction, and linked Markdown table. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, follow-up choice, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Stop rules

* Stop as Blocked if a reviewable artifact set cannot be formed, the required builder is unavailable, or evidence is insufficient for a credible verdict.
* Stop as Not accepted when material defects or unaccepted decision gaps remain.
* Complete a partial review only when the record names the evidence boundary and routes the missing work.
* Do not dispatch the builder again after Complete, Partial, or Blocked. Parent decisions and later remediation do not create a review loop.
* Do not replace a stranded `started` builder. End the current Review as Blocked and state the exact condition for a later new Review.

## Handoff

Return the review record, builder execution, final review execution status, final outcome, severity summary, validation coverage, parent route dispositions, and next RPI stage or distinct follow-up. A standalone review advises the exact `/rpi-*` command only when an accepted finding needs that destination and does not invoke it. In `rpi-quick` or confirmed automatic RPI Agent mode, return the record and parent decisions to the orchestrator.

## Final response

Return review execution status separately from outcome, findings, validation coverage, blockers or open items, routed follow-up, and conditional compaction advice when warranted. Follow Conversation guidance for standalone or parent-orchestrated continuation, the linked artifact table, and final next steps.


