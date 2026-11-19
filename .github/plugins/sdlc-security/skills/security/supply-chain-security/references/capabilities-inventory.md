---
description: The 27 combined supply chain capabilities across hve-core unique, physical-ai-toolchain unique, and shared sets, with the detect/classify/document/verify assessment protocol
---

# 27 Combined Capabilities Inventory

Assess a target repository's supply chain security posture against the combined capabilities inventory from hve-core and physical-ai-toolchain.

> **Scope:** This file defines the full set of 27 combined capabilities. They are a distinct taxonomy from the 20 OpenSSF Scorecard checks, which are a separate standard catalog with substantial conceptual overlap (the inventory treats the whole Scorecard scan as a single capability, #22). For the per-check crosswalk between the 20 Scorecard checks and these capabilities, see [scorecard-check-mapping.md](scorecard-check-mapping.md). The inventory also draws on capabilities sourced from SLSA build levels, the OpenSSF Best Practices Badge, Sigstore (cosign), and NTIA SBOM minimum elements — see their respective reference files for those standards.

## hve-core Unique (6)

| # | Capability                           | Implementation                                                                              |
|---|--------------------------------------|---------------------------------------------------------------------------------------------|
| 1 | pip-audit                            | pip-audit.yml reusable workflow for Python dependency vulnerability scanning                |
| 2 | Action version consistency           | Test-ActionVersionConsistency.ps1 validates all workflow references use consistent versions |
| 3 | Automated SHA pinning updates        | Update-ActionSHAPinning.ps1 automates SHA pin refresh when actions publish new versions     |
| 4 | Consolidated weekly security summary | Aggregated reporting across all security scan results                                       |
| 5 | Get-VerifiedDownload.ps1             | Verified download utility with SHA-256 hash validation for external tool acquisition        |
| 6 | Security workflow orchestration      | Coordinated execution of multiple security scans with unified reporting                     |

**Critical incident prompt:** Recall the most recent near-miss or incident in this repository involving an unpinned or stale GitHub Action, an unverified external tool download, or a Python dependency CVE — which of the controls in this batch would have detected or prevented it, and which gap let it through?

## physical-ai-toolchain Unique (10)

| #  | Capability                            | Implementation                                                                               |
|----|---------------------------------------|----------------------------------------------------------------------------------------------|
| 7  | SBOM generation                       | anchore/sbom-action producing SPDX-JSON output per release                                   |
| 8  | Sigstore signing                      | gitsign-based keyless signing for release tags and commits                                   |
| 9  | DAST/ZAP                              | Dynamic application security testing via OWASP ZAP                                           |
| 10 | Dual attestation                      | Build provenance and SBOM attestation via actions/attest-build-provenance and actions/attest |
| 11 | Stale docs → issue                    | Automated issue creation when documentation drifts from code                                 |
| 12 | OpenSSF Best Practices badge          | Badge enrollment and criteria tracking in GOVERNANCE.md                                      |
| 13 | Dependabot security prefix enrichment | Auto-retitle security Dependabot PRs with `security(deps):` prefix using GHSA/CVSS metadata  |
| 14 | Comprehensive threat model            | Structured threat model document with STRIDE analysis                                        |
| 15 | release-please pipeline               | Automated release management with conventional commits                                       |
| 16 | Vulnerability SLA                     | Defined service-level agreements for vulnerability remediation timelines                     |

**Critical incident prompt:** Describe the most recent time a downstream consumer, auditor, or release reviewer questioned a release's provenance, signature, SBOM contents, threat model coverage, or vulnerability-remediation timeline — which of the controls in this batch would have provided sufficient evidence or shortened the response?

## Shared (11)

| #  | Capability           | Implementation                                                           |
|----|----------------------|--------------------------------------------------------------------------|
| 17 | Dependency pinning   | dependency-pinning-scan.yml with Test-DependencyPinning.ps1              |
| 18 | SHA staleness        | SHA staleness checks validating pinned action references are current     |
| 19 | gitleaks             | Secret scanning via gitleaks in CI pipelines                             |
| 20 | CodeQL               | GitHub Code Scanning with CodeQL for SAST                                |
| 21 | Dependency review    | dependency-review.yml for PR-time dependency change analysis             |
| 22 | OpenSSF Scorecard    | Scorecard scanning for supply chain security posture                     |
| 23 | Workflow permissions | Test-WorkflowPermissions.ps1 enforcing least-privilege token permissions |
| 24 | Copyright headers    | Automated copyright header validation across source files                |
| 25 | Dependabot           | Dependabot configuration for automated dependency updates                |
| 26 | SECURITY.md          | Security policy document with vulnerability reporting process            |
| 27 | CODEOWNERS           | Code ownership enforcement for required reviews                          |

**Critical incident prompt:** Recall the most recent leaked secret, unreviewed dependency change, over-privileged workflow token, CodeQL finding, or unpatched CVE that affected this repository — which of the controls in this batch caught it, would have caught it, or shortened the time to remediate?

## Assessment Protocol

For each of the 27 capabilities, evaluate the target repository:

1. **Detect**: Search the repository for evidence of the capability (workflow files, scripts, configuration, documentation).
2. **Classify**: Assign a coverage status:
   * ✅ **Covered** — capability is implemented and active
   * ⚠️ **Partial** — capability exists but is incomplete or misconfigured
   * ❌ **Gap** — capability is absent
   * ➖ **N/A** — capability does not apply to this repository's technology stack
3. **Document**: Record evidence (file paths, workflow names, configuration details) for each assessment.
4. **Verify**: For ✅ and ⚠️ items, confirm the implementation matches the reference patterns from hve-core or physical-ai-toolchain.
