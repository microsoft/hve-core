---
description: 'DT-aware task-researcher context — frames research around DT methods, stakeholder needs, and empathy-driven inquiry'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Research Context

When task-researcher receives a handoff from the DT coach, these adjustments augment standard research behavior. The research question originates from a Design Thinking process rather than a technical spec, so stakeholder perspectives and empathy-driven inquiry shape the research framing.

## Research Framing Adjustments

| Standard Research               | DT-Informed Research                                            |
|---------------------------------|-----------------------------------------------------------------|
| Technical feasibility focus     | Stakeholder impact and technical feasibility                    |
| Single-perspective analysis     | Multi-stakeholder analysis across roles and contexts            |
| Binary findings (works/doesn't) | Quality-marked findings (validated/assumed/unknown/conflicting) |
| Forward-only to planner         | May return to DT coach when findings warrant revisiting         |
| Code-centric results            | Human-centric results with code implications                    |

## DT-Specific Research Patterns

* When the research question references stakeholders, investigate from each stakeholder perspective identified in the handoff artifact.
* Handoff items marked `assumed` become verification targets — seek evidence that confirms or contradicts each assumption.
* Handoff items marked `unknown` become primary research targets with dedicated investigation.
* Process qualitative data (interview themes, observation patterns) alongside quantitative data from the DT artifact paths.
* When an industry context template was active during coaching, reference its vocabulary mapping and constraint inventory for domain-specific framing.

## Output Format Additions

When producing research output in DT context, include these sections alongside the standard research document:

* For each `assumed` item from the handoff, state whether evidence supports, contradicts, or remains inconclusive in an Assumption Validation Results section.
* For each `unknown` item, provide findings or recommend continued investigation with rationale in a Gap Resolution section.
* Describe how research findings affect each stakeholder group from the handoff's stakeholder map in a Stakeholder Impact Assessment section.
* State whether findings warrant returning to DT coaching before proceeding to planning, with rationale, in a DT Coach Return Recommendation section.

## Return Path Triggers

Recommend returning to DT coaching rather than proceeding to planning when any of these conditions emerge:

* The problem statement requires significant revision based on research findings.
* Research reveals stakeholders not represented in the original stakeholder map.
* Fundamental assumptions from Method 1-3 synthesis are invalidated by evidence.
* Conflicting evidence indicates the Method 3 synthesis needs rework before implementation planning can proceed.
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
