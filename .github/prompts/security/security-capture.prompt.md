---
description: "Start security planning from existing notes using the Security Planner agent (capture mode)"
agent: Security Planner
---

# Security Capture

## Startup

Display the Security Planning CAUTION block from #file:../../instructions/shared/disclaimer-language.instructions.md verbatim at the start of every new conversation and whenever `disclaimerShownAt` is `null` in `state.json`, before any questions or analysis. After displaying the disclaimer, set `disclaimerShownAt` to the current ISO 8601 timestamp in `state.json`.

After the disclaimer, display the framework attribution `OWASP ASVS • OWASP Top 10 • NIST SSDF`. Display both the disclaimer and the attribution before any questions or analysis.

## Inputs

* ${input:project-slug}: (Optional) Kebab-case project identifier for the artifact directory. When omitted, asks for a suitable project name and derives the slug.

## Requirements

* Initialize capture mode by creating the project directory at `.copilot-tracking/security-plans/{project-slug}/` and writing `state.json` with `entryMode: "capture"`, `currentPhase: 1`, and empty or default values for remaining fields.
* If the user provides existing security notes, threat assessments, or documentation as input, extract relevant information and pre-populate Phase 1 fields before asking clarifying questions.
* Begin the Phase 1 interview about the project's security posture with 3-5 focused questions covering: project name and purpose, technology stack, deployment target (cloud, on-prem, hybrid), types of data processed or stored, and known compliance requirements.

## Entry Behavior

Start security planning in capture mode. Initialize the project directory and begin the Phase 1 scoping interview.
