---
title: 'DT→RPI Handoff Contract'
description: Formal contract for lateral handoffs from Design Thinking coaching into the RPI workflow, including exit points and confidence markers.
---

Defines the formal contract for lateral handoffs from Design Thinking coaching into the retained RPI phases: `rpi-research`, `rpi-plan`, `rpi-implement`, and `rpi-review`. Use this guidance whenever a team graduates from a DT space boundary or explicitly requests implementation support.

## Tiered Handoff Schema

Three exit points align with DT space boundaries. Every exit targets `rpi-research`; the tier communicates how much validated DT evidence is available.

| Exit Point                 | DT Methods   | DT Space Boundary         | RPI Target     | What Transfers                                                                         |
|----------------------------|--------------|---------------------------|----------------|----------------------------------------------------------------------------------------|
| Problem Statement Complete | 1-3 complete | Problem → Solution        | `rpi-research` | Validated problem statement, synthesis themes, stakeholder map, constraint inventory   |
| Concept Validated          | 4-6 complete | Solution → Implementation | `rpi-research` | Tested concepts, lo-fi prototype feedback, constraint discoveries, narrowed directions |
| Implementation Spec Ready  | 7-9 complete | Implementation exit       | `rpi-research` | Hi-fi prototype specs, user testing results, architecture decisions, rollout criteria  |

The exit tier describes the richness and completeness of artifacts provided to `rpi-research`, not which RPI phase to skip. Later exits provide richer context that may reduce the investigation scope, but they do not bypass research.

Every exit enters the RPI pipeline at `rpi-research`. Earlier exit points provide leaner artifacts requiring broader investigation. Later exit points provide richer, more validated artifacts that narrow the investigation scope. The full pipeline continues through `rpi-plan`, `rpi-implement`, and `rpi-review`; maturity never bypasses a phase. `RPI Agent` may coordinate the lifecycle, but the handoff artifact remains a research-ready input for `rpi-research`.

## Exit-Point Artifact Schema

Record handoff artifacts in the coaching state `transition_log` using a lateral transition entry. Create a handoff summary file alongside the coaching state.

```yaml
# .copilot-tracking/dt/{project-slug}/handoff-summary.md
exit_point: "problem-statement-complete | concept-validated | implementation-spec-ready"
dt_method: 3          # last completed DT method
dt_space: "problem"   # space being exited
handoff_target: "rpi-research"  # constant: all DT exits enter at rpi-research
date: "YYYY-MM-DD"

artifacts:
  - path: ".copilot-tracking/dt/{project-slug}/method-03-synthesis-themes.md"
    type: "synthesis-themes"
    confidence: validated
  - path: ".copilot-tracking/dt/{project-slug}/method-01-stakeholder-map.md"
    type: "stakeholder-map"
    confidence: validated

constraints:
  - description: "System must integrate with existing ERP"
    source: "stakeholder-interview"
    confidence: validated
  - description: "Budget limited to current fiscal year"
    source: "project-sponsor"
    confidence: assumed

assumptions:
  - description: "Maintenance team has tablet access on factory floor"
    confidence: unknown
    impact: "high"
```

## RPI Input Contracts

Each retained RPI phase consumes DT context at a different point. Provide artifacts matching the phase's needs.

| RPI Phase       | DT Artifact Consumption                                                                                                                 | Format                                                |
|-----------------|-----------------------------------------------------------------------------------------------------------------------------------------|-------------------------------------------------------|
| `rpi-research`  | All DT exit artifacts: problem statements, tested concepts, hi-fi specs, stakeholder maps, constraint inventories, user testing results | Research-ready topic referencing DT artifacts by path |
| `rpi-plan`      | Receives DT context through the `rpi-research` output                                                                                   | Research artifact path                                |
| `rpi-implement` | Receives DT context through the approved `rpi-plan` output                                                                              | Plan and phase-details paths                          |
| `rpi-review`    | Evaluates implementation evidence against inherited DT context and constraints                                                          | Plan, phase details, changes, and validation evidence |

Frame the DT outputs as the research topic and reference artifact paths so `rpi-research` can read DT evidence directly rather than relying only on summarized context. The resulting context flows through `rpi-plan`, `rpi-implement`, and `rpi-review`.

## Graduation Awareness Behavior

The DT coach monitors for handoff readiness at every space boundary using this four-step flow:

1. **Detect**: At each method boundary, assess whether the team's work satisfies the space boundary readiness signals defined in the method sequencing protocol.
2. **Surface**: When readiness signals are met, explicitly name the lateral handoff option alongside forward and backward options. State which exit point applies. All exits hand off to `rpi-research`.
3. **Prepare**: If the team chooses lateral handoff, create the handoff summary file. Tag each artifact and constraint with a confidence marker. Identify gaps where confidence is `unknown` or `conflicting`.
4. **Transfer**: Record a lateral transition in the coaching state `transition_log` with rationale. Announce the handoff to `rpi-research` and provide the handoff summary path.

The coach remains available in an advisory capacity after handoff. If the RPI workflow surfaces questions that require DT methods, the team can resume coaching from the recorded state.

## Handoff Quality Markers

Every artifact, constraint, and assumption in the handoff summary carries a confidence marker:

| Marker        | Definition                                               | RPI Implication                                   |
|---------------|----------------------------------------------------------|---------------------------------------------------|
| `validated`   | Confirmed through multiple sources or direct observation | Accept as grounded input                          |
| `assumed`     | Stated by a source but not independently confirmed       | Flag for verification during RPI research         |
| `unknown`     | Gap identified but not yet investigated                  | Prioritize in RPI research scope                  |
| `conflicting` | Multiple sources disagree                                | Resolve before planning; escalate if unresolvable |

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
