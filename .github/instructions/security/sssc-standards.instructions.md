---
description: "Phase 3 OpenSSF Scorecard, SLSA v1.0, OpenSSF Best Practices Badge, Sigstore (cosign), and NTIA SBOM minimum elements standards mapping for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 3: Standards Mapping

Map the assessed supply chain posture against the open standards anchored below: OpenSSF Scorecard, SLSA v1.0, OpenSSF Best Practices Badge, Sigstore (cosign), and NTIA SBOM minimum elements. Use the Phase 2 assessment results as input.

## OpenSSF Scorecard: 20 Checks

Map each Scorecard check to the repository's current implementation and identify the available workflow or script from hve-core or physical-ai-toolchain.

| #  | Check                  | Risk     | Score Range    | Agent Mapping                                                                   |
|----|------------------------|----------|----------------|---------------------------------------------------------------------------------|
| 1  | Binary-Artifacts       | High     | 0–10           | Scan for committed binaries; recommend removal                                  |
| 2  | Branch-Protection      | High     | 0–10 (5 tiers) | Verify branch rules, required reviews, status checks                            |
| 3  | CI-Tests               | Low      | 0–10           | Map to CI workflow; verify test execution on PRs                                |
| 4  | CII-Best-Practices     | Low      | 0–10           | Check for GOVERNANCE.md, Badge enrollment                                       |
| 5  | Code-Review            | High     | 0–10           | Verify CODEOWNERS and required PR reviews                                       |
| 6  | Contributors           | Low      | 0–10           | Count unique contributors (informational)                                       |
| 7  | Dangerous-Workflow     | Critical | 0/10           | Audit for `pull_request_target` with checkout, `workflow_run`, untrusted inputs |
| 8  | Dependency-Update-Tool | High     | 0/10           | Check for dependabot.yml or Renovate config                                     |
| 9  | Fuzzing                | Medium   | 0/10           | Check for fuzzing config (OSS-Fuzz, ClusterFuzzLite)                            |
| 10 | License                | Low      | 0/10           | Verify LICENSE file with SPDX-compatible identifier                             |
| 11 | Maintained             | High     | 0–10           | Evaluate recent commit activity and issue response                              |
| 12 | Packaging              | Medium   | 0/10           | Verify published packages via GitHub                                            |
| 13 | Pinned-Dependencies    | Medium   | 0–10           | Scan for SHA-pinned actions and locked package files                            |
| 14 | SAST                   | Medium   | 0–10           | Check for CodeQL, Semgrep, or other SAST tools in CI                            |
| 15 | SBOM                   | Medium   | 0–10           | Check for SBOM generation workflow (SPDX or CycloneDX)                          |
| 16 | Security-Policy        | Medium   | 0/10           | Verify SECURITY.md exists with reporting process                                |
| 17 | Signed-Releases        | High     | 0–10           | Check for Sigstore attestations or GPG signatures                               |
| 18 | Token-Permissions      | High     | 0–10           | Audit workflow permissions for least-privilege                                  |
| 19 | Vulnerabilities        | High     | 0–10           | Check for dependency review, Dependabot alerts, pip-audit                       |
| 20 | Webhooks               | Critical | 0/10           | Verify webhook authentication and secret configuration                          |

For each check, record:

* **Current score** (estimated 0–10 or binary 0/10)
* **Evidence** (file paths, workflow names, configuration details)
* **Available implementation** (which hve-core or PAT workflow/script addresses this check)
* **Gap** (what is missing to achieve maximum score)

## SLSA v1.0 Build Track Levels

Assess the repository against SLSA v1.0 Build track requirements:

| Level    | Requirements                                      | Assessment Criteria                                         |
|----------|---------------------------------------------------|-------------------------------------------------------------|
| Build L0 | No requirements                                   | Baseline, all repositories start here                       |
| Build L1 | Provenance exists and is distributed to consumers | Check for `actions/attest-build-provenance` or equivalent   |
| Build L2 | Hosted build platform, signed provenance          | Verify GitHub Actions (hosted), Sigstore provenance signing |
| Build L3 | Build runs in isolation, signing key isolation    | Verify ephemeral runners, ephemeral Sigstore keys (OIDC)    |

Record current level and specific steps needed to reach the next level.

## OpenSSF Best Practices Badge Criteria

Assess readiness against OpenSSF Best Practices Badge tiers:

| Level   | Focus                       | Key Criteria                                                                      |
|---------|-----------------------------|-----------------------------------------------------------------------------------|
| Passing | Basic hygiene (67 criteria) | LICENSE, CONTRIBUTING, build system, test suite, security policy, static analysis |
| Silver  | Governance + quality        | GOVERNANCE.md, code coverage, reproducible builds, signed releases                |
| Gold    | Advanced security           | Formal verification, security audits, advanced threat modeling                    |

Map repository files and practices to Badge criteria. Flag missing criteria as gaps.

## Sigstore (cosign) Standards

Assess Sigstore adoption maturity using cosign as the canonical signing tool:

* **Not adopted**: No signing or attestation in place
* **Basic**: Build provenance via `actions/attest-build-provenance` (cosign-backed)
* **Intermediate**: Build provenance + SBOM attestation via `actions/attest`
* **Advanced**: Tag signing via gitsign + cosign artifact signing + build provenance + SBOM attestation + verification workflow

Document current level and steps to advance.

## NTIA SBOM Minimum Elements

Assess SBOM generation and distribution against NTIA SBOM minimum elements:

* **Format**: SPDX-JSON (preferred for GitHub ecosystem) or CycloneDX
* **Generator**: anchore/sbom-action with syft, or Microsoft SBOM Tool
* **Distribution**: Attached to release artifacts, published to dependency graph
* **NTIA SBOM minimum elements**: Supplier, component name, version, unique identifier, dependency relationship, author, timestamp

Verify NTIA SBOM minimum element compliance for existing SBOM output.

## Researcher Subagent Delegation

Supply chain security standards evolve rapidly and contain framework-specific guidance best retrieved on demand. The following standards are delegated to the Researcher Subagent at runtime:

| Standard                        | Rationale for Delegation                                                      |
|---------------------------------|-------------------------------------------------------------------------------|
| OpenSSF Scorecard check details | Check-specific scoring criteria and remediation evolve with each release      |
| SLSA Build Track specification  | Version-dependent build integrity requirements and verification procedures    |
| Sigstore signing models         | Keyless signing setup varies by package manager and CI platform               |
| SBOM format specifications      | SPDX and CycloneDX schemas evolve; NTIA minimum element guidance updates      |
| Best Practices Badge criteria   | Tier-specific criteria and evidence requirements change across badge versions |
| WAF / CAF                       | Cloud-specific supply chain security guidance, frequently updated             |

Do NOT delegate OpenSSF Scorecard check names, SLSA level definitions, Sigstore maturity levels, SBOM standard names, or Best Practices Badge tier names. Those are embedded above.

### When to Delegate

* Phase 3 identifies supply chain controls that exceed embedded standards coverage.
* Scorecard check remediation requires platform-specific or version-specific guidance.
* SLSA level verification requires CI-platform-specific build provenance procedures.
* Sigstore adoption requires package-manager-specific signing configuration.
* SBOM generation requires tool-specific or language-specific format guidance.
* Compliance requirements demand WAF or CAF supply chain pillar mapping.

### Invocation Pattern

Use `runSubagent` or `task` with the Researcher Subagent:

```text
Agent: Researcher Subagent
Topic: {specific supply chain standard area to research}
Context: Repository "{name}" with supply chain maturity "{current-level}" targeting "{target-level}"
Output: .copilot-tracking/research/subagents/{{YYYY-MM-DD}}/{repo-name}-{standard}.md
```

The Researcher Subagent returns: subagent research document path, research status, important discovered details, recommended next research not yet completed, and any clarifying questions.

When neither `runSubagent` nor `task` tools are available, inform the user that one of these tools is required and should be enabled. Do not synthesize or fabricate answers for delegated standards from training data.

Execution constraints: Complete research within a single invocation. Do not delegate to additional subagents.

### Query Templates

* OpenSSF Scorecard: "OpenSSF Scorecard {check-name} check scoring criteria and remediation steps for {CI-platform}"
* SLSA: "SLSA Build Track Level {N} requirements and verification for {CI-platform} with {build-system}"
* Sigstore: "Sigstore keyless signing setup for {package-manager} with {CI-platform}"
* SBOM: "{SPDX-JSON|CycloneDX} SBOM generation with {tool} for {language} project covering NTIA minimum elements"
* Best Practices Badge: "OpenSSF Best Practices Badge {tier} criteria for {project-type} projects"
* WAF/CAF: "Microsoft Well-Architected Framework supply chain security pillar for {technology-stack} on {cloud-platform}"

Subagents can run in parallel when researching independent standard domains.

## Output

Write the mapping to `.copilot-tracking/sssc-plans/{project-slug}/standards-mapping.md`.

Structure the output as:

```markdown
# Standards Mapping: {project-slug}

## Scorecard Summary
- Estimated overall score: {N}/10
- Checks at maximum: {count}/20
- Checks with gaps: {count}/20

## Scorecard Detail
{per-check assessment table}

## SLSA Assessment
- Current level: Build L{N}
- Target level: Build L{N}
- Steps to advance: {list}

## Best Practices Badge
- Current readiness: {Passing|Silver|Gold|Not enrolled}
- Missing criteria: {list}

## Sigstore Maturity
- Current level: {Not adopted|Basic|Intermediate|Advanced}

## SBOM Compliance
- Format: {SPDX-JSON|CycloneDX|None}
- NTIA compliant: {Yes|Partial|No}
```

Update `state.json`:
* Set `phases.3-standards.status` to `✅`
* Add `standards-mapping.md` to `phases.3-standards.artifacts`
* Advance `currentPhase` to `4`

## Third-Party Attribution

OpenSSF® Scorecard check data derived from the OpenSSF Scorecard project, licensed under
Apache 2.0. Source: <https://github.com/ossf/scorecard>

SLSA Build Track level data derived from the SLSA specification, licensed under Community
Specification License 1.0. Source: <https://slsa.dev/spec/>

OpenSSF Best Practices Badge criteria derived from the CII Best Practices Badge project,
licensed under MIT (criteria) and CC BY 3.0+ (documentation).
Source: <https://www.bestpractices.dev/>

Sigstore maturity data derived from the Sigstore project, licensed under Apache 2.0.
Source: <https://www.sigstore.dev/>

SPDX content derived from the SPDX specification, licensed under Community Specification
License 1.0. Source: <https://spdx.dev/>

CycloneDX content derived from the CycloneDX specification, licensed under Apache 2.0.
Source: <https://cyclonedx.org/>

NTIA Minimum Elements content is derived from a U.S. government publication. Not subject
to copyright (17 U.S.C. § 105).

OpenSSF® is a registered trademark of the Linux Foundation.
