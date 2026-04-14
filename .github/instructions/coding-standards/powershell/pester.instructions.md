---
description: "Instructions for Pester testing conventions - Brought to you by microsoft/hve-core"
applyTo: '**/*.Tests.ps1'
---

# Pester Testing Instructions

Pester 5.x is the testing framework for all PowerShell code. Run tests through the repository's test runner (check `package.json` for a test script, or invoke `Invoke-Pester` directly if no runner is configured). Follow the repository's conventions for test execution.

## Test File Naming

Test files use a `.Tests.ps1` suffix matching the production file name:

| Production file              | Test file                          |
|------------------------------|------------------------------------|
| `Test-DependencyPinning.ps1` | `Test-DependencyPinning.Tests.ps1` |
| `SecurityHelpers.psm1`       | `SecurityHelpers.Tests.ps1`        |
| `SecurityClasses.psm1`       | `SecurityClasses.Tests.ps1`        |

## Test File Location

**Mirror directory pattern**: Place test files in a `tests/` directory that mirrors the production directory layout. Each production subdirectory has a corresponding test subdirectory. Discover the repository's test directory structure by examining existing test files.

**Co-located tests**: Self-contained packages (such as skills or plugins) place tests inside the package directory rather than the mirror tree:

```text
package-root/
├── scripts/
│   ├── action.ps1
│   └── helpers.psm1
└── tests/
    ├── action.Tests.ps1
    └── helpers.Tests.ps1
```

## Test File Header

Test files place `#Requires -Modules Pester` before the copyright header. This ordering differs from production scripts:

```powershell
#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
```

## SUT Import Patterns

Import the system under test in a file-level `BeforeAll` block. Use the pattern matching the production file type:

**Dot-source for scripts** (`.ps1`):

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1')
}
```

**Import-Module for modules** (`.psm1`):

```powershell
BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../security/Modules/SecurityHelpers.psm1') -Force
}
```

**using module for class modules** (parse-time type resolution):

```powershell
using module ..\..\security\Modules\SecurityClasses.psm1
```

The `using module` statement appears at the top of the file outside any block because PowerShell processes it at parse time.

## BeforeAll Setup

File-level `BeforeAll` initializes the test environment. Common activities include SUT import, mock module import, fixture path resolution, and output suppression:

```powershell
BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Test-DependencyPinning.ps1')
    Import-Module (Join-Path $PSScriptRoot '../../security/Modules/SecurityHelpers.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force
    $script:FixtureRoot = Join-Path $PSScriptRoot '../Fixtures/Security'
    Mock Write-Host {}
    Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
}
```

## Describe, Context, and It Blocks

All `Describe` blocks require `-Tag 'Unit'`. The pester configuration excludes `Integration` and `Slow` tags by default:

```powershell
Describe 'FunctionName' -Tag 'Unit' {
    Context 'when input is valid' {
        It 'Returns expected output' {
            Get-Something -Path 'test' | Should -Be 'result'
        }
    }
}
```

`Context` groups related scenarios. Each `It` tests a single behavior with a descriptive sentence name.

## Data-Driven Tests

Use `-ForEach` on `It` blocks for parameterized testing:

```powershell
It 'Accepts valid type <Value>' -ForEach @(
    @{ Value = 'Unpinned' }
    @{ Value = 'Stale' }
    @{ Value = 'VersionMismatch' }
) {
    $v = [DependencyViolation]::new()
    $v.ViolationType = $Value
    $v.ViolationType | Should -Be $Value
}
```

## Mock Patterns

**Output suppression**: Empty scriptblock mocks prevent console noise:

```powershell
Mock Write-Host {}
```

**Module-scoped mocks**: `-ModuleName` injects mocks into modules under test:

```powershell
Mock Write-CIAnnotation {} -ModuleName SecurityHelpers
```

**Parameter-filtered mocks**: `-ParameterFilter` targets specific invocations:

```powershell
Mock git {
    $global:LASTEXITCODE = 0
    return 'abc123'
} -ModuleName LintingHelpers -ParameterFilter {
    $args[0] -eq 'merge-base'
}
```

## Mock Verification

Use `Should -Invoke` to verify mock calls:

```powershell
Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -Times 1 -Exactly
Should -Invoke Write-CIAnnotation -ModuleName SecurityHelpers -ParameterFilter {
    $Level -eq 'Warning'
}
```

## Test Isolation

**`$TestDrive`**: Pester-managed temp directory, automatically cleaned per `Describe`:

```powershell
$testDir = Join-Path $TestDrive 'test-collection'
New-Item -ItemType Directory -Path $testDir -Force
```

**`New-TemporaryFile` with try/finally**: Manual temp file management when `$TestDrive` is insufficient:

```powershell
$tempFile = New-TemporaryFile
try {
    # test using $tempFile
}
finally {
    Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
}
```

**`$script:` scope**: Shares state across `It` blocks within a `Describe` or `Context`:

```powershell
BeforeAll {
    $script:result = Get-Something -Path 'test'
}
It 'Returns correct name' {
    $script:result.Name | Should -Be 'expected'
}
```

## Environment Save and Restore

Tests modifying environment variables use the `GitMocks.psm1` save/restore pattern:

```powershell
BeforeAll {
    Import-Module "$PSScriptRoot/../Mocks/GitMocks.psm1" -Force
}
BeforeEach {
    Save-CIEnvironment
    $script:MockFiles = Initialize-MockCIEnvironment
}
AfterEach {
    Remove-MockCIFiles -MockFiles $script:MockFiles
    Restore-CIEnvironment
}
```

## Cleanup

Remove imported modules in `AfterAll` to prevent state leakage between test files:

```powershell
AfterAll {
    Remove-Module SecurityHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module GitMocks -Force -ErrorAction SilentlyContinue
}
```

## Assertion Reference

| Assertion                     | Usage                   |
|-------------------------------|-------------------------|
| `Should -Be`                  | Exact value equality    |
| `Should -BeExactly`           | Case-sensitive equality |
| `Should -BeTrue` / `-BeFalse` | Boolean checks          |
| `Should -BeNullOrEmpty`       | Null or empty string    |
| `Should -Not -BeNullOrEmpty`  | Non-null and non-empty  |
| `Should -Match`               | Regex matching          |
| `Should -BeLike`              | Wildcard matching       |
| `Should -Contain`             | Collection membership   |
| `Should -BeOfType`            | Type assertion          |
| `Should -HaveCount`           | Collection length       |
| `Should -Throw`               | Exception expected      |
| `Should -Not -Throw`          | No exception expected   |
| `Should -BeGreaterThan`       | Numeric comparison      |
| `Should -BeLessThan`          | Numeric comparison      |
| `Should -Invoke`              | Mock call verification  |

## Running Tests

Check `package.json` for a test runner script (common name: `test:ps`). If a runner is configured, use it to execute tests:

```bash
# Example: run all tests via the repository's test runner
npm run test:ps

# Example: run tests for a specific directory or file
npm run test:ps -- -TestPath "path/to/tests/"
```

If no runner is configured, invoke Pester directly:

```powershell
Invoke-Pester -Path './tests/' -Output Detailed
```

After execution, check the repository's log or output directory for structured test results (such as summary and failure JSON files) when available.

## Complete Test Example

<!-- <template-complete-test> -->

```powershell
#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../linting/Invoke-Linter.ps1')
    Import-Module (Join-Path $PSScriptRoot '../Mocks/GitMocks.psm1') -Force
    $script:FixtureRoot = Join-Path $PSScriptRoot '../Fixtures/Linting'
    Mock Write-Host {}
}

Describe 'Invoke-Linter' -Tag 'Unit' {
    Context 'when input file is valid' {
        BeforeAll {
            $script:result = Invoke-Linter -Path (Join-Path $script:FixtureRoot 'valid.md')
        }

        It 'Returns zero violations' {
            $script:result.Violations | Should -HaveCount 0
        }

        It 'Sets status to pass' {
            $script:result.Status | Should -Be 'Pass'
        }
    }

    Context 'when input file has errors' {
        BeforeAll {
            $script:result = Invoke-Linter -Path (Join-Path $script:FixtureRoot 'invalid.md')
        }

        It 'Returns violations' {
            $script:result.Violations | Should -Not -BeNullOrEmpty
        }

        It 'Includes file path in each violation' {
            $script:result.Violations | ForEach-Object {
                $_.File | Should -Not -BeNullOrEmpty
            }
        }
    }
}

AfterAll {
    Remove-Module GitMocks -Force -ErrorAction SilentlyContinue
}
```

<!-- </template-complete-test> -->
