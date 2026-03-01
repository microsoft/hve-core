---
description: 'DT-to-RPI handoff contract defining exit points, artifact schemas, and per-agent input requirements for lateral transitions from Design Thinking to RPI workflow'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT→RPI Handoff Contract

Defines the formal contract for lateral handoffs from Design Thinking coaching into the RPI (Research → Plan → Implement) workflow. Use this guidance whenever a team graduates from a DT space boundary or explicitly requests implementation support.

## Tiered Handoff Schema

Three exit points align with DT space boundaries. Each exit targets the RPI agent best suited to consume DT outputs at that stage.

| Exit Point                 | DT Methods   | DT Space Boundary         | RPI Target | What Transfers                                                                         |
|----------------------------|--------------|---------------------------|------------|----------------------------------------------------------------------------------------|
| Problem Statement Complete | 1-3 complete | Problem → Solution        | Researcher | Validated problem statement, synthesis themes, stakeholder map, constraint inventory   |
| Concept Validated          | 4-6 complete | Solution → Implementation | Researcher | Tested concepts, lo-fi prototype feedback, constraint discoveries, narrowed directions |
| Implementation Spec Ready  | 7-9 complete | Implementation exit       | Researcher | Hi-fi prototype specs, user testing results, architecture decisions, rollout criteria  |

The exit tier describes the richness and completeness of artifacts provided to the Researcher, not which RPI phase to skip to. Later exits provide richer context that may reduce the Researcher's investigation scope, but the full RPI pipeline (Research → Plan → Implement) always executes.

Every exit enters the RPI pipeline at Task Researcher. Earlier exit points provide leaner artifacts requiring broader research investigation. Later exit points provide richer, more validated artifacts that narrow the Researcher's scope but do not bypass any RPI phase.

## Exit-Point Artifact Schema

Record handoff artifacts in the coaching state `transition_log` using a lateral transition entry. Create a handoff summary file alongside the coaching state.

```yaml
# .copilot-tracking/dt/{project-slug}/handoff-summary.md
exit_point: "problem-statement-complete | concept-validated | implementation-spec-ready"
dt_method: 3          # last completed DT method
dt_space: "problem"   # space being exited
handoff_target: "researcher"  # constant — all DT exits enter RPI at Researcher
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

Each RPI agent consumes different DT outputs. Provide artifacts matching the target agent's needs.

| RPI Agent   | DT Artifact Consumption                                                                                                                 | Format                                           |
|-------------|-----------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------------------|
| Researcher  | All DT exit artifacts: problem statements, tested concepts, hi-fi specs, stakeholder maps, constraint inventories, user testing results | Free-form topic referencing DT artifacts by path |
| Planner     | Receives DT context indirectly through Researcher output                                                                                | Research file path (upstream from Researcher)    |
| Implementor | Receives DT context indirectly through Researcher→Planner chain                                                                         | Plan file path (upstream from Planner)           |

Frame the DT outputs as the research topic and reference artifact paths so the Researcher can read DT evidence directly rather than relying on summarized context. Planner and Implementor consume DT findings as they flow through the standard RPI pipeline.

## Graduation Awareness Behavior

The DT coach monitors for handoff readiness at every space boundary using this four-step flow:

1. **Detect**: At each method boundary, assess whether the team's work satisfies the space boundary readiness signals defined in the method sequencing protocol.
2. **Surface**: When readiness signals are met, explicitly name the lateral handoff option alongside forward and backward options. State which exit point applies. All exits hand off to Task Researcher.
3. **Prepare**: If the team chooses lateral handoff, create the handoff summary file. Tag each artifact and constraint with a confidence marker. Identify gaps where confidence is `unknown` or `conflicting`.
4. **Transfer**: Record a lateral transition in the coaching state `transition_log` with rationale. Announce the handoff to Task Researcher and provide the handoff summary path.

The coach remains available in an advisory capacity after handoff. If the RPI workflow surfaces questions that require DT methods, the team can resume coaching from the recorded state.

## Handoff Quality Markers

Every artifact, constraint, and assumption in the handoff summary carries a confidence marker:

| Marker        | Definition                                               | RPI Implication                                   |
|---------------|----------------------------------------------------------|---------------------------------------------------|
| `validated`   | Confirmed through multiple sources or direct observation | Accept as grounded input                          |
| `assumed`     | Stated by a source but not independently confirmed       | Flag for verification during RPI research         |
| `unknown`     | Gap identified but not yet investigated                  | Prioritize in RPI research scope                  |
| `conflicting` | Multiple sources disagree                                | Resolve before planning; escalate if unresolvable |

The RPI researcher treats `assumed`, `unknown`, and `conflicting` markers as investigation targets. Downstream RPI agents (Planner, Implementor) encounter these markers through the pipeline chain rather than from direct DT handoff.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
