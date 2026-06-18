---
name: rai-planner
description: "On-demand RAI planner reference pack for Phase 1 capture, Phase 2 risk classification, Phase 5 impact assessment, and Phase 6 review and backlog handoff. Read the matching reference when entering a phase boundary or when you need the detailed guidance for that phase."
license: MIT
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-17"
---

# RAI Planner

## Overview

Use this skill as an on-demand reference pack for the RAI Planner. The main skill body stays compact, and the detailed phase guidance lives in the reference files under this folder so the agent can load only the material needed for the current phase.

## Phase Reference Index

* Phase 1 — Capture and scoping: [capture-coaching.md](references/capture-coaching.md) — read this when entering Phase 1 and again during capture turns when you need the exploration-first questioning techniques.
* Phase 2 — Risk classification: [risk-classification.md](references/risk-classification.md) — read this when entering Phase 2 to apply the prohibited-use gate, indicator assessment, and depth-tier logic.
* Phase 5 — Impact assessment: [impact-assessment.md](references/impact-assessment.md) — read this when entering Phase 5 to build the evidence register, tradeoff log, and work-item seeds.
* Phase 6 — Review rubric and backlog handoff: [backlog-handoff.md](references/backlog-handoff.md) — read this when entering Phase 6 to run the review rubric and generate the final handoff summary.

## Usage Notes

* Load these references on demand at phase boundaries rather than as fixed startup context.
* Use the referenced file that matches the phase you are about to enter or the section you need to re-open during execution.
* Keep the detailed rubric, templates, and evidence guidance in the reference files rather than in the main skill body.
