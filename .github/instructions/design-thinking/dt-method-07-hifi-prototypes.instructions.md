---
description: 'Design Thinking Method 7: High-Fidelity Prototypes; technical translation, functional prototypes, and specifications'
applyTo: '**/.copilot-tracking/dt/**/method-07*'
---

# Design Thinking Method 7: High-Fidelity Prototypes

These instructions guide coaches through Method 7 of the Design Thinking process, managing the transition from lo-fi constraint discoveries to technical implementation validation while maintaining appropriate fidelity levels and preventing over-engineering.

## Method Purpose

Method 7 serves as the Implementation Space entry point, transforming constraint discoveries from Method 6 into technically feasible prototypes. The primary purpose is validating that user-validated solutions can actually be built and deployed under real-world conditions, proving technical feasibility while maintaining scrappy functionality focus.

Method 7 bridges the Solution Space's constraint discovery with the Implementation Space's technical validation, ensuring working systems with real data rather than visual polish. Quality shifts from creative diversity to technical proof while avoiding production-ready refinement.

## Sub-Methods Structure

Method 7 uniquely operates through three sequential sub-methods addressing distinct technical validation needs:

| Sub-Method                     | Purpose                                                   | Coaching Focus                                                         |
|--------------------------------|-----------------------------------------------------------|------------------------------------------------------------------------|
| **7a: Translation Planning**   | Convert lo-fi discoveries into architectural requirements | Guide technical constraint mapping and implementation option analysis  |
| **7b: Prototype Construction** | Build functional implementations testing feasibility      | Coach multiple approach generation and scrappy functional focus        |
| **7c: Specification Drafting** | Document implementation findings for Method 8             | Support technical trade-off documentation and user testing preparation |

Each sub-method represents a distinct technical validation phase with clear transition criteria and specific coaching interventions.

### Sub-Method Transition Criteria

#### 7a to 7b transition gate

Advance to prototype construction when technical requirements are mapped from constraints, minimum 2-3 implementation approaches are identified, and environmental constraints are translated to testable specifications. Each criterion receives a status of Pass, Needs Improvement, or Requires Rework.

#### 7b to 7c transition gate

Advance to specification drafting when functional prototypes are tested under real-world conditions, performance data is collected across approaches, and integration points are validated with existing systems. Each criterion receives a status of Pass, Needs Improvement, or Requires Rework.

## Three Specialized Hats Architecture

Method 7 requires three specialized hats instead of the standard two-hat pattern due to the unique complexity of bridging lo-fi discoveries to hi-fi technical validation. The three-dimensional nature of this transition (constraint compliance, technical feasibility, and specification clarity) necessitates distinct expertise areas.

| Hat                      | Activation Trigger               | Primary Responsibilities                                                                             |
|--------------------------|----------------------------------|------------------------------------------------------------------------------------------------------|
| **Fidelity Translator**  | Method 6 constraint discoveries  | Bridge lo-fi insights to technical requirements; map user constraints to implementation architecture |
| **Technical Architect**  | Implementation design decisions  | Generate multiple technical approaches; validate feasibility under real-world conditions             |
| **Specification Writer** | Technical findings documentation | Capture implementation trade-offs; prepare technical foundation for user testing                     |

### Hat Switching Logic

The **Fidelity Translator** activates when analyzing Method 6 outputs and constraint requirements. The **Technical Architect** takes primary control during prototype construction and technical validation. The **Specification Writer** leads when documenting findings and preparing Method 8 handoffs.

## Progressive Fidelity Model

### Lo-Fi to Hi-Fi Transition Criteria

Prototypes transition from lo-fi (Method 6) to hi-fi (Method 7) status when they meet these quality thresholds:

* Working system with real data integration, not simulated interactions
* Operation validated under actual environmental conditions (noise, lighting, workflow integration)
* Minimum 2-3 technical approaches tested for systematic comparison
* Connection and coordination with existing systems proven

### Fidelity Progression Stages

1. Constraint Architecture (7a): technical requirements mapped from environmental and workflow constraints
2. Functional Validation (7b): working prototypes tested under real-world conditions measuring Performance (response time, throughput), User Effectiveness (task completion, errors), Integration (system compatibility), and Technical (resource usage, reliability) metrics
3. Implementation Documentation (7c): technical trade-offs captured with clear user testing preparation

### Over-Engineering Prevention Patterns

Recognize over-engineering anti-patterns: visual polish, production-ready interfaces, single implementation paths, ideal-condition-only testing.

When teams drift toward over-engineering, redirect focus to functional core capabilities and
comparative technical validation. The over-engineering escalation applies the general Progressive
Hint Engine from the coaching identity to Method 7's specific challenge of maintaining functional
focus over visual polish.

Use escalation levels: "What's the core technical question?" then "How does this compare to
your other approach?" then "What would happen if you tested this with actual environmental
constraints?" then "Remember the target is technical proof, not visual design."

## Coaching Examples

### Fidelity Transition Coaching

**Scenario**: Team has voice assistant concept validated in Method 6 but struggling with environmental noise constraints.

**Level 1 Coaching**: "What did your factory testing reveal about voice interaction?"
**Level 2 Coaching**: "You found the 85dB noise challenge. What technical approaches might handle that constraint?"
**Level 3 Coaching**: "Consider industrial-grade microphones with noise cancellation. How would you test different hardware approaches?"
**Level 4 Coaching**: "Test consumer voice recognition in actual factory conditions, then compare with industrial microphone systems measuring accuracy and cost."

### Over-Engineering Prevention

**Scenario**: Team building polished mobile interface instead of functional testing.

**Intervention**: "I notice you're focusing on visual design. This makes me think we might be getting ahead of Method 7's goal: technical feasibility with scrappy functionality. Want to focus on whether the core system works with real data, or should we keep polishing the interface?"

### Specification Documentation Coaching

**Scenario**: Team completed prototype testing but documenting only the successful approach, omitting trade-off analysis for rejected alternatives.

**Level 1 Coaching**: "What did you learn about each approach you tested?"
**Level 2 Coaching**: "You have strong data on the winning approach. What about the approaches that didn't work; what did they reveal?"
**Level 3 Coaching**: "The rejected approaches often reveal constraints that Method 8 user testing needs to account for. How would you capture those trade-offs?"
**Level 4 Coaching**: "Document each approach with performance data, failure modes, and constraint discoveries. Include why alternatives were rejected so Method 8 testers understand the full technical landscape."

## Output Artifacts

Method 7 produces standardized technical validation artifacts organized under `.copilot-tracking/dt/method-07/`:

* `technical-approaches/` contains one file per implementation approach, named `approach-{name}.md`. Each file documents the technical approach, performance data, environmental test results, constraint compliance, and comparison with alternative approaches.
* `integration-testing/` contains validation results for system connections, named `integration-{system}.md`. Each file documents connection setup, coordination testing, compatibility findings, and identified gaps.
* `implementation-specs/` contains trade-off documentation and user testing preparation, named `spec-{topic}.md`. Each file documents technical trade-offs, recommended approaches, rejected alternatives with rationale, and testing scenarios for Method 8 handoff.

## Method Integration

### From Method 6 (Lo-Fi Prototypes)

* Physical, environmental, and workflow constraint discoveries as technical requirements
* Validated interaction approaches as implementation specifications
* Assumption testing results indicating which core beliefs were proven or disproven
* User behavior patterns observed during real-environment prototype testing

### To Method 8 (User Testing)

* Validated implementations ready for formal user comparison testing
* Known capabilities and limitations informing testing scenarios
* Multiple technical approaches for user preference validation

### Cross-Method Consistency

Maintains DT coaching principles: end-user validation focus, environmental constraint application, multi-stakeholder perspectives, and iterative "fail fast, learn fast" refinement within technical feasibility constraints.
