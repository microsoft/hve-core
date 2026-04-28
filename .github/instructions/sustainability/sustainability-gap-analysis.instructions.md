---
description: "Phase 4 gap analysis contract — cross-walks capability covers[] against control automatableBy[] and records SCI inputs with measurementClass."
applyTo: '**/.copilot-tracking/sustainability-plans/**'
---

# Sustainability Phase 4 — Gap Analysis (DR-04)

Cross-walk every active control's `automatableBy[]` against every assessed capability's `covers[]`, classify the coverage, and record every SCI input with an explicit `measurementClass`. Phase 4 is the carbon-accounting heart of the assessment: every measurement that flows into Phase 5 SCI budgets originates here.

Attach the Sustainability Planning disclaimer block from [`#file:../shared/disclaimer-language.instructions.md`](../shared/disclaimer-language.instructions.md) at the top of every gap-analysis artifact written by this phase.

Inputs:

* `state.standardsMapping.activeControls[]` from Phase 3 ([`#file:./sustainability-standards.instructions.md`](./sustainability-standards.instructions.md)).
* `state.workloadAssessment.capabilities[]` from Phase 2 ([`#file:./sustainability-workload-assessment.instructions.md`](./sustainability-workload-assessment.instructions.md)).
* `state.workloadAssessment.confidence` (caps measurement-class assignment when `low`).

## Decision Rule DR-04 — Measurement-Class Precedence

Every SCI input is tagged with exactly one `measurementClass`. When multiple sources are available for the same input, the highest-precedence class wins:

```
deterministic > estimated > heuristic > user-declared
```

| Class           | Source profile                                                                                   |
|-----------------|--------------------------------------------------------------------------------------------------|
| `deterministic` | Direct telemetry (cloud meter, RAPL, kWh meter, GPU power log) attributable to the workload.     |
| `estimated`     | Bottom-up model (CPU-hours × TDP, fleet count × per-device kWh) with documented coefficients.    |
| `heuristic`     | Rule-of-thumb (industry average, vendor-supplied default) without workload-specific calibration. |
| `user-declared` | User-attested value with no inspectable source.                                                  |

When `state.workloadAssessment.confidence == "low"`, no input may be promoted above `heuristic` regardless of source claims; the user is asked to upgrade evidence in Phase 5 backlog work items.

## Cross-Walk Protocol

For every `(control, capability)` pair where `control.appliesTo` ∩ `capability.appliesTo` ∩ `state.surfaces` is non-empty:

1. Compute the intersection `control.automatableBy[] ∩ capability.covers[]`.
2. Classify the coverage:

| Classification | Condition                                                                                                                        | State slice                    |
|----------------|----------------------------------------------------------------------------------------------------------------------------------|--------------------------------|
| `verified`     | Intersection is non-empty AND capability verdict is `present` AND inspectable evidence exists (file/dashboard/workflow pointer). | `state.gapAnalysis.verified[]` |
| `partial`      | Intersection is non-empty AND capability verdict is `present` or `partial` AND evidence is user-attested only.                   | `state.gapAnalysis.partial[]`  |
| `absent`       | Intersection is non-empty AND capability verdict is `absent`.                                                                    | `state.gapAnalysis.absent[]`   |
| `manual`       | Intersection is empty (control has no automation hooks the capability supports) — operational/process control.                   | `state.gapAnalysis.manual[]`   |

3. Record the classification entry:
   ```json
   {
     "frameworkId": "<id>",
     "controlId": "<id>",
     "capabilityId": "<id>",
     "appliesTo": ["<surface>", "..."],
     "evidence": "<pointer-or-null>",
     "rationale": "<one-sentence-why>"
   }
   ```

4. When the control declares an `sciVariable` (`E | I | M | R`), prompt the user for the supporting measurement and append to `state.gapAnalysis.measurementInputs[]`:
   ```json
   {
     "sciVariable": "E|I|M|R",
     "measurementClass": "deterministic|estimated|heuristic|user-declared",
     "value": <number>,
     "units": "<units-string>",
     "source": "<pointer-or-attestation-tag>"
   }
   ```

## Six Adoption Categories

Each gap classification additionally receives one adoption category guiding Phase 5 backlog priority:

| Category                   | Trigger                                                                                                           |
|----------------------------|-------------------------------------------------------------------------------------------------------------------|
| `instrumentation-required` | `absent` AND `sciVariable` declared AND no measurement input recorded.                                            |
| `measurement-upgrade`      | `partial` AND highest current `measurementClass` is `estimated`.                                                  |
| `measurement-improvement`  | `partial` AND highest current `measurementClass` is `heuristic` or `user-declared`.                               |
| `automation-gap`           | `partial` AND evidence is user-attested only AND control has `automatableBy[]` entries the capability could meet. |
| `process-control`          | `manual` (operational policy or training control with no automation surface).                                     |
| `validated`                | `verified` (no backlog item required; recorded for the audit trail only).                                         |

## Effort Sizing

Apply the T-shirt sizing table to each non-`validated` classification:

| Size | Indicative effort | Trigger heuristic                                                               |
|------|-------------------|---------------------------------------------------------------------------------|
| XS   | < 1 person-day    | Documentation, configuration toggle, single-line workflow change.               |
| S    | 1-3 person-days   | Single-component instrumentation hook, single-control automation.               |
| M    | 1-2 person-weeks  | Multi-component telemetry, deterministic SCI input bring-up, dashboard wiring.  |
| L    | > 2 person-weeks  | Cross-team workflow change, fleet-wide rollout, vendor coefficient negotiation. |

## Prioritization Rules

* `instrumentation-required` items always rank above any `measurement-upgrade` item.
* Within each category, items whose control `appliesToPrinciples` includes `carbon-efficiency` rank above `energy-efficiency`, which ranks above `hardware-efficiency`, which ranks above all other principles.
* Within each principle band, larger surface-coverage (more entries in `appliesTo`) ranks higher.

These ranks feed Phase 5 ([`#file:./sustainability-backlog.instructions.md`](./sustainability-backlog.instructions.md)) priority assignment.

## Output

Write the gap-analysis artifact to `.copilot-tracking/sustainability-plans/{project-slug}/gap-analysis.md` containing:

* The Sustainability Planning disclaimer block.
* A summary table: count of `verified | partial | absent | manual` per framework.
* A per-classification table with columns: `frameworkId`, `controlId`, `capabilityId`, `category`, `size`, `evidence`, `rationale`. Format every `evidence` cell as the canonical Evidence row defined in [`#file:../shared/evidence-citation.instructions.md`](../shared/evidence-citation.instructions.md); rows missing line spans (or the appropriate `kind:` qualifier) cannot be classified `verified`.
* A measurement-input register table sourced from `state.gapAnalysis.measurementInputs[]` with columns: `sciVariable`, `measurementClass`, `value`, `units`, `source`.

Update `state.json`:

* Populate `state.gapAnalysis.verified[]`, `state.gapAnalysis.partial[]`, `state.gapAnalysis.absent[]`, `state.gapAnalysis.manual[]`, `state.gapAnalysis.measurementInputs[]`.
* Advance `phase` to `5.backlog` only after explicit user confirmation that the gap analysis is complete.

## Phase Exit Gate

The phase advances only when:

* Every `(control, capability)` pair with non-empty surface intersection has a classification.
* Every control with a declared `sciVariable` has either a recorded measurement input OR a recorded `instrumentation-required` gap.
* DR-04 precedence is respected (no input is recorded above its source's class; no input exceeds `heuristic` when confidence is `low`).
* The user has explicitly confirmed advancement.
