---
description: "Phase 2 workload assessment contract — discovers capability skills under .github/skills/sustainability/ and populates state.workloadAssessment."
applyTo: '**/.copilot-tracking/sustainability-plans/**'
---

# Sustainability Phase 2 — Workload Assessment

Enumerate the workload-archetype capabilities that apply to the user's deployment surfaces, capture the supporting evidence, and populate `state.workloadAssessment`. The assessment output drives Phase 3 (standards mapping) and Phase 4 (gap analysis).

Attach the Sustainability Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every workload-assessment artifact written by this phase.

## Capability Discovery Protocol

Discover capabilities through the Framework Skill Interface (FSI v1.0) helper, scoped to the surfaces captured in Phase 1:

```powershell
$capabilities = Get-FrameworkSkill -ItemKind capability -SurfaceFilter $state.surfaces
```

Discovery rules:

1. The helper returns every `capability` item from every published `domain: sustainability` framework skill whose `surfaceFilter` intersects `state.surfaces` (`cloud | web | ml | fleet`).
2. Skip any framework whose `id` appears in `state.frameworksDisabled[]`. Disabled frameworks were never loaded in Phase 1 and produce no capabilities here; the filter is a defense-in-depth check.
3. Capabilities discovered through frameworks not listed in `state.frameworksDisabled[]` are eligible for assessment, regardless of which framework supplied them.
4. Drafts (`status: draft`) are quarantined and never returned by the helper. Only `status: published` and `status: stable` capabilities reach the agent.

## Hard Loading Contract

Each capability load is recorded in two places, in this order, before any user-facing output:

1. Append one entry to `skills-loaded.log` (append-only — never edit prior entries):
   ```
   <ISO-8601-UTC> phase=2.workload-assessment kind=capability framework=<framework-id> version=<version> id=<capability-id> license=<license> appliesTo=<surfaces>
   ```
2. Append one entry to `state.licenseRegister[]` for the parent framework if it is not already present, capturing `bundleId`, `version`, `license`, `attributionRequired`, `loadedAt`.

The agent refuses to advance to Phase 3 when any capability rendered to the user is missing from `skills-loaded.log`.

## Per-Capability Field Usage

Each FSI capability item is consumed using the following fields:

| Field             | Usage in Phase 2                                                                                       |
|-------------------|--------------------------------------------------------------------------------------------------------|
| `id`              | Recorded as `state.workloadAssessment.capabilities[].capabilityId`.                                    |
| `version`         | Persisted alongside `id` for reproducibility.                                                          |
| `appliesTo`       | Persisted as `state.workloadAssessment.capabilities[].appliesTo` (intersection with `state.surfaces`). |
| `covers[]`        | Read-only here; cross-walked against `automatableBy[]` in Phase 4.                                     |
| `evidenceHints[]` | Surfaced verbatim in the per-capability question set as suggested artifacts to inspect.                |
| `summary`         | Rendered to the user as the human-readable capability description.                                     |

Fields not listed above are not consumed in Phase 2.

## Assessment Protocol

For each discovered capability, run the following loop:

1. Render the capability summary, the surfaces it applies to (intersected with `state.surfaces`), and any `evidenceHints[]` from the FSI item.
2. Ask the user up to five focused questions per turn (per the question-sequence rule in `sustainability-planner.agent.md`) covering:
   * Whether the capability is present in the workload.
   * Which deployment surface(s) it manifests on.
   * Telemetry availability for SCI inputs (`E`, `I`, `M`, `R`).
   * Pre-existing controls or instrumentation already in place.
3. Apply the Verdict Ladder (`present | partial | absent | not-applicable`) for each capability. `not-applicable` requires a recorded reason and is excluded from Phase 4 cross-walking.
4. Apply the Evidence Exhaustion Rule: when the user reports `present` or `partial`, request at least one concrete evidence pointer (file path, dashboard URL, telemetry stream, or workflow reference). Record the evidence pointer alongside the verdict, formatted as the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md); bare workflow paths without line spans (or the appropriate `kind:` qualifier) are not accepted as inspectable evidence and downgrade the verdict to `partial`.
5. Update `state.workloadAssessment.capabilities[]` in memory and continue.

## Confidence Capture

Set `state.workloadAssessment.confidence` to `low | medium | high` based on the breadth and quality of evidence collected:

| Level  | Criteria                                                                                                                               |
|--------|----------------------------------------------------------------------------------------------------------------------------------------|
| high   | Every `present` or `partial` capability is backed by inspectable evidence (telemetry, code, or workflow).                              |
| medium | At least one `present` or `partial` capability is backed by user attestation only (no inspectable artifact).                           |
| low    | Multiple capabilities rely on user attestation or speculative answers, or the user requested to advance with significant `❌` markings. |

The confidence value flows forward to Phase 4 measurement-class assignment. `low` confidence forces every Phase 4 SCI input that lacks deterministic backing to be recorded as `heuristic` or `user-declared`.

## Output

Write the workload-assessment artifact to `.copilot-tracking/sustainability-plans/{project-slug}/workload-assessment.md` containing:

* The Sustainability Planning disclaimer block.
* A per-capability table: `id`, `version`, `verdict`, `appliesTo`, `evidence`, `notes`. Format every `evidence` cell as the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md).
* Aggregate counts by surface and by verdict.
* The recorded `confidence` and a one-paragraph rationale.

Update `state.json` (per the six-step state protocol in `sustainability-planner.agent.md`):

* Set `state.workloadAssessment.capabilities[]`, `state.workloadAssessment.scope`, and `state.workloadAssessment.confidence`.
* Append every capability load to `skillsLoadedLogPath`.
* Set `phase` to `3.standards-mapping` (per `sustainability-state.schema.json`) only after explicit user confirmation that workload assessment is complete.

## Phase Exit Gate

The phase advances only when:

* Every discovered capability has a recorded verdict (no `❓` markings remain).
* Every `present` or `partial` capability has at least one evidence pointer.
* `state.workloadAssessment.confidence` is set.
* The user has explicitly confirmed advancement.

Cross-reference: Phase 3 standards mapping (`sustainability-standards.instructions.md`) consumes `state.workloadAssessment.capabilities[].appliesTo` to scope framework loading. Risk classification (`sustainability-risk-classification.instructions.md`) consumes the same slice to evaluate binary and categorical triggers.
