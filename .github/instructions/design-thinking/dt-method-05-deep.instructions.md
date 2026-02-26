---
description: 'Deep expertise for Method 5: User Concepts, covering advanced D/F/V analysis, image prompt crafting, concept stress-testing, and portfolio management'
applyTo: ''
---

# DT Method 05 Deep: Advanced User Concept Techniques

On-demand deep reference for Method 5. The coach loads this file when users encounter complex concept evaluation requiring sophisticated D/F/V analysis beyond basic three-lens questions, need advanced guidance for M365 Copilot image prompt crafting, face multi-concept portfolio decisions, or require structured concept stress-testing techniques that exceed the method-tier guidance.

## Advanced D/F/V Analysis

The method-tier file covers Desirability, Feasibility, and Viability as evaluation lenses with guiding questions. The techniques below provide structured frameworks for deeper concept evaluation when surface-level lens application produces inconclusive or conflicting results.

### Jobs-to-Be-Done Mapping

Connect each concept to the specific jobs stakeholders hire a solution to perform. A concept that addresses a real job outperforms one that addresses a perceived need.

* Functional jobs: what the stakeholder needs to accomplish (access repair history, track equipment status, submit incident reports).
* Emotional jobs: how the stakeholder wants to feel while performing the task (confident in the diagnosis, supported during an unfamiliar procedure, trusted by management to act independently).
* Social jobs: how the stakeholder wants to be perceived by peers and leadership (competent, efficient, safety-conscious).

Map each concept against all three job types. Concepts that address only functional jobs tend to score high on feasibility but low on adoption. Concepts addressing emotional and social jobs generate stronger stakeholder resonance during Silent Review.

Coaching prompt: "What job is this concept doing for the operator? Beyond the task itself, how do they want to feel while using it?"

### Kano Model Application

Categorize concept features to distinguish what drives satisfaction from what prevents dissatisfaction:

* Must-be qualities: features stakeholders expect but do not mention. Their absence causes rejection; their presence does not generate enthusiasm. In manufacturing contexts, safety compliance and data accuracy are typical must-be qualities.
* One-dimensional qualities: features where satisfaction scales linearly with performance. Faster response time, broader equipment coverage, and more accurate diagnostics follow this pattern.
* Attractive qualities: features stakeholders do not expect but find delightful when present. Voice-activated interfaces for gloved operators, predictive failure alerts, and context-aware guidance examples fall here.

Evaluate each concept against these categories. A concept composed entirely of must-be qualities functions as table stakes rather than a differentiated solution. A concept overloaded with attractive qualities may lack the foundation stakeholders assume.

Coaching prompt: "If this feature disappeared, would stakeholders complain or not notice? That tells us whether it's a must-have or a differentiator."

### Unit Economics Sketching

Rough cost-benefit framing helps Viability evaluation without requiring financial modeling. The goal is directional understanding, not precision.

* Time savings: estimate minutes saved per occurrence multiplied by occurrence frequency. A 5-minute saving that happens 50 times per shift carries more weight than a 30-minute saving that happens once per month.
* Error reduction: estimate the cost of the errors the concept prevents. Include rework time, scrap materials, downtime, and safety incident costs where applicable.
* Adoption cost: estimate training time, workflow disruption during transition, and ongoing maintenance burden. Concepts requiring extensive retraining face higher viability risk.

Present these sketches as order-of-magnitude comparisons ("saves hours per week" vs "saves minutes per month") rather than precise calculations. Precision at this stage creates false confidence.

Coaching prompt: "Without exact numbers, is this saving minutes or hours? Is the cost of doing nothing higher than the cost of changing?"

### Lens Tension Resolution

When Desirability, Feasibility, and Viability conflict, structured resolution prevents premature concept rejection.

* D-F tension: stakeholders want a feature the team cannot build with current capabilities. Investigate whether a reduced-fidelity version preserves desirability while becoming feasible. Separate the core value from the delivery mechanism.
* D-V tension: stakeholders want a feature the organization cannot justify economically. Explore whether phased rollout or a pilot scope reduces viability risk while maintaining stakeholder interest.
* F-V tension: the team can build a feature, but the organization questions its return. Reframe the value proposition from direct ROI to indirect benefits (reduced turnover, faster onboarding, regulatory compliance).

Document tension patterns and resolution approaches in stakeholder-alignment.md. Unresolved tensions carry forward as explicit risks for Method 6 prototyping rather than hidden assumptions.

Coaching prompt: "Desirability and feasibility are pulling in different directions here. What's the smallest version that satisfies both?"

## M365 Copilot Image Prompt Crafting

The method-tier file covers basic lo-fi style directives (stick figures, minimal lines, plain background). The techniques below provide structured guidance for crafting prompts that produce effective concept visualizations across different scenario types.

### Scene Composition

Effective concept visuals place elements deliberately to communicate the core interaction:

* Foreground: the primary user and their immediate interaction with the solution. This is the concept's focal point.
* Midground: environmental context that establishes constraints (equipment, workspace layout, other people involved in the workflow).
* Background: minimal contextual cues that locate the scene without adding visual noise (factory floor indicators, office setting markers).

Limit each visual to three foreground elements maximum. Every additional element dilutes attention from the core concept. When a concept involves multiple interactions, split into separate visuals rather than crowding one frame.

Coaching prompt: "What's the one interaction this concept enables? Put that front and center, and let the background establish where it happens."

### Perspective Selection

Choose the visual perspective based on what the concept needs to communicate:

* Bird's-eye view: shows spatial relationships, workflow sequences, and multi-person interactions. Use when the concept's value depends on how people and systems connect across a space.
* First-person view: shows what the user sees during the interaction. Use when the concept's value depends on information presentation or interface comprehension.
* Over-the-shoulder view: shows the user in their environment interacting with the solution. Use when environmental constraints are central to the concept's feasibility.
* Side view: shows the physical posture and ergonomic context. Use when the concept involves hands-free interaction, wearable devices, or physical constraints like gloves or hearing protection.

Default to over-the-shoulder for most manufacturing and industrial concepts. This perspective naturally includes environmental constraints while keeping the user's interaction visible.

Coaching prompt: "Are we showing what the user sees, or how the user works? That determines whether we need first-person or over-the-shoulder perspective."

### Sequence Prompts

Some concepts require multiple frames to convey a workflow or interaction progression:

* Limit sequences to three frames: before, during, and after the core interaction. More frames introduce narrative complexity that belongs in Method 6 prototyping.
* Each frame uses consistent style and perspective to avoid visual discontinuity.
* Number frames explicitly in the prompt ("Frame 1 shows..., Frame 2 shows..., Frame 3 shows...").
* Keep each frame's prompt as minimal as a single-frame concept. Sequence prompts that describe detailed scenarios produce cluttered, unreadable visuals.

Coaching prompt: "Can this concept be understood in one image, or does the before-and-after matter? If it needs a sequence, keep it to three frames maximum."

### Prompt Anti-Patterns

Common mistakes that produce visuals undermining concept validation:

* Technology specification: naming specific devices, brands, or interface elements ("iPhone screen showing a React dashboard") anchors stakeholder feedback to implementation rather than concept.
* Emotional staging: requesting facial expressions, body language cues, or dramatic lighting shifts feedback from concept clarity to aesthetic preference.
* Resolution inflation: requesting "detailed," "realistic," or "high-quality" visuals. These terms override lo-fi directives and produce polished images that attract cosmetic feedback.
* Environmental overload: describing complex backgrounds with multiple machines, people, and activities. Each additional element competes with the concept for attention.
* Solution prescription: describing how the solution works internally ("a machine learning model analyzes the sensor data and displays...") rather than what the user experiences.

Coaching prompt: "Does this prompt describe what the user experiences, or how the system works? We need the first one for concept validation."

## Concept Stress-Testing

The method-tier file covers stakeholder validation through the Silent Review sequence. The techniques below provide structured adversarial approaches that test concept resilience before committing to prototyping investment.

### Edge Case Scenarios

Test each concept against conditions that stretch beyond the typical use case:

* Environmental extremes: how does the concept perform during shift changes, equipment failures, power outages, or peak production periods?
* User extremes: how does a first-day employee interact with this concept versus a 20-year veteran? Does the concept serve both without separate training paths?
* Scale extremes: does the concept work for one production line and for twelve? Does it work for a three-person team and for a sixty-person team?
* Failure modes: what happens when the concept's core assumption breaks? If network connectivity drops, if sensor data is unavailable, if the database is unreachable?

Document each edge case and the concept's response. Concepts that fail gracefully under edge conditions are stronger candidates for prototyping than concepts that depend on ideal conditions.

Coaching prompt: "What's the worst realistic day this concept has to survive? Not a catastrophe, but the kind of bad day that happens monthly."

### Assumption Mapping

Every concept rests on assumptions that may not be explicitly stated. Surface them before they become embedded in prototypes:

* Technical assumptions: connectivity availability, device access, system integration capabilities, data quality and latency.
* Behavioral assumptions: user willingness to adopt new workflows, management support for process changes, training time availability.
* Organizational assumptions: budget approval processes, cross-department cooperation, regulatory approval timelines.
* Environmental assumptions: physical space availability, noise levels, lighting conditions, equipment compatibility.

Classify each assumption as validated (supported by Method 2 research evidence), plausible (reasonable but untested), or risky (depends on conditions outside the team's control). Concepts with many risky assumptions need targeted validation before prototyping.

Coaching prompt: "What has to be true about the organization, the technology, and the users for this concept to work? Which of those have we actually verified?"

### Pre-Mortem Exercise

Imagine the concept has been prototyped, tested, and failed. Work backward to identify the most likely failure causes:

* Ask each stakeholder perspective: "It's six months from now and this concept didn't work. What went wrong?"
* Categorize failure causes: adoption resistance, technical infeasibility, organizational misalignment, unmet user needs, cost overrun.
* Identify which failure causes the concept could address now through design changes versus which require external conditions to change.
* Prioritize design changes that prevent the most likely and most damaging failure modes.

Pre-mortems surface risks that optimistic forward-looking evaluation misses. They are particularly effective when stakeholders have experience with previous failed initiatives in similar domains.

Coaching prompt: "If this concept fails in six months, what's the most likely reason? Now, can we design around that failure before it happens?"

### Competitive Response Analysis

Consider how existing solutions and alternatives address the same need:

* Current workarounds: what do stakeholders do today without this concept? What would it take for them to continue with the status quo instead of adopting the new concept?
* Adjacent solutions: what partial solutions exist that address some of the same needs? Could stakeholders assemble existing tools to approximate the concept's value?
* Resistance patterns: what has failed before in this environment? Why did previous attempts to address similar needs not succeed?

Concepts that offer marginal improvement over existing workarounds face adoption challenges regardless of technical quality. Identify the concept's unique advantage over alternatives and ensure it is significant enough to motivate behavior change.

Coaching prompt: "What are people doing today instead of this concept? Why would they switch? The switching cost has to be worth it."

## Concept Portfolio Management

The method-tier file evaluates concepts individually through D/F/V lenses. The techniques below address scenarios where multiple concepts compete for prototyping resources and the team must make portfolio-level decisions.

### Portfolio Balance Assessment

Evaluate the concept portfolio as a collection rather than evaluating concepts in isolation:

* Need coverage: do the selected concepts address different user needs, or do they cluster around the same problem area? A portfolio of three concepts solving the same need with different mechanisms provides less learning than three concepts addressing complementary needs.
* Risk distribution: does the portfolio include both safe bets (incremental improvements with high feasibility) and exploratory concepts (higher-risk ideas with potentially transformative value)? All-safe portfolios miss innovation opportunities; all-exploratory portfolios risk delivering nothing.
* Stakeholder coverage: does each major stakeholder group see at least one concept that addresses their primary concerns?

Coaching prompt: "Looking at all three concepts together, are we exploring one need from three angles or three different needs? Both are valid, but we should know which we're doing."

### Comparison Matrix

When choosing between concepts, structured comparison prevents recency bias and loudest-voice-wins dynamics:

* List evaluation criteria derived from D/F/V analysis, stakeholder priorities, and constraint findings.
* Rate each concept against each criterion using a simple scale (strong, moderate, weak) rather than numerical scores. Numerical precision creates false confidence at this stage.
* Identify which criteria are non-negotiable (must-be qualities from Kano analysis) versus differentiating (attractive qualities).
* A concept that scores weak on any non-negotiable criterion requires design modification before advancing, regardless of other scores.

Coaching prompt: "Before we compare concepts, which criteria are deal-breakers versus nice-to-haves? That changes how we read the comparison."

### Kill Criteria

Define conditions under which a concept should be dropped rather than refined:

* The concept's core assumption has been invalidated by research evidence or stakeholder feedback.
* The concept duplicates another concept's value proposition without offering a meaningful alternative approach.
* Feasibility assessment reveals dependencies outside the team's control with no viable mitigation path.
* Stakeholder feedback during Silent Review reveals consistent misunderstanding that persists after concept revision.

Kill decisions are evidence-based, not preference-based. Document the specific evidence that triggered the kill decision and preserve the concept's insights for potential future use.

Coaching prompt: "Is this concept struggling because the idea is weak, or because our articulation needs work? If we re-explained it and stakeholders still don't connect, that's a signal."

### Merge Identification

Recognize when concepts share enough foundation to combine into a stronger unified concept:

* Shared user job: both concepts address the same functional, emotional, or social job through different mechanisms. The mechanisms may complement rather than compete.
* Complementary strengths: one concept scores high on desirability while another scores high on feasibility. Combining their strongest elements may produce a concept that scores well across both lenses.
* Stakeholder overlap: different stakeholder groups favor different concepts that address the same underlying workflow. A merged concept may serve multiple groups.

Merge candidates should be tested through a new round of Silent Review to verify that the combined concept retains the strengths of both originals without introducing confusion. Forced merges that compromise each concept's clarity produce weaker results than selecting one concept over another.

Coaching prompt: "These two concepts are solving the same problem differently. What if we took the interaction model from one and the value proposition from the other?"

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
