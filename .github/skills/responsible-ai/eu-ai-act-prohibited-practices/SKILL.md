---
name: eu-ai-act-prohibited-practices
description: "EU AI Act (Regulation (EU) 2024/1689) Article 5 prohibited AI practices encoded as paraphrased per-principle YAML for the RAI Planner agent's Phase 2 Prohibited Uses Gate - Brought to you by microsoft/hve-core."
license: Apache-2.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  framework_revision: "2024.06"
  last_updated: "2026-04-23"
  skill_based_on: ".github/skills/shared/framework-skill-interface/SKILL.md"
  content_based_on: "https://eur-lex.europa.eu/eli/reg/2024/1689/oj"
---

# EU AI Act — Prohibited Practices — Skill Entry

This `SKILL.md` is the entrypoint for the **EU AI Act Prohibited Practices** Framework Skill consumed by the RAI Planner agent during Phase 2 (Risk Classification) as a seed `prohibited-use-framework`. It encodes the eight prohibited AI practices set out in Article 5(1) of Regulation (EU) 2024/1689 of the European Parliament and of the Council of 13 June 2024 laying down harmonised rules on artificial intelligence (Artificial Intelligence Act).

## Consumer contract

1. Read [`index.yml`](index.yml) to enumerate the eight prohibited-practice items grouped under `phaseMap.phase-2-risk-classification`.
2. Resolve each item id (`eu-aia-pp-1` … `eu-aia-pp-8`) to its per-item YAML under [`items/`](items/).
3. Validate each per-item file against [`scripts/linting/schemas/planner-framework-principle.schema.json`](../../../../scripts/linting/schemas/planner-framework-principle.schema.json) via the FSI dispatch `responsible-ai:principle`.
4. Use the `articleRef` and `prohibitionType` fields to render Phase 2 Prohibited Uses Gate output blocks. When any prohibition matches the proposed system, the agent halts the planning workflow per the gate's existing precedence rules.

## Phase coverage

* `phase-2-risk-classification` — All eight prohibited practices (`eu-aia-pp-1` … `eu-aia-pp-8`) consulted by the Prohibited Uses Gate before any other classification logic.

## Skill layout

* `SKILL.md` — this file.
* [`index.yml`](index.yml) — phaseMap roll-up for the RAI Planner.
* [`items/`](items/) — eight principle YAMLs, one per Article 5(1) prohibited practice (mapped (a)–(h) → 1–8).
* [`references/eu-ai-act-article-5.md`](references/eu-ai-act-article-5.md) — paraphrased overview of Article 5 with citation to the official EUR-Lex source.

## License and attribution

This skill is licensed Apache-2.0 for the authored paraphrases, structure, and metadata. The underlying legal text — Regulation (EU) 2024/1689 — is an act of the European Union published on EUR-Lex; reuse of EU institutional documents follows the European Commission's reuse policy. To preserve a license-conservative posture, **no verbatim text from the regulation is reproduced** in this skill; item `summary` and `body` fields are paraphrases authored by the skill maintainers, and each item carries a `references[]` link back to the official EUR-Lex source for direct consultation.

Authoritative source: [Regulation (EU) 2024/1689 — EUR-Lex](https://eur-lex.europa.eu/eli/reg/2024/1689/oj).

---
