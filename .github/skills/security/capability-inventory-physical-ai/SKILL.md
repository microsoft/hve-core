---
name: capability-inventory-physical-ai
description: physical-ai-toolchain capability inventory (physical-ai-toolchain (10 native + 11 shared)) for the SSSC Planner agent — per-capability YAML items consumed during assessment, gap-analysis, and backlog-generation phases - Brought to you by microsoft/hve-core.
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "microsoft/hve-core SSSC Planner contributors"
  spec_version: "1.0"
  framework_revision: "1.0"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: ".github/instructions/security/sssc-assessment.instructions.md"
---

# physical-ai-toolchain Capability Inventory — Skill Entry

This `SKILL.md` is the **entrypoint** for the `capability-inventory-physical-ai` capability inventory skill.

The skill encodes the physical-ai-toolchain (10 native + 11 shared) portion of the SSSC Planner's capability inventory
(originally embedded as prose tables in `sssc-assessment.instructions.md`) as
machine-readable per-capability YAML items consumed by the planner during the
`assessment`, `gap-analysis`, and `backlog-generation` phases.

## Capability Source

Capability rows in this skill are extracted **verbatim** from
`.github/instructions/security/sssc-assessment.instructions.md`. Each capability
becomes one `controls/<capability-id>.yml` item that validates against
`scripts/linting/schemas/planner-framework-control.schema.json`.

## Controls

Each capability uses a categorical assessment with the ladder
`absent → partial → present → verified` and declares two phase gates
(`presence` for assessment, `verification` for gap-analysis). Capabilities
optionally declare `mapsTo` cross-framework links (Scorecard checks, SLSA
levels, SBOM/Sigstore controls) so the planner can collapse duplicate
evidence requests across frameworks.

| Group  | Count |
|--------|-------|
| native | 10    |
| shared | 11    |
| total  | 21    |

## Phase Mapping

`index.yml` maps each capability to the SSSC Planner phases that consume it.
The planner loads only the capabilities listed for the active phase.

## Skill Layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — capability roll-up with `framework`, `version`, and `phaseMap`.
* `controls/` — per-capability items (one YAML file per capability).
