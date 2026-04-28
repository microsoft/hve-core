---
name: wcag-2-2
description: "W3C Web Content Accessibility Guidelines 2.2 Framework Skill providing all 87 success criteria across conformance levels A, AA, and AAA as machine-readable per-criterion YAML for the Accessibility Planner agent — Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: ["@microsoft/hve-core"]
  spec_version: "2.2"
  framework_revision: "2023-10-05"
  last_updated: "2026-04-21"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: "https://www.w3.org/TR/WCAG22/"
---

# WCAG 2.2 Framework Skill

This Framework Skill packages the W3C Web Content Accessibility Guidelines (WCAG) 2.2 Recommendation as host-agent-neutral YAML for the Accessibility Planner and any other consuming agent that resolves criteria via `phaseMap`.

## Consumer Contract

Hosts enumerate this Framework Skill via `Get-FrameworkSkill -Domain accessibility` and resolve each `phaseMap[<phase>][]` entry to `items/<id>.yml`. Every per-criterion file declares `itemKind: criterion` and conforms to `scripts/linting/schemas/accessibility-criterion.schema.json`.

Identifiers use the lower-kebab dotted form `<principle>-<guideline>-<criterion>` (for example `1-1-1` for "Non-text Content"). The mapping back to the canonical W3C dotted form (`1.1.1`) is documented in each item's `references[]`.

## Skill Layout

* `index.yml` — Framework manifest. Declares `framework: wcag-2-2`, `version: "2.2.0"`, `itemKind: criterion`, the W3C Document License metadata block, and the host-facing `phaseMap` (six phases: `scoping`, `surface-assessment`, `standards-mapping`, `gap-analysis`, `backlog-generation`, `review-handoff`).
* `items/<id>.yml` — One file per success criterion. Carries `id`, `title`, `level`, `principle`, `guideline`, `addedIn`, `summary`, `verificationMode`, `automatableBy`, `applicability`, `techniques`, `relatedAriaPatterns`, and `references`.

## Phase Mapping

The `phaseMap` block in `index.yml` declares which criteria each Accessibility Planner phase reads:

* `scoping` — All 87 criteria; the planner uses this superset to enumerate the catalog.
* `surface-assessment` — Criteria whose applicability commonly varies by surface (web, hybrid-mobile, native, content, authoring tool).
* `standards-mapping` — Levels A and AA (the legally-cited conformance baseline in most jurisdictions).
* `gap-analysis` — Criteria with broad automated-detection support that gate most product backlogs.
* `backlog-generation` — Criteria most often translated into engineering work items.
* `review-handoff` — Criteria most likely to require human reviewer sign-off for evidence acceptance.

## Conformance Levels

The `globals.conformanceLevels` array (`[A, AA, AAA]`) lets host agents render filterable views. Each per-criterion item declares its own `level`.

## Verification Modes

Each criterion declares `verificationMode`:

* `automated` — Detectable by tooling alone (rare).
* `hybrid` — Detectable by tooling but requires human confirmation for false positives or context.
* `manual` — Requires human evaluation; tooling cannot reliably decide.

## Applicability

Each criterion may declare `applicability` with `discriminator: surface`. The `appliesWhen` array lists surfaces (such as `web`, `hybrid-mobile`, `native`, `content`, `authoring-tool`) where the criterion is in scope; `naWhen` lists surfaces where the planner should mark the criterion N/A with `naReason`.

## Third-Party Attribution

WCAG 2.2 success-criterion identifiers, titles, and the paraphrased summaries in this Framework Skill are © W3C and used under the W3C Document License (2023): <https://www.w3.org/copyright/document-license-2023/>. The canonical source is <https://www.w3.org/TR/WCAG22/>. Attribution is aggregated into the repository THIRD-PARTY-NOTICES at packaging time via the `metadata.attributionText` field declared in `index.yml`.

## Validation

Run repository-wide validation:

```bash
npm run validate:skills
npm run validate:fsi-content
npm run lint:yaml
```

The FSI content validator routes per-item files through `scripts/linting/schemas/accessibility-criterion.schema.json` (registered via the validator's `itemKind` schema map).
