---
description: "Start an SSSC assessment from existing PRD artifacts using the SSSC Planner agent"
agent: sssc-planner
---

# SSSC from PRD

Activate the SSSC Planner in **from-prd mode** to bootstrap a supply chain security assessment from existing product definition artifacts.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered PRD project name.

## Requirements

### PRD Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/prd-sessions/` for product requirements documents

If the primary path yields no matches, perform a secondary scan of `.copilot-tracking/` for files whose names match `prd-*.md`, `*-prd.md`, or `product-definition*.md`. Exclude generic matches like `requirements.txt` or files outside product-scoping contexts.

Present all discovery results to the user for confirmation before proceeding.

### Initialization

* Create the project directory at `.copilot-tracking/sssc-plans/{project-slug}/` and write `state.json` with `entryMode: "from-prd"`, `currentPhase: 1`, and remaining fields populated from PRD context.
* Extract technology stack, package managers, CI/CD platform, deployment targets, and integration points from the PRD.
* Pre-populate Phase 1 scoping fields with extracted information and ask 3-5 confirmation questions to verify accuracy and fill gaps.

## Entry Behavior

Start supply chain security planning from PRD artifacts. Discover PRD files, extract context, initialize the project directory, and begin Phase 1 with pre-populated scoping data.
