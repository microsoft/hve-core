---
name: prompt-refactor
description: 'Compatibility alias for behavior-preserving prompt artifact cleanup. Routes refactoring to hve-builder refactor mode.'
argument-hint: "[promptFiles=...] [requirements=...]"
license: MIT
user-invocable: true
---

# Prompt Refactor Compatibility Skill

## Goal

Preserve legacy `prompt-refactor` activation while simplifying approved prompt-engineering artifacts through the `hve-builder` refactor route and its independent quality gates.

## Flow

1. Translate `promptFiles` to existing `targets` and resolve the behavior that must remain unchanged.
2. When requirements are omitted, use the HVE Builder baseline review to derive evidence-backed cleanup objectives.
3. Activate `hve-builder` with `mode=refactor`, the approved write boundary, requirements, and any caller-owned evidence root.
4. Return the HVE Builder static verdict, behavior-test fidelity and verdict, validation result, and overall outcome.

## Inputs

* `promptFiles`: existing prompt-engineering artifacts to refactor
* `requirements`: optional cleanup objectives, constraints, and preserved behavior
* `evidenceRoot`: optional caller-owned HVE Builder evidence path

## Success Criteria

* The approved targets are simpler without unintended behavior change.
* Static review, behavior testing, and host validation pass.
* Source changes stay inside the approved write boundary.
* The returned overall outcome is unchanged from `hve-builder`.

## Constraints

* Do not dispatch legacy Prompt Tester, Prompt Evaluator, or Prompt Updater workers.
* Do not create a second orchestration loop or sandbox contract.
* Route a requested type change, artifact split, or new support artifact back through HVE Builder scope approval.

## Stop Rules

* Stop Pass only when the HVE Builder refactor route passes every required gate.
* Preserve Revise, Deferred, or Blocked and its rerun condition.
* Ask when preserved behavior or write scope cannot be inferred safely.

## Handoff

Use `prompt-analyze` for read-only follow-up review and `prompt-builder` when the requested work intentionally changes behavior or creates artifacts.

## Final Response Contract

Return targets, changed files, refactor rationale, static verdict, behavior-test fidelity and verdict, validation result, overall outcome, evidence links, and next action.
