---
name: rai-output-formats
description: "RAI Planner output-format library: 12 document-section templates covering risk classification, standards mapping, security-model tables, impact-assessment artifacts, and Phase 6 dual-format backlog handoff - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "2026.04"
  last_updated: "2026-04-23"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: ".github/instructions/rai-planning/"
---

# RAI Output Formats — Skill Entry

This `SKILL.md` is the entrypoint for the **RAI Output Formats** Framework Skill consumed by the RAI Planner agent across phases 2 through 6 to render structured artifacts.

## Consumer contract

1. Read [`index.yml`](index.yml) for the 12 section ids and their `phaseMap` placement.
2. Resolve each id to its per-item YAML under [`items/`](items/) and validate against [`scripts/linting/schemas/planner-framework-document-section.schema.json`](../../../../scripts/linting/schemas/planner-framework-document-section.schema.json).
3. Use the `template` body and `tokens` list to render each section; the host agent supplies token values at render time.

## Section inventory

* Phase 2 Risk Classification: `of-risk-classification-screening`.
* Phase 3 Standards Mapping: `of-characteristic-coverage-table`.
* Phase 4 Security Model: `of-extended-threat-table`, `of-stride-matrix-table`.
* Phase 5 Impact Assessment: `of-principle-tracker-table`, `of-tradeoff-table`, `of-evidence-register-table`.
* Phase 6 Handoff: `of-review-rubric`, `of-rai-review-summary`, `of-ado-work-item-template`, `of-github-issue-template`, `of-handoff-summary`.

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up across phases 2–6.
* [`items/`](items/) — one document-section YAML per output format.

---
