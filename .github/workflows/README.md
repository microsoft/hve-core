---
title: GitHub Actions Workflows
description: Modular CI/CD workflow architecture for validation, security scanning, and automated maintenance
author: HVE Core Team
ms.date: 2026-08-19
ms.topic: reference
keywords:
  - github actions
  - ci/cd
  - workflows
  - security scanning
  - automation
  - reusable workflows
  - validation
  - security
estimated_reading_time: 25
---

This directory contains GitHub Actions workflows for continuous integration, security scanning, and automated maintenance of the `hve-core` repository.

## Overview

Workflows run automatically on pull requests, pushes to protected branches, and scheduled intervals. They enforce code quality standards, validate documentation, perform security scans, and ensure consistency across the codebase.

## Architecture

Modular reusable workflows following Single Responsibility Principle. Each workflow handles one specific tool or validation task.

## Workflow Organization

### Naming Conventions

| Pattern       | Purpose                          | Example                   |
|---------------|----------------------------------|---------------------------|
| `*-scan.yml`  | Security scanning, SARIF outputs | `codeql-analysis.yml`     |
| `*-check.yml` | Validation, compliance checking  | `markdown-link-check.yml` |
| `*-lint.yml`  | Code quality, formatting         | `markdown-lint.yml`       |
| Orchestrators | Compose multiple workflows       | `pr-validation.yml`       |

### Workflow Types

**Reusable** (`workflow_call`): Called by other workflows, accept inputs, expose outputs, single-task focused.

**Standalone** (`schedule`/`push`/`pull_request`): Run on events, may compose reusable workflows.

## Orchestrator Workflows

Compose multiple reusable workflows for comprehensive validation and security scanning.

| Workflow                          | Triggers                                                | Mode                          | Purpose                                                                                      |
|-----------------------------------|---------------------------------------------------------|-------------------------------|----------------------------------------------------------------------------------------------|
| `pr-validation.yml`               | PR to main, develop, or either release branch; dispatch | Strict validation             | Pre-merge quality gate with the `PR Validation Success` required-check aggregator            |
| `release-prerelease-prepare.yml`  | Merged PR to `main`; dispatch                           | Reviewed PreRelease promotion | Open the target-based `main` to `release/prerelease` promotion PR                            |
| `release-prerelease.yml`          | Merged PR to `release/prerelease`                       | Managed PreRelease release    | Prepare the managed release PR or publish the verified odd-minor release and VSIX assurance  |
| `release-stable.yml`              | Published PreRelease; dispatch                          | Reviewed Stable promotion     | Open the target-based `release/prerelease` to `release/stable` promotion PR                  |
| `release-stable-publish.yml`      | Merged PR to `release/stable`                           | Managed Stable release        | Prepare the managed release PR or publish the verified even-minor release and VSIX assurance |
| `weekly-security-maintenance.yml` | Schedule (Sun 2AM UTC)                                  | Soft-fail warnings            | Weekly security posture                                                                      |
| `scorecard.yml`                   | Push to main, Schedule (Sun 3AM UTC)                    | SARIF upload                  | OpenSSF Scorecard security posture                                                           |

The validation jobs in `pr-validation.yml` feed the `pr-validation-success` aggregator, which is the required merge signal. The `gate-completeness-check` job verifies that every validation job appears in that gate's `needs:` list.

release-stable.yml jobs: prepare-promotion, open-promotion-pr

release-stable-publish.yml jobs: validate-trigger, release-please, sync-release-pr, validate-release, close-milestone, extension-package-release, extension-provenance, generate-dependency-sbom, vex-attest, verify-provenance, sbom-diff, append-verification-notes, publish-release

release-prerelease-prepare.yml jobs: prepare-promotion, open-promotion-pr

release-prerelease.yml jobs: validate-trigger, release-please, sync-release-pr,
validate-release, close-milestone, extension-package-prerelease,
generate-dependency-sbom, extension-provenance-prerelease,
verify-provenance, publish-release

### Release Channel Contract

The reviewed branch ladder is `main` to `release/prerelease` to
`release/stable`. Each hop has two review boundaries: a promotion pull request
and a release-please managed pull request. Promotion preparation writes exact
release intent but creates no tag or release.

After release-please opens the managed pull request, `sync-release-pr`
synchronizes committed versions and removes the consumed `release-as`. Merging
the reviewed managed pull request runs release-please in tag-only mode.
Release-please is the sole tag writer:

* PreRelease creates `prerelease-v<version>`.
* Stable creates `v<version>`.

Release-please creates the draft channel release at the reviewed managed merge, and publication occurs after packaging and provenance verification complete.

| Registration                               | Repository contract                                    |
|--------------------------------------------|--------------------------------------------------------|
| `microsoft/hve-core`                       | Ref-less development-tip registration for `main`       |
| `microsoft/hve-core#release/prerelease`    | Moving registration for the reviewed PreRelease branch |
| `microsoft/hve-core#release/stable`        | Moving registration for the reviewed Stable branch     |
| `microsoft/hve-core#prerelease-v<version>` | Immutable exact PreRelease registration                |
| `microsoft/hve-core#v<version>`            | Immutable exact Stable registration                    |

Publication does not synchronize release metadata or changelog history back to `main`. An explicit marketplace refresh and plugin update are required for ref-less main, which has no release gate, SBOM, or attestation. Release-channel assets remain release-gated, SBOM-covered, and attested.

Both release channels preserve one VSIX, its SPDX, Sigstore, and in-toto sidecars, `dependencies.spdx.json`, provenance verification, and Azure OIDC publication. Stable additionally preserves `hve-core.openvex.json` and its attestations.

`extension-marketplace-publish.yml` has four jobs: `validate-inputs`, `verify`, `prepare-publisher`, and `publish`. Input validation resolves immutable release and protected-main commits before Marketplace environment activation. Verification downloads the one VSIX and checks its lane-specific attestation. Publisher preparation builds the minimal locked `vsce` toolchain from protected `main`. The protected publish job re-verifies provenance, obtains Azure OIDC, and invokes `vsce` directly.

Tag protection, Marketplace environment reviewers, and Azure OIDC claim policy remain external controls.

### Release Version Allocation

Ordinary version allocation is branch-owned and does not classify commits or
select an automatic patch, minor, or major release class. PreRelease reads its
current `release/prerelease` version and returns the same major, minor plus
two, and patch zero. Stable reads the promoted PreRelease version and returns
the promoted major, promoted minor plus one, and patch zero. Current Stable
state only rejects a candidate that does not advance it.

The ordinary sequence is `3.3.101` to `3.5.0` to `3.6.0`. The plugin manifest
and VSIX use the identical channel version. A major-line transition and a
Stable patch or hotfix each require a separate explicit manifest and
release-state decision. Odd/even minor parity remains repository policy
aligned with VS Code Marketplace guidance and behavior, rather than a
requirement of `MAJOR.MINOR.PATCH` syntax.

Release branches and exact tags retain the repository-root plugin source from their selected snapshots. Their reviewed, release-gated VSIX assets remain SBOM-covered, attested, and immutable. The ref-less main catalog instead sources current root `plugin.json` and canonical `.github` artifacts from `main` and has no published-release assurance.

Final publication mints a release GitHub App token and atomically runs
`gh release edit --prerelease --draft=false`; the resulting published event
triggers `Pre-Release Marketplace Publish`. Main remains a ref-less
development-tip channel and is not updated by release completion. Release
branches, immutable tags, and published releases own release state and history.

Hosted branch, tag, release, asset, workflow, and installed-client checks are
authorized manual actions. Local validation does not execute or verify them.

## Reusable Workflows

### Validation Workflows

| Workflow                     | Tool                     | Purpose                              | Key Inputs                                                                                                      | Artifacts                      |
|------------------------------|--------------------------|--------------------------------------|-----------------------------------------------------------------------------------------------------------------|--------------------------------|
| `spell-check.yml`            | cspell                   | Validate spelling across all files   | `soft-fail` (false)                                                                                             | spell-check-results            |
| `markdown-lint.yml`          | markdownlint-cli         | Enforce markdown standards           | `soft-fail` (false)                                                                                             | markdown-lint-results          |
| `table-format.yml`           | markdown-table-formatter | Verify table formatting (check-only) | `soft-fail` (false)                                                                                             | table-format-results           |
| `ps-script-analyzer.yml`     | PSScriptAnalyzer         | PowerShell static analysis           | `soft-fail` (false), `changed-files-only` (true)                                                                | psscriptanalyzer-results       |
| `frontmatter-validation.yml` | Custom PS script         | YAML frontmatter validation          | `soft-fail` (false), `changed-files-only` (true), `skip-footer-validation` (false), `warnings-as-errors` (true) | frontmatter-validation-results |
| `skill-validation.yml`       | Custom PS script         | Skill directory structure validation | `soft-fail` (false), `changed-files-only` (true)                                                                | skill-validation-results       |
| `link-lang-check.yml`        | Custom PS script         | Detect language-specific URLs        | `soft-fail` (false)                                                                                             | link-lang-check-results        |
| `markdown-link-check.yml`    | markdown-link-check      | Validate internal and external links | `soft-fail` (false), `changed-files-only` (true, external links only), `throttle-limit` (8)                     | markdown-link-check-results    |

Parenthesized values are the defaults declared by each reusable workflow, not the values its callers pass. Callers override them per lane: `pr-validation.yml` and `weekly-validation.yml` both invoke `markdown-link-check.yml` with `soft-fail: true`, and `weekly-validation.yml` additionally sets `changed-files-only: false` for the full-repository sweep.

All validation workflows use `permissions: contents: read`, publish PR annotations, and retain artifacts for 30 days.

Usage example:

```yaml
jobs:
  spell-check:
    uses: ./.github/workflows/spell-check.yml
    with:
      soft-fail: false
```

## Workflow Result Publishing Strategy

Each modular workflow implements comprehensive 4-channel result publishing:

1. PR Annotations: Warnings/errors appear on Files Changed tab
2. Artifacts: Raw output files retained for 30 days
3. SARIF Reports: Security tab integration (security workflows only)
4. Job Summaries: Rich markdown summaries in Actions tab

## Security Best Practices

All workflows in this repository follow security best practices:

### Dependency Pinning

* All GitHub Actions use full 40-character commit SHAs
* Comments include semantic version tags for human readability
* Example: `uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2`

### Minimal Permissions

* Workflows use minimal permissions by default (`contents: read`)
* Additional permissions granted only when required for specific jobs
* Example: `security-events: write` only for SARIF uploads

### Credential Protection

* `persist-credentials: false` used in checkouts to prevent credential leakage
* Secrets inherited explicitly with `secrets: inherit`
* No hardcoded tokens or credentials

## Maintenance

### Updating SHA Pins

The repository includes PowerShell scripts in `scripts/security/` for SHA pinning maintenance:

* `Update-ActionSHAPinning.ps1` - Update GitHub Actions SHA pins
* `Update-DockerSHAPinning.ps1` - Update Docker image SHA pins
* `Update-ShellScriptSHAPinning.ps1` - Update shell script dependencies
* `Test-SHAStaleness.ps1` - Check for stale SHA pins
* `Test-DependencyPinning.ps1` - Validate dependency pinning compliance

### Dependabot Integration

Dependabot is configured to automatically create PRs for:

* GitHub Actions updates
* npm package updates
* Other dependency updates

The SHA staleness check workflow complements Dependabot by monitoring for stale pins between updates.

## Security Workflows

### Reusable Security Workflows

#### `codeql-analysis.yml`

Purpose: Performs comprehensive security analysis using GitHub CodeQL

Triggers: `schedule` (Sundays at 4 AM UTC), `workflow_call`

Features:

* Languages: `actions` (GitHub Actions workflows), `python` (Python scripts), and `javascript-typescript` (VS Code extension source)
* Queries: security-extended and security-and-quality query suites
* Coverage: Detects SQL injection, XSS, command injection, path traversal, and 200+ other vulnerabilities
* Integration: Results appear in Security > Code Scanning tab
* Auto-build: Prepares compiled code where required for each language target; Actions analysis needs no compilation

Outputs: SARIF results uploaded to GitHub Security tab, job summary with analysis details

#### `dangerous-workflow-scan.yml`

Purpose: Combines a blocking workflow-injection gate with an advisory Poutine
supply-chain scan for GitHub Actions workflows.

Jobs:

* `dangerous-workflow-check`: Runs `Test-DangerousWorkflow.ps1` as the blocking homegrown gate and uploads SARIF under the `dangerous-workflow` category
* `poutine-scan`: Runs Poutine as an advisory scan by default and uploads SARIF under the `poutine` category

Rules enforced by the homegrown gate:

* `dangerous-workflow/template-injection`: attacker-controllable `github.event.*` and `github.head_ref` values interpolated into `run:` or `actions/github-script` bodies
* `dangerous-workflow/direct-input-interpolation`: caller-controlled `workflow_call` or `workflow_dispatch` inputs interpolated into the same bodies (control CQ-6). Inputs declared `type: boolean` are the only exception; an input whose declared type cannot be resolved is reported so the gate fails closed. Route every other input through a step-level `env:` mapping named `INPUT_<UPPER_SNAKE>` and read the native shell variable inside the block

Both rules scan `.github/workflows` and `.github/actions`. Composite action inputs have no `type` in the action metadata schema, so any action input reaching a `runs.steps[*].run` body is reported as `untyped` with no exception.

Inputs:

* `soft-fail` (boolean, default: false): Continue when the homegrown gate finds violations
* `poutine-soft-fail` (boolean, default: true): Keep Poutine findings advisory
* `upload-sarif` (boolean, default: true): Upload both scanners' SARIF results to the Security tab
* `upload-artifact` (boolean, default: true): Retain both scanners' result artifacts

Outputs:

* `violation-count`: Number of findings from the homegrown gate
* `is-compliant`: Whether the homegrown gate found no violations

`pr-validation.yml` calls this workflow as the blocking `dangerous-workflow-check`
required-check dependency. That call keeps the homegrown gate strict while explicitly
setting Poutine to advisory mode.

#### `dependency-review.yml`

Purpose: Reviews dependency changes in pull requests for known vulnerabilities

Triggers: `pull_request`, `workflow_call`

Features:

* Threshold: Fails on moderate or higher severity vulnerabilities
* PR Comments: Automatically comments on PRs with vulnerability summary
* Coverage: Checks npm packages against GitHub Advisory Database
* Integration: Works with Dependabot alerts and security advisories

Behavior: Blocks PRs introducing vulnerable dependencies (moderate+ severity)

#### `dependency-pinning-scan.yml`

Purpose: Validates that all GitHub Actions use SHA-pinned versions

Inputs:

* `threshold` (number, default: 95): Minimum compliance percentage
* `dependency-types` (string, default: 'actions,containers'): Types to validate
* `soft-fail` (boolean, default: false): Continue on failures
* `upload-sarif` (boolean, default: false): Upload to Security tab
* `upload-artifact` (boolean, default: true): Upload JSON results

Outputs:

* `compliance-score`: Percentage of dependencies properly pinned
* `unpinned-count`: Number of unpinned dependencies
* `is-compliant`: Boolean indicating threshold met

#### `sha-staleness-check.yml`

Purpose: Detects outdated GitHub Action SHA pins

Inputs:

* `max-age-days` (number, default: 30): Maximum age before stale

Outputs:

* `stale-count`: Number of stale SHA pins
* `has-stale`: Boolean indicating stale pins found

Severity Levels:

* Info: 0-30 days
* Low: 31-90 days
* Medium: 91-180 days
* High: 181-365 days
* Critical: >365 days

#### `scorecard.yml`

Purpose: Performs OpenSSF Scorecard analysis for security posture assessment

Triggers: `schedule` (Sundays at 3 AM UTC), `push` to main

Features:

* Analysis: Supply chain security, CI/CD best practices, code review practices
* Integration: Results published to OpenSSF Scorecard API and GitHub Security tab
* Badge: Live Scorecard badge available for README display
* Artifacts: SARIF results retained for 90 days

Outputs: SARIF results uploaded to GitHub Security tab, job summary with badge link

## Architecture Decisions

### CodeQL Execution Strategy

**Previous Behavior:** CodeQL previously ran as both a standalone workflow (on PR/push events) AND within orchestrator workflows, causing duplicate analyses on the same commits and wasting GitHub Actions minutes.

**Current Architecture:** CodeQL now runs through dedicated entrypoint workflows to prevent duplicate runs and ensure consistent security scanning:

* CodeQL PR validation: Runs via `pr-validation.yml` on all PR activity (open, push, reopen)
* Main branch: Runs via `security-scan.yml` on pushes to `main` and `develop`, which calls the reusable workflow `codeql-analysis.yml`
* Weekly scan: Standalone scheduled run every Sunday at 4 AM UTC for continuous security monitoring
* `release-stable.yml` does not run CodeQL

This architecture ensures:

* CodeQL does not run duplicate analyses on the same commit (previously executed both standalone and within orchestrators)
* Comprehensive security coverage across all code paths
* Clear ownership of when and why CodeQL executes
* Reduced GitHub Actions minutes consumption

Workflow Execution Matrix:

| Event                                | Workflows That Run                                       | CodeQL Included                                          |
|--------------------------------------|----------------------------------------------------------|----------------------------------------------------------|
| Open PR to main/develop              | `pr-validation.yml`                                      | ✅ Yes                                                    |
| Push to PR branch                    | `pr-validation.yml`                                      | ✅ Yes                                                    |
| Merge to main                        | `release-prerelease-prepare.yml`, `security-scan.yml`    | ✅ Yes (via `security-scan.yml` -> `codeql-analysis.yml`) |
| Sunday 4AM UTC                       | `codeql-analysis.yml`, `weekly-security-maintenance.yml` | ✅ Yes (standalone)                                       |
| Feature branch push (no open PR)[^1] | None                                                     | ❌ No                                                     |

[^1]: Feature branches without an open PR are not validated. Open a PR to main or develop to trigger validation workflows.

## Adding New Workflows

To add a new workflow to the repository:

1. Create `{tool-name}.yml` following existing patterns
2. Implement 4-channel result publishing (annotations, artifacts, SARIF if security, summaries)
3. Use dependency pinning for all dependencies
4. Use minimal permissions
5. Add soft-fail input support
6. Update each applicable validation orchestrator to include the new job
7. Document in this README

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

* Retention: 30 days for all artifacts
* Naming: `{workflow-name}-results`
* Contents: JSON results, markdown summaries, logs
* Condition: `if: always()` to upload even on failure

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

| File                                                           | Purpose                      | Used By                     |
|----------------------------------------------------------------|------------------------------|-----------------------------|
| `scripts/linting/PSScriptAnalyzer.psd1`                        | PowerShell linting rules     | `ps-script-analyzer.yml`    |
| `.markdownlint.json`                                           | Markdown formatting rules    | `markdown-lint.yml`         |
| `scripts/linting/markdown-link-check.config.json`              | Link checking configuration  | `markdown-link-check.yml`   |
| `.cspell.json`                                                 | Spell checking configuration | `spell-check.yml`           |
| `.github/instructions/hve-core/markdown.instructions.md`       | Markdown style guide         | All markdown workflows      |
| `.github/instructions/hve-core/commit-message.instructions.md` | Commit message standards     | All workflows (informative) |

## Resources

* [GitHub Actions: Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
* [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
* [GitHub Actions: Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
* [SARIF specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
