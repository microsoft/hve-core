---
description: Phase 2 accessibility framework selection rules with explicit enable and atomic disabled-bundle requirements
---

# Accessibility Framework Selection

Phase 2 of the Accessibility Planner captures which accessibility frameworks apply to the assessment. Selection is always **explicit**: every default framework is either explicitly enabled or carries an atomic disabled bundle. There is no auto-include and no implicit fallback.

## Default Framework Inventory

The five default frameworks correspond to SKILL packages under `.github/skills/accessibility/`:

| Framework id  | Skill path                                  | Default state       | Conformance level field                   |
|---------------|---------------------------------------------|---------------------|-------------------------------------------|
| `wcag-22`     | `.github/skills/accessibility/wcag-22/`     | enabled at level AA | required (`A`, `AA`, `AAA`); default `AA` |
| `aria-apg`    | `.github/skills/accessibility/aria-apg/`    | optional            | not applicable (`null`)                   |
| `coga`        | `.github/skills/accessibility/coga/`        | optional            | not applicable (`null`)                   |
| `section-508` | `.github/skills/accessibility/section-508/` | enabled             | not applicable (`null`)                   |
| `en-301-549`  | `.github/skills/accessibility/en-301-549/`  | optional            | not applicable (`null`)                   |

The default enablement set (`wcag-22` at level `AA` plus `section-508`) is the regulated baseline aligned with EN 301 549, ADA Title II and III, and Section 508 enforcement. Users may add, remove, or re-level frameworks; the planner records every change as an explicit selection entry.

User-imported skills (custom frameworks delivered as additional SKILL packages under `.github/skills/accessibility/<id>/`) appear alongside the defaults during selection. Imported skill ids follow the same kebab-case pattern as the defaults and are matched against the schema `patternProperties` key `^[a-z0-9]+(-[a-z0-9]+)*$`.

## Host-Aware Multi-Select Pattern

This protocol applies the host-aware enumeration pattern recorded in user memory (`/memories/patterns.md`, section "Host-aware enumeration in planner agents"). The rule is to prefer a chat-native multi-select tool when the host supports it and to fall back to a single batched question otherwise. Never serialize the five framework decisions as five separate questions.

### Preferred path — multi-select tool

When the host exposes a multi-select capability (for example `vscode_askQuestions` with `multiSelect: true`):

* Render one option per framework, labelled with the framework id and a short human-readable summary
* Pre-check the default selection (`wcag-22` at level `AA` plus `section-508`)
* Capture the user's selection in a single turn
* For `wcag-22`, follow up immediately with a level prompt (`A`, `AA`, `AAA`) defaulting to `AA`
* Record the rationale for any framework moved away from its default in the same turn

### Fallback path — single batched question

When no multi-select tool is available:

* Emit one question listing every framework with id, summary, and default
* Instruct the user to reply with the ids to include and the ids to skip plus a short reason per skipped framework
* Default the WCAG level to `AA` unless the user specifies otherwise
* Accept partial answers and treat unaddressed frameworks as remaining defaults (the planner re-prompts for explicit confirmation on the next turn)

### Forbidden — serialised questions

Asking the user "do you want WCAG 2.2?" then "do you want ARIA APG?" then "do you want COGA?" and so on is forbidden. Serialised selection inflates turn count, blurs the relationship between framework decisions, and breaks the audit trail by spreading rationale across many turns.

## Per-Framework Selection Schema

Each entry under `frameworkSelections` in `state.json` conforms to the `frameworkSelectionEntry` definition in `scripts/linting/schemas/accessibility-state.schema.json`. Required and optional fields:

| Field             | Required              | Notes                                                               |
|-------------------|-----------------------|---------------------------------------------------------------------|
| `enabled`         | always                | `true` to include, `false` to exclude                               |
| `skillPath`       | when imported         | Relative path to the SKILL.md when the framework is a custom import |
| `version`         | recommended           | Framework version pinned for the assessment                         |
| `level`           | when applicable       | `A`, `AA`, or `AAA` for `wcag-22`; `null` otherwise                 |
| `disabled`        | required for excluded | `true` only on excluded frameworks                                  |
| `disabledReason`  | when `disabled=true`  | Non-empty rationale                                                 |
| `disabledAtPhase` | when `disabled=true`  | One of the six phase ids                                            |

### Atomic Disabled Bundle

The schema enforces an `allOf if/then` rule: when `disabled` is `true`, both `disabledReason` and `disabledAtPhase` are required and `disabledReason` must be non-empty. The planner therefore treats these three fields as a single atomic bundle. Three rules follow:

1. Setting `disabled: true` in the same write that adds `disabledReason` and `disabledAtPhase` — never one at a time
2. Re-enabling a framework removes all three fields together by replacing the entry with `{ "enabled": true, ... }`
3. Editing `disabledReason` or `disabledAtPhase` on an already-disabled framework rewrites the full atomic bundle

This atomic rule applies equally to default frameworks and to user-imported frameworks.

### WCAG Conformance Level Field

The `level` field is required on `wcag-22` and is preserved across session recovery and re-imports. Three rules govern the level field:

* On scaffold, `wcag-22` is created with `level: "AA"`
* On user change, the planner records the prior level in `planRiskAssessment.tradeoffs` with `decision: "accept"` and a rationale citing the user's intent
* On disable, the `level` field is retained (not nulled) so re-enabling restores the prior conformance target

## Selection Defaults at Scaffold

When the state file is first written in Phase 1 the planner initialises `frameworkSelections` with all five default keys present and `enabled: false`. The planner does **not** auto-enable the defaults at scaffold time; defaults are applied during Phase 2 once the user has been shown the selection prompt. This keeps the audit trail unambiguous: the state always reflects an explicit user-confirmed decision per framework.

When Phase 2 begins:

1. The planner pre-fills the multi-select with `wcag-22` (level `AA`) and `section-508` checked
2. The user confirms, modifies, or replaces the pre-fill
3. The planner writes `frameworkSelections` with the confirmed entries, atomic disabled bundles for excluded frameworks, and `level` set on `wcag-22`
4. The planner sets `gates.framework-selection.confirmed = true` with `confirmedAt` and `confirmedBy`

## Re-entry and Re-selection

When the user revisits Phase 2 after gate confirmation (for example, after discovering a new regulatory driver during Phase 4), the planner re-runs the multi-select prompt seeded with the existing selections. The atomic disabled bundle rule applies in both directions:

* Enabling a previously disabled framework removes `disabled`, `disabledReason`, and `disabledAtPhase` together
* Disabling a previously enabled framework requires capturing the new `disabledReason` and `disabledAtPhase` in the same write

A re-selection event resets `gates.framework-selection.confirmed` to `false` until the user confirms the new selection.

## Audit Trail Invariants

These invariants are checked on every Phase 2 write:

* Every default framework key exists in `frameworkSelections` after Phase 2 completes
* `wcag-22.level` is set to one of `A`, `AA`, `AAA` whenever `wcag-22.enabled = true`
* Every entry with `disabled: true` carries the full atomic bundle
* Imported framework ids match `^[a-z0-9]+(-[a-z0-9]+)*$` and reference an existing SKILL package at `skillPath`
* No framework appears in `controlMappings[*].frameworkId` unless its entry in `frameworkSelections` has `enabled: true`
