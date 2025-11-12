# GitHub Actions Workflows

This directory contains GitHub Actions workflows for the HVE Core project. Workflows are organized by purpose and follow established naming conventions.

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

* **Orchestrator workflows**: Compose multiple reusable workflows
  * Example: `weekly-security-maintenance.yml`
  * Purpose: Run multiple security checks and generate consolidated reports
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

| Workflow | Type | Purpose | Triggers |
|----------|------|---------|----------|
| `weekly-security-maintenance.yml` | Orchestrator | Weekly security posture check | `schedule`, `workflow_dispatch` |
| `dependency-pinning-scan.yml` | Reusable | Validate SHA pinning compliance | `workflow_call` |
| `sha-staleness-check.yml` | Reusable | Check for stale SHA pins | `schedule`, `workflow_dispatch`, `workflow_call` |
| `gitleaks-scan.yml` | Reusable | Secret detection scan | `workflow_call` |
| `checkov-scan.yml` | Reusable | Infrastructure-as-Code security scan | `workflow_call` |
| `gitleaks.yml` | Standalone | Legacy secret detection | `push`, `pull_request` |

## Using Reusable Workflows

### Basic Usage

Call a reusable workflow from another workflow using the `uses` keyword:

```yaml
jobs:
  security-scan:
    name: Run Security Scan
    uses: ./.github/workflows/gitleaks-scan.yml
    permissions:
      contents: read
      security-events: write
    with:
      soft-fail: true
      upload-sarif: true
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

1. Follow the naming convention (`*-scan.yml` or `*-check.yml`)
2. Pin all actions to SHA commits
3. Include Harden Runner as the first step
4. Document inputs, outputs, and purpose
5. Update this README with the new workflow entry

## Resources

* [GitHub Actions: Reusing workflows](https://docs.github.com/en/actions/using-workflows/reusing-workflows)
* [GitHub Actions: Workflow syntax](https://docs.github.com/en/actions/using-workflows/workflow-syntax-for-github-actions)
* [GitHub Actions: Security hardening](https://docs.github.com/en/actions/security-guides/security-hardening-for-github-actions)
* [SARIF specification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html)
