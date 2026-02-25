---
description: "Required instructions for GitHub Actions workflow files in hve-core repository"
applyTo: '**/.github/workflows/*.yml'

---

# GitHub Actions Workflow Instructions

These instructions define required conventions and security requirements for GitHub Actions workflows in the hve-core repository. All workflows MUST comply with these rules to pass CI validation.

## Dependency Pinning

All third-party GitHub Actions MUST be pinned to a full commit SHA. Version tags MUST NOT be used as the reference. A semantic version MAY be included as a trailing comment for readability.

**Required pattern:**

```yaml
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

**Forbidden patterns:**

```yaml
uses: actions/checkout@v4
uses: actions/checkout@v4.2.2
```

Local reusable workflows referenced via relative paths are excluded from SHA pinning requirements.

**Enforcement:** Violations are detected by `scripts/security/Test-DependencyPinning.ps1` and `scripts/security/Test-SHAStaleness.ps1`. CI will fail on SHA pinning violations.

## Permissions

Workflows MUST declare explicit permissions following the principle of least privilege. The default permission set is `contents: read`. Additional permissions MUST be granted at the job level and only when required for a specific capability.

**Required pattern:**

```yaml
permissions:
  contents: read
  pull-requests: write
```

**Job-level permissions example:**

```yaml
jobs:
  validate:
    name: Validate Code
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - name: Run validation
        run: |
          echo "Running validation steps"
```

**Enforcement:** Violations are detected by `scripts/security/Test-WorkflowPermissions.ps1`. CI will fail on workflows missing a top-level `permissions:` block. The `copilot-setup-steps.yml` workflow is excluded by default.

## Credentials and Secrets

Workflows MUST NOT persist GitHub credentials by default. Credential persistence MUST be enabled only when explicitly required for a specific capability. Secrets and tokens MUST be granted explicitly and scoped to the minimum required permissions.

**Required pattern:**

```yaml
- name: Checkout code
  uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
  with:
    persist-credentials: false
```

**Secret handling:**

```yaml
- name: Use secret
  env:
    MY_SECRET: ${{ secrets.MY_SECRET }}
  run: |
    # Use $MY_SECRET securely
```

## Runners

Workflows MUST run on GitHub-hosted Ubuntu runners. Other runner types are not supported in hve-core.

**Required pattern:**

```yaml
runs-on: ubuntu-latest
```

## Workflow Structure

Workflows MUST follow these structural expectations:

- Use descriptive names for workflows and jobs
- Group related jobs with `needs:` dependencies
- Use `concurrency:` to prevent duplicate runs
- Prefer reusable workflows for common patterns

**Required structure example:**

```yaml
name: Descriptive Workflow Name

on:
  push:
    branches:
      - main
  pull_request:
    types: [opened, synchronize, reopened]
    branches:
      - main
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: false

permissions:
  contents: read

jobs:
  validate:
    name: Validate Code
    runs-on: ubuntu-latest
    permissions:
      contents: read
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - name: Run Validation
        run: |
          echo "Running validation steps"
```

## Reusable Workflows

### Defining Reusable Workflows

Reusable workflows MUST use `workflow_call` trigger and define explicit inputs and outputs.

**Reusable workflow definition:**

```yaml
name: Reusable Analysis Workflow

on:
  workflow_call:
    inputs:
      threshold:
        description: 'Compliance threshold percentage (0-100)'
        required: false
        type: number
      soft-fail:
        description: 'Whether to continue on violations'
        required: false
        type: boolean
      upload-sarif:
        description: 'Whether to upload SARIF results to Security tab'
        required: false
        type: boolean
    outputs:
      compliance-score:
        description: 'Compliance score percentage'
        value: ${{ jobs.scan.outputs.compliance-score }}
      unpinned-count:
        description: 'Number of unpinned dependencies found'
        value: ${{ jobs.scan.outputs.unpinned-count }}
      is-compliant:
        description: 'Whether repository meets compliance threshold'
        value: ${{ jobs.scan.outputs.is-compliant }}

permissions:
  contents: read

jobs:
  scan:
    name: Validate Compliance
    runs-on: ubuntu-latest
    permissions:
      contents: read
    outputs:
      compliance-score: ${{ steps.analyze.outputs.compliance-score }}
      unpinned-count: ${{ steps.analyze.outputs.unpinned-count }}
      is-compliant: ${{ steps.analyze.outputs.is-compliant }}
    steps:
      - name: Checkout
        uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      - name: Run Analysis
        id: analyze
        run: |
          echo "compliance-score=95" >> $GITHUB_OUTPUT
          echo "unpinned-count=2" >> $GITHUB_OUTPUT
          echo "is-compliant=true" >> $GITHUB_OUTPUT
```

### Consuming Reusable Workflows

Reusable workflows MUST be called using relative paths with explicit permissions and inputs.

**Example usage:**

```yaml
name: PR Validation Workflow

on:
  pull_request:
    branches: [main]

permissions:
  contents: read

jobs:
  validate-pinning:
    name: Validate Dependency Pinning
    uses: ./.github/workflows/dependency-pinning-scan.yml
    permissions:
      contents: read
      security-events: write
    with:
      soft-fail: false
      upload-sarif: true
```

## Validation Requirements

All workflows MUST pass the following validation checks:

### actionlint Validation

- **What it enforces:** Syntax validation, best practices, and security checks
- **Configuration:** Uses actionlint with SHA256 verification
- **CI blocking:** Workflows fail CI if violations are detected

### Dependency Pinning Validation

- **Script:** `scripts/security/Test-DependencyPinning.ps1`
- **What it enforces:** All third-party actions use full SHA pins
- **CI blocking:** Failures block CI when configured to enforce compliance

### SHA Staleness Validation

- **Script:** `scripts/security/Test-SHAStaleness.ps1`
- **What it enforces:** SHA-pinned dependencies are not stale
- **CI blocking:** Stale dependencies generate warnings and may fail CI

### Workflow Permissions Validation

- **Script:** `scripts/security/Test-WorkflowPermissions.ps1`
- **What it enforces:** All workflows declare a top-level `permissions:` block
- **CI blocking:** Failures block CI when configured to enforce compliance

## Security Requirements

- Never expose secrets in logs or outputs
- No personal access tokens (PATs) are used in workflows
- Use event guards for release-specific operations when needed
- Enable security features like CodeQL and dependency scanning
- All security workflows use explicit, minimal permissions

**Example event guard pattern:**

```yaml
- name: Process Release
  run: |
    if [ "${{ github.event_name }}" == "release" ]; then
      VERSION="${{ github.event.release.tag_name }}"
      echo "Processing release: $VERSION"
    else
      VERSION="${{ inputs.version }}"
      echo "Processing version: $VERSION"
    fi
```

## YAML Expression Quoting

GitHub Actions expression single quotes (`'...'`) inside `${{ }}` are NOT YAML quotes. The YAML parser treats them as literal characters in a plain scalar. If the expression text contains a colon followed by whitespace (`:`&nbsp;), the YAML parser interprets it as a mapping value indicator and fails with `mapping values are not allowed in this context`.

**Problem pattern:**

```yaml
# FAILS: ': release' contains colon-space, YAML parser chokes
with:
  my-input: ${{ startsWith(value, 'prefix: release') }}
```

**Acceptable solutions (in preference order):**

1. **Shorten the literal to avoid colon-space.** Use a prefix that does not contain a colon followed by whitespace when the specificity tradeoff is acceptable.

    ```yaml
    with:
      my-input: ${{ startsWith(value, 'prefix') }}
    ```

2. **Double-quote the entire expression.** This makes the value a YAML quoted scalar, preventing the parser from interpreting internal colon-space as structure. Add a comment explaining why quotes are required.

    ```yaml
    with:
      # Quotes required: expression literal contains ': ' which breaks YAML plain scalars
      my-input: "${{ startsWith(value, 'prefix: release') }}"
    ```

Avoid `format()` workarounds or environment variable indirection when the simpler options above apply.

## Enforcement Statement

The following scripts enforce compliance:

- `scripts/security/Test-DependencyPinning.ps1` - Validates SHA pinning
- `scripts/security/Test-SHAStaleness.ps1` - Checks for stale dependencies
- `scripts/security/Test-WorkflowPermissions.ps1` - Validates workflow permissions declarations
- `scripts/linting/Invoke-YamlLint.ps1` - Runs actionlint validation

All workflows must pass these validation checks to be merged into the repository.
