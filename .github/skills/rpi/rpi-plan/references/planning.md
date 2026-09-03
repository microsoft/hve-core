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

## Artifact audience and order

The plan is the user-facing planning source of truth and the downstream implementation checklist. Put its Executive Summary, User Decisions and Requirements, Planning Readiness and Next Step, goals, scope, requirements, acceptance criteria, risks and open questions, phase checklist, and dependencies before Sources, Critique Disposition, and Artifact Self-Check. Keep each fact in one canonical section; summary prose projects current state without creating another decision authority. Acceptance Criteria is the single verification record, so requirements do not repeat criteria inline.

Phase details are implementation-facing. Keep their full phase and task context, likely targets, dependencies, validation expectations, completion evidence, and unresolved items. They do not need to repeat the plan's reader summary or decision walkthrough.

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

The plan's `## User Decisions and Requirements` section has two distinct records. Confirmed User Direction is a concise freeform list of current user intent from prompts, user-pointed documents, tasks, issues, prior research, and accepted decisions. Planning Decisions and Feedback holds unresolved, proposed, deferred, and resolved material choices grouped by dependency and decision context. Each row records group, status, owner, rationale or requested input, evidence, and impact.

The planner synthesizes confirmed direction and current evidence into separate top-level `## Goals`, `## Scope and Non-Goals`, `## Functional Requirements`, `## Non-Functional Requirements`, and `## Acceptance Criteria` sections before `## Phase Checklist`. These sections inform one another without duplicating confirmed direction or unresolved decision rows. Move a resolved user-owned choice into Confirmed User Direction and update or close its decision row.

When the user makes a clear change, update the list and every affected synthesized section directly without asking a redundant question. Reconcile the plan, phase details, executive summary, phases, task markers, dependencies, references, critique inputs, and follow-up items after the update. Do not silently weaken or contradict a confirmed requirement.

When a decision-critical change remains unclear, apply the Planning Decision Walkthrough below. The question tool collects a choice; its evidence and explanation remain in the conversation and plan.

## Planning decision walkthrough

Resolve decision participation before presenting unresolved material planning decisions.

| Mode                                         | Decision owner | Behavior                                                                                                                                                  |
|----------------------------------------------|----------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------|
| Standalone or manual RPI                     | User           | Walk through unresolved material decision groups and persist each answer before continuing.                                                               |
| Automatic RPI Agent, default                 | Agent          | Resolve supported ordinary planning decisions and critique dispositions; stop on an unsupported material choice rather than asking or guessing.           |
| Automatic RPI Agent, user-retained           | User           | Keep the session automatic, pause Plan for focused decision groups, then resume automatic progression after required answers and planning gates complete. |
| Parent-owned orchestration such as RPI Quick | Parent         | Follow the parent-provided decision-participation and continuation contract.                                                                              |

Build groups from unresolved rows in Planning Decisions and Feedback. Order them by dependency, blocker status, and effect on Planning Readiness. A group contains one decision by default. Combine decisions only when they share the same choice, evidence, and consequences or when answering one independently would be misleading.

For each `user-owned` or `user-retained` group:

1. Persist the pending group and its evidence before conversation.
2. Present the plan, phase details when relevant, and supporting research, source, or code as Markdown links. Explain the decision, why it matters now, viable choices and consequences, evidence-backed recommendation when available, uncertainty, and readiness effect in plain language.
3. Add a compact Mermaid diagram in conversation only when architecture, dependency, sequence, or a trade-off would otherwise be difficult to understand. The diagram supplements accessible prose.
4. Call `vscode_askQuestions` when available with one concise question per decision and fixed options plus freeform input when useful. When unavailable, ask the same question in chat and wait.
5. Persist the answer, provenance, affected requirements and phases, and readiness effect before presenting the next group.

When no unresolved material decision exists, record that no walkthrough is required and do not ask for acknowledgment. In `agent-owned` mode, apply the same group ordering internally, select only evidence-supported options, and persist each rationale. Missing decision-critical evidence produces Not ready or Blocked with the smallest evidence needed.

## Planning opening and material updates

Before substantive phase drafting or delegation, create or revise the plan and phase-details artifacts, then persist the canonical planning state in the sections that own it. The plan records task identity, interpreted planning goal, user decisions and requirements, goals, scope and non-goals, initial evidence and readiness assessment, active boundaries, unresolved decisions or blockers, and resolved artifact paths when applicable. Phase details record the initial phase direction and task-level context, evidence, boundaries, and blockers. This persistence gives the opening and later updates a durable planning basis.

After that persistence, send one concise canonical `RPI Plan` opening using this shape:

```markdown
## 🧭 RPI Plan: [Task or topic] | [Readiness or planning focus]

[Interpreted planning goal.]

* Starting evidence and readiness: [current basis and readiness state]
* Initial phase direction: [first planning focus or artifact action]
* Active boundaries: [scope, non-goals, constraints, or critique boundary]
* Current decision state: [settled decisions, proposals, or unresolved items]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

These are the starting planning state and may evolve only through the existing evidence, critique, caller-direction, and planning-update rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent state, links, or planning certainty.

Before each potential continual update, persist the item in the canonical plan, phase details, or critique disposition section that owns it. Chat is a concise projection of that state, not a second history or delivery audit. A continual update is warranted only when the item changes phase direction, a current decision or readiness state, a material result or artifact state, a blocker or decision need, validation state where applicable, handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw subagent returns, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted:

```markdown
### [Marker when useful] [Planning state]: [Short item]

Basis: [compact evidence, critique, or decision context and relevant Markdown links]

Planning consequence: [effect on goals, scope, requirements, phases, readiness, or unresolved work]

Next planning action: [next draft, revision, critique, decision request, handoff, or stop]
```

Use `✅` only for an evidence-backed settled decision or achieved readiness, `⚠️` for a proposal, unresolved item, critique concern, or revision need, and `⛔` for a blocker. Preserve factual uncertainty and identify proposals and unresolved items as such rather than presenting them as settled decisions. The pre-question decision-context requirement remains separate: provide it before a focused decision question, not before every tool call.

## Implementation-time updates and follow-up items

When `rpi-implement` updates the plan or phase details during implementation, update Confirmed User Direction and the affected synthesized sections when the change affects current confirmed intent. Record unresolved choices in Planning Decisions and Feedback. Reconcile the updated facts, markers, details, dependencies, and executive summary. Remove superseded active content rather than retaining plan-state history. A significant or divergent discovery may require a user decision and plan update before affected work resumes, but the task's critique is not repeated.

Persist any user answer that informed an implementation-time update in the freeform list and affected synthesized sections.

Every plan includes `## Follow-Up Items` immediately before `## Handoff`. Initialize it with `* None`. For each newly discovered item that is not immediately related to the approved plan, record the item, why it is outside immediate scope, and its owner or next action. Follow-up items are review-visible but do not become active `Pxx` or `Pxx-Txx` work, completion evidence, or acceptance claims without later planning.

## Executive summary

Every plan checklist includes a user-facing `## Executive Summary` immediately after `## Task Metadata`. It gives readers a useful overview before decisions, readiness, requirements, and phases.

Include these elements when evidence supports them:

* Explain, in approachable language, what the plan will implement and why the outcome matters.
* Include a `### What You May Not Know` subsection for important context, dependencies, risks, or constraints that a user might otherwise miss.
* State planning execution status, readiness, confidence, and residual uncertainty in plain language. Keep detailed decisions, blockers, and next actions in their canonical sections.

Keep summary claims synchronized with the evidence and the detailed plan. Do not invent claims, decisions, resources, risks, or links. Link to same-plan sections when navigation helps, and add an authoritative external explanatory link only when supplied evidence supports it and it materially improves comprehension. Keep workspace-relative paths as plain text, not Markdown links.

Use readable Markdown selectively: concise paragraphs and lists for structure, bold for essential reader attention, and italics when introducing a term. Plain Markdown has no underline syntax. Use renderer-specific underline only when the generated tracking artifact's renderer is known to support it and the emphasis is essential; pair it with a plain-Markdown fallback, preferably bold. Do not use underline as decoration or repeat it for routine emphasis.

Update the executive summary after every material plan change, including critique-driven revisions, user decisions or their consequences, goals, scope, phases, dependencies, acceptance criteria, risks, and readiness. Before critique handoff and finalization, reconcile the summary with confirmed direction, decision rows, synthesized sections, and Planning Readiness and Next Step. Summary synchronization is a readiness condition.

## Research readiness

Read and understand the supplied research before deciding whether to activate `rpi-research`. Additional research is justified only when at least one condition holds:

* Evidence does not cover a requirement, acceptance criterion, dependency, or material risk needed for planning.
* The task's complexity or uncertainty makes a plan speculative.
* A decision-critical choice has multiple plausible outcomes without credible supporting evidence.

When none apply, plan from the supplied evidence. When one applies, ask `rpi-research` for the smallest evidence set that closes the gap, then resume planning.

## Overall planning and bounded assignments

The planning parent owns Confirmed User Direction, Planning Decisions and Feedback, synthesized sections, phase order, dependencies, follow-up items, critique disposition, both planning artifacts, and finalization. It may activate planning skills or dispatch subagents selected from their available stable names and descriptions for bounded planning assignments.

Select a skill or subagent only when its stable name contains `plan` or `planning`, or its description explicitly says it is used during planning, and its description fits the bounded assignment. Exclude `rpi-plan`, `rpi-plan-critique`, and other RPI lifecycle phase entrypoints. Activate selected skills as scoped guidance. When delegated work has no suitable planning subagent, dispatch an unnamed general-purpose subagent with the agent selection omitted.

Every planning-worker dispatch contains:

* Exact plan and phase-details paths
* Relevant user decisions and requirements, caller requirements, and supplied evidence pointers
* A bounded assignment to refine details, examine supplied sources, propose decisions or options, expose assumptions, or challenge and refute current goals, phases, or tasks with counter-evidence
* An explicit allowed write boundary
* An expected return that states findings, proposed or completed changes within the boundary, assumptions, unresolved items, and evidence
* A prohibition on production source edits, implementation, Review, overall-plan decisions, nested delegation, and writes outside explicitly assigned plan or phase-detail sections

Independent assignments may run in parallel. Dependent assignments run sequentially. The worker does not perform unbounded research, implement production changes, critique the full plan, or redesign the overall plan. The primary planner evaluates every return and decides whether to add, update, delete, recreate, reorder, split, merge, or replace current plan or detail content. A subagent return does not automatically become plan content.

## Independent critique

Activate `rpi-plan-critique` at most once, only when the primary planner judges both the plan and phase details to be implementation-ready candidates. Do not critique an initial draft merely because it exists.

Select one critique depth and record its provenance before dispatch:

| Depth      | Selection rule                           | Assessment behavior                                                                                                                                                                                                   |
|------------|------------------------------------------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `standard` | Default                                  | Assess the complete material supplied boundary as quickly as evidence permits, returning every evidence-supported implementation blocker and credibility gap without restatement, cosmetics, or low-impact expansion. |
| `deep`     | Explicit user request to critique deeply | Trace the supplied evidence more broadly, stress-test alternatives and boundaries, and include substantive lower-severity concerns. It remains one invocation and performs no open-ended research.                    |

Do not infer deep mode from plan size, complexity, uncertainty, or risk. Standard optimizes prioritization and output for minimal elapsed work without reducing complete coverage of actionable material concerns in the supplied boundary.

Before dispatch, inspect the plan's Critique Disposition, parent state when present, and the critique path. A `started`, `Complete`, `Partial`, or `Blocked` execution record or existing critique artifact consumes the task's single invocation. On resume, reconcile existing evidence instead of dispatching a replacement. Persist `started`, candidate identity, selected depth and provenance, and output path immediately before dispatch; do not dispatch if that write fails.

Lock applicable test ownership, exact removals or `none`, maximum additions, canonical and generated targets, semantic-versus-regression coverage, and validation evidence. Dispatch one fresh generic critique worker with selected depth, exact task context, confirmed direction, resolved planning decisions, caller requirements, research, evidence, dependencies, acceptance criteria, plan path, details path, and one critique output path. The critique worker reads plan sources and directly relevant supplied evidence, writes only the critique artifact, and returns one complete actionable finding set.

The critique is a one-time internal readiness gate. Its verdict returns to the planning parent, which owns revision, decision requests, and finalization. It is not a peer lifecycle transition and does not cause a standalone user to invoke another stage.

Record the latest critique findings and their dispositions in the plan's standalone top-level `## Critique Disposition` section. Use the critique verdict to select the smallest next action:

* Revise the plan directly for localized evidence-backed corrections, applying all planner-owned findings in one coherent batch.
* Dispatch a phase-matched planning subagent, or an unnamed general-purpose subagent with the planning restrictions above, when deeper planning work is needed.
* Preserve confirmed user requests and answers when critique advice conflicts with them. Reject conflicting advice without re-asking when current user direction already resolves it.
* Route a significant or divergent finding not resolved by current user direction through the current Planning Decision Walkthrough when it affects requirements, scope, architecture, acceptance criteria, dependencies, or evidence boundary.
* Close every `PC-xxx` with its declared owner, disposition, and exact resolving evidence, then finalize without a retry or closure critique.
* Finalize after direct corrections and required user decisions are resolved and any accepted residual risk is explicitly recorded.

Any returned execution status consumes the invocation. Partial or Blocked critique evidence remains terminal for the gate. If its missing evidence or open findings cannot be resolved by the planning parent, stop Plan with the exact blocker rather than dispatching again.

## Detail quality

Phase details describe context, intent, boundaries, likely targets, dependencies, validation expectations, completion evidence, and unresolved items. They ground execution in evidence without inventing a procedural choreography that the evidence does not support.

## Planning conversation and closeout

Use the planning opening and material-update protocol above during planning work. Use the Planning Decision Walkthrough for material choices and critique findings. Keep automatic agent-owned decisions free of routine prompts and keep user-retained automatic sessions automatic while awaiting a decision group.

At closeout, report planning execution status separately from readiness or decision state. Include results, important updates, decisions, and blockers or open items. Advise `/compact` only when stale tool output, superseded reasoning, or completed-stage detail outweighs useful context and the durable plan, details, and critique artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For a standalone, implementation-ready plan, report planning execution status and readiness separately, then identify the latest critique disposition and the current implementation context: plan, phase details, latest critique, relevant research, and the changes record's role as the implementation evidence record. Advise `/rpi-implement` without invoking it. Do not ask the user to attach artifacts.

If the plan is not ready, state the stop or no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return that same context to the parent and state that it continues automatically when the gate and confirmation conditions are met. Do not give the parent attachment instructions.

For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Final planning handoff

The final plan identifies the implementation handoff with task IDs, markers, and artifact paths. Its Planning Readiness and Next Step record identifies the plan, phase details, latest critique, relevant research, downstream changes-record role, decision participation, blockers, gates, and continuation. A standalone planning response advises `/rpi-implement` only when the plan is ready. The parent continues instead in `rpi-quick` or confirmed automatic RPI Agent mode. It does not create a separate legacy log artifact or require a line-based verification pass.
