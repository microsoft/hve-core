---
name: rpi-implement
description: "Follow an approved RPI plan, keep it current as new information comes to light, check off completed work, and keep a condensed changes log. Use when implementation is ready to begin or resume."
argument-hint: "[plan=...] [phase=...] [task=...] [subagents={auto|none}]"
license: MIT
user-invocable: true
---

# RPI Implement

## Goal

Deliver the approved outcome by following the current task-centered plan. Keep the plan current as new information comes to light, check off work as it completes, and keep a condensed changes log of the behavioral and functional changes made, so the caller can trust what was done and what remains.

## Flow

1. Resolve the exact plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md` and the declared invocation scope: the full plan, one `Pxx` phase, or one `Pxx-Txx` task. Read each in-scope task's `Goals:`, `Requirements:`, `Details:`, `Guidance:` when present, `References:`, and `Dependencies:` blocks, follow the linked references, and check the plan's decision and risk tables for rows that name the task. The declared scope limits completion claims and active work.
    * Before source changes, read the plan's Planning Readiness and Critique Disposition. Implementation does not require a critique; a skipped or absent critique is not a blocker. When the plan is marked not ready, records open blockers, or has unresolved blocking critique findings, name them and confirm with the user before implementing affected tasks, unless the user or the confirmed automatic parent already directed implementation with them known.
    * An approved plan is an implementation-ready plan for the declared scope, not a human sign-off. A direct `/rpi-implement` request needs no additional plan-approval prompt. Agent self-checks are not human attestations; human review applies only when an instruction, domain artifact, or explicit user requirement names it for the affected action, and its checkboxes stay human-owned.
2. Create or continue `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` using [templates/changes-log.md](templates/changes-log.md). Record each completed item under a descriptive heading tied to its plan marker, describing the behavior or functionality that changed rather than the edits made.
3. Before substantive source edits, bring the plan checklist, changes record, and any related state tracking artifacts current, then send the implementation opening defined in [references/implementation.md](references/implementation.md).
4. Start with the first unchecked dependency-ready plan item in declared scope and work through eligible items in plan order. When a task's `Requirements:` hold and its changes-record entry exists, check the `Pxx-Txx` marker immediately. Check a `Pxx` phase only when it is in scope and every task in it is checked. Do not check markers outside declared scope. Implementation needs no subagent. Use subagents only when a dispatch tool is available and the user's direction allows them, including using none. When you use them, run dependency-ready tasks that change different files in one parallel batch, keep dependent or same-file work in sequence, and verify each result yourself before checking its marker. Run a subagent on `Claude Haiku 5.5 (copilot)` at `max` reasoning effort, passed as dispatch parameters when the tool accepts them, unless the user names another model or the subagent's frontmatter declares its own. If a subagent dispatch fails because its model does not support the subagent's reasoning effort, retry it once with `reasoning_effort` set to `medium`.
5. When new information comes to light, classify it using [references/implementation.md](references/implementation.md): ordinary local judgment, an implementation-only annotation, follow-up-only work outside the active plan, or a plan change that may need a user decision.
   * When completed work creates something a later task needs that the plan does not already name, such as a class, API, contract, utility, fixture, or path, add a `Guidance:` block immediately after that task's `Details:` with the concrete pointer. This needs no user decision.
   * Keep the Phase Checklist diagrams current when a plan update adds, merges, splits, or removes phases or tasks.
   * When a plan update changes, or completed behavior differs from, a requirement that cites a BRD, PRD, or ADR, add a Business Alignment entry as [references/implementation.md](references/implementation.md) defines.
6. Ask for the smallest decision-critical user input only when available evidence cannot support a responsible user-owned decision. Persist the result in the plan and the changes record. When requirements, scope, architecture, capability, safety, dependencies, or evidence must change, update the affected plan sections under [references/implementation.md](references/implementation.md). A significant or divergent choice needs a user decision first, and affected dependent work pauses until it is recorded; an evidence-backed clarification needs no user question. The confirmed user decision remains authoritative. Do not run a critique from implementation; a follow-up critique runs only when the user asks for one.
7. Run the checks the task's `Requirements:` or `Details:` name and record each result in the changes record as passed, failed, skipped, or unavailable with its reason. Validation alone does not resume paused dependent work.
8. When declared scope finishes, bring the changes record, blockers, completion markers, remaining work, and validation state current. Report active plan markers outside the scope as remaining work. Report full-plan completion only when the full plan was declared and every marker has completion evidence.
9. Before handing a full-plan or review-ready scope to Review, reconcile plan markers and task-local context, completed-work entries, handoff prose, blockers, remaining work, follow-up items, and validation state. Compare completed behavior with every cited BRD, PRD, or ADR requirement and add any missing Business Alignment entry.
10. Return the current implementation result to the caller using the return contract below.

## Inputs

* Approved plan path or task context
* Optional declared scope: full plan, exact `Pxx` phase, or exact `Pxx-Txx` task
* Task-local plan context, supplied evidence, latest critique disposition, and prior changes record when available
* Subagent use: `auto` by default, which uses subagents when a dispatch tool is available and they would help, or the user's direction, such as `none` or only named uses

## Success criteria

* The implementation follows the approved plan or records a material discovery and its current state explicitly.
* The first unchecked dependency-ready item in declared scope starts first, and later dependent work does not bypass plan order.
* Completed `Pxx-Txx` tasks are checked immediately after their changes-record entry exists. A `Pxx` phase is checked immediately after every task in that in-scope phase is checked.
* A bounded `Pxx` or `Pxx-Txx` result confirms only its declared scope and reports remaining active-plan markers without claiming full-plan completion.
* Each changes-record entry is a condensed description of the behavior or functionality that changed, tied to its plan marker, with affected files and validation. Entries use descriptive headings, with no second per-entry identity scheme.
* New information is classified as local judgment, implementation-only annotation, follow-up-only work, or a plan change; unresolved significant or divergent choices require a user decision before affected work resumes.
* A later task that depends on something earlier work created receives a `Guidance:` block naming it when the plan did not already do so.
* Every plan update that changes, and every completed behavior that differs from, a cited business source requirement has a Business Alignment entry naming the source, owner, change, rationale, decision, and alignment value.
* Affected dependent work resumes after the significant or divergent user decision is reflected in the current plan.
* Every check the plan names has a recorded result or an explicit skip reason.
* A later invocation may implement applicable Review findings as ordinary work without a correction run type or mandatory second Review.
* Plan markers and task-local context, changes entries, handoff prose, blockers, remaining work, follow-up items, and validation state are reconciled before Review.
* The caller receives the current execution status, evidence paths, current plan state, validation coverage, blockers, remaining work, and follow-up items.

## Constraints

* Use [references/implementation.md](references/implementation.md) for the changes-record contract, plan-update rules, material-discovery handling, questions, resumption, and rendered conversation mechanics.
* Do not expand active scope. Place unrelated work in an explicit follow-up item.
* Do not use line numbers or separate legacy log artifacts.
* In the plan and changes record, wrap code, commands, and symbols in backticks and link existing files and folders with the workspace-relative path as the link text and a path relative to the artifact file as the destination. Keep a not-yet-created path in backticks and convert it to a link once the file exists.
* Keep `.copilot-tracking/` references out of production code, code comments, documentation strings, and commit messages; keep shipped references durable and self-contained.

## Conversation guidance

* Follow the opening, continual-update, and pre-question protocol in [references/implementation.md](references/implementation.md), which is the authority for the rendered message templates. Closeout follows Return to Caller.
* Persist canonical state before the opening, any material update, decision question, handoff, or closeout. Chat is a concise projection of that state, never a second history or delivery log.

## Stop rules

* Stop as Blocked when the approved plan, required details, or a dependency prevents credible progress.
* Stop as Blocked when a decision-critical user answer needed for a major plan change, blocker, or workaround is unavailable.
* Pause affected dependent work only while a significant or divergent decision about requirements, scope, architecture, dependencies, or evidence is unresolved. Resume after the user decision and plan state are current; return to `rpi-plan` only when the change needs replanning beyond the affected tasks.
* Stop after a caller-bounded `Pxx` phase or `Pxx-Txx` task once its declared-scope plan state and changes evidence are current. Do not require or imply completion of work outside that scope.

## Return to Caller

* Return the changes-record path, implementation execution status, completed and remaining `Pxx` or `Pxx-Txx` items, validation coverage, blockers with their owner and clearing action, current plan updates, Business Alignment entries or `none` with any `pending-decision` entry called out, follow-up items, and review readiness or the explicit reason affected work awaits a user decision. Include results, material updates, and decisions.
* Report implementation execution status separately from review readiness. Qualify every status by the declared scope and list all remaining active-plan markers, including later work outside the declared scope, so bounded completion is not mistaken for task completion.
* In a standalone invocation, do not invoke `rpi-review`. State `/rpi-review` as the optional next step only when review prerequisites are met; otherwise state the current no-handoff reason. In an active confirmed automatic RPI Agent context, return current artifacts and scope facts to the parent, which owns eligible continuation after its gates and required confirmations pass.
* Advise `/compact` only when stale tool output, superseded reasoning, or completed task detail outweighs useful current context and the plan and changes record are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section.
* End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command.
