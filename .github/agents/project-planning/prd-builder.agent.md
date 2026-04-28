---
name: PRD Builder
description: "[DEPRECATED — use Requirements Builder] Legacy PRD-only entrypoint, redirected to the unified six-phase requirements-builder agent."
---

# PRD Builder (Deprecated)

> **Status: Deprecated.** This agent has been superseded by the unified
> [`requirements-builder`](./requirements-builder.agent.md), which authors PRDs,
> BRDs, and other requirements artifacts under a single six-phase Framework Skill
> Interface (FSI) workflow.

## What changed

* PRD authoring now resolves Framework Skills under `.github/skills/requirements/requirements-prd/` via `Get-FrameworkSkill -Domain requirements`.
* Session state moves from `.copilot-tracking/prd-sessions/{slug}/` to `.copilot-tracking/requirements-sessions/{slug}/` (legacy folders remain readable for in-flight work).
* Six phase split: identity, intake, template-selection, drafting, review, handoff — see `.github/instructions/project-planning/requirements-*.instructions.md`.

## What to do

Invoke `requirements-builder` instead:

* Ad-hoc start: `@requirements-builder` and answer the framework multi-select with `requirements-prd`.
* Resuming legacy `prd-sessions/{slug}/` work: open `requirements-builder` and pass the slug; it reads the legacy directory in read-only mode and writes new artifacts under `requirements-sessions/{slug}/`.

## File-path contract preservation

Final output paths remain `docs/prds/<slug>.md`. Downstream prompts (`security-plan-from-prd`, `sssc-from-prd`, `rai-plan-from-prd`, `sustainability-from-prd`, `ado-prd-to-wit`, `jira-prd-to-wit`) continue to consume the same locations.
