#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts the SSSC inline state schema stays consistent across the canonical
    identity instructions and the agent definition that copies it.
.DESCRIPTION
    The canonical SSSC `state.json` schema lives in sssc-planner.instructions.md
    and is duplicated inline in sssc-planner.agent.md. This test guards both
    copies against drift by validating that each inline block parses as JSON and
    preserves the canonical `context` keys, `phaseGates`, `userPreferences`, and
    `handoffGenerated` structures.
#>

BeforeDiscovery {
    $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:stateSchemaFiles = @(
        @{ Name = 'sssc-planner.instructions.md'; Path = (Join-Path $repoRoot '.github/instructions/security/sssc-planner.instructions.md') }
        @{ Name = 'sssc-planner.agent.md'; Path = (Join-Path $repoRoot '.github/agents/security/sssc-planner.agent.md') }
    )
}

BeforeAll {
    $script:expectedContextKeys = @('ciPlatform','complianceTargets','packageManagers','releaseStrategy','techStack')
    $script:expectedPhaseGates = @('phase1','phase2','phase3','phase4','phase5','phase6')

    function Get-InlineStateSchema {
        param([string]$Path)

        $content = Get-Content -Path $Path -Raw
        if ($content -notmatch '(?s)```json\s*\r?\n(\{.*?\})\s*\r?\n```') {
            throw "No ```json block found in $Path"
        }
        $json = $Matches[1]
        $json | Should -Not -BeNullOrEmpty
        ($json | Test-Json) | Should -BeTrue -Because "the inline state schema in $Path must be valid JSON"
        $json | ConvertFrom-Json
    }
}

Describe 'SSSC inline state schema stays consistent across copies' -Tag 'Unit' {
    It '<Name> context contains exactly the canonical key set' -TestCases $script:stateSchemaFiles {
        param($Name, $Path)

        $state = Get-InlineStateSchema -Path $Path
        $state.context | Should -Not -BeNullOrEmpty
        $observed = $state.context.PSObject.Properties.Name | Sort-Object
        $expected = $script:expectedContextKeys | Sort-Object
        ($observed -join ',') | Should -Be ($expected -join ',') -Because "context sub-object must contain exactly: $($expected -join ', ')"
    }

    It '<Name> defines all canonical phaseGates' -TestCases $script:stateSchemaFiles {
        param($Name, $Path)

        $state = Get-InlineStateSchema -Path $Path
        $state.phaseGates | Should -Not -BeNullOrEmpty -Because 'the canonical schema declares a phaseGates block'
        $observed = $state.phaseGates.PSObject.Properties.Name | Sort-Object
        $expected = $script:expectedPhaseGates | Sort-Object
        ($observed -join ',') | Should -Be ($expected -join ',') -Because "phaseGates must contain exactly: $($expected -join ', ')"
    }

    It '<Name> defines userPreferences and handoffGenerated' -TestCases $script:stateSchemaFiles {
        param($Name, $Path)

        $state = Get-InlineStateSchema -Path $Path
        $state.userPreferences | Should -Not -BeNullOrEmpty -Because 'the canonical schema declares a userPreferences block'
        $state.userPreferences.outputDetailLevel | Should -Not -BeNullOrEmpty
        $state.handoffGenerated | Should -Not -BeNullOrEmpty -Because 'the canonical schema declares a handoffGenerated block'
        $observed = $state.handoffGenerated.PSObject.Properties.Name | Sort-Object
        ($observed -join ',') | Should -Be 'ado,github' -Because 'handoffGenerated tracks both ado and github'
    }
}
