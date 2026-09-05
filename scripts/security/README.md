---
title: Security Scripts
description: PowerShell scripts for dependency pinning validation, SHA staleness monitoring, supply chain security, and centralized PS module installation
author: HVE Core Team
ms.date: 2026-07-28
ms.topic: reference
keywords:
  - powershell
  - security
  - dependency-pinning
  - sha-validation
  - supply-chain
estimated_reading_time: 8
---

This directory contains PowerShell scripts for validating dependency pinning
compliance, monitoring SHA staleness, and maintaining supply chain security in
the `hve-core` repository.

## Architecture

The security scripts share common modules and follow a consistent pattern:

* `SecurityClasses.psm1` defines shared data types for violation tracking and
  compliance reporting
* `SecurityHelpers.psm1` provides timestamped logging, CI annotations, and file
  output utilities
* `CIHelpers.psm1` (from `scripts/lib/`) provides CI platform detection and
  GitHub Actions output formatting
* `tool-checksums.json` stores SHA256 checksums for verified tool downloads
  (see [tool-checksums.json schema](#tool-checksumsjson-schema))

## Scripts

* [`Test-DependencyPinning.ps1`](#test-dependencypinningps1): dependency pinning compliance
* [`Test-SHAStaleness.ps1`](#test-shastalenessps1): SHA freshness monitoring
* [`Test-ActionVersionConsistency.ps1`](#test-actionversionconsistencyps1): action version alignment
* [`Update-ActionSHAPinning.ps1`](#update-actionshapinningps1): auto-remediation of SHA pins
* [`Invoke-PipAudit.ps1`](#invoke-pipauditps1): Python dependency audit
* [`Test-PublicDependencyFeeds.ps1`](#test-publicdependencyfeedsps1): public dependency feed enforcement
* [`Test-WorkflowPermissions.ps1`](#test-workflowpermissionsps1): workflow permissions validation
* [`Test-DangerousWorkflow.ps1`](#test-dangerousworkflowps1): workflow template-injection detection
* [`Test-PrValidationGate.ps1`](#test-prvalidationgateps1): PR-validation gate completeness
* [`Install-PSModules.ps1`](#install-psmodulesps1): centralized PS module install with retry
* [`Test-PSModulePins.ps1`](#test-psmodulepinsps1): PS module version pin enforcement
* [`Sign-PlannerArtifacts.ps1`](#sign-plannerartifactsps1): planner artifact manifest and signing
* [`Modules/SecurityClasses.psm1`](#modulessecurityclassespsm1): shared data types
* [`Modules/SecurityHelpers.psm1`](#modulessecurityhelperspsm1): shared utilities

### `Test-DependencyPinning.ps1`

Verifies dependency pinning compliance for all dependencies in GitHub Actions
workflows and composite actions.

Purpose: Detect unpinned or improperly pinned dependencies to maintain
supply chain security.

#### Features

* Scans workflow files and composite actions (`.github/actions/`) for GitHub
  Actions, Docker images, and other dependency types
* Categorizes violations by type (Unpinned, Stale, VersionMismatch,
  MissingVersionComment)
* Outputs results in JSON, SARIF, CSV, Markdown, or table format
* Supports auto-remediation with `-Remediate`
* Configurable compliance threshold

#### Parameters

* `-Path` - Root path to scan (defaults to repository root)
* `-Recursive` (switch) - Scan subdirectories
* `-Format` - Output format: `json`, `sarif`, `csv`, `markdown`, `table`
* `-OutputPath` - File path for results output
* `-FailOnUnpinned` (switch) - Exit with non-zero code when violations exist
* `-ExcludePaths` - Paths to exclude from scanning
* `-IncludeTypes` - Dependency types to include
* `-Threshold` - Minimum compliance percentage
* `-Remediate` (switch) - Attempt automatic remediation

#### Usage

```powershell
# Scan all workflows with table output
./scripts/security/Test-DependencyPinning.ps1 -Recursive

# Export SARIF results
./scripts/security/Test-DependencyPinning.ps1 -Format sarif -OutputPath logs/pinning.sarif

# Fail CI when unpinned dependencies exist
./scripts/security/Test-DependencyPinning.ps1 -FailOnUnpinned -Recursive
```

### `Test-SHAStaleness.ps1`

Monitors SHA-pinned dependencies for staleness by checking whether newer
versions are available. Scans both `.github/workflows/` and
`.github/actions/` (composite actions) for SHA-pinned references.

Purpose: Identify pinned dependencies that have fallen behind upstream
releases.

#### Features

* Queries GitHub API for latest releases of pinned actions
* Supports multiple output formats (JSON, Azure DevOps, GitHub, console)
* Configurable maximum age threshold
* Batch GraphQL queries for efficient API usage

#### Parameters

* `-OutputFormat` - Output format: `json`, `azdo`, `github`, `console`
* `-MaxAge` - Maximum age in days before a pin is considered stale
* `-LogPath` - Path for log file output
* `-OutputPath` - Path for structured results output
* `-FailOnStale` (switch) - Exit with non-zero code when stale pins exist
* `-GraphQLBatchSize` - Number of repositories per GraphQL batch query

#### Usage

```powershell
# Check for stale SHAs with console output
./scripts/security/Test-SHAStaleness.ps1 -OutputFormat console

# Export JSON results with 90-day threshold
./scripts/security/Test-SHAStaleness.ps1 -OutputFormat json -OutputPath logs/staleness.json -MaxAge 90

# Fail CI on stale dependencies
./scripts/security/Test-SHAStaleness.ps1 -FailOnStale
```

### `Test-ActionVersionConsistency.ps1`

Validates that GitHub Actions version comments match their corresponding SHA
pins across workflow files.

Purpose: Detect mismatches between version comments and pinned SHAs that
could indicate incomplete updates.

#### Features

* Compares version comment annotations with resolved SHA references
* Outputs results in table, JSON, or SARIF format
* Integrates with `lint:version-consistency` npm script

#### Parameters

* `-Path` - Root path containing workflow files
* `-Format` - Output format: `Table`, `Json`, `Sarif`
* `-OutputPath` - File path for results output
* `-FailOnMismatch` (switch) - Exit with non-zero code when mismatches exist
* `-FailOnMissingComment` (switch) - Fail when SHA pins lack version comments

#### Usage

```powershell
# Check version consistency
./scripts/security/Test-ActionVersionConsistency.ps1

# Fail on mismatches (used in CI)
./scripts/security/Test-ActionVersionConsistency.ps1 -FailOnMismatch

# Export JSON results
./scripts/security/Test-ActionVersionConsistency.ps1 -Format Json -OutputPath logs/version-consistency.json
```

### `Update-ActionSHAPinning.ps1`

Updates GitHub Actions workflow files to use SHA-pinned references. Supports
`WhatIf` via `SupportsShouldProcess`.

Purpose: Automate the process of resolving and updating SHA pins for GitHub
Actions dependencies.

#### Features

* Resolves current SHA for each action reference
* Supports dry-run via `-WhatIf`
* Updates stale pins with `-UpdateStale`
* Generates update reports

#### Parameters

* `-WorkflowPath` - Path to workflow file(s) to update
* `-OutputReport` - Path for the update report
* `-OutputFormat` - Report format
* `-UpdateStale` (switch) - Update only stale pins rather than all

#### Usage

```powershell
# Preview changes without modifying files
./scripts/security/Update-ActionSHAPinning.ps1 -WhatIf

# Update all SHA pins
./scripts/security/Update-ActionSHAPinning.ps1

# Update stale pins and generate report
./scripts/security/Update-ActionSHAPinning.ps1 -UpdateStale -OutputReport logs/sha-update-report.json
```

### `Invoke-PipAudit.ps1`

Audits Python project dependencies for known vulnerabilities using pip-audit.

Purpose: Detect vulnerable Python packages across all Python skills before they
reach production.

#### Features

* Discovers Python projects via `pyproject.toml` file search
* Exports locked dependencies via `uv export` before auditing
* Runs pip-audit against each project's dependency set
* Writes JSON results to the `logs/` directory
* Configurable path exclusions

#### Parameters

* `-Path` - Root path to scan for Python projects (default: repository root)
* `-OutputPath` - Directory for JSON results (default: `logs/` under repository root)
* `-FailOnVulnerability` (switch) - Exit with error code if vulnerabilities are found
* `-ExcludePaths` - Path patterns to exclude from scanning

#### Usage

```powershell
# Scan all Python projects
./scripts/security/Invoke-PipAudit.ps1

# Fail if vulnerabilities found
./scripts/security/Invoke-PipAudit.ps1 -FailOnVulnerability

# Scan a specific skill directory
./scripts/security/Invoke-PipAudit.ps1 -Path ".github/skills/experimental/powerpoint"
```

### `Test-PublicDependencyFeeds.ps1`

Validates that committed dependency metadata uses canonical public feeds.

Purpose: Prevent dependency-confusion and credential-leak vectors by rejecting
non-public hosts, plain HTTP, embedded credentials, and non-literal npm registry
values in committed manifests and lockfiles.

#### Features

* Scans npm, Python, and uv dependency manifests and lockfiles for source URLs
* Requires npm registry declarations to use the canonical public npm registry
* Flags plain HTTP sources and URLs carrying embedded credentials
* Writes structured results to `logs/public-dependency-feeds-results.json`
* Integrates with `npm run lint:public-dependency-feeds`

#### Parameters

* `-RepoRoot` - Repository root to scan (default: the repository containing this script)
* `-OutputPath` - JSON results path (default: `logs/public-dependency-feeds-results.json`)
* `-FailOnViolation` (switch) - Exit with non-zero code when a prohibited source is found

#### Usage

```powershell
# Report only
./scripts/security/Test-PublicDependencyFeeds.ps1

# Enforce in CI
./scripts/security/Test-PublicDependencyFeeds.ps1 -FailOnViolation
```

### `Test-WorkflowPermissions.ps1`

Validates that GitHub Actions workflow files declare permissions at the workflow
and job level.

Purpose: Ensure workflows explicitly declare token permissions to prevent
OpenSSF Scorecard Token-Permissions failures, and ensure each job declares the
scope it holds rather than inheriting the workflow grant implicitly.

#### Classification

| Workflow-level block | Job-level block | Effective scopes                   | Verdict   |
|----------------------|-----------------|------------------------------------|-----------|
| absent               | absent          | repository or organization default | violation |
| `permissions: {}`    | absent          | none                               | pass      |
| populated            | absent          | inherits the workflow grant        | violation |
| any                  | present         | job-declared                       | pass      |

A job beneath an empty workflow-level block that declares no block of its own
inherits an empty set and therefore holds no scope, so that case passes. An empty
workflow-level block is a default, not a ceiling: a job that does declare its own
block still receives what it declares, because job-level permissions replace the
workflow-level set rather than being capped by it.

#### Features

* Scans `.github/workflows/*.yml` and `.yaml` files
* Parses each workflow with `ConvertFrom-Yaml`, so job indentation and the
  `permissions` value shape do not affect detection
* Reports workflow-level and job-level compliance as separate metrics
* Outputs results in JSON, SARIF, or console format
* Configurable workflow exclusions
* Integrates with `npm run lint:permissions`

#### Parameters

* `-Path` - Directory containing workflow YAML files (default: `.github/workflows`)
* `-Format` - Output format: `json`, `sarif`, or `console` (default: `json`)
* `-OutputPath` - Path for result output file (default: `logs/workflow-permissions-results.json`)
* `-FailOnViolation` (switch) - Exit with non-zero code if any workflow or job is missing permissions
* `-ExcludePaths` - Workflow filenames to exclude (default: `copilot-setup-steps.yml`)

#### Usage

```powershell
# Check all workflows
./scripts/security/Test-WorkflowPermissions.ps1

# Fail on missing permissions
./scripts/security/Test-WorkflowPermissions.ps1 -FailOnViolation

# Export SARIF results
./scripts/security/Test-WorkflowPermissions.ps1 -Format sarif -FailOnViolation
```

### `Test-DangerousWorkflow.ps1`

Detects template-injection patterns in GitHub Actions workflows.

Purpose: Catch direct interpolation of attacker-controllable GitHub event values
into `run` or script execution contexts. This is a narrowed single-rule gate that
emits the rule ID `dangerous-workflow/template-injection`. Broader
dangerous-workflow coverage, including untrusted checkout and unpinned actions, is
provided advisory-only by the Poutine scanner in CI.

#### Features

* Scans workflow YAML files for injected event-context expressions
* Outputs results in `console`, `json`, or `sarif` format
* Integrates with `npm run lint:dangerous-workflow`

#### Parameters

* `-Path` - Directory containing workflow YAML files (default: `.github/workflows`)
* `-Format` - Output format: `console`, `json`, or `sarif` (default: `console`)
* `-OutputPath` - Path for result output file (default: `logs/dangerous-workflow-results.json`, or the `.sarif` variant for SARIF output)
* `-FailOnViolation` (switch) - Exit with non-zero code when in-scope findings remain

#### Usage

```powershell
# Console report
./scripts/security/Test-DangerousWorkflow.ps1

# Enforce and export SARIF
./scripts/security/Test-DangerousWorkflow.ps1 -FailOnViolation -Format sarif
```

### `Test-PrValidationGate.ps1`

Validates that the PR-validation aggregator gate job depends on every other job.

Purpose: Prevent a job from silently bypassing required-check enforcement because
the gate job never waits on it.

#### Features

* Parses the workflow structurally with `ConvertFrom-Yaml` rather than regex
* Detects missing jobs, where a job exists but is absent from the gate's `needs:` list
* Detects stale needs, where `needs:` references a job ID that no longer exists
* Treats an absent gate job as a violation
* Writes JSON results under `logs/` and a readable summary to the console
* Integrates with `npm run lint:pr-gate`

#### Parameters

* `-WorkflowPath` - Workflow YAML file to validate (default: `.github/workflows/pr-validation.yml`)
* `-GateJobId` - Aggregator gate job ID (default: `pr-validation-success`)
* `-OutputPath` - JSON results path (default: `logs/pr-validation-gate-results.json`)
* `-FailOnViolation` (switch) - Exit with non-zero code and name the offending jobs

#### Usage

```powershell
# Report only
./scripts/security/Test-PrValidationGate.ps1

# Enforce in CI
./scripts/security/Test-PrValidationGate.ps1 -FailOnViolation
```

This validator requires the `PowerShell-Yaml` module at the version pinned in
`ps-module-versions.json`.

### `Install-PSModules.ps1`

Installs PowerShell modules declared in `ps-module-versions.json` with
exponential-backoff retry for PSGallery transient failures.

Purpose: Provide a single, testable entry point for PS module provisioning
across CI workflows, devcontainers, and local development. Retry logic lives
here so the composite action (`.github/actions/setup-ps-modules/`) stays a
thin cache-then-call wrapper.

#### Colocation rationale

This script lives in `scripts/security/` because it
consumes `ps-module-versions.json` (the pinned-version manifest that the
security scanners enforce) and its correct operation is a supply-chain security
concern. If the scope later expands beyond security-module provisioning, move
it to `scripts/lib/`.

#### Contract

| Aspect       | Detail                                                                                                                                                                         |
|--------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| Error mode   | `$ErrorActionPreference = 'Stop'`; throws on exhausted retries                                                                                                                 |
| Exit code    | 0 on success, 1 on any module install failure                                                                                                                                  |
| Logging      | Timestamped `Write-Host` (green success, yellow retry, red failure); emits `::warning::` annotations when `$env:GITHUB_ACTIONS -eq 'true'`                                     |
| Idempotent   | Skips modules already present at the required version (`Get-Module -ListAvailable`) unless `-Force` is specified; verifies default PSGallery registration before use           |
| Side effects | Imports requested modules; creates and removes a temporary canonical PSGallery alias when default registration is unavailable; cleanup also runs after an installation failure |

#### Parameters

| Parameter           | Type     | Default                                                                     | Description                                                             |
|---------------------|----------|-----------------------------------------------------------------------------|-------------------------------------------------------------------------|
| `-ConfigPath`       | `string` | `scripts/security/ps-module-versions.json` (resolved relative to repo root) | Path to the JSON version manifest                                       |
| `-Scope`            | `string` | `CurrentUser`                                                               | `Install-Module` scope (`CurrentUser` or `AllUsers`)                    |
| `-Repository`       | `string` | `PSGallery`                                                                 | PowerShell repository name                                              |
| `-Import`           | `switch` | `$false`                                                                    | Import each module after install                                        |
| `-Force`            | `switch` | `$false`                                                                    | Re-install even if the module is already present at the correct version |
| `-MaxAttempts`      | `int`    | `3`                                                                         | Maximum retry attempts per module                                       |
| `-BaseDelaySeconds` | `int`    | `10`                                                                        | Initial backoff delay; doubles each retry                               |

#### Environment variable overrides

| Variable                | Overrides     | Purpose                                                                          |
|-------------------------|---------------|----------------------------------------------------------------------------------|
| `PS_MODULE_CONFIG_PATH` | `-ConfigPath` | Allows CI steps to point at an alternate manifest without changing the call site |
| `PS_MODULE_SCOPE`       | `-Scope`      | Allows `copilot-setup-steps.yml` to set `AllUsers` at the environment level      |

Parameters take precedence over environment variables.

#### Usage

```powershell
# Default: install all modules for current user, no import
./scripts/security/Install-PSModules.ps1

# CI composite action call (import after install)
./scripts/security/Install-PSModules.ps1 -Import

# copilot-setup-steps.yml (needs AllUsers for pre-installed runner)
./scripts/security/Install-PSModules.ps1 -Scope AllUsers -Import

# Local dev: ensure modules present, skip if satisfied
./scripts/security/Install-PSModules.ps1 -Import

# Force reinstall (troubleshooting)
./scripts/security/Install-PSModules.ps1 -Force -Import
```

### `Test-PSModulePins.ps1`

Validates PowerShell module version pins against the canonical pin config.

Purpose: Keep every module pin in the repository aligned with
`ps-module-versions.json` so a single manifest governs the supply chain.

#### Features

* Scans tracked and untracked, non-ignored files for pins expressed as
  `Install-Module -RequiredVersion`, `Import-Module -RequiredVersion`, and
  `#Requires -Modules @{ ... RequiredVersion='...' }`
* Compares every pin for a managed module against the canonical version
* Allows a small fixture list of files that intentionally carry non-canonical literals
* Writes JSON results to `logs/ps-module-pins-results.json`
* Exits non-zero on violations
* Integrates with `npm run lint:ps-module-pins`

#### Parameters

* `-ConfigPath` - Path to the canonical pin config (default: `scripts/security/ps-module-versions.json`)

#### Usage

```powershell
./scripts/security/Test-PSModulePins.ps1
```

### `Sign-PlannerArtifacts.ps1`

Generates a SHA-256 manifest for planner artifacts and optionally signs it with cosign.

Purpose: Provide cryptographic provenance for RAI, SSSC, and other planner
session outputs.

#### Features

* Enumerates every file under a planner session directory and hashes it with SHA-256
* Resolves RAI sessions from `-ProjectSlug` under `.copilot-tracking/rai-plans/`
* Accepts any other planner session directory through `-SessionPath`
* Excludes the manifest itself and cosign signature files (`.sig`, `.bundle`) from the inventory
* Signs the manifest with Sigstore keyless signing when `-IncludeCosign` is set,
  and warns rather than fails when cosign is unavailable

#### Parameters

* `-ProjectSlug` - RAI session slug under `.copilot-tracking/rai-plans/` (mutually exclusive with `-SessionPath`)
* `-SessionPath` - Planner session directory, absolute or repository-relative (mutually exclusive with `-ProjectSlug`)
* `-ManifestName` - Manifest file name written inside the session directory (default: `artifact-manifest.json`)
* `-OutputPath` - Full manifest path; overrides `-ManifestName`
* `-IncludeCosign` (switch) - Sign the manifest with cosign keyless signing

#### Usage

```powershell
# RAI session manifest
./scripts/security/Sign-PlannerArtifacts.ps1 -ProjectSlug "contoso-ai"

# RAI session manifest with cosign signing
./scripts/security/Sign-PlannerArtifacts.ps1 -ProjectSlug "contoso-ai" -IncludeCosign

# SSSC session manifest
./scripts/security/Sign-PlannerArtifacts.ps1 -SessionPath '.copilot-tracking/sssc-plans/contoso-supply-chain' -ManifestName 'sssc-manifest.json'
```

The package scripts `npm run rai:sign`, `npm run sssc:sign`, and
`npm run security:sign` all invoke this script; pass parameters after `--`.

Under the `-SessionPath` parameter set, the manifest's `projectSlug` field is
populated from the session directory leaf. The field name is retained for
back-compatibility with existing RAI manifest consumers; callers that need to
distinguish project slug from session label should rely on `sessionPath`.

## Modules

### `Modules/SecurityClasses.psm1`

Shared class definitions imported using `using module` syntax:

| Class                 | Purpose                                                                 |
|-----------------------|-------------------------------------------------------------------------|
| `DependencyViolation` | Tracks individual pinning violations with file location and remediation |
| `ComplianceReport`    | Aggregates violations and calculates compliance scores                  |

### `Modules/SecurityHelpers.psm1`

Shared utility functions used across security scripts:

| Function            | Purpose                                                                   |
|---------------------|---------------------------------------------------------------------------|
| `Write-SecurityLog` | Outputs timestamped, color-coded log entries with optional CI annotations |

## tool-checksums.json schema

`tool-checksums.json` supports a dual schema for tool download metadata. Legacy
scalar fields remain available for compatibility, while per-arch maps are
preferred for new entries.

* Legacy scalar fields: `sha256` and `downloadUrlTemplate`. These fields are
  deprecated for new entries, but they remain the values the current tooling
  consumes; for example, `Test-SHAStaleness.ps1` reads `sha256`.
* Preferred per-arch maps: `sha256ByArch` and `assetTemplateByArch`. New entries
  should populate these maps to carry architecture-specific download metadata.
  The current scripts do not yet read these fields, so populate the legacy
  scalar fields alongside them until a consumer adopts the maps.
* This documentation describes the manifest schema only and does not change
  runtime behavior.

## GitHub Actions Integration

Security scripts integrate with these workflows:

| Workflow                        | Script(s)                      | Trigger                       |
|---------------------------------|--------------------------------|-------------------------------|
| `dependency-pinning-scan.yml`   | `Test-DependencyPinning.ps1`   | PR, schedule                  |
| `sha-staleness-check.yml`       | `Test-SHAStaleness.ps1`        | Schedule                      |
| `pr-validation.yml`             | `Test-DependencyPinning.ps1`   | Pull request                  |
| `pip-audit.yml`                 | `Invoke-PipAudit.ps1`          | PR, schedule                  |
| `workflow-permissions-scan.yml` | `Test-WorkflowPermissions.ps1` | PR, schedule                  |
| `dangerous-workflow-scan.yml`   | `Test-DangerousWorkflow.ps1`   | Called by `pr-validation.yml` |

`dangerous-workflow-scan.yml` is a reusable `workflow_call` workflow rather than a
directly triggered one. It runs `Test-DangerousWorkflow.ps1` as the blocking gate and
the Poutine scanner alongside it, with Poutine advisory by default through the
`poutine-soft-fail` input.

## Related Documentation

* [Scripts README](../README.md) for overall script organization
* [Build Workflows](../../docs/architecture/workflows.md) for CI pipeline
  details

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
