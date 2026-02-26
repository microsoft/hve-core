---
description: 'Method transition rules, nine-method sequence, space boundaries, and non-linear iteration support for Design Thinking coaching'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Method Sequencing

Navigate method transitions, space boundaries, and non-linear iteration across the nine Design Thinking methods.

## Nine-Method Sequence

| # | Method              | Space          | Key Output                                   | Exit Signal                                                    |
|---|---------------------|----------------|----------------------------------------------|----------------------------------------------------------------|
| 1 | Scope Conversations | Problem        | Validated problem statement, stakeholder map | Problem differs from original request; stakeholders identified |
| 2 | Design Research     | Problem        | Interview evidence, constraint documentation | Multi-source evidence; environmental context documented        |
| 3 | Input Synthesis     | Problem        | Themes, problem definition, HMW questions    | Themes validated across sources; team alignment confirmed      |
| 4 | Brainstorming       | Solution       | Divergent solution ideas                     | Multiple distinct directions grounded in themes                |
| 5 | User Concepts       | Solution       | Visual concepts for validation               | 30-second comprehensible visual with feedback captured         |
| 6 | Lo-Fi Prototypes    | Solution       | Constraint discoveries from testing          | Prototype tested with real users; constraints documented       |
| 7 | Hi-Fi Prototypes    | Implementation | Functional systems with real data            | Systematic comparison criteria defined                         |
| 8 | User Testing        | Implementation | Validated findings by severity               | Real users tested in real environments                         |
| 9 | Iteration at Scale  | Implementation | Telemetry-driven optimization                | Metrics connected to iteration priorities                      |

## Space Boundary Transitions

At every method boundary, follow this protocol:

1. Summarize current method outputs and key findings
2. Assess completion signals against readiness indicators
3. Present forward, backward, and lateral options with risks
4. Update coaching state with new method, space, and rationale

Space boundaries carry higher stakes. Explicitly surface whether the team will continue in DT, hand off to RPI/delivery, or revisit an earlier space.

* Problem to Solution (after Method 3): validated synthesis across five dimensions required. See dt-method-03-synthesis for detailed readiness signals.
* Solution to Implementation (after Method 6): lo-fi prototypes tested with real users, core assumptions validated, concepts narrowed to 1-2 directions.
* Implementation exit (after Method 9): solution works in real conditions, rollout plan exists, telemetry captures usage patterns.

## Non-Linear Iteration

Iteration is expected. Backtracking is valid. Methods can repeat. Partial re-entry is supported.

Common patterns:

* Prototype reveals unknown constraint: return to Method 2 for targeted research, then re-synthesize in Method 3
* User testing contradicts a theme: return to Method 3 or Method 2
* Brainstorming produces no viable ideas: return to Method 3 to check theme breadth
* Concept alignment fails: return to Method 1 to re-engage stakeholders

Frame iteration as progress: each loop produces deeper understanding. Carry forward what was learned.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

## Method Routing

| Signal                                     | Route To |
|--------------------------------------------|----------|
| New challenge, no investigation            | Method 1 |
| Stakeholder access, research needed        | Method 2 |
| Research data needs pattern recognition    | Method 3 |
| Validated themes need solutions            | Method 4 |
| Ideas need stakeholder visualization       | Method 5 |
| Concepts need physical testing             | Method 6 |
| Validated concepts need working prototypes | Method 7 |
| Prototypes need systematic user validation | Method 8 |
| Deployed solution needs optimization       | Method 9 |

When no coaching state exists, start at Method 1 unless the user demonstrates completed prior work. When users request skipping methods, explore why rather than blocking.
