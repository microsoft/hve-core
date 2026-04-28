---
description: "Start a new sustainability assessment via guided conversation using the Sustainability Planner agent in capture mode"
agent: sustainability-planner
---

# Sustainability Capture

## Inputs

* ${input:project-slug}: (Optional) Kebab-case project identifier for the artifact directory. When omitted, asks for a suitable project name and derives the slug.

## Requirements

* Render the `## Sustainability Planning` `[!CAUTION]` disclaimer block from `.github/instructions/shared/disclaimer-language.instructions.md` verbatim on the first user-facing turn before any other output, then set `state.disclaimerShownAt` and `state.meta.disclaimerVersion`.
* Initialize capture mode by creating the project directory at `.copilot-tracking/sustainability-plans/{project-slug}/` and writing `state.json` with `entryMode: "capture"`, `currentPhase: "1.scoping"`, and empty or default values for remaining fields (including empty `surfaces[]`, empty `workloadAssessment.capabilities[]`, and empty `context.businessOutcomes`).
* If the user provides existing sustainability notes, carbon/energy reports, workload inventories, or architecture documentation as input, extract relevant information and pre-populate Phase 1 fields before asking clarifying questions.
* Begin the Phase 1 workload-scoping interview with 3-5 focused questions covering: project name and purpose, deployment surfaces (cloud-only, web-only, ml-only, fleet-only, mixed), workload characteristics (traffic profile, always-on vs. autoscale, fleet size, ML training/inference footprint), declared sustainability budgets or SCI targets, and known disclosure obligations (CSRD/ESRS, SEC climate, GHG Protocol, TCFD).

## Entry Behavior

Start sustainability planning in capture mode. Initialize the project directory and begin the Phase 1 workload-scoping interview.
