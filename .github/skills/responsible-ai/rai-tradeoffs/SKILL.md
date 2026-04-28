---
name: rai-tradeoffs
description: "Documented Responsible AI characteristic tradeoffs (privacy/accuracy, explainability/accuracy, fairness/accuracy, safety/accuracy, accountability/security) consumed by the RAI Planner Phase 5 Impact Assessment - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "2026.04"
  last_updated: "2026-04-23"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: ".github/instructions/rai-planning/rai-impact-assessment.instructions.md"
---

# RAI Tradeoffs — Skill Entry

This `SKILL.md` is the entrypoint for the **RAI Tradeoffs** Framework Skill consumed by the RAI Planner agent during Phase 5 Impact Assessment.

## Consumer contract

1. Read [`index.yml`](index.yml) to enumerate the five tradeoffs participating in `phase-5-impact-assessment`.
2. Resolve each tradeoff id under `phaseMap.phase-5-impact-assessment` to its per-item YAML under [`items/`](items/).
3. Validate each per-item file against [`scripts/linting/schemas/planner-framework-criterion.schema.json`](../../../../scripts/linting/schemas/planner-framework-criterion.schema.json) via the FSI dispatch `responsible-ai:criterion`.
4. Use the `characteristics[]` array on each item to identify the two competing NIST trustworthiness characteristics.

## Tradeoff inventory

* `to-001` — Privacy-Enhanced ↔ Valid and Reliable.
* `to-002` — Explainable and Interpretable ↔ Valid and Reliable.
* `to-003` — Fair with Harmful Bias Managed ↔ Valid and Reliable.
* `to-004` — Safe ↔ Valid and Reliable.
* `to-005` — Accountable and Transparent ↔ Secure and Resilient.

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up for the RAI Planner.
* [`items/`](items/) — one criterion YAML per documented tradeoff.

---
