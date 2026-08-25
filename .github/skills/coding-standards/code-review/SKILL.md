---
name: code-review
description: Review code changes from multiple perspectives with context bootstrap, depth-tier rigor, and structured findings output.
license: MIT
user-invocable: true
metadata:
  authors: "microsoft/hve-core"
  spec_version: "1.0"
  last_updated: "2026-08-25"
---

# Code Review Skill Entry

This `SKILL.md` is the entrypoint for the Code Review skill.

The skill provides a reusable review workflow for pull requests, branch diffs, and local changes across functional, standards, accessibility, security, and readiness perspectives. It separates the review target and profile from perspective and depth selection, and centralizes change-brief preparation, severity normalization, and output contracts so review agents stay thin and consistent.

## Shared principles

Review work should stay anchored in evidence and should avoid premature conclusions. Keep the review grounded in file and line evidence, use proportional depth based on risk, read the full diff range before narrowing, and keep factual orientation separate from structured findings.

## Normative references

1. [Output Formats](references/output-formats.md): reporting structure, merged report skeleton, and persisted artifact contract.
2. [Severity Taxonomy](references/severity-taxonomy.md): severity levels, verdict normalization, and risk classification.
3. [Lens Checklists](references/lens-checklists.md): perspective-specific review questions for functional, standards, accessibility, security, and readiness reviews.
4. [Context Bootstrap](references/context-bootstrap.md): Tier 0 procedure for proving the change surface, drafting a change brief, and scoping hotspots.
5. [Depth Tiers](references/depth-tiers.md): basic, standard, and comprehensive verification rigor dials.
6. [Walkthrough Protocol](references/walkthrough-protocol.md): firm orientation floor, full-diff reading contract, and Register 1 narrative guidance.
7. [Dispatch Loop](references/dispatch-loop.md): human-steered dispatch board, manifest schema, and walk-back loop contract.
8. [Emission Modes](references/emission-modes.md): capability-gated dual-mode emission and persisted emission record.
9. [Cross-Skill Forks](references/cross-skill-forks.md): specialist review registry and package-aware gating for follow-up reviews.
10. [Review Targets and Profiles](references/review-targets.md): target resolution, profile expansion, task serialization, and emission identity.

## Skill layout

* `SKILL.md`: this file (skill entrypoint).
* `references/`: durable review knowledge documents.
  * `output-formats.md`: output schema, report skeleton, and persistence behavior.
  * `severity-taxonomy.md`: severity and verdict normalization model.
  * `lens-checklists.md`: per-perspective review checklists.
  * `context-bootstrap.md`: Tier 0 context bootstrap and human-scoping workflow.
  * `depth-tiers.md`: Tier 1/2/3 verification-depth guidance.
  * `walkthrough-protocol.md`: orientation-first walkthrough contract and Register 1 narrative expectations.
  * `dispatch-loop.md`: dispatch board, manifest schema, and walk-back loop.
  * `emission-modes.md`: native and canonical emission strategies.
  * `cross-skill-forks.md`: specialist review registry and gating rules.
  * `review-targets.md`: review target, profile, and task-state rules.
