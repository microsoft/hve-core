---
description: 'Start a new Design Thinking coaching project with state initialization and first coaching interaction - Brought to you by microsoft/hve-core'
agent: DT Coach
argument-hint: "project-slug=... [context=...] [stakeholders=...] [industry=...]"
---

# Start Design Thinking Project

## Inputs

* ${input:project-slug}: (Required) Kebab-case project identifier for the artifact directory (e.g., `factory-floor-maintenance`).
* ${input:context}: (Optional) Initial project context, problem statement, or customer request to capture.
* ${input:stakeholders}: (Optional) Known stakeholder groups or key contacts to include in initial mapping.
* ${input:industry}: (Optional) Industry or domain context (e.g., manufacturing, healthcare, finance) to inform coaching vocabulary and constraint patterns.

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.

---

Start the Design Thinking coaching project by initializing the state directory and beginning Method 1 coaching.
