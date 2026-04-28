---
description: "Start a sustainability assessment from existing PRD artifacts using the Sustainability Planner agent"
agent: sustainability-planner
---

# Sustainability from PRD

Activate the Sustainability Planner in **from-prd mode** to bootstrap a sustainability assessment from existing product requirements documents.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the sustainability plan directory. When omitted, derive from the discovered PRD project name.

## Requirements

### PRD Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/prd-sessions/` for product requirements documents

If the primary path yields no matches, perform a secondary scan of `.copilot-tracking/` for files whose names match `prd-*.md`, `*-prd.md`, or `product-definition*.md`. Exclude generic matches like `requirements.txt` or files outside product-scoping contexts.

Present all discovery results to the user for confirmation before proceeding.

### Initialization

* Render the `## Sustainability Planning` `[!CAUTION]` disclaimer block from `.github/instructions/shared/disclaimer-language.instructions.md` verbatim on the first user-facing turn before any other output, then set `state.disclaimerShownAt` and `state.meta.disclaimerVersion`.
* Create the project directory at `.copilot-tracking/sustainability-plans/{project-slug}/` and write `state.json` with `entryMode: "from-prd"`, `currentPhase: "1.scoping"`, and remaining fields populated from PRD context.
* Extract non-functional sustainability and performance requirements from the PRD — including workload type, traffic profile, scaling posture, fleet/device footprint, ML training and inference scope, latency and throughput targets, energy or carbon budgets, and regional deployment constraints — and pre-fill `state.workloadAssessment.capabilities[]` with one entry per identified capability, recording the source PRD section in each entry's `provenance` field.
* Pre-populate Phase 1 scoping fields (surfaces, workload characteristics, declared sustainability budgets, disclosure obligations) with extracted information and ask 3-5 confirmation questions to verify accuracy and fill gaps.

## Entry Behavior

Start sustainability planning from PRD artifacts. Discover PRD files, extract sustainability and performance non-functional requirements, initialize the project directory with pre-filled `workloadAssessment.capabilities[]`, and begin Phase 1 with pre-populated scoping data.
