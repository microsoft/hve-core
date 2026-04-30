---
description: "Phase 4 gap comparison, adoption categorization, and effort sizing for SSSC Planner."
applyTo: '**/.copilot-tracking/sssc-plans/**'
---

# SSSC Phase 4 — Gap Analysis

Compare the repository's current supply chain security posture against the desired state using Phase 3 standards mapping output.

## Gap Table Format

Produce a prioritized gap table sorted by Scorecard risk level (Critical > High > Medium > Low):

| Gap           | Scorecard Check | Risk                       | Concern                  | Current State | Target State | Adoption Type | Effort     | Workflow/Script Reference |
|---------------|-----------------|----------------------------|--------------------------|---------------|--------------|---------------|------------|---------------------------|
| {description} | {check_name}    | {Critical/High/Medium/Low} | {Low / Moderate / High} | {current}     | {target}     | {category}    | {S/M/L/XL} | {reference}               |

The `Risk` column carries the OpenSSF Scorecard risk classification. The `Concern` column carries the qualitative residual concern level after considering the repository's current posture and compensating controls (Low, Moderate, or High). Concern is independent from Effort — a small effort may still address a high-concern gap.

Include all 20 Scorecard checks and any additional SLSA, Badge, Sigstore, or SBOM gaps not directly mapped to a Scorecard check.

## Six Adoption Categories

Classify each gap into one of six adoption categories based on the required implementation effort:

### 1. Reusable Workflow Adoption

Reference an hve-core workflow directly via `uses:` in the target repository. Lowest effort — the target repo adds a workflow file that calls the reusable workflow.

Applicable checks: CI-Tests (#3), SAST (#14), Vulnerabilities (#19), and other checks where hve-core provides a reusable `workflow_call` workflow.

### 2. Workflow Copy/Modify

Copy a workflow from physical-ai-toolchain (or hve-core) and adapt it to the target repository's technology stack. Medium effort — requires editing workflow configuration.

Applicable checks: Dependency-Update-Tool (#8), SBOM (#15), Signed-Releases (#17), and other checks requiring repository-specific tuning.

### 3. Reusable Workflow + Script Adoption

Adopt both a reusable workflow and its supporting PowerShell or Python scripts. Medium effort — requires both workflow reference and script installation.

Applicable checks: Pinned-Dependencies (#13), Token-Permissions (#18), and other checks with validation scripts.

### 4. Platform Configuration

GitHub or Azure DevOps settings configured via the web UI or API. Variable effort — depends on organizational policies and admin access.

Applicable checks: Binary-Artifacts (#1), Branch-Protection (#2), Code-Review (#5), CII-Best-Practices (#4), License (#10), Security-Policy (#16), Webhooks (#20).

### 5. New Capability

Requires building something not available in either hve-core or physical-ai-toolchain. Highest effort.

Applicable checks: Fuzzing (#9) — requires setting up ClusterFuzzLite, OSS-Fuzz, or a custom fuzzing harness.

### 6. N/A / Organic

Not actionable as backlog items. These checks improve through natural project activity.

Applicable checks: Contributors (#6), Maintained (#11), Packaging (#12).

## Effort Sizing

Assign T-shirt sizes based on implementation scope:

| Size | Criteria                                           | Typical Duration |
|------|----------------------------------------------------|------------------|
| S    | Single file addition or configuration change       | < 1 day          |
| M    | Multiple files or workflow customization required  | 1–3 days         |
| L    | Cross-cutting changes across CI/CD pipeline        | 3–5 days         |
| XL   | New capability build or major architectural change | 1+ weeks         |

## Qualitative Concern Levels

Assign a qualitative concern level to each gap reflecting residual risk after considering the repository's current posture and compensating controls. Concern is independent from Scorecard risk classification and from effort sizing.

| Concern  | Criteria                                                                                                  |
|----------|-----------------------------------------------------------------------------------------------------------|
| Low      | Gap is informational or already partially mitigated by existing controls; minimal residual exposure       |
| Moderate | Gap leaves measurable residual exposure but compensating controls reduce immediate impact                  |
| High     | Gap leaves significant residual exposure with no effective compensating controls; prioritize remediation  |

Record concern in the gap table alongside Risk and Effort. Use Concern to break ties when multiple gaps share the same Scorecard risk classification.

## Full 20-Check Reference Mapping

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

## Output

Write the analysis to `.copilot-tracking/sssc-plans/{project-slug}/gap-analysis.md`.

Structure the output as:

```markdown
# Gap Analysis — {project-slug}

## Summary
- Total gaps: {count}
- Critical: {count} | High: {count} | Medium: {count} | Low: {count}
- Reusable workflow adoption: {count}
- Workflow copy/modify: {count}
- Workflow + script: {count}
- Platform config: {count}
- New capability: {count}

## Gap Table
{prioritized gap table}

## Adoption Recommendations
{per-category recommendations with specific workflow references}
```

Update `state.json`:
* Set `phases.4-gap-analysis.status` to `✅`
* Add `gap-analysis.md` to `phases.4-gap-analysis.artifacts`
* Advance `currentPhase` to `5`
