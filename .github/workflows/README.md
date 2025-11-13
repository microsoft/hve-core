---
title: GitHub Workflows
description: Documentation for GitHub Actions workflows in the HVE Core project
author: HVE Core Team
ms.date: 2025-11-12
ms.topic: reference
keywords:
  - github actions
  - workflows
  - ci/cd
  - automation
  - validation
  - security
estimated_reading_time: 20
---

# GitHub Actions Workflows

This directory contains GitHub Actions workflow definitions for continuous integration, code quality validation, security scanning, and automated maintenance in the HVE Core project.

## Overview

Workflows run automatically on pull requests, pushes to protected branches, and scheduled intervals. They enforce code quality standards, validate documentation, perform security scans, and ensure consistency across the codebase.

## Workflow Organization

### Naming Conventions

Workflows follow a consistent naming pattern to indicate their purpose and usage:

* **`*-scan.yml`**: Security scanning workflows (reusable or standalone)
  * Example: `gitleaks-scan.yml`, `checkov-scan.yml`, `dependency-pinning-scan.yml`
  * Purpose: Run security scanners and produce SARIF outputs for the Security tab
  * Typically support `workflow_call` trigger for composition

* **`*-check.yml`**: Validation and compliance checking workflows
  * Example: `sha-staleness-check.yml`
  * Purpose: Validate code/configuration quality or security posture
  * May run on schedule or be called by orchestrator workflows

* **`*-lint.yml`**: Code quality and formatting workflows
  * Example: `markdown-lint.yml`, `spell-check.yml`
  * Purpose: Enforce code style and formatting standards
  * Typically run on pull requests

* **Orchestrator workflows**: Compose multiple reusable workflows
  * Example: `weekly-security-maintenance.yml`
  * Purpose: Run multiple related checks and generate consolidated reports
  * Typically run on schedule or manual trigger

### Workflow Types

**Reusable Workflows** (`workflow_call` trigger)

* Designed to be called by other workflows
* Accept inputs via `workflow_call.inputs`
* Expose outputs via `workflow_call.outputs`
* Should be self-contained and focused on a single task
* Include appropriate permissions declarations

**Standalone Workflows** (`schedule`, `workflow_dispatch`, `push`, `pull_request` triggers)

* Run independently based on event triggers
* May call reusable workflows for composition
* Should minimize duplication by using reusable workflows

## Current Workflows

### Security Workflows

| Workflow | Type | Purpose | Triggers |
|----------|------|---------|----------|
| `weekly-security-maintenance.yml` | Orchestrator | Weekly security posture check | `schedule`, `workflow_dispatch` |
| `dependency-pinning-scan.yml` | Reusable | Validate SHA pinning compliance | `workflow_call` |
| `sha-staleness-check.yml` | Reusable | Check for stale SHA pins | `workflow_call`, `workflow_dispatch` |
| `codeql-analysis.yml` | Reusable | CodeQL security analysis | `push`, `pull_request`, `schedule`, `workflow_call` |
| `dependency-review.yml` | Reusable | Dependency vulnerability review | `pull_request`, `workflow_call` |
| `security-scan.yml` | Standalone | Security scanning orchestrator | `push`, `pull_request` |

### Validation Workflows

| Workflow | Purpose | Triggers | Configuration |
|----------|---------|----------|---------------|
| `ps-script-analyzer.yml` | PowerShell static analysis | PR (*.ps1, *.psm1), dispatch | `scripts/linting/PSScriptAnalyzer.psd1` |
| `markdown-lint.yml` | Markdown formatting standards | PR (*.md), dispatch | `.markdownlint.json` |
| `frontmatter-validation.yml` | YAML frontmatter validation | PR (*.md), dispatch | Script hardcoded |
| `markdown-link-check.yml` | Link validation | PR (*.md), dispatch | `scripts/linting/markdown-link-check.config.json` |
| `link-lang-check.yml` | Detect language-specific URLs | PR (*.md), dispatch | Script regex |
| `spell-check.yml` | Spell checking | PR, dispatch | `.cspell.json` |
| `table-format.yml` | Markdown table formatting | PR (*.md), dispatch | N/A |

## Using Reusable Workflows

### Basic Usage

Call a reusable workflow from another workflow using the `uses` keyword:

```yaml
jobs:
  security-scan:
    name: CodeQL Security Analysis
    uses: ./.github/workflows/codeql-analysis.yml
    permissions:
      contents: read
      security-events: write
      actions: read
```

### Passing Inputs

Provide inputs to reusable workflows using the `with` keyword:

```yaml
jobs:
  pinning-check:
    uses: ./.github/workflows/dependency-pinning-scan.yml
    with:
      threshold: 95
      dependency-types: 'actions,containers'
      soft-fail: true
      upload-sarif: true
      upload-artifact: true
```

### Accessing Outputs

Access outputs from reusable workflows in downstream jobs:

```yaml
jobs:
  security-scan:
    uses: ./.github/workflows/dependency-pinning-scan.yml
    with:
      soft-fail: true

  summary:
    needs: security-scan
    runs-on: ubuntu-latest
    steps:
      - name: Check compliance
        run: |
          echo "Compliance: ${{ needs.security-scan.outputs.compliance-score }}%"
          echo "Unpinned: ${{ needs.security-scan.outputs.unpinned-count }}"
```

## Workflow Details

### Security Workflows

#### `weekly-security-maintenance.yml`

**Purpose**: Orchestrates weekly security posture checks

**Schedule**: Weekly on Sundays at 02:00 UTC

**Jobs**:

* `validate-pinning`: Checks SHA pinning compliance (100% threshold)
* `check-staleness`: Identifies stale SHA pins (>30 days)
* `codeql-scan`: Runs CodeQL security analysis
* `summary`: Generates consolidated report

**Outputs**: Consolidated job summaries, JSON reports

**Security Coverage**:

* **CodeQL Analysis**: JavaScript/TypeScript code security scanning with security-extended queries
* **GitHub Secret Scanning**: Automatic detection of 200+ secret patterns (enabled via Security tab)
* **Dependabot Alerts**: Automatic vulnerability detection for npm dependencies (enabled via Security tab)

#### `dependency-pinning-scan.yml`

**Purpose**: Validates that all GitHub Actions use SHA-pinned versions

**Inputs**:

* `threshold` (number, default: 95): Minimum compliance percentage
* `dependency-types` (string, default: 'actions,containers'): Types to validate
* `soft-fail` (boolean, default: false): Continue on failures
* `upload-sarif` (boolean, default: false): Upload to Security tab
* `upload-artifact` (boolean, default: true): Upload JSON results

**Outputs**:

* `compliance-score`: Percentage of dependencies properly pinned
* `unpinned-count`: Number of unpinned dependencies
* `is-compliant`: Boolean indicating threshold met

#### `sha-staleness-check.yml`

**Purpose**: Detects outdated GitHub Action SHA pins

**Inputs**:

* `max-age-days` (number, default: 30): Maximum age before stale

**Outputs**:

* `stale-count`: Number of stale SHA pins
* `has-stale`: Boolean indicating stale pins found

**Severity Levels**:

* Info: 0-30 days
* Low: 31-90 days
* Medium: 91-180 days
* High: 181-365 days
* Critical: >365 days

#### `codeql-analysis.yml`

**Purpose**: Performs comprehensive security analysis using GitHub CodeQL

**Triggers**: `push`, `pull_request`, `schedule` (Sundays at 4 AM UTC), `workflow_call`

**Features**:

* **Languages**: JavaScript/TypeScript analysis
* **Queries**: security-extended and security-and-quality query suites
* **Coverage**: Detects SQL injection, XSS, command injection, path traversal, and 200+ other vulnerabilities
* **Integration**: Results appear in Security > Code Scanning tab
* **Autobuild**: Automatically detects and builds JavaScript/TypeScript projects

**Outputs**: SARIF results uploaded to GitHub Security tab, job summary with analysis details

#### `dependency-review.yml`

**Purpose**: Reviews dependency changes in pull requests for known vulnerabilities

**Triggers**: `pull_request`, `workflow_call`

**Features**:

* **Threshold**: Fails on moderate or higher severity vulnerabilities
* **PR Comments**: Automatically comments on PRs with vulnerability summary
* **Coverage**: Checks npm packages against GitHub Advisory Database
* **Integration**: Works with Dependabot alerts and security advisories

**Behavior**: Blocks PRs introducing vulnerable dependencies (moderate+ severity)

### Validation Workflows

#### `ps-script-analyzer.yml`

**Purpose**: Static analysis of PowerShell scripts using PSScriptAnalyzer

**Features**:

* Analyzes only changed PowerShell files
* Creates GitHub annotations for violations
* Exports JSON results and markdown summary
* Uploads artifacts with 30-day retention

**Exit Behavior**: Fails on Error or Warning severity issues

#### `frontmatter-validation.yml`

**Purpose**: Validates YAML frontmatter in markdown files

**Required Fields**:

* `title`, `description`, `author`, `ms.date`, `ms.topic`, `keywords`, `estimated_reading_time`

**Features**:

* Validates frontmatter format
* Checks footer format and copyright notice
* Creates GitHub annotations
* Exports JSON statistics

#### `markdown-link-check.yml`

**Purpose**: Validates all links in markdown files

**Features**:

* Checks internal and external links
* Retries failed links
* Creates GitHub annotations
* Generates detailed summaries

**Exit Behavior**: Soft-fail (sets failure status but continues)

#### `link-lang-check.yml`

**Purpose**: Detects URLs with language paths (e.g., `/en-us/`)

**Exit Behavior**: Warning only (does not fail workflow)

## Common Patterns

### Workflow Structure

All workflows follow a consistent pattern:

```yaml
name: Workflow Name
on:
  pull_request:
    paths:
      - '**/*.ext'
  workflow_dispatch:

permissions:
  contents: read

jobs:
  validate:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@<sha>  # v4.2.2
        with:
          persist-credentials: false
      - name: Setup environment
        # Install dependencies
      - name: Run validation
        # Execute validation script
      - name: Upload artifacts
        if: always()
        uses: actions/upload-artifact@<sha>  # v4
```

### Artifact Handling

* **Retention**: 30 days for all artifacts
* **Naming**: `{workflow-name}-results`
* **Contents**: JSON results, markdown summaries, logs
* **Condition**: `if: always()` to upload even on failure

### GitHub Annotations

All workflows create annotations in the format:

```text
::error file={file},line={line}::{message}
::warning file={file},line={line}::{message}
```

These appear in:

* PR files changed view
* Workflow run summary
* Checks tab

### Step Summaries

Workflows generate markdown summaries displayed in the workflow run:

* Overall status (passed/failed)
* Statistics (files checked, issues found)
* Tables of violations with file paths
* Links to artifacts

## Local Testing

### Security Scripts

```powershell
# Dependency pinning validation
.\scripts\security\Test-DependencyPinning.ps1 -Path .github/workflows -Verbose

# SHA staleness check
.\scripts\security\Test-SHAStaleness.ps1 -MaxAge 30 -OutputFormat github

# Update stale SHA pins
.\scripts\security\Update-ActionSHAPinning.ps1 -Path .github/workflows -UpdateStale
```

### Validation Scripts

```powershell
# PowerShell analysis
.\scripts\linting\Invoke-PSScriptAnalyzer.ps1 -ChangedFilesOnly

# Frontmatter validation
.\scripts\linting\Validate-MarkdownFrontmatter.ps1 -ChangedFilesOnly

# Link validation
.\scripts\linting\Markdown-Link-Check.ps1

# Language path check
.\scripts\linting\Invoke-LinkLanguageCheck.ps1
```

```bash
# Markdown linting
npm run lint:md

# Spell checking
npm run spell-check

# Table formatting
npm run format:tables
```

## Best Practices

### When to Extract a Reusable Workflow

Extract workflow logic to a reusable workflow when:

* The logic is duplicated across multiple workflows (DRY principle)
* The workflow performs a focused, reusable task (single responsibility)
* The workflow needs to be tested or maintained independently
* The workflow could benefit other projects or teams

**Do NOT extract** when:

* The logic is highly specific to a single workflow
* The extraction would create more complexity than it solves
* The workflow is fewer than 20 lines and unlikely to be reused

### Input and Output Design

**Inputs:**

* Use descriptive names with clear documentation
* Provide sensible defaults for optional inputs
* Use appropriate types (`string`, `number`, `boolean`)
* Consider `required: false` with defaults over `required: true`

**Outputs:**

* Export key metrics and results for downstream jobs
* Use consistent naming conventions across workflows
* Include both raw values and computed flags (e.g., `count` and `has-items`)

Example:

```yaml
workflow_call:
  inputs:
    max-age-days:
      description: 'Maximum SHA age in days before considered stale'
      required: false
      type: number
      default: 30
  outputs:
    stale-count:
      description: 'Number of stale SHA pins found'
      value: ${{ jobs.check.outputs.stale-count }}
    has-stale:
      description: 'Whether any stale SHA pins were found'
      value: ${{ jobs.check.outputs.has-stale }}
```

### Permissions

* Declare minimal required permissions at workflow and job levels
* Use `permissions: {}` to disable all permissions when not needed
* Escalate permissions only where necessary (e.g., `security-events: write` for SARIF upload)

Example:

```yaml
permissions:
  contents: read
  security-events: write  # Required for SARIF upload
```

### Security Considerations

* All actions MUST be pinned to SHA commits (not tags or branches)
* Include SHA comment showing the tag/version (e.g., `# v4.2.2`)
* Use Harden Runner for audit logging
* Disable credential persistence when checking out code: `persist-credentials: false`

## Troubleshooting

### "Unable to find reusable workflow" error

This lint error appears in VS Code but workflows run correctly on GitHub. The editor cannot resolve local workflow files at edit time. Ignore this error if:

* The workflow file exists at the specified path
* The workflow has a `workflow_call` trigger
* The workflow runs successfully on GitHub

### Outputs not available in downstream jobs

Ensure outputs are defined at three levels:

1. Step outputs: `echo "key=value" >> $GITHUB_OUTPUT`
2. Job outputs: `outputs.key: ${{ steps.step-id.outputs.key }}`
3. Workflow outputs: `outputs.key: ${{ jobs.job-id.outputs.key }}`

### SARIF upload failures

SARIF uploads require:

* `security-events: write` permission
* SARIF file generated by the scanner
* Valid SARIF format (JSON schema validation)

Use `continue-on-error: true` to prevent workflow failure on SARIF upload issues.

### Workflow Fails But Local Test Passes

* Check environment differences (Node.js version, PowerShell version)
* Verify all dependencies are installed in workflow
* Review workflow logs for specific error messages

### Artifacts Not Uploading

* Ensure `if: always()` condition is present
* Verify artifact path exists before upload
* Check for file permission issues

### Annotations Not Appearing

* Verify annotation format: `::error file={file},line={line}::{message}`
* Ensure file paths are relative to repository root
* Check that workflow has write permissions

## Configuration Files

| File | Purpose | Used By |
|------|---------|---------|
| `scripts/linting/PSScriptAnalyzer.psd1` | PowerShell linting rules | ps-script-analyzer.yml |
| `.markdownlint.json` | Markdown formatting rules | markdown-lint.yml |
| `scripts/linting/markdown-link-check.config.json` | Link checking configuration | markdown-link-check.yml |
| `.cspell.json` | Spell checking configuration | spell-check.yml |
| `.github/instructions/markdown.instructions.md` | Markdown style guide | All markdown workflows |
| `.github/instructions/commit-message.instructions.md` | Commit message standards | All workflows (informative) |

## Maintenance

### Updating SHA Pins

Keep action SHA pins up-to-date using the provided script:

```powershell
# Update all stale SHA pins
scripts/security/Update-ActionSHAPinning.ps1 -Path .github/workflows -UpdateStale

# Dry-run to see what would be updated
scripts/security/Update-ActionSHAPinning.ps1 -Path .github/workflows -WhatIf
```

### Adding New Workflows

When adding a new workflow:

1. Follow the naming convention (`*-scan.yml`, `*-check.yml`, or `*-lint.yml`)
2. Pin all actions to SHA commits
3. Include Harden Runner as the first step (security workflows)
4. Document inputs, outputs, and purpose
5. Add appropriate triggers (pull_request paths, workflow_dispatch)
6. Implement artifact uploads with 30-day retention
7. Create GitHub annotations for violations
8. Generate step summary with results
9. Support local testing with corresponding script
10. Update this README with the new workflow entry
11. Test thoroughly before merging

## Related Documentation

* [Linting Scripts Documentation](../../scripts/linting/README.md)
* [Security Scripts Documentation](../../scripts/security/)
* [Scripts Documentation](../../scripts/README.md)
* [Contributing Guidelines](../../CONTRIBUTING.md)

## Resources

* [GitHub Actions: Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
* [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
* [GitHub Actions: Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
* [SARIF specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)

---

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
