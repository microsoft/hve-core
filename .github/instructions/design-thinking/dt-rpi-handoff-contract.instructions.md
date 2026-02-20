---
description: 'DT-to-RPI handoff contract defining exit points, artifact schemas, and per-agent input requirements for lateral transitions from Design Thinking to RPI workflow'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT→RPI Handoff Contract

Defines the formal contract for lateral handoffs from Design Thinking coaching into the RPI (Research → Plan → Implement) workflow. Use this guidance whenever a team graduates from a DT space boundary or explicitly requests implementation support.

## Tiered Handoff Schema

Three exit points align with DT space boundaries. Each exit targets the RPI agent best suited to consume DT outputs at that stage.

| Exit Point                 | DT Methods   | DT Space Boundary         | RPI Target  | What Transfers                                                                         |
|----------------------------|--------------|---------------------------|-------------|----------------------------------------------------------------------------------------|
| Problem Statement Complete | 1-3 complete | Problem → Solution        | Researcher  | Validated problem statement, synthesis themes, stakeholder map, constraint inventory   |
| Concept Validated          | 4-6 complete | Solution → Implementation | Planner     | Tested concepts, lo-fi prototype feedback, constraint discoveries, narrowed directions |
| Implementation Spec Ready  | 7-8 complete | Implementation exit       | Implementor | Hi-fi prototype specs, user testing results, architecture decisions, rollout criteria  |

Earlier exit points produce more RPI work. A Problem Statement Complete handoff requires full RPI research and planning. An Implementation Spec Ready handoff may skip directly to implementation.

## Exit-Point Artifact Schema

Record handoff artifacts in the coaching state `transition_log` using a lateral transition entry. Create a handoff summary file alongside the coaching state.

```yaml
# .copilot-tracking/dt/{project-slug}/handoff-summary.md
exit_point: "problem-statement-complete | concept-validated | implementation-spec-ready"
dt_method: 3          # last completed DT method
dt_space: "problem"   # space being exited
handoff_target: "researcher | planner | implementor"
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

| RPI Agent   | Required Inputs                                                           | Optional Inputs                                                             | Format                                                          |
|-------------|---------------------------------------------------------------------------|-----------------------------------------------------------------------------|-----------------------------------------------------------------|
| Researcher  | Problem statement, synthesis themes, constraint inventory                 | Stakeholder map, interview evidence, environmental context                  | Free-form topic referencing DT artifacts by path                |
| Planner     | Validated concepts, constraint discoveries, user feedback from prototypes | Synthesis themes, stakeholder alignment status, frozen/fluid classification | Research file path (from RPI researcher) plus DT artifact paths |
| Implementor | Hi-fi prototype specs, user testing results, architecture decisions       | Performance benchmarks, rollout criteria, trade-off documentation           | Plan file path (from RPI planner)                               |

When handing off to the Researcher, frame the DT problem statement as the research topic and reference artifact paths so the researcher can read DT evidence directly rather than relying on summarized context.

## Graduation Awareness Behavior

The DT coach monitors for handoff readiness at every space boundary using this four-step flow:

1. **Detect**: At each method boundary, assess whether the team's work satisfies the space boundary readiness signals defined in the method sequencing protocol.
2. **Surface**: When readiness signals are met, explicitly name the lateral handoff option alongside forward and backward options. State which exit point applies and which RPI agent would receive the work.
3. **Prepare**: If the team chooses lateral handoff, create the handoff summary file. Tag each artifact and constraint with a confidence marker. Identify gaps where confidence is `unknown` or `conflicting`.
4. **Transfer**: Record a lateral transition in the coaching state `transition_log` with rationale. Announce the handoff target and provide the handoff summary path for the RPI agent.

The coach remains available in an advisory capacity after handoff. If the RPI workflow surfaces questions that require DT methods, the team can resume coaching from the recorded state.

## Handoff Quality Markers

Every artifact, constraint, and assumption in the handoff summary carries a confidence marker:

| Marker        | Definition                                               | RPI Implication                                   |
|---------------|----------------------------------------------------------|---------------------------------------------------|
| `validated`   | Confirmed through multiple sources or direct observation | Accept as grounded input                          |
| `assumed`     | Stated by a source but not independently confirmed       | Flag for verification during RPI research         |
| `unknown`     | Gap identified but not yet investigated                  | Prioritize in RPI research scope                  |
| `conflicting` | Multiple sources disagree                                | Resolve before planning; escalate if unresolvable |

The RPI researcher treats `assumed`, `unknown`, and `conflicting` markers as investigation targets. The RPI planner distinguishes `validated` constraints from `assumed` ones when assessing implementation risk.
