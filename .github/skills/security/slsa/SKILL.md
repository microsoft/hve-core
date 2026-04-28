---
name: slsa
description: SLSA v1.1 Build and Source track requirements knowledge base for assessing and remediating supply-chain build and source integrity controls - Brought to you by microsoft/hve-core.
license: Apache-2.0
user-invocable: false
metadata:
  authors: "SLSA Project"
  spec_version: "1.0"
  framework_revision: "1.1"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://slsa.dev/spec/v1.1/"
---

# SLSA — Skill Entry

This `SKILL.md` is the **entrypoint** for the SLSA framework skill.

The skill encodes the **SLSA v1.1 Build and Source tracks** as machine-readable per-control
items that the SSSC Planner lazy-loads per the canonical Framework Skill layout
(see `.copilot-tracking/research/2026-04-17/sssc-extensibility-research.md`,
Decision 5c-final).

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — phase-to-control mapping consumed by the SSSC Planner loader.
* `items/` — one YAML per SLSA level per track. Each file conforms to
  `scripts/linting/schemas/planner-framework-control.schema.json`.
  * `build-l0.yml`, `build-l1.yml`, `build-l2.yml`, `build-l3.yml` — Build track.
  * `source-l0.yml`, `source-l1.yml`, `source-l2.yml`, `source-l3.yml` — Source track.

## Loading contract

The planner MUST NOT read controls outside the set declared for the active phase in
`index.yml`. Each session emits `skills-loaded.log` for validator enforcement.

## Third-Party Attribution

SLSA Build and Source track requirements derived from the SLSA specification v1.1,
licensed under the Community Specification License 1.0.
Source: <https://slsa.dev/spec/v1.1/>
Modifications: Specification level requirements restructured into agent-consumable
per-control YAML items with phase gates and evidence hints.

---
