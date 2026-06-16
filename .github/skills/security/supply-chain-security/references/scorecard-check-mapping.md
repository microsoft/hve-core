---
description: Full 20-check Scorecard reference mapping with hve-core and physical-ai-toolchain implementations, default adoption types, default efforts, and gap prioritization rules
---

# Full 20-Check Reference Mapping

This file is the crosswalk home between the 20 OpenSSF Scorecard checks and the 27 combined capabilities defined in [capabilities-inventory.md](capabilities-inventory.md). The 20 Scorecard checks are one standard catalog; the inventory additionally covers capabilities sourced from SLSA build levels ([slsa-levels.md](slsa-levels.md)), the OpenSSF Best Practices Badge ([best-practices-badge.md](best-practices-badge.md)), Sigstore/cosign maturity ([sigstore-maturity.md](sigstore-maturity.md)), and NTIA SBOM minimum elements ([sbom-elements.md](sbom-elements.md)). The two sets overlap conceptually but are not a strict subset of one another.

Use this reference table when mapping gaps. It provides the known implementation sources for each Scorecard check:

| #  | Scorecard Check        | Risk     | hve-core Implementation                                 | PAT Implementation               | Default Adoption Type | Default Effort |
|----|------------------------|----------|---------------------------------------------------------|----------------------------------|-----------------------|----------------|
| 1  | Binary-Artifacts       | High     | No binaries (convention)                                | Same                             | Platform config       | S              |
| 2  | Branch-Protection      | High     | CODEOWNERS, PR process                                  | Same                             | Platform config       | S              |
| 3  | CI-Tests               | Low      | pr-validation.yml                                       | ci.yml                           | Reusable workflow     | M              |
| 4  | CII-Best-Practices     | Low      | GOVERNANCE.md targets Silver                            | GOVERNANCE.md                    | Platform config       | M              |
| 5  | Code-Review            | High     | CODEOWNERS enforcement                                  | CODEOWNERS                       | Platform config       | S              |
| 6  | Contributors           | Low      | Multi-contributor                                       | Same                             | N/A (organic)         | —              |
| 7  | Dangerous-Workflow     | Critical | Clean patterns; CodeQL                                  | Same                             | Script adoption       | S              |
| 8  | Dependency-Update-Tool | High     | dependabot.yml                                          | dependabot.yml (12 ecosystems)   | Workflow copy/modify  | S              |
| 9  | Fuzzing                | Medium   | ❌ Gap                                                   | ❌ Gap                            | New capability        | L              |
| 10 | License                | Low      | LICENSE (MIT)                                           | LICENSE                          | Platform config       | S              |
| 11 | Maintained             | High     | Active dev                                              | Active dev                       | N/A (organic)         | —              |
| 12 | Packaging              | Medium   | VS Code extension                                       | Same                             | N/A (existing)        | —              |
| 13 | Pinned-Dependencies    | Medium   | Test-DependencyPinning.ps1, dependency-pinning-scan.yml | SHA-pinned actions               | Workflow + script     | M              |
| 14 | SAST                   | Medium   | CodeQL, PSScriptAnalyzer, ruff                          | CodeQL, ruff                     | Reusable workflow     | M              |
| 15 | SBOM                   | Medium   | anchore/sbom-action                                     | anchore/sbom-action, dual attest | Workflow copy/modify  | M              |
| 16 | Security-Policy        | Medium   | SECURITY.md (MSRC)                                      | SECURITY.md                      | Platform config       | S              |
| 17 | Signed-Releases        | High     | attest-build-provenance, Sigstore                       | gitsign + dual attest            | Workflow copy/modify  | L              |
| 18 | Token-Permissions      | High     | Test-WorkflowPermissions.ps1                            | Minimal perms                    | Workflow + script     | M              |
| 19 | Vulnerabilities        | High     | dependency-review.yml, pip-audit.yml                    | Same + Dependabot enrichment     | Reusable workflow     | M              |
| 20 | Webhooks               | Critical | Platform-managed                                        | Platform-managed                 | Platform config       | S              |

Adjust adoption type and effort based on the target repository's actual technology stack and existing tooling.

## Gap Prioritization

Within the gap table, sort entries by:

1. Scorecard risk level: Critical > High > Medium > Low
2. Within the same risk level: checks with available reusable workflows before those requiring new capabilities
3. Within the same adoption type: lower effort before higher effort
