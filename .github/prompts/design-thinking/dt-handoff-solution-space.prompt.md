---
description: 'Solution Space exit handoff — compiles DT Methods 4-6 outputs into RPI-ready artifact targeting task-researcher'
mode: 'agent'
tools: ['read_file', 'create_file']
argument-hint: "project-slug=..."
---

# Solution Space Exit Handoff

Compile Design Thinking Methods 4-6 outputs into an RPI-ready handoff artifact targeting task-researcher.
Invoke when a team graduates from the Solution Space and chooses lateral handoff to the RPI pipeline.

Methods 4-6 (Brainstorming, User Concepts, Lo-fi Prototypes) correspond to Tier 2 "Concept Validated" in the three-tier exit schema, routing to RPI Researcher for investigation with rich Solution Space context. The handoff transfers tested concepts, constraint discoveries, lo-fi prototype feedback, and narrowed directions.

## Inputs

* ${input:project-slug}: (Required) Kebab-case project identifier for the artifact directory (e.g., `factory-floor-maintenance`).

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

## Required Steps

### Step 1: Read Coaching State

1. Use `${input:project-slug}` as the project directory identifier.
2. Read the coaching state file at `.copilot-tracking/dt/{project-slug}/coaching-state.md`.
3. Verify that Methods 4, 5, and 6 appear in the `methods_completed` list.
4. If any of Methods 4-6 are incomplete, report which methods remain and suggest resuming coaching before handoff.

### Step 2: Compile DT Artifacts

Read all Method 4-6 artifacts listed in the coaching state `artifacts` section and organize by method.

#### Method 4: Brainstorming

* Theme clusters (divergent ideas grouped by affinity).
* Selected themes for concept development.
* Session plan and brainstorming notes.

#### Method 5: User Concepts

* `concepts.yml`: Structured concept definitions with name, description, file, and prompt fields.
* `method-06-handoff.md`: 1-2 prioritized concepts advanced to prototyping.
* Stakeholder alignment notes showing D/F/V (Desirability/Feasibility/Viability) evaluation.

#### Method 6: Lo-fi Prototypes

* `constraint-discoveries.md`: Physical, environmental, and workflow constraints discovered through testing (categorized by type and severity: Blocker/Friction/Minor).
* `test-observations.md`: Structured behavioral evidence from user testing.
* Prototype variations (3-5 per concept) with feedback summaries.
* Validated and invalidated assumptions from testing.
* User behavior patterns observed during prototype interactions.

For each artifact, record the path, type, and evidence summary.
Note any expected artifact missing from the coaching state as a gap.

### Step 3: Readiness Assessment

Evaluate Solution Space completion against these readiness signals:

* Lo-fi prototypes tested in real user environments (not simulated or hypothetical).
* Constraints categorized by type (Physical/Environmental/Workflow) and severity (Blocker/Friction/Minor).
* Core assumptions validated or invalidated through user testing evidence.
* Concept directions narrowed to 1-2 validated approaches.
* User behavior patterns documented from test observations.

Tag each readiness signal with a quality marker:

| Marker        | Definition                                               |
|---------------|----------------------------------------------------------|
| `validated`   | Confirmed through multiple sources or direct observation |
| `assumed`     | Stated by a source but not independently confirmed       |
| `unknown`     | Identified gap not yet investigated                      |
| `conflicting` | Multiple sources disagree                                |

If critical gaps exist (signals marked `unknown` or `conflicting`), present findings and ask whether to proceed with the handoff, return to Method 6 for additional testing, or return to Method 2 for deeper research.

Document the readiness decision and any caveats in the handoff artifact.

### Step 4: Produce Handoff Artifact

Create the handoff summary file at `.copilot-tracking/dt/{project-slug}/handoff-solution-space.md` following the exit-point artifact schema from the DT→RPI handoff contract.

Include the YAML header:

```yaml
exit_point: "concept-validated"
dt_method: 6
dt_space: "solution"
handoff_target: "researcher"
date: "{today's date}"
```

Include these sections:

* Artifacts: each compiled artifact with path, type, and confidence marker.
* Constraints: each constraint with description, source, confidence marker, category (Physical/Environmental/Workflow), and severity (Blocker/Friction/Minor).
* Assumptions: each assumption with description, confidence, validation status (validated/invalidated/untested), and impact rating (high/medium/low).
* Validated Patterns: user behavior patterns observed during testing with supporting evidence.
* Technical Unknowns: items tagged `assumed`, `unknown`, or `conflicting` requiring further investigation.

Inline all content directly rather than referencing artifact paths. The document stands alone as complete context for handoff and audit trail.

Record a lateral transition in the coaching state `transition_log`:

```yaml
- type: lateral
  from_method: 6
  to: rpi-researcher
  rationale: "Solution Space complete: handoff to RPI Researcher with validated concepts"
  date: "{today's date}"
```

### Step 5: Generate RPI Entry

Create a self-contained RPI handoff document at `.copilot-tracking/research/{project-slug}-research-topic.md` for task-researcher to consume directly.

Include YAML frontmatter with `description` set to a summary of the handoff context (for example, `description: 'RPI research topic from DT Solution Space for {project name}'`).

Transform DT artifacts into research-topic context using these mappings:

| DT Artifact                       | Research Topic Context    | Notes                                        |
|-----------------------------------|---------------------------|----------------------------------------------|
| Validated concepts (Method 5)     | Research scope definition | Concepts frame what the Researcher validates |
| Constraint discoveries (Method 6) | Known constraints         | Group by category, flag blockers             |
| User behavior patterns (Method 6) | Observed context          | Include observation evidence                 |
| Invalidated assumptions           | Investigation priorities  | Document what testing disproved              |
| Technical unknowns                | Primary research targets  | Items marked assumed/unknown/conflicting     |

Structure the document with these sections:

* Research Topic: frame the validated concepts as a research question for the Researcher to investigate. State the problem domain, validated directions, and what remains uncertain.
* Known Constraints: constraints organized by category (Physical/Environmental/Workflow) with severity markers. The Researcher treats these as established boundaries.
* Observed Context: user behavior patterns and environmental observations from prototype testing that provide context for research.
* Investigation Priorities: items tagged `assumed`, `unknown`, or `conflicting` requiring Researcher investigation. Prioritize blockers and high-impact unknowns.
* DT Artifact Paths: list all `.copilot-tracking/dt/{project-slug}/` artifact paths so the Researcher can read original DT evidence directly.

---

Execute the Solution Space exit handoff for project "${input:project-slug}" by following the Required Steps.
