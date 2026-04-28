---
description: "Phase 3 standards mapping contract — discovers framework skills under .github/skills/responsible-ai/ and reads only the items scoped to the active phase."
applyTo: '**/.copilot-tracking/rai-plans/**'
---

# RAI Phase 3 — Standards Mapping (Framework-Consumer Contract)

This file is a **consumer contract**. It does not encode any framework data inline. The planner discovers NIST AI RMF (default) and any additional standards (such as the EU AI Act prohibited-practices framework) by reading the framework skills under `.github/skills/responsible-ai/`. Adding or replacing a framework requires no edits to this file.

## Framework Discovery Protocol

Each framework is published as a self-contained skill directory containing:

* `SKILL.md` — entrypoint metadata (consumer contract description, license, attribution).
* `index.yml` — `framework`, `version`, and `phaseMap` fields. `phaseMap.<phase>` lists the item identifiers participating in that planner phase.
* `items/<id>.yml` — one file per characteristic, principle, threat, control, tradeoff, indicator, or output template, validated against the matching schema in [`scripts/linting/schemas/`](../../../scripts/linting/schemas/).

The planner discovers frameworks by enumerating `.github/skills/responsible-ai/<framework-id>/` directories. Discovery filters to entries whose `phaseMap.phase-3-standards-mapping` is non-empty and registers each as a `frameworks[]` entry in `state.json`. Externally authored Framework Skills declared on a `frameworkRef` via `additionalRoot` are also enumerated.

### Draft Quarantine

Framework Skills whose `index.yml` declares `status: draft` are excluded from discovery by default. They are registered only when the corresponding `frameworkRef` opts in via `includeDrafts: true`. All other `status` values (`published`, omitted) are registered normally. Discovery logs skipped drafts to `skills-loaded.log` with a `skipped: draft` annotation.

### Disabled Framework Skip

Frameworks where `state.frameworks[<id>].disabled === true` are skipped entirely in this phase. The planner does not read `index.yml`, does not load any item files, and does not register characteristics for the framework. Each skip is logged to `skills-loaded.log` with `{skipped: "disabled", reason: <state.disabledReason>, atPhase: <state.disabledAtPhase>}` so the Phase 6 handoff appendix can render an audit trail. Disabled frameworks remain in `state.frameworks[]` so the audit trail survives compaction.

## Hard Loading Contract

The planner reads framework data lazily and append-only:

1. Read `index.yml` for every registered framework whose `disabled` field is not `true`.
2. For the active phase (`phase-3-standards-mapping`), resolve `phaseMap.phase-3-standards-mapping` to the matching `items/<id>.yml` files.
3. Read **only** those item files; never enumerate or read items outside the active phase scope.
4. Append one entry per `read_file` of any skill artifact to `skillsLoaded[]` in `state.json` (see [`rai-identity.instructions.md`](rai-identity.instructions.md) for the entry schema).

Reading items scoped to a different phase is a contract violation.

## Per-Item Field Usage

For each `items/<id>.yml` loaded during this phase:

* `id`, `title`, `function`, `category` — populate the standards mapping table row.
* `description` — populate the explanatory text for the characteristic or principle.
* `assessmentMethod` ∈ `{binary, categorical, continuous}` — drives evidence collection prompts when the item participates in risk classification.
* `mapsTo[]` — cross-framework links surfaced in the mapping output (for example, NIST AI RMF subcategory ↔ EU AI Act article).
* `evidenceHints[]` — deterministic file globs the planner inspects to suggest current posture.
* `relatedThreats[]`, `relatedControls[]` — link characteristics to threat-catalog and control-surface items consumed in Phases 4 and 5.

The planner does **not** invent characteristic semantics, function/category groupings, or subcategory codes. All such data originates from the per-item YAML.

## Registering a New Framework

To add a framework (for example, ISO/IEC 42001 or a domain-specific RAI standard):

1. Create `.github/skills/responsible-ai/<framework-id>/` containing `SKILL.md`, `index.yml`, and `items/<id>.yml` files.
2. Validate with `npm run validate:skills` and `npm run validate:fsi-content`.
3. Reference the new skill in `collections/project-planning.collection.yml` if it is to ship with the project-planning collection.

No edits to this instruction file or to `rai-identity.instructions.md` are required. The planner picks up the new framework on next session start.

## Replacing the Default Framework Set

A user may declare `replaceDefaultFramework: true` on `state.riskClassification.framework` (or on a `frameworkRef` registered through Phase 1 scoping). When set, the planner ignores the default `nist-ai-rmf` framework discovered by enumeration and uses only the user-declared frameworks for this assessment.

The Prohibited Uses Gate framework (`eu-ai-act-prohibited-practices` by default) is opt-in via Phase 1 scoping. It is not loaded unless the user requests it or the AI system targets the EU market.

## Verdict Ladder

Standards mapping rows surface the verdict assigned during evidence collection. The legend below mirrors the per-item `assessmentMethod` results. Evidence row formatting for every cited file and line defers to the canonical rule in #file:../shared/evidence-citation.instructions.md.

* **verified** — Positive evidence the characteristic is addressed. Cite the specific artifact and line.
* **present** — Artifact exists but full conformance is not yet confirmed; cite the artifact.
* **partial** — Positive evidence of partial coverage. Cite both what is present and the specific gap.
* **unknown** — Evidence Exhaustion Rule incomplete. Not a final verdict; must be resolved before this phase closes.
* **absent** — Positive evidence the characteristic is not addressed.
* **n/a** — Characteristic does not apply. Cite reason.

### Phase 3 Exit Gate

Phase 3 cannot close while any characteristic row carries a `verdict` of `unknown`. Resolve every `unknown` to one of the other ladder values (or capture a user follow-up answer that does so) before advancing `state.currentPhase` past `3`.

## Researcher Subagent Delegation

For runtime documentation lookups not encoded as framework items (for example, NIST AI 600-1 Generative AI Profile addenda, sector-specific regulatory updates, ISO/IEC 23894 risk management guidance), delegate to the Researcher Subagent. Do not attempt to encode net-new external standards inline; either delegate the lookup or publish a new framework skill per the registration protocol above.

## Output

Write `standards-mapping.md` to `.copilot-tracking/rai-plans/{project-slug}/standards-mapping.md`. Group rows by framework, then by `function` and `category`. Cite the source skill path and item id for every row.

Update `state.json`:

* Append the loaded framework records to `frameworks[]`.
* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Set `currentPhase` to `4` and `standardsMapped` to `true` once mapping is complete.

## Third-Party Attribution

Attribution lives in each framework skill's `SKILL.md` `metadata` block (`license`, `licenseUrl`, `attributionText`, `content_based_on`). Do not duplicate attribution text in the mapping output; cite the skill path and let the consumer follow the link. Per-framework attribution requirements (for example, NIST's U.S.-Government work-product notice or the EU AI Act paraphrase-only constraint) are honored by the framework skill's metadata.
