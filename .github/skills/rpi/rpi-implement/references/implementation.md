---
description: "Reference protocol for following a marker-based RPI plan, keeping it current, checking off work, and keeping a condensed changes record."
---

# RPI Implement Reference

## Artifact contract

Read the task-centered plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`. Create or update `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` for implementation evidence.

Navigate plan content through `<!-- rpi:phase id=Pxx -->`, `<!-- rpi:task id=Pxx-Txx -->`, and their headings; enable searching through ignored files for the plan. Do not create or maintain line-number references or separate legacy log artifacts.

In both artifacts, wrap code, commands, and symbols in backticks. Link an existing file or folder with the workspace-relative path as the link text and a path relative to the artifact file as the destination; from `.copilot-tracking/changes/{{YYYY-MM-DD}}/`, a repository file is three levels up and the plan is at `../../plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md`. Keep a not-yet-created path in backticks and convert it to a link once the file exists.

## Following the plan and checking off work

1. Resolve declared invocation scope before changing source. With no exact scope, the full plan is in scope. An exact `Pxx` includes that phase and its tasks; an exact `Pxx-Txx` includes that task only. Keep all other active-plan markers outside completion claims.
2. Read the first unchecked applicable plan item and its labeled blocks: `Goals:`, `Requirements:`, `Details:`, `Guidance:` when present, `References:`, and `Dependencies:`. Open the linked references, the decision and risk table rows that name the task, the latest critique disposition, the prior changes record, and relevant evidence. Select the first dependency-ready item in plan order. Do not advance a dependent item until its plan prerequisites are checked.
3. Complete the item so that its `Requirements:` hold, then write its changes-record entry.
4. Check the `Pxx-Txx` marker immediately after the entry exists. The checked marker and the changes record are the completion record; the plan carries no per-task evidence block. Check a `Pxx` phase immediately after every task in it is checked and the phase is within declared scope. A bounded task does not complete its containing phase. Never check an item outside declared scope.
5. Record each check the plan names as passed, failed, skipped, or unavailable, with the relevant reason or output summary.

## Changes record

The changes record is a condensed history of what the implementation changed in behavior and functionality. It is evidence for Review and for anyone resuming the work, not a narration of edits.

Write one entry per completed item under a descriptive heading. Each entry names the related `Pxx` or `Pxx-Txx`, the files affected, what now behaves or works differently and why, and the validation result. Describe outcomes such as a new capability, a changed contract, a corrected behavior, or a removed path. Leave out the sequence of edits, tool calls, and intermediate states.

Record plan updates, blockers, remaining work, and follow-up items in their own sections as they occur. The changes record holds rationale and history; the plan holds current state.

## Implementation-time plan updates

Apply this decision rule when new information comes to light:

1. Use ordinary local judgment without changing the plan when the discovery does not warrant a plan update.
2. Apply an immediately relevant update when it needs no new user decision or planning reconsideration. Update the current plan to clarify factual `References:`, `Requirements:`, `Details:`, task wording, sequencing, or directly required in-scope work while preserving approved intent.
   * Add a `Guidance:` block to a later task when completed work created something that task needs and the plan did not already name it: a class, API, contract, utility, fixture, script, or path that a future agent would otherwise have to rediscover. Place the block immediately after that task's `Details:` and keep each bullet concrete, for example a bullet that says to consider using the contracts added under `scripts/plugins/contracts/`. Do not restate what the task's existing blocks already say.
   * Keep the Phase Checklist diagrams current when an update adds, merges, splits, or removes phases or tasks, reusing the existing node IDs.
3. Use a follow-up-only update when newly discovered work is outside immediate scope. Add its item to the plan's `## Follow-Up Items` section with the outside-immediate-scope reason, triggering evidence, and owner or next action. Keep it outside active `Pxx` and `Pxx-Txx` completion and acceptance claims.
4. Treat a discovery as material only when a new user decision would change assessed requirements, scope, architecture, dependency model, or evidence boundary. Corrections, test work, and validation refinement within the approved scope remain in Implement.

For every plan update, add a descriptive changes-record entry that records the affected plan area or `Pxx` or `Pxx-Txx` marker, what changed, why, triggering evidence, user answer or decision when present, reconciliation performed, and planning and critique state when material.

For an immediately relevant update, reconcile all affected current-state sections: `## User Decisions and Requirements` only when confirmed user intent changed; executive summary; goals; scope and non-goals; functional and non-functional requirements; the affected task blocks; current phase and task markers and checklist; diagrams; dependencies; critique inputs and disposition; and follow-up items as applicable. Remove superseded active content instead of retaining history in the plan. Keep the rationale and evidence history in the changes record. A `Guidance:` addition needs only a brief changes-record entry naming the task and what was pointed to.

For a follow-up-only update, record the item, why it is outside immediate scope, triggering evidence, and owner or next action in `## Follow-Up Items` and mirror it in the changes record. Exclude it from active implementation, completion, and acceptance claims.

Use the native `vscode_askQuestions` tool only when available evidence cannot support a responsible user-owned decision. This includes unresolved significant or divergent plan changes, blockers, and proposed workarounds, but not ordinary local judgment. Immediately before the tool call, send a visible conversation message that states the affected user decision or requirement and plan area, evidence or conflict, viable choices, material consequences, an evidence-backed recommendation when available, and Markdown links to relevant artifacts or sources when available. Ask the smallest decision-critical question set. Persist the answer and resulting decision in `## User Decisions and Requirements`, every affected current synthesized section, and the changes record. Stop affected work as Blocked when required feedback is unavailable. The user's answer resolves the decision; do not run another critique.

## Review findings and pre-Review reconciliation

When a later standalone invocation implements Review findings, treat the applicable `RV-xxx` entries as ordinary plan inputs. Record the changed behavior, affected files, and validation in the changes record. Do not create correction or amended run types, and do not require another Review.

Before handoff to Review, reconcile current plan markers and task-local context, changes-record entries, handoff prose, blockers, remaining work, follow-up items, and validation state. Do not hand off stale status text or unchecked work as complete.

## Material discovery and resumption

A discovery requires planning reconsideration only when a significant or divergent user decision changes assessed requirements, scope, architecture, dependency model, or evidence boundary. Before affected dependent work can resume:

1. Record the discovery, affected `Pxx` or `Pxx-Txx`, current plan state, triggering evidence, impact, and paused work in the changes record.
2. Return the current plan and evidence to the planning owner when the accepted plan must change.
3. Reconcile the plan through the planning owner's current-state process. Preserve unrelated completed work and its evidence.
4. Resume only affected dependent work after the user decision and updated plan state are current. Preserve the one critique as historical evidence and record the resulting decision state in the changes record.

On resumption, continue from the first unchecked dependency-ready item in declared scope. Read the prior changes-record entries, current plan markers and task-local context, and latest critique disposition. Do not resume a task awaiting a user decision or advance a dependent item before its prerequisites are checked.

## Conversation protocol

Before substantive source edits, bring the plan and changes record current. Record the active scope, planned validation, blockers, and the first item to work. Then send one concise canonical `RPI Implement` opening using this shape:

```markdown
## 🛠️ RPI Implement: [Task] | [Full plan, Pxx, or Pxx-Txx]

[Interpreted implementation goal.]

* Starting scope: [active scope and first item]
* Planned validation: [checks the plan names or explicit validation intent]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

These describe the current approved plan state and may evolve only through the implementation-time update rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent state, links, or a separate conversation-delivery log.

Before each potential continual update, persist the relevant canonical state first: update the current plan when approved state changes, and add the changes-record entry for completed work or history. Chat is a concise projection of that state, not a second history or delivery audit. A continual update is warranted only when the item changes phase direction, a current decision or readiness state, a material result or artifact state, a blocker or decision need, validation state where applicable, handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted, omitting a field only when it is genuinely not applicable:

```markdown
### [Functional marker when useful] [Implementation state]: [Short item]

Result: [what completed, changed, failed, or remains blocked]

Evidence: [compact evidence basis and relevant Markdown links]

Plan effect: [current task-centered plan state, including any pause or decision need]

Next implementation action: [next plan item, validation, stop, or planning action]
```

Use `✅` for completed or validated work, `⚠️` for a material discovery, failed validation, or decision need, and `⛔` when progress is blocked. Use a marker only when it improves scanning and pair it with text.

Before a user question, state the affected decision, viable choices and consequences, an evidence-backed recommendation when available, blockers, and relevant Markdown links. At closeout, report implementation execution status separately from review readiness. Include results, material updates, decisions, and blockers or open items. Advise `/compact` only when stale output, superseded reasoning, or completed task detail outweighs current context and the plan and changes record are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

## Implementation Closeout Projection

Qualify every Complete, Partial, or Blocked status by the declared invocation scope: full plan, `Pxx`, or `Pxx-Txx`. A Complete bounded scope confirms only its checked scope markers; it does not imply the full plan is complete. Show all remaining active-plan markers, including later work outside the declared scope, so the caller can distinguish bounded completion from task completion. A bounded task leaves its containing phase unchecked unless all phase tasks are checked within a declared phase or full-plan scope.

The closeout also states validation coverage, blockers with their owner and clearing action, current planning state, and review readiness or the explicit no-handoff reason. For a user-owned blocker, state that affected work cannot continue until the required response is recorded. For a dependency-owned blocker, name the dependency owner and the evidence needed to clear it.

In standalone use, do not present unchecked work as a retry or start the plan again. Advise `/rpi-review` only when review prerequisites are met; otherwise state the current no-handoff reason. In confirmed automatic RPI Agent mode, return the same scope and readiness facts to the parent, which owns eligible continuation after its gates and required confirmations pass.

## Return to caller

During material work, apply the Conversation protocol. Before a user decision, state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

Apply the Implementation Closeout Projection. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Production-reference hygiene

Tracking paths guide the work but do not belong in production code, code comments, documentation strings, or commit messages. Keep shipped references durable and self-contained.
