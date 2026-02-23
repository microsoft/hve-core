#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Pester tests for Find-CollectionManifests.ps1 script
.DESCRIPTION
    Tests for collection manifest discovery and matrix building:
    - Empty collections directory returns empty matrix
    - Single stable collection returns one matrix item
    - Deprecated collections are always skipped
    - Experimental collections skipped for Stable channel
    - Experimental collections included for Preview channel
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
}

AfterAll {
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}

Describe 'Find-CollectionManifests' -Tag 'Unit' {

    Context 'Empty collections directory' {
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

            @"
id: test-collection
name: Test Collection
maturity: stable
"@ | Set-Content -Path (Join-Path $script:TempDir 'test.collection.yml')
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

            @"
id: old-collection
name: Old Collection
maturity: deprecated
"@ | Set-Content -Path (Join-Path $script:TempDir 'old.collection.yml')
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

    Context 'Experimental skipped for Stable channel' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            @"
id: exp-collection
name: Experimental Collection
maturity: experimental
"@ | Set-Content -Path (Join-Path $script:TempDir 'exp.collection.yml')
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Excludes experimental from Stable channel matrix' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $result.MatrixItems | Should -HaveCount 0
        }

        It 'Tracks experimental in Skipped with reason' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $result.Skipped | Should -HaveCount 1
            $result.Skipped[0].Reason | Should -BeLike '*experimental*'
        }
    }

    Context 'Experimental included for Preview channel' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            @"
id: exp-collection
name: Experimental Collection
maturity: experimental
"@ | Set-Content -Path (Join-Path $script:TempDir 'exp.collection.yml')
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

            @"
id: stable-one
name: Stable One
maturity: stable
"@ | Set-Content -Path (Join-Path $script:TempDir 'stable-one.collection.yml')

            @"
id: stable-two
name: Stable Two
maturity: stable
"@ | Set-Content -Path (Join-Path $script:TempDir 'stable-two.collection.yml')

            @"
id: deprecated-one
name: Deprecated One
maturity: deprecated
"@ | Set-Content -Path (Join-Path $script:TempDir 'deprecated-one.collection.yml')
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

            @"
id: good-one
name: Good One
maturity: stable
"@ | Set-Content -Path (Join-Path $script:TempDir 'good.collection.yml')

            @"
id: dep-one
name: Deprecated One
maturity: deprecated
"@ | Set-Content -Path (Join-Path $script:TempDir 'dep.collection.yml')

            @"
id: exp-one
name: Experimental One
maturity: experimental
"@ | Set-Content -Path (Join-Path $script:TempDir 'exp.collection.yml')
        }

        AfterEach {
            Remove-Item -Path $script:TempDir -Recurse -Force -ErrorAction SilentlyContinue
        }

        It 'Tracks all skipped collections' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $result.Skipped | Should -HaveCount 2
            $result.Skipped.Id | Should -Contain 'dep-one'
            $result.Skipped.Id | Should -Contain 'exp-one'
        }

        It 'Includes correct reason for deprecated' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $depSkip = $result.Skipped | Where-Object { $_.Id -eq 'dep-one' }
            $depSkip.Reason | Should -Be 'deprecated'
        }

        It 'Includes correct reason for experimental' {
            $result = Find-CollectionManifestsCore -Channel 'Stable' -CollectionsDir $script:TempDir
            $expSkip = $result.Skipped | Where-Object { $_.Id -eq 'exp-one' }
            $expSkip.Reason | Should -BeLike '*experimental*'
        }
    }

    Context 'Missing name falls back to id' {
        BeforeEach {
            $script:TempDir = Join-Path ([System.IO.Path]::GetTempPath()) "pester-$([Guid]::NewGuid().ToString('N').Substring(0,8))"
            New-Item -ItemType Directory -Path $script:TempDir -Force | Out-Null

            @"
id: no-name-collection
maturity: stable
"@ | Set-Content -Path (Join-Path $script:TempDir 'noname.collection.yml')
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

            @"
id: no-maturity
name: No Maturity
"@ | Set-Content -Path (Join-Path $script:TempDir 'nomaturity.collection.yml')
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

            @"
id: stable-guard
name: Stable Guard
maturity: stable
"@ | Set-Content -Path (Join-Path $script:TempDir 'stable.collection.yml')

            @"
id: dep-guard
name: Deprecated Guard
maturity: deprecated
"@ | Set-Content -Path (Join-Path $script:TempDir 'dep.collection.yml')

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
