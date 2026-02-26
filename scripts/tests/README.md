---
title: Test Scripts
description: Pester test runner, changed-file detection, and test directory organization
author: HVE Core Team
ms.date: 2025-11-05
ms.topic: reference
keywords:
  - powershell
  - pester
  - testing
  - automation
estimated_reading_time: 5
---

This directory contains the Pester test runner, changed-file detection
utilities, test configuration, and test suites organized to mirror the
production `scripts/` structure.

## Scripts

### `Invoke-PesterTests.ps1`

Pester test runner that writes structured output to `logs/`.

**Purpose**: Provide a consistent entry point for running Pester tests in both
local and CI environments.

**Features**:

* Writes `logs/pester-summary.json` with overall pass/fail counts and duration
* Writes `logs/pester-failures.json` with failure details including test name,
  file path, error message, and stack trace
* Supports code coverage reporting
* Integrates with CI for exit codes and NUnit output

**Parameters**:

* `-TestPath` - Path to specific test file(s) or directory
* `-CI` (switch) - Enable CI mode with exit codes and NUnit output
* `-CodeCoverage` (switch) - Enable code coverage analysis

**Usage**:

```powershell
# Run all tests
./scripts/tests/Invoke-PesterTests.ps1

# Run a specific test directory
./scripts/tests/Invoke-PesterTests.ps1 -TestPath scripts/tests/linting/

# Run with code coverage in CI mode
./scripts/tests/Invoke-PesterTests.ps1 -CI -CodeCoverage
```

The corresponding npm script:

```bash
npm run test:ps
npm run test:ps -- -TestPath "scripts/tests/security/"
```

### `Get-ChangedTestFiles.ps1`

Detects changed PowerShell files and resolves corresponding Pester test paths.

**Purpose**: Enable targeted test runs by identifying which tests correspond to
changed production scripts.

**Features**:

* Compares the current branch against a base branch using `git diff`
* Maps changed production files to their mirror test files
* Supports custom file filters and alternate root paths

**Parameters**:

* `-BaseBranch` - Git branch to compare against (defaults to `main`)
* `-FileFilter` - Glob pattern for filtering changed files
* `-SkillsRoot` - Root path for skill scripts
* `-TestRoot` - Root path for test files

**Usage**:

```powershell
# Get test files for all changed scripts
./scripts/tests/Get-ChangedTestFiles.ps1

# Compare against a specific branch
./scripts/tests/Get-ChangedTestFiles.ps1 -BaseBranch develop
```

### `pester.config.ps1`

Pester 5.x configuration script that defines test execution behavior, coverage
targets, and output paths. See
[Testing Architecture](../../docs/architecture/testing.md) for configuration
details.

## Directory Structure

Test suites mirror the production `scripts/` layout:

```text
tests/
├── collections/     Collection validation tests
├── extension/       Extension packaging tests
├── lib/             Library utility tests
├── linting/         Linting script tests
├── plugins/         Plugin generation tests
├── security/        Security validation tests
├── Fixtures/        Shared test fixtures
└── Mocks/           Shared mock data (GitMocks.psm1)
```

Test files use the `.Tests.ps1` suffix convention for automatic discovery by
Pester.

## Related Documentation

* [Testing Architecture](../../docs/architecture/testing.md) for Pester
  configuration and conventions
* [Scripts README](../README.md) for overall script organization

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
