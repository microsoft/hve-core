#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../collections/Validate-Collections.ps1')
    Import-Module PowerShell-Yaml -ErrorAction Stop

    function script:Set-AgentFile {
        param(
            [Parameter(Mandatory)] [string]$Root,
            [Parameter(Mandatory)] [string]$RelativePath,
            [Parameter(Mandatory)] [string]$Name,
            [string[]]$AgentRefs = @(),
            [string[]]$HandoffRefs = @()
        )
        $fullPath = Join-Path $Root $RelativePath
        $dir = Split-Path -Parent $fullPath
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        $frontmatter = [System.Text.StringBuilder]::new()
        [void]$frontmatter.AppendLine('---')
        [void]$frontmatter.AppendLine("name: $Name")
        [void]$frontmatter.AppendLine('description: fixture agent')
        if ($AgentRefs.Count -gt 0) {
            [void]$frontmatter.AppendLine('agents:')
            foreach ($ref in $AgentRefs) {
                [void]$frontmatter.AppendLine("  - $ref")
            }
        }
        if ($HandoffRefs.Count -gt 0) {
            [void]$frontmatter.AppendLine('handoffs:')
            foreach ($ref in $HandoffRefs) {
                [void]$frontmatter.AppendLine("  - agent: $ref")
                [void]$frontmatter.AppendLine("    when: example")
            }
        }
        [void]$frontmatter.AppendLine('---')
        [void]$frontmatter.AppendLine('')
        [void]$frontmatter.AppendLine("# $Name")

        Set-Content -Path $fullPath -Value $frontmatter.ToString() -NoNewline
    }
}

Describe 'Test-AgentHandoffNameReferences' {
    BeforeEach {
        $script:repoRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot '.github/agents/test') -Force | Out-Null
    }

    Context 'when a reference matches a suffixed target exactly' {
        It 'Returns no diagnostics' {
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/target.agent.md' -Name 'Target Agent (exp)'
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/source.agent.md' -Name 'Source Agent' -AgentRefs @('Target Agent (exp)')

            $diagnostics = Test-AgentHandoffNameReferences -RepoRoot $script:repoRoot

            $diagnostics.Count | Should -Be 0
        }

        It 'Returns no diagnostics for handoff to suffixed target' {
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/target.agent.md' -Name 'Target Agent (pre)'
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/source.agent.md' -Name 'Source Agent' -HandoffRefs @('Target Agent (pre)')

            $diagnostics = Test-AgentHandoffNameReferences -RepoRoot $script:repoRoot

            $diagnostics.Count | Should -Be 0
        }
    }

    Context 'when a reference uses the base name but the target carries (exp)' {
        It 'Emits AgentHandoffNameMismatch with a Did you mean suggestion equal to the suffixed name' {
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/target.agent.md' -Name 'Target Agent (exp)'
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/source.agent.md' -Name 'Source Agent' -AgentRefs @('Target Agent')

            $diagnostics = Test-AgentHandoffNameReferences -RepoRoot $script:repoRoot

            $diagnostics.Count | Should -Be 1
            $diagnostics[0].ErrorType | Should -Be 'AgentHandoffNameMismatch'
            $diagnostics[0].Severity | Should -Be 'Error'
            $diagnostics[0].Message | Should -Match "Reference 'Target Agent' in "
            $diagnostics[0].Message | Should -Match "Did you mean 'Target Agent \(exp\)'\?"
        }

        It 'Emits AgentHandoffNameMismatch with suggestion for handoff to suffixed target referenced by base name' {
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/target.agent.md' -Name 'Target Agent (pre)'
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/source.agent.md' -Name 'Source Agent' -HandoffRefs @('Target Agent')

            $diagnostics = Test-AgentHandoffNameReferences -RepoRoot $script:repoRoot

            $diagnostics.Count | Should -Be 1
            $diagnostics[0].ErrorType | Should -Be 'AgentHandoffNameMismatch'
            $diagnostics[0].Message | Should -Match "Did you mean 'Target Agent \(pre\)'\?"
        }
    }

    Context 'when a reference points at an unknown agent' {
        It 'Emits AgentHandoffNameMismatch with no Did you mean suggestion' {
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/target.agent.md' -Name 'Real Agent'
            Set-AgentFile -Root $script:repoRoot -RelativePath '.github/agents/test/source.agent.md' -Name 'Source Agent' -AgentRefs @('Phantom Agent')

            $diagnostics = Test-AgentHandoffNameReferences -RepoRoot $script:repoRoot

            $diagnostics.Count | Should -Be 1
            $diagnostics[0].ErrorType | Should -Be 'AgentHandoffNameMismatch'
            $diagnostics[0].Severity | Should -Be 'Error'
            $diagnostics[0].Message | Should -Match "Reference 'Phantom Agent' in "
            $diagnostics[0].Message | Should -Not -Match 'Did you mean'
        }
    }
}
