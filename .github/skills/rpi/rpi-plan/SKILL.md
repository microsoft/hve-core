---
name: rpi-plan
description: "Create evidence-based RPI plans and phase details from supplied context, research, drafts, and decisions. Use when implementation planning is needed."
argument-hint: "[task=...] [research=...] [context=...] [draft=...] [decisions=...]"
license: MIT
user-invocable: true
---

# RPI Plan

## Goal

Produce an implementation-ready, ordinary Markdown plan and separate phase details. Record user intent in a concise freeform `## User Decisions and Requirements` list, then maintain independently editable planner-synthesized goals, scope, requirements, and acceptance criteria. The primary planner owns both artifacts, orchestration, revisions, critique timing, and the final readiness decision.

Read [references/planning.md](references/planning.md) for readiness, executive-summary, delegation, and artifact guidance.

## Flow

1. Establish the task identity and build `## User Decisions and Requirements` from user prompts, user-pointed external documents, tasks, issues, and prior research that captures the user's task, goals, requirements, or accepted decisions. Preserve the user's meaning without forcing entries into categories. Distinguish evidence, assumptions, and open choices. Treat supplied evidence as the starting point, not as a reason to repeat investigation.
2. Create or revise these artifacts with one stable task ID, current `Pxx` phase IDs, and current `Pxx-Txx` task IDs. Initialize and maintain the plan's `## Follow-Up Items` section for discovered work outside the active approved plan.
   * `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
   * `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
3. Before substantive phase drafting or delegation, persist the canonical planning state in the plan and phase-details sections that own it. Record task identity, interpreted planning goal, user decisions and requirements, goals, scope and non-goals, initial evidence and readiness assessment, active boundaries, unresolved decisions or blockers, and resolved artifact paths when applicable. The plan owns task-wide state; phase details own the initial phase direction and task-level context.
4. Send one canonical `RPI Plan` opening after that state is persisted and before substantive phase drafting or delegation. Follow the opening shape in [references/planning.md](references/planning.md).
5. Assess supplied and completed evidence against goals, requirements, acceptance criteria, dependencies, material risks, complexity, uncertainty, and decision-critical choices. Reuse adequate evidence and activate `rpi-research` only when one of those dimensions reveals a demonstrated planning gap.
6. Use [templates/implementation-plan.md](templates/implementation-plan.md) for the overall plan and [templates/implementation-details.md](templates/implementation-details.md) for evidence-based phase detail. Keep `## User Decisions and Requirements` as a concise freeform list, with optional source pointers in entries when useful. Before `## Phase Checklist`, maintain separate top-level `## Goals`, `## Scope and Non-Goals`, `## Functional Requirements`, `## Non-Functional Requirements`, and `## Acceptance Criteria` sections. Synthesize and update those sections from current user input and evidence without duplicating the list. Follow the executive-summary protocol, placing the summary after task metadata and before sources, and keep it synchronized with every material plan change. Put contextual phase and task markers immediately before their headings.
7. Use one or more `RPI Planner` subagents for bounded planning assignments. A dispatch may refine phase details, examine supplied evidence, propose decisions or options, expose assumptions, or challenge and refute current goals, phases, or tasks with counter-evidence. Give each dispatch the exact artifacts, relevant evidence, assignment, allowed write boundary, and expected return. Run independent assignments in parallel and dependent assignments sequentially. The primary planner evaluates every return and decides whether to add, update, delete, recreate, reorder, split, merge, or replace goals, scope, non-goals, requirements, acceptance criteria, phases, tasks, or details. Subagent output does not automatically become plan content.
8. Apply a clear user decision or requirement change directly, without a redundant question. When a decision-critical change remains unclear, use a small focused `vscode_askQuestions` set. Before asking, send a conversation message that states the affected user decision or requirement and plan area, the evidence or conflict, viable choices, material consequences, a recommendation when evidence supports one, and Markdown links to relevant planning artifacts, documents, code, or authoritative external sources when available. Apply the user's answer to the freeform list and all affected synthesized sections. Reconcile current sections, IDs and markers, dependencies, executive summary, details, and `## Follow-Up Items` after every material revision.
9. Keep the stable overall task ID and current `Pxx` and `Pxx-Txx` markers for navigation. During planning, the primary planner may add, update, delete, recreate, reorder, split, merge, or replace phases and tasks, and may renumber current IDs so the plan and details remain aligned. Remove obsolete active content rather than retaining it for identifier history.
10. Run the internal critique gate only when the primary planner judges both the plan and phase details to be implementation-ready candidates.
   * Dispatch a fresh critique worker that activates `rpi-plan-critique` with the exact task context, caller requirements, research and evidence pointers, plan and details paths, current user decisions and requirements, dependencies, acceptance criteria, and one critique output path.
   * Give the critique worker read access to the supplied evidence and write access only to the critique artifact. Do not critique an initial draft merely because it exists.
   * Record findings and dispositions in the plan's standalone top-level `## Critique Disposition` section.
   * Revise directly, use bounded planning assignments, obtain a decision, or rerun critique as the findings require.
   * Finalize only when the latest critique passes, or when blocking findings are resolved and every accepted residual risk has an explicit permitted disposition.
11. Prepare the plan, phase details, critique, and downstream changes-record path for the next stage. Treat executive-summary synchronization as a readiness condition. The implementation phase owns creation of `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`.

## Inputs

* Task context and caller requirements
* Completed or supplied research and evidence pointers
* Draft plan details, decisions, dependencies, and acceptance criteria when available
* Existing plan and phase-details artifacts when resuming

## Success criteria

* The plan and phase-details artifacts use the prescribed plain Markdown paths and contain no `applyTo` metadata.
* The plan has one stable task ID, a near-top user-facing executive summary, a concise freeform `## User Decisions and Requirements` list, separate current synthesized sections for goals, scope and non-goals, functional requirements, non-functional requirements, and acceptance criteria, current phase and task IDs with contextual markers, `## Follow-Up Items`, and a clear handoff.
* The primary planner maintains both artifacts and evaluates all bounded subagent returns before revising active content.
* Details provide evidence-based context and completion expectations for every planned task without prescribing unsupported choreography.
* Research is activated only for a demonstrated readiness gap.
* Critique begins only after both artifacts are implementation-ready candidates, and the latest critique outcome plus dispositions are recorded before finalization.

## Constraints

* Keep planning evidence-based. State assumptions and unresolved items when evidence does not support a local choice.
* The primary planner retains ownership of the complete plan and phase details while using bounded `RPI Planner` assignments as needed.
* Do not create separate legacy log artifacts, line-number references, line-refresh work, or detail-line verification.
* Do not implement production changes in this phase.
* Keep follow-up items outside active `Pxx` and `Pxx-Txx` completion and acceptance claims.
* Use plain-text workspace-relative paths in tracking artifacts.

## Conversation guidance

* Follow the detailed opening, continual-update, pre-question, and closeout protocol in [references/planning.md](references/planning.md). That reference is the authority for the rendered message templates.
* Before substantive phase drafting or delegation, persist canonical planning state, then send one phase-specific opening. Before each potential continual update, persist the item in the plan, phase details, or critique disposition that owns it. Chat is a concise projection of that state, never a second history or delivery log.
* Send an update only when the item changes phase direction, a current decision or readiness state, a material result or artifact state, a blocker or decision need, validation state where applicable, handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw subagent returns, unchanged state, and minor rows or edits. Distinguish settled decisions from proposals and unresolved items.
* Before asking a user question, state the affected decision, viable choices and consequences, an evidence-backed recommendation when available, blockers, and relevant Markdown links.
* Use a status marker only when it improves scanning and pair it with text. `✅` denotes an evidence-backed settled decision or achieved readiness, `⚠️` a proposal, unresolved item, critique concern, or revision need, and `⛔` a blocker.
* At closeout, separate planning execution status from planning readiness or decision state. Summarize results, important updates, decisions, blockers or open items, and anything the user might otherwise miss.
* Advise `/compact` only when stale tool output, superseded reasoning, or completed-stage detail outweighs useful current context and the plan, phase details, and critique artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* In a standalone invocation, do not invoke `rpi-implement`. State `/rpi-implement` as the exact next command only when the plan is implementation-ready. Otherwise state the explicit stop or no-handoff reason. In an active `rpi-quick` or confirmed automatic RPI Agent context, state that the parent continues to the eligible next stage automatically unless a blocker or required confirmation returns control to the user.
* End the user-facing closeout with a Markdown table that links every relevant existing artifact and gives each a short description. The table is the final response element.

## Stop rules

* Stop as Blocked when the task, required acceptance criteria, or a decision-critical evidence gap cannot be resolved responsibly. When a required clarification remains unavailable after `vscode_askQuestions`, preserve the unresolved item and do not guess.
* Stop as Revise when critique findings require plan changes that remain open.
* Finalize when the plan is credible for implementation, the latest critique passes or blocking findings are resolved, and any accepted residual risk is explicitly disposed.

## Handoff

The critique gate returns to this planning parent and is not a peer lifecycle transition. For a standalone implementation-ready plan, advise the user to run `/rpi-implement` with `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` as its changes-record path. Do not invoke the peer stage. In `rpi-quick` or confirmed automatic RPI Agent mode, return the ready artifacts to the parent so it can continue automatically after all gates and required confirmations pass.

## Final Response

Return a concise user-facing version of the executive summary, covering planning execution status, planning readiness, important decisions and consequences, information the user may not immediately know, and unresolved decisions or blockers. Follow the Conversation guidance section for conditional compaction advice, standalone or parent-orchestrated continuation, and the final linked artifact table.


