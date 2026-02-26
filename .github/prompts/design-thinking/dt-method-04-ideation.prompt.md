---
description: 'Divergent ideation for Design Thinking Method 4b with constraint-informed solution generation - Brought to you by microsoft/hve-core'
agent: dt-coach
argument-hint: "project-slug=... [constraintContext=...] [divergentTarget=...]"
---

# Method 4: Brainstorming - Ideation

## Inputs

* ${input:project-slug}: (Required) Kebab-case project identifier for the artifact directory (e.g., `factory-floor-maintenance`).
* ${input:constraintContext}: (Optional) Environmental, workflow, or technical constraints to inform ideation.
* ${input:divergentTarget}: (Optional) Number of ideas to generate before convergence (default: 15).

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

---

Invoke Design Thinking coaching for Method 4b (Ideation Execution) to facilitate divergent idea generation with constraint-informed creativity.
