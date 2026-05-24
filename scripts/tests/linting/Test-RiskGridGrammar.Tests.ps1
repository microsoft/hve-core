#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts the Security Planner has no risk multiplication notation and the
    security-model named-bucket grid markers are present.
.NOTES
    Effective case count: 7 (2 multiplication-notation cases via `-ForEach $script:files`
    + 5 bucket-name cases via `-ForEach $script:bucketNames`).
#>

$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$script:files = @(
    (Join-Path $script:repoRoot '.github/instructions/security/security-model.instructions.md'),
    (Join-Path $script:repoRoot '.github/agents/security/security-planner.agent.md')
)
$script:gridFile = Join-Path $script:repoRoot '.github/instructions/security/security-model.instructions.md'
$script:bucketNames = @('Critical','High','Medium','Low','Informational')

Describe 'Risk multiplication notation is forbidden' {
    It 'File <_> has no Likelihood × Impact / numeric multiplication notation' -ForEach $script:files {
        Test-Path $_ | Should -BeTrue -Because "fixture file must exist: $_"
        $content = Get-Content -Path $_ -Raw
        $content | Should -Not -Match 'Likelihood\s*[\u00d7x\*]\s*Impact'
        $content | Should -Not -Match '(?i)risk\s*=\s*likelihood\s*[\u00d7x\*]\s*impact'
    }
}

Describe 'Named-bucket risk grid is present' {
    BeforeAll {
        $script:gridFile = Join-Path (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path '.github/instructions/security/security-model.instructions.md'
    }

    It 'security-model.instructions.md lists every named bucket: <_>' -ForEach $script:bucketNames {
        $content = Get-Content -Path $script:gridFile -Raw
        $content | Should -Match "\b$_\b"
    }
}
