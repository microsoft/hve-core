---
name: gsf-sci
description: Green Software Foundation Software Carbon Intensity (SCI) v1.0 specification as machine-readable Framework Skill items for the Sustainability Planner agent - Brought to you by microsoft/hve-core.
license: Apache-2.0
user-invocable: false
metadata:
  authors: "Green Software Foundation"
  spec_version: "1.0"
  framework_revision: "1.0"
  last_updated: "2026-04-21"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://sci.greensoftware.foundation/"
---

# GSF SCI — Skill Entry

This `SKILL.md` is the **entrypoint** for the Green Software Foundation Software
Carbon Intensity (SCI) Framework Skill. It is the **anchor bundle** for the
sustainability domain: every other sustainability Framework Skill cross-walks its
items to the four SCI variables encoded here.

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — phase-to-item mapping consumed by the Sustainability Planner loader.
* `items/` — one YAML per SCI control. Each file conforms to
  `scripts/linting/schemas/planner-framework-control.schema.json`.
  * `sci-formula.yml` — verbatim SCI formula `SCI = (E*I + M) / R`.
  * `sci-energy.yml` — variable `E` (energy consumed by a software system).
  * `sci-carbon-intensity.yml` — variable `I` (carbon intensity of the energy).
  * `sci-embodied.yml` — variable `M` (embodied emissions of the hardware).
  * `sci-functional-unit.yml` — variable `R` (functional unit declared by user).
  * `iso-21031-reference.yml` — ISO/IEC 21031:2024 reference-by-identifier only.
* `references/` — runtime-fetch dataset references (Electricity Maps, WattTime, Ember).

## Loading contract

The planner MUST NOT read items outside the set declared for the active phase in
`index.yml`. The `surfaceFilter: [cloud, web, ml, fleet]` declares that this
bundle applies to all four sustainability surfaces; downstream filtering by
workload mix is the planner's responsibility.

## Third-Party Attribution

Software Carbon Intensity (SCI) Specification v1.0 — Copyright Green Software
Foundation, licensed under the Community Specification License 1.0 (CSL-1.0).
Source: <https://sci.greensoftware.foundation/>
License: <https://github.com/CommunitySpecification/1.0/blob/main/1._Community_Specification_License-v1.md>
Modifications: Specification text restructured into agent-consumable per-control
YAML items with surface tagging, SCI variable mapping, and measurement-class metadata.

ISO/IEC 21031:2024 (SCI Specification) is referenced by identifier only; no
specification text is reproduced in this bundle.

---
