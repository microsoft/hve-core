---
name: capability-inventory-web
description: "Web-surface accessibility tooling capability inventory (axe-core runners, screen readers, contrast checkers, HTML validators) for the Accessibility Planner agent — per-capability YAML items consumed during scoping, surface-assessment, standards-mapping, gap-analysis, and backlog-generation phases — Brought to you by microsoft/hve-core."
license: MIT
user-invocable: false
metadata:
  authors: ["@microsoft/hve-core"]
  spec_version: "1.0"
  framework_revision: "1.0.0"
  last_updated: "2026-04-21"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: ".copilot-tracking/research/2026-04-21/accessibility-planner-research.md"
---

# Web Capability Inventory — Skill Entry

This `SKILL.md` is the entrypoint for the `capability-inventory-web` Framework Skill.

The skill encodes the web-surface portion of the Accessibility Planner's capability inventory as machine-readable per-capability YAML items consumed by the planner during the `scoping`, `surface-assessment`, `standards-mapping`, `gap-analysis`, and `backlog-generation` phases.

## Capability Source

Capability rows are derived from `.copilot-tracking/research/2026-04-21/accessibility-planner-research.md` and cross-walk to W3C WCAG 2.2 success criteria packaged in the sibling `wcag-2-2` Framework Skill. Each capability becomes one `items/<capability-id>.yml` file that validates against `scripts/linting/schemas/planner-framework-control.schema.json`.

## Controls

Each capability uses a categorical assessment with the ladder `absent → partial → present → verified` and declares two phase gates (`presence` for surface-assessment, `verification` for gap-analysis). The `mapsTo.wcag-2-2[]` array cross-walks each capability to the success criteria it can detect, partially cover, or assist with manual verification.

| Group     | Count |
|-----------|------:|
| automated |    11 |
| manual    |     5 |
| hybrid    |     1 |
| total     |    17 |

## Phase Mapping

`index.yml` maps each capability to the Accessibility Planner phases that consume it. The planner loads only the capabilities listed for the active phase. Manual-only capabilities are excluded from `gap-analysis` because that phase compares automated detection signals against the project's adopted controls.

## Skill Layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — capability roll-up with `framework`, `version`, `itemKind: capability`, and `phaseMap`.
* `items/` — per-capability files (one YAML per capability).
