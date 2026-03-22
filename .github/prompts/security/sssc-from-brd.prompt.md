---
description: "Start an SSSC assessment from existing BRD artifacts using the SSSC Planner agent"
agent: sssc-planner
---

# SSSC from BRD

Activate the SSSC Planner in **from-brd mode** to bootstrap a supply chain security assessment from existing business requirements documents.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the SSSC plan directory. When omitted, derive from the discovered BRD project name.

## Requirements

### BRD Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/brd-sessions/` for business requirements documents

If the primary path yields no matches, perform a secondary scan of `.copilot-tracking/` for files whose names match `brd-*.md`, `*-brd.md`, or `business-requirements*.md`. Exclude generic matches like `requirements.txt` or files outside business-scoping contexts.

Present all discovery results to the user for confirmation before proceeding.

### Initialization

* Create the project directory at `.copilot-tracking/sssc-plans/{project-slug}/` and write `state.json` with `entryMode: "from-brd"`, `currentPhase: 1`, and remaining fields populated from BRD context.
* Extract technology stack, compliance requirements, integration points, and deployment targets from the BRD.
* Pre-populate Phase 1 scoping fields with extracted information and ask 3-5 confirmation questions to verify accuracy and fill gaps.

## Entry Behavior

Start supply chain security planning from BRD artifacts. Discover BRD files, extract context, initialize the project directory, and begin Phase 1 with pre-populated scoping data.
