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
