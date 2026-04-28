---
title: Planner Artifact Validation and Signing
description: Validate planner footer and disclaimer compliance and produce signed SHA-256 manifests for planner outputs
sidebar_position: 6
author: Microsoft
ms.date: 2026-04-22
ms.topic: how-to
keywords:
  - planner
  - validation
  - signing
  - cosign
  - sigstore
  - manifest
  - rai
  - sssc
---

HVE Core ships two PowerShell scripts that operators and release engineers run against planner outputs (RAI, SSSC, security, accessibility, sustainability). `Validate-PlannerArtifacts.ps1` enforces footer, disclaimer, and skill-loading-contract compliance. `Sign-PlannerArtifacts.ps1` produces a SHA-256 manifest for a planner instance and optionally signs it with cosign keyless signing.

Both scripts replace earlier RAI-only utilities. The [Rename Notice](#rename-notice) section lists the old names; any local automation that calls them must be updated.

## Overview

| Script                                                                                               | Purpose                                                                                                                                                                 |
|------------------------------------------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| [scripts/linting/Validate-PlannerArtifacts.ps1](../../scripts/linting/Validate-PlannerArtifacts.ps1) | Reads footer and disclaimer config files and verifies that every classified instruction file carries the required footer text. Optionally enforces skill-loading scope. |
| [scripts/security/Sign-PlannerArtifacts.ps1](../../scripts/security/Sign-PlannerArtifacts.ps1)       | Enumerates files under a planner artifact directory, hashes each one with SHA-256, writes `artifact-manifest.json`, and (optionally) signs the manifest with cosign.    |

The validator scans `.github/instructions/` by default. The signer accepts either an explicit `-PlanRoot` (for example `.copilot-tracking/sssc-plans/{slug}`) or the legacy `-Scope` plus `-ProjectSlug` form.

## Configuration

Footer and disclaimer behavior is driven by two YAML files validated against a single schema:

* [.github/config/footer-with-review.yml](../../.github/config/footer-with-review.yml) defines reusable footer blocks and an `artifact-classification` table that maps file globs to required footers and disclaimers.
* [.github/config/disclaimers.yml](../../.github/config/disclaimers.yml) defines disclaimer text referenced by classification entries.

Both files conform to [scripts/linting/schemas/ai-artifact-config.schema.json](../../scripts/linting/schemas/ai-artifact-config.schema.json), which uses a `oneOf` to accept either shape:

```yaml
version: "1.0"
footers:
  microsoft-hve-core:
    id: microsoft-hve-core
    label: Microsoft HVE Core
    text: |
      Brought to you by microsoft/hve-core.
artifact-classification:
  planner-outputs:
    scope:
      - ".copilot-tracking/**/*-plan.instructions.md"
    required-footers:
      - microsoft-hve-core
    artifacts:
      - rai-plans
      - sssc-plans
    requires-disclaimer: true
    disclaimer-ref: ai-assisted-review
```

When a classification entry sets `requires-disclaimer: true`, the validator resolves `disclaimer-ref` against `disclaimers.yml` and verifies the referenced text is present in every matched artifact.

## Cosign Provisioning

Manifest signing uses Sigstore keyless signing. Cosign must be available on `PATH`; the signer prints a warning and skips signing when it is not. The standard provisioning steps and version-pinning conventions are documented in [SBOM Verification](sbom-verification) and [Dependency Pinning](dependency-pinning).

In CI the signer relies on the GitHub OIDC token. Required environment variables:

| Variable                         | Purpose                                                                |
|----------------------------------|------------------------------------------------------------------------|
| `COSIGN_EXPERIMENTAL=1`          | Enables keyless signing on cosign versions that gate it behind a flag. |
| `ACTIONS_ID_TOKEN_REQUEST_URL`   | Provided by GitHub Actions; required for the OIDC exchange.            |
| `ACTIONS_ID_TOKEN_REQUEST_TOKEN` | Provided by GitHub Actions; required for the OIDC exchange.            |

Keyless signing produces a transparency-log entry tied to the workflow identity, so there is no long-lived private key to rotate. When a workload moves between repositories or workflow files, re-verify the signing identity and update any verifier policies that pin the previous identity.

## Rename Notice

These scripts were renamed to remove the RAI-only branding. The old names no longer exist on disk; any automation that references them will fail.

| Old                        | New                             |
|----------------------------|---------------------------------|
| `Validate-AIArtifacts.ps1` | `Validate-PlannerArtifacts.ps1` |
| `Sign-RaiArtifacts.ps1`    | `Sign-PlannerArtifacts.ps1`     |
| `Sign-RAIArtifacts.ps1`    | `Sign-PlannerArtifacts.ps1`     |

The npm aliases were renamed in lockstep:

| Old npm script                  | New npm script                       |
|---------------------------------|--------------------------------------|
| `npm run sign:rai`              | `npm run sign:planner`               |
| `npm run validate:ai-artifacts` | `npm run validate:planner-artifacts` |
| `npm run lint:ai-artifacts`     | `npm run lint:planner-artifacts`     |

For migration guidance specific to SSSC sessions, see [SSSC Planner Framework Opt-Out](sssc-planner-opt-out).

## Invocation

Run the validator over the default instruction tree:

```bash
npm run validate:planner-artifacts
```

Run the lint variant, which fails the build on any missing footer or disclaimer:

```bash
npm run lint:planner-artifacts
```

Sign a specific planner instance:

```bash
npm run sign:planner -- -Scope sssc -PlanRoot .copilot-tracking/sssc-plans/contoso-sssc -IncludeCosign
```

The signer writes `artifact-manifest.json` (and, when cosign succeeds, an adjacent `.sig` and `.bundle`) to the plan root.

## Troubleshooting

| Symptom                                                           | Cause and fix                                                                                                                             |
|-------------------------------------------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------|
| Validator exits with `Schema validation failed` for a config file | The YAML does not match `ai-artifact-config.schema.json`. Run the validator with `-Verbose` to see the failing JSON pointer.              |
| Validator reports missing footers in files you intend to ignore   | Add an exclude glob via `-ExcludePaths`, or scope the classification entry so it no longer matches the file.                              |
| Signer logs `cosign not found` and skips signing                  | Install cosign on `PATH`. The manifest is still written; rerun with `-IncludeCosign` after installation to produce signatures.            |
| Signer fails with `error getting OIDC token` in CI                | Confirm `id-token: write` is set on the workflow job and that the runner exposes `ACTIONS_ID_TOKEN_REQUEST_*` variables.                  |
| Skill-loading violations reported when `-PlanRoot` is supplied    | Inspect `logs/planner-loading-violations.json`. Each entry names the skill loaded outside its declared phase scope; remove or rescope it. |

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
