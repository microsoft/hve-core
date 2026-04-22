---
name: sbom
description: Software Bill of Materials (SBOM) Framework Skill covering SPDX 2.3 and CycloneDX 1.5 conformance, generation pipelines, and ingestion controls for the SSSC Planner agent - Brought to you by microsoft/hve-core.
license: CC-BY-4.0
user-invocable: false
metadata:
  authors: "SPDX Workgroup (Linux Foundation) and CycloneDX project (OWASP)"
  spec_version: "1.0"
  framework_revision: "1.0"
  last_updated: "2026-04-17"
  skill_based_on: "https://github.com/chris-buckley/agnostic-prompt-standard"
  content_based_on: "https://spdx.dev/ + https://cyclonedx.org/specification/overview/"
---

# SBOM — Skill Entry

This `SKILL.md` is the **entrypoint** for the SBOM framework skill.

The skill encodes Software Bill of Materials format conformance, generation, and ingestion
controls as machine-readable per-control YAML items consumed by the SSSC Planner during the
`standards-mapping`, `gap-analysis`, and `backlog-generation` phases.

## SBOM Standards (verbatim from `sssc-standards.instructions.md`)

Assess SBOM generation and distribution:

* **Format**: SPDX-JSON (preferred for GitHub ecosystem) or CycloneDX
* **Generator**: anchore/sbom-action with syft, or Microsoft SBOM Tool
* **Distribution**: Attached to release artifacts, published to dependency graph
* **NTIA minimum elements**: Supplier, component name, version, unique identifier, dependency relationship, author, timestamp

Verify NTIA minimum element compliance for existing SBOM output.

## Controls

Each control is a separate YAML item under `controls/` and validates against
`scripts/linting/schemas/planner-framework-control.schema.json`. All controls use a
categorical assessment with the ladder `absent → partial → present → verified` and
declare gates across four maturity dimensions: `presence`, `signing`, `distribution`,
`vuln-mapping`.

| Control id        | Title                                          | Risk   |
|-------------------|------------------------------------------------|--------|
| `spdx-2.3`        | SPDX 2.3 format conformance                    | medium |
| `cyclonedx-1.5`   | CycloneDX 1.5 format conformance               | medium |
| `sbom-generation` | SBOM generation pipeline (when, how, signing)  | medium |
| `sbom-ingestion`  | SBOM ingestion, verification, vuln correlation | medium |

## Phase Mapping

`index.yml` maps each control to the SSSC Planner phases that consume it. The planner
loads only the controls listed for the active phase.

## Skill Layout

* `SKILL.md` — this file (skill entrypoint).
* `index.yml` — framework roll-up with `framework`, `version`, and `phaseMap`.
* `controls/` — per-control items.
  * `spdx-2.3.yml` — SPDX 2.3 format conformance.
  * `cyclonedx-1.5.yml` — CycloneDX 1.5 format conformance.
  * `sbom-generation.yml` — Generation pipeline (when, how, signing).
  * `sbom-ingestion.yml` — Ingestion, verification, vulnerability correlation.

## Third-Party Attribution

Copyright © Linux Foundation (SPDX) and OWASP Foundation (CycloneDX).

SPDX 2.3 specification content is derived from the SPDX project, with specification text
published under the Community Specification License 1.0 and documentation under
CC-BY-3.0. Source: <https://spdx.dev/> and
<https://spdx.github.io/spdx-spec/v2.3/>. SPDX® is a registered trademark of the Linux
Foundation.

CycloneDX 1.5 specification content is derived from the CycloneDX project, licensed under
Apache 2.0 (<https://www.apache.org/licenses/LICENSE-2.0>).
Source: <https://cyclonedx.org/specification/overview/>. CycloneDX is an OWASP Foundation
project.

NTIA Minimum Elements content is derived from a U.S. government publication and is not
subject to copyright (17 U.S.C. § 105).
Source: <https://www.ntia.gov/page/software-bill-materials>.

Modifications: SBOM standards guidance restructured into per-control YAML items aligned
with the SSSC Planner framework control schema; phase gates, evidence hint globs, and
Framework Skill indexing added. The "SBOM Standards" block above is reproduced verbatim from
`.github/instructions/security/sssc-standards.instructions.md`.

Use of upstream marks does not imply endorsement.

---
