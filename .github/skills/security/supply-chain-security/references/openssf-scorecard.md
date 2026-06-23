---
description: OpenSSF Scorecard 20 checks with risk classifications, score ranges, and per-check assessment guidance
---

# OpenSSF Scorecard: 20 Checks

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

* Current score (estimated 0–10 or binary 0/10)
* Evidence (file paths, workflow names, configuration details)
* Available implementation (which hve-core or PAT workflow/script addresses this check)
* Gap (what is missing to achieve maximum score)

## Attribution

OpenSSF Scorecard check data derived from the OpenSSF Scorecard project, licensed under Apache 2.0. Source: <https://github.com/ossf/scorecard>

OpenSSF is a registered trademark of the Linux Foundation.
