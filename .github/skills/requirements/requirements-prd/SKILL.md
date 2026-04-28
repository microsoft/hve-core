---
name: requirements-prd
description: "Product Requirements Document Framework Skill providing a phased document-section roster, depth-tiered applicability, and a single shared PRD template at docs/templates/prd-template.md - Brought to you by microsoft/hve-core."
license: MIT
user-invocable: false
metadata:
  authors: "HVE Core contributors"
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-04-22"
---

# Requirements PRD — Skill Entry

This `SKILL.md` is the entrypoint for the `requirements-prd` Framework Skill consumed by the [Requirements Builder](../../../agents/project-planning/requirements-builder.agent.md) agent.

The skill encodes a Product Requirements Document as `document-section` items that all reference a single shared template at [`docs/templates/prd-template.md`](../../../../docs/templates/prd-template.md). The host agent collects values for the manifest `globals`, then renders the template once per drafting pass while honoring `selectWhen.depth_tier` and `applicability.audience` gates.

## Consumer contract

1. Read [`index.yml`](index.yml) to discover globals, the six-phase `phaseMap`, and the section roster.
2. For each section id under `phaseMap.<phase>`, resolve the per-item file under [`items/`](items/).
3. Validate each item file against [`scripts/linting/schemas/document-section.schema.json`](../../../../scripts/linting/schemas/document-section.schema.json).
4. Filter items by `selectWhen` (depth_tier) and `applicability` (audience) using the active session profile.
5. Collect values for manifest `globals`; each item carries no inline template — render via the shared `templatePath`.

## Output contract

* Output path: `docs/prds/<slug>.md` (set on the requirements-builder session state).
* Format: markdown.
* Wrapper: include `<!-- markdownlint-disable-file -->` and the generation HTML comment with sha256 line per `requirements-drafting.instructions.md`.

## Phases

The `phaseMap` mirrors the requirements-builder six-phase pipeline:

* `identity` — disclaimer + framework selection (no document items).
* `intake` — vision, personas, problem-statement, success-metrics.
* `template-selection` — applicability gates (no document items).
* `drafting` — goals-non-goals, scope, out-of-scope, user-stories, requirements-functional, requirements-non-functional, dependencies, risks-mitigations, assumptions, instrumentation.
* `review` — open-questions, release-criteria.
* `handoff` — appendix.

## Depth tiers

* `light` — vision, personas, problem-statement, scope, requirements-functional.
* `standard` — light + goals-non-goals, success-metrics, out-of-scope, user-stories, requirements-non-functional, dependencies, risks-mitigations, assumptions, open-questions, release-criteria.
* `deep` — standard + instrumentation, appendix.
