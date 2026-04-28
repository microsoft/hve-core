---
name: rai-control-surface
description: "RAI control surface taxonomy mapping each NIST trustworthiness characteristic to preventive, detective, and corrective control types for the RAI Planner Phase 5 Impact Assessment - Brought to you by microsoft/hve-core."
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

# RAI Control Surface — Skill Entry

This `SKILL.md` is the entrypoint for the **RAI Control Surface** Framework Skill consumed by the RAI Planner agent during Phase 5 Impact Assessment.

## Consumer contract

1. Read [`index.yml`](index.yml) for the 21 control-surface ids participating in `phase-5-impact-assessment`.
2. Resolve each id to its per-item YAML under [`items/`](items/) and validate against [`scripts/linting/schemas/planner-framework-criterion.schema.json`](../../../../scripts/linting/schemas/planner-framework-criterion.schema.json).
3. Use the `characteristic` and `controlType` fields together to position each candidate control in the 7×3 matrix.

## Taxonomy

7 NIST trustworthiness characteristics × 3 control types (preventive, detective, corrective) = 21 control surface cells. Item id pattern: `cs-<char-abbrev>-<controlType>`.

| Abbrev | Characteristic           |
|--------|--------------------------|
| vr     | validReliable            |
| safe   | safe                     |
| sr     | secureResilient          |
| at     | accountableTransparent   |
| ei     | explainableInterpretable |
| priv   | privacyEnhanced          |
| fair   | fairBiasManaged          |

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up listing all 21 ids.
* [`items/`](items/) — one criterion YAML per control-surface cell.

---
