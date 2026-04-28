---
name: capability-inventory-content
description: "Content capability inventory Framework Skill enumerating prose linters readability metrics and human-review touchpoints used by the Accessibility Planner agent during cognitive-accessibility assessment - Brought to you by microsoft/hve-core."
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

# Content Capability Inventory Framework Skill

This Framework Skill packages the content-side capability inventory consumed by the Accessibility Planner agent. Each item describes a tool or human-review touchpoint that supports cognitive-accessibility outcomes, and each cross-walks to the cognitive-a11y controls it helps measure or enforce.

## Consumer Contract

Hosts enumerate this Framework Skill via `Get-FrameworkSkill -Domain accessibility` and resolve each `phaseMap[<phase>][]` entry to `items/<id>.yml`. Every per-item file declares `itemKind: capability` and validates against `scripts/linting/schemas/planner-framework-control.schema.json` (one mini-bundle per file with a single capability control).

Identifiers use the lower-kebab tool form (for example `vale`, `alex`, `markdownlint-prose-rules`).

## Skill Layout

* `index.yml` - Framework manifest. Declares `framework: capability-inventory-content`, `version: "1.0.0"`, `itemKind: capability`, the licensing block, and a YAML-anchor `phaseMap` shared across `assessment`, `gap-analysis`, and `backlog-generation` (mirrors `capability-inventory-hve-core`).
* `items/<id>.yml` - One file per capability. Each file is a mini planner-framework-control bundle with `id: capability-inventory-content`, `version`, `name`, `description`, `source`, and a single-element `controls` array that carries `id`, `title`, `description`, `group`, `assessmentMethod: categorical`, `categories: [absent, partial, present, verified]`, `risk`, two `gates` (`presence` at `assessment`, `verification` at `gap-analysis`), `mapsTo: cognitive-a11y`, `evidenceHints` (path globs), and `references`.

## Phase Mapping

All three Accessibility Planner phases that consult capability inventory data read the same id list via a YAML anchor:

* `assessment` - Initial inventory of which content tools are present in the project.
* `gap-analysis` - Comparison of present capabilities against cognitive-a11y controls.
* `backlog-generation` - Source for tooling adoption work items.

## Cross-Walk to cognitive-a11y

Each capability declares `mapsTo.cognitive-a11y[]` listing the cognitive-accessibility controls it supports. The Accessibility Planner uses this cross-walk to report which `cognitive-a11y` controls have at least one automation lever and which remain manual-only.

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
