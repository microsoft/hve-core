---
description: 'Method 1 Scope Conversations coaching knowledge for Design Thinking: frozen vs fluid assessment, stakeholder discovery, constraint patterns, and conversation navigation'
applyTo: '**/.copilot-tracking/dt/**/method-01*'
---

# DT Method 01: Scope Conversations

Scope conversations transform initial customer requests into genuine understanding of business challenges. This method cannot be skipped. Without this foundation, engagements solve the wrong problems efficiently.

## Purpose

Discover and verify the underlying problems of the customer's business and identify high-value problems to solve through nuanced discussion with primary stakeholders.

## Sub-Methods

| Sub-Method              | Focus         | Coaching Behavior                                                                                                                          |
|-------------------------|---------------|--------------------------------------------------------------------------------------------------------------------------------------------|
| 1a: Scope Planning      | Planning      | Help the user identify key stakeholders and define conversation goals. Ask: "Who experiences this problem most directly?"                  |
| 1b: Scope Execution     | Execution     | Guide stakeholder conversations. Help frame questions that reveal assumptions: "What would change if [stakeholder] described the problem?" |
| 1c: Scope Documentation | Documentation | Capture outputs: stakeholder map, scope boundaries, known vs assumed. Help organize without polishing.                                     |

## Specialized Hats

| Hat                | Role                                                               | Activation       |
|--------------------|--------------------------------------------------------------------|------------------|
| Stakeholder Mapper | Guides identification and relationship mapping of affected parties | During 1a and 1b |
| Scope Framer       | Helps articulate boundaries, constraints, and open questions       | During 1b and 1c |

## Artifact Outputs

Outputs stored at `.copilot-tracking/dt/{project-slug}/method-01-scope/`:

* `stakeholder-map.md` captures stakeholder groups, relationships, and influence levels.
* `scope-boundaries.md` records what is in scope, out of scope, and open questions.
* `assumptions-log.md` tracks known facts vs assumptions to validate.

## Lo-Fi Quality Enforcement

Method 1 artifacts are explicitly rough:

* Stakeholder maps are bullet lists or simple tables, not polished diagrams.
* Scope boundaries are conversational, not formal requirements documents.
* Assumptions are captured as-is, not analyzed or prioritized yet.

## Frozen vs Fluid Assessment

Every customer engagement begins with classifying the initial request. Classification shapes the entire conversation strategy.

### Fluid Requests

Vague desires that need focus and direction. Example: "We want to use AI."

Coaching approach for fluid requests:

* Focus on business goals and specific metrics the customer wants to drive and change.
* Explore how AI has been used in admired companies.
* Identify manual processes in the business unit that could benefit from automation.
* Suggest starting with a brainstorming workshop to explore AI possibilities and gather ideas from business arms.

### Frozen Requests

Specific solution requests that may mask the real problem. Example: "Build me a chatbot for our manufacturing floor."

Coaching approach for frozen requests:

* Acknowledge their thinking before exploring further: "It sounds like you've thought this through and have a solid plan."
* Ask what drives the specific request and what problem it solves.
* Explore business impact expectations: time savings, cost reduction, quality improvement.
* Understand current state and existing processes before discussing future state.
* Surface solution complexity: "There really are a dozen different kinds of chatbots that could be built."

### Classification Signals

* Frozen requests contain both a specific technology and a specific context.
* Fluid requests express broad aspiration without a defined problem or solution.
* Frozen requests often hide fluid underlying needs; do not assume obvious classifications.
* When uncertain, classify as frozen and explore the driving problem.

## Stakeholder Discovery

Map the full ecosystem of people who influence or are impacted by potential solutions.

### Three Tiers of Stakeholders

* Primary: decision makers, budget holders, daily users
* Secondary: influencers, supporters, potential resistors
* Hidden: compliance, regulatory, union representatives, IT security

### Discovery Patterns

* Ask "who else should we talk to?" and "who would use this day-to-day?" in every conversation.
* Map real power dynamics: formal authority and actual influence often differ.
* Sequence engagement thoughtfully: some stakeholders provide context that informs conversations with others.
* Consider how conversations with one group affect relationships with another.
* Identify experts and SMEs for design research in Method 2.

### Stakeholder-Specific Conversation Strategies

* Visionaries: connect big ideas to concrete metrics.
* Skeptics: address concerns while demonstrating value through insightful questions.
* Detail-oriented stakeholders: honor expertise while broadening scope.
* Busy executives: maximize efficiency while building relationships.

## Constraint Discovery

Environmental constraints often reveal why initial solution requests will not work and point toward better alternatives.

### Physical Environment

* "Walk me through the actual workspace where this would be used."
* "What are the environmental conditions like?" (noise, temperature, safety requirements)
* "How do people currently interact with technology in this environment?"

### Operational Workflow

* "How does this fit into people's current daily routine?"
* "What happens when the current process breaks down?"
* "What are the time pressures and deadlines involved?"

### Technical Reality

* "What technology infrastructure is already in place?"
* "Are there security or compliance requirements we should know about?"
* "Who manages technology decisions and implementation?"

## Conversation Coaching

### Rapport Building

* Build rapport before diving deep; understand their perspective and acknowledge their thinking first.
* Use a "Yes, and..." approach: acknowledge their thinking, then build on it to deepen understanding rather than pivoting immediately.
* Challenge assumptions gently by asking about context rather than rejecting ideas.
* Demonstrate genuine curiosity about their business, not just your interpretation of their problem.
* Recognize that customers know their business better than the consulting team.

### Navigation Techniques

* When conversations get stuck or stakeholders become defensive, shift focus from process to user experience.
* When stakeholders give evasive responses, note the pattern and explore from a different angle.
* When themes repeat across stakeholders, flag the pattern and dig deeper.
* When stakeholders insist on a specific solution, ask what drives the urgency rather than blocking.
* Help customers see complexity: what seems simple often has many variables and considerations.

### Common Pitfalls to Coach Against

* Rushing to solutions instead of understanding what to build.
* Taking requests at face value without asking "what problem does this solve?" and "why now?"
* Skipping stakeholder identification and talking only to the requester.
* Making assumptions without validating understanding through summarization.
* Agreeing on solutions or implementation during scope conversations.

## Scope Conversation Goals

### Accomplish

* Scope down the problem space from broad challenges to specific, solvable problems.
* Map the stakeholder ecosystem including hidden stakeholders.
* Identify experts and SMEs for design research.
* Understand confidence level in the problem definition.
* Surface environmental constraints (physical, operational, technical).
* Document the evolution from initial request to discovered problem space.

### Avoid

* Agreeing on solutions or implementation details.
* Locking into the initial request without exploring alternatives.

## Quality Rules

* Classify constraints as frozen (fixed, non-negotiable) or fluid (malleable, open to change) before proceeding
* Success indicator: the customer shares context they had not originally planned to discuss. The initial request evolves or becomes more nuanced.
* Document the original request alongside the discovered problem space. The gap between them reveals understanding depth.

## Success Indicators

### During Conversations

* The customer shares context they had not originally planned to discuss.
* New stakeholders or user groups are identified.
* The initial request evolves or becomes more nuanced.
* The customer asks about the team's methodology or approach.

### After Conversations

* A clear problem statement that differs from the initial request.
* An identified list of people to interview in design research.
* Shared understanding of what good outcomes look like.
* Customer excitement about collaborative discovery.

## Transition to Method 2

Use scope conversation outputs to prepare for design research:

* Who to interview: end users, SMEs, and decision makers identified during scoping.
* What to focus on: specific problem areas and business contexts discovered.
* Where to observe: locations, processes, or workflows mentioned as relevant.
* Stakeholder map with contact information and interview priorities.
* Success criteria and measurement approaches established.

## Multi-Stakeholder Validation

Do not rely on a single conversation. Validate key insights across different stakeholder groups:

* Primary stakeholder confirms business goals and constraints.
* End users verify assumptions about daily reality and pain points.
* Technical teams validate infrastructure and implementation constraints.
* Decision makers ensure alignment on success criteria and scope.

Document original request versus discovered problem space, key constraints, the stakeholder ecosystem with roles, and business impact expectations as the foundation for all subsequent methods.

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
