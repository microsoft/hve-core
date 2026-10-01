#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../security/Assert-WorkflowProjectDirectory.ps1')
}

Describe 'Assert-WorkflowProjectDirectory' -Tag 'Unit' {
    Context 'when the candidate is a legitimate repository-relative project directory' {
        It 'accepts <Value>' -ForEach @(
            @{ Value = '.' }
            @{ Value = 'scripts' }
            @{ Value = 'docs/docusaurus' }
            @{ Value = '.github/skills/project-planning/security-planning' }
            @{ Value = 'evals/beval' }
        ) {
            Get-WorkflowProjectDirectoryRejection -Candidate $Value | Should -BeNullOrEmpty
        }

        It 'returns the complete validated list unchanged' {
            $candidates = @('scripts', 'docs/docusaurus', '.')
            Assert-WorkflowProjectDirectory -Path $candidates | Should -Be $candidates
        }
    }

    Context 'when the candidate carries a shell metacharacter or quote' {
        It 'rejects <Value>' -ForEach @(
            @{ Value = "skills/it's-a-trap" }
            @{ Value = 'skills/say"hello' }
            @{ Value = 'skills/$(whoami)' }
            @{ Value = 'skills/`id`' }
            @{ Value = 'skills/a;rm -rf' }
            @{ Value = 'skills/a b' }
        ) {
            Get-WorkflowProjectDirectoryRejection -Candidate $Value | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when the candidate carries a control character or empty value' {
        It 'rejects <Name>' -ForEach @(
            @{ Name = 'newline'; Value = "skills/a`nb" }
            @{ Name = 'carriage return'; Value = "skills/a`rb" }
            @{ Name = 'tab'; Value = "skills/a`tb" }
            @{ Name = 'empty string'; Value = '' }
            @{ Name = 'leading whitespace'; Value = ' scripts' }
        ) {
            Get-WorkflowProjectDirectoryRejection -Candidate $Value | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when the candidate is absolute or uses a backslash separator' {
        It 'rejects <Value>' -ForEach @(
            @{ Value = '/etc/passwd' }
            @{ Value = '/scripts' }
            @{ Value = 'C:/Windows' }
            @{ Value = 'scripts\security' }
            @{ Value = '\\server\share' }
        ) {
            Get-WorkflowProjectDirectoryRejection -Candidate $Value | Should -Not -BeNullOrEmpty
        }
    }

    Context 'when the candidate contains a traversal or empty segment' {
        It 'rejects <Value>' -ForEach @(
            @{ Value = '../outside' }
            @{ Value = 'scripts/../../etc' }
            @{ Value = 'scripts/./security' }
            @{ Value = 'scripts//security' }
            @{ Value = 'scripts/' }
        ) {
            Get-WorkflowProjectDirectoryRejection -Candidate $Value | Should -Not -BeNullOrEmpty
        }

        It 'throws for the whole list when one candidate is unsafe' {
            { Assert-WorkflowProjectDirectory -Path @('scripts', '../outside', 'docs') } |
                Should -Throw -ExpectedMessage '*Unsafe project directory detected*'
        }
    }
}
