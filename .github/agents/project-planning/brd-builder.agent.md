---
name: BRD Builder
description: "[DEPRECATED — use Requirements Builder] Legacy BRD-only entrypoint, redirected to the unified six-phase requirements-builder agent."
---

# BRD Builder (Deprecated)

> **Status: Deprecated.** This agent has been superseded by the unified
> [`requirements-builder`](./requirements-builder.agent.md), which authors PRDs,
> BRDs, and other requirements artifacts under a single six-phase Framework Skill
> Interface (FSI) workflow.

## What changed

* BRD authoring now resolves Framework Skills under `.github/skills/requirements/requirements-brd/` via `Get-FrameworkSkill -Domain requirements`.
* Session state moves from `.copilot-tracking/brd-sessions/{slug}/` to `.copilot-tracking/requirements-sessions/{slug}/` (legacy folders remain readable for in-flight work).
* Six phase split: identity, intake, template-selection, drafting, review, handoff — see `.github/instructions/project-planning/requirements-*.instructions.md`.

## What to do

Invoke `requirements-builder` instead:

* Ad-hoc start: `@requirements-builder` and answer the framework multi-select with `requirements-brd`.
* Resuming legacy `brd-sessions/{slug}/` work: open `requirements-builder` and pass the slug; it reads the legacy directory in read-only mode and writes new artifacts under `requirements-sessions/{slug}/`.

## File-path contract preservation

Final output paths remain `docs/brds/<slug>-brd.md`. Any downstream consumers that read BRDs from that location continue to work unchanged.
