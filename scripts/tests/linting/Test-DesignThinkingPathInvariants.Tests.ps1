#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    $script:ScanRoots = @(
        (Join-Path $script:RepoRoot '.github'),
        (Join-Path $script:RepoRoot 'docs'),
        (Join-Path $script:RepoRoot 'evals')
    ) | Where-Object { Test-Path $_ }

    # This spec names the retired locations to assert their absence, so exclude it from its own scan.
    $script:ScannedFiles = Get-ChildItem -Path $script:ScanRoots -Recurse -File |
        Where-Object { $_.Extension -in @('.md', '.yml', '.yaml') -and $_.FullName -ne $PSCommandPath }

    function Get-RelativeOffender {
        param([Parameter(ValueFromPipeline = $true)]$Match)
        process {
            $Match.Path.Substring($script:RepoRoot.Length + 1) -replace '\\', '/'
        }
    }
}

Describe 'Design Thinking path invariants' -Tag 'Unit' {
    Context 'canonical coaching-state home' {
        It 'Uses .copilot-tracking/dt/{project-slug}/ as the coaching-state home' {
            $canonical = $script:ScannedFiles |
                Select-String -Pattern '\.copilot-tracking/dt/\{project-slug\}/coaching-state\.md'

            @($canonical).Count | Should -BeGreaterThan 0 -Because 'Design Thinking consumers must reference the canonical coaching-state path'
        }

        It 'Retires the .copilot-tracking/design-thinking-sessions/ location' {
            $offenders = $script:ScannedFiles |
                Select-String -SimpleMatch -Pattern '.copilot-tracking/design-thinking-sessions' |
                Get-RelativeOffender |
                Sort-Object -Unique

            $offenders | Should -BeNullOrEmpty -Because 'the retired coaching-state location must not reappear'
        }
    }

    Context 'canonical artifact home' {
        It 'Does not scope Design Thinking artifacts to docs/design-thinking/{project-slug}/' {
            $offenders = $script:ScannedFiles |
                Select-String -SimpleMatch -Pattern 'docs/design-thinking/{project-slug}' |
                Get-RelativeOffender |
                Sort-Object -Unique

            $offenders | Should -BeNullOrEmpty -Because 'Design Thinking artifacts live under .copilot-tracking/dt/{project-slug}/'
        }
    }
}
