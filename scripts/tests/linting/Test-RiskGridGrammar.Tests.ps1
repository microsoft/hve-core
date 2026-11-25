#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Asserts the Security Planner has no risk multiplication notation and the
    security-planning skill named-bucket grid markers are present.
.NOTES
    Effective case count: 7 (2 multiplication-notation cases via `-ForEach $script:files`
    + 5 bucket-name cases via `-ForEach $script:bucketNames`).
#>

Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/ArtifactHelpers.psm1') -Force
$script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
$script:files = @(
    (Resolve-CanonicalArtifactPath -RepoRoot $script:repoRoot -Path '.github/skills/project-planning/security-planning/references/stride-model.md'),
    (Resolve-CanonicalArtifactPath -RepoRoot $script:repoRoot -Path '.github/agents/security/security-planner.agent.md')
)
$script:gridFile = Resolve-CanonicalArtifactPath -RepoRoot $script:repoRoot -Path '.github/skills/project-planning/security-planning/references/stride-model.md'
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
        Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/ArtifactHelpers.psm1') -Force
        $script:gridFile = Resolve-CanonicalArtifactPath -RepoRoot (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path -Path '.github/skills/project-planning/security-planning/references/stride-model.md'
    }

    It 'stride-model.md lists every named bucket: <_>' -ForEach $script:bucketNames {
        $content = Get-Content -Path $script:gridFile -Raw
        $content | Should -Match "\b$_\b"
    }
}
