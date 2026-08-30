---
title: Test Scripts
description: Pester test runner, changed-file detection, and test directory organization
author: HVE Core Team
ms.date: 2026-08-21
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

Purpose: Provide a consistent entry point for running Pester tests in both
local and CI environments.

#### Features

* Writes `logs/pester-summary.json` with overall pass/fail counts and duration.
  When code coverage is enabled, the summary also includes `CoveragePercent`
  (measured percentage, rounded to two decimal places) and `CoverageTarget`
  (configured threshold from `pester.config.ps1`)
* Writes `logs/pester-failures.json` with failure details including test name,
  file path, error message, and stack trace
* Supports code coverage reporting
* Integrates with CI for exit codes and NUnit output

#### Parameters

* `-TestPath` - Path to specific test file(s) or directory
* `-CI` (switch) - Enable CI mode with exit codes and NUnit output
* `-CodeCoverage` (switch) - Enable code coverage analysis
* `-Tag` / `-IncludeTag` - Run only tests whose Describe/Context/It blocks carry
  one of the supplied tags
* `-ExcludeTag` - Exclude tests whose blocks carry any of the supplied tags;
  defaults to `@('Integration','Slow')` when omitted, and passing this parameter
  (including `-ExcludeTag @()`) replaces the default rather than appending to it

#### Usage

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

Purpose: Enable targeted test runs by identifying which tests correspond to
changed production scripts.

#### Features

* Compares the current branch against a base branch using `git diff`
* Maps changed production files to their mirror test files
* Supports custom file filters and alternate root paths

#### Parameters

* `-BaseBranch` - Git branch to compare against (defaults to `main`)
* `-FileFilter` - Glob pattern for filtering changed files
* `-SkillsRoot` - Root path for skill scripts
* `-TestRoot` - Root path for test files

#### Usage

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
├── extension/       Extension packaging tests
├── lib/             Library utility tests
├── linting/         Linting script tests
├── plugins/         Plugin manifest synchronization tests
├── security/        Security validation tests
├── Fixtures/        Shared test fixtures
└── Mocks/           Shared mock data (GitMocks.psm1)
```

Test files use the `.Tests.ps1` suffix convention for automatic discovery by
Pester.

Planner-related tests are split intentionally: rule-validator suites (state
schema, cadence ordering, startup blocks, risk-grid grammar) live under
`linting/` alongside other linter tests, while artifact-signing and runtime
concerns (e.g. `Sign-PlannerArtifacts.Tests.ps1`) live under `security/`.

## PowerShell 7 and Pester gotchas

### Read empty files as empty strings

In PowerShell 7, `Get-Content -Raw` returns `$null` for a 0-byte file instead of
an empty string. This can make string assertions fail unexpectedly. Check the
file size and use `[System.IO.File]::ReadAllText` when a string result is
required:

```powershell
$Bytes = if (Test-Path $Path) { (Get-Item $Path).Length } else { -1 }
$Content = if ($Bytes -gt 0) {
    [System.IO.File]::ReadAllText($Path)
}
else {
    ''
}
```

### Wait for redirected output to flush

`Start-Process -Wait` can return before redirected output file handles finish
flushing, especially for small payloads in a Pester runspace. Call
`WaitForExit()`, check the output size, and use a short retry when successful
execution should have produced output:

```powershell
$Process = Start-Process -FilePath 'pwsh' -ArgumentList $Arguments `
    -RedirectStandardOutput $OutputPath -Wait -PassThru
$Process.WaitForExit()

$Bytes = if (Test-Path $OutputPath) { (Get-Item $OutputPath).Length } else { -1 }
if ($Bytes -eq 0 -and $Process.ExitCode -eq 0) {
    Start-Sleep -Milliseconds 100
    $Bytes = (Get-Item $OutputPath).Length
}
```

### Put diagnostic context in assertions

`[System.IO.File]::AppendAllText` calls inside Pester `It` blocks can be
silently swallowed, so in-test diagnostic files are unreliable. Add context
with `Should -Because`; the test runner preserves it in
`logs/pester-failures.json`:

```powershell
$Result.StdOut | Should -Match 'expected text' -Because (
    "ExitCode=$($Result.ExitCode); StdOutBytes=$($Result.StdOutBytes); " +
    "StdErr=[$($Result.StdErr)]"
)
```

## Related Documentation

* [Testing Architecture](../../docs/architecture/testing.md) for Pester
  configuration and conventions
* [Scripts README](../README.md) for overall script organization

<!-- markdownlint-disable MD036 -->
*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,
then carefully refined by our team of discerning human reviewers.*
<!-- markdownlint-enable MD036 -->
