#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', 'RuleCases',
    Justification = 'Consumed by Pester -ForEach on It blocks at discovery time')]
param()

BeforeDiscovery {
    $RuleCases = @(
        @{ RuleId = 'ADR-CONSISTENCY-001'; Dir = 'affected-components-mirror' }
        @{ RuleId = 'ADR-CONSISTENCY-002'; Dir = 'success-criteria-source-resolves' }
        @{ RuleId = 'ADR-CONSISTENCY-003'; Dir = 'state-placeholder-resolved' }
        @{ RuleId = 'ADR-CONSISTENCY-004'; Dir = 'peer-planner-names' }
        @{ RuleId = 'ADR-CONSISTENCY-005'; Dir = 'drivers-matrix-cardinality' }
        @{ RuleId = 'ADR-CONSISTENCY-006'; Dir = 'risks-consequences-pairing' }
        @{ RuleId = 'ADR-CONSISTENCY-007'; Dir = 'numeric-claim-generalized' }
        @{ RuleId = 'ADR-CONSISTENCY-008'; Dir = 'driver-trigger-map-complete' }
        @{ RuleId = 'ADR-CONSISTENCY-009'; Dir = 'affected-components-cited' }
    )
}

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../linting/Modules/AdrConsistency.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot '../../linting/Modules/AdrBodyParser.psm1') -Force
    Mock Write-Host {}
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
    $script:FixtureRoot = Join-Path $PSScriptRoot 'fixtures/adr-consistency'
}

AfterAll {
    Remove-Module AdrConsistency -Force -ErrorAction SilentlyContinue
    Remove-Module AdrBodyParser -Force -ErrorAction SilentlyContinue
}

Describe 'Invoke-AdrConsistencyValidation pass fixtures' -Tag 'Unit' {
    It 'rule <RuleId> (<Dir>) pass fixture produces zero violations' -ForEach $RuleCases {
        $path = Join-Path $script:FixtureRoot $Dir 'pass.md'
        $result = Invoke-AdrConsistencyValidation -Path $path -RepoRoot $script:RepoRoot
        $result.Violations.Count | Should -Be 0
    }
}

Describe 'Invoke-AdrConsistencyValidation fail fixtures' -Tag 'Unit' {
    It 'rule <RuleId> (<Dir>) fail fixture fires the target rule' -ForEach $RuleCases {
        $path = Join-Path $script:FixtureRoot $Dir 'fail.md'
        $result = Invoke-AdrConsistencyValidation -Path $path -RepoRoot $script:RepoRoot

        $hits = @($result.Violations | Where-Object { $_.ruleId -eq $RuleId })
        $hits.Count | Should -BeGreaterThan 0
    }

    It 'rule <RuleId> (<Dir>) fail violation message has all template tokens substituted' -ForEach $RuleCases {
        $path = Join-Path $script:FixtureRoot $Dir 'fail.md'
        $result = Invoke-AdrConsistencyValidation -Path $path -RepoRoot $script:RepoRoot

        $hits = @($result.Violations | Where-Object { $_.ruleId -eq $RuleId })
        foreach ($hit in $hits) {
            $hit.message | Should -Not -Match '\{[A-Za-z_]+\}'
        }
    }
}

Describe 'Invoke-AdrConsistencyValidation return contract' -Tag 'Unit' {
    BeforeAll {
        $passPath = Join-Path $script:FixtureRoot 'affected-components-mirror' 'pass.md'
        $failPath = Join-Path $script:FixtureRoot 'affected-components-mirror' 'fail.md'
        $script:PassResult = Invoke-AdrConsistencyValidation -Path $passPath -RepoRoot $script:RepoRoot
        $script:FailResult = Invoke-AdrConsistencyValidation -Path $failPath -RepoRoot $script:RepoRoot
    }

    It 'returns an object exposing File and Violations properties' {
        $script:PassResult.PSObject.Properties.Name | Should -Contain 'File'
        $script:PassResult.PSObject.Properties.Name | Should -Contain 'Violations'
    }

    It 'File property echoes the input path' {
        $expected = Join-Path $script:FixtureRoot 'affected-components-mirror' 'pass.md'
        $script:PassResult.File | Should -Be $expected
    }

    It 'Violations is an array' {
        ($script:PassResult.Violations -is [System.Array]) | Should -BeTrue
    }

    It 'each violation exposes file, ruleId, severity, message, line' {
        $v = $script:FailResult.Violations[0]
        $v.PSObject.Properties.Name | Should -Contain 'file'
        $v.PSObject.Properties.Name | Should -Contain 'ruleId'
        $v.PSObject.Properties.Name | Should -Contain 'severity'
        $v.PSObject.Properties.Name | Should -Contain 'message'
        $v.PSObject.Properties.Name | Should -Contain 'line'
    }

    It 'violation severity is a registry-defined label' {
        $script:FailResult.Violations[0].severity | Should -BeIn @('error', 'warn')
    }

    It 'throws when the ADR file does not exist' {
        $missing = Join-Path $TestDrive 'does-not-exist.md'
        { Invoke-AdrConsistencyValidation -Path $missing -RepoRoot $script:RepoRoot } | Should -Throw
    }
}
