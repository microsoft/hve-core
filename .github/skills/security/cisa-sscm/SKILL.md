---
name: cisa-sscm
description: CISA Securing the Software Supply Chain Recommended Practices Framework Skill providing Acquire, Develop, and Deliver lifecycle controls as machine-readable per-control YAML for the SSSC Planner agent - Brought to you by microsoft/hve-core.
license: Public-Domain
user-invocable: false
metadata:
  authors: "CISA, NSA, and ODNI Enduring Security Framework (ESF) working group"
  spec_version: "1.0"
  framework_revision: "2022.08"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://www.cisa.gov/resources-tools/resources/securing-software-supply-chain-recommended-practices-guide-developers"
---

# CISA Securing the Software Supply Chain — Skill Entry

This `SKILL.md` is the **entrypoint** for the CISA "Securing the Software Supply Chain" (SSCM) Framework Skill.

The skill encodes CISA's Recommended Practices for the software supply chain lifecycle (Acquire, Develop, Deliver) as structured, machine-readable Framework Skills that the SSSC Planner agent loads during the `standards-mapping`, `gap-analysis`, and `backlog-generation` phases. It is not user-invocable; it serves as a data contract consumed by planner orchestration.

## Consumer contract

The Framework Skill is designed for the SSSC Planner extensibility refactor. Consumers:

1. Read [`index.yml`](index.yml) to discover which controls participate in each planner phase and which CISA lifecycle phase each control belongs to.
2. Resolve each control ID listed under `phaseMap.<phase>` to its per-control YAML file under [`items/`](items/).
3. Validate each control file against [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../../scripts/linting/schemas/planner-framework-control.schema.json).
4. Treat all gates as `pending` until evidence is collected and a phase outcome is recorded.

Each control file declares one CISA SSCM practice with its risk tier, categorical assessment scale (`absent`, `partial`, `present`, `verified`), planner phase gates, and evidence hint globs. `evidenceHints` are deterministic file or glob references; runtime evidence collection is the consumer's responsibility.

## Lifecycle phases

CISA organizes the practices across three lifecycle phases, reflected by the `acquire-`, `develop-`, and `deliver-` control ID prefixes:

* **Acquire** — Practices governing supplier selection, attestation intake, and component provenance verification.
* **Develop** — Practices governing secure design, threat modeling, hardened builds, and source integrity.
* **Deliver** — Practices governing artifact signing, secure distribution, vulnerability disclosure, and SBOM publication.

The `index.yml` `phaseMap` keys remain the planner orchestration phases (`standards-mapping`, `gap-analysis`, `backlog-generation`); the CISA lifecycle phase for each control is encoded in the control ID prefix and in the control's `group` field.

## Skill layout

* `SKILL.md` — this file (skill entrypoint and consumer contract).
* [`index.yml`](index.yml) — phase-to-control roll-up consumed by the planner orchestrator.
* [`items/`](items/) — one YAML file per CISA SSCM practice, each validating against the planner framework control schema.

## Third-Party Attribution

CISA "Securing the Software Supply Chain — Recommended Practices Guide for Developers" is a US Government work produced jointly by the Cybersecurity and Infrastructure Security Agency (CISA), the National Security Agency (NSA), and the Office of the Director of National Intelligence (ODNI) under the Enduring Security Framework (ESF). US Government works are not subject to copyright protection in the United States and are placed in the public domain.
Source: <https://www.cisa.gov/resources-tools/resources/securing-software-supply-chain-recommended-practices-guide-developers>
Modifications: Recommended Practice text restructured into per-control YAML Framework Skill items aligned with the SSSC Planner framework control schema; categorical assessment scale, planner phase gates, and evidence hint globs added.

---
