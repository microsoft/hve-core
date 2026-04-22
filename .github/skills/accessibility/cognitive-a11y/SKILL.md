---
name: cognitive-a11y
description: "Cognitive accessibility Framework Skill packaging W3C COGA, plain-language, and cognitive-load heuristics as machine-readable per-control YAML for the Accessibility Planner agent - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: ["@microsoft/hve-core"]
  spec_version: "1.0"
  framework_revision: "2026-04-21"
  last_updated: "2026-04-21"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: "https://www.w3.org/WAI/cognitive/"
---

# Cognitive Accessibility Framework Skill

This Framework Skill packages cognitive-accessibility practices for the Accessibility Planner agent and any other consuming agent that resolves controls via `phaseMap`.

The bundle synthesizes guidance from:

* W3C Cognitive and Learning Disabilities Accessibility (COGA) Task Force materials.
* Plain-language style guidance from plainlanguage.gov (PLAIN) and the Plain Writing Act of 2010.
* Cognitive-load and decision-fatigue heuristics paraphrased from Nielsen Norman Group articles.

All long-form text is paraphrased; no verbatim third-party text appears in this bundle.

## Consumer Contract

Hosts enumerate this Framework Skill via `Get-FrameworkSkill -Domain accessibility` and resolve each `phaseMap[<phase>][]` entry to `items/<id>.yml`. Every per-item file declares `itemKind: control` and conforms to `scripts/linting/schemas/planner-framework-control.schema.json` (one mini-bundle per file with a single control).

Identifiers use the lower-kebab `coga-<topic>` form.

## Skill Layout

* `index.yml` - Framework manifest. Declares `framework: cognitive-a11y`, `version: "1.0.0"`, `itemKind: control`, the licensing block, and the `phaseMap` (six phases: `scoping`, `surface-assessment`, `standards-mapping`, `gap-analysis`, `backlog-generation`, `review-handoff`).
* `items/<id>.yml` - One file per cognitive-accessibility control. Each file is a mini planner-framework-control bundle with `id: cognitive-a11y`, `version`, `name`, `description`, `source`, and a single-element `controls` array carrying `id`, `title`, `description`, `group`, `assessmentMethod: categorical`, `categories: [absent, partial, present, verified]`, `risk`, `gates`, optional `mapsTo: capability-inventory-content`, `applicability`, and `references`.

## Phase Mapping

The `phaseMap` block in `index.yml` declares which controls each Accessibility Planner phase reads:

* `scoping` - All 42 controls; the planner uses this superset to enumerate the catalog.
* `surface-assessment` - Controls whose applicability commonly varies by surface (structure, iconography, visual design, redundant encoding, personalization).
* `standards-mapping` - Language, structure, error-recovery, and redundant-encoding controls that align with WCAG 2.2 cognitive-adjacent criteria.
* `gap-analysis` - Controls that have at least one capability-inventory automation entry, so the planner can compare adoption against tooling output.
* `backlog-generation` - Controls most often translated into engineering work items.
* `review-handoff` - Controls most likely to require human reviewer sign-off for evidence acceptance.

## Verification Model

Each control uses `assessmentMethod: categorical` with the ladder `absent -> partial -> present -> verified` and declares two phase gates:

* `presence` (phase `scoping`) - Project commits to applying the practice.
* `verification` (phase `review-handoff`) - Application is verified through review or tooling.

Controls that can be automated reference the corresponding `capability-inventory-content` controls via `mapsTo.capability-inventory-content[]`. Controls without entries are manual-only and require reviewer sign-off.

## Applicability

Each control declares `applicability` with `discriminator: surface`. The `appliesWhen` array lists surfaces (`web`, `mobile-web`, `hybrid-mobile`, `native`, `desktop`, `content`) where the control is in scope; `naWhen` lists `voice-only` surfaces where written-language conventions do not apply, with a `naReason` explaining the substitution.

## Third-Party Attribution

Cognitive-accessibility guidance in this Framework Skill paraphrases material from W3C COGA (used under the W3C Document License (2023): <https://www.w3.org/copyright/document-license-2023/>), plainlanguage.gov (US public domain), the Plain Language Action and Information Network (PLAIN) guidelines, and Nielsen Norman Group articles (cited as nominative references; no verbatim text). Attribution is aggregated into the repository THIRD-PARTY-NOTICES at packaging time via the `metadata.attributionText` field declared in `index.yml`.

## Validation

Run repository-wide validation:

```bash
npm run validate:skills
npm run validate:fsi-content
npm run lint:yaml
```

The FSI content validator routes per-item files through `scripts/linting/schemas/planner-framework-control.schema.json` (registered via the validator's `itemKind` schema map for `control`).
