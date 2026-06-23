#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts tiered phase gates, notice fields, and `referencesProcessed` defaults
    in the inline JSON-literal state block of both planner identity files.
.NOTES
    Effective case count: 10 (5 `It` blocks x `-ForEach $script:identityFiles` arity 2).
#>

$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

$script:identityFiles = @(
    (Join-Path $script:repoRoot '.github/instructions/security/identity.instructions.md'),
    (Join-Path $script:repoRoot '.github/instructions/security/sssc-planner.instructions.md')
)

Describe 'Inline planner state schema defaults' -Tag 'Unit' {
    BeforeAll {
        function Get-InlineStateJson {
            param([string]$Path)
            $content = Get-Content -Path $Path -Raw
            if ($content -notmatch '(?s)```json\s*\r?\n(\{.*?\})\s*\r?\n```') {
                throw "No ``````json block found in $Path"
            }
            return $Matches[1] | ConvertFrom-Json
        }
    }

    It 'Identity <_> defines disclaimerShownAt as null' -ForEach $script:identityFiles {
        $state = Get-InlineStateJson -Path $_
        $state.PSObject.Properties.Name | Should -Contain 'disclaimerShownAt'
        $state.disclaimerShownAt | Should -BeNullOrEmpty
    }

    It 'Identity <_> defines noticeLog as empty array' -ForEach $script:identityFiles {
        $state = Get-InlineStateJson -Path $_
        $state.PSObject.Properties.Name | Should -Contain 'noticeLog'
        @($state.noticeLog).Count | Should -Be 0
    }

    It 'Identity <_> defines tiered hard gates on phases 1, 4, 6 with confirmedAt null' -ForEach $script:identityFiles {
        $state = Get-InlineStateJson -Path $_
        foreach ($phase in 'phase1','phase4','phase6') {
            $gate = $state.phaseGates.$phase
            $gate | Should -Not -BeNullOrEmpty -Because "$phase must be present in phaseGates"
            $gate.gate | Should -Be 'hard'
            $gate.confirmedAt | Should -BeNullOrEmpty
        }
    }

    It 'Identity <_> defines summary-and-advance gates on phases 2, 3, 5' -ForEach $script:identityFiles {
        $state = Get-InlineStateJson -Path $_
        foreach ($phase in 'phase2','phase3','phase5') {
            $gate = $state.phaseGates.$phase
            $gate | Should -Not -BeNullOrEmpty
            $gate.gate | Should -Be 'summary-and-advance'
        }
    }

    It 'Identity <_> defines referencesProcessed as empty array' -ForEach $script:identityFiles {
        $state = Get-InlineStateJson -Path $_
        $state.PSObject.Properties.Name | Should -Contain 'referencesProcessed'
        @($state.referencesProcessed).Count | Should -Be 0
    }
}
