---
name: prompt-analyze
description: 'Compatibility alias for read-only prompt artifact review. Routes static and behavior analysis to hve-builder review mode.'
argument-hint: "[promptFiles=...] [requirements=...]"
license: MIT
user-invocable: true
---

# Prompt Analyze Compatibility Skill

## Goal

Preserve legacy `prompt-analyze` activation while producing independent static and behavior evidence through `hve-builder` in read-only `review` mode.

## Flow

1. Translate `promptFiles` to `targets` and infer current open or attached prompt-engineering artifacts when omitted.
2. Activate `hve-builder` with `mode=review`, the targets, analysis requirements, requested behavior-test fidelity, and any caller-owned evidence root.
3. Keep source artifacts read-only. Permit only review, behavior-test, and requested validation evidence writes.
4. Return the static verdict, behavior-test fidelity and verdict, validation as `Not requested` unless the caller requested it, overall outcome, findings summary, and report links.

## Inputs

* `promptFiles`: existing prompt, instruction, agent, subagent, skill, reference, or template files to review
* `requirements`: optional purpose, criteria, or behavior to emphasize
* `fidelity`: optional `simulation` or `native` request, subject to HVE Builder Tester safety preconditions
* `evidenceRoot`: optional caller-owned HVE Builder evidence path

## Success Criteria

* Source artifacts are unchanged.
* Static review and required behavior testing complete or carry an explicit deferral.
* Findings use the HVE rubric severity and fidelity contracts.
* The response links the durable review and behavior reports.

## Constraints

* Do not dispatch legacy Prompt Tester or Prompt Evaluator workers.
* Do not research, fix, refactor, or create source artifacts in this mode.
* Do not describe simulation as native runtime evidence.

## Stop Rules

* Stop Pass when `hve-builder` review mode returns Pass.
* Preserve Revise, Deferred, or Blocked and its rerun condition.
* Stop before any source edit.

## Handoff

Recommend `prompt-builder` for approved improvements or `prompt-refactor` for behavior-preserving cleanup. Both route changes through `hve-builder`.

## Final Response Contract

Return targets, static verdict, behavior-test profile and fidelity, behavior verdict, validation result (`Not requested` unless requested), overall outcome, top findings, report links, and next action.
