---
description: "Instructions for Pester testing conventions - Brought to you by microsoft/hve-core"
applyTo: '**/*.Tests.ps1'
---

# Pester Testing Instructions

Pester 5.x is the testing framework for all PowerShell code. Tests run exclusively through `npm run test:ps`. Never invoke Pester or test scripts directly.

## Test File Naming

Test files use a `.Tests.ps1` suffix matching the production file name:

| Production file              | Test file                          |
|------------------------------|------------------------------------|
| `Test-DependencyPinning.ps1` | `Test-DependencyPinning.Tests.ps1` |
| `SecurityHelpers.psm1`       | `SecurityHelpers.Tests.ps1`        |
| `SecurityClasses.psm1`       | `SecurityClasses.Tests.ps1`        |

## Test File Location

**Mirror directory pattern**: Test files in `scripts/tests/` mirror the production `scripts/` layout. Each production subdirectory has a corresponding test subdirectory:

| Production directory   | Test directory               |
|------------------------|------------------------------|
| `scripts/collections/` | `scripts/tests/collections/` |
| `scripts/linting/`     | `scripts/tests/linting/`     |
| `scripts/security/`    | `scripts/tests/security/`    |
| `scripts/lib/`         | `scripts/tests/lib/`         |

**Co-located skill tests**: Skills place tests inside the skill directory rather than the mirror tree:

```text
.github/skills/shared/pr-reference/
├── scripts/
│   ├── generate.ps1
│   └── shared.psm1
└── tests/
    ├── generate.Tests.ps1
    └── shared.Tests.ps1
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

Run all tests:

```bash
npm run test:ps
```

Run tests for a specific directory or file:

```bash
npm run test:ps -- -TestPath "scripts/tests/linting/"
npm run test:ps -- -TestPath "scripts/tests/security/Test-DependencyPinning.Tests.ps1"
```

After execution, check `logs/pester-summary.json` for overall status and `logs/pester-failures.json` for failure details.

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
