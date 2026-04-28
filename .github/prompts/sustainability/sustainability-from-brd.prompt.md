---
description: "Start a sustainability assessment from existing BRD artifacts using the Sustainability Planner agent"
agent: sustainability-planner
---

# Sustainability from BRD

Activate the Sustainability Planner in **from-brd mode** to bootstrap a sustainability assessment from existing business requirements documents.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the sustainability plan directory. When omitted, derive from the discovered BRD project name.

## Requirements

### BRD Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/brd-sessions/` for business requirements documents

If the primary path yields no matches, perform a secondary scan of `.copilot-tracking/` for files whose names match `brd-*.md`, `*-brd.md`, or `business-requirements*.md`. Exclude generic matches like `requirements.txt` or files outside business-scoping contexts.

Present all discovery results to the user for confirmation before proceeding.

### Initialization

* Render the `## Sustainability Planning` `[!CAUTION]` disclaimer block from `.github/instructions/shared/disclaimer-language.instructions.md` verbatim on the first user-facing turn before any other output, then set `state.disclaimerShownAt` and `state.meta.disclaimerVersion`.
* Create the project directory at `.copilot-tracking/sustainability-plans/{project-slug}/` and write `state.json` with `entryMode: "from-brd"`, `currentPhase: "1.scoping"`, and remaining fields populated from BRD context.
* Extract business sustainability outcomes and constraints from the BRD — including ESG commitments, net-zero or carbon-reduction targets, disclosure obligations (CSRD/ESRS, SEC climate, GHG Protocol, TCFD, ISO 14064/14067), regional or jurisdictional commitments, supplier or customer sustainability requirements, and budget or cost-of-carbon constraints — and pre-fill `state.context.businessOutcomes` with one entry per outcome, recording the source BRD section in each entry's `provenance` field.
* Pre-populate Phase 1 scoping fields (surfaces, workload characteristics, declared sustainability budgets) with any inferable information and ask 3-5 confirmation questions to verify accuracy and fill technical-detail gaps the BRD does not cover.

## Entry Behavior

Start sustainability planning from BRD artifacts. Discover BRD files, extract business sustainability outcomes and constraints, initialize the project directory with pre-filled `context.businessOutcomes`, and begin Phase 1 with pre-populated scoping data.
