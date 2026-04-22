---
name: aria-apg
description: "W3C ARIA Authoring Practices Guide composite-widget patterns Framework Skill providing per-pattern keyboard models, focus-management strategies, role/state/property contracts, and WCAG 2.2 cross-walks as machine-readable per-pattern YAML for the Accessibility Planner agent — Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: ["@microsoft/hve-core"]
  spec_version: "1.0"
  framework_revision: "2024-12-12"
  last_updated: "2026-04-21"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: "https://www.w3.org/WAI/ARIA/apg/patterns/"
---

# ARIA Authoring Practices Guide Framework Skill

This Framework Skill packages the W3C ARIA Authoring Practices Guide (APG) composite-widget patterns as host-agent-neutral YAML for the Accessibility Planner and any other consuming agent that resolves patterns via `phaseMap`.

## Consumer Contract

Hosts enumerate this Framework Skill via `Get-FrameworkSkill -Domain accessibility` and resolve each `phaseMap[<phase>][]` entry to `items/<id>.yml`. Every per-pattern file declares `itemKind: pattern` and conforms to `scripts/linting/schemas/aria-pattern.schema.json`.

Identifiers use the lower-kebab APG URL slug form (for example `combobox-autocomplete-list`, `dialog-modal`, `treeview-file-directory`). The `referenceImplementationUrl` field links each item to its canonical APG pattern page.

## Skill Layout

* `index.yml` — Framework manifest. Declares `framework: aria-apg`, `version: "1.0.0"`, `itemKind: pattern`, the W3C Document License metadata block, and the host-facing `phaseMap` (six phases: `scoping`, `surface-assessment`, `standards-mapping`, `gap-analysis`, `backlog-generation`, `review-handoff`).
* `items/<id>.yml` — One file per APG pattern. Carries `id`, `title`, `summary`, `keyboardModel[]`, `focusManagement`, `relatedRoles[]`, `requiredStates[]`, `requiredProperties[]`, `relatedSuccessCriteria[]` (cross-walk to `wcag-2-2:<sc-id>`), `referenceImplementationUrl`, `applicability`, and `references`.

## Phase Mapping

The `phaseMap` block in `index.yml` declares which patterns each Accessibility Planner phase reads:

* `scoping` — All patterns; the planner uses this superset to enumerate the catalog.
* `surface-assessment` — Composite-widget patterns whose applicability commonly varies by surface (web vs hybrid-mobile vs native).
* `standards-mapping` — All patterns; each cross-walks to one or more WCAG 2.2 success criteria via `relatedSuccessCriteria`.
* `gap-analysis` — All patterns; each is evaluated against current implementation evidence.
* `backlog-generation` — All patterns; the planner emits work items per gap.
* `review-handoff` — All patterns flagged for human reviewer sign-off (typically those with `focusManagement: trap` or `roving`).

## Keyboard Model Taxonomy

The `keyboardModel[]` field uses a coarse-grained taxonomy of dominant interaction styles:

* `menu`, `menubar` — Menu-bar/menu-button activation with arrow-key traversal.
* `listbox` — Single- or multi-select list with arrow-key navigation and Enter/Space selection.
* `combobox` — Editable or selectable input combined with a popup.
* `grid`, `treegrid` — Two-dimensional cell navigation with arrow keys.
* `tabs` — Horizontal/vertical tab strip with arrow-key navigation between panels.
* `tree` — Hierarchical node navigation with expand/collapse semantics.
* `modal` — Focus-trapped overlay with Escape-to-dismiss.
* `slider`, `spinbutton` — Numeric value adjustment with arrow keys.
* `disclosure` — Toggle-to-expand/collapse a single region.
* `toolbar` — Roving-tabindex group of related controls.
* `inline` — Single-element widget with browser-default keyboard behavior.
* `carousel`, `feed` — Sequenced-content navigation with previous/next semantics.

## Focus Management Strategy

Each pattern declares one of four `focusManagement` strategies:

* `trap` — Focus is trapped within the widget; Escape returns focus to the invoking element (modal dialog, alertdialog).
* `roving` — Single tab stop into the widget; arrow keys move focus among descendants (menubar, toolbar, tabs).
* `single` — Widget is a single tab stop with no descendant focus management (button, switch, link).
* `none` — No special focus handling beyond browser defaults (disclosure, tooltip).

## Cross-Walk to WCAG 2.2

The `relatedSuccessCriteria[]` field cross-walks each pattern to sibling Framework Skill items, formatted as `wcag-2-2:<sc-id>` (for example `wcag-2-2:2-1-1`, `wcag-2-2:4-1-2`). Hosts MAY follow these references to the `wcag-2-2` Framework Skill for full success-criterion text.

## Applicability

Each pattern may declare `applicability` with `discriminator: surface`. The `appliesWhen` array lists surfaces where the pattern is in scope (`web`, `mobile-web`, `hybrid-mobile`); `naWhen` lists surfaces where the planner should mark the pattern N/A.

## Third-Party Attribution

ARIA APG pattern identifiers, names, and the paraphrased summaries in this Framework Skill are © W3C and used under the W3C Document License (2023): <https://www.w3.org/copyright/document-license-2023/>. The canonical source is <https://www.w3.org/WAI/ARIA/apg/patterns/>. Attribution is aggregated into the repository THIRD-PARTY-NOTICES at packaging time via the `metadata.attributionText` field declared in `index.yml`.

## Validation

Run repository-wide validation:

```bash
npm run validate:skills
npm run validate:fsi-content
npm run lint:yaml
```

The FSI content validator routes per-item files through `scripts/linting/schemas/aria-pattern.schema.json` (registered via the validator's `itemKind` schema map).
