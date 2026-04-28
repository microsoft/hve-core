---
description: "Extend a Security Planner assessment with sustainability coverage using the Sustainability Planner agent"
agent: sustainability-planner
---

# Sustainability from Security Plan

Activate the Sustainability Planner in **from-security-plan mode** to extend an existing Security Planner assessment with sustainability coverage.

## Inputs

* ${input:project-slug}: (Optional) Project slug for the sustainability plan directory. When omitted, derive from the discovered security plan project name.

## Requirements

### Security Plan Discovery

Scan these directories as the primary discovery path:

* `.copilot-tracking/security-plans/` for Security Planner artifacts

Look for existing `state.json` files within subdirectories. If multiple security plans exist, present all candidates to the user for selection.

### Initialization

* Render the `## Sustainability Planning` `[!CAUTION]` disclaimer block from `.github/instructions/shared/disclaimer-language.instructions.md` verbatim on the first user-facing turn before any other output, then set `state.disclaimerShownAt` and `state.meta.disclaimerVersion`.
* Create the project directory at `.copilot-tracking/sustainability-plans/{project-slug}/` and write `state.json` with `entryMode: "from-security-plan"`, `currentPhase: "1.scoping"`, and `securityPlannerLink` set to the path of the source security plan.
* Read the Security Planner's `state.json` and completed artifacts to extract: declared operational buckets, deployment targets, technology stack, regional/jurisdictional context, and any sustainability-adjacent findings (resource sizing, scaling posture, ML usage).
* Map the security plan's operational buckets to the sustainability surface taxonomy and pre-fill `state.surfaces[]` using the following rules:
  * Cloud-Infrastructure or Backend-Services bucket only → `cloud-only`.
  * Web-Application or Frontend bucket only → `web-only`.
  * AI/ML or Model-Serving bucket only → `ml-only`.
  * Edge-Devices, IoT, or Fleet bucket only → `fleet-only`.
  * Two or more of the above bucket categories present → `mixed`.
  * Record each surface entry's `provenance` as the source bucket id(s) from the security plan.
* Pre-populate remaining Phase 1 scoping fields (workload characteristics, declared sustainability budgets, disclosure obligations) with any inferable information and ask 3-5 confirmation questions to verify the surface mapping and capture sustainability-specific details the security plan does not cover (energy/carbon budgets, ESG commitments, fleet device counts, ML training footprint).

## Entry Behavior

Start sustainability planning from Security Planner artifacts. Discover security plan files, extract operational buckets and cross-domain context, initialize the project directory with `state.surfaces[]` pre-filled from the bucket → surface mapping, and begin Phase 1 with pre-populated scoping data enriched by existing security findings.
