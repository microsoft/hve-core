#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates the shared coaching-patterns instruction file presents the nine canonical
    H2 sections in order and carries the required instruction frontmatter.
#>

BeforeAll {
    $script:repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:filePath = Join-Path $script:repoRoot '.github/instructions/shared/coaching-patterns.instructions.md'

    Import-Module powershell-yaml -Force -ErrorAction SilentlyContinue

    $script:expectedSections = @(
        'Coaching Framework',
        'Context Pre-Scan',
        'Scope Assessment',
        'Exploration-First Questioning',
        'Progressive Guidance',
        'Psychological Safety',
        'Raw Capture Principles',
        'Early Tension Surfacing',
        'Output Preferences'
    )
}

Describe 'Shared coaching-patterns instruction file' {
    It 'Exists at the expected path' {
        Test-Path $script:filePath | Should -BeTrue
    }

    It 'Has YAML frontmatter with description and applyTo keys' {
        $raw = Get-Content -Path $script:filePath -Raw
        $matched = $raw -match '(?s)^---\s*\r?\n(.*?)\r?\n---'
        $matched | Should -BeTrue -Because 'frontmatter block must be present'
        $frontmatter = ConvertFrom-Yaml $Matches[1]
        $frontmatter.ContainsKey('description') | Should -BeTrue
        $frontmatter.ContainsKey('applyTo') | Should -BeTrue
        [string]::IsNullOrWhiteSpace($frontmatter.description) | Should -BeFalse
    }

    It 'Contains the nine canonical H2 sections in order' {
        $headings = Get-Content -Path $script:filePath |
            Where-Object { $_ -match '^##\s+(.+?)\s*$' } |
            ForEach-Object { ($_ -replace '^##\s+', '').Trim() }
        foreach ($section in $script:expectedSections) {
            $headings | Should -Contain $section -Because "section '$section' must be present"
        }
        $observedOrdered = $headings | Where-Object { $script:expectedSections -contains $_ }
        ($observedOrdered -join '|') | Should -Be ($script:expectedSections -join '|')
    }
}
