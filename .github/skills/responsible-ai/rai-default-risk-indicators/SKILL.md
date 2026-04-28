---
name: rai-default-risk-indicators
description: "Default Responsible AI risk indicators (safety/reliability, rights/fairness/privacy, security/explainability) used by the RAI Planner Phase 2 Risk Classification screen - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "2026.04"
  last_updated: "2026-04-23"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: ".github/instructions/rai-planning/rai-risk-classification.instructions.md"
---

# RAI Default Risk Indicators — Skill Entry

This `SKILL.md` is the entrypoint for the **RAI Default Risk Indicators** Framework Skill consumed by the RAI Planner agent during Phase 2 Risk Classification.

## Consumer contract

1. Read [`index.yml`](index.yml) to enumerate the three default indicators participating in `phase-2-risk-classification`.
2. Resolve each indicator id under `phaseMap.phase-2-risk-classification` to its per-item YAML under [`items/`](items/).
3. Validate each per-item file against [`scripts/linting/schemas/planner-framework-criterion.schema.json`](../../../../scripts/linting/schemas/planner-framework-criterion.schema.json) via the FSI dispatch `responsible-ai:criterion`.
4. Score each indicator using its declared `indicatorType` (binary, categorical, or continuous) and apply the activation rules in `summary`/`description`.

## Indicator inventory

* `safety-reliability` — binary indicator covering physical/operational harm potential.
* `rights-fairness-privacy` — categorical indicator (none/indirect/direct/primary) for rights, fairness, and privacy impact.
* `security-explainability` — continuous indicator (0.0–1.0 mean of attack surface, data sensitivity, decision explainability gap).

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up for the RAI Planner.
* [`items/`](items/) — one criterion YAML per default risk indicator.

---
