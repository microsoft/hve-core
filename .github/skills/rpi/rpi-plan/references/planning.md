---
description: "Reference protocol for evidence-based RPI planning, bounded phase authoring, and independent plan critique."
---

# RPI Plan Reference

## Artifact paths

Use one date and one lower-kebab-case task slug across the task's durable artifacts.

* `.copilot-tracking/research/{{YYYY-MM-DD}}/{{task_slug}}-research.md`
* `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`
* `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`
* `.copilot-tracking/reviews/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan-critique.md`
* `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md`
* `.copilot-tracking/reviews/logs/{{YYYY-MM-DD}}/{{task_slug}}-review.md`

The research, changes, and review paths belong to their respective RPI stages. Planning creates or revises only the plan, phase details, and critique artifact unless a justified research activation is required.

## Identity and markers

Use one stable task ID throughout the artifact set. Use `Pxx` for phase IDs and `Pxx-Txx` for task IDs. Put each marker immediately before its matching heading:

```markdown
<!-- rpi:phase id=P01 -->
### [ ] P01: Establish the change

<!-- rpi:task id=P01-T01 -->
#### [ ] P01-T01: Update the primary artifact
```

Do not use line numbers, line ranges, detail-line verification, or separate legacy log artifacts. Navigate by task ID, marker, and heading.

Use one stable overall task ID. Keep current `Pxx` and `Pxx-Txx` markers for navigation. During planning, the parent may add, update, delete, recreate, reorder, split, merge, or replace phases and tasks, and may renumber current IDs so the plan and details stay aligned. Remove obsolete active content rather than preserving it for identifier history.

## User decisions and requirements

The plan's `## User Decisions and Requirements` section is a concise freeform list of current user intent. Build and interpret the list from user prompts, user-pointed external documents, tasks, issues, and prior research that captures the user's task, goals, requirements, or accepted decisions. Preserve each entry's meaning without forcing it into a taxonomy. Add optional source pointers inside entries when they clarify the basis for an item.

The planner synthesizes the list and current evidence into separate top-level `## Goals`, `## Scope and Non-Goals`, `## Functional Requirements`, `## Non-Functional Requirements`, and `## Acceptance Criteria` sections before `## Phase Checklist`. These sections are independently editable current planning content. They inform one another but do not duplicate the freeform list or become its subheadings. Keep unresolved proposals and blockers outside the user list until the user confirms them.

When the user makes a clear change, update the list and every affected synthesized section directly without asking a redundant question. Reconcile the plan, phase details, executive summary, phases, task markers, dependencies, references, critique inputs, and follow-up items after the update. Do not silently weaken or contradict a confirmed requirement.

When a decision-critical change remains unclear, ask only a small focused question set. Before asking, send a conversation message containing the affected user decision or requirement and plan area, the finding or conflict, viable choices, material consequences, an evidence-backed recommendation when available, and Markdown links to relevant planning artifacts, documents, code, or authoritative external sources when available. The question tool may refine the choice, but the decision context belongs in the conversation. Apply the user's answer to the freeform list and all affected synthesized sections.

## Planning opening and material updates

Before substantive phase drafting or delegation, create or revise the plan and phase-details artifacts, then persist the canonical planning state in the sections that own it. The plan records task identity, interpreted planning goal, user decisions and requirements, goals, scope and non-goals, initial evidence and readiness assessment, active boundaries, unresolved decisions or blockers, and resolved artifact paths when applicable. Phase details record the initial phase direction and task-level context, evidence, boundaries, and blockers. This persistence gives the opening and later updates a durable planning basis.

After that persistence, send one concise canonical `RPI Plan` opening. Include the following when applicable:

* Identify `RPI Plan` and the task or topic
* State execution state or readiness and the interpreted planning goal
* Summarize the starting evidence or context and active boundaries
* Name the planning focus or initial phase direction
* Identify unresolved decisions or blockers
* Include relevant Markdown links when available
* State that the initial phase direction can change with evidence, critique, and caller direction

Before each material planning update, persist the item in the canonical plan, phase details, or critique disposition section that owns it. Do not create a separate chat-delivery log. Material updates are limited to these planning milestones:

* Evidence or readiness assessment
* Initial artifact drafting
* User decision or requirement changes
* Research returns that change planning
* Critique findings, dispositions, and revisions
* Blockers
* Readiness or handoff

Use a compact update shape: state what changed, the basis or evidence, the planning consequence, and the next planning action. Preserve factual uncertainty. Identify proposals and unresolved items as such, rather than presenting them as settled decisions.

Do not send an update for low-level actions, raw subagent returns, unchanged state, or routine tool calls. The pre-question decision-context requirement remains separate: provide it before a focused decision question, not before every tool call.

## Implementation-time updates and follow-up items

When `rpi-implement` updates the plan or phase details during implementation, update the freeform user list and the affected synthesized sections when the change affects a current confirmed decision or requirement. Reconcile the updated facts, markers, details, dependencies, and executive summary. Remove superseded active content rather than retaining plan-state history. A material implementation discovery may require a fresh planning and critique pass before dependent work resumes.

Persist any user answer that informed an implementation-time update in the freeform list and affected synthesized sections.

Every plan includes `## Follow-Up Items` immediately before `## Handoff`. Initialize it with `* None`. For each newly discovered item that is not immediately related to the approved plan, record the item, why it is outside immediate scope, and its owner or next action. Follow-up items are review-visible but do not become active `Pxx` or `Pxx-Txx` work, completion evidence, or acceptance claims without later planning.

## Executive summary

Every plan checklist includes a user-facing `## Executive Summary` immediately after `## Task Metadata` and before `## Sources`. It gives readers a useful overview before the detailed evidence, scope, and phases.

Include these elements when evidence supports them:

* Explain, in approachable language, what the plan will implement and why the outcome matters.
* Highlight current user decisions and requirements and their practical consequences without creating a second decision authority.
* Include a `### What You May Not Know` subsection for important context, dependencies, risks, or constraints that a user might otherwise miss.
* State unresolved decisions or blockers and the next action when they remain. Do not present an unsupported assumption as a settled decision.

Keep summary claims synchronized with the evidence and the detailed plan. Do not invent claims, decisions, resources, risks, or links. Link to same-plan sections when navigation helps, and add an authoritative external explanatory link only when supplied evidence supports it and it materially improves comprehension. Keep workspace-relative paths as plain text, not Markdown links.

Use readable Markdown selectively: concise paragraphs and lists for structure, bold for essential reader attention, and italics when introducing a term. Plain Markdown has no underline syntax. Use renderer-specific underline only when the generated tracking artifact's renderer is known to support it and the emphasis is essential; pair it with a plain-Markdown fallback, preferably bold. Do not use underline as decoration or repeat it for routine emphasis.

Update the executive summary after every material plan change, including critique-driven revisions, user decisions or their consequences, goals, scope, phases, dependencies, acceptance criteria, risks, and readiness. Before critique handoff and again before finalization, reconcile the summary with the current user list and synthesized plan. Summary synchronization is a readiness condition.

## Research readiness

Read and understand the supplied research before deciding whether to activate `rpi-research`. Additional research is justified only when at least one condition holds:

* Evidence does not cover a requirement, acceptance criterion, dependency, or material risk needed for planning.
* The task's complexity or uncertainty makes a plan speculative.
* A decision-critical choice has multiple plausible outcomes without credible supporting evidence.

When none apply, plan from the supplied evidence. When one applies, ask `rpi-research` for the smallest evidence set that closes the gap, then resume planning.

## Overall planning and bounded assignments

The planning parent owns the freeform user list, synthesized sections, phase order, dependencies, follow-up items, critique disposition, both planning artifacts, and finalization. It may dispatch one or more `RPI Planner` subagents for bounded planning assignments.

Every `RPI Planner` dispatch contains:

* Exact plan and phase-details paths
* Relevant user decisions and requirements, caller requirements, and supplied evidence pointers
* A bounded assignment to refine details, examine supplied sources, propose decisions or options, expose assumptions, or challenge and refute current goals, phases, or tasks with counter-evidence
* An explicit allowed write boundary
* An expected return that states findings, proposed or completed changes within the boundary, assumptions, unresolved items, and evidence

Independent assignments may run in parallel. Dependent assignments run sequentially. The worker does not perform unbounded research, implement production changes, critique the full plan, or redesign the overall plan. The primary planner evaluates every return and decides whether to add, update, delete, recreate, reorder, split, merge, or replace current plan or detail content. A subagent return does not automatically become plan content.

## Independent critique

Activate `rpi-plan-critique` only when the primary planner judges both the plan and phase details to be implementation-ready candidates. Do not critique an initial draft merely because it exists. Dispatch a fresh generic critique worker with the exact task context, current user list, caller requirements, research, evidence, dependencies, acceptance criteria, plan path, details path, and one critique output path. The critique worker reads plan sources and writes only the critique artifact.

The critique is an internal readiness gate. Its verdict returns to the planning parent, which owns revision, decision requests, reruns, and finalization. It is not a peer lifecycle transition and does not cause a standalone user to invoke another stage.

Record the latest critique findings and their dispositions in the plan's standalone top-level `## Critique Disposition` section. Use the critique verdict to select the smallest next action:

* Revise the plan directly for a localized evidence-backed correction.
* Dispatch `RPI Planner` for a bounded planning assignment when deeper planning work is needed.
* Ask a small set of decision-critical questions when a missing choice cannot be inferred.
* Rerun critique after material changes.
* Finalize only after the latest critique passes, or after blocking findings are resolved and an accepted residual risk is explicitly disposed according to the critique workflow's permitted outcome.

## Detail quality

Phase details describe context, intent, boundaries, likely targets, dependencies, validation expectations, completion evidence, and unresolved items. They ground execution in evidence without inventing a procedural choreography that the evidence does not support.

## Planning conversation and closeout

Use the planning opening and material-update protocol above during planning work. Before a decision question, state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

At closeout, report planning execution status separately from readiness or decision state. Include results, important updates, decisions, and blockers or open items. Advise `/compact` only when stale tool output, superseded reasoning, or completed-stage detail outweighs useful context and the durable plan, details, and critique artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For a standalone, implementation-ready plan, advise `/rpi-implement` without invoking it. If the plan is not ready, state the stop or no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the current artifacts to the parent and state that it continues automatically when the gate and confirmation conditions are met. End the user-facing closeout with a Markdown table that links every relevant existing artifact and gives each a short description. Keep that table as the final response element.

## Final planning handoff

The final plan identifies the implementation handoff with task IDs, markers, and artifact paths. A standalone planning response advises `/rpi-implement` only when the plan is ready. The parent continues instead in `rpi-quick` or confirmed automatic RPI Agent mode. It does not create a separate legacy log artifact or require a line-based verification pass.
