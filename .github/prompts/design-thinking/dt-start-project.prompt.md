---
description: 'Start a new Design Thinking coaching project with state initialization and first coaching interaction'
agent: DT Coach
argument-hint: "[project-name=...] [context=...] [stakeholders=...] [industry=...]"
---

# Start Design Thinking Project

## Inputs

* ${input:project-name}: (Optional) Human-readable project name. When omitted, derive a concise name from the supplied context or ask what the user would like to call the project.
* ${input:project-slug}: (Optional) Preformatted project identifier for automation or advanced use.
* ${input:context}: (Optional) Initial project context, problem statement, or customer request to capture.
* ${input:stakeholders}: (Optional) Known stakeholder groups or key contacts to include in initial mapping.
* ${input:industry}: (Optional) Industry or domain context (e.g., manufacturing, healthcare, finance) to inform coaching vocabulary and constraint patterns.

## Requirements

* All DT coaching artifacts are scoped to `.copilot-tracking/dt/{project-slug}/`. Never write DT artifacts directly under `.copilot-tracking/dt/` without a project-slug directory.
* When `${input:project-slug}` is omitted, normalize the project name to a kebab-case identifier internally. Do not ask the user to provide a slug, kebab-case value, or specially formatted folder name.

---

Start the Design Thinking coaching project by initializing the state directory and beginning Method 1 coaching.
