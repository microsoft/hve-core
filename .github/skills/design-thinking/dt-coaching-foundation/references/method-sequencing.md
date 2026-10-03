---
title: 'DT Method Sequencing'
description: Guidance for navigating method transitions, space boundaries, and non-linear iteration across the nine Design Thinking methods.
---

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

* Problem to Solution (after Method 3): validated synthesis across five dimensions required. See ../../dt-methods/references/method-03-synthesis.md for detailed readiness signals.
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

## Next-Method Assessment

When the team asks what to do next, or a session resumes without a clear next step, assess the project before recommending a method:

1. Locate the project from the supplied slug, open files, or conversation. When several projects exist under `.copilot-tracking/dt/` and the slug is ambiguous, list them with their last session dates and ask which one to use. When none exists, offer to start a new project.
2. Read the coaching state's `current`, `methods_completed`, `transition_log`, `session_log`, and `artifacts`, scan the project directory for method artifacts, and compare them with the exit signals in the Nine-Method Sequence.
3. Summarize the project: name and slug, current method and phase, methods completed out of nine, the latest session-log summary, and two or three key artifacts from the current method.
4. Recommend the next method with its transition type:
   * Forward when the current method's exit signals are met; at the 3→4 and 6→7 boundaries, check the space boundary readiness signals above first. Quote the exit signals or readiness signals that support the move.
   * Backward when current work reveals gaps in earlier work; name the source method and target method, and quote the Non-Linear Iteration pattern that authorizes the return.
   * Lateral when all nine methods are complete: offer further Method 9 iteration or a handoff to the RPI workflow.
5. When the same method or method pair appears three or more times in the last six `transition_log` entries, name the loop and ask whether to revisit the underlying challenge or continue refining that method.
6. Ask whether the recommendation fits or the team prefers another method. After the team confirms, update `current.method`, append the `transition_log` entry with its rationale and date, load the target method's references, and begin coaching at the appropriate phase.

At space boundaries and after methods that produce visual artifacts (Methods 1, 3, 4, 5, and 6), mention that the team can export artifacts to a collaborative board for review.

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

When no coaching state exists, start at Method 1 unless the user demonstrates completed prior work. When users request skipping methods, explore why rather than blocking: explain the sequencing rationale and what the skipped methods would contribute, then offer to proceed with caution if the team still prefers to skip.
