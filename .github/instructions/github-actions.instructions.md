---
applyTo: '**/.github/workflows/*.yml'
description: 'Instructions for GitHub Actions workflow files - Brought to you by microsoft/hve-core'
maturity: stable
---

# GitHub Actions Workflow Instructions

These instructions define workflow conventions enforced by actionlint and security validation scripts in this codebase.

## Dependency Pinning (Required)

All action references MUST use full 40-character SHA pins, not version tags.

### Required Format

```yaml
# ✅ Correct - Full SHA with version comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
```

### Not Allowed

```yaml
# ❌ Wrong - Version tag only
uses: actions/checkout@v4
uses: actions/checkout@v4.2.2

# ❌ Wrong - No version comment
uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683
```

### Why SHA Pinning?

- **Security**: Prevents supply chain attacks via tag mutation
- **Reproducibility**: Guarantees identical behavior across runs
- **Auditability**: Clear record of exact code being executed

### Finding SHA Pins

```bash
# Get the commit SHA for a tag
git ls-remote --tags https://github.com/actions/checkout | grep "v4.2.2"

# Or visit the releases page and copy the commit SHA
```

## Permissions (Least Privilege)

Always define explicit `permissions:` at workflow or job level. Never use `permissions: write-all`.

### Workflow-Level Permissions

```yaml
name: CI Pipeline

permissions:
  contents: read  # Default for most workflows

jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      # ...
```

### Job-Level Permissions

```yaml
jobs:
  deploy:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      deployments: write
      id-token: write  # For OIDC authentication
    steps:
      # ...
```

### Common Permission Patterns

| Use Case | Permissions |
|----------|-------------|
| Read-only checkout | `contents: read` |
| Create releases | `contents: write` |
| Comment on PRs | `pull-requests: write` |
| Update PR status | `statuses: write`, `checks: write` |
| Push packages | `packages: write` |
| OIDC auth (Azure/AWS) | `id-token: write` |

## Workflow Structure

### Required Elements

```yaml
name: Descriptive Workflow Name  # Required

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

# Prevent duplicate runs
concurrency:
  group: ${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true  # false for main branch

permissions:
  contents: read  # Explicit permissions

jobs:
  job-name:
    name: Human Readable Job Name
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
```

### Job Dependencies

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps: # ...

  test:
    needs: build  # Runs after build completes
    runs-on: ubuntu-latest
    steps: # ...

  deploy:
    needs: [build, test]  # Runs after both complete
    if: github.ref == 'refs/heads/main'
    runs-on: ubuntu-latest
    steps: # ...
```

## Reusable Workflows

### Calling Reusable Workflows

```yaml
jobs:
  spell-check:
    name: Spell Check
    uses: ./.github/workflows/spell-check.yml  # Local reusable workflow
    permissions:
      contents: read
    with:
      soft-fail: false

  external-workflow:
    uses: organization/repo/.github/workflows/workflow.yml@11bd71901bbe5b1630ceea73d27597364c9af683
    with:
      input-param: value
    secrets:
      TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### Creating Reusable Workflows

```yaml
name: Reusable Lint Workflow

on:
  workflow_call:
    inputs:
      soft-fail:
        description: 'Continue on lint errors'
        required: false
        type: boolean
        default: false
    secrets:
      token:
        description: 'GitHub token'
        required: false

jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@11bd71901bbe5b1630ceea73d27597364c9af683 # v4.2.2
      # ...
```

## Security Best Practices

### Secret Handling

```yaml
steps:
  - name: Use secret securely
    env:
      API_KEY: ${{ secrets.API_KEY }}  # ✅ Pass via environment
    run: |
      # Never echo secrets
      curl -H "Authorization: Bearer $API_KEY" https://api.example.com
```

### Input Validation

```yaml
steps:
  - name: Validate PR title
    if: github.event_name == 'pull_request'
    run: |
      # Validate before using untrusted input
      TITLE="${{ github.event.pull_request.title }}"
      if [[ ! "$TITLE" =~ ^(feat|fix|docs|chore): ]]; then
        echo "Invalid PR title format"
        exit 1
      fi
```

### Pull Request Guards

```yaml
jobs:
  deploy:
    # Only run on main branch, not PRs
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    
  pr-check:
    # Only run on PRs, not pushes
    if: github.event_name == 'pull_request'
```

### Prefer GITHUB_TOKEN

```yaml
steps:
  - name: Create comment
    uses: actions/github-script@60a0d83039c74a4aee543508d2ffcb1c3799cdea # v7.0.1
    with:
      github-token: ${{ secrets.GITHUB_TOKEN }}  # ✅ Use built-in token
      script: |
        // ...
```

## Validation Requirements

Workflows must pass these validation checks:

| Tool | Purpose | Config |
|------|---------|--------|
| actionlint | Syntax and best practices | `.github/actionlint.yaml` |
| Test-DependencyPinning.ps1 | SHA pinning compliance | `scripts/security/` |
| Test-SHAStaleness.ps1 | SHA freshness validation | `scripts/security/` |

### Running Validation Locally

```bash
# Install actionlint
brew install actionlint  # macOS
# or download from https://github.com/rhysd/actionlint

# Run actionlint
actionlint

# Run dependency pinning check
pwsh scripts/security/Test-DependencyPinning.ps1 -Path .github/workflows
```

## Common Patterns

### Matrix Builds

```yaml
jobs:
  test:
    strategy:
      fail-fast: false
      matrix:
        os: [ubuntu-latest, windows-latest, macos-latest]
        node: [18, 20, 22]
    runs-on: ${{ matrix.os }}
    steps:
      - uses: actions/setup-node@39370e3970a6d050c480ffad4ff0ed4d3fdee5af # v4.1.0
        with:
          node-version: ${{ matrix.node }}
```

### Conditional Steps

```yaml
steps:
  - name: Deploy to staging
    if: github.ref == 'refs/heads/develop'
    run: ./deploy.sh staging

  - name: Deploy to production
    if: github.ref == 'refs/heads/main' && github.event_name == 'push'
    run: ./deploy.sh production
```

### Artifact Upload/Download

```yaml
jobs:
  build:
    steps:
      - uses: actions/upload-artifact@b4b15b8c7c6ac21ea08fcf65892d2ee8f75cf882 # v4.4.3
        with:
          name: build-output
          path: dist/

  deploy:
    needs: build
    steps:
      - uses: actions/download-artifact@fa0a91b85d4f404e444e00e005971372dc801d16 # v4.1.8
        with:
          name: build-output
          path: dist/
```

## References

- Security validation: `scripts/security/Test-DependencyPinning.ps1`
- SHA staleness check: `scripts/security/Test-SHAStaleness.ps1`
- Tool checksums: `scripts/security/tool-checksums.json`
- Existing workflows: `.github/workflows/`
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [actionlint](https://github.com/rhysd/actionlint)
