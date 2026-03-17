#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../scripts/shared.psm1') -Force
}

Describe 'Get-RepositoryRoot' {
    Context 'Default (fallback) mode' {
        It 'Returns a valid directory when in a git repository' {
            $result = Get-RepositoryRoot
            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $result -PathType Container | Should -BeTrue
        }

        It 'Returns path containing .git directory' {
            $result = Get-RepositoryRoot
            Test-Path -Path (Join-Path $result '.git') | Should -BeTrue
        }

        It 'Falls back to current directory when git fails' {
            Mock git { $global:LASTEXITCODE = 128; return $null } -ModuleName shared
            $result = Get-RepositoryRoot
            $result | Should -Be $PWD.Path
        }

        It 'Falls back to current directory when git returns empty' {
            Mock git { $global:LASTEXITCODE = 0; return '' } -ModuleName shared
            $result = Get-RepositoryRoot
            $result | Should -Be $PWD.Path
        }
    }

    Context 'Strict mode' {
        It 'Returns a valid directory when in a git repository' {
            $result = Get-RepositoryRoot -Strict
            $result | Should -Not -BeNullOrEmpty
            Test-Path -Path $result -PathType Container | Should -BeTrue
        }

        It 'Throws when repository root cannot be determined' {
            Mock git { $global:LASTEXITCODE = 0; return '' } -ModuleName shared
            { Get-RepositoryRoot -Strict } | Should -Throw '*Unable to determine repository root*'
        }
    }
}

Describe 'Resolve-DefaultBranch' {
    Context 'Successful resolution' {
        It 'Returns a branch reference' {
            $result = Resolve-DefaultBranch
            $result | Should -Not -BeNullOrEmpty
            $result | Should -BeOfType [string]
        }

        It 'Returns origin-prefixed branch name' {
            $result = Resolve-DefaultBranch
            $result | Should -Match '^origin/'
        }
    }

    Context 'Fallback behavior' {
        It 'Falls back to origin/main when symbolic-ref fails' {
            Mock git { $global:LASTEXITCODE = 1; return $null } -ModuleName shared
            $result = Resolve-DefaultBranch
            $result | Should -Be 'origin/main'
        }

        It 'Falls back to origin/main when symbolic-ref returns empty' {
            Mock git { $global:LASTEXITCODE = 0; return '' } -ModuleName shared
            $result = Resolve-DefaultBranch
            $result | Should -Be 'origin/main'
        }
    }
}

Describe 'Build-PathspecExclusions' {
    Context 'Extension exclusions' {
        It 'Returns pathspec for single extension' {
            $result = Build-PathspecExclusions -Extensions @('yml')
            $result | Should -Contain ':!*.yml'
        }

        It 'Returns pathspecs for multiple extensions' {
            $result = Build-PathspecExclusions -Extensions @('yml', 'json', 'png')
            $result.Count | Should -Be 3
            $result | Should -Contain ':!*.yml'
            $result | Should -Contain ':!*.json'
            $result | Should -Contain ':!*.png'
        }

        It 'Strips leading dots from extensions' {
            $result = Build-PathspecExclusions -Extensions @('.yml', '.json')
            $result | Should -Contain ':!*.yml'
            $result | Should -Contain ':!*.json'
        }

        It 'Returns empty array for empty extensions input' {
            $result = Build-PathspecExclusions -Extensions @()
            $result.Count | Should -Be 0
        }

        It 'Skips empty extension strings' {
            $result = Build-PathspecExclusions -Extensions @('yml', '', 'json')
            $result.Count | Should -Be 2
        }
    }

    Context 'Path exclusions' {
        It 'Returns pathspec for single path' {
            $result = Build-PathspecExclusions -Paths @('docs/')
            $result | Should -Contain ':!docs/**'
        }

        It 'Returns pathspecs for multiple paths' {
            $result = Build-PathspecExclusions -Paths @('docs/', '.github/skills/')
            $result.Count | Should -Be 2
            $result | Should -Contain ':!docs/**'
            $result | Should -Contain ':!.github/skills/**'
        }

        It 'Strips trailing slashes from paths' {
            $result = Build-PathspecExclusions -Paths @('docs/')
            $result | Should -Contain ':!docs/**'
        }

        It 'Handles paths without trailing slash' {
            $result = Build-PathspecExclusions -Paths @('docs')
            $result | Should -Contain ':!docs/**'
        }

        It 'Returns empty array for empty paths input' {
            $result = Build-PathspecExclusions -Paths @()
            $result.Count | Should -Be 0
        }

        It 'Skips empty path strings' {
            $result = Build-PathspecExclusions -Paths @('docs/', '', '.github/')
            $result.Count | Should -Be 2
        }
    }

    Context 'Combined exclusions' {
        It 'Returns pathspecs for both extensions and paths' {
            $result = Build-PathspecExclusions -Extensions @('yml') -Paths @('docs/')
            $result.Count | Should -Be 2
            $result | Should -Contain ':!*.yml'
            $result | Should -Contain ':!docs/**'
        }

        It 'Returns empty array when both inputs are empty' {
            $result = Build-PathspecExclusions -Extensions @() -Paths @()
            $result.Count | Should -Be 0
        }
    }

    Context 'Default parameters' {
        It 'Returns empty array when called without parameters' {
            $result = Build-PathspecExclusions
            $result.Count | Should -Be 0
        }
    }
}
