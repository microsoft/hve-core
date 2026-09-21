#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../extension/Resolve-VsixFile.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force
}

Describe 'Resolve-VsixFile' -Tag 'Unit' {
    Context 'when the directory holds exactly one VSIX' {
        BeforeAll {
            $script:SingleDirectory = (New-Item -Path (Join-Path $TestDrive 'single-vsix') -ItemType Directory -Force).FullName
            Set-FixtureFile -Path (Join-Path $script:SingleDirectory 'hve-core-3.3.106.vsix') -Value 'fixture asset'
            Set-FixtureFile -Path (Join-Path $script:SingleDirectory 'hve-core-3.3.106.vsix.spdx.json') -Value '{}'
            Set-FixtureFile -Path (Join-Path $script:SingleDirectory 'notes.txt') -Value 'unrelated'
        }

        It 'Returns the absolute VSIX path' {
            $resolved = Resolve-VsixFile -DirectoryPath $script:SingleDirectory
            $resolved | Should -BeExactly (Join-Path $script:SingleDirectory 'hve-core-3.3.106.vsix')
            [System.IO.Path]::IsPathRooted($resolved) | Should -BeTrue
        }

        It 'Ignores sibling assets that are not VSIX files' {
            Split-Path -Leaf (Resolve-VsixFile -DirectoryPath $script:SingleDirectory) | Should -BeExactly 'hve-core-3.3.106.vsix'
        }

        It 'Rejects the retired Path alias' {
            { Resolve-VsixFile -Path $script:SingleDirectory } | Should -Throw '*Path*'
        }
    }

    Context 'when the directory is missing' {
        It 'Throws the missing directory message' {
            $missing = Join-Path $TestDrive 'absent-vsix'
            { Resolve-VsixFile -DirectoryPath $missing } | Should -Throw "Directory not found: $missing"
        }
    }

    Context 'when the directory holds no VSIX' {
        It 'Throws the empty directory message' {
            $directory = (New-Item -Path (Join-Path $TestDrive 'empty-vsix') -ItemType Directory -Force).FullName
            Set-FixtureFile -Path (Join-Path $directory 'dependencies.spdx.json') -Value '{}'
            { Resolve-VsixFile -DirectoryPath $directory } | Should -Throw "No VSIX file found in directory: $directory"
        }
    }

    Context 'when the directory holds more than one VSIX' {
        It 'Throws the ambiguity message listing every match' {
            $directory = (New-Item -Path (Join-Path $TestDrive 'many-vsix') -ItemType Directory -Force).FullName
            Set-FixtureFile -Path (Join-Path $directory 'hve-core-3.3.106.vsix') -Value 'fixture asset'
            Set-FixtureFile -Path (Join-Path $directory 'hve-core-all-3.3.106.vsix') -Value 'fixture asset'
            { Resolve-VsixFile -DirectoryPath $directory } |
                Should -Throw 'Expected exactly one VSIX file but found 2: hve-core-3.3.106.vsix, hve-core-all-3.3.106.vsix'
        }
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
