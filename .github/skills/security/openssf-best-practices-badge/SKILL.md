---
name: openssf-best-practices-badge
description: OpenSSF Best Practices Badge tier criteria (Passing, Silver, Gold) as machine-readable framework controls for SSSC planner standards mapping, gap analysis, and backlog generation - Brought to you by microsoft/hve-core.
license: CC-BY-3.0
user-invocable: false
metadata:
  authors: "OpenSSF Best Practices Badge Working Group"
  spec_version: "1.0"
  framework_revision: "1.0"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://www.bestpractices.dev/criteria"
---

# OpenSSF Best Practices Badge — Skill Entry

This `SKILL.md` is the **entrypoint** for the OpenSSF Best Practices Badge framework skill.

The skill encodes the **OpenSSF Best Practices Badge** tier criteria (Passing, Silver, Gold) as
structured, schema-validated Framework Skill items consumable by the SSSC Planner across the
`standards-mapping`, `gap-analysis`, and `backlog-generation` phases.

## Framework index

* [index.yml](index.yml) — framework identifier, version, and phase-to-tier map.

## Control items

1. [items/passing.yml](items/passing.yml) — Passing tier (basic hygiene; 67 criteria).
2. [items/silver.yml](items/silver.yml) — Silver tier (governance and quality).
3. [items/gold.yml](items/gold.yml) — Gold tier (advanced security).

## Skill layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — framework metadata and phase-to-control mapping.
* `items/` — per-tier control items validated by `scripts/linting/schemas/planner-framework-control.schema.json`.

## Tier Detection Protocol (mandatory before scoring any tier control)

The current badge tier is **not** encoded in the markdown badge URL in `README.md`; it is rendered dynamically into the SVG and exposed via a JSON endpoint. Static markdown inspection cannot determine the tier. Before scoring `passing`, `silver`, or `gold` as anything other than `verified`, the planner runs all three of the following checks (the third is the controlling source of truth):

1. **Grep `README.md` for the project id.** Locate any URL matching `bestpractices.dev/projects/<id>` or `bestpractices.dev/projects/<id>/badge`. Capture `<id>`.
2. **Grep `CHANGELOG.md` for tier campaigns.** Search for `OSSF`, `OpenSSF`, `bestpractices`, `passing`, `silver`, `gold`. Each PR explicitly tagged `for Passing`, `for Silver`, or `for Gold` is positive evidence of a deliberate tier-advancement campaign and counts toward the converging-evidence rule (see [`sssc-assessment.instructions.md`](../../../instructions/security/sssc-assessment.instructions.md) Evidence Exhaustion Rule item 6).
3. **Fetch the live tier endpoint.** Issue a GET to `https://www.bestpractices.dev/projects/<id>/badge` (or the JSON endpoint `https://www.bestpractices.dev/projects/<id>.json`, field `badge_level`) and record the returned level (`in_progress`, `passing`, `silver`, `gold`) in the inputs log. The returned level is the controlling source of truth for tier verdicts. Score every tier at or below the returned level as `verified` for the tier-attainment criterion.

Tier criteria *within* a tier (governance docs, signed releases, reproducible builds, etc.) are still scored individually against the criteria in `items/<tier>.yml` even when the live endpoint reports the tier as attained; the live endpoint confirms attestation, not per-criterion granularity.

## Third-Party Attribution

OpenSSF Best Practices Badge criteria derived from the CII Best Practices Badge project,
licensed under MIT (criteria) and CC BY 3.0+ (documentation).
Source: <https://www.bestpractices.dev/criteria>
Modifications: Tier criteria restructured into agent-consumable YAML Framework Skill items
for SSSC Planner phases.
OpenSSF® is a registered trademark of the Linux Foundation. Use does not imply endorsement.

---
