---
description: NTIA SBOM minimum elements, format options, generators, and distribution guidance
---

# NTIA SBOM Minimum Elements

Assess SBOM generation and distribution against NTIA SBOM minimum elements:

* Format: SPDX-JSON (preferred for GitHub ecosystem) or CycloneDX
* Generator: anchore/sbom-action with syft, or Microsoft SBOM Tool
* Distribution: Attached to release artifacts, published to dependency graph
* NTIA SBOM minimum elements: Supplier, component name, version, unique identifier, dependency relationship, author, timestamp

Verify NTIA SBOM minimum element compliance for existing SBOM output.

## Attribution

SPDX content derived from the SPDX specification, licensed under Community Specification License 1.0. Source: <https://spdx.dev/>

CycloneDX content derived from the CycloneDX specification, licensed under Apache 2.0. Source: <https://cyclonedx.org/>

NTIA Minimum Elements content is derived from a U.S. government publication. Not subject to copyright (17 U.S.C. section 105).
