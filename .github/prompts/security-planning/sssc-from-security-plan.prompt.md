---
description: "Extend a Security Planner assessment with supply chain coverage using the SSSC Planner agent"
agent: sssc-planner
---

# SSSC from Security Plan

Activate the SSSC Planner in **from-security-plan mode** to extend an existing Security Planner assessment with supply chain security coverage.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered security plan project name.

## Requirements

### Security Plan Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/security-plans/` for Security Planner artifacts

Look for existing `state.json` files within subdirectories. If multiple security plans exist, present all candidates to the user for selection.

### Initialization

* Create the project directory at `.copilot-tracking/sssc-plans/{project-slug}/` and write `state.json` with `entryMode: "from-security-plan"`, `currentPhase: 1`, and `securityPlannerLink` set to the path of the source security plan.
* Read the Security Planner's `state.json` and completed artifacts to extract: technology stack, deployment targets, compliance requirements, threat model findings, and identified security controls.
* Map Security Planner findings to supply chain context: application-level threats inform dependency and build pipeline priorities.
* Pre-populate Phase 1 scoping fields with extracted information and ask 3-5 confirmation questions to verify accuracy and identify supply-chain-specific details not covered by the security plan (package managers, CI/CD pipeline details, release strategy).

## Entry Behavior

Start supply chain security planning from Security Planner artifacts. Discover security plan files, extract cross-domain context, initialize the project directory, and begin Phase 1 with pre-populated scoping data enriched by existing security findings.
