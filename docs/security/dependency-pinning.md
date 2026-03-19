---
title: Dependency Pinning
description: How HVE Core enforces dependency pinning across GitHub Actions, npm, pip, and shell downloads with automated CI validation
sidebar_position: 3
author: Microsoft
ms.date: 2026-03-02
ms.topic: concept
keywords:
  - dependency pinning
  - supply chain security
  - npm
  - pip
  - github actions
estimated_reading_time: 8
---

## Overview

HVE Core enforces dependency pinning to mitigate supply chain attacks. Every dependency reference in the repository must resolve to a specific, immutable version. The `Test-DependencyPinning.ps1` scanner validates all dependency types during CI and produces SARIF reports for GitHub code scanning integration.

| Dependency Type       | Pinning Strategy             | Example                                                     |
|-----------------------|------------------------------|-------------------------------------------------------------|
| GitHub Actions        | Full 40-character commit SHA | `actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29` |
| npm                   | Exact version (no ranges)    | `"eslint": "9.18.0"`                                        |
| pip                   | Exact version with `==`      | `requests==2.31.0`                                          |
| Workflow npm commands | `npm ci` enforcement         | `npm ci` instead of `npm install`                           |
| Shell downloads       | Checksum verification        | `sha256sum --check` after download                          |

## npm: Exact-Version Enforcement

> [!NOTE]
> npm dependencies use **exact-version enforcement** rather than SHA-pinning. Unlike GitHub Actions (where commit SHAs identify immutable source snapshots), npm packages are published as immutable registry artifacts. An exact version string like `9.18.0` is already a unique, deterministic reference.

### What Is Validated

The scanner rejects any version string that contains range operators or wildcards:

```json
{
  "dependencies": {
    "valid": "9.18.0",
    "invalid-caret": "^9.18.0",
    "invalid-tilde": "~9.18.0",
    "invalid-wildcard": "9.*",
    "invalid-range": ">=9.0.0 <10.0.0"
  }
}
```

### Validation Regex

```text
^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$
```

This permits standard semver (`1.2.3`), pre-release tags (`1.2.3-beta.1`), and build metadata (`1.2.3+build.42`), while rejecting all range operators.

### Why Not SHA-Pinning for npm

| Criterion            | SHA-Pinning (GitHub Actions)                   | Exact-Version (npm)                          |
|----------------------|------------------------------------------------|----------------------------------------------|
| Registry model       | Git repositories with mutable tags             | Immutable package tarballs                   |
| Mutability risk      | Tags can be force-pushed to different commits  | Published versions are permanently immutable |
| Audit tooling        | `npm audit` cross-references semver, not SHAs  | Full compatibility with `npm audit`          |
| Lockfile integration | N/A                                            | `package-lock.json` records integrity hashes |
| Human readability    | 40-char hex strings obscure the actual version | Version is self-documenting                  |

## GitHub Actions: SHA Pinning

GitHub Actions references must use full 40-character commit SHAs because action tags (like `v4`) are mutable Git references that can be retargeted to arbitrary commits.

```yaml
# Rejected: mutable tag reference
- uses: actions/checkout@v4

# Accepted: immutable SHA reference
- uses: actions/checkout@a5ac7e51b41094c92402da3b24376905380afc29 # v4.2.2
```

The scanner validates that the SHA is a real 40-character hexadecimal string and optionally checks staleness against the GitHub API.

## pip: Exact-Version Pinning

Python dependencies must use the `==` operator for exact version pinning. The scanner excludes virtual environment directories (`.venv`, `venv`, `.tox`, `.nox`, `__pypackages__`) to avoid false positives from installed package metadata.

```text
# Accepted
requests==2.31.0
flask==3.0.0

# Rejected
requests>=2.31.0
flask~=3.0
```

## Workflow npm Commands: npm ci Enforcement

CI workflow YAML files are scanned for npm commands that modify the dependency tree at install time. These commands resolve version ranges against the registry, producing non-deterministic installs that can pull in compromised packages.

### Detected Commands

The scanner inspects `run:` blocks in workflow YAML with indentation-aware parsing and flags these commands:

| Flagged            | Reason                                                 |
|--------------------|--------------------------------------------------------|
| `npm install`      | Resolves ranges from `package.json`, ignoring lockfile |
| `npm i`            | Alias for `npm install`                                |
| `npm update`       | Upgrades to latest versions within semver ranges       |
| `npm install-test` | Combines install and test in a non-deterministic way   |

### Safe Commands

These npm commands are not flagged because they do not modify the dependency tree:

* `npm ci`: Installs exactly from the lockfile, removing `node_modules` first
* `npm run`: Executes a script defined in `package.json`
* `npm test`: Alias for `npm run test`
* `npm audit`: Reports known vulnerabilities without installing
* `npx`: Runs a package binary without modifying dependencies

### Remediation

Replace flagged commands with `npm ci` for deterministic, lockfile-based installs:

```yaml
# Rejected: resolves version ranges from the registry
- run: npm install

# Accepted: installs exactly what the lockfile specifies
- run: npm ci
```

### File Scope

The scanner processes files matching `.github/workflows/*.yml` and `.github/workflows/*.yaml`.

## Shell Downloads: Checksum Verification

Shell scripts that download files from the internet must verify checksums to prevent tampered or corrupted binaries from entering the build environment.

### Detection

The scanner identifies download commands matching `curl` or `wget` with an HTTP/HTTPS URL. It then checks the next five lines for a checksum verification command. If no verification is found, the download is flagged.

### Accepted Verification Commands

Any of these patterns within five lines of the download satisfies the check:

* `sha256sum`: GNU coreutils checksum
* `shasum`: macOS/BSD checksum utility
* `Get-FileHash`: PowerShell checksum cmdlet
* `openssl dgst -sha256`: OpenSSL digest
* `sha256sum -c`: Checksum file verification

### Examples

```bash
# Accepted — checksum verified immediately after download
curl -Lo tool.tar.gz https://example.com/tool-v1.0.tar.gz
echo "abc123...  tool.tar.gz" | sha256sum --check

# Rejected — no checksum verification after download
wget https://example.com/tool-v1.0.tar.gz
tar xzf tool-v1.0.tar.gz
```

### Scanned Files

The scanner processes files matching `.devcontainer/scripts/*.sh` and `scripts/*.sh`, excluding fixture directories used in tests.

## CI Integration

The dependency pinning scanner runs in CI as part of the security validation workflow. It produces SARIF 2.1.0 output that integrates with GitHub code scanning.

```mermaid
flowchart LR
    A[CI Trigger] --> B[Test-DependencyPinning.ps1]
    B --> C{Violations?}
    C -->|None| D[✅ Pass]
    C -->|Found| E[SARIF Report]
    E --> F[GitHub Code Scanning]
```

### Severity Mapping

| Scanner Severity | SARIF Level | Trigger                                    |
|------------------|-------------|--------------------------------------------|
| High             | `error`     | Unpinned or mutable dependency reference   |
| Medium           | `warning`   | Stale pinned version with available update |
| Low              | `note`      | Informational findings                     |

### Running Locally

```powershell
# Full scan with SARIF output
./scripts/security/Test-DependencyPinning.ps1

# Results appear in logs/dependency-pinning-results.json
```

## Related Resources

* [Threat Model](threat-model.md): Supply chain threats S-1, S-2, SC-1, SC-4, and SC-6
* [Branch Protection](../contributing/branch-protection.md): Required status checks including dependency pinning

---

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
