---
description: 'Start a new Design Thinking coaching project with state initialization and first coaching interaction'
agent: DT Coach
argument-hint: "project-slug=... [context=...] [stakeholders=...] [industry=...]"
---

# Start Design Thinking Project

## Inputs

* ${input:project-slug}: (Required) Short folder name for the project, using lowercase words separated by hyphens (e.g., `factory-floor-maintenance`).
* ${input:context}: (Optional) Initial project context, problem statement, or customer request to capture.
* ${input:stakeholders}: (Optional) Known stakeholder groups or key contacts to include in initial mapping.
* ${input:industry}: (Optional) Industry or domain context (e.g., manufacturing, healthcare, finance) to inform coaching vocabulary and constraint patterns.

## Requirements

* If the folder name is missing, ask in plain language: "What short folder name would you like for this project? Use lowercase words separated by hyphens, for example `factory-floor-maintenance`." Adapt the example to the user's project context when available. Avoid "slug" and "kebab-case" in user-facing questions. Wait for the user's answer before creating project files; if a valid folder name was already supplied, use it without asking again.
* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

---

Start the Design Thinking coaching project by initializing the state directory and beginning Method 1 coaching.
