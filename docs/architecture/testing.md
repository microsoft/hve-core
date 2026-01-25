---
title: Testing Architecture
description: PowerShell Pester test infrastructure and conventions
author: Microsoft
ms.date: 2026-01-22
ms.topic: concept
---

## Overview

HVE Core uses Pester 5.x for PowerShell testing with a mirror directory structure that maps production scripts to their corresponding test files. The test infrastructure supports isolated unit testing through mock utilities and enforces a 70% code coverage threshold.

## Directory Structure

Test files follow a mirror pattern where each script directory has a corresponding `tests/` subdirectory:

```text
scripts/
├── dev-tools/
│   └── Generate-PrReference.ps1
├── extension/
│   ├── Package-Extension.ps1
│   └── Prepare-Extension.ps1
├── lib/
│   └── Get-VerifiedDownload.ps1
├── linting/
│   └── *.ps1
├── security/
│   └── *.ps1
└── tests/
    ├── dev-tools/
    │   └── Generate-PrReference.Tests.ps1
    ├── extension/
    ├── lib/
    ├── linting/
    ├── security/
    ├── Fixtures/
    ├── Mocks/
    │   └── GitMocks.psm1
    └── pester.config.ps1
```

Test files use the `.Tests.ps1` suffix convention, enabling automatic discovery by Pester.

## Pester Configuration

The configuration file at [scripts/tests/pester.config.ps1](../../scripts/tests/pester.config.ps1) defines test execution behavior:

```powershell
# Key configuration settings
$configuration.Run.TestExtension = '.Tests.ps1'
$configuration.Filter.ExcludeTag = @('Integration', 'Slow')
$configuration.CodeCoverage.CoveragePercentTarget = 70
```

### Coverage Configuration

Code coverage analyzes scripts in production directories while excluding test files:

| Setting           | Value               |
|-------------------|---------------------|
| Coverage target   | 70% minimum         |
| Output format     | JaCoCo XML          |
| Output path       | `logs/coverage.xml` |
| Excluded patterns | `*.Tests.ps1`       |

Coverage directories include `linting/`, `security/`, `dev-tools/`, `lib/`, and `extension/`.

### Test Output

| Output Type     | Format   | Path                      |
|-----------------|----------|---------------------------|
| Test results    | NUnitXml | `logs/pester-results.xml` |
| Coverage report | JaCoCo   | `logs/coverage.xml`       |

## Test Utilities

### LintingHelpers Module

The [LintingHelpers.psm1](../../scripts/linting/Modules/LintingHelpers.psm1) module provides shared functions for linting scripts and tests:

| Function                  | Purpose                                                         |
|---------------------------|-----------------------------------------------------------------|
| `Get-ChangedFilesFromGit` | Detects changed files using merge-base with fallback strategies |
| `Get-FilesRecursive`      | Recursively finds files while respecting gitignore patterns     |
| `Get-GitIgnorePatterns`   | Parses `.gitignore` into PowerShell wildcard patterns           |
| `Write-GitHubAnnotation`  | Writes GitHub Actions annotations for errors and warnings       |
| `Set-GitHubOutput`        | Sets GitHub Actions output variables                            |
| `Set-GitHubEnv`           | Sets GitHub Actions environment variables                       |

### GitMocks Module

The [GitMocks.psm1](../../scripts/tests/Mocks/GitMocks.psm1) module provides reusable mock helpers for Git CLI and GitHub Actions testing.

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

| Command           | Description          |
|-------------------|----------------------|
| `npm run test:ps` | Run all Pester tests |

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
