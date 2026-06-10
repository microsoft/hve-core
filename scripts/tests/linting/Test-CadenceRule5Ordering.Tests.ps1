#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts Cadence Rule 5 in both planner identity files leads with open-ended
    discovery before any mention of option lists.
.NOTES
    Effective case count: 2 (1 `It` block x `-ForEach $script:files` arity 2).
#>

$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$script:files = @(
    (Join-Path $script:repoRoot '.github/instructions/security/identity.instructions.md'),
    (Join-Path $script:repoRoot '.github/instructions/security/sssc-identity.instructions.md')
)

Describe 'Cadence Rule 5 enforces discovery-first ordering' {
    BeforeAll {
        function Get-Rule5Text {
            param([string]$Path)
            $lines = Get-Content -Path $Path
            $inCadence = $false
            foreach ($line in $lines) {
                if ($line -match '^###\s+Seven Rules\b') { $inCadence = $true; continue }
                if ($inCadence -and $line -match '^##\s+') { break }
                if ($inCadence -and $line -match '^\s*5\.\s+') {
                    return ($line -replace '^\s*5\.\s+','').Trim()
                }
            }
            return ''
        }
    }

    It 'Identity file <_> states discovery before option lists' -ForEach $script:files {
        Test-Path $_ | Should -BeTrue
        $text = Get-Rule5Text -Path $_
        $text | Should -Not -BeNullOrEmpty -Because "Rule 5 must be present in $_"
        $text | Should -Match '(?i)discover' -Because "Rule 5 must mention discovery"
        $discoverIdx = $text.ToLower().IndexOf('discover')
        $optionIdx = $text.ToLower().IndexOf('option')
        $discoverIdx | Should -BeGreaterOrEqual 0
        $optionIdx | Should -BeGreaterThan $discoverIdx -Because "discovery wording must precede option-list wording in Rule 5"
    }
}
