---
description: 'Coaching state schema for Design Thinking session persistence, method progress tracking, and session recovery'
applyTo: '**/.copilot-tracking/dt/**/coaching-state.md'
---

# DT Coaching State Protocol

This instruction defines the coaching state schema, file conventions, and session management protocol for Design Thinking projects. The state file tracks method progress across sessions and enables the coach to resume seamlessly.

## State File Location

Store the coaching state file at `.copilot-tracking/dt/{project-slug}/coaching-state.md`.

* `{project-slug}` is a kebab-case project identifier provided by the user (e.g., `factory-floor-maintenance`). All DT artifacts are scoped under `.copilot-tracking/dt/{project-slug}/`.
* Create the directory when initializing a new coaching project.
* One state file per project. Multiple concurrent projects each get their own directory.

## State File Schema

```yaml
# .copilot-tracking/dt/{project-slug}/coaching-state.md
project:
  name: "Human-readable project name"
  slug: "kebab-case-identifier"
  created: "YYYY-MM-DD"
  initial_request: "Original customer request verbatim"
  initial_classification: "frozen | fluid"

current:
  method: 1          # integer 1-9
  space: "problem"   # problem | solution | implementation
  phase: ""          # free-text label for step within current method

methods_completed: []  # list of integers, e.g. [1, 2, 3]

transition_log:
  - from_method: null
    to_method: 1
    rationale: "Project initialized"
    date: "YYYY-MM-DD"

hint_calibration:
  level: 1              # integer 1-4 matching Progressive Hint Engine levels
  pattern_notes: ""     # free-text observations about user's hint responsiveness

session_log:
  - date: "YYYY-MM-DD"
    method: 1
    summary: "Brief description of session work"

artifacts: []
  # - path: ".copilot-tracking/dt/{project-slug}/stakeholder-map.md"
  #   method: 1
  #   type: "stakeholder-map"
```

### Field Definitions

#### Project Block

* `name`: display name for the project, set during initialization.
* `slug`: kebab-case identifier matching the directory name.
* `created`: ISO 8601 date when the project was initialized.
* `initial_request`: verbatim customer request captured at project start. Preserved as-is for comparison against discovered problem space.
* `initial_classification`: frozen or fluid classification from Method 1 assessment.

#### Current Block

* `method`: integer 1-9 indicating the active method.
* `space`: derived from method number. Methods 1-3 map to `problem`, 4-6 to `solution`, 7-9 to `implementation`.
* `phase`: free-text label describing the current step within the method (e.g., "stakeholder mapping", "interview planning", "theme clustering", "prototype testing").

#### Hint Calibration

* `level`: integer 1-4 indicating the current Progressive Hint Engine level for this team. Start at 1; increase when the team needs more direct guidance and decrease when the team demonstrates self-direction. Levels match the coaching identity's Progressive Hint Engine (Broad Direction, Contextual Focus, Specific Area, Direct Detail).
* `pattern_notes`: free-text observations about the team's hint responsiveness, learning pace, and coaching style preferences. Updated as patterns emerge across sessions.

#### Methods Completed

List of method numbers the team has finished. A method is complete when the coach and team agree its outputs are sufficient to proceed. Once added, methods remain in this list even if they are revisited later.

#### Transition Log

Chronological record of method transitions. Each entry captures:

* `from_method`: source method number (null for initial entry).
* `to_method`: target method number.
* `rationale`: brief explanation of why the transition occurred.
* `date`: ISO 8601 date.

Non-linear iteration produces backward transitions (e.g., from Method 6 back to Method 2). These are normal and recorded with rationale.

#### Session Log

Chronological record of coaching sessions. Each entry captures:

* `date`: ISO 8601 date.
* `method`: active method during the session.
* `summary`: brief description of work accomplished.

#### Artifacts

List of artifacts produced during coaching. Each entry captures:

* `path`: relative path to the artifact from workspace root.
* `method`: method number that produced the artifact.
* `type`: artifact type descriptor (e.g., "stakeholder-map", "interview-notes", "synthesis-themes", "concept-sketch", "prototype-feedback").

## State Management Rules

### Initialization

Create the state file when starting a new coaching project via the `dt-start-project` prompt. Set `current.method` to 1, `current.space` to `problem`, and record the initial transition log entry.

### Updates

Update the state file at these events:

* Method transition (forward, backward, or lateral): update `current` block and append to `transition_log`. When the transition reflects that the current method is complete (the coach and team agree its outputs are sufficient to proceed), add the departing method to `methods_completed` if not already present.
* Session start: append to `session_log` with current date and active method.
* Artifact creation: append to `artifacts` list.
* Phase change within a method: update `current.phase`.
* Hint calibration shift: update `hint_calibration.level` when the team's responsiveness to hints changes. Record observations in `hint_calibration.pattern_notes`.

### Space Derivation

Always derive `current.space` from `current.method`:

* Methods 1-3: `problem`
* Methods 4-6: `solution`
* Methods 7-9: `implementation`

Do not set space independently of method.

## Session Recovery Protocol

When resuming a coaching session:

1. Read the state file at `.copilot-tracking/dt/{project-slug}/coaching-state.md`.
2. Verify the file parses as valid YAML and contains required fields (`project`, `current`, `methods_completed`, `transition_log`).
3. Restore coaching context from `current.method`, `current.space`, and `current.phase`.
4. Review the most recent `transition_log` and `session_log` entries to understand where the team left off.
5. Check `methods_completed` to understand overall progress.
6. Scan the `artifacts` list for available project artifacts to reference.
7. Announce the resumed state to the user: current method, current phase, and a brief summary of previous work.

If the state file is missing or corrupted, inform the user and offer to reinitialize from scratch or reconstruct state from existing artifacts in the project directory.

## Project Directory Contents

The `.copilot-tracking/dt/{project-slug}/` directory holds all project-specific artifacts alongside the state file:

* `coaching-state.md`: coaching state (this schema).
* Method outputs: stakeholder maps, interview notes, synthesis documents, concept descriptions, prototype feedback, testing results.
* Naming convention: use descriptive kebab-case filenames prefixed with the method number (e.g., `method-01-stakeholder-map.md`, `method-03-synthesis-themes.md`).
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

## Integration with Method Sequencing

The coaching state schema aligns with the method routing assessment flow used during method sequencing. The `current.method` field drives which method-tier instructions load via `applyTo` pattern matching. The `transition_log` provides the history that the method sequencing transition protocol references.
