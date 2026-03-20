---
description: "Start a new SSSC assessment via guided conversation using the SSSC Planner agent in capture mode"
agent: sssc-planner
---

# SSSC Capture

## Inputs

* ${input:project-slug}: (Optional) Kebab-case project identifier for the artifact directory. When omitted, asks for a suitable project name and derives the slug.

## Requirements

* Initialize capture mode by creating the project directory at `.copilot-tracking/sssc-plans/{project-slug}/` and writing `state.json` with `entryMode: "capture"`, `currentPhase: 1`, and empty or default values for remaining fields.
* If the user provides existing supply chain security notes, workflow inventories, or documentation as input, extract relevant information and pre-populate Phase 1 fields before asking clarifying questions.
* Begin the Phase 1 interview about the project's supply chain security posture with 3-5 focused questions covering: project name and purpose, technology stack, package managers, CI/CD platform, release strategy, and known compliance targets (OpenSSF Scorecard, SLSA, Best Practices Badge).

## Entry Behavior

Start supply chain security planning in capture mode. Initialize the project directory and begin the Phase 1 scoping interview.
