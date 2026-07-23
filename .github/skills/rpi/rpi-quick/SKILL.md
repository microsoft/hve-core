---
name: rpi-quick
description: "Sequence Research, Plan, Implement, Review, and Follow-up for an RPI task. Use when one workflow should coordinate the full delivery lifecycle."
argument-hint: "[task=...] [continue=...] [followUp=...]"
license: MIT
user-invocable: true
---

# RPI

## Goal

Coordinate one task through evidence, planning, execution, review, and explicit follow-up without duplicating the phase skills' detailed responsibilities.

## Flow

1. Assess research readiness from caller-supplied research, task details, decisions, and plan inputs.
	1. Activate `rpi-research` only when evidence is missing, stale, contradictory, insufficient for planning, or when complexity, uncertainty, dependencies, risk, or a decision-critical question warrants investigation. Record Research disposition `executed` and consume the primary artifact's Planning Readiness.
	2. When evidence is adequate, record disposition `reused` or `satisfied-and-skipped` with the evidence that supports it.
	3. Apply the `rpi-research` continuation contract. Continue to Plan without another stage-start command only when either an executed Research primary artifact records Planning Readiness `Ready`, or reused or satisfied-and-skipped evidence is adequate, and all applicable gates pass, blockers clear, and required confirmations are explicit.
	4. When Research is `Blocked`, `Needs clarification`, or `Not ready`, or another transition requirement is not met, stop in Research and record the blocker or next action.
2. Run `rpi-plan` to create or revise the ordinary Markdown plan and phase details. Its `rpi-plan-critique` gate is internal to planning and returns its disposition to the planning parent.
3. Run `rpi-implement` for approved `Pxx` and `Pxx-Txx` work. Consume its return, including completed and remaining markers, validation coverage, blockers, plan and detail updates, follow-up items, and readiness or the reason work is awaiting a significant or divergent user decision.
4. Run `rpi-review` once after Implementation returns and no affected work awaits a user decision. Compare the current plan, details, critique, descriptive changes record, and validation evidence. Record execution status separately from outcome.
5. Follow-up: route defects, decision gaps, research gaps, and residual work to their correct next destination.

When Review finds open work, route it to the appropriate later stage or distinct follow-up item. Do not execute it or run Review again inside the current lifecycle.

## Delegation crosswalk

* Research readiness -> assess existing evidence, then use `rpi-research` only for a demonstrated investigation need
* Plan -> `rpi-plan`, which may use `RPI Planner` for one exact phase and `rpi-plan-critique` for an independent critique
* Implement -> `rpi-implement`
* Review -> `rpi-review`
* Follow-up -> handled by the parent from the review record

## Inputs

* `task`: primary task description or inferred task context
* `evidence`: caller-supplied research, task details, decisions, and plan inputs to assess for research readiness
* `continue`: resume an active task from its durable artifacts
* `followUp`: select a distinct review follow-up item

## Success criteria

* One task identity, date, and task slug link any durable artifacts.
* Research readiness records the `executed`, `reused`, or `satisfied-and-skipped` disposition, Planning Readiness or adequacy evidence, and the gates or confirmations that permit or stop continuation.
* Each phase uses the matching RPI skill rather than duplicating its workflow.
* Planning uses marker-addressed plain Markdown artifacts and exactly one independent critique. Confirmed user requests and answers remain authoritative over critique advice.
* Implementation returns descriptive evidence, current plan and detail updates, validation coverage, blockers, and follow-up items. A significant or divergent change pauses affected work until the user decision and plan state are current; critique is not repeated.
* Review separates execution status from outcome and routes every open item.
* Follow-up identifies whether work returns to research, planning, implementation, or a distinct future item.

## Constraints

* Keep this skill as a sequencing layer, not a duplicate of phase protocols.
* Use the smallest appropriate stage action. Do not create process work solely to satisfy a lifecycle label.
* Treat caller-supplied research, task details, decisions, and plan inputs as evidence to assess, not as a requirement to repeat Research.
* Keep internal tracking paths out of production code, code comments, documentation strings, and commit messages.
* Treat unresolved product decisions and decision-critical evidence gaps as hard stops for the affected stage.

## Conversation guidance

* During material orchestration work, provide concise updates at stage boundaries. Explain the current stage and why it is eligible, what changed or was learned, key decisions, blockers, results, relevant artifact links, and one important point the user might otherwise miss. Do not narrate low-level actions.
* Before a user question or required confirmation, state the decision context, viable choices and consequences, an evidence-backed recommendation when available, blockers, and relevant Markdown links.
* Use a small status marker such as ✅, ⚠️, or ⛔ only when it improves scanning, and pair it with text.
* At closeout, separate lifecycle execution or session status from outcome or decision state. Summarize results, important updates, decisions, blockers or open items, and anything the user might otherwise miss.
* Advise `/compact` only when stale tool output, superseded reasoning, or completed-stage detail outweighs useful current context and the durable phase artifacts are current. When advising it, name the state and artifact pointers to retain. Otherwise omit compaction guidance.
* `rpi-quick` is an explicit parent orchestration context. Continue automatically to each eligible stage without waiting for a new user command, while honoring every stage gate, blocker, risky-action confirmation, and user-owned decision. State when a blocker or confirmation returns control to the user.
* For every relevant existing artifact, use the two-cell row `| [Descriptive label](actual/workspace-relative/path.ext) | Short description |`, replacing `actual/workspace-relative/path.ext` with that artifact's actual workspace-relative path; omit unavailable files and keep the table as the final response element.

## Stop rules

* Stop the active stage when its needed evidence, decision, or dependency is unavailable. Pause affected dependent implementation when a significant or divergent revision awaits a user decision.
* Do not claim an accepted outcome while critical review findings remain open.
* Route Review findings to the earliest appropriate later stage or a distinct follow-up without executing another stage in the current lifecycle.

## Handoff

As the explicit parent, use the `rpi-research` continuation contract. Activate Research only when the research-readiness assessment warrants investigation; otherwise record the reused or satisfied-and-skipped disposition and adequacy evidence. Continue to Plan only through the contract's eligible Research outcome. Continue through `rpi-implement` and `rpi-review` only when their prerequisites are met. Follow-up routes to the earliest affected stage or a distinct next task. Do not wait for another user command between eligible stages, but pause for a blocker or required confirmation.

## Final response contract

Return lifecycle execution or session status separately from the research-readiness and review outcome state. Include phase status, durable artifact paths, validation coverage, blockers, routed follow-up items, conditional compaction advice when warranted, and whether the parent continues automatically or awaits a required confirmation. End with the linked artifact table required by Conversation guidance.


