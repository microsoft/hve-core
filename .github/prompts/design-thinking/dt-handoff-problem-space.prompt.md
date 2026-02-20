---
description: 'Problem Space exit handoff — compiles DT Methods 1-3 outputs into RPI-ready artifact targeting task-researcher'
mode: 'agent'
tools: ['read_file', 'create_file']
argument-hint: "projectName=..."
---

# Problem Space Exit Handoff

Compile Design Thinking Methods 1-3 outputs into an RPI-ready handoff artifact targeting task-researcher.
Invoke when a team graduates from the Problem Space and chooses lateral handoff to the RPI pipeline.

## Inputs

* ${input:projectName}: (Required) Name of the DT project. Derives the project slug (kebab-case) for directory lookup under `.copilot-tracking/dt/`.

## Required Steps

### Step 1: Read Coaching State

1. Derive the project slug from `${input:projectName}` using kebab-case conversion.
2. Read the coaching state file at `.copilot-tracking/dt/{project-slug}/coaching-state.md`.
3. Verify that Methods 1, 2, and 3 appear in the `methods_completed` list.
4. If any of Methods 1-3 are incomplete, report which methods remain and suggest resuming coaching before handoff.

### Step 2: Compile DT Artifacts

Read all Method 1-3 artifacts listed in the coaching state `artifacts` section and organize by method.

#### Method 1: Scope Conversations

* Stakeholder map, scope boundaries, assumptions log, frozen/fluid classification, environmental constraints.

#### Method 2: Design Research

* Research plan, raw findings, interview notes, user observation data.

#### Method 3: Input Synthesis

* Affinity clusters, insight statements, problem definition, how-might-we questions.

For each artifact, record the path, type, and evidence summary.
Note any expected artifact missing from the coaching state as a gap.

### Step 3: Readiness Assessment

Evaluate Problem Space completion against these readiness signals:

* Synthesis validation shows strength across affinity clustering, insight extraction, problem framing, HMW generation, and stakeholder alignment.
* The team articulates a discovered problem that differs meaningfully from the original request.
* Multiple stakeholder perspectives are represented in synthesis themes.
* Environmental and workflow constraints are documented.

Tag each readiness signal with a quality marker:

| Marker        | Definition                                               |
|---------------|----------------------------------------------------------|
| `validated`   | Confirmed through multiple sources or direct observation |
| `assumed`     | Stated by a source but not independently confirmed       |
| `unknown`     | Identified gap not yet investigated                      |
| `conflicting` | Multiple sources disagree                                |

If critical gaps exist (signals marked `unknown` or `conflicting`), present findings and ask whether to proceed with the handoff or return to address gaps first.

### Step 4: Produce Handoff Artifact

Create the handoff summary file at `.copilot-tracking/dt/{project-slug}/handoff-summary.md` following the exit-point artifact schema from the DT→RPI handoff contract.

Include the YAML header:

```yaml
exit_point: "problem-statement-complete"
dt_method: 3
dt_space: "problem"
handoff_target: "researcher"
date: "{today's date}"
```

Include these sections:

* Artifacts: each compiled artifact with path, type, and confidence marker.
* Constraints: each constraint with description, source, and confidence marker.
* Assumptions: each assumption with description, confidence, and impact rating (high/medium/low).

Record a lateral transition in the coaching state `transition_log`:

```yaml
- type: lateral
  from_method: 3
  to: rpi-researcher
  rationale: "Problem Space complete: handoff to RPI pipeline"
  date: "{today's date}"
```

### Step 5: Generate RPI Entry

Create a self-contained RPI handoff document at `.copilot-tracking/dt/{project-slug}/rpi-handoff-problem-space.md` for task-researcher to consume directly.

Structure the document with these sections:

* Problem Statement: the validated problem definition from Method 3, framed as a research topic.
* Stakeholder Context: stakeholder map summary with roles and perspectives.
* Research Themes: key synthesis themes and supporting evidence from Methods 2-3.
* Constraints: validated and assumed constraints with sources.
* Investigation Targets: items tagged `assumed`, `unknown`, or `conflicting` that require RPI research.
* Coaching Notes: context about the DT journey that helps the researcher understand how the problem was discovered.

Inline all content directly rather than referencing `.copilot-tracking/` paths.
The document stands alone as complete context for the receiving RPI agent.

---

Execute the Problem Space exit handoff for project "${input:projectName}" by following the Required Steps.
