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

1. Research readiness: assess caller-supplied research, task details, decisions, and plan inputs for a credible evidence set. Activate `rpi-research` only when evidence is missing, stale, contradictory, insufficient for planning, or when complexity, uncertainty, dependencies, risk, or a decision-critical question warrants investigation. If evidence is adequate, record why Research is reused or satisfied-and-skipped, then continue to Plan.
2. Plan: create or revise the ordinary Markdown plan, phase details, and critique disposition when durable planning is needed.
3. Implement: execute approved `Pxx` and `Pxx-Txx` work, maintain the changes record, and amend significant divergence explicitly. Return a material amendment to the planning parent for fresh `rpi-plan-critique`; affected dependent work resumes only with Pass.
4. Review: compare plan, details, critique, amendments, changes, and validation evidence, then record a separate execution status and outcome.
5. Follow-up: route defects, decision gaps, research gaps, and residual work to their correct next destination.

If Review finds active-task work, return to the earliest affected stage. If Review identifies residual work outside the active task, create a distinct follow-up item rather than reopening the completed scope.

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
* Research readiness records why `rpi-research` is activated or why Research is reused or satisfied-and-skipped.
* Each phase uses the matching RPI skill rather than duplicating its workflow.
* Planning uses marker-addressed plain Markdown artifacts and independent critique evidence, including a fresh disposition for a material implementation amendment.
* Implementation records `CHG-xxx` changes, links significant `DIV-xxx` records to `AM-xxx` amendments, and does not resume affected dependent work before Pass.
* Review separates execution status from outcome and routes every open item.
* Follow-up identifies whether work returns to research, planning, implementation, or a distinct future item.

## Constraints

* Keep this skill as a sequencing layer, not a duplicate of phase protocols.
* Use the smallest appropriate stage action. Do not create process work solely to satisfy a lifecycle label.
* Treat caller-supplied research, task details, decisions, and plan inputs as evidence to assess, not as a requirement to repeat Research.
* Keep internal tracking paths out of production code, code comments, documentation strings, and commit messages.
* Treat unresolved product decisions and decision-critical evidence gaps as hard stops for the affected stage.

## Stop rules

* Stop the active stage when its needed evidence, decision, or dependency is unavailable. Pause affected dependent implementation when a material amendment awaits a fresh critique disposition.
* Do not claim an accepted outcome while critical review findings remain open.
* Return to the earliest affected stage after review instead of hiding work in a generic follow-up.

## Handoff

Use `rpi-research` only when the research-readiness assessment warrants investigation. Otherwise hand adequate evidence to `rpi-plan` and record its reused or satisfied-and-skipped disposition. Use `rpi-implement` and `rpi-review` for their respective phase work. Follow-up routes to one of those stages or to a distinct next task.

## Final response contract

Return phase status, the research-readiness disposition and reason, durable artifact paths, validation coverage, review execution status and outcome, and the routed follow-up items.


