---
title: GitHub Actions Workflows
description: Modular CI/CD workflow architecture for validation, security scanning, and automated maintenance
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - github actions
  - ci/cd
  - workflows
  - security scanning
  - automation
  - reusable workflows
estimated_reading_time: 12
---

# GitHub Actions Workflows

This directory contains GitHub Actions workflows for continuous integration, security scanning, and automated maintenance of the `hve-core` repository.

## Architecture

This repository uses a **modular GitHub Actions workflow architecture** based on the **Single Responsibility Principle**. Each reusable workflow focuses on one specific validation or security tool, making the system maintainable, testable, and flexible.

**Benefits**:

* **29% faster** execution (210s → 150s) via parallel execution
* **Better maintainability** - Each workflow has one clear purpose
* **Enhanced security** - Workflow isolation, minimal permissions per tool
* **Greater flexibility** - Compose any combination of checks
* **Improved testability** - Test and debug each tool independently

## Workflows

### Modular Reusable Workflows

#### Validation Workflows

##### `spell-check.yml`

Spell checking using cspell.

**Purpose**: Validate spelling across markdown, code, and configuration files.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on spell check errors

**Permissions**: `contents: read`

**Result Publishing**:

* PR annotations for errors
* Artifact: `spell-check-results` (30-day retention)
* Job summary with pass/fail status

**Usage**:

```yaml
jobs:
  spell-check:
    uses: ./.github/workflows/spell-check.yml
    with:
      soft-fail: false
```

##### `markdown-lint.yml`

Markdown linting using markdownlint-cli.

**Purpose**: Enforce markdown formatting standards and best practices.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on linting violations

**Permissions**: `contents: read`

**Result Publishing**:

* PR annotations for violations
* Artifact: `markdown-lint-results` (30-day retention)
* Job summary with pass/fail status

**Usage**:

```yaml
jobs:
  markdown-lint:
    uses: ./.github/workflows/markdown-lint.yml
    with:
      soft-fail: false
```

##### `table-format.yml`

Table formatting validation using markdown-table-formatter (CHECK ONLY mode).

**Purpose**: Verify markdown tables are properly formatted. Does NOT auto-fix.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on format issues

**Permissions**: `contents: read`

**Result Publishing**:

* PR annotations with manual fix instructions
* Artifact: `table-format-results` (30-day retention)
* Job summary with manual fix guidance

**Usage**:

```yaml
jobs:
  table-format:
    uses: ./.github/workflows/table-format.yml
    with:
      soft-fail: false
```

##### `psscriptanalyzer.yml`

PowerShell static analysis using PSScriptAnalyzer.

**Purpose**: Enforce PowerShell best practices and detect common issues.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on violations
* `changed-files-only` (boolean, default: true) - Analyze only changed files

**Permissions**: `contents: read`

**Result Publishing**:

* Error annotations for violations
* Artifact: `psscriptanalyzer-results` (JSON + markdown, 30-day retention)
* Job summary with violation details

**Usage**:

```yaml
jobs:
  psscriptanalyzer:
    uses: ./.github/workflows/psscriptanalyzer.yml
    with:
      soft-fail: false
      changed-files-only: true
```

##### `frontmatter-validation.yml`

Markdown frontmatter and footer validation.

**Purpose**: Ensure consistent YAML frontmatter metadata across documentation.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on validation failures
* `changed-files-only` (boolean, default: true) - Validate only changed files
* `skip-footer-validation` (boolean, default: false) - Skip footer checks
* `warnings-as-errors` (boolean, default: true) - Treat warnings as errors

**Permissions**: `contents: read`

**Result Publishing**:

* Error/warning annotations on specific lines
* Artifact: `frontmatter-validation-results` (30-day retention)
* Job summary with validation status

**Usage**:

```yaml
jobs:
  frontmatter-validation:
    uses: ./.github/workflows/frontmatter-validation.yml
    with:
      soft-fail: false
      changed-files-only: true
      skip-footer-validation: false
      warnings-as-errors: true
```

##### `link-lang-check.yml`

Detects URLs with language paths (e.g., `/en-us/`) in markdown files.

**Purpose**: Ensure language-agnostic URLs for better internationalization.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on language path detection

**Permissions**: `contents: read`

**Result Publishing**:

* Warning annotations on files with language paths
* Artifact: `link-lang-check-results` (JSON + markdown, 30-day retention)
* Job summary with fix instructions

**Usage**:

```yaml
jobs:
  link-lang-check:
    uses: ./.github/workflows/link-lang-check.yml
    with:
      soft-fail: false
```

##### `markdown-link-check.yml`

Validates all links in markdown files using markdown-link-check npm package.

**Purpose**: Detect broken internal and external links before deployment.

**Inputs**:

* `soft-fail` (boolean, default: true) - Continue on link failures (recommended for external link flakiness)

**Permissions**: `contents: read`

**Result Publishing**:

* Error annotations for broken links
* Artifact: `markdown-link-check-results` (30-day retention)
* Job summary with broken link details

**Usage**:

```yaml
jobs:
  markdown-link-check:
    uses: ./.github/workflows/markdown-link-check.yml
    with:
      soft-fail: true
```

#### Security Workflows

##### `gitleaks-scan.yml`

Secret scanning using Gitleaks.

**Purpose**: Detect exposed secrets, credentials, and API keys in repository.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on secret detection
* `upload-sarif` (boolean, default: false) - Upload results to Security tab

**Permissions**: `contents: read`, `security-events: write`

**Result Publishing**:

* Error annotations for detected secrets
* Artifact: `gitleaks-results` (30-day retention)
* Job summary with security alert guidance
* Optional: SARIF upload to Security tab

**Usage**:

```yaml
jobs:
  gitleaks-scan:
    uses: ./.github/workflows/gitleaks-scan.yml
    permissions:
      contents: read
      security-events: write
    with:
      soft-fail: true
      upload-sarif: false
```

##### `checkov-scan.yml`

Infrastructure as Code (IaC) security scanning using Checkov.

**Purpose**: Detect security misconfigurations in workflows, JSON, YAML, and secrets.

**Inputs**:

* `soft-fail` (boolean, default: false) - Continue on violations
* `upload-sarif` (boolean, default: false) - Upload results to Security tab

**Permissions**: `contents: read`, `security-events: write`

**Result Publishing**:

* Warning annotations for violations
* Artifacts: `checkov-results` (SARIF + text, 30-day retention)
* Job summary with scanned frameworks list
* Optional: SARIF upload to Security tab

**Usage**:

```yaml
jobs:
  checkov-scan:
    uses: ./.github/workflows/checkov-scan.yml
    permissions:
      contents: read
      security-events: write
    with:
      soft-fail: false
      upload-sarif: true
```

### Core Workflows

#### `pr-validation.yml`

Validates pull requests before merge with soft-fail security scanning.

**Triggers**:

* Pull requests to `main` branch
* Manual workflow dispatch

**Behavior**:

* Runs all 9 modular workflows in parallel
* Validation checks: strict mode (soft-fail: false)
* Security scans: soft-fail mode (soft-fail: true)
* Results uploaded as artifacts (upload-sarif: false)
* Must pass for PR to be mergeable (via branch protection)

**Jobs**: `spell-check`, `markdown-lint`, `table-format`, `psscriptanalyzer`, `frontmatter-validation`, `link-lang-check`, `markdown-link-check`, `gitleaks-scan`, `checkov-scan`

#### `main.yml`

Validates code after merge to main branch with strict security scanning.

**Triggers**:

* Push to `main` branch
* Manual workflow dispatch

**Behavior**:

* Runs all 9 modular workflows in parallel
* All checks: strict mode (soft-fail: false)
* Security scans: SARIF uploads enabled (upload-sarif: true)
* Provides post-merge validation and security monitoring

**Jobs**: `spell-check`, `markdown-lint`, `table-format`, `psscriptanalyzer`, `frontmatter-validation`, `link-lang-check`, `markdown-link-check`, `gitleaks-scan`, `checkov-scan`

#### `weekly-security-maintenance.yml`

Weekly security maintenance and dependency health monitoring.

**Triggers**: Weekly schedule (Sundays at 2 AM UTC), manual workflow dispatch

**Behavior**:

* Validates SHA pinning compliance (`Test-DependencyPinning.ps1`)
* Checks for stale SHA pins >30 days (`Test-SHAStaleness.ps1`)
* Runs Gitleaks and Checkov security scans with SARIF uploads
* Generates consolidated security health report
* All issues reported as warnings (non-blocking)

**Outputs**: Comprehensive job summary with health dashboard, downloadable JSON reports (90-day retention)

### Legacy Workflows

#### `reusable-validation.yml` (DEPRECATED)

⚠️ **Deprecated as of 2024-11-04**. Replaced by 9 modular workflows. See `pr-validation.yml` and `main.yml` for migration examples.

#### `sha-staleness-check.yml`

⚠️ **Functionality integrated into `weekly-security-maintenance.yml`**. May be deprecated in the future.

#### `gitleaks.yml`

⚠️ **Standalone trigger workflow**. Runs Gitleaks on push/PR to `main`/`develop`. Functionality available via reusable `gitleaks-scan.yml` workflow called by `pr-validation.yml` and `main.yml`.

## Workflow Naming Convention

All reusable workflows follow the pattern: `{tool-name}.yml`

**Benefits**:

* **Discoverability**: Clear what each workflow does
* **Self-documenting**: Tool name indicates purpose
* **Scalability**: Easy to add new tools (e.g., `prettier-format.yml`)
* **No ambiguity**: Specific names eliminate confusion

## Result Publishing Strategy

Each modular workflow implements comprehensive 4-channel result publishing:

1. **PR Annotations**: Warnings/errors appear on Files Changed tab
2. **Artifacts**: Raw output files retained for 30 days
3. **SARIF Reports**: Security tab integration (security workflows only)
4. **Job Summaries**: Rich markdown summaries in Actions tab

## Performance

**Parallel Execution**: All 9 modular workflows run simultaneously.

**Measured Performance**:

* Previous monolithic workflow: ~210 seconds
* New modular workflows: ~150 seconds
* **Improvement**: 29% faster (60 seconds saved)

## Security Best Practices

All workflows in this repository follow security best practices:

### SHA Pinning

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

### Network Hardening

* `step-security/harden-runner` used in all jobs for egress policy auditing
* Egress policy set to `audit` mode for visibility

## Maintenance

### Updating SHA Pins

The repository includes PowerShell scripts in `scripts/security/` for SHA pinning maintenance:

* `Update-ActionSHAPinning.ps1` - Update GitHub Actions SHA pins
* `Update-DockerSHAPinning.ps1` - Update Docker image SHA pins
* `Update-ShellScriptSHAPinning.ps1` - Update shell script dependencies
* `Test-SHAStaleness.ps1` - Check for stale SHA pins
* `Test-DependencyPinning.ps1` - Validate SHA pinning compliance

### Dependabot Integration

Dependabot is configured to automatically create PRs for:

* GitHub Actions updates
* npm package updates
* Other dependency updates

The SHA staleness check workflow complements Dependabot by monitoring for stale pins between updates.

## Workflow Architecture

**New Modular Architecture** (Current):

```text
pr-validation.yml (PR trigger, soft-fail security)
    ├── spell-check → spell-check.yml
    ├── markdown-lint → markdown-lint.yml
    ├── table-format → table-format.yml
    ├── psscriptanalyzer → psscriptanalyzer.yml
    ├── frontmatter-validation → frontmatter-validation.yml
    ├── link-lang-check → link-lang-check.yml
    ├── markdown-link-check → markdown-link-check.yml (soft-fail)
    ├── gitleaks-scan → gitleaks-scan.yml (soft-fail)
    └── checkov-scan → checkov-scan.yml (soft-fail)
    (All jobs run in parallel)

main.yml (Push to main, strict security)
    ├── spell-check → spell-check.yml
    ├── markdown-lint → markdown-lint.yml
    ├── table-format → table-format.yml
    ├── psscriptanalyzer → psscriptanalyzer.yml
    ├── frontmatter-validation → frontmatter-validation.yml
    ├── link-lang-check → link-lang-check.yml
    ├── markdown-link-check → markdown-link-check.yml
    ├── gitleaks-scan → gitleaks-scan.yml (SARIF upload)
    └── checkov-scan → checkov-scan.yml (SARIF upload)
    (All jobs run in parallel)

weekly-security-maintenance.yml (Weekly, Sundays 2 AM UTC)
    ├── validate-pinning → Test-DependencyPinning.ps1
    ├── check-staleness → Test-SHAStaleness.ps1
    ├── gitleaks-scan → gitleaks-scan.yml (soft-fail, SARIF)
    ├── checkov-scan → checkov-scan.yml (soft-fail, SARIF)
    └── summary → Consolidated report

Standalone Triggers:
    ├── gitleaks.yml (Push/PR to main/develop)
    └── sha-staleness-check.yml (May be deprecated)
```

**Legacy Architecture** (Deprecated):

```text
pr-validation.yml / main.yml
    └── calls reusable-validation.yml (DEPRECATED)
            └── Combined all 9 checks sequentially
```

## Adding New Validation Tools

To add a new validation tool:

1. Create `{tool-name}.yml` following existing patterns
2. Implement 4-channel result publishing (annotations, artifacts, SARIF if security, summaries)
3. Add harden-runner and SHA pinning
4. Use minimal permissions
5. Add soft-fail input support
6. Update `pr-validation.yml` and `main.yml` to include new job
7. Document in this README

**Example**: Adding prettier formatting

```yaml
# .github/workflows/prettier-format.yml
name: Prettier Format

on:
  workflow_call:
    inputs:
      soft-fail:
        description: 'Whether to continue on format issues'
        required: false
        type: boolean
        default: false

permissions:
  contents: read

jobs:
  prettier-format:
    name: Prettier Format Check
    runs-on: ubuntu-latest
    steps:
      - name: Harden Runner
        uses: step-security/harden-runner@0080882f6c36860b6ba35c610c98ce87d4e2f26f # v2.10.2
      # ... implement pattern from existing workflows
```

## Related Documentation

* [BRANCH_PROTECTION.md](../BRANCH_PROTECTION.md) - Branch protection configuration
* [CODEOWNERS](../CODEOWNERS) - Code ownership definitions
* [Linting Scripts](../../scripts/linting/README.md) - PowerShell linting and validation scripts
* [Security Scripts](../../scripts/security/README.md) - SHA pinning automation

## Contributing

When adding or modifying workflows:

1. Follow SHA pinning conventions (full 40-char SHA with version comment)
2. Use minimal permissions principle
3. Add network hardening with `step-security/harden-runner`
4. Use `persist-credentials: false` in checkouts
5. Document inputs, outputs, and behavior in this README
6. Test workflows thoroughly before merging
7. Ensure CODEOWNERS approval for workflow changes

---

🤖 Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.
