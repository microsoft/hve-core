---
name: rpi-implement
description: "Follow an approved RPI plan, keep it current as new information comes to light, check off completed work, and keep a condensed changes log. Use when implementation is ready to begin or resume."
argument-hint: "[plan=...] [phase=...] [task=...]"
license: MIT
user-invocable: true
---

# RPI Implement

## Goal

Deliver the approved outcome by following the current task-centered plan. Keep the plan current as new information comes to light, check off work as it completes, and keep a condensed changes log of the behavioral and functional changes made, so the caller can trust what was done and what remains.

## Flow

1. Resolve the exact plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md` and the declared invocation scope: the full plan, one `Pxx` phase, or one `Pxx-Txx` task. Read each in-scope task's `Goals:`, `Requirements:`, `Details:`, `Guidance:` when present, `References:`, and `Dependencies:` blocks, follow the linked references, and check the plan's decision and risk tables for rows that name the task. The declared scope limits completion claims and active work.
2. Create or continue `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` using [templates/changes-log.md](templates/changes-log.md). Record each completed item under a descriptive heading tied to its plan marker, describing the behavior or functionality that changed rather than the edits made.
3. Before substantive source edits, bring the plan checklist, changes record, and any related state tracking artifacts current, then send the implementation opening defined in [references/implementation.md](references/implementation.md).
4. Start with the first unchecked dependency-ready plan item in declared scope and work through eligible items in plan order. When a task's `Requirements:` hold and its changes-record entry exists, check the `Pxx-Txx` marker immediately. Check a `Pxx` phase only when it is in scope and every task in it is checked. Do not check markers outside declared scope.
5. When new information comes to light, classify it using [references/implementation.md](references/implementation.md): ordinary local judgment, an immediately relevant plan update that preserves approved intent, follow-up-only work outside the active plan, or a material discovery that needs a user decision or planning reconsideration.
   * When completed work creates something a later task needs that the plan does not already name, such as a class, API, contract, utility, fixture, or path, add a `Guidance:` block immediately after that task's `Details:` with the concrete pointer. This needs no user decision.
   * Keep the Phase Checklist diagrams current when a plan update adds, merges, splits, or removes phases or tasks.
6. Ask for the smallest decision-critical user input only when available evidence cannot support a responsible user-owned decision. Persist the result in the plan and the changes record. If the accepted plan must change, pause only affected dependent work and return the current evidence to planning. The confirmed user decision remains authoritative; do not run another critique.
7. Run the checks the task's `Requirements:` or `Details:` name and record each result in the changes record as passed, failed, skipped, or unavailable with its reason. Validation alone does not resume paused dependent work.
8. When declared scope finishes, bring the changes record, blockers, completion markers, remaining work, and validation state current. Report active plan markers outside the scope as remaining work. Report full-plan completion only when the full plan was declared and every marker has completion evidence.
9. Before handing a full-plan or review-ready scope to Review, reconcile plan markers and task-local context, completed-work entries, handoff prose, blockers, remaining work, follow-up items, and validation state.
10. Return the current implementation result to the caller using the return contract below.

## Inputs

* Approved plan path or task context
* Optional declared scope: full plan, exact `Pxx` phase, or exact `Pxx-Txx` task
* Task-local plan context, supplied evidence, latest critique disposition, and prior changes record when available

## Success criteria

* The implementation follows the approved plan or records a material discovery and its current state explicitly.
* The first unchecked dependency-ready item in declared scope starts first, and later dependent work does not bypass plan order.
* Completed `Pxx-Txx` tasks are checked immediately after their changes-record entry exists. A `Pxx` phase is checked immediately after every task in that in-scope phase is checked.
* A bounded `Pxx` or `Pxx-Txx` result confirms only its declared scope and reports remaining active-plan markers without claiming full-plan completion.
* Each changes-record entry is a condensed description of the behavior or functionality that changed, tied to its plan marker, with affected files and validation. Entries use descriptive headings, with no second per-entry identity scheme.
* New information is classified as local judgment, immediately relevant plan update, follow-up-only work, or material decision, with the record required by the reference.
* A later task that depends on something earlier work created receives a `Guidance:` block naming it when the plan did not already do so.
* Affected dependent work resumes after the significant or divergent user decision is reflected in the current plan. The task's critique is not repeated.
* Every check the plan names has a recorded result or an explicit skip reason.
* A later invocation may implement applicable Review findings as ordinary work without a correction run type or mandatory second Review.
* Plan markers and task-local context, changes entries, handoff prose, blockers, remaining work, follow-up items, and validation state are reconciled before Review.
* The caller receives the current execution status, evidence paths, current plan state, validation coverage, blockers, remaining work, and follow-up items.

## Constraints

* Use [references/implementation.md](references/implementation.md) for the changes-record contract, plan-update rules, material-discovery handling, questions, resumption, and rendered conversation mechanics.
* Do not expand active scope. Place unrelated work in an explicit follow-up item.
* Do not use line numbers or separate legacy log artifacts.
* In the plan and changes record, wrap code, commands, and symbols in backticks and link existing files and folders with the workspace-relative path as the link text and a path relative to the artifact file as the destination. Keep a not-yet-created path in backticks.
* Keep `.copilot-tracking/` references out of production code, code comments, documentation strings, and commit messages.

## Conversation guidance

* Follow the detailed opening, continual-update, pre-question, and closeout protocol in [references/implementation.md](references/implementation.md). That reference is the authority for the rendered message templates.
* Persist canonical state before the opening, any material update, decision question, handoff, or closeout. Chat is a concise projection of that state, never a second history or delivery log.
* At closeout, report implementation execution status separately from review readiness. Qualify every status by the declared scope and list remaining active-plan markers so bounded completion is not mistaken for task completion.
* Advise `/compact` only when stale tool output, superseded reasoning, or completed task detail outweighs useful current context and the plan and changes record are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* In a standalone invocation, do not invoke `rpi-review`. State `/rpi-review` only when review prerequisites are met. In an active confirmed automatic RPI Agent context, return current artifacts and scope facts to the parent for eligible continuation.
* For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Stop rules

* Stop as Blocked when the approved plan, required details, or a dependency prevents credible progress.
* Stop as Blocked when a decision-critical user answer needed for a major plan change, blocker, or workaround is unavailable.
* Pause affected dependent work only when a significant or divergent decision changes assessed requirements, scope, architecture, dependency model, or evidence boundary. Return current artifacts to planning when needed, preserve the existing critique as historical evidence, and resume after the user decision and plan state are current.
* Stop after a caller-bounded `Pxx` phase or `Pxx-Txx` task once its declared-scope plan state and changes evidence are current. Do not require or imply completion of work outside that scope.

## Return to Caller

Return the changes-record path, implementation execution status, completed and remaining `Pxx` or `Pxx-Txx` items, validation coverage, blockers, current plan updates, follow-up items, and review readiness or the explicit reason affected work awaits a user decision. Follow the Conversation guidance section for standalone or parent-orchestrated continuation, conditional compaction advice, the linked artifact table, and final next steps.


