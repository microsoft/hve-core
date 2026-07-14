---
name: rpi-plan-critique
description: "Independently critique an RPI plan and phase details against supplied evidence without editing plan sources. Use when planning credibility needs a read-only assessment."
argument-hint: "[plan=...] [details=...] [evidence=...] [output=...]"
license: MIT
user-invocable: true
---

# RPI Plan Critique

## Goal

Return a substantive, evidence-grounded credibility assessment of an RPI plan and its phase details. The critique is read-only with respect to plan sources and writes only the caller-specified critique artifact.

## Flow

1. Confirm the exact plan, phase-details, evidence, requirements, decisions, dependencies, acceptance criteria, and critique output path supplied by the caller.
2. Read the supplied materials. Do not perform open-ended research or infer missing evidence as fact.
3. Define the supplied inputs and criterion boundary, then assess coverage across requirements, research, phases, tasks, acceptance criteria, dependencies, decisions, risks, and missed concerns.
4. Write the critique using [templates/plan-critique.md](templates/plan-critique.md). Use severity-graded `PC-xxx` findings keyed to relevant requirement, research, phase, or task IDs, and name the smallest useful change for each actionable finding.
5. Return Pass, Revise, or Blocked. A passing critique may identify residual risks that the planning parent has explicitly accepted.

## Inputs

* Plan and phase-details paths
* Caller requirements and task context
* Supplied research, evidence pointers, draft details, and decisions
* Dependencies and acceptance criteria
* One critique output path

## Success criteria

* The critique distinguishes evidence-backed concerns from missing evidence.
* Findings identify substantive gaps rather than structure, formatting, or cosmetic preferences.
* The critique records its inputs, criterion boundary, coverage assessment, and limitations.
* Each actionable finding has a severity, related IDs, evidence, impact, and smallest useful change.
* The plan and phase-details sources remain unchanged.

## Constraints

* Do not edit plan sources, phase details, research, changes, or review records.
* Do not perform research beyond the supplied inputs. Route a material research gap to the planning parent as a Blocked or Revise finding.
* Do not grade formatting, document cosmetics, or template adherence unless the issue conceals a substantive planning risk.
* Use plain-text workspace-relative paths in the output artifact.

## Stop rules

* Return Blocked when supplied evidence cannot support a decision-critical assessment.
* Return Revise when substantive findings require a plan change.
* Return Pass when the plan is credible for implementation and any residual risks are explicitly accepted.

## Handoff

Return the verdict, output path, severity summary, and the smallest next action. The planning parent decides whether to revise directly, delegate one phase to `RPI Planner`, obtain a decision, rerun critique, or finalize.

## Final response contract

Return Pass, Revise, or Blocked; the critique output path; severity counts; the highest-impact `PC-xxx` findings; and the smallest recommended next action. Do not reproduce the full critique in the response.
