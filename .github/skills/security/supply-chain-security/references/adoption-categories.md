---
description: Six supply chain adoption categories, T-shirt effort sizing, and qualitative concern levels for gap classification
---

# Adoption Categories, Effort Sizing, and Concern Levels

Classify each supply chain gap by adoption category, effort size, and qualitative concern level.

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

| Concern  | Criteria                                                                                                 |
|----------|----------------------------------------------------------------------------------------------------------|
| Low      | Gap is informational or already partially mitigated by existing controls; minimal residual exposure      |
| Moderate | Gap leaves measurable residual exposure but compensating controls reduce immediate impact                |
| High     | Gap leaves significant residual exposure with no effective compensating controls; prioritize remediation |

Record concern in the gap table alongside Risk and Effort. Use Concern to break ties when multiple gaps share the same Scorecard risk classification.
