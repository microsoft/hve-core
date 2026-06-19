---
name: code-review
description: Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.
license: MIT
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-06-18"
---

# Code Review — Skill Entry

This `SKILL.md` is the entrypoint for the Code Review skill.

The skill provides a reusable review workflow for orchestrators and perspective subagents that evaluate code changes across functional, standards, accessibility, PR, security, and full review perspectives. It centralizes change-brief preparation, review depth selection, severity normalization, and output contract details so that review agents stay thin and consistent.

## Normative references

1. [Output Formats](references/output-formats.md) — reporting structure, merged report skeleton, and persisted artifact contract.
2. [Severity Taxonomy](references/severity-taxonomy.md) — severity levels, verdict normalization, and risk classification.
3. [Lens Checklists](references/lens-checklists.md) — perspective-specific review questions for functional, standards, accessibility, PR, and security reviews.
4. [Context Bootstrap](references/context-bootstrap.md) — Tier 0 procedure for proving the change surface, drafting a change brief, and scoping hotspots.
5. [Depth Tiers](references/depth-tiers.md) — basic, standard, and comprehensive verification rigor dials.

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `references/` — durable review knowledge documents.
  * `output-formats.md` — output schema, report skeleton, and persistence behavior.
  * `severity-taxonomy.md` — severity and verdict normalization model.
  * `lens-checklists.md` — per-perspective review checklists.
  * `context-bootstrap.md` — Tier 0 context bootstrap and human-scoping workflow.
  * `depth-tiers.md` — Tier 1/2/3 verification-depth guidance.
