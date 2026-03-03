---
description: 'Design Thinking Method 8: User Testing - evidence-based evaluation, test protocols, and non-linear iteration support'
applyTo: '**/.copilot-tracking/dt/**/method-08*'
---

# Design Thinking Method 8: User Testing

These instructions guide coaches through Method 8 of the Design Thinking process, conducting structured user testing of hi-fi prototypes to gather evidence for refinement decisions while supporting non-linear iteration loops back to earlier methods when test findings invalidate core assumptions.

## Method Purpose

Method 8 puts prototypes in front of real or representative users and gathers evidence for go, iterate, or revisit decisions. Unlike Method 6's lo-fi feedback planning, Method 8 conducts structured testing with the functional prototypes validated in Method 7, producing actionable evidence rather than opinions.

Method 8 is the primary trigger for non-linear navigation across the nine-method sequence. Test results may reveal gaps requiring return to Method 2 (research), Method 4 (brainstorming), or Method 6/7 (prototyping), making honest evidence interpretation the defining coaching challenge.

## Sub-Methods Structure

Method 8 operates through three sequential sub-methods addressing distinct testing phases:

| Sub-Method               | Purpose                                                        | Coaching Focus                                                          |
|--------------------------|----------------------------------------------------------------|-------------------------------------------------------------------------|
| **8a: Test Planning**    | Design test protocols, participant profiles, success criteria  | Guide rigorous protocol design and bias-aware question development      |
| **8b: Test Execution**   | Conduct testing sessions with users under realistic conditions | Coach neutral observation and leap-enabling questioning                 |
| **8c: Results Analysis** | Analyze test data and determine next steps                     | Facilitate honest evidence interpretation and non-linear loop decisions |

Each sub-method represents a distinct testing phase with clear transition criteria and specific coaching interventions.

### Sub-Method Transition Criteria

#### 8a to 8b transition gate

Advance to test execution when test protocols define specific tasks (not opinion questions), participant profiles represent all relevant user types, success and failure criteria are explicit and measurable, and leap-enabling question progressions are prepared for each test scenario. Each criterion receives a status of Pass, Needs Improvement, or Requires Rework.

#### 8b to 8c transition gate

Advance to results analysis when testing sessions cover all planned user types and scenarios, observations capture behavior (what users did) not just opinions (what users said), environmental and stress conditions are tested alongside normal operation, and raw data is documented before interpretation begins. Each criterion receives a status of Pass, Needs Improvement, or Requires Rework.

## Two Specialized Hats

| Hat                  | Activation Trigger                           | Primary Responsibilities                                                                            |
|----------------------|----------------------------------------------|-----------------------------------------------------------------------------------------------------|
| **Test Designer**    | Protocol planning and methodology selection  | Design testing methodology, participant selection criteria, success metrics, and bias mitigation    |
| **Evidence Analyst** | Test execution observation and data analysis | Facilitate objective interpretation, separate signal from noise, connect findings to loop decisions |

### Hat Switching Logic

The **Test Designer** activates during 8a when designing protocols and preparing question progressions. The **Evidence Analyst** takes primary control during 8b observation and 8c analysis, ensuring findings are interpreted honestly without confirmation bias.

## Leap Enabling Framework

### Leap Killing vs Leap Enabling Questions

Method 8 coaching enforces leap-enabling questioning throughout test execution:

**Leap Killing** (surface validation, no insight): "Do you like this?" "Is this useful?" "Any problems?"

**Leap Enabling** (progressive discovery through "why?" questioning):

1. **Experience Question**: "Tell me about your experience using this"
2. **First Why**: "What made that challenging or successful?"
3. **Second Why**: "What's driving that underlying need or constraint?"
4. **Implementation Insight**: "How should this change to work better?"

When teams default to leap-killing patterns, coach redirection: "That question will get a yes-or-no answer. What open-ended experience question would reveal how users actually behave?"

## Test Protocol Design

Structured testing approaches the coach guides based on context:

| Protocol               | When to Use                                  | What It Reveals                                       |
|------------------------|----------------------------------------------|-------------------------------------------------------|
| **Task-based testing** | Validating workflow integration              | Completion rate, time, error patterns                 |
| **A/B comparison**     | Multiple prototype variants exist            | User preference with measurable criteria              |
| **Think-aloud**        | Understanding user mental models             | Decision reasoning and confusion points               |
| **Wizard of Oz**       | Testing concept viability before full build  | Whether the concept works when simulated by a human   |
| **Longitudinal**       | Assessing adoption over time (when feasible) | Usage patterns, abandonment triggers, habit formation |

### Environmental Testing Requirements

Validate implementations under realistic conditions: actual noise, lighting, space constraints, time pressure, and integration with existing tools and processes. Avoid testing only in ideal conditions that mask deployment failures.

## Non-Linear Iteration Loops

Method 8 is the primary trigger for non-linear navigation. The coach helps users interpret findings honestly and determine the appropriate response:

| Finding                       | Action                  | Target          |
|-------------------------------|-------------------------|-----------------|
| Missing user data             | Return to research      | → Method 2      |
| Concept invalidated           | Return to brainstorming | → Method 4      |
| Wrong fidelity or constraints | Revisit prototyping     | → Method 6 or 7 |
| Minor usability issues        | Iterate                 | → Method 9      |
| Core assumptions validated    | Proceed                 | → Method 9      |

### Loop Decision Coaching

When test results suggest revisiting earlier methods, the coach facilitates honest assessment:

| Finding depth | Example                                                     | Response                           |
|---------------|-------------------------------------------------------------|------------------------------------|
| Shallow       | "Users found the button hard to tap"                        | Method 9 iteration (UI refinement) |
| Deep          | "Users don't understand the core value proposition"         | Method 4 revisit (concept rethink) |
| Research gap  | "We assumed users work alone, but they coordinate in pairs" | Method 2 revisit (field research)  |

The coach prevents avoidance: "The data suggests users struggled with the fundamental interaction model. That's a Method 4 finding, not a Method 9 tweak. Should we revisit our concepts?"

## Coaching Examples

### Confirmation Bias Prevention

**Scenario**: Team focuses on 7 positive sessions while dismissing 3 sessions where users abandoned a task.

**Level 1 Coaching**: "What patterns do you see across all 10 sessions?"
**Level 2 Coaching**: "You have strong results from most users. What about the 3 users who abandoned the task?"
**Level 3 Coaching**: "Those 3 users share a characteristic: they're all from the night shift with less experience. What does that tell us about expertise-dependent assumptions?"
**Level 4 Coaching**: "The abandonment pattern correlates with experience level. This suggests the interface assumes expertise that newer users lack. That's a concept-level finding, not a UI fix."

### Leap Enabling Coaching

**Scenario**: Team asks users "Do you like the dashboard?" and gets positive responses.

**Intervention**: "That question will confirm what you hope to hear. Try instead: 'Walk me through what happened when you checked the dashboard during your last shift.' That reveals actual behavior, not opinions."

### Loop Decision Scenario

**Scenario**: Testing reveals users coordinate tasks in pairs, but the prototype assumes individual workflows.

**Level 1 Coaching**: "What did you notice about how users interacted with each other during testing?"
**Level 2 Coaching**: "The pair coordination pattern appeared in most sessions. Was that in our original user research?"
**Level 3 Coaching**: "If pair coordination is fundamental to how work happens here, our individual workflow assumption may need revisiting."
**Level 4 Coaching**: "This is a research gap: we built on an assumption about individual workflows that testing disproved. A Method 2 field study of actual coordination patterns would strengthen the foundation before we iterate."

## Output Artifacts

Method 8 produces standardized testing artifacts organized under `.copilot-tracking/dt/{project-slug}/method-08-testing/`:

* `test-protocol.md` documents testing methodology, participant profiles, success and failure criteria, and question progressions for each scenario.
* `test-sessions/` contains per-session observation notes named `session-{participant-type}-{n}.md`, capturing user behavior, environmental factors, and raw observations before interpretation.
* `results-analysis.md` synthesizes findings across sessions, identifying patterns, statistical observations, and evidence strength for each finding.
* `decision-log.md` records go, iterate, or revisit decisions with supporting evidence and rationale linking each decision to the non-linear loop table.

## Method Integration

### From Method 7 (Hi-Fi Prototypes)

* Functional implementations validated for technical feasibility under real-world conditions
* Multiple technical approaches with performance data for user comparison
* Known capabilities, limitations, and trade-offs informing test scenario design
* Specification documents preparing testing scope and focus areas

### To Method 9 (Iteration at Scale)

* User-validated implementations with evidence-based improvement priorities
* Production optimization priorities ranked by user impact
* Adoption risk findings informing telemetry and monitoring strategy
* Loop decisions documenting which findings require iteration versus revisit
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

### Non-Linear Loop Outputs

When testing triggers a return to an earlier method, the decision log captures: the finding, supporting evidence, target method, and what the revisit should investigate. This preserves context across the non-linear jump so earlier-method coaches understand why the team returned.

### Cross-Method Consistency

Maintains DT coaching principles: end-user validation focus, environmental constraint application, multi-stakeholder perspectives, leap-enabling questioning over surface validation, and iterative "fail fast, learn fast" refinement.
