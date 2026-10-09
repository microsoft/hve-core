---
title: 'DT Space-Exit Handoffs'
description: Procedures for compiling Problem, Solution, and Implementation Space exits into research-ready input for rpi-research.
---

Use these procedures when a team graduates from a Design Thinking space and chooses a lateral handoff to the RPI workflow. Every exit targets `rpi-research`. The [handoff contract](rpi-handoff-contract.md) owns the exit-point tiers, the artifact schema, and the quality markers; the [subagent handoff](subagent-handoff.md) owns readiness dispatch and compilation; the [research context](rpi-research-context.md) frames the receiving phase.

All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory. Only the RPI entry documents named below may live elsewhere.

## Shared Procedure

1. Load the handoff contract, subagent handoff, and research context references.
2. Read `.copilot-tracking/dt/{project-slug}/coaching-state.md`. When it does not exist, report the missing path and ask the user to confirm the project before continuing.
3. Confirm that the space's methods appear in `methods_completed`. When any are incomplete, report the remaining methods and suggest resuming coaching before the handoff.
4. Compile the space's artifacts from the coaching state `artifacts` list and organize them by method. Record each artifact's path, type, and a one- to two-sentence evidence summary of its key finding or outcome. Record any expected artifact that is missing from the coaching state as a gap.
5. Evaluate the space's readiness signals and tag each with a quality marker from the handoff contract (`validated`, `assumed`, `unknown`, or `conflicting`). When signals are `unknown` or `conflicting`, present the findings and ask whether to proceed with the handoff or return to address the gaps first.
6. Write the space's handoff summary file and append the lateral `transition_log` entry to the coaching state.
7. Generate the space's self-contained RPI entry document for `rpi-research`. Inline content rather than linking `.copilot-tracking/` paths, except in a section that explicitly lists DT artifact paths.

## Problem Space Exit

Use this exit after Methods 1-3, the `problem-statement-complete` exit point.

### Artifacts to Compile

* Method 1, Scope Conversations: stakeholder map, scope boundaries, assumptions log, frozen and fluid classification, environmental constraints.
* Method 2, Design Research: research plan, raw findings, interview notes, user observation data.
* Method 3, Input Synthesis: affinity clusters, insight statements, problem definition, how-might-we questions.

### Readiness Signals

* Synthesis validation shows strength across affinity clustering, insight extraction, problem framing, HMW generation, and stakeholder alignment.
* The team articulates a discovered problem that differs meaningfully from the original request.
* Multiple stakeholder perspectives are represented in synthesis themes.
* Environmental and workflow constraints are documented.

### Handoff Summary and Transition

Create `.copilot-tracking/dt/{project-slug}/handoff-summary.md` with this YAML header:

```yaml
exit_point: "problem-statement-complete"
dt_method: 3
dt_space: "problem"
handoff_target: "rpi-research"
date: "{today's date}"
```

Include these sections:

* Artifacts: each compiled artifact with path, type, and confidence marker.
* Constraints: each constraint with description, source, and confidence marker.
* Assumptions: each assumption with description, confidence, and impact rating (high, medium, or low).

Append this `transition_log` entry:

```yaml
- type: lateral
  from_method: 3
  to: "rpi-research"
  rationale: "Problem Space complete: handoff to rpi-research"
  date: "{today's date}"
```

### RPI Entry

Create `.copilot-tracking/dt/{project-slug}/rpi-handoff-problem-space.md` with these sections:

* Problem Statement: the validated problem definition from Method 3, framed as a research topic.
* Stakeholder Context: stakeholder map summary with roles and perspectives.
* Research Themes: key synthesis themes and supporting evidence from Methods 2-3.
* Constraints: validated and assumed constraints with sources.
* Investigation Targets: items tagged `assumed`, `unknown`, or `conflicting` that require RPI research.
* Coaching Notes: context about the DT journey that helps the research phase understand how the problem was discovered.

The document stands alone as complete context for `rpi-research`.

## Solution Space Exit

Use this exit after Methods 4-6 (Brainstorming, User Concepts, Lo-fi Prototypes), the `concept-validated` exit point. It carries tested concepts, constraint discoveries, lo-fi prototype feedback, and narrowed directions.

### Artifacts to Compile

* Method 4, Brainstorming: theme clusters of divergent ideas grouped by affinity, themes selected for concept development, and the session plan with brainstorming notes.
* Method 5, User Concepts: `concepts.yml` with structured concept definitions (name, description, file, and prompt fields), `method-06-handoff.md` with the 1-2 prioritized concepts advanced to prototyping, and stakeholder alignment notes with the Desirability, Feasibility, and Viability evaluation.
* Method 6, Lo-fi Prototypes: `constraint-discoveries.md` with physical, environmental, and workflow constraints categorized by type and severity (Blocker, Friction, or Minor), `test-observations.md` with structured behavioral evidence, prototype variations (3-5 per concept) with feedback summaries, validated and invalidated assumptions, and observed user behavior patterns.

### Readiness Signals

* Lo-fi prototypes were tested in real user environments, not simulated or hypothetical ones.
* Constraints are categorized by type (Physical, Environmental, or Workflow) and severity (Blocker, Friction, or Minor).
* Core assumptions are validated or invalidated through user testing evidence.
* Concept directions are narrowed to 1-2 validated approaches.
* User behavior patterns are documented from test observations.

When signals are `unknown` or `conflicting`, offer three choices: proceed with the handoff, return to Method 6 for additional testing, or return to Method 2 for deeper research. Document the readiness decision and any caveats in the handoff summary.

### Handoff Summary and Transition

Create `.copilot-tracking/dt/{project-slug}/handoff-solution-space.md` with this YAML header:

```yaml
exit_point: "concept-validated"
dt_method: 6
dt_space: "solution"
handoff_target: "rpi-research"
date: "{today's date}"
```

Include these sections, inlining content rather than referencing artifact paths so the document stands alone as handoff context and audit trail:

* Artifacts: each compiled artifact with path, type, and confidence marker.
* Constraints: each constraint with description, source, confidence marker, category, and severity.
* Assumptions: each assumption with description, confidence, validation status (validated, invalidated, or untested), and impact rating.
* Validated Patterns: user behavior patterns observed during testing with supporting evidence.
* Technical Unknowns: items tagged `assumed`, `unknown`, or `conflicting` that require further investigation.

Append this `transition_log` entry:

```yaml
- type: lateral
  from_method: 6
  to: "rpi-research"
  rationale: "Solution Space complete: handoff to rpi-research with validated concepts"
  date: "{today's date}"
```

### RPI Entry

Create `.copilot-tracking/research/{project-slug}-research-topic.md` with YAML frontmatter whose `description` summarizes the handoff, for example `description: 'RPI research topic from DT Solution Space for {project name}'`. Map DT artifacts to research context:

| DT Artifact                       | Research Topic Context    | Notes                                           |
|-----------------------------------|---------------------------|-------------------------------------------------|
| Validated concepts (Method 5)     | Research scope definition | Concepts frame what `rpi-research` investigates |
| Constraint discoveries (Method 6) | Known constraints         | Group by category, flag blockers                |
| User behavior patterns (Method 6) | Observed context          | Include observation evidence                    |
| Invalidated assumptions           | Investigation priorities  | Document what testing disproved                 |
| Technical unknowns                | Primary research targets  | Items marked assumed, unknown, or conflicting   |

Structure the document with these sections:

* Research Topic: the validated concepts framed as a research question, stating the problem domain, the validated directions, and what remains uncertain.
* Known Constraints: constraints organized by category with severity markers, which the research phase treats as established boundaries.
* Observed Context: user behavior patterns and environmental observations from prototype testing.
* Investigation Priorities: items tagged `assumed`, `unknown`, or `conflicting`, with blockers and high-impact unknowns first.
* DT Artifact Paths: every `.copilot-tracking/dt/{project-slug}/` artifact path so `rpi-research` can read the original DT evidence.

### Optional UX Structure Route

This route is separate, optional, and never automatic. When the practitioner separately asks to wireframe a validated concept, they may pass the completed handoff document as an explicit `source` to the `ux-artifacts` `sketch-structure` mode. That mode records what a surface contains and how it behaves; a picture is a later destination step it does not perform.

Do not start this route as part of the exit, and do not treat it as a prerequisite for `rpi-research`. Methods 5 and 6 keep their low-fidelity constraints: concept sketches stay scrappy, prototypes stay deliberately rough, and neither becomes an interface specification here.

## Implementation Space Exit

Use this exit after Implementation Space work, the `implementation-spec-ready` exit point. It is the final DT exit and carries cumulative artifact lineage from all completed methods.

### Exit Tier

Determine the tier from `methods_completed` and record it for the later steps:

* Method 7 only: tier `guided`.
* Methods 7-8: tier `structured`.
* Methods 7-9: tier `comprehensive`.

When no Implementation Space method is complete, report the status and suggest resuming coaching before the handoff.

### Artifacts to Compile

* Method 7, Hi-Fi Prototypes: architecture decisions and technical trade-offs, comparison results across at least 2-3 implementation approaches, the fidelity mapping matrix, performance benchmarks, integration validation results, and specification drafts.
* Method 8, User Testing (structured and comprehensive tiers): test protocols and participant profiles, behavioral, verbal, and task-completion observations, severity-frequency matrix findings, assumption validation results (confirmed, challenged, or invalidated), and the pivot-or-persevere iteration decision log.
* Method 9, Iteration at Scale (comprehensive tier): the refinement log with baseline measurements, the scaling assessment across technical, user, process, and constraint dimensions, the deployment plan with change management, the iteration summary with business value metrics, and leading and lagging adoption metrics.

Check for handoff lineage from earlier exits: `handoff-summary.md` and `rpi-handoff-problem-space.md` from a Problem Space exit, and `handoff-solution-space.md` plus `.copilot-tracking/research/{project-slug}-research-topic.md` from a Solution Space exit. Reference and summarize them when they exist. When they do not, because the team ran through all methods without a lateral exit, compile lineage from the coaching state artifacts for Methods 1-6: the validated problem statement, stakeholder map, synthesis themes, and constraint inventory from the Problem Space, and the tested concepts, lo-fi prototype feedback, constraint discoveries, and narrowed directions from the Solution Space.

### Readiness Signals

* Working prototype with real data integration (Method 7).
* Operation validated under actual conditions (Method 7).
* At least 2-3 technical approaches compared (Method 7).
* Real users tested in real environments (Method 8; structured and comprehensive tiers).
* Behavioral observations captured alongside opinions (Method 8; structured and comprehensive tiers).
* Severity-frequency matrix applied to findings (Method 8; structured and comprehensive tiers).
* Telemetry captures meaningful patterns (Method 9; comprehensive tier).
* Phased rollout plan with rollback capability (Method 9; comprehensive tier).
* Business value metrics connect to outcomes (Method 9; comprehensive tier).

Before writing any handoff artifact, verify explicit evidence that the user chose a lateral handoff: either the current user request to run this handoff or a coaching state `session_log` entry that records the user's explicit choice. Do not treat a `transition_log` entry, completed methods, available artifacts, or remembered conversation as approval. When approval cannot be established, present the readiness findings, ask whether to hand off even when no answer is currently available, and stop without changing coaching state or creating handoff artifacts.

Every Implementation Space exit hands off to `rpi-research` regardless of tier or prototype maturity. The tier and readiness assessment shape the investigation scope; higher tiers with more validated evidence typically narrow the research needed without bypassing it.

When signals are `unknown` or `conflicting`, present the findings and ask whether to proceed or return to address the gaps first. When no answer to that question is available and prior handoff approval was verified, preserve the earlier choice, proceed, and document every gap under Investigation Priorities. When prior approval was not verified, stop as described above. Never treat a missing response as initial handoff approval.

### Handoff Summary and Transition

Create `.copilot-tracking/dt/{project-slug}/handoff-summary-implementation-space.md` with this YAML header. The `tier` field extends the base contract schema to capture exit granularity:

```yaml
exit_point: "implementation-spec-ready"
dt_method: 9          # or 7 or 8 based on tier
dt_space: "implementation"
handoff_target: "rpi-research"
date: "{today's date}"
tier: "comprehensive"  # guided | structured | comprehensive
```

Include Artifacts, Constraints, and Assumptions sections with the same fields as the Problem Space exit, then append this `transition_log` entry:

```yaml
- type: lateral
  from_method: 9      # or 7 or 8 based on tier
  to: "rpi-research"
  rationale: "Implementation Space complete: handoff to rpi-research with validated implementation artifacts"
  date: "{today's date}"
  tier: "comprehensive"   # guided | structured | comprehensive
```

### RPI Entry

Create `.copilot-tracking/research/{project-slug}-research-topic.md` with YAML frontmatter whose `description` summarizes the handoff. Sanitize the content first:

* Remove coaching notes, hint calibration data, and session management metadata.
* Convert method references to outcome descriptions: "high-fidelity prototype validation" for Method 7, "user testing results" for Method 8, and "iteration and scaling assessment" for Method 9.
* Preserve all evidence, metrics, and quotes verbatim.
* Remove temporal markers from handoff content.
* Retain the confidence markers.

Structure the document with these sections:

* Research Topic: the implementation artifacts framed as a research question, stating the validated prototype, the architecture decisions, and what `rpi-research` should investigate further, such as production readiness, scaling gaps, and integration concerns.
* Validated Implementation Evidence: architecture decisions, technical trade-offs, and prototype validation results; testing observations and severity-frequency findings; and, for the comprehensive tier, the scaling assessment and deployment readiness.
* Problem and Solution Space Lineage: the validated problem statement, stakeholder map, and synthesis themes, plus the tested concepts, constraint discoveries, and narrowed directions, drawn from earlier handoff artifacts or compiled from the coaching state.
* Known Constraints: validated and assumed constraints with sources, organized by type.
* Investigation Priorities: items tagged `assumed`, `unknown`, or `conflicting`, grouped with blockers first, then high-impact items, then lower-impact items.
* DT Artifact Paths: every `.copilot-tracking/dt/{project-slug}/` artifact path so `rpi-research` can read the original DT evidence.

Inline all other content rather than referencing `.copilot-tracking/` paths. The document stands alone as complete context for `rpi-research`.

### Completion Ceremony

Close with a conversational summary that covers:

1. The journey from the original request (`initial_request` in coaching state) through Problem Space discovery and Solution Space validation to Implementation Space technical proof.
2. Key pivot moments: significant non-linear iterations and what they revealed.
3. Value delivered: measurable business value from comprehensive-tier metrics, or the expected value for earlier tiers.
4. Coaching state updates: confirm every completed method in `methods_completed`, verify the lateral transition entry, and append a completion summary to `session_log`.
5. The forward look: how the RPI workflow carries the DT investment forward, naming `rpi-research` as the target phase and giving the RPI entry document path.
