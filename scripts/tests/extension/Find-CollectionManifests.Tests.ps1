#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Find-CollectionManifests.ps1 script
.DESCRIPTION
    Tests for collection manifest discovery and matrix building. Discovery now
    reads the central core manifest (collections/core-manifest.yml) and projects
    per-collection manifests via ConvertTo-CollectionManifestFromCore, so each
    fixture builds a temp core-manifest.yml with a collections map:
    - Missing core manifest returns empty matrix
    - Single stable collection returns one matrix item
    - Deprecated and removed collections are always skipped
    - Experimental collections are included for all channels (per-item maturity
      gating is enforced downstream by Prepare-Extension)
    - Multiple collections produce correct matrix JSON
    - Skipped collections tracked in Skipped property
    - Missing name falls back to id
    - Missing maturity defaults to stable
#>

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../extension/Find-CollectionManifests.ps1'
    $script:CIHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'

    # Import modules for mocking
    Import-Module $script:CIHelpersPath -Force

    # Dot-source the script to access Find-CollectionManifestsCore
    . $script:ScriptPath

    # Writes a temp core-manifest.yml with a collections map. Each collection is a
    # hashtable with an Id key and optional Name and Maturity keys, mirroring the
    # collection-level metadata that ConvertTo-CollectionManifestFromCore projects.
    function New-TestCoreManifest {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Dir,

            [Parameter(Mandatory = $true)]
            [object[]]$Collections
        )

        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('schemaVersion: "1.0"')
        $lines.Add('collections:')
        foreach ($collection in $Collections) {
            $lines.Add("  $($collection.Id):")
            $lines.Add("    path: collections/$($collection.Id).collection.yml")
            if ($collection.Contains('Name')) {
                $lines.Add("    name: $($collection.Name)")
            }
            if ($collection.Contains('Maturity')) {
                $lines.Add("    maturity: $($collection.Maturity)")
            }
        }

        Set-Content -Path (Join-Path $Dir 'core-manifest.yml') -Value ($lines -join "`n")
    }
}

AfterAll {
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Find-CollectionManifests' -Tag 'Unit' {

    Context 'Missing core manifest' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns empty matrix JSON' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixJson | Should -Be '{"include":[]}'
        }

        It 'Returns empty MatrixItems' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 0
        }
    }

    Context 'Single stable collection' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'test-collection'; Name = 'Test Collection'; Maturity = 'stable' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Returns one matrix item' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 1
        }

        It 'Includes correct id and name' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems[0].id | Should -Be 'test-collection'
            $result.MatrixItems[0].name | Should -Be 'Test Collection'
        }

        It 'Includes manifest path with forward slashes' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems[0].manifest | Should -Not -BeLike '*\*'
        }
    }

    Context 'Deprecated collections always skipped' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'old-collection'; Name = 'Old Collection'; Maturity = 'deprecated' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Excludes deprecated from matrix' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 0
        }

        It 'Tracks deprecated in Skipped' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.Skipped | Should -HaveCount 1
            $result.Skipped[0].Reason | Should -Be 'deprecated'
        }
    }

    Context 'Removed collections always skipped' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'gone-collection'; Name = 'Gone Collection'; Maturity = 'removed' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Excludes removed from matrix on Stable channel' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir -Channel 'Stable'
            $result.MatrixItems | Should -HaveCount 0
        }

        It 'Excludes removed from matrix on Preview channel' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir -Channel 'Preview'
            $result.MatrixItems | Should -HaveCount 0
        }

        It 'Tracks removed in Skipped with reason removed' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.Skipped | Should -HaveCount 1
            $result.Skipped[0].Reason | Should -Be 'removed'
        }
    }

    Context 'Experimental included for Stable channel' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'exp-collection'; Name = 'Experimental Collection'; Maturity = 'experimental' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Includes experimental in Stable channel matrix (per-item gating happens downstream)' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 1
            $result.MatrixItems[0].id | Should -Be 'exp-collection'
        }

        It 'Does not track experimental in Skipped' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $result.Skipped | Should -HaveCount 0
        }
    }

    Context 'Experimental included for Preview channel' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'exp-collection'; Name = 'Experimental Collection'; Maturity = 'experimental' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Includes experimental for Preview channel' {
            $result = Find-CollectionManifestsCore -Channel 'Preview' -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 1
            $result.MatrixItems[0].id | Should -Be 'exp-collection'
        }
    }

    Context 'Multiple collections produce correct matrix' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'stable-one'; Name = 'Stable One'; Maturity = 'stable' }
                @{ Id = 'stable-two'; Name = 'Stable Two'; Maturity = 'stable' }
                @{ Id = 'deprecated-one'; Name = 'Deprecated One'; Maturity = 'deprecated' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Includes only non-deprecated collections' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 2
        }

        It 'Produces valid matrix JSON' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            { $result.MatrixJson | ConvertFrom-Json } | Should -Not -Throw
        }

        It 'Matrix JSON contains include array with correct count' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $parsed = $result.MatrixJson | ConvertFrom-Json
            $parsed.include | Should -HaveCount 2
        }
    }

    Context 'Skipped collections tracked with reasons' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'good-one'; Name = 'Good One'; Maturity = 'stable' }
                @{ Id = 'dep-one'; Name = 'Deprecated One'; Maturity = 'deprecated' }
                @{ Id = 'exp-one'; Name = 'Experimental One'; Maturity = 'experimental' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Tracks only deprecated/removed collections as skipped' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $result.Skipped | Should -HaveCount 1
            $result.Skipped.Id | Should -Contain 'dep-one'
        }

        It 'Includes correct reason for deprecated' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $depSkip = $result.Skipped | Where-Object { $_.Id -eq 'dep-one' }
            $depSkip.Reason | Should -Be 'deprecated'
        }

        It 'Does not skip experimental on Stable channel' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $expSkip = $result.Skipped | Where-Object { $_.Id -eq 'exp-one' }
            $expSkip | Should -BeNullOrEmpty
            $result.MatrixItems.id | Should -Contain 'exp-one'
        }
    }

    Context 'Missing name falls back to id' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'no-name-collection'; Maturity = 'stable' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Uses id as name when name field is missing' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems[0].name | Should -Be 'no-name-collection'
        }
    }

    Context 'Missing maturity defaults to stable' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'no-maturity'; Name = 'No Maturity' }
            )
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Defaults maturity to stable when missing' {
            $result = Find-CollectionManifestsCore -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 1
            $result.MatrixItems[0].maturity | Should -Be 'stable'
        }
    }

    Context 'Script guard execution with skipped collections' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            New-TestCoreManifest -Dir $script:TempDir -Collections @(
                @{ Id = 'stable-guard'; Name = 'Stable Guard'; Maturity = 'stable' }
                @{ Id = 'dep-guard'; Name = 'Deprecated Guard'; Maturity = 'deprecated' }
            )

            $script:OutputFile = Join-Path $script:TempDir 'github_output'
            New-Item -ItemType File -Path $script:OutputFile -Force | Out-Null
            $env:GITHUB_OUTPUT = $script:OutputFile
            $env:GITHUB_ACTIONS = 'true'
        }

        AfterEach {
            $env:GITHUB_OUTPUT = $null
            $env:GITHUB_ACTIONS = $null
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Writes matrix output to GITHUB_OUTPUT' {
            & $script:ScriptPath -CollectionsDir $script:TempDir
            $content = Get-Content $script:OutputFile -Raw
            $content | Should -Match 'matrix='
        }

        It 'Emits notice for skipped collections' {
            $output = & $script:ScriptPath -CollectionsDir $script:TempDir 6>&1 | Out-String
            $output | Should -Match '::notice::Skipping Deprecated Guard'
        }

        It 'Outputs discovered collections JSON to host' {
            $output = & $script:ScriptPath -CollectionsDir $script:TempDir 6>&1 | Out-String
            $output | Should -Match 'Discovered collections:'
        }
    }
}
