---
description: "Phase 3 standards mapping contract — discovers framework skills under .github/skills/security/ and reads only the controls scoped to the active phase."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 3 — Standards Mapping (Framework-Consumer Contract)

This file is a **consumer contract**. It does not encode any framework data inline. The planner discovers OpenSSF Scorecard, SLSA, OpenSSF Best Practices Badge, Sigstore, SBOM, NIST SSDF, OSSF S2C2F, and CISA SSCM controls by reading the framework skills under `.github/skills/security/`. Adding or replacing a framework requires no edits to this file.

## Framework Discovery Protocol

Each framework is published as a self-contained skill directory containing:

* `SKILL.md` — entrypoint metadata (consumer contract description, license, attribution).
* `index.yml` — `framework`, `version`, and `phaseMap` fields. `phaseMap.<phase>` lists the control identifiers participating in that planner phase.
* `controls/<id>.yml` — one file per control, validated against [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../scripts/linting/schemas/planner-framework-control.schema.json).

The planner discovers frameworks by invoking `Get-FrameworkSkill -Domain security` (from `scripts/lib/Modules/FrameworkSkillDiscovery.psm1`), passing any `state.frameworks[].additionalRoot` values via `-AdditionalRoots` so externally authored Framework Skills are registered. Discovery filters to entries whose `phaseMap.standards-mapping` is non-empty and registers each as a `frameworkRef` in `state.json` (see [`scripts/linting/schemas/sssc-state.schema.json`](../../../scripts/linting/schemas/sssc-state.schema.json) `$defs.frameworkRef`).

### Draft Quarantine

Framework Skills whose `index.yml` declares `status: draft` are excluded from discovery by default. They are registered only when the corresponding `frameworkRef` opts in via `includeDrafts: true` (typically a user-imported Framework Skill still under authoring). All other `status` values (`published`, omitted) are registered normally. Discovery must log skipped drafts to `skills-loaded.log` with a `skipped: draft` annotation so the consumer can audit exclusions.

### Disabled Framework Skip

Frameworks where `state.frameworks[<id>].disabled === true` are skipped entirely in this phase. The planner does not read `index.yml`, does not load any control files, and does not register gates for the framework. Each skip is logged to `skills-loaded.log` with `{skipped: "disabled", reason: <state.disabledReason>, atPhase: <state.disabledAtPhase>}` so the Phase 6 handoff appendix can render an audit trail. Disabled frameworks remain in `state.frameworks[]` so the audit trail survives compaction.

## Hard Loading Contract

The planner reads framework data lazily and append-only:

1. Read `index.yml` for every registered framework whose `disabled` field is not `true`.
2. For the active phase (`standards-mapping`), resolve `phaseMap.standards-mapping` to the matching `controls/<id>.yml` files, **excluding** any control id present in `state.frameworks[<id>].suppressedControls[].id`.
3. Read **only** those control files; never enumerate or read controls outside the active phase scope.
4. Append one entry per `read_file` of any skill artifact to `skills-loaded.log` (see Identity instructions for the entry schema and enforcement). For each suppressed control, emit a `{skipped: "suppressed", controlId, reason, atPhase}` entry instead of a `read_file` entry so suppressions are visible to the validator and the handoff appendix.

Reading controls scoped to a different phase is a contract violation and is rejected by `Validate-PlannerArtifacts.ps1`.

## Per-Control Field Usage

For each `controls/<id>.yml` loaded during this phase:

* `id`, `title`, `riskTier` — populate the standards mapping table row.
* `assessmentMethod` ∈ `{binary, categorical, continuous}` — drives evidence collection prompts.
* `categories` (categorical) or `range` (continuous) — define allowable values.
* `gates[]` — recorded with `status: pending` until evidence is collected (per [`sssc-risk-classification.instructions.md`](sssc-risk-classification.instructions.md) gate model).
* `evidenceHints[]` — deterministic file globs the planner inspects to suggest current posture.
* `mapsTo[]` — cross-framework links surfaced in the mapping output.

The planner does **not** invent gate semantics, risk tiers, or check identifiers. All such data originates from the per-control YAML.

## Registering a New Framework

To add a framework (for example, OWASP SAMM or CRA Annex I):

1. Create `.github/skills/security/<framework-id>/` containing `SKILL.md`, `index.yml`, and `controls/<id>.yml` files.
2. Validate with `npm run validate:skills`.
3. Validate each control against the planner-framework-control schema.
4. Reference the new skill in `collections/security.collection.yml` if it is to ship with the security collection.

No edits to this instruction file or to `sssc-identity.instructions.md` are required. The planner picks up the new framework on next session start.

## Replacing the Default Framework Set

A user may declare `replaceDefaults: true` on a `frameworkRef` registered through Phase 1 scoping. When set, the planner ignores the default framework set discovered by enumeration and uses only the user-declared frameworks for this assessment.

## Verdict Ladder

Standards mapping rows surface the verdict assigned in Phase 2. The legend below mirrors [`sssc-assessment.instructions.md`](sssc-assessment.instructions.md#verdict-ladder); see that file for the Evidence Exhaustion Rule that governs verdict assignment.

* **verified** — Positive evidence of full coverage. Cite the specific file and line.
* **present** — Artifact exists but full conformance is not yet confirmed; cite the artifact.
* **partial** — Positive evidence of partial coverage. Cite both what is present and the specific gap.
* **unknown** — Evidence Exhaustion Rule incomplete. Not a final verdict; must be resolved before this phase closes.
* **absent** — Positive evidence the control is not implemented (Evidence Exhaustion Rule completed).
* **n/a** — Control does not apply. Cite reason (alternative satisfied, applicability discriminator, repo-settings-only, etc.).

When a framework skill declares `equivalentImplementations` for a control, presence of any listed equivalent scores as `verified`.

### Phase 3 Exit Gate

Phase 3 cannot close while any control row carries a `verdict` of `unknown`. Resolve every `unknown` to one of the other ladder values (or capture a user follow-up answer that does so) before advancing `state.phase` past `standards-mapping`. `Validate-PlannerArtifacts.ps1` enforces this gate.

## Researcher Subagent Delegation

For runtime documentation lookups not encoded as framework controls (for example, CIS Controls, Azure Well-Architected Framework Security pillar, Cloud Adoption Framework), delegate to the Researcher Subagent. Do not attempt to encode net-new external standards inline; either delegate the lookup or publish a new framework skill per the registration protocol above.

## Output

Write `standards-mapping.md` to `.copilot-tracking/sssc-plans/{project-slug}/standards-mapping.md`. Group rows by framework, then by `riskTier` descending. Cite the source skill path and control id for every row.

Update `state.json`:

* Append the loaded framework records to `frameworks[]`.
* Append every `read_file` of a skill artifact to `skillsLoaded[]`.
* Set `phase` to `gap-analysis` once mapping is complete.

## Third-Party Attribution

Attribution lives in each framework skill's `SKILL.md` `metadata` block (`authors`, `content_based_on`). Do not duplicate attribution text in the mapping output; cite the skill path and let the consumer follow the link.
