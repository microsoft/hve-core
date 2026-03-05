---
description: 'DT subagent handoff workflow: readiness assessment, artifact compilation, and handoff validation via subagent dispatch'
applyTo: '**/.copilot-tracking/dt/**'
---

# DT Subagent Handoff Workflow

Defines how the DT coach dispatches subagents during handoff transitions at space boundaries. Mid-session research dispatch (quick queries during active coaching) is governed by the coach agent definition. This instruction governs the multi-step handoff workflow.

## Readiness Assessment

When the coach detects graduation awareness at a space boundary, dispatch an assessment subagent with:

* Current DT space (problem, solution, or implementation)
* Expected artifacts per the exit-point schema from the handoff contract
* Project directory path for artifact scanning

The subagent scans artifacts against the exit-point schema:

1. Verify file existence for each expected artifact.
2. Assess content completeness: non-empty files with key sections populated.
3. Inventory quality markers: count validated, assumed, unknown, and conflicting items.

The subagent returns:

* Readiness status: Ready, Partially Ready, or Not Ready
* Missing artifacts list
* Quality summary (for example, "3 validated insights, 2 unknown assumptions, 1 conflicting data point")
* Recommended actions when not fully ready

## Artifact Compilation

When the user confirms handoff and readiness is acceptable, dispatch a compilation subagent with:

* Exit-point schema template from the handoff contract
* Project artifact directory paths
* Quality marker definitions

The subagent reads and compiles method artifacts into the exit schema:

1. Extract key content from each method's output files.
2. Apply quality markers based on artifact content and coaching history.
3. Generate the structured exit-point artifact with confidence annotations.

The subagent returns the compiled artifact. The coach reviews and adjusts before passing it to the handoff prompt.

## Handoff Validation

After the handoff prompt generates the RPI entry artifact, dispatch a validation subagent with:

* Generated RPI entry artifact
* RPI input contract for the target agent
* Content sanitization rules

The subagent validates:

1. All required RPI input fields are populated.
2. No `.copilot-tracking/` paths appear in the artifact.
3. No planning reference IDs leak into the artifact.
4. Quality markers are present and consistent with source data.

The subagent returns a validation result: Pass or Fail with specific issues listed.

## Session Continuity

During all subagent dispatch:

* Coaching state remains read-only for subagents. Only the coach modifies state.
* Coach identity and hint calibration persist across dispatch boundaries.
* If subagent dispatch fails, the coach presents assessment or compilation manually with reduced detail.
* Inform the user that background work is in progress ("Let me check our readiness for handoff...").
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
