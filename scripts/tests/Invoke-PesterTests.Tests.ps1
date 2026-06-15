#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
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
}

AfterAll {
    Remove-Variable -Name CapturedConfig -Scope Global -ErrorAction SilentlyContinue
}
