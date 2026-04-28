---
name: nist-ssdf
description: NIST Secure Software Development Framework (SP 800-218 v1.1) practices and tasks as machine-readable Framework Skill items for the SSSC Planner agent - Brought to you by microsoft/hve-core.
license: Public-Domain
user-invocable: false
metadata:
  authors: "U.S. National Institute of Standards and Technology (NIST)"
  spec_version: "1.0"
  framework_revision: "SP 800-218 v1.1"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://csrc.nist.gov/pubs/sp/800/218/final"
---

# NIST Secure Software Development Framework — Skill Entry

This `SKILL.md` is the **entrypoint** for the NIST SSDF Framework Skill.

The skill encodes a curated subset of **NIST SP 800-218 v1.1** practices and tasks as
structured, machine-readable Framework Skill items that the SSSC Planner agent loads during the
`standards-mapping`, `gap-analysis`, and `backlog-generation` phases. It is not user-invocable;
it serves as a data contract consumed by planner orchestration.

## Consumer contract

The Framework Skill is designed for the SSSC Planner extensibility refactor. Consumers:

1. Read [`index.yml`](index.yml) to discover which controls participate in each planner phase.
2. Resolve each control ID listed under `phaseMap.<phase>` to its per-control YAML file under
   [`items/`](items/).
3. Validate each control file against
   [`scripts/linting/schemas/planner-framework-control.schema.json`](../../../../scripts/linting/schemas/planner-framework-control.schema.json).
4. Treat all gates as `pending` until evidence is collected and a phase outcome is recorded.

Each control file declares one SSDF task with its practice group (`PO`, `PS`, `PW`, `RV`),
risk tier, categorical assessment scale, phase gates, and evidence hint globs. `evidenceHints`
are deterministic file or glob references; runtime evidence collection is the consumer's
responsibility.

## Practice groups

* **PO — Prepare the Organization** — define security requirements, roles, supporting tools, and
  software development lifecycle policies before building software.
* **PS — Protect the Software** — protect all components of source, build, and release
  artifacts from tampering and unauthorized access.
* **PW — Produce Well-Secured Software** — design, review, test, and configure software so it
  has minimal vulnerabilities at release.
* **RV — Respond to Vulnerabilities** — identify residual vulnerabilities in released software
  and respond appropriately to remediate them and prevent recurrence.

## Skill layout

* `SKILL.md` — this file (skill entrypoint and consumer contract).
* [`index.yml`](index.yml) — phase-to-control roll-up consumed by the planner orchestrator.
* [`items/`](items/) — one YAML file per SSDF task, each validating against the planner
  framework control schema.

## Third-Party Attribution

NIST SP 800-218 *Secure Software Development Framework (SSDF) Version 1.1: Recommendations for
Mitigating the Risk of Software Vulnerabilities* is a work of the U.S. Government and is in the
public domain in the United States.
Source: <https://csrc.nist.gov/pubs/sp/800/218/final>
Modifications: SSDF practice and task metadata restructured into per-control YAML items
aligned with the SSSC Planner framework control schema; phase gates, evidence hint globs, and
Framework Skill indexing added.

---
