#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Get-AgentDependencyMap.ps1'
    $script:FixtureRoot = Join-Path $PSScriptRoot 'fixtures'

    function script:Initialize-FixtureRepo {
        param([Parameter(Mandatory)] [string]$Root)

        $agentsDir = Join-Path $Root '.github/agents'
        $instrDir  = Join-Path $Root '.github/instructions'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $instrDir  -Force | Out-Null

        Copy-Item -Recurse -LiteralPath (Join-Path $script:FixtureRoot 'agents/minimal-coll') -Destination $agentsDir
        Copy-Item -LiteralPath (Join-Path $script:FixtureRoot 'instructions/minimal.instructions.md') -Destination $instrDir
    }
}

Describe 'Get-AgentDependencyMap.ps1' -Tag 'Unit' {
    BeforeEach {
        $script:TestRoot = Join-Path $TestDrive ([Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:TestRoot -Force | Out-Null
        Initialize-FixtureRepo -Root $script:TestRoot
        $script:OutputPath = Join-Path $script:TestRoot 'logs/agent-dependency-map.json'
    }

    Context 'Discovery and JSON shape' {
        BeforeEach {
            & $script:ScriptPath `
                -RepoRoot $script:TestRoot `
                -OutputPath $script:OutputPath 3>$null 6>$null
            $script:Map = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        }

        It 'Writes the JSON document at the requested path' {
            Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
        }

        It 'Records one top-level key per discovered agent slug' {
            $keys = @($script:Map.PSObject.Properties.Name | Sort-Object)
            $keys | Should -Be @('minimal-agent-a', 'minimal-agent-b', 'minimal-subagent')
        }

        It 'Records the workspace-relative agent path for each slug' {
            $script:Map.'minimal-agent-a'.agent | Should -Be '.github/agents/minimal-coll/minimal-agent-a.agent.md'
            $script:Map.'minimal-agent-b'.agent | Should -Be '.github/agents/minimal-coll/minimal-agent-b.agent.md'
            $script:Map.'minimal-subagent'.agent | Should -Be '.github/agents/minimal-coll/subagents/minimal-subagent.agent.md'
        }

        It 'Includes the standard record fields for each slug' {
            foreach ($slug in @('minimal-agent-a', 'minimal-agent-b', 'minimal-subagent')) {
                $record = $script:Map.$slug
                $record.PSObject.Properties.Name | Sort-Object | Should -Be @('agent', 'instructions', 'skills', 'subagents', 'warnings')
            }
        }
    }

    Context 'Reference resolution' {
        BeforeEach {
            & $script:ScriptPath `
                -RepoRoot $script:TestRoot `
                -OutputPath $script:OutputPath 3>$null 6>$null
            $script:Record = (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).'minimal-agent-a'
        }

        It 'Resolves frontmatter instructions and markdown link references' {
            $script:Record.instructions | Should -Contain '.github/instructions/minimal.instructions.md'
        }

        It 'Resolves agents named in the body to subagent entries' {
            $script:Record.subagents | Should -Contain '.github/agents/minimal-coll/subagents/minimal-subagent.agent.md'
        }

        It 'Resolves glob subagent references via recursive enumeration' {
            # The minimal-agent-a body declares a glob `subagents/*.agent.md` that should
            # resolve to the single fixture subagent file.
            @($script:Record.subagents | Where-Object { $_ -like '*subagents/minimal-subagent.agent.md' }).Count |
                Should -BeGreaterThan 0
        }
    }

    Context 'Commented frontmatter lists' {
        It 'Resolves skills and instructions declared in lists with comments' {
            $agentPath = Join-Path $script:TestRoot '.github/agents/minimal-coll/commented-agent.agent.md'
            Set-Content -LiteralPath $agentPath -Value "---`ndescription: Commented fixture agent.`nskills: [fixture-skill] # preloads`ninstructions:`n  # declared`n  - .github/instructions/minimal.instructions.md`n---`n`nBody." -Encoding UTF8
            $skillDir = Join-Path $script:TestRoot '.github/skills/pkg/fixture-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value 'Fixture skill.' -Encoding UTF8

            & $script:ScriptPath -RepoRoot $script:TestRoot -OutputPath $script:OutputPath 3>$null 6>$null

            $record = (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).'commented-agent'
            $record.skills | Should -Contain '.github/skills/pkg/fixture-skill/SKILL.md'
            $record.instructions | Should -Contain '.github/instructions/minimal.instructions.md'
            $record.warnings | Should -HaveCount 0
        }

        It 'Records a warning when frontmatter cannot be parsed' {
            $agentPath = Join-Path $script:TestRoot '.github/agents/minimal-coll/malformed-agent.agent.md'
            Set-Content -LiteralPath $agentPath -Value "---`nskills: [one`nname: : :`n---`n`nBody." -Encoding UTF8

            & $script:ScriptPath -RepoRoot $script:TestRoot -OutputPath $script:OutputPath 3>$null 6>$null

            $record = (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).'malformed-agent'
            ($record.warnings -join "`n") | Should -Match 'frontmatter not parsed'
        }
    }

    Context 'Preloaded skill references' {
        It 'Adds the subagents and instructions a preloaded skill names, skipping user-invocable agents' {
            $collDir = Join-Path $script:TestRoot '.github/agents/minimal-coll'
            Set-Content -LiteralPath (Join-Path $collDir 'subagents/checker.agent.md') -Value "---`nname: Checker`nuser-invocable: false`n---`n`nChecks work." -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $collDir 'coach.agent.md') -Value "---`nname: Coach`n---`n`nCoaches teams." -Encoding UTF8
            $skillDir = Join-Path $script:TestRoot '.github/skills/pkg/protocol-skill'
            New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $skillDir 'SKILL.md') -Value "---`nname: protocol-skill`n---`n`nDispatch the Checker subagent and follow [rules](../../../instructions/minimal.instructions.md). The Coach adopts this protocol too." -Encoding UTF8
            Set-Content -LiteralPath (Join-Path $collDir 'preloader.agent.md') -Value "---`ndescription: Preloads the protocol.`nskills:`n  - protocol-skill`n---`n`nFollow the preloaded protocol." -Encoding UTF8

            & $script:ScriptPath -RepoRoot $script:TestRoot -OutputPath $script:OutputPath 3>$null 6>$null

            $record = (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).'preloader'
            $record.subagents | Should -Contain '.github/agents/minimal-coll/subagents/checker.agent.md'
            $record.subagents | Should -Not -Contain '.github/agents/minimal-coll/coach.agent.md'
            $record.instructions | Should -Contain '.github/instructions/minimal.instructions.md'
            $record.skills | Should -Contain '.github/skills/pkg/protocol-skill/SKILL.md'
            $record.warnings | Should -HaveCount 0
        }
    }

    Context 'Warnings on missing references' {
        It 'Records a warning for an unresolved reference but still exits successfully' {
            $warnings = $null
            & $script:ScriptPath `
                -RepoRoot $script:TestRoot `
                -OutputPath $script:OutputPath `
                -WarningVariable warnings 6>$null

            Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
            $map = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $recordWarnings = $map.'minimal-agent-a'.warnings
            ($recordWarnings -join "`n") | Should -Match 'does-not-exist'
            ($warnings -join "`n") | Should -Match 'does-not-exist'
        }
    }

    Context 'Determinism' {
        It 'Produces byte-identical output on consecutive runs' {
            $first = Join-Path $TestDrive 'dep-map-first.json'
            $second = Join-Path $TestDrive 'dep-map-second.json'

            & $script:ScriptPath -RepoRoot $script:TestRoot -OutputPath $first 3>$null 6>$null
            & $script:ScriptPath -RepoRoot $script:TestRoot -OutputPath $second 3>$null 6>$null

            $bytesA = [System.IO.File]::ReadAllBytes($first)
            $bytesB = [System.IO.File]::ReadAllBytes($second)
            $bytesA.Length | Should -Be $bytesB.Length
            [System.Linq.Enumerable]::SequenceEqual([byte[]]$bytesA, [byte[]]$bytesB) | Should -BeTrue
        }
    }
}
