---
description: "Phase 3 standards mapping contract — discovers framework skills under .github/skills/sustainability/ and populates state.standardsMapping.activeControls[]."
applyTo: '**/.copilot-tracking/sustainability-plans/**'
---

# Sustainability Phase 3 — Standards Mapping

Discover every published `domain: sustainability` framework skill, intersect each bundle's `surfaceFilter` with `state.surfaces`, expand per-control `appliesTo`, and populate `state.standardsMapping.activeControls[]`. The mapping is the substrate Phase 4 (gap analysis) cross-walks against capabilities discovered in Phase 2 ([`#file:./sustainability-workload-assessment.instructions.md`](./sustainability-workload-assessment.instructions.md)).

Attach the Sustainability Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every standards-mapping artifact written by this phase.

## Framework Discovery

```powershell
$frameworks = Get-FrameworkSkill -Domain sustainability -ItemKind framework
```

Filter the returned set in this order:

1. Drop any framework whose `id` appears in `state.frameworksDisabled[]` (Phase 1 user opt-out). Record the skip in `state.standardsMapping.skipped[]` with the original `reason` and `atPhase: 1` carried forward, plus a `skills-loaded.log` entry stating `skipped: framework-disabled`.
2. Drop any framework whose `surfaceFilter` does not intersect `state.surfaces`. Record the skip in `state.standardsMapping.skipped[]` with `reason: surface-mismatch` and append a `skills-loaded.log` entry.
3. Drop any framework whose `status` is `draft`. Drafts are quarantined and never loaded.

Frameworks that survive all three filters are eligible for active loading.

## Hard Loading Contract

For each surviving framework, before the agent renders any control to the user:

1. Append one entry to `skills-loaded.log` (append-only):
   ```
   <ISO-8601-UTC> phase=3.standards-mapping kind=framework framework=<framework-id> version=<version> license=<license> surfaceIntersection=<surfaces>
   ```
2. Add the bundle to `state.licenseRegister[]` if not already present, capturing `bundleId`, `version`, `license`, `attributionRequired`, `loadedAt`.
3. Add `<framework-id>` to `state.standardsMapping.activeFrameworks[]` (de-duplicated).
4. Iterate the framework's `controls[]` (or `requirements[]`, `practices[]`, `principles[]`, `patterns[]` — whichever item kinds the bundle exposes). For each item:
   * Compute `appliesTo` ∩ `state.surfaces`. If empty, skip the control and record it in `state.standardsMapping.skipped[]` with `reason: control-surface-mismatch`.
   * Otherwise append `{ frameworkId, controlId }` to `state.standardsMapping.activeControls[]`.

The agent refuses to advance to Phase 4 when any framework rendered to the user is missing from `skills-loaded.log` or `state.licenseRegister[]`.

## Per-Control Field Usage

| Field                 | Usage in Phase 3                                                                                 |
|-----------------------|--------------------------------------------------------------------------------------------------|
| `id`                  | Recorded as `state.standardsMapping.activeControls[].controlId`.                                 |
| `framework`           | Recorded as `state.standardsMapping.activeControls[].frameworkId`.                               |
| `appliesTo`           | Intersected with `state.surfaces`; non-empty intersection required for activation.               |
| `automatableBy[]`     | Read-only here; cross-walked against capability `covers[]` in Phase 4.                           |
| `measurementClass`    | Read-only here; consumed by Phase 4 measurement-input recording and Phase 5 priority assignment. |
| `sciVariable`         | Read-only here; consumed by Phase 4 to bind SCI inputs to `E`, `I`, `M`, or `R`.                 |
| `appliesToPrinciples` | Read-only here; consumed by Phase 5 priority ranking (carbon > energy > hardware > others).      |
| `summary`             | Rendered to the user as the human-readable control description.                                  |

Fields not listed above are not consumed in Phase 3.

## Suppression and Skip Recording

Every dropped framework or control is recorded in `state.standardsMapping.skipped[]` as:

```json
{ "frameworkId": "<id>", "controlId": "<id-or-null>", "reason": "<framework-disabled|surface-mismatch|control-surface-mismatch|draft-quarantine>" }
```

`controlId` is omitted when the entire framework is dropped.

## Output

Write the standards-mapping artifact to `.copilot-tracking/sustainability-plans/{project-slug}/standards-mapping.md` containing:

* The Sustainability Planning disclaimer block.
* A per-framework section listing `version`, `license`, `surfaceIntersection`, and the count of active controls.
* A flat table of every active control: `frameworkId`, `controlId`, `appliesTo`, `summary`, `measurementClass`, `sciVariable`.
* A skipped-frameworks/controls appendix sourced from `state.standardsMapping.skipped[]`.

Update `state.json`:

* Populate `state.standardsMapping.activeFrameworks[]`, `state.standardsMapping.activeControls[]`, and `state.standardsMapping.skipped[]`.
* Append every framework load and skip to `skills-loaded.log`.
* Append every newly loaded bundle to `state.licenseRegister[]`.
* Advance `phase` to `4.gap-analysis` only after explicit user confirmation that the standards mapping is complete and accurate.

## Phase Exit Gate

The phase advances only when:

* Every framework not in `state.frameworksDisabled[]` has been evaluated and either loaded or recorded in `state.standardsMapping.skipped[]`.
* `state.standardsMapping.activeControls[]` is non-empty (the assessment has at least one control to evaluate). When empty — e.g. all frameworks were disabled or skipped — the agent halts and asks the user to revisit Phase 1 framework selection.
* The user has explicitly confirmed advancement.

Cross-reference: Phase 4 gap analysis ([`#file:./sustainability-gap-analysis.instructions.md`](./sustainability-gap-analysis.instructions.md)) consumes `state.standardsMapping.activeControls[]` for the cross-walk; Phase 6 handoff ([`#file:./sustainability-handoff.instructions.md`](./sustainability-handoff.instructions.md)) renders both `state.standardsMapping.activeControls[]` and `state.standardsMapping.skipped[]` in the audit appendix.
