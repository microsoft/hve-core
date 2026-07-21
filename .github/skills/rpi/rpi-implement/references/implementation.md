---
description: "Reference protocol for marker-based RPI implementation, current-state maintenance, and evidence-led return."
---

# RPI Implement Reference

## Artifact contract

Read the plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md` and phase details at `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`. Create or update `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` for implementation evidence.

Navigate plan and detail content through `<!-- rpi:phase id=Pxx -->`, `<!-- rpi:task id=Pxx-Txx -->`, and their headings. Do not create or maintain line-number references or separate legacy log artifacts.

## Execution and tracking

1. Read the applicable plan phase, matching details, latest critique disposition, prior changes record, and relevant evidence before changing source.
2. Perform the planned work, using a generic bounded subagent only when its isolated scope, write boundary, and expected result are clear.
3. Mark a task or phase complete only after its stated completion evidence is available.
4. Record material work under descriptive changes-record headings. For every completed-work item, include related `Pxx` or `Pxx-Txx`, files, what changed and why, completion evidence, and validation.
5. Record validation as run, passed, failed, skipped, or unavailable, with the relevant reason or output summary.

## Implementation-time plan updates

Apply this decision rule when implementation reveals new information:

1. Use ordinary local implementation judgment without changing the plan when the discovery does not warrant a plan or phase-detail update.
2. Apply an immediately relevant update when it needs no new user decision or planning reconsideration. The primary implementation agent may update the current plan and matching phase details to clarify factual targets, task wording, sequencing, or directly required in-scope work while preserving approved intent.
3. Use a follow-up-only update when newly discovered work is outside immediate implementation scope. Add its item to the plan's `## Follow-Up Items` section with the outside-immediate-scope reason, triggering evidence, and owner or next action. Keep it outside active `Pxx` and `Pxx-Txx` implementation, completion, and acceptance claims.
4. Treat a discovery that may change confirmed user decisions or requirements, goals, scope, acceptance criteria, architecture, dependencies, validation strategy, or implementation approach as material.

For every plan or detail update, use a descriptive changes-record subheading and record the affected plan area or `Pxx` or `Pxx-Txx` marker, what changed, why, triggering evidence, user answer or decision when present, reconciliation performed, and planning and critique state when material. The changes record is evidence history, not the authority for active plan state.

For an immediately relevant update, reconcile all affected current-state sections: `## User Decisions and Requirements` only when confirmed user intent changed; executive summary; goals; scope and non-goals; functional and non-functional requirements; acceptance criteria; current phase and task markers and checklist; details; dependencies; critique inputs and disposition; and follow-up items as applicable. Remove superseded active content instead of retaining history in the plan. Keep the rationale and evidence history in the changes record.

For a follow-up-only update, record the item, why it is outside immediate scope, triggering evidence, and owner or next action in `## Follow-Up Items` and mirror it in the changes record. Exclude it from active implementation, completion, and acceptance claims.

Use the native `vscode_askQuestions` tool only when available evidence cannot support a responsible user-owned decision. This includes unresolved major plan changes, blockers, and proposed workarounds, but not ordinary local implementation judgment. Immediately before the tool call, send a visible conversation message that states the affected user decision or requirement and plan area, evidence or conflict, viable choices, material consequences, an evidence-backed recommendation when available, and Markdown links to relevant artifacts or sources when available. Ask the smallest decision-critical question set. Persist the answer and resulting decision in `## User Decisions and Requirements`, every affected current synthesized section, and the changes record. Stop affected work as Blocked when required feedback is unavailable. A user answer does not bypass a required fresh planning and critique pass.

When implementation discovers work that is not immediately related to the approved plan, use a follow-up-only update. Do not add it to active `Pxx` or `Pxx-Txx` implementation, completion, or acceptance claims.

## Material discovery and resumption

A material discovery may change confirmed user decisions or requirements, goals, scope, acceptance criteria, architecture, dependencies, validation strategy, or implementation approach. Before affected dependent work can resume:

1. Record the discovery, affected `Pxx` or `Pxx-Txx`, current plan and detail state, triggering evidence, impact, and paused work in the changes record.
2. Return the current plan, phase details, and evidence to the planning owner for fresh planning and critique.
3. Reconcile the plan and phase details through the planning owner's current-state process. Preserve unrelated completed work and its evidence.
4. Resume only affected dependent work after the updated plan is implementation-ready under the planner's current critique contract. Record the resulting planning and critique state, including relevant `PC-xxx` evidence when present, in the changes record.

On resumption, continue from the first unchecked applicable task or phase. Read prior descriptive changes-record sections, current plan markers, phase details, and latest critique disposition. Do not resume a task awaiting a user decision or fresh planning and critique.

## Return to caller

During material work, give concise updates at implementation boundaries. State the action and reason, changes or findings, decisions, blockers, validation results, relevant artifact or source links, and one important point the user might otherwise miss. Before a user decision, state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

At closeout, report implementation execution status separately from review readiness. Include results, material updates, decisions, and blockers or open items. Advise `/compact` only when stale output, superseded reasoning, or completed task detail outweighs current context and the plan, details, and changes record are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

For standalone use, advise `/rpi-review` only when review prerequisites are met and do not invoke it. When planning or a decision is required, state the explicit stop or no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the artifacts to the parent for automatic continuation after gates and required confirmations pass. End the closeout with a Markdown table linking every relevant existing artifact and a short description. Keep the table as the final response element.

## Production-reference hygiene

Tracking paths guide implementation but do not belong in production code, code comments, documentation strings, or commit messages. Keep shipped references durable and self-contained.
