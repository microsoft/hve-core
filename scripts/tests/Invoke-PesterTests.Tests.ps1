#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Invoke-PesterTests.ps1 and pester.config.ps1 tag passthrough.
.DESCRIPTION
    Verifies the -Tag / -IncludeTag / -ExcludeTag parameters added to the runner
    and configuration script:
    - Default ExcludeTag stays @('Integration','Slow') when no override is passed
    - -Tag populates Filter.Tag
    - -IncludeTag is an alias of -Tag
    - -ExcludeTag REPLACES the default (does not append)
    - -ExcludeTag @() clears the exclude list entirely
    - Runner forwards each parameter into the configuration handed to Invoke-Pester
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '',
    Justification = 'Pester mock scriptblocks execute in a separate session state; a global variable is the supported way to capture call arguments across that boundary.')]
param()

BeforeAll {
    $script:RunnerPath = Join-Path $PSScriptRoot 'Invoke-PesterTests.ps1'
    $script:ConfigPath = Join-Path $PSScriptRoot 'pester.config.ps1'

    # Helper: read the raw value off a Pester StringArrayOption. Older/newer Pester
    # versions sometimes expose the value directly vs via .Value, so try both.
    function Get-FilterArray {
        param($Option)
        if ($null -eq $Option) { return @() }
        if ($Option.PSObject.Properties.Name -contains 'Value') {
            return @($Option.Value)
        }
        return @($Option)
    }
}

Describe 'pester.config.ps1 tag parameters' -Tag 'Unit' {

    Context 'when no tag parameters are supplied' {
        BeforeAll {
            $script:config = & $script:ConfigPath
        }

        It 'Sets Filter.ExcludeTag to the default Integration/Slow list' {
            $excludes = Get-FilterArray $script:config.Filter.ExcludeTag
            $excludes | Should -Contain 'Integration'
            $excludes | Should -Contain 'Slow'
            $excludes | Should -HaveCount 2
        }

        It 'Leaves Filter.Tag empty' {
            $tags = Get-FilterArray $script:config.Filter.Tag
            $tags | Should -HaveCount 0
        }
    }

    Context 'when -Tag is supplied' {
        It 'Populates Filter.Tag with the supplied values' {
            $config = & $script:ConfigPath -Tag 'Unit'
            $tags = Get-FilterArray $config.Filter.Tag
            $tags | Should -Contain 'Unit'
            $tags | Should -HaveCount 1
        }

        It 'Accepts multiple tag values' {
            $config = & $script:ConfigPath -Tag 'Unit', 'Smoke'
            $tags = Get-FilterArray $config.Filter.Tag
            $tags | Should -Contain 'Unit'
            $tags | Should -Contain 'Smoke'
        }

        It 'Leaves the default ExcludeTag intact when only -Tag is set' {
            $config = & $script:ConfigPath -Tag 'Unit'
            $excludes = Get-FilterArray $config.Filter.ExcludeTag
            $excludes | Should -Contain 'Integration'
            $excludes | Should -Contain 'Slow'
        }
    }

    Context 'when -IncludeTag is supplied as an alias for -Tag' {
        It 'Populates Filter.Tag the same as -Tag' {
            $config = & $script:ConfigPath -IncludeTag 'Unit'
            $tags = Get-FilterArray $config.Filter.Tag
            $tags | Should -Contain 'Unit'
        }
    }

    Context 'when -ExcludeTag is supplied' {
        It 'Replaces the default exclude list rather than appending to it' {
            $config = & $script:ConfigPath -ExcludeTag 'Slow'
            $excludes = Get-FilterArray $config.Filter.ExcludeTag
            $excludes | Should -Contain 'Slow'
            $excludes | Should -Not -Contain 'Integration'
            $excludes | Should -HaveCount 1
        }

        It 'Accepts an empty array to disable exclusion entirely' {
            $config = & $script:ConfigPath -ExcludeTag @()
            $excludes = Get-FilterArray $config.Filter.ExcludeTag
            $excludes | Should -HaveCount 0
        }
    }

    Context 'when both -Tag and -ExcludeTag are supplied' {
        BeforeAll {
            $script:bothConfig = & $script:ConfigPath -Tag 'Unit' -ExcludeTag 'Flaky'
        }

        It 'Sets Filter.Tag to the include list' {
            $tags = Get-FilterArray $script:bothConfig.Filter.Tag
            $tags | Should -Contain 'Unit'
        }

        It 'Sets Filter.ExcludeTag to the explicit exclude list' {
            $excludes = Get-FilterArray $script:bothConfig.Filter.ExcludeTag
            $excludes | Should -Contain 'Flaky'
            $excludes | Should -Not -Contain 'Integration'
        }
    }
}

Describe 'Invoke-PesterTests.ps1 parameter forwarding' -Tag 'Unit' {

    BeforeEach {
        # Reset the captured configuration so each test sees a fresh value.
        Remove-Variable -Name CapturedConfig -Scope Global -ErrorAction SilentlyContinue

        $script:RunnerRepoRoot = Join-Path $TestDrive 'runner-repo'
        $global:RunnerTestRepoRoot = $script:RunnerRepoRoot
        $PinDirectory = Join-Path $script:RunnerRepoRoot 'scripts/security'
        New-Item -ItemType Directory -Path $PinDirectory -Force | Out-Null
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../security/ps-module-versions.json') -Destination $PinDirectory
        Mock git { $global:RunnerTestRepoRoot }

        # Intercept Invoke-Pester so the runner does not actually execute tests.
        # Capturing the Configuration argument lets us assert what the runner
        # constructed from its own parameters via pester.config.ps1.
        Mock -CommandName Invoke-Pester -MockWith {
            param($Configuration)
            $global:CapturedConfig = $Configuration
            return [PSCustomObject]@{
                Result       = 'Passed'
                TotalCount   = 0
                PassedCount  = 0
                FailedCount  = 0
                SkippedCount = 0
                Duration     = [TimeSpan]::Zero
                Tests        = @()
                Containers   = @()
                CodeCoverage = $null
            }
        }
        Mock -CommandName Write-Host -MockWith {}
    }

    It 'Applies the default ExcludeTag (Integration, Slow) when no overrides are passed' {
        & $script:RunnerPath
        $LASTEXITCODE | Should -Be 0
        $global:CapturedConfig | Should -Not -BeNullOrEmpty
        $excludes = Get-FilterArray $global:CapturedConfig.Filter.ExcludeTag
        $excludes | Should -Contain 'Integration'
        $excludes | Should -Contain 'Slow'
        $excludes | Should -HaveCount 2
    }

    It 'Forwards -Tag to the Pester configuration' {
        & $script:RunnerPath -Tag 'Unit'
        $LASTEXITCODE | Should -Be 0
        $tags = Get-FilterArray $global:CapturedConfig.Filter.Tag
        $tags | Should -Contain 'Unit'
    }

    It 'Forwards -IncludeTag (alias of -Tag) to the Pester configuration' {
        & $script:RunnerPath -IncludeTag 'Smoke'
        $LASTEXITCODE | Should -Be 0
        $tags = Get-FilterArray $global:CapturedConfig.Filter.Tag
        $tags | Should -Contain 'Smoke'
    }

    It 'Forwards -ExcludeTag and replaces the default exclude list' {
        & $script:RunnerPath -ExcludeTag 'Slow'
        $LASTEXITCODE | Should -Be 0
        $excludes = Get-FilterArray $global:CapturedConfig.Filter.ExcludeTag
        $excludes | Should -Contain 'Slow'
        $excludes | Should -Not -Contain 'Integration'
    }

    It 'Honors -ExcludeTag @() as a request to exclude nothing' {
        & $script:RunnerPath -ExcludeTag @()
        $LASTEXITCODE | Should -Be 0
        $excludes = Get-FilterArray $global:CapturedConfig.Filter.ExcludeTag
        $excludes | Should -HaveCount 0
    }

    It 'Keeps CI formatting and NUnit output while deferring exit until reports are written' {
        & $script:RunnerPath -CI
        $LASTEXITCODE | Should -Be 0
        $global:CapturedConfig.Run.Exit.Value | Should -BeFalse
        $global:CapturedConfig.Run.PassThru.Value | Should -BeTrue
        $global:CapturedConfig.TestResult.Enabled.Value | Should -BeTrue
        $global:CapturedConfig.TestResult.OutputFormat.Value | Should -Be 'NUnitXml'
        $global:CapturedConfig.Output.CIFormat.Value | Should -Be 'GithubActions'
        $FailureJson = Get-Content -LiteralPath (Join-Path $script:RunnerRepoRoot 'logs/pester-failures.json') -Raw
        $FailureJson | Should -Match '^\[\s*\]\s*$'
    }
}

Describe 'CI runner report finalization' -Tag 'Unit' {
    It 'Finalizes JSON and coverage before exiting <ExpectedExit>' -ForEach @(
        @{ Case = 'passing'; ExpectedValue = 1; ExpectedExit = 0; FailedCount = 0 }
        @{ Case = 'failing'; ExpectedValue = 2; ExpectedExit = 1; FailedCount = 1 }
    ) {
        $FixtureRoot = Join-Path $TestDrive $Case
        $TestsRoot = Join-Path $FixtureRoot 'scripts/tests'
        $CiRoot = Join-Path $FixtureRoot 'scripts/ci'
        $SecurityRoot = Join-Path $FixtureRoot 'scripts/security'
        New-Item -ItemType Directory -Path $TestsRoot, $CiRoot, $SecurityRoot -Force | Out-Null
        Copy-Item -LiteralPath $script:RunnerPath, $script:ConfigPath -Destination $TestsRoot
        Copy-Item -LiteralPath (Join-Path $PSScriptRoot '../security/ps-module-versions.json') -Destination $SecurityRoot
        '{"private":true,"scripts":{"test:ps":"pwsh -NoProfile -File scripts/tests/Invoke-PesterTests.ps1"}}' |
            Set-Content -LiteralPath (Join-Path $FixtureRoot 'package.json')
        'function Get-RunnerFixtureValue { 1 }' |
            Set-Content -LiteralPath (Join-Path $CiRoot 'RunnerFixture.ps1')
        @"
BeforeAll { . (Join-Path `$PSScriptRoot '../ci/RunnerFixture.ps1') }
Describe 'Report fixture' -Tag 'Unit' {
    It 'always passes' { Get-RunnerFixtureValue | Should -Be 1 }
    It 'matches the requested result' { Get-RunnerFixtureValue | Should -Be $ExpectedValue }
}
"@ | Set-Content -LiteralPath (Join-Path $TestsRoot 'RunnerFixture.Tests.ps1')

        Push-Location $FixtureRoot
        try {
            $Output = & npm run test:ps -- -CI -CodeCoverage -TestPath scripts/tests/RunnerFixture.Tests.ps1 2>&1
            $ExitCode = $LASTEXITCODE
        }
        finally {
            Pop-Location
        }

        $ExitCode | Should -Be $ExpectedExit -Because (($Output | Select-Object -Last 5) -join "`n")
        $LogsRoot = Join-Path $FixtureRoot 'logs'
        $Summary = Get-Content -LiteralPath (Join-Path $LogsRoot 'pester-summary.json') -Raw | ConvertFrom-Json
        $Summary.TotalCount | Should -Be 2
        $Summary.FailedCount | Should -Be $FailedCount
        $Summary.PassedCount | Should -Be (2 - $FailedCount)
        $Summary.CoveragePercent | Should -BeGreaterThan 0
        $Summary.CoverageTarget | Should -Be 80
        $Summary.Result | Should -Be $(if ($FailedCount) { 'Failed' } else { 'Passed' })
        $FailureJson = Get-Content -LiteralPath (Join-Path $LogsRoot 'pester-failures.json') -Raw
        $FailureJson | Should -Match '^\s*\['
        $Failures = ConvertFrom-Json -InputObject $FailureJson -NoEnumerate
        $Failures.Count | Should -Be $FailedCount
        if ($FailedCount) {
            $Failures[0].Name | Should -Be 'matches the requested result'
            $Failures[0].ErrorMessage | Should -Not -BeNullOrEmpty
        }
        (Join-Path $LogsRoot 'pester-results.xml') | Should -Exist
        (Join-Path $LogsRoot 'coverage.xml') | Should -Exist
    }
}

AfterAll {
    Remove-Variable -Name CapturedConfig, RunnerTestRepoRoot -Scope Global -ErrorAction SilentlyContinue
}
