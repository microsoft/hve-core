---
description: "Initiate security planning from existing notes or knowledge using the Security Planner agent in capture mode"
agent: security-planner
---

# Security Capture

## Inputs

* ${input:project-slug}: (Optional) Kebab-case project identifier for the artifact directory. When omitted, asks for a suitable project name and derives the slug.

## Requirements

* Initialize capture mode by creating the project directory at `.copilot-tracking/security-plans/{project-slug}/` and writing `state.json` with `entryMode: "capture"`, `currentPhase: 1`, and empty or default values for remaining fields.
* If the user provides existing security notes, threat assessments, or documentation as input, extract relevant information and pre-populate Phase 1 fields before asking clarifying questions.
* Begin the Phase 1 interview about the project's security posture with 3-5 focused questions covering: project name and purpose, technology stack, deployment target (cloud, on-prem, hybrid), types of data processed or stored, and known compliance requirements.

## Entry Behavior

Start security planning in capture mode. Initialize the project directory and begin the Phase 1 scoping interview.
