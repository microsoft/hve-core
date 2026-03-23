---
description: "Phase 2 supply chain assessment protocol with the 27 combined capabilities inventory for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 2 — Supply Chain Assessment

Assess the target repository's current supply chain security posture against the combined capabilities inventory from hve-core and physical-ai-toolchain.

## 27 Combined Capabilities Inventory

### hve-core Unique (6)

| # | Capability                           | Implementation                                                                              |
|---|--------------------------------------|---------------------------------------------------------------------------------------------|
| 1 | pip-audit                            | pip-audit.yml reusable workflow for Python dependency vulnerability scanning                |
| 2 | Action version consistency           | Test-ActionVersionConsistency.ps1 validates all workflow references use consistent versions |
| 3 | Automated SHA pinning updates        | Update-ActionSHAPinning.ps1 automates SHA pin refresh when actions publish new versions     |
| 4 | Consolidated weekly security summary | Aggregated reporting across all security scan results                                       |
| 5 | Get-VerifiedDownload.ps1             | Verified download utility with SHA-256 hash validation for external tool acquisition        |
| 6 | Security workflow orchestration      | Coordinated execution of multiple security scans with unified reporting                     |

### physical-ai-toolchain Unique (10)

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

### Shared (11)

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

Ask the user to confirm or correct assessment findings in batches of 5-7 capabilities per turn.

## Output

Write the assessment to `.copilot-tracking/sssc-plans/{project-slug}/supply-chain-assessment.md`.

Structure the output as:

```markdown
# Supply Chain Assessment — {project-slug}

## Summary
- Covered: {count}/27
- Partial: {count}/27
- Gap: {count}/27
- N/A: {count}/27

## Detailed Assessment

### hve-core Unique Capabilities
{per-capability assessment}

### physical-ai-toolchain Unique Capabilities
{per-capability assessment}

### Shared Capabilities
{per-capability assessment}
```

Update `state.json`:
* Set `phases.2-assessment.status` to `✅`
* Add `supply-chain-assessment.md` to `phases.2-assessment.artifacts`
* Advance `currentPhase` to `3`
