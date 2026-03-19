---
title: Security Scripts
description: PowerShell scripts for dependency pinning validation, SHA staleness monitoring, and supply chain security
author: HVE Core Team
ms.date: 2026-03-17
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

## Scripts

### `Test-DependencyPinning.ps1`

Verifies dependency pinning compliance for all dependencies in GitHub Actions workflows.

Purpose: Detect unpinned or improperly pinned dependencies to maintain
supply chain security.

#### Features

* Scans workflow files for GitHub Actions, Docker images, and other dependency
  types
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
versions are available.

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

### `Test-WorkflowPermissions.ps1`

Validates that GitHub Actions workflow files include a top-level `permissions` block.

Purpose: Ensure workflows explicitly declare token permissions to prevent
OpenSSF Scorecard Token-Permissions failures.

#### Features

* Scans `.github/workflows/*.yml` and `.yaml` files
* Uses regex-based detection (`^permissions:`) with zero false positives
* Outputs results in JSON, SARIF, or console format
* Configurable workflow exclusions
* Integrates with `npm run lint:permissions`

#### Parameters

* `-Path` - Directory containing workflow YAML files (default: `.github/workflows`)
* `-Format` - Output format: `json`, `sarif`, or `console` (default: `json`)
* `-OutputPath` - Path for result output file (default: `logs/workflow-permissions-results.json`)
* `-FailOnViolation` (switch) - Exit with non-zero code if any workflow is missing permissions
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

## GitHub Actions Integration

Security scripts integrate with these workflows:

| Workflow                        | Script(s)                      | Trigger      |
|---------------------------------|--------------------------------|--------------|
| `dependency-pinning-scan.yml`   | `Test-DependencyPinning.ps1`   | PR, schedule |
| `sha-staleness-check.yml`       | `Test-SHAStaleness.ps1`        | Schedule     |
| `pr-validation.yml`             | `Test-DependencyPinning.ps1`   | Pull request |
| `pip-audit.yml`                 | `Invoke-PipAudit.ps1`          | PR, schedule |
| `workflow-permissions-scan.yml` | `Test-WorkflowPermissions.ps1` | PR, schedule |

## Related Documentation

* [Scripts README](../README.md) for overall script organization
* [Build Workflows](../../docs/architecture/workflows.md) for CI pipeline
  details

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
