---
description: "Reference protocol for marker-based RPI implementation, current-state maintenance, and evidence-led return."
---

# RPI Implement Reference

## Artifact contract

Read the plan at `.copilot-tracking/plans/{{YYYY-MM-DD}}/{{task_slug}}-plan.md` and phase details at `.copilot-tracking/details/{{YYYY-MM-DD}}/{{task_slug}}-phase-details.md`. Create or update `.copilot-tracking/changes/{{YYYY-MM-DD}}/{{task_slug}}-changes.md` for implementation evidence.

Navigate plan and detail content through `<!-- rpi:phase id=Pxx -->`, `<!-- rpi:task id=Pxx-Txx -->`, and their headings, enable searching through ignored files for plan and details files. Do not create or maintain line-number references or separate legacy log artifacts.

## Execution and tracking

1. Resolve declared invocation scope before changing source. With no exact scope, the full plan is in scope. An exact `Pxx` includes that phase and its tasks; an exact `Pxx-Txx` includes that task only. Keep all other active-plan markers outside implementation and completion claims.
2. Read the first unchecked applicable plan item, matching details, latest critique disposition, prior changes record, and relevant evidence. Select the first dependency-ready item in plan order. Do not advance a dependent item until its plan prerequisites have completion evidence.
3. Execute that item. The primary implementation agent executes every individual `Pxx-Txx` task and may delegate only a whole `Pxx` phase that is in declared scope, dependency-ready, independent, parallelizable, and write-disjoint. A delegated phase has a clear phase scope, dependencies, disjoint write boundary, expected evidence return, and consuming parent step. The primary implementation agent retains plan order, consumes phase returns, reconciles plan and changes-record state, applies implementation-time plan updates, and updates completion markers. Do not parallelize overlapping writes or work whose dependencies are unresolved.
4. Mark each completed `Pxx-Txx` task immediately after its stated completion evidence exists. Mark a `Pxx` phase immediately after all of that phase's plan tasks have completion evidence and the full phase is declared scope. A bounded task does not complete its containing phase. Never mark an item outside declared scope.
5. Record material work under descriptive changes-record headings. For every completed-work item, include related `Pxx` or `Pxx-Txx`, files, what changed and why, completion evidence, and validation.
6. Record validation as run, passed, failed, skipped, or unavailable, with the relevant reason or output summary.

## Implementation-time plan updates

Apply this decision rule when implementation reveals new information:

1. Use ordinary local implementation judgment without changing the plan when the discovery does not warrant a plan or phase-detail update.
2. Apply an immediately relevant update when it needs no new user decision or planning reconsideration. The primary implementation agent may update the current plan and matching phase details to clarify factual targets, task wording, sequencing, or directly required in-scope work while preserving approved intent.
3. Use a follow-up-only update when newly discovered work is outside immediate implementation scope. Add its item to the plan's `## Follow-Up Items` section with the outside-immediate-scope reason, triggering evidence, and owner or next action. Keep it outside active `Pxx` and `Pxx-Txx` implementation, completion, and acceptance claims.
4. Treat a discovery as material only when a new material user decision changes assessed requirements, scope, architecture, acceptance criteria, dependency model, or evidence boundary. Local grader or fixture corrections, generated-output repair, tracking reconciliation, validation-command refinement, and test implementation within an approved owner, behavior list, maximum case count, and evidence boundary remain in Implement.

For every plan or detail update, use a descriptive changes-record subheading and record the affected plan area or `Pxx` or `Pxx-Txx` marker, what changed, why, triggering evidence, user answer or decision when present, reconciliation performed, and planning and critique state when material. The changes record is evidence history, not the authority for active plan state.

For an immediately relevant update, reconcile all affected current-state sections: `## User Decisions and Requirements` only when confirmed user intent changed; executive summary; goals; scope and non-goals; functional and non-functional requirements; acceptance criteria; current phase and task markers and checklist; details; dependencies; critique inputs and disposition; and follow-up items as applicable. Remove superseded active content instead of retaining history in the plan. Keep the rationale and evidence history in the changes record.

For a follow-up-only update, record the item, why it is outside immediate scope, triggering evidence, and owner or next action in `## Follow-Up Items` and mirror it in the changes record. Exclude it from active implementation, completion, and acceptance claims.

Use the native `vscode_askQuestions` tool only when available evidence cannot support a responsible user-owned decision. This includes unresolved significant or divergent plan changes, blockers, and proposed workarounds, but not ordinary local implementation judgment. Immediately before the tool call, send a visible conversation message that states the affected user decision or requirement and plan area, evidence or conflict, viable choices, material consequences, an evidence-backed recommendation when available, and Markdown links to relevant artifacts or sources when available. Ask the smallest decision-critical question set. Persist the answer and resulting decision in `## User Decisions and Requirements`, every affected current synthesized section, and the changes record. Stop affected work as Blocked when required feedback is unavailable. The user's answer resolves the decision; do not run another critique.

When implementation discovers work that is not immediately related to the approved plan, use a follow-up-only update. Do not add it to active `Pxx` or `Pxx-Txx` implementation, completion, or acceptance claims.

## Batching, Review findings, and pre-Review reconciliation

Complete approved source edits in a coherent batch before downstream HVE static, behavior, or validation gates. When a later standalone invocation implements Review findings, treat the applicable `RV-xxx` entries as ordinary inputs. Record changed files, the implemented result, and validation. Do not create correction or amended run types, and do not require another Review.

Before handoff to Review, reconcile current plan markers, phase details, completed-work evidence, handoff prose, blockers, remaining work, follow-up items, and validation state. Do not hand off stale status text or unchecked work as complete.

## Material discovery and resumption

A discovery requires planning reconsideration only when a significant or divergent user decision changes assessed requirements, scope, architecture, acceptance criteria, dependency model, or evidence boundary. Before affected dependent work can resume:

1. Record the discovery, affected `Pxx` or `Pxx-Txx`, current plan and detail state, triggering evidence, impact, and paused work in the changes record.
2. Return the current plan, phase details, and evidence to the planning owner when the accepted plan must change.
3. Reconcile the plan and phase details through the planning owner's current-state process. Preserve unrelated completed work and its evidence.
4. Resume only affected dependent work after the user decision and updated plan state are current. Preserve the one critique as historical evidence and record the resulting decision state in the changes record.

On resumption, continue from the first unchecked dependency-ready item in declared scope. Read prior descriptive changes-record sections, current plan markers, phase details, and latest critique disposition. Do not resume a task awaiting a user decision or advance a dependent item before its prerequisites have completion evidence.

## Conversation protocol

Before substantive source edits or implementation delegation, persist canonical approved implementation state in the plan, phase details, and changes record sections that own it. Record the active implementation scope, approved write boundary, validation intent, blockers, and first execution boundary. Then send one concise canonical `RPI Implement` opening using this shape:

```markdown
## 🛠️ RPI Implement: [Task] | [Full plan, Pxx, or Pxx-Txx]

[Interpreted implementation goal.]

* Starting scope: [active scope and first execution boundary]
* Approved write boundary: [allowed source and artifact targets]
* Planned validation: [expected checks or explicit validation intent]
* Current blockers: [active blockers]
* Relevant links: [Markdown links when available]

These describe the current approved implementation state and may evolve only through the existing implementation-time update rules.
```

Omit Current blockers when none are active. Omit Relevant links when no valid link is available. Do not invent state, links, or a separate conversation-delivery log.

Before each potential continual update, persist the relevant canonical state first: update the current plan and phase details when approved state changes, and update the changes record for implementation evidence and history. Chat is a concise projection of that state, not a second history or delivery audit. A continual update is warranted only when the item changes phase direction, a current decision or readiness state, a material result or artifact state, a blocker or decision need, validation state where applicable, handoff, or the user's likely understanding. Suppress low-level actions, routine tool calls, raw subagent returns, unchanged state, and minor rows or edits.

Use this compact shape when a message is warranted, omitting a field only when it is genuinely not applicable:

```markdown
### [Functional marker when useful] [Implementation state]: [Short item]

Result: [what completed, changed, failed, or remains blocked]

Evidence: [compact evidence basis and relevant Markdown links]

Plan effect: [current plan or phase-detail state, including any pause or decision need]

Next implementation action: [next execution, validation, stop, or planning action]
```

Use `✅` for completed or validated work, `⚠️` for a material discovery, failed validation, or decision need, and `⛔` when progress is blocked. Use a marker only when it improves scanning and pair it with text.

Before a user question, state the affected decision, viable choices and consequences, an evidence-backed recommendation when available, blockers, and relevant Markdown links. At closeout, report implementation execution status separately from review readiness. Include results, material updates, decisions, and blockers or open items. Advise `/compact` only when stale output, superseded reasoning, or completed task detail outweighs current context and the plan, details, and changes record are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.

## Implementation Closeout Projection

Qualify every Complete, Partial, or Blocked status by the declared invocation scope: full plan, `Pxx`, or `Pxx-Txx`. A Complete bounded scope confirms only its completed scope markers; it does not imply the full plan is complete. Show all remaining active-plan markers, including later work outside the declared scope, so the caller can distinguish bounded completion from task completion. A bounded task leaves its containing phase unchecked unless all phase tasks have completion evidence within a declared phase or full-plan scope.

The closeout also states validation coverage, blockers with their owner and clearing action, current planning state, and review readiness or the explicit no-handoff reason. For a user-owned blocker, state that affected work cannot continue until the required response is recorded. For a dependency-owned blocker, name the dependency owner and the evidence needed to clear it.

In standalone use, do not present unchecked work as a retry or trigger implementation again. Advise `/rpi-review` only when review prerequisites are met; otherwise state the current no-handoff reason. In `rpi-quick` or confirmed automatic RPI Agent mode, return the same scope and readiness facts to the parent, which owns eligible continuation after its gates and required confirmations pass.

## Return to caller

During material work, apply the Conversation protocol. Before a user decision, state the decision context, viable choices and consequences, evidence-backed recommendation when available, blockers, and relevant Markdown links.

Apply the Implementation Closeout Projection. For every relevant existing artifact, use the two-cell row `| [actual/workspace-relative/path.ext](actual/workspace-relative/path.ext) | Short description |`, using that artifact's actual workspace-relative path as both link text and destination; omit unavailable files and render the table immediately before the final `## Next Steps` section. End with `## Next Steps`: state the exact eligible user command, active-parent action, blocker-clearing action, or that no user action is required. When compaction is warranted, tell the user to run `/compact` before the next RPI command; otherwise omit compaction guidance.

## Production-reference hygiene

Tracking paths guide implementation but do not belong in production code, code comments, documentation strings, or commit messages. Keep shipped references durable and self-contained.
