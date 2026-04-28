---
name: capability-inventory-web
description: "Web-surface capability inventory Framework Skill enumerating automated accessibility scanners static analyzers and assistive-tech manual review touchpoints used by the Accessibility Planner agent during web-surface assessment - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: ["@microsoft/hve-core"]
  spec_version: "1.0"
  framework_revision: "2026-04-21"
  last_updated: "2026-04-21"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: "https://github.com/microsoft/hve-core"
---

# Web Capability Inventory Framework Skill

This Framework Skill packages the web-surface capability inventory consumed by the Accessibility Planner agent. Each item describes a tool or assistive-tech manual review touchpoint that supports WCAG 2.2 outcomes, and each cross-walks to the success criteria it helps measure or enforce.

## Consumer Contract

Hosts enumerate this Framework Skill via `Get-FrameworkSkill -Domain accessibility` and resolve each `phaseMap[<phase>][]` entry to `items/<id>.yml`. Every per-item file declares `itemKind: capability` and validates against `scripts/linting/schemas/planner-framework-control.schema.json` (one mini-bundle per file with a single capability control).

Identifiers use the lower-kebab tool form (for example `axe-core-ci`, `lighthouse-a11y-ci`, `nvda-manual`).

## Skill Layout

* `index.yml` - Framework manifest. Declares `framework: capability-inventory-web`, `version: "1.0.0"`, `itemKind: capability`, the licensing block, and a `phaseMap` covering `scoping`, `surface-assessment`, `gap-analysis`, `backlog-generation`, and `review-handoff`.
* `items/<id>.yml` - One file per capability. Each file is a mini planner-framework-control bundle with `id: capability-inventory-web`, `version`, `name`, `description`, `source`, and a single-element `controls` array that carries `id`, `title`, `description`, `group`, `assessmentMethod: categorical`, `categories: [absent, partial, present, verified]`, `risk`, two `gates` (`presence` at `assessment`, `verification` at `gap-analysis`), `mapsTo: wcag-2-2`, `evidenceHints` (path globs), and `references`.

## Phase Mapping

The Accessibility Planner consults this inventory across multiple phases:

* `scoping` - Full enumeration of which web tools are candidate for the project.
* `surface-assessment` - Surface-targeted automated and component-test capabilities.
* `gap-analysis` - Comparison of present capabilities against WCAG 2.2 success criteria.
* `backlog-generation` - Source for tooling adoption work items.
* `review-handoff` - Includes manual screen-reader capabilities used to validate findings before sign-off.

## Cross-Walk to wcag-2-2

Each capability declares `mapsTo.wcag-2-2[]` listing the WCAG 2.2 success criterion ids it supports. The Accessibility Planner uses this cross-walk to report which `wcag-2-2` criteria have at least one automation lever and which remain manual-only.

## Evidence Hints

Each capability supplies `evidenceHints` as an array of path globs (configuration files or workflow paths) that signal the capability is configured. Hints are advisory; the planner treats them as starting points for evidence collection rather than strict requirements.

## Validation

Run repository-wide validation:

```bash
npm run validate:skills
npm run validate:fsi-content
npm run lint:yaml
```

The FSI content validator routes per-item files through `scripts/linting/schemas/planner-framework-control.schema.json` (registered via the validator's `itemKind` schema map for `capability`).
