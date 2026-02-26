---
title: DT to RPI Integration
description: How Design Thinking outputs feed into the RPI workflow
author: Microsoft
ms.date: 2026-02-25
ms.topic: how-to
keywords:
  - design thinking
  - rpi
  - integration
  - handoff
estimated_reading_time: 6
---

Design Thinking and RPI connect through structured handoff artifacts. When a DT session reaches a natural exit point, the DT Coach prepares an artifact containing validated findings, confidence markers, and stakeholder maps that RPI agents consume as input.

## Handoff Pipeline Overview

```text
DT Coach Session
    │
    ├── Exit Point 1: Problem Statement Complete (Methods 1-3)
    │       └── → Task Researcher
    │
    ├── Exit Point 2: Concept Validated (Methods 4-6)
    │       └── → Task Planner
    │
    └── Exit Point 3: Implementation Spec Ready (Methods 7-8)
            └── → Task Implementor
```

Each exit point produces a handoff artifact with the same schema: artifact paths, confidence markers (`validated`, `assumed`, `unknown`, `conflicting`), and a stakeholder map.

## Exit Points

### Problem Statement Complete (Methods 1-3 → Task Researcher)

After completing Scope Conversations, Design Research, and Input Synthesis, the team has a validated problem statement backed by multi-source evidence. Task Researcher uses this framing to:

* Scope technical research around stakeholder-validated needs rather than assumed requirements
* Treat `assumed` items as verification targets
* Treat `unknown` items as primary research targets
* Investigate from each stakeholder perspective identified in the handoff

### Concept Validated (Methods 4-6 → Task Planner)

After Brainstorming, User Concepts, and Low-Fidelity Prototypes, the team has a stakeholder-validated concept with known constraints. Task Planner uses this to:

* Create implementation plans with space-appropriate fidelity constraints
* Include stakeholder validation steps in each plan phase
* Weight task priority using confidence markers from the handoff
* Build iteration loops that can route work back to DT methods when needed

### Implementation Spec Ready (Methods 7-8 → Task Implementor)

After High-Fidelity Prototypes and User Testing, the team has functionally validated specifications. Task Implementor uses this to:

* Execute implementation with DT-informed fidelity constraints
* Verify implementation against the stakeholder map
* Trace decisions back to DT artifacts via referenced paths
* Flag when real-world constraints invalidate DT assumptions

## Per-Agent Input Mapping

Each RPI agent applies DT-specific adjustments when it receives a handoff artifact.

### Task Researcher

| Standard Behavior               | DT-Informed Behavior                                 |
|---------------------------------|------------------------------------------------------|
| Technical feasibility focus     | Stakeholder impact and technical feasibility         |
| Single-perspective analysis     | Multi-stakeholder analysis across roles and contexts |
| Binary findings (works/doesn't) | Quality-marked findings (validated/assumed/unknown)  |
| Forward-only to planner         | May return to DT coach when findings warrant it      |

When research reveals that the DT problem statement needs revision, fundamental assumptions are invalidated, or unrepresented stakeholders emerge, the researcher recommends returning to DT coaching rather than proceeding to planning.

### Task Planner

| Standard Behavior               | DT-Informed Behavior                                        |
|---------------------------------|-------------------------------------------------------------|
| Production-quality deliverables | Space-appropriate fidelity (rough/scrappy/functional)       |
| Linear phase execution          | Iteration-aware phases with return paths to earlier methods |
| Technical success criteria      | Stakeholder-segmented success criteria                      |
| Forward-only validation         | Validation incorporating DT coach return triggers           |

Plans include a DT Reconnection phase that assesses whether findings warrant returning to DT coaching before downstream implementation.

### Task Implementor

| Standard Behavior            | DT-Informed Behavior                                        |
|------------------------------|-------------------------------------------------------------|
| Production-quality code      | Space-appropriate fidelity                                  |
| Complete feature delivery    | Constraint-validated scope matching DT prototype specs      |
| Technical correctness focus  | Stakeholder experience validation alongside correctness     |
| Full polish and optimization | Anti-polish: functional core without premature optimization |

The implementor enforces fidelity constraints from the originating DT space and references DT artifact paths in implementation logs.

### Task Reviewer

| Standard Behavior        | DT-Informed Behavior                              |
|--------------------------|---------------------------------------------------|
| Code correctness focus   | Coaching quality and method fidelity focus        |
| Pass/fail assessment     | Space-appropriate fidelity assessment             |
| Style guide conformance  | Think/Speak/Empower coaching identity conformance |
| Single output evaluation | Multi-stakeholder coverage evaluation             |

The reviewer checks that all identified stakeholder groups are represented, confidence markers are applied correctly, and output fidelity matches the originating space.

## Confidence Markers

Every handoff artifact tags its contents with confidence markers that downstream agents use to calibrate their work:

| Marker        | Meaning                                 | Downstream Treatment                         |
|---------------|-----------------------------------------|----------------------------------------------|
| `validated`   | Confirmed through multi-source evidence | Treat as reliable input                      |
| `assumed`     | Believed true but not yet verified      | Include verification steps                   |
| `unknown`     | Information gap requiring investigation | Primary research or resolution target        |
| `conflicting` | Evidence points in multiple directions  | Must resolve before downstream work proceeds |

## Iteration Support

The DT-to-RPI handoff is not one-way. When RPI agents encounter issues that trace back to DT assumptions, they can recommend returning to DT coaching:

* Task Researcher returns when the problem statement needs revision or unrepresented stakeholders emerge.
* Task Planner returns when core assumptions remain unresolved after research or fidelity requirements conflict with the originating space.
* Task Implementor returns when real-world constraints invalidate concepts validated during DT coaching.
* Task Reviewer flags items that need DT method re-entry based on artifact quality criteria.

> [!TIP]
> Returning to DT from RPI is a sign of thoroughness, not failure. The integration is designed for non-linear iteration across both frameworks.

## Shared Prompts

The following prompts support DT-to-RPI transitions at each space boundary:

* `dt-handoff-problem-space.prompt.md`: Packages Problem Space artifacts (Methods 1-3) for RPI research and planning
* `dt-handoff-solution-space.prompt.md`: Packages Solution Space artifacts (Methods 4-6) for RPI implementation
* `dt-handoff-implementation-space.prompt.md`: Packages Validation Space artifacts (Methods 7-9) for RPI review and iteration

Each prompt collects the relevant method outputs, confidence markers, and open questions into a structured handoff that RPI agents can consume directly.

## Related Resources

* [Tutorial: Handing Off from DT to RPI](tutorial-handoff-to-rpi.md): Step-by-step guide with practical examples at each exit point
* [Design Thinking Guide](README.md): Overview of all nine methods and three spaces
* [DT Coach Guide](dt-coach.md): How to use the DT Coach agent
* [RPI Workflow](../rpi/README.md): Research, Plan, Implement, Review framework

> Brought to you by microsoft/hve-core

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
