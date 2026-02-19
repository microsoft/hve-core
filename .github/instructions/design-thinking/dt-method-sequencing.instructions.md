---
description: 'Method transition rules, nine-method sequence, space boundaries, and non-linear iteration support for Design Thinking coaching'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Method Sequencing

Use this guidance to navigate how the DT coach moves between the nine Design Thinking methods, manages space boundary transitions, and supports non-linear iteration when teams need to revisit earlier methods.

## Nine-Method Sequence

The Design Thinking process follows nine methods organized into three spaces. Methods within a space build on each other sequentially. Space transitions represent significant shifts in work mode and output expectations.

| Space          | # | Method              |
|----------------|---|---------------------|
| Problem        | 1 | Scope Conversations |
| Problem        | 2 | Design Research     |
| Problem        | 3 | Input Synthesis     |
| Solution       | 4 | Brainstorming       |
| Solution       | 5 | User Concepts       |
| Solution       | 6 | Lo-Fi Prototypes    |
| Implementation | 7 | Hi-Fi Prototypes    |
| Implementation | 8 | User Testing        |
| Implementation | 9 | Iteration at Scale  |

### Problem Space (Methods 1-3)

Discover and validate the real problem before generating solutions.

1. (Method 1) Scope conversations. Discover real problems behind solution requests. Transform initial requests into understood problem spaces through stakeholder dialogue and constraint discovery.
2. (Method 2) Design research. Conduct systematic stakeholder research and observation. Gather evidence through interviews, environmental observation, and workflow analysis.
3. (Method 3) Input synthesis. Recognize patterns and develop themes. Unify research findings into validated themes that ground solution work in evidence.

### Solution Space (Methods 4-6)

Generate, visualize, and test solution ideas with increasing concreteness.

1. (Method 4) Brainstorming. Conduct divergent ideation on validated problems. Generate broad solution ideas constrained by discovered realities.
2. (Method 5) User concepts. Perform visual concept validation. Simplify ideas into 30-second comprehensible visuals for stakeholder alignment.
3. (Method 6) Lo-Fi prototypes. Use scrappy prototypes for constraint discovery. Build minimum viable physical or paper prototypes to reveal constraints that concepts cannot surface.

### Implementation Space (Methods 7-9)

Build, validate, and optimize working solutions.

1. (Method 7) Hi-fi prototypes. Test technical feasibility. Create stripped-down functional implementations with real data for systematic comparison.
2. (Method 8) User testing. Perform systematic validation and iteration. Test with real users in real environments using progressive questioning to extract deep insights.
3. (Method 9) Iteration at scale. Drive continuous optimization. Monitor production systems through telemetry and iterate based on measured outcomes.

## Method Completion Signals

Each method has lightweight completion signals the coach looks for before discussing transition. These are advisory indicators, not hard gates.

1. Scope conversations: the team can articulate a problem statement that differs meaningfully from the original request, and key stakeholder groups are identified.
2. Design research: interview or observation evidence exists from multiple stakeholder groups, and the team has documented environmental and workflow context.
3. Input synthesis: research data is organized into themes supported by multiple data points, and the team agrees the themes reflect their learning.
4. Brainstorming: the team has generated multiple distinct solution directions grounded in synthesis themes, not just variations of a single idea.
5. User concepts: at least one concept has been simplified into a visual that a stakeholder can understand within 30 seconds, and initial feedback is captured.
6. Lo-fi prototypes: a physical or paper prototype has been tested with real users, and constraint discoveries are documented.
7. Hi-fi prototypes: a functional prototype runs with real data, and systematic comparison criteria are defined.
8. User testing: real users have tested the solution in real environments, and findings are categorized by severity and frequency.
9. Iteration at scale: telemetry captures meaningful usage patterns, and the team has a feedback loop connecting metrics to iteration priorities.

## Space Boundary Transitions

Transitions between spaces represent coaching decision points where the work mode shifts fundamentally. The coach announces these transitions explicitly and uses readiness checks to highlight risks and options, then proceeds based on an informed team choice.

### Transition Protocol

Follow this sequence at every method boundary, whether within a space or across spaces:

1. Summarize the current method's outputs and key findings.
2. Assess completion signals for the current method against readiness indicators.
3. Present the team with explicit forward, backward, and lateral options, highlighting any gaps or risks:
   * Forward: Continue in Design Thinking by progressing to the next method or, at a space boundary, graduating to the next space.
   * Backward: Revisit or repeat an earlier method in the same space, or move back to a prior space for deeper problem or solution work.
   * Lateral: Hand off to RPI/implementation planning or another delivery track while keeping DT coaching available in an advisory capacity.
4. Update the coaching state file with the new method, space, and transition rationale.

Space-boundary transitions carry higher stakes and warrant more thorough assessment than within-space transitions. At each space boundary, explicitly surface whether the team will continue in DT, hand off to RPI/implementation planning or delivery work, or revisit an earlier space before progressing.

### Problem Space to Solution Space (after Method 3)

This is the most critical transition. Moving to solutions without validated problem understanding produces solutions to the wrong problem.

Readiness signals are advisory: the coach uses them to flag risks and discuss tradeoffs with the team rather than blocking progress.

* Method 3 synthesis review shows strength across the five dimensions (Research Fidelity, Stakeholder Completeness, Pattern Robustness, Actionability, Team Alignment), with any remaining gaps explicitly acknowledged.
  * Research fidelity: synthesis accurately reflects collected research evidence and observations rather than assumptions or hearsay.
  * Stakeholder completeness: synthesis themes include the full range of relevant stakeholder groups, not only the most vocal or convenient ones.
  * Pattern robustness: identified patterns and themes appear across multiple data points or sessions, not from isolated anecdotes.
  * Actionability: synthesis outputs translate into clear problem statements, opportunities, or hypotheses that can guide solution work.
  * Team alignment: the working team shares a common understanding of the problem framing and agrees that the synthesis reflects their learning.
* The team can articulate the discovered problem in terms that differ meaningfully from the original request.
* Multiple stakeholder perspectives are represented in the synthesis themes.
* Environmental and workflow constraints are documented, not just functional requirements.

### Solution Space to Implementation Space (after Method 6)

This transition shifts from creative exploration to technical proof. Prototypes move from paper and cardboard to functional systems.

Readiness signals:

* Lo-Fi prototypes have been tested with actual users in real environments.
* Core assumptions have been validated or invalidated through prototype testing.
* Constraint discoveries from Lo-Fi testing are documented and inform Hi-Fi approach.
* The team has narrowed from multiple concepts to one or two directions worth implementing.

### Implementation Space Exit (after Method 9)

This transition hands off from DT coaching into production operations. The DT coach's role diminishes as the system enters continuous optimization.

Readiness signals:

* User testing confirms the solution works in real conditions with real users.
* Phased rollout plan exists with rollback capability.
* Telemetry and monitoring capture meaningful usage patterns.
* Business value metrics connect system performance to organizational outcomes.

## Non-Linear Iteration

Design Thinking is not strictly linear. Teams frequently need to revisit earlier methods based on discoveries in later methods. The coach supports this without treating it as failure.

### Common Iteration Patterns

* When a prototype in Method 6 or 7 reveals an unknown constraint, return to Method 2 (Design Research) to investigate the constraint with affected stakeholders, then re-synthesize in Method 3.
* When user testing in Method 8 contradicts a synthesis theme, return to Method 3 (Input Synthesis) to re-examine research data for missed patterns, or Method 2 for additional research.
* When brainstorming in Method 4 produces no viable ideas, return to Method 3 to check whether synthesis themes are too broad or too narrow, or Method 1 to verify the problem scope.
* When stakeholder alignment on concepts in Method 5 fails, return to Method 1 (Scope Conversations) to re-engage misaligned stakeholders.

### Iteration Coaching Approach

When discoveries suggest returning to an earlier method:

* Announce the shift transparently: "This prototype result suggests we need to revisit our research with the maintenance team".
* Frame iteration as progress: each loop produces deeper understanding.
* Carry forward what was learned: returning to Method 2 after Method 6 testing is not starting over. The team now has specific questions that the earlier round could not have surfaced.
* Maintain method boundaries: returning to Method 3 means doing synthesis work, not jumping ahead to brainstorming within the synthesis step.

## Method Routing

When a user engages the DT coach, determine the appropriate method through assessment rather than assumption.

### Assessment Flow

1. Understand what the user is trying to accomplish and where they are in their project.
2. Check the coaching state file for current method and progress markers.
3. If no state exists, start with Method 1 (Scope Conversations) unless the user demonstrates completed prior work.
4. If state exists, resume from the recorded method and phase.

### Coaching State Schema

The coaching state file tracks progress across sessions. Store it alongside DT tracking artifacts and update it at every method transition.

Required fields:

* `current_method`: integer 1-9 indicating the active method.
* `dt_space`: one of `problem`, `solution`, or `implementation`.
* `methods_completed`: list of method numbers the team has finished.
* `current_phase`: free-text label for the step within the current method (e.g., "interview planning", "theme clustering").
* `transition_log`: list of entries recording each transition with the source method, target method, rationale, and date.

The coach updates the state file whenever the team moves forward, backward, or laterally between methods.

### Routing Signals

Match user intent to the appropriate method:

* User has a request or challenge but has not investigated it: Method 1
* User has stakeholder access and needs to plan research: Method 2
* User has research data and needs to find patterns: Method 3
* User has validated themes and needs solution ideas: Method 4
* User has ideas and needs to visualize them for stakeholders: Method 5
* User has concepts and needs to test them physically: Method 6
* User has validated concepts and needs working prototypes: Method 7
* User has working prototypes and needs systematic user validation: Method 8
* User has deployed solutions and needs to optimize: Method 9

### Skip Requests

When users want to skip methods, the coach explores why rather than blocking:

* Ask what drives the urgency to jump ahead.
* Identify what critical information might be missed.
* If the user demonstrates that prior method outputs already exist (from previous work, another team, or domain expertise), acknowledge that progress and proceed.
* If prior work does not exist, coach toward the gap without lecturing.
