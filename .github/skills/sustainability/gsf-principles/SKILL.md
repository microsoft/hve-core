---
name: gsf-principles
description: Green Software Foundation Principles of Green Software (8 principles) for the Sustainability Planner agent
license: CC-BY-4.0
content_based_on: https://learn.greensoftware.foundation/
---

# GSF Principles Framework Skill (gsf-principles/v1)

Framework Skill bundle delivering the eight Principles of Green Software as discrete `principle` items consumable by the Sustainability Planner.

## Skill layout

* `index.yml` — manifest declaring framework `gsf-principles`, version `1.0`, license `CC-BY-4.0`, `surfaceFilter: [cloud, web, ml, fleet]`.
* `items/*.yml` — eight per-principle items; each `itemKind: principle`.
* `references/cat-manifesto.yml` — link-only stub for the Climate Action Tech manifesto (no text; pending CAT licensing outreach per WI-03).

## Loading contract

Loaded by the Sustainability Planner during Phase 3 (Standards Mapping). Every Phase 3+ instruction references principles by `gsf-principles:{id}` (e.g., `gsf-principles:carbon-efficiency`).

## Third-Party Attribution

Content derived from the Green Software Foundation under CC-BY-4.0. Attribution required and recorded in this bundle's `index.yml` (`metadata.attributionText`).
