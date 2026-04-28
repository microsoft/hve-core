---
name: rai-threat-catalog
description: "RAI threat catalog covering 8 AI element types and 6 trust boundaries with the AI-extended ML STRIDE matrix and dual T-RAI/T-{BUCKET}-AI threat ID convention for the RAI Planner Phase 4 Security Model - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "2026.04"
  last_updated: "2026-04-23"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: ".github/instructions/rai-planning/rai-security-model.instructions.md"
---

# RAI Threat Catalog — Skill Entry

This `SKILL.md` is the entrypoint for the **RAI Threat Catalog** Framework Skill consumed by the RAI Planner agent during Phase 4 Security Model.

## Consumer contract

1. Read [`index.yml`](index.yml) for the 14 catalog ids participating in `phase-4-security-model` plus the `globals.dataFlows` and `globals.strideMatrix` payloads.
2. Resolve each id to its per-item YAML under [`items/`](items/) and validate against [`scripts/linting/schemas/planner-framework-criterion.schema.json`](../../../../scripts/linting/schemas/planner-framework-criterion.schema.json).
3. Use the catalog to seed the extended threat table; assign each emitted threat a `T-RAI-{NNN}` id and, when a Security Planner bucket overlaps, a parallel `T-{BUCKET}-AI-{NNN}` id.

## Catalog scope

* 8 AI element types (`tc-elem-*`): training data store, model artifact, inference endpoint, feature pipeline, feedback loop, human review queue, monitoring dashboard, orchestration layer.
* 6 AI trust boundaries (`tc-bound-*`): training data, model, inference, feedback, human oversight, human-review-to-automated-decision (accountability boundary).
* `globals.dataFlows`: training pipeline, inference pipeline, feedback loop with RAI-relevant stages and threat concentration points.
* `globals.strideMatrix`: 8 components × 6 STRIDE columns with `applicability` (High/Medium/Low/N/A) and `nistCharacteristic` annotation per cell.

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up, dual-ID convention notes, dataFlows and strideMatrix globals.
* [`items/`](items/) — one criterion YAML per element or boundary.

---
