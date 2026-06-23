#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/Modules/AffectedAgents.psm1'
    Import-Module $script:ModulePath -Force

    function script:New-AgentFile {
        param(
            [Parameter(Mandatory)] [string]$RelativePath,
            [bool]$UserInvocable
        )
        $absPath = Join-Path $script:TestRoot $RelativePath
        $dir = Split-Path -Parent $absPath
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
        $body = if ($PSBoundParameters.ContainsKey('UserInvocable')) {
            $val = if ($UserInvocable) { 'true' } else { 'false' }
            "---`nuser-invocable: $val`n---`n# Agent`n"
        } else {
            "---`ndescription: test`n---`n# Agent`n"
        }
        Set-Content -LiteralPath $absPath -Value $body -Encoding utf8
    }

    function script:New-DepMap {
        param([Parameter(Mandatory)] [hashtable]$Map)
        $obj = [pscustomobject]$Map
        $obj | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $script:DepMapPath -Encoding utf8
    }
}

Describe 'AffectedAgents module' -Tag 'Unit' {
    BeforeEach {
        $script:TestRoot = Join-Path $TestDrive ('repo-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        $script:DepMapPath = Join-Path $script:TestRoot 'logs/agent-dependency-map.json'
        New-Item -ItemType Directory -Path (Split-Path -Parent $script:DepMapPath) -Force | Out-Null
        Clear-AffectedAgentsCache
    }

    Context 'Direct agent classification' {
        It 'Returns the slug for a changed parent agent (frontmatter user-invocable: true)' {
            New-AgentFile -RelativePath '.github/agents/hve-core/task-planner.agent.md' -UserInvocable $true
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/agents/hve-core/task-planner.agent.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-planner')
        }

        It 'Treats agent files with no frontmatter user-invocable key as parents' {
            New-AgentFile -RelativePath '.github/agents/hve-core/some-agent.agent.md'
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/agents/hve-core/some-agent.agent.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('some-agent')
        }

        It 'Treats agent files for deleted paths as parents (file missing on disk)' {
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/agents/hve-core/removed-agent.agent.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('removed-agent')
        }

        It 'Maps a subagent change (user-invocable: false) to every parent that lists it' {
            New-AgentFile -RelativePath '.github/agents/hve-core/subagents/researcher-subagent.agent.md' -UserInvocable $false
            New-DepMap -Map @{
                'task-planner' = @{ subagents = @('.github/agents/hve-core/subagents/researcher-subagent.agent.md') }
                'task-implementor' = @{ subagents = @('.github/agents/hve-core/subagents/researcher-subagent.agent.md') }
                'task-reviewer' = @{ subagents = @() }
            }
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/agents/hve-core/subagents/researcher-subagent.agent.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-implementor', 'task-planner')
        }

        It 'Does not include security subagents as direct parents (DD-09: frontmatter wins)' {
            New-AgentFile -RelativePath '.github/agents/security/subagents/security-reviewer-subagent.agent.md' -UserInvocable $false
            New-DepMap -Map @{
                'security-reviewer' = @{ subagents = @('.github/agents/security/subagents/security-reviewer-subagent.agent.md') }
            }
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/agents/security/subagents/security-reviewer-subagent.agent.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('security-reviewer')
            $result | Should -Not -Contain 'security-reviewer-subagent'
        }
    }

    Context 'Stimulus YAML changes' {
        It 'Returns the slug encoded in the stimulus filename' {
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('evals/agent-behavior/stimuli/task-planner.yml') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-planner')
        }

        It 'Accepts .yaml extension as well as .yml' {
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('evals/agent-behavior/stimuli/task-reviewer.yaml') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-reviewer')
        }
    }

    Context 'Indirect artifact expansion via dep-map reverse lookup' {
        It 'Expands an instruction change to every parent that references it' {
            New-DepMap -Map @{
                'task-planner' = @{ instructions = @('.github/instructions/coding-standards/powershell/powershell.instructions.md') }
                'task-implementor' = @{ instructions = @('.github/instructions/coding-standards/powershell/powershell.instructions.md') }
                'task-reviewer' = @{ instructions = @('.github/instructions/hve-core/markdown.instructions.md') }
            }
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/instructions/coding-standards/powershell/powershell.instructions.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-implementor', 'task-planner')
        }

        It 'Expands a skill SKILL.md change to every parent that references it' {
            New-DepMap -Map @{
                'task-planner' = @{ skills = @('.github/skills/shared/pr-reference/SKILL.md') }
                'task-reviewer' = @{ skills = @('.github/skills/shared/pr-reference/SKILL.md') }
            }
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/skills/shared/pr-reference/SKILL.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-planner', 'task-reviewer')
        }

        It 'Returns an empty array for an indirect artifact with no references' {
            New-DepMap -Map @{
                'task-planner' = @{ instructions = @('.github/instructions/other.instructions.md') }
            }
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github/instructions/coding-standards/powershell/powershell.instructions.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            ,$result | Should -BeOfType ([string[]])
            $result.Count | Should -Be 0
        }
    }

    Context 'Mixed and edge inputs' {
        It 'De-duplicates and sorts slugs across direct and indirect inputs' {
            New-AgentFile -RelativePath '.github/agents/hve-core/task-planner.agent.md' -UserInvocable $true
            New-DepMap -Map @{
                'task-planner' = @{ instructions = @('.github/instructions/x.instructions.md') }
                'task-implementor' = @{ instructions = @('.github/instructions/x.instructions.md') }
            }
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @(
                    '.github/agents/hve-core/task-planner.agent.md',
                    '.github/instructions/x.instructions.md'
                ) `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-implementor', 'task-planner')
        }

        It 'Ignores paths that are not artifacts' {
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('docs/README.md', 'scripts/evals/Test-EvalSpec.ps1') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            ,$result | Should -BeOfType ([string[]])
            $result.Count | Should -Be 0
        }

        It 'Returns an empty array for an empty input' {
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @() `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            ,$result | Should -BeOfType ([string[]])
            $result.Count | Should -Be 0
        }

        It 'Normalizes backslash separators before classification' {
            New-AgentFile -RelativePath '.github/agents/hve-core/task-planner.agent.md' -UserInvocable $true
            $result = Get-AffectedAgentSlugs `
                -ChangedFiles @('.github\agents\hve-core\task-planner.agent.md') `
                -RepoRoot $script:TestRoot `
                -DepMapPath $script:DepMapPath `
                -SkipDepMapRefresh
            $result | Should -Be @('task-planner')
        }
    }
}
