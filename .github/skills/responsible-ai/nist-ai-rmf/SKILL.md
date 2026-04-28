---
name: nist-ai-rmf
description: "NIST AI Risk Management Framework 1.0 (NIST.AI.100-1) core functions and 72 subcategories as machine-readable per-item YAML for the RAI Planner agent's Phase 1-6 standards mapping - Brought to you by microsoft/hve-core."
license: Public-Domain
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "2026.04"
  last_updated: "2026-04-23"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: ".github/instructions/rai-planning/rai-standards.instructions.md"
---

# NIST AI RMF 1.0 — Skill Entry

This `SKILL.md` is the entrypoint for the **NIST AI Risk Management Framework 1.0** Framework Skill consumed by the RAI Planner agent across all six phases as the default active framework.

## Consumer contract

1. Read [`index.yml`](index.yml) to enumerate the 72 subcategories grouped by RAI Planner phase under `phaseMap`.
2. Resolve each subcategory id under any `phaseMap.phase-N-*` entry to its per-item YAML under [`items/`](items/).
3. Validate each per-item file against [`scripts/linting/schemas/planner-framework-criterion.schema.json`](../../../../scripts/linting/schemas/planner-framework-criterion.schema.json) via the FSI dispatch `responsible-ai:criterion`.
4. Use the `function` (govern|map|measure|manage), `group` (parent category), and `nistSubcategories[]` fields on each item to render Phase 3 standards-mapping output blocks.

## Phase coverage

* `phase-1-scoping` — Map function (MP-1 through MP-5 leaf subcategories).
* `phase-2-risk-classification` — Govern subset (GV-1.1-1.3, GV-3, GV-5).
* `phase-3-standards-mapping` — Remaining Govern (GV-1.4-1.7, GV-2, GV-4, GV-6) plus Measure methods (MS-1).
* `phase-4-security-model` — Measure trustworthiness evaluation (MS-2).
* `phase-5-impact-assessment` — Measure tracking (MS-3, MS-4) and Manage (MN-1, MN-2, MN-4.1-4.2).
* `phase-6-handoff` — Manage third-party (MN-3) and incident communication (MN-4.3).

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up for the RAI Planner.
* [`items/`](items/) — 72 criterion YAMLs, one per NIST AI RMF leaf subcategory.

## License and attribution

NIST AI RMF 1.0 (NIST.AI.100-1, January 2023) is a U.S. Government work in the public domain (17 U.S.C. § 105). Authors paraphrase subcategory descriptions in `summary` fields rather than reproducing source text verbatim.

---
