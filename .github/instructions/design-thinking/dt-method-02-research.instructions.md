---
description: 'Method 2 Design Research coaching knowledge: interview techniques, research planning, environmental observation, and insight extraction patterns'
applyTo: '**/.copilot-tracking/dt/**/method-02*'
---

# DT Method 02: Design Research

Systematic discovery of end-user needs through direct engagement (interviews, observations, surveys) transforms abstract business problems into concrete user insights. Skipping this method results in building solutions that stakeholders want but users do not need.

## Purpose

Bridge the gap between stakeholder assumptions and actual user experiences by discovering what problems users really face in their work environment.

## Sub-Method Phases

### Phase 1: Research Planning

Translate Method 1 scope findings into a structured research strategy. Determine which users to engage, what methods to use, and how to sequence activities.

Exit criteria: a research plan exists with prioritized objectives, tiered user targets, selected methods, and a timeline.

### Phase 2: Research Execution

Conduct interviews, observations, and surveys. Adapt questions based on emerging discoveries. Capture raw data including direct quotes, environmental measurements, and workflow observations.

Exit criteria: raw interview notes and observation logs exist for each session with direct quotes and specific observations.

### Phase 3: Research Documentation

Organize raw findings into structured artifacts ready for Method 3 synthesis. Anchor every insight to direct evidence.

Exit criteria: a findings document exists with evidence-backed patterns, environmental constraint documentation, and assumption validation results.

## Coaching Hats

Two specialized hats activate based on conversation context. See dt-method-02-deep.instructions.md for detailed hat guidance, activation triggers, and coaching focus areas.

| Hat               | Role                                                                   | Activation                                                    |
|-------------------|------------------------------------------------------------------------|---------------------------------------------------------------|
| Research Designer | Guides study design, user prioritization, resource optimization        | Planning discussions, resource constraints, research protocol |
| Empathy Guide     | Real-time interview coaching, follow-up questions, pattern recognition | Interview responses, observation notes, challenging dynamics  |

## Research Discovery

### Curiosity-Driven Research

* "Walk me through a typical day when you need to \[accomplish core task\]."
* "What happens when you encounter \[challenge/obstacle\]?"
* "How do you currently work around that limitation?"

### Environmental Constraint Discovery

* "Show me where you actually do this work."
* "What environmental factors make this harder than it should be?"
* "What tools or systems do you currently use for this?"

## Research Planning

Structure research targets into three tiers:

* Tier 1: direct end users who experience the problem daily
* Tier 2: adjacent stakeholders who influence or are affected by the problem
* Tier 3: organizational or technical contacts providing system context

Follow a universal discovery sequence: Environmental Observation, then Workflow Interviews, then Constraint Validation, then Unmet Need Exploration.

A research plan covers: prioritized objectives, tiered user targets with access strategies, method selection matched to objectives, timeline, and compliance protocols.

## Interview Techniques

Design questions for discovery rather than confirmation. See dt-method-02-deep.instructions.md for detailed question patterns, live coaching strategies, and recovery techniques.

* Use open-ended questions about specific situations and workflows, not abstract preferences
* Follow workarounds and adaptations: user-created solutions reveal unmet needs
* Avoid leading questions that confirm existing assumptions

## Environmental Observation

Combine interviews with direct observation of work environments.

* Physical conditions: noise, contamination, temperature, safety, lighting
* Technology interaction: devices, barriers to use, workaround artifacts
* Workflow sequences: actual task execution versus documented procedures
* Communication patterns: channels, breakdowns, informal information sharing

## Lo-Fi Quality Enforcement

Method 2 artifacts enforce raw-data fidelity. The coach actively prevents premature synthesis.

* Capture direct user quotes, not paraphrased summaries
* Record specific environmental details rather than general impressions
* Keep researcher reflections separate from raw observations
* Defer categorization and theming to Method 3
* Redirect solution proposals during research back to deeper constraint understanding

## Mid-Session Subagent Dispatch

The coach can dispatch subagents via `runSubagent` for parallel research analysis (cross-interview patterns, constraint catalogs, assumption validation) while continuing the conversation. See dt-method-02-deep.instructions.md for dispatch protocol and task examples.

## Quality Rules

* Assign insight confidence levels: High (multiple sources confirm), Medium (good evidence but limited), Low (requires additional validation)
* Identify research gaps explicitly. Gaps left unacknowledged propagate into flawed synthesis.
* Insights that surprise stakeholders indicate genuine discovery. Insights confirming initial assumptions suggest confirmation bias.

## Research Goals

### Accomplish

* Genuine need discovery: uncover actual user problems, not confirmation of assumed needs
* Environmental context: map physical, technical, and organizational constraints
* Workflow integration: understand how solutions must fit existing processes

### Avoid

* Solution validation: resist testing predetermined ideas
* Checklist interviewing: avoid rigid scripts preventing adaptive exploration

## Success Indicators

* Environmental factors documented with specific design implications
* User workflows mapped including informal workarounds
* Constraints identified with measurable detail
* Patterns consistent across multiple users
* Insights surprise stakeholders

## Artifact Structure

Method 2 artifacts at `.copilot-tracking/dt/{project-slug}/method-02-research/`:

* `research-plan.md`: prioritized objectives, tiered user targets, methods, timeline
* `interview-{nn}-{user-role}.md`: raw notes with direct quotes and observations
* `observation-{nn}-{context}.md`: environmental observation logs
* `findings-summary.md`: evidence-backed patterns and assumption validation
* `constraint-catalog.md`: structured constraint catalog with design implications

## Input from Method 1

* Identified end-user groups and access pathways
* Business problem hypotheses to investigate
* Stakeholder assumptions to validate
* Environmental constraint initial understanding

## Output to Method 3

* Interview findings with direct quotes and observations
* Environmental constraint documentation with design implications
* Workflow integration requirements
* Unmet need patterns across user groups
* Assumption validation results
