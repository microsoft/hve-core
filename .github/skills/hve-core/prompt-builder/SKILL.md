---
name: prompt-builder
description: 'Compatibility alias for legacy prompt-building requests. Routes creation and improvement to the hve-builder skill.'
argument-hint: "[promptFiles=...] [files=...] [requirements=...]"
license: MIT
user-invocable: true
---

# Prompt Builder Compatibility Skill

## Goal

Preserve legacy `prompt-builder` activation while routing all source changes, review, behavior testing, validation, and outcome resolution through the `hve-builder` skill.

## Flow

1. Translate `promptFiles` to `targets`. Treat `files` as reference context unless the caller explicitly includes them in the write boundary.
2. Resolve `create` when an approved target is missing and `improve` when targets already exist. Route explicit cleanup to the `prompt-refactor` compatibility skill and read-only analysis to `prompt-analyze`.
3. Activate `hve-builder` with the targets, selected mode, requirements, reference context, and any caller-owned evidence root.
4. Return the `hve-builder` final response without adding a second author, test, or evaluation loop.

## Inputs

* `promptFiles`: target prompt-engineering artifacts; defaults to current open or attached files
* `files`: reference artifacts used to derive requirements
* `requirements`: explicit objectives, constraints, and acceptance criteria
* `evidenceRoot`: optional caller-owned HVE Builder evidence path

## Success Criteria

* Legacy inputs map to an explicit HVE Builder target set and write boundary.
* `hve-builder` completes every required gate for the selected mode.
* The returned overall outcome is unchanged from `hve-builder`.

## Constraints

* Do not dispatch `Prompt Tester`, `Prompt Evaluator`, or `Prompt Updater`.
* Do not maintain a second sandbox, status vocabulary, or quality rubric.
* Do not treat reference files as write targets without explicit approval.

## Stop Rules

* Stop when `hve-builder` returns Pass, Revise, Deferred, or Blocked.
* Ask only when target identity or write authority cannot be inferred safely.

## Handoff

Use `prompt-analyze` for a legacy read-only request and `prompt-refactor` for a legacy behavior-preserving cleanup request. Both route back to `hve-builder`.

## Final Response Contract

Return the mode, targets, changed files, static verdict, behavior-test fidelity and verdict, validation result, overall outcome, evidence links, and next action.
