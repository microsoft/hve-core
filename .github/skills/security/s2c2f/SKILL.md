---
name: s2c2f
description: OSSF Secure Supply Chain Consumption Framework (S2C2F) v2024 practices encoded as machine-readable per-control YAML for the SSSC Planner agent - Brought to you by microsoft/hve-core.
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "OpenSSF Secure Supply Chain Consumption Framework working group"
  spec_version: "1.0"
  framework_revision: "2024.06"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://github.com/ossf/s2c2f"
---

# OSSF® S2C2F — Skill Entry

This `SKILL.md` is the **entrypoint** for the Secure Supply Chain Consumption Framework
(S2C2F) Framework Skill.

The skill encodes the **OSSF S2C2F v2024** practice catalog across the seven practice groups
(Ingest, Inventory, Update, Audit, Enforce, Rebuild, Fix Upstream) as structured,
machine-readable Framework Skills that the SSSC Planner agent loads during the
`standards-mapping`, `gap-analysis`, and `backlog-generation` phases. It is not user-invocable;
it serves as a data contract consumed by planner orchestration.

## Consumer contract

The Framework Skill is designed for the SSSC Planner extensibility refactor. Consumers:

1. Read [`index.yml`](index.yml) to discover which controls participate in each planner phase.
2. Resolve each control ID listed under `phaseMap.<phase>` to its per-control YAML file under
   [`controls/`](controls/).
3. Validate each control file against
   [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../../scripts/linting/schemas/planner-framework-control.schema.json).
4. Treat all gates as `pending` until evidence is collected and a phase outcome is recorded.

Each control file declares one S2C2F practice with its risk tier, assessment categories, phase
gates, and evidence hint globs. `evidenceHints` are deterministic file or glob references;
runtime evidence collection is the consumer's responsibility.

S2C2F practices are organized by group prefix:

* `ing-*` — Ingest: how OSS enters the build pipeline.
* `inv-*` — Inventory: tracking what OSS is in use.
* `upd-*` — Update: keeping OSS current and patched.
* `aud-*` — Audit: verifying OSS provenance and integrity.
* `enf-*` — Enforce: gating consumption to approved sources.
* `reb-*` — Rebuild: producing internally-built OSS artifacts.
* `fix-*` — Fix Upstream: contributing fixes back to maintainers.

Maturity level mapping (ML1–ML4) is preserved in each control's `description`. The Framework Skill
schema does not encode maturity directly; consumers that need maturity filtering should layer
that view in the planner orchestrator.

## Skill layout

* `SKILL.md` — this file (skill entrypoint and consumer contract).
* [`index.yml`](index.yml) — phase-to-control roll-up consumed by the planner orchestrator.
* [`controls/`](controls/) — one YAML file per S2C2F practice, each validating against the
  planner framework control schema.

## Third-Party Attribution

Copyright © OpenSSF S2C2F working group.
S2C2F practice identifiers, requirement text, and group taxonomy are derived from the OSSF
Secure Supply Chain Consumption Framework, licensed under CC BY 4.0
(<https://creativecommons.org/licenses/by/4.0/>).
Source: <https://github.com/ossf/s2c2f>
Modifications: Practice metadata restructured into per-control YAML Framework Skill items aligned with the
SSSC Planner framework control schema; phase gates, evidence hint globs, categorical
assessment vocabulary, and Framework Skill indexing added.
OpenSSF® is a registered trademark of the Linux Foundation. Use does not imply endorsement.

---
