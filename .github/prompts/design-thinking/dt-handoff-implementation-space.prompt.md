---
description: 'Compiles DT Methods 7-9 outputs into RPI-ready handoff artifact with tiered routing'
agent: 'agent'
tools: ['read_file', 'create_file', 'replace_string_in_file']
argument-hint: "project-slug=..."
---

# Implementation Space Exit Handoff

Compile Design Thinking Methods 7-9 outputs into an RPI-ready handoff artifact with tiered routing.
Invoke when a team graduates from the Implementation Space and chooses lateral handoff to the RPI pipeline.
This is the final DT exit point: the richest handoff carrying cumulative artifact lineage from all nine methods.

## Inputs

* ${input:project-slug}: (Required) Kebab-case project identifier for the artifact directory (e.g., `factory-floor-maintenance`).

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

## Required Steps

### Step 1: Read Coaching State

1. Use `${input:project-slug}` as the project directory identifier.
2. Read the coaching state file at `.copilot-tracking/dt/{project-slug}/coaching-state.md`. If the file does not exist, report the missing file path and ask the user to verify the project name before proceeding.
3. Check `methods_completed` to determine the exit tier:
   * Method 7 only → tier 1 (guided).
   * Methods 7-8 → tier 2 (structured).
   * Methods 7-9 → tier 3 (comprehensive).
4. If no Implementation Space methods are complete, report status and suggest resuming coaching before handoff.
5. Record the determined tier for use in subsequent steps.

### Step 2: Compile DT Artifacts

Read all artifacts listed in the coaching state `artifacts` section and organize by method.
For each artifact, record the path, type, and evidence summary (a one to two sentence summary capturing the key finding or outcome documented in the artifact).
Note any expected artifact missing from the coaching state as a gap.

#### Method 7: Hi-Fi Prototypes

* Architecture decisions and technical trade-offs.
* Implementation comparison results (minimum 2-3 approaches).
* Fidelity mapping matrix.
* Performance benchmarks.
* Integration validation results.
* Specification drafts.

#### Method 8: User Testing (Tier 2+)

* Test protocols and participant profiles.
* Observation data (behavioral, verbal, task completion).
* Severity-frequency matrix findings.
* Assumption validation results (confirmed, challenged, invalidated).
* Iteration decision log (pivot vs persevere).

#### Method 9: Iteration at Scale (Tier 3)

* Refinement log with baseline measurements.
* Scaling assessment (technical, user, process, constraint dimensions).
* Deployment plan with change management.
* Iteration summary with business value metrics.
* Adoption metrics (leading and lagging indicators).

#### Handoff Lineage

Check for existing earlier handoff artifacts:

* `handoff-summary.md`: prior Problem Space handoff summary in the project directory.
* `handoff-summary-solution-space.md`: prior Solution Space handoff summary in the project directory, if a lateral exit occurred at Method 6.
* `rpi-handoff-problem-space.md`: Problem Space handoff artifact if a lateral exit occurred at Method 3.
* `rpi-handoff-solution-space.md`: Solution Space handoff artifact if a lateral exit occurred at Method 6.

If earlier handoff artifacts exist, reference them and summarize key outcomes.
If they do not exist (team ran through all methods without lateral exits), compile lineage from coaching state artifacts for Methods 1-6 directly:

* Validated problem statement, stakeholder map, synthesis themes, and constraint inventory from Problem Space (Methods 1-3).
* Tested concepts, lo-fi prototype feedback, constraint discoveries, and narrowed directions from Solution Space (Methods 4-6).

### Step 3: Readiness Assessment

Evaluate Implementation Space completion against tier-appropriate readiness signals:

* Working prototype with real data integration (M7).
* Operation validated under actual conditions (M7).
* Minimum 2-3 technical approaches compared (M7).
* Real users tested in real environments (M8, tier 2+).
* Behavioral observations captured alongside opinions (M8, tier 2+).
* Severity-frequency matrix applied to findings (M8, tier 2+).
* Telemetry captures meaningful patterns (M9, tier 3).
* Phased rollout plan with rollback capability (M9, tier 3).
* Business value metrics connect to outcomes (M9, tier 3).

Tag each readiness signal with a quality marker:

| Marker        | Definition                                               |
|---------------|----------------------------------------------------------|
| `validated`   | Confirmed through multiple sources or direct observation |
| `assumed`     | Stated by a source but not independently confirmed       |
| `unknown`     | Identified gap not yet investigated                      |
| `conflicting` | Multiple sources disagree                                |

Routing decision:

* Route to task-implementor when the prototype is near production-ready, the deployment plan is comprehensive, testing evidence is thorough, and architecture decisions are documented.
* Route to task-planner when significant production architecture gaps remain, the scaling assessment reveals large unresolved needs, or the exit tier is tier 1 (guided).

If critical gaps exist (signals marked `unknown` or `conflicting`), present findings and ask whether to proceed with the handoff or return to address gaps first. If no user response is available, default to proceeding with the handoff and documenting gaps in the Investigation Targets section.

### Step 4: Produce Handoff Artifact

Create the handoff summary file at `.copilot-tracking/dt/{project-slug}/handoff-summary-implementation-space.md` following the exit-point artifact schema from the DT-RPI handoff contract.

Include the YAML header. The `tier` field extends the base DT-RPI handoff contract schema to capture exit granularity:

```yaml
exit_point: "implementation-spec-ready"
dt_method: 9          # or 7/8 based on tier
dt_space: "implementation"
handoff_target: "implementor"  # or "planner" based on routing decision
date: "{today's date}"
tier: "comprehensive"  # guided | structured | comprehensive
```

Include these sections:

* Artifacts: each compiled artifact with path, type, and confidence marker.
* Constraints: each constraint with description, source, and confidence marker.
* Assumptions: each assumption with description, confidence, and impact rating (high/medium/low).

Record a lateral transition in the coaching state `transition_log`:

```yaml
- type: lateral
  from_method: 9      # or 7/8 based on tier
  to: "implementor"  # or "planner"
  rationale: "Implementation Space complete: handoff to RPI pipeline"
  date: "{today's date}"
  tier: "comprehensive"   # guided | structured | comprehensive
```

### Step 5: Generate RPI Entry

Create a self-contained RPI handoff document at `.copilot-tracking/dt/{project-slug}/rpi-handoff-implementation-space.md` for the target RPI agent to consume directly.

Include YAML frontmatter with `description` set to a summary of the handoff context (for example, `description: 'RPI handoff from DT Implementation Space for {project name}'`).

Content sanitization: apply these rules before generating.

* Remove coaching notes, hint calibration data, and session management metadata.
* Convert DT method references to outcome descriptions. Replace "Method 7" with "high-fidelity prototype validation," "Method 8" with "user testing results," and "Method 9" with "iteration and scaling assessment."
* Preserve all evidence, metrics, and quotes verbatim.
* Remove temporal markers from handoff content.
* Retain confidence markers (validated, assumed, unknown, conflicting).

Structure the document with these sections:

#### Implementation Summary

Validated prototype description, architecture decisions, and key technical trade-offs from high-fidelity prototype validation.

#### Testing Evidence (Tier 2+)

User testing results, behavioral observations, severity-frequency findings, and iteration decisions from user testing.

#### Deployment Readiness (Tier 3)

Scaling assessment, deployment plan, rollout strategy, business value metrics, and adoption indicators from iteration and scaling assessment.

#### Problem Space Foundation (Lineage)

Validated problem statement, stakeholder map, and synthesis themes from Methods 1-3.

#### Solution Space Refinement (Lineage)

Tested concepts, constraint discoveries, and narrowed directions from Methods 4-6.

#### Constraints

Validated and assumed constraints with sources.

#### Investigation Targets

Items tagged `assumed`, `unknown`, or `conflicting` requiring further work.

#### Routing Rationale

Why task-implementor or task-planner was selected, with gap analysis summary.

Inline all content directly rather than referencing `.copilot-tracking/` paths.
The document stands alone as complete context for the receiving RPI agent.

### Step 6: Completion Ceremony

Present the completion ceremony as a conversational summary to the user covering these topics.

1. Journey summary: trace the path from initial request through Problem Space discovery, Solution Space validation, to Implementation Space technical proof. Compare the original request (`initial_request` from coaching state) to the validated solution.
2. Key pivot moments: highlight significant non-linear iterations and what they revealed.
3. Value delivered: summarize measurable business value from tier 3 (comprehensive) metrics or note expected value for earlier tiers.
4. Coaching state updates:
   * Confirm all completed methods in `methods_completed`.
   * Verify the lateral transition entry from Step 4 is recorded.
   * Append a completion summary to `session_log`.
5. Forward look: describe how the RPI pipeline carries the DT investment forward, naming the target agent and the handoff artifact path.

---

Execute the Implementation Space exit handoff for project "${input:project-slug}" by following the Required Steps.
