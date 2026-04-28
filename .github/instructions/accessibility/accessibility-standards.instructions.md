---
description: "Phase 3 standards mapping contract — discovers framework skills under .github/skills/accessibility/ and reads only the controls scoped to the active phase."
applyTo: '**/.copilot-tracking/accessibility-plans/**'
---

# Accessibility Phase 3 — Standards Mapping (Framework-Consumer Contract)

This file is a **consumer contract**. It does not encode any framework data inline. The Accessibility Planner discovers WCAG 2.2, ARIA Authoring Practices, and Cognitive Accessibility controls by reading the framework skills under `.github/skills/accessibility/`. Adding or replacing a framework requires no edits to this file.

The Wave 1 framework skills enumerated by default are:

* `wcag-2-2` — W3C Web Content Accessibility Guidelines 2.2 success criteria across conformance levels A, AA, and AAA (`itemKind: criterion`).
* `aria-apg` — W3C ARIA Authoring Practices Guide composite-widget patterns with keyboard models and focus-management strategies (`itemKind: pattern`).
* `cognitive-a11y` — W3C COGA, plain-language, and cognitive-load controls for the cognitive accessibility overlay (`itemKind: control`).

Capability inventory skills under `.github/skills/accessibility/capability-inventory-*` are **not** standards frameworks and are excluded from discovery in this phase; they are consumed by the surface-assessment phase (see [`accessibility-surface-assessment.instructions.md`](accessibility-surface-assessment.instructions.md)).

## Framework Discovery Protocol

Each framework is published as a self-contained skill directory containing:

* `SKILL.md` — entrypoint metadata (consumer contract description, license, attribution).
* `index.yml` — `framework`, `version`, `itemKind`, and `phaseMap` fields. `phaseMap.<phase>` lists the control identifiers participating in that planner phase. (`itemKind` may be `criterion`, `pattern`, or `control`; the loading contract treats them uniformly as "controls" below.)
* `items/<id>.yml` — one file per control, validated against [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../scripts/linting/schemas/planner-framework-control.schema.json).

The planner discovers frameworks by invoking `Get-FrameworkSkill -Domain accessibility` (from `scripts/lib/Modules/FrameworkSkillDiscovery.psm1`), passing any `state.frameworks[].additionalRoot` values via `-AdditionalRoots` so externally authored Framework Skills are registered. Discovery filters to entries whose `phaseMap.standards-mapping` is non-empty and registers each as a `frameworkRef` in `state.json` (see [`scripts/linting/schemas/accessibility-state.schema.json`](../../../scripts/linting/schemas/accessibility-state.schema.json) `$defs.frameworkRef`). Capability-inventory skills are filtered out by `Get-FrameworkSkill` based on their domain metadata and never appear as standards `frameworkRef` entries.

### Draft Quarantine

Framework Skills whose `index.yml` declares `status: draft` are excluded from discovery by default. They are registered only when the corresponding `frameworkRef` opts in via `includeDrafts: true` (typically a user-imported Framework Skill still under authoring). All other `status` values (`published`, omitted) are registered normally. Discovery must log skipped drafts to `skills-loaded.log` with a `skipped: draft` annotation so the consumer can audit exclusions.

### Disabled Framework Skip

Frameworks where `state.frameworks[<id>].disabled === true` are skipped entirely in this phase. The planner does not read `index.yml`, does not load any control files, and does not register gates for the framework. Each skip is logged to `skills-loaded.log` with `{skipped: "disabled", reason: <state.disabledReason>, atPhase: <state.disabledAtPhase>}` so the Phase 6 handoff appendix can render an audit trail. Disabled frameworks remain in `state.frameworks[]` so the audit trail survives compaction.

## Hard Loading Contract

The planner reads framework data lazily and append-only:

1. Read `index.yml` for every registered framework whose `disabled` field is not `true`.
2. For the active phase (`standards-mapping`), resolve `phaseMap.standards-mapping` to the matching `items/<id>.yml` files, **excluding** any control id present in `state.frameworks[<id>].suppressedControls[].id`.
3. Apply the active risk tier filter from [#file:./accessibility-risk-classification.instructions.md](./accessibility-risk-classification.instructions.md): the tier selects which framework subsets load (for example, lower tiers may load only the `wcag-2-2` Level A subset; higher tiers load Level AA, AAA, ARIA APG, and the full cognitive overlay). Controls whose `riskTier` exceeds the active tier are skipped.
4. Apply the active capability inventory filter from [#file:./accessibility-surface-assessment.instructions.md](./accessibility-surface-assessment.instructions.md): the capability inventory determines which controls apply to the surfaces in scope (for example, a content-only surface skips ARIA APG composite-widget patterns). Controls whose `appliesToSurfaces[]` does not intersect `state.surfaces[]` are skipped.
5. Read **only** those control files; never enumerate or read controls outside the active phase scope, the active risk tier, or the active surface set.
6. Append one entry per `read_file` of any skill artifact to `skills-loaded.log` (see Identity instructions for the entry schema and enforcement). For each suppressed, tier-filtered, or surface-filtered control, emit a `{skipped: "suppressed" | "tier-filtered" | "surface-filtered", controlId, reason, atPhase}` entry instead of a `read_file` entry so exclusions are visible to the validator and the handoff appendix.

Reading controls scoped to a different phase, a higher risk tier, or a non-applicable surface is a contract violation and is rejected by `Validate-PlannerArtifacts.ps1`.

## Per-Control Field Usage

For each `items/<id>.yml` loaded during this phase:

* `id`, `title`, `riskTier` — populate the standards mapping table row.
* `assessmentMethod` ∈ `{binary, categorical, continuous}` — drives evidence collection prompts.
* `categories` (categorical) or `range` (continuous) — define allowable values.
* `gates[]` — recorded with `status: pending` until evidence is collected (per [`accessibility-risk-classification.instructions.md`](accessibility-risk-classification.instructions.md) gate model).
* `evidenceHints[]` — deterministic file globs the planner inspects to suggest current posture.
* `mapsTo[]` — cross-framework links surfaced in the mapping output (for example, an ARIA APG pattern mapping to one or more WCAG 2.2 success criteria).
* `appliesToSurfaces[]` — surface tokens (`web`, `content`, `mobile`, `desktop`) consumed by the capability inventory filter.

The planner does **not** invent gate semantics, risk tiers, or check identifiers. All such data originates from the per-control YAML.

## Registering a New Framework

To add a framework (for example, Section 508, EN 301 549, EAA, or an internal vendor accessibility spec):

1. Create `.github/skills/accessibility/<framework-id>/` containing `SKILL.md`, `index.yml`, and `items/<id>.yml` files.
2. Validate with `npm run validate:skills`.
3. Validate each control against the planner-framework-control schema.
4. Reference the new skill in `collections/accessibility.collection.yml` if it is to ship with the accessibility collection.

No edits to this instruction file or to `accessibility-identity.instructions.md` are required. The planner picks up the new framework on next session start.

## Replacing the Default Framework Set

A user may declare `replaceDefaults: true` on a `frameworkRef` registered through Phase 1 scoping. When set, the planner ignores the default framework set discovered by enumeration and uses only the user-declared frameworks for this assessment.

## Verdict Ladder

Standards mapping rows surface the verdict assigned during surface assessment. The legend below mirrors [`accessibility-surface-assessment.instructions.md`](accessibility-surface-assessment.instructions.md#verdict-ladder); see that file for the Evidence Exhaustion Rule that governs verdict assignment. Evidence row formatting for every cited file and line defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.

* **verified** — Positive evidence of full coverage. Cite the specific file and line.
* **present** — Artifact exists but full conformance is not yet confirmed; cite the artifact.
* **partial** — Positive evidence of partial coverage. Cite both what is present and the specific gap.
* **unknown** — Evidence Exhaustion Rule incomplete. Not a final verdict; must be resolved before this phase closes.
* **absent** — Positive evidence the control is not implemented (Evidence Exhaustion Rule completed).
* **n/a** — Control does not apply. Cite reason (alternative satisfied, applicability discriminator, surface-not-in-scope, etc.).

When a framework skill declares `equivalentImplementations` for a control, presence of any listed equivalent scores as `verified`.

### Phase 3 Exit Gate

Phase 3 cannot close while any control row carries a `verdict` of `unknown`. Resolve every `unknown` to one of the other ladder values (or capture a user follow-up answer that does so) before advancing `state.phase` past `standards-mapping`. `Validate-PlannerArtifacts.ps1` enforces this gate.

## Question Cadence

Batch evidence-collection questions **per framework**, not per control. After loading the in-scope control set for one framework, ask a single batched question covering every control in that framework that needs user evidence (using `vscode_askQuestions` with `multiSelect: true` when the host supports it; otherwise a single fallback question listing every control with safe defaults). Move to the next framework only after the previous framework's batch is resolved. Never serialize as one question per control.

## Researcher Subagent Delegation

For runtime documentation lookups not encoded as framework controls (for example, jurisdiction-specific obligations under Section 508, EN 301 549, the European Accessibility Act, or a vendor's published VPAT), delegate to the Researcher Subagent. Do not attempt to encode net-new external standards inline; either delegate the lookup or publish a new framework skill per the registration protocol above.

## Output

Write `standards-mapping.md` to `.copilot-tracking/accessibility-plans/{project-slug}/standards-mapping.md`. Group rows by framework, then by `riskTier` descending. Cite the source skill path and control id for every row.

Update `state.json`:

* Append the loaded framework records to `frameworks[]`.
* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Append one entry per mapped control to `standardsMapping[]`, where each entry is `{frameworkId, controlId, applicabilityRationale, status, evidence}`.
* Set `phase` to `gap-analysis` once mapping is complete.

## Third-Party Attribution

Attribution lives in each framework skill's `SKILL.md` `metadata` block (`authors`, `content_based_on`). Do not duplicate attribution text in the mapping output; cite the skill path and let the consumer follow the link.
