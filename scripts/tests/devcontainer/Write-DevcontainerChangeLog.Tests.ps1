#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../devcontainer/Write-DevcontainerChangeLog.ps1')
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1') -Force

    Mock Write-Host {}
    Mock Write-CIAnnotation {}
    Mock Write-CIStepSummary {}
}

Describe 'Get-DevcontainerFileClassification' -Tag 'Unit' {
    It 'Classifies <Path> as <Category> with <Impact> impact' -ForEach @(
        @{ Path = '.devcontainer/scripts/on-create.sh'; Category = 'Lifecycle Scripts'; Impact = 'High' }
        @{ Path = '.devcontainer/scripts/post-create.sh'; Category = 'Lifecycle Scripts'; Impact = 'Low' }
        @{ Path = '.devcontainer/Dockerfile'; Category = 'Base Image'; Impact = 'High' }
        @{ Path = '.devcontainer/Dockerfile.custom'; Category = 'Base Image'; Impact = 'High' }
        @{ Path = '.devcontainer/base.dockerfile'; Category = 'Base Image'; Impact = 'High' }
        @{ Path = '.devcontainer/features/custom-feature'; Category = 'Features'; Impact = 'Medium' }
        @{ Path = '.devcontainer/devcontainer.json'; Category = 'Config'; Impact = 'High' }
        @{ Path = '.devcontainer/devcontainer-lock.json'; Category = 'Lockfile'; Impact = 'Medium' }
        @{ Path = '.github/workflows/copilot-setup-steps.yml'; Category = 'Setup Steps'; Impact = 'Medium' }
        @{ Path = '.devcontainer/something-else.txt'; Category = 'Config'; Impact = 'Medium' }
        @{ Path = 'unrelated/file.txt'; Category = 'Other'; Impact = 'Unknown' }
    ) {
        $result = Get-DevcontainerFileClassification -FilePath $Path
        $result.Category | Should -Be $Category
        $result.Impact | Should -Be $Impact
    }
}

Describe 'New-DevcontainerChangeSummary' -Tag 'Unit' {
    Context 'when EventName is workflow_dispatch' {
        It 'Returns markdown with dispatch message' {
            $result = New-DevcontainerChangeSummary -CommitSha 'abc123' -BranchName 'main' -EventName 'workflow_dispatch'
            $result | Should -Match 'workflow_dispatch'
            $result | Should -Match 'No push range available'
        }
    }

    Context 'when BeforeSha is all zeros' {
        It 'Returns markdown with initial push message' {
            $result = New-DevcontainerChangeSummary -CommitSha 'abc123' -BranchName 'main' -EventName 'push' -BeforeSha '0000000000000000000000000000000000000000'
            $result | Should -Match 'Initial push'
        }
    }

    Context 'when git diff succeeds with changed files' {
        BeforeAll {
            Mock git {
                $global:LASTEXITCODE = 0
                return @(
                    '.devcontainer/devcontainer.json'
                    '.devcontainer/scripts/on-create.sh'
                )
            } -ParameterFilter { $args -contains 'diff' }
        }

        It 'Returns markdown with classified file table' {
            $result = New-DevcontainerChangeSummary -CommitSha 'abc123' -BranchName 'main' -EventName 'push' -BeforeSha 'def456' -RepoRoot '/fake'
            $result | Should -Match 'devcontainer\.json'
            $result | Should -Match 'on-create\.sh'
            $result | Should -Match 'Config'
            $result | Should -Match 'Lifecycle Scripts'
        }
    }

    Context 'when git diff fails (force push)' {
        BeforeAll {
            Mock git {
                $global:LASTEXITCODE = 128
                return 'fatal: bad object abc123'
            } -ParameterFilter { $args -contains 'diff' }
        }

        It 'Returns markdown with force push message' {
            $result = New-DevcontainerChangeSummary -CommitSha 'abc123' -BranchName 'main' -EventName 'push' -BeforeSha 'def456' -RepoRoot '/fake'
            $result | Should -Match 'not be reachable'
        }
    }

    Context 'when git diff returns empty' {
        BeforeAll {
            Mock git {
                $global:LASTEXITCODE = 0
                return ''
            } -ParameterFilter { $args -contains 'diff' }
        }

        It 'Returns markdown with no changes message' {
            $result = New-DevcontainerChangeSummary -CommitSha 'abc123' -BranchName 'main' -EventName 'push' -BeforeSha 'def456' -RepoRoot '/fake'
            $result | Should -Match 'No devcontainer infrastructure files changed'
        }
    }
}
