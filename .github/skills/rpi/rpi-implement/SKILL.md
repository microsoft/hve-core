---
name: rpi-implement
description: "Execute an approved RPI plan, maintain current planning state, and record implementation evidence. Use when implementation is ready to begin or resume."
argument-hint: "[plan=...] [phase=...] [task=...]"
license: MIT
user-invocable: true
---

# RPI Implement

## Goal

Deliver the approved outcome using the current plan and phase details as evidence. Keep task completion, implementation evidence, plan maintenance, and validation trustworthy for the caller.

## Flow

1. Resolve the exact plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`, phase details, relevant evidence, latest critique disposition, and prior changes record. Use markers and headings to locate `Pxx` and `Pxx-Txx`, not line positions.
2. Create or continue `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` using [templates/changes-log.md](templates/changes-log.md). Record material evidence under descriptive headings tied to plan areas or markers, not per-entry formal IDs.
3. Before substantive source edits or implementation delegation, make the active implementation scope, approved write boundary, validation intent, blockers, and first execution boundary current in their owning artifacts. Keep current approved state in the plan and phase details, and implementation evidence and history in the changes record, as applicable. Then send the implementation opening defined in Conversation guidance.
4. Execute approved tasks with judgment.
	* Work directly when the task is coupled or small.
	* Use a generic bounded subagent only when isolated execution materially improves the outcome.
	* For a phase implementation subagent, select the Medium reasoning profile at dispatch with this ordered availability fallback: `GPT-5.6 Terra (copilot)`, `Claude Sonnet 5 (copilot)`, `MAI-Code-1-Flash (copilot)`.
	* Provide the exact phase or task, evidence, allowed write boundary, and expected return.
5. Mark completed tasks and phases in the plan only after completion evidence is available. Record completed work, validation evidence, blockers, and remaining work in the changes record.
6. Classify new implementation information using [references/implementation.md](references/implementation.md).
	* Retain ordinary local judgment in execution.
	* Apply an immediately relevant current-state update only when it needs no new user decision or planning reconsideration.
	* Place unrelated work in `## Follow-Up Items`.
	* Pause only affected dependent work for a material discovery.
7. Use the native `vscode_askQuestions` tool only when available evidence cannot support a responsible user-owned decision, including a major plan change, blocker, or proposed workaround.
	* Before the tool call, provide the required decision context in the conversation.
	* Ask the smallest decision-critical set.
	* Persist the answer in the current plan and changes record.
	* Stop affected work as Blocked when feedback is unavailable.
	* A user answer does not replace a required fresh planning and critique pass.
8. For a material discovery, record the discovery and current state in the changes record. Return the current plan, phase details, and evidence to the planning owner. Pause only affected dependent work and preserve unrelated completed work and evidence.
9. Run validation expected by the plan or by completed changed behavior. Record checks, results, and explicit skip reasons without treating validation alone as permission to resume paused dependent work.
10. Return the current implementation result to the caller using the return contract below.

## Inputs

* Approved plan path or task context
* Optional exact `Pxx` phase or `Pxx-Txx` task scope
* Phase details, supplied evidence, latest critique disposition, and prior changes record when available

## Success criteria

* The implementation follows the approved plan or records a material discovery and its current state explicitly.
* Completed `Pxx-Txx` tasks and `Pxx` phases are checked off only after completion evidence exists.
* The changes record uses descriptive evidence headings and plan or task markers, with no second per-entry identity scheme.
* Every implementation-time plan or detail update records its affected area, change, rationale, triggering evidence, user decision when present, reconciliation, and planning or critique state.
* Affected dependent work resumes only after the updated plan is implementation-ready under the planner's current critique contract. Blocked planning leaves affected work stopped.
* Decision-critical user feedback, when needed, is persisted in `## User Decisions and Requirements`, all affected current synthesized sections, and the changes record. Implementation-discovered unrelated work is recorded as a plan follow-up item.
* Validation evidence or an explicit skip reason is available for changed behavior.
* The caller receives the current execution status, evidence paths, current plan and detail state, validation coverage, blockers, remaining work, and follow-up items.

## Constraints

* Use [references/implementation.md](references/implementation.md) for detailed tracking, current-state reconciliation, and material-discovery rules.
* Do not expand active scope. Place unrelated work in an explicit follow-up item.
* Ordinary local judgment does not alter the plan. An immediately relevant update preserves approved intent and needs no new user decision or planning reconsideration. Only material discoveries pause affected dependent work and return to planning.
* Do not use line numbers, separate legacy log artifacts, or retired dedicated RPI execution workers.
* Keep `.copilot-tracking/` references out of production code, code comments, documentation strings, and commit messages.

## Conversation guidance

* Before substantive source edits or implementation delegation, persist the current approved implementation state from Flow step 3, then send one opening message in this shape:

	```markdown
	## 🛠️ RPI Implement: [Task] | [Full plan, Pxx, or Pxx-Txx]

	[Interpreted implementation goal.]

	* Starting scope: [active scope and first execution boundary]
	* Approved write boundary: [allowed source and artifact targets]
	* Planned validation: [expected checks or explicit validation intent]
	* Current blockers: [active blockers]
	* Relevant links: [Markdown links when available]

	These describe the current approved implementation state and may change only through the existing implementation-time update rules.
	```

	Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent state, links, or a separate conversation-delivery log.
* Before each material continual update, persist the relevant canonical state first: update the current plan and phase details when approved state changes, and update the changes record for implementation evidence and history. Generate chat as a concise projection of that state, not as a second history or delivery audit.
* Send a material update for meaningful completion, a material discovery, a blocker or decision need, or a validation boundary. Do not send one for low-level actions, unchanged state, or raw subagent returns. Use this shape, omitting a field only when it is genuinely not applicable:

	```markdown
	### [Functional marker] [Implementation state]: [Short item]

	Result: [what completed, changed, failed, or remains blocked]
	Evidence: [compact evidence basis and relevant Markdown links]
	Plan effect: [current plan or phase-detail state, including any pause or decision need]
	Next implementation effect: [next execution, validation, stop, or planning action]
	```

	Use `✅` for completed or validated work, `⚠️` for a material discovery, failed validation, or decision need, and `⛔` when progress is blocked.
* Before a user question, state the affected decision, viable choices and consequences, an evidence-backed recommendation when available, blockers, and relevant Markdown links.
* Use a small status marker such as ✅, ⚠️, or ⛔ only when it improves scanning, and pair it with text.
* At closeout, separate implementation execution status from implementation outcome or readiness for review. Summarize results, important updates, decisions, blockers or open items, and anything the user might otherwise miss.
* Advise `/compact` only when stale tool output, superseded reasoning, or completed task detail outweighs useful current context and the plan, phase details, and changes record are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* In a standalone invocation, do not invoke `rpi-review`. State `/rpi-review` as the exact next command only when review prerequisites are met. When planning or a user decision is still required, state the explicit stop or no-handoff reason. In an active `rpi-quick` or confirmed automatic RPI Agent context, return the current artifacts to the parent so it can continue automatically after gates and required confirmations pass.
* End the user-facing closeout with a Markdown table that links every relevant existing artifact and gives each a short description. The table is the final response element.

## Stop rules

* Stop as Blocked when the approved plan, required details, or a dependency prevents credible execution.
* Stop as Blocked when a decision-critical user answer needed for a major plan change, blocker, or workaround is unavailable.
* Pause affected dependent work when a material discovery may change confirmed user decisions or requirements, goals, scope, acceptance criteria, architecture, dependencies, validation strategy, or implementation approach. Return current artifacts to planning for a fresh planning and critique pass, and do not resume that work until it is implementation-ready.
* Stop after a caller-bounded phase or task once its plan state and changes evidence are current.

## Return to Caller

Return the changes-record path, implementation execution status, completed and remaining `Pxx` or `Pxx-Txx` items, validation coverage, blockers, current plan and detail updates with their planning and critique state, follow-up items, and review readiness or the explicit reason affected work awaits a user decision or fresh planning and critique. Follow the Conversation guidance section for standalone or parent-orchestrated continuation, conditional compaction advice, and the final linked artifact table.


