---
description: 'DT-aware task-implementor context: fidelity constraints, stakeholder validation, and iteration support'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Implementation Context

When task-implementor operates on DT artifacts or executes a DT-originated plan, these adjustments augment standard implementation behavior. The plan originates from a Design Thinking process, so fidelity constraints, stakeholder validation, and iteration support shape implementation decisions.

## Implementation Adjustments

| Standard Implementation      | DT-Informed Implementation                                                       |
|------------------------------|----------------------------------------------------------------------------------|
| Production-quality code      | Space-appropriate fidelity (rough/scrappy/functional)                            |
| Complete feature delivery    | Constraint-validated scope matching DT prototype specifications                  |
| Technical correctness focus  | Stakeholder experience validation alongside technical correctness                |
| Forward-only execution       | Iteration-aware execution with return paths to earlier DT methods                |
| Full polish and optimization | Anti-polish: functional core without premature optimization or visual refinement |

## DT-Specific Implementation Patterns

* Enforce fidelity constraints from the originating DT space. Problem Space outputs are research-grade, Solution Space outputs are scrappy and concept-grade, and Implementation Space outputs are functionally rigorous without visual polish.
* Verify implementation against each stakeholder group from the handoff's stakeholder map (an artifact of type `stakeholder-map` in the handoff `artifacts` array). When the handoff contains no stakeholder map artifact, flag this gap before proceeding.
* Reference DT artifact paths (`.copilot-tracking/dt/{project-slug}/`) in implementation comments and change logs so decisions trace back to research and synthesis outputs.
* Treat handoff items marked `assumed` with explicit verification steps during implementation. Items marked `unknown` or `conflicting` require resolution before the affected implementation proceeds.
* Support return paths to earlier DT methods as conditional outcomes within phase completion criteria rather than treating all implementation as forward-only.
* For Solution Space implementations, enforce anti-polish: scope deliverables to scrappy fidelity and flag production-quality requests as out-of-scope for the current space.

## Fidelity Constraints by DT Space

| Originating Space                  | Implementation Fidelity                                                             |
|------------------------------------|-------------------------------------------------------------------------------------|
| Problem Space (Methods 1-3)        | Research-grade: outputs serve understanding, not production deployment              |
| Solution Space (Methods 4-6)       | Concept-grade: scrappy prototypes, paper-level fidelity, no production optimization |
| Implementation Space (Methods 7-9) | Functionally rigorous: working systems with real data, not visual polish            |

## Return Path Triggers

Recommend returning to DT coaching rather than continuing implementation when any of these conditions emerge:

* Implementation reveals that core assumptions validated during DT coaching do not hold under real-world constraints.
* Stakeholder groups absent from the original stakeholder map surface during implementation.
* Fidelity requirements for the deliverable exceed the originating space tier, indicating the team may have advanced too quickly through DT methods.
* The prototype or concept validated during DT coaching fails under implementation constraints, requiring a return to Solution Space methods for redesign.

These adjustments complement co-loaded instruction files (`dt-rpi-handoff-contract`, `dt-quality-constraints`, `dt-method-sequencing`, `dt-rpi-planning-context`, `dt-rpi-review-context`): reference their content during implementation rather than duplicating it.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
