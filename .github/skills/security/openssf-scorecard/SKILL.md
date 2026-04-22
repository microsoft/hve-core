---
name: openssf-scorecard
description: OpenSSF Scorecard Framework Skill providing the 20 supply-chain security checks as machine-readable per-control YAML for the SSSC Planner agent - Brought to you by microsoft/hve-core.
license: Apache-2.0
user-invocable: false
metadata:
  authors: "OpenSSF Scorecard project contributors"
  spec_version: "1.0"
  framework_revision: "v5"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://github.com/ossf/scorecard"
---

# OpenSSF® Scorecard — Skill Entry

This `SKILL.md` is the **entrypoint** for the OpenSSF Scorecard Framework Skill.

The skill encodes the **OpenSSF Scorecard v5** check catalog as structured, machine-readable
Framework Skill items that the SSSC Planner agent loads during the `standards-mapping`,
`gap-analysis`, and `backlog-generation` phases. It is not user-invocable; it serves as a data
contract consumed by planner orchestration.

## Consumer contract

The Framework Skill is designed for the SSSC Planner extensibility refactor. Consumers:

1. Read [`index.yml`](index.yml) to discover which controls participate in each planner phase.
2. Resolve each control ID listed under `phaseMap.<phase>` to its per-control YAML file under
   [`controls/`](controls/).
3. Validate each control file against
   [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../../scripts/linting/schemas/planner-framework-control.schema.json).
4. Treat all gates as `pending` until evidence is collected and a phase outcome is recorded.

Each control file declares one Scorecard check with its risk tier, score range, phase gates, and
evidence hint globs. `evidenceHints` are deterministic file or glob references; runtime evidence
collection is the consumer's responsibility.

## Skill layout

* `SKILL.md` — this file (skill entrypoint and consumer contract).
* [`index.yml`](index.yml) — phase-to-control roll-up consumed by the planner orchestrator.
* [`controls/`](controls/) — one YAML file per Scorecard check, each validating against the
  planner framework control schema.

## Third-Party Attribution

Copyright © OpenSSF Scorecard project contributors.
OpenSSF® Scorecard check data, names, risk classifications, and score ranges are derived from
the OpenSSF Scorecard project, licensed under Apache 2.0
(<https://www.apache.org/licenses/LICENSE-2.0>).
Source: <https://github.com/ossf/scorecard>
Modifications: Check metadata restructured into per-control YAML items aligned with the SSSC
Planner framework control schema; phase gates, evidence hint globs, and Framework Skill indexing added.
OpenSSF® is a registered trademark of the Linux Foundation. Use does not imply endorsement.

---
