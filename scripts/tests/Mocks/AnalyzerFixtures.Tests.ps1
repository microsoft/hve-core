#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot 'AnalyzerFixtures.psm1'
    Import-Module $script:ModulePath -Force
}

AfterAll {
    Remove-Module AnalyzerFixtures -Force -ErrorAction SilentlyContinue
}

Describe 'New-MockAnalyzerIssue' -Tag 'Unit' {
    Context 'Default invocation' {
        BeforeAll {
            $script:Issue = New-MockAnalyzerIssue
        }

        It 'Returns a PSCustomObject' {
            $script:Issue | Should -BeOfType ([pscustomobject])
        }

        It 'Exposes the documented default <Property> value' -TestCases @(
            @{ Property = 'ScriptPath'; Expected = 'test.ps1' }
            @{ Property = 'Line';       Expected = 1 }
            @{ Property = 'Column';     Expected = 1 }
            @{ Property = 'RuleName';   Expected = 'TestRule' }
            @{ Property = 'Severity';   Expected = 'Warning' }
            @{ Property = 'Message';    Expected = 'Test message' }
        ) {
            param($Property, $Expected)
            $script:Issue.$Property | Should -Be $Expected
        }

        It 'Exposes only the documented default property set' {
            ($script:Issue.PSObject.Properties.Name | Sort-Object) |
                Should -Be (@('Column', 'Line', 'Message', 'RuleName', 'ScriptPath', 'Severity') | Sort-Object)
        }
    }

    Context 'Parameter overrides' {
        It 'Honors the <Parameter> override' -TestCases @(
            @{ Parameter = 'ScriptPath'; Value = 'src/foo.ps1' }
            @{ Parameter = 'Line';       Value = 42 }
            @{ Parameter = 'Column';     Value = 7 }
            @{ Parameter = 'RuleName';   Value = 'PSAvoidUsingCmdletAliases' }
            @{ Parameter = 'Severity';   Value = 'Error' }
            @{ Parameter = 'Message';    Value = 'avoid alias' }
        ) {
            param($Parameter, $Value)
            $splat = @{ $Parameter = $Value }
            $issue = New-MockAnalyzerIssue @splat
            $issue.$Parameter | Should -Be $Value
        }

        It 'Honors all overrides together' {
            $issue = New-MockAnalyzerIssue `
                -ScriptPath 'src/bar.ps1' `
                -Line 10 `
                -Column 5 `
                -RuleName 'PSUseDeclaredVarsMoreThanAssignments' `
                -Severity 'Information' `
                -Message 'declared but unused'

            $issue.ScriptPath | Should -Be 'src/bar.ps1'
            $issue.Line       | Should -Be 10
            $issue.Column     | Should -Be 5
            $issue.RuleName   | Should -Be 'PSUseDeclaredVarsMoreThanAssignments'
            $issue.Severity   | Should -Be 'Information'
            $issue.Message    | Should -Be 'declared but unused'
        }
    }

    Context 'Parameter validation' {
        It 'Rejects Severity values outside the PSScriptAnalyzer enum' {
            { New-MockAnalyzerIssue -Severity 'Critical' } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,New-MockAnalyzerIssue'
        }

        It 'Accepts the documented Severity value <Value>' -TestCases @(
            @{ Value = 'ParseError' }
            @{ Value = 'Error' }
            @{ Value = 'Warning' }
            @{ Value = 'Information' }
        ) {
            param($Value)
            (New-MockAnalyzerIssue -Severity $Value).Severity | Should -Be $Value
        }

        It 'Rejects a non-positive <Parameter> value of <Value>' -TestCases @(
            @{ Parameter = 'Line';   Value = 0 }
            @{ Parameter = 'Line';   Value = -1 }
            @{ Parameter = 'Column'; Value = 0 }
            @{ Parameter = 'Column'; Value = -1 }
        ) {
            param($Parameter, $Value)
            $splat = @{ $Parameter = $Value }
            { New-MockAnalyzerIssue @splat } |
                Should -Throw -ErrorId 'ParameterArgumentValidationError,New-MockAnalyzerIssue'
        }
    }
}
