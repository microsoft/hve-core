---
description: SLSA v1.0 Build track levels L0 through L3 with requirements and assessment criteria
---

# SLSA v1.0 Build Track Levels

Assess the repository against SLSA v1.0 Build track requirements:

| Level    | Requirements                                      | Assessment Criteria                                         |
|----------|---------------------------------------------------|-------------------------------------------------------------|
| Build L0 | No requirements                                   | Baseline, all repositories start here                       |
| Build L1 | Provenance exists and is distributed to consumers | Check for `actions/attest-build-provenance` or equivalent   |
| Build L2 | Hosted build platform, signed provenance          | Verify GitHub Actions (hosted), Sigstore provenance signing |
| Build L3 | Build runs in isolation, signing key isolation    | Verify ephemeral runners, ephemeral Sigstore keys (OIDC)    |

Record current level and specific steps needed to reach the next level.

## Attribution

SLSA Build Track level data derived from the SLSA specification, licensed under Community Specification License 1.0. Source: <https://slsa.dev/spec/>
