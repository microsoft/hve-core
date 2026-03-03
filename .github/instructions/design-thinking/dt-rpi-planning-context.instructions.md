---
description: 'DT-aware task-planner context: fidelity constraints, iteration support, and confidence-informed planning for DT artifacts'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Planning Context

When task-planner operates on artifacts that originated from a Design Thinking process, these adjustments augment standard planning behavior. The Planner does not receive direct DT handoffs; DT context arrives through the Researcher's output. The plan originates from a Design Thinking process, so fidelity constraints, stakeholder coverage, and iteration support shape planning decisions.

## Planning Adjustments

| Standard Planning               | DT-Informed Planning                                                               |
|---------------------------------|------------------------------------------------------------------------------------|
| Production-quality deliverables | Space-appropriate fidelity (rough/scrappy/functional)                              |
| Linear phase execution          | Iteration-aware phases with return paths to earlier methods                        |
| Technical success criteria      | Stakeholder-segmented success criteria validated by affected groups                |
| Forward-only validation         | Validation incorporating DT coach return triggers                                  |
| Technical risk focus            | Confidence-marker-informed risk assessment (validated/assumed/unknown/conflicting) |

## DT-Specific Planning Patterns

* Use confidence markers (`validated`, `assumed`, `unknown`, `conflicting`) from the handoff artifact to weight task priority and risk. Items marked `unknown` or `conflicting` require resolution steps before downstream implementation. Items marked `assumed` carry elevated risk; include verification steps or note them as research dependencies for the researcher to resolve.
* Verify stakeholder coverage in each plan phase. All stakeholder groups from the handoff's stakeholder map (an artifact entry of type `stakeholder-map` in the handoff `artifacts` array) appear in at least one validation step. When the handoff contains no stakeholder map artifact, flag this gap and recommend updating the handoff before planning proceeds.
* Plan phases may include iteration loops that direct work back to an earlier DT method rather than only forward through implementation. Represent return paths as conditional outcomes within a phase's completion criteria (for example, "If core assumptions remain unresolved, return to DT Method 2 for targeted research").
* Success criteria match the space in which the planned deliverables will be produced: rough acceptance in Problem Space, scrappy acceptance in Solution Space, functional acceptance in Implementation Space.
* Reference DT artifact paths from the handoff in the plan's context section so implementers can trace decisions back to research and synthesis outputs.
* For Solution Space plans, enforce anti-polish: scope deliverables to scrappy fidelity and flag production-quality requests as out-of-scope for the current space.

## Phase Architecture for DT-Origin Plans

Plans originating from DT handoffs follow this content architecture. This describes the phases of the resulting plan, not a replacement for the planner's own workflow phases.

| Phase                  | Purpose                                                                                                                                                                                                                                               |
|------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Context Integration    | Consume the DT handoff artifact, verify confidence markers, identify constraints inherited from the originating space, and establish plan-level success criteria aligned with DT exit signals                                                         |
| Implementation         | Execute implementation tasks with DT constraints applied. Fidelity tier limits scope, stakeholder map informs acceptance criteria, and `assumed` items carry explicit verification steps                                                              |
| Stakeholder Validation | Validate deliverables against each stakeholder group from the handoff's stakeholder map, using space-appropriate evaluation (rough sketches for Problem Space, scrappy prototypes for Solution Space, functional prototypes for Implementation Space) |
| DT Reconnection        | Assess whether findings warrant returning to DT coaching, document outcomes for potential DT method re-entry, and produce a handoff artifact for downstream agents or DT coach return                                                                 |

## Return Path Triggers

Recommend returning to DT coaching rather than proceeding to implementation when any of these conditions emerge:

* Plan decomposition reveals that core assumptions from the DT synthesis remain `unknown` or `conflicting` after research.
* Stakeholder validation during planning surfaces groups absent from the original stakeholder map.
* Fidelity requirements conflict with the originating space tier, indicating the team may have advanced too quickly through DT methods.
* Implementation constraints invalidate the concept or prototype that was validated during DT coaching, requiring a return to Solution Space methods.

These adjustments complement co-loaded instruction files (`dt-rpi-handoff-contract`, `dt-quality-constraints`, `dt-method-sequencing`, `dt-rpi-research-context`, `dt-rpi-review-context`): reference their content during planning rather than duplicating it.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
