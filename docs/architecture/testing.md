---
title: Testing Architecture
description: PowerShell Pester test infrastructure and conventions
sidebar_position: 4
author: Microsoft
ms.date: 2026-06-25
ms.topic: concept
---

## Overview

HVE Core uses Pester 5.x for PowerShell testing with a mirror directory structure that maps production scripts to their corresponding test files. The test infrastructure supports isolated unit testing through mock utilities and enforces an 80% code coverage threshold.

## Directory Structure

Test files follow a mirror pattern where each script directory has a corresponding `tests/` subdirectory:

```text
scripts/
├── collections/
│   └── *.ps1
├── evals/
│   └── *.ps1
├── extension/
│   ├── Package-Extension.ps1
│   └── Prepare-Extension.ps1
├── lib/
│   └── Get-VerifiedDownload.ps1
├── linting/
│   └── *.ps1
├── plugins/
│   └── *.ps1
├── security/
│   └── *.ps1
└── tests/
    ├── collections/
    ├── evals/
    ├── extension/
    ├── lib/
    ├── linting/
    ├── plugins/
    ├── security/
    ├── Fixtures/
    ├── Mocks/
    │   └── GitMocks.psm1
    └── pester.config.ps1
```

Test files use the `.Tests.ps1` suffix convention, enabling automatic discovery by Pester.

## Pester Configuration

The configuration file at [scripts/tests/pester.config.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/tests/pester.config.ps1) defines test execution behavior:

```powershell
# Key configuration settings
$configuration.Run.TestExtension = '.Tests.ps1'
$configuration.Filter.ExcludeTag = @('Integration', 'Slow')
$configuration.CodeCoverage.CoveragePercentTarget = 80
```

### Coverage Configuration

Code coverage analyzes scripts in production directories while excluding test files:

| Setting           | Value               |
|-------------------|---------------------|
| Coverage target   | 80% minimum         |
| Output format     | JaCoCo XML          |
| Output path       | `logs/coverage.xml` |
| Excluded patterns | `*.Tests.ps1`       |

Coverage directories include `linting/`, `security/`, `lib/`, `extension/`, `collections/`, and `tests/`, plus skill scripts under `.github/skills/` (resolved separately further down in the config).

When code coverage is enabled, the [pester-tests.yml](https://github.com/microsoft/hve-core/blob/main/.github/workflows/pester-tests.yml)
workflow enforces the coverage target through its **Coverage Threshold Check** step. The step sources both the measured
percentage (`CoveragePercent`) and the target (`CoverageTarget`) from `logs/pester-summary.json`, which is the authoritative
summary written by [Invoke-PesterTests.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/tests/Invoke-PesterTests.ps1).
The target originates in [pester.config.ps1](https://github.com/microsoft/hve-core/blob/main/scripts/tests/pester.config.ps1)
as the single source of truth. The job fails when the measured coverage falls below the 80% target, unless soft-fail mode is enabled.

### Test Output

| Output Type     | Format   | Path                      |
|-----------------|----------|---------------------------|
| Test results    | NUnitXml | `logs/pester-results.xml` |
| Coverage report | JaCoCo   | `logs/coverage.xml`       |

When code coverage is enabled, `Invoke-PesterTests.ps1` also records the coverage measurement in `logs/pester-summary.json`:

| Field             | Description                                                                   |
|-------------------|-------------------------------------------------------------------------------|
| `CoveragePercent` | Measured code coverage percentage, rounded to two decimal places              |
| `CoverageTarget`  | Configured coverage target (`CoveragePercentTarget`), rounded to two decimals |

## Test Utilities

### LintingHelpers Module

The [LintingHelpers.psm1](https://github.com/microsoft/hve-core/blob/main/scripts/linting/Modules/LintingHelpers.psm1) module provides shared functions for linting scripts and tests:

| Function                  | Purpose                                                         |
|---------------------------|-----------------------------------------------------------------|
| `Get-ChangedFilesFromGit` | Detects changed files using merge-base with fallback strategies |
| `Get-FilesRecursive`      | Finds files via `git ls-files` with `Get-ChildItem` fallback    |
| `Get-GitIgnorePatterns`   | Parses `.gitignore` into PowerShell wildcard patterns           |
| `Write-GitHubAnnotation`  | Writes GitHub Actions annotations for errors and warnings       |
| `Set-GitHubOutput`        | Sets GitHub Actions output variables                            |
| `Set-GitHubEnv`           | Sets GitHub Actions environment variables                       |

### GitMocks Module

The [GitMocks.psm1](https://github.com/microsoft/hve-core/blob/main/scripts/tests/Mocks/GitMocks.psm1) module provides reusable mock helpers for Git CLI and GitHub Actions testing.

#### Environment Management

| Function                           | Purpose                                                 |
|------------------------------------|---------------------------------------------------------|
| `Save-GitHubEnvironment`           | Saves current GitHub Actions environment variables      |
| `Restore-GitHubEnvironment`        | Restores saved environment state                        |
| `Initialize-MockGitHubEnvironment` | Creates mock GitHub Actions environment with temp files |
| `Clear-MockGitHubEnvironment`      | Removes GitHub Actions environment variables            |
| `Remove-MockGitHubFiles`           | Cleans up temp files from mock initialization           |

#### Git Mocks

| Function                      | Purpose                                           |
|-------------------------------|---------------------------------------------------|
| `Initialize-GitMocks`         | Sets up standard git command mocks for a module   |
| `Set-GitMockChangedFiles`     | Updates files returned by git diff mock           |
| `Set-GitMockMergeBaseFailure` | Simulates merge-base failure for fallback testing |

#### Test Data

| Function                  | Purpose                                           |
|---------------------------|---------------------------------------------------|
| `New-MockFileList`        | Generates mock file paths for testing             |
| `Get-MockGitDiffScenario` | Returns predefined scenarios for git diff testing |

### Environment Save/Restore Pattern

Tests that modify environment variables follow this pattern:

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../Mocks/GitMocks.psm1" -Force
}

BeforeEach {
    Save-GitHubEnvironment
    $script:MockFiles = Initialize-MockGitHubEnvironment
}

AfterEach {
    Remove-MockGitHubFiles -MockFiles $script:MockFiles
    Restore-GitHubEnvironment
}
```

## Running Tests

### npm Scripts

| Command           | Description                     |
|-------------------|---------------------------------|
| `npm run test:ps` | Run all PowerShell Pester tests |
| `npm run test:py` | Run all Python tests via pytest |

### Direct Pester Invocation

Run tests with default configuration:

```powershell
Invoke-Pester -Configuration (& ./scripts/tests/pester.config.ps1)
```

Run tests with code coverage:

```powershell
Invoke-Pester -Configuration (& ./scripts/tests/pester.config.ps1 -CodeCoverage)
```

Run tests in CI mode with exit codes and NUnit output:

```powershell
Invoke-Pester -Configuration (& ./scripts/tests/pester.config.ps1 -CI -CodeCoverage)
```

Run a specific test file:

```powershell
Invoke-Pester -Path ./scripts/tests/linting/Invoke-PSScriptAnalyzer.Tests.ps1
```

### Test Utility Scripts

Two wrapper scripts in `scripts/tests/` streamline test execution:

* `Invoke-PesterTests.ps1` orchestrates full test runs with configuration loading, code coverage, CI output formatting, and result file generation. The `npm run test:ps` command calls this script.
* `Get-ChangedTestFiles.ps1` identifies test files affected by recent changes, enabling targeted test runs during development or in pull request workflows.

See [scripts/tests/README.md](https://github.com/microsoft/hve-core/blob/main/scripts/tests/README.md) for parameters and usage details.

## Skills Testing

Skill scripts use a co-located test pattern instead of the mirror directory structure used by `scripts/`. Each skill contains its own `tests/` subdirectory:

```text
.github/skills/<skill-name>/
├── scripts/
│   ├── convert.ps1
│   └── convert.sh
└── tests/
    └── convert.Tests.ps1
```

### Coverage Integration

The Pester configuration at `scripts/tests/pester.config.ps1` resolves skill scripts from the repository root for code coverage analysis. When you include a skill `tests/` directory in an `Invoke-Pester -Path` argument or test run configuration, Pester discovers the skill test files through the `.Tests.ps1` naming convention.

Coverage path resolution for skills uses the repository root rather than `$scriptRoot` (which points to `scripts/`):

```powershell
$repoRoot = Split-Path $scriptRoot -Parent
$skillScripts = Get-ChildItem -Path (Join-Path $repoRoot '.github/skills') `
    -Include '*.ps1', '*.psm1' -Recurse -File -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '\.Tests\.ps1$' }
```

### Packaging Exclusion

Co-located `tests/` directories are excluded from the VSIX extension package by `Package-Extension.ps1`. After copying a skill directory, the packaging script removes any `tests/` subdirectories from the destination.

🤖 *Crafted with precision by ✨Copilot following brilliant human instruction, then carefully refined by our team of discerning human reviewers.*
