---
name: requirements-brd
description: "Business Requirements Document Framework Skill providing a phased document-section roster with BR-ID traceability discipline and a single shared BRD template at docs/templates/brd-template.md - Brought to you by microsoft/hve-core."
license: MIT
user-invocable: false
metadata:
  authors: "HVE Core contributors"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-04-22"
---

# Requirements BRD — Skill Entry

This `SKILL.md` is the entrypoint for the `requirements-brd` Framework Skill consumed by the [Requirements Builder](../../../agents/project-planning/requirements-builder.agent.md) agent.

The skill encodes a Business Requirements Document as `document-section` items that all reference a single shared template at [`docs/templates/brd-template.md`](../../../../docs/templates/brd-template.md). Item ids are prefixed `br-` to preserve BR-ID traceability discipline inherited from the deprecated `brd-builder` agent.

## Consumer contract

1. Read [`index.yml`](index.yml) to discover globals, the six-phase `phaseMap`, and the section roster.
2. For each section id under `phaseMap.<phase>`, resolve the per-item file under [`items/`](items/).
3. Validate each item file against [`scripts/linting/schemas/document-section.schema.json`](../../../../scripts/linting/schemas/document-section.schema.json).
4. Filter items by `selectWhen` (depth_tier) and `applicability` (audience) using the active session profile.
5. Collect values for manifest `globals`; each item carries no inline template — render via the shared `templatePath`.

## Output contract

* Output path: `docs/brds/<slug>-brd.md` (set on the requirements-builder session state).
* Format: markdown.
* Wrapper: include `<!-- markdownlint-disable-file -->` and the generation HTML comment with sha256 line per `requirements-drafting.instructions.md`.

## BR-ID traceability

Item `br-business-requirements` carries a `required: true` input that elicits the BR-ID linkage scheme (e.g. `BR-001` → objective → KPI). Every other requirements/objectives item references this scheme so downstream agents (`ado-prd-to-wit`, `jira-prd-to-wit`, `rai-planner`) can trace back to the originating BR-ID.

## Phases

The `phaseMap` mirrors the requirements-builder six-phase pipeline:

* `identity` — disclaimer + framework selection (no document items).
* `intake` — br-business-context, br-stakeholders, br-problem-statement, br-objectives.
* `template-selection` — applicability gates (no document items).
* `drafting` — br-scope, br-business-processes, br-business-requirements, br-data-reporting, br-assumptions-dependencies, br-implementation, br-benefits.
* `review` — br-risks-issues, br-open-questions.
* `handoff` — br-references-appendices.

## Depth tiers

* `standard` — br-business-context, br-problem-statement, br-objectives, br-stakeholders, br-scope, br-business-requirements, br-assumptions-dependencies, br-risks-issues, br-open-questions.
* `deep` — standard + br-business-processes, br-data-reporting, br-implementation, br-benefits, br-references-appendices.
