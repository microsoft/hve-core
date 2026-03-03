#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module $PSScriptRoot/../../plugins/Modules/PluginHelpers.psm1 -Force
}

Describe 'New-PluginReadmeContent - maturity notice' {
    It 'Includes experimental notice when maturity is experimental' {
        $collection = @{
            id          = 'test-exp'
            name        = 'Test Experimental'
            description = 'An experimental collection'
        }
        $items = @(@{ Name = 'test-agent'; Description = 'desc'; Kind = 'agent' })
        $result = New-PluginReadmeContent -Collection $collection -Items $items -Maturity 'experimental'
        $result | Should -Match '\u26A0' # warning sign emoji
    }

    It 'Has no notice when maturity is stable' {
        $collection = @{
            id          = 'test-stable'
            name        = 'Test Stable'
            description = 'A stable collection'
        }
        $items = @(@{ Name = 'test-agent'; Description = 'desc'; Kind = 'agent' })
        $result = New-PluginReadmeContent -Collection $collection -Items $items -Maturity 'stable'
        $result | Should -Not -Match '\u26A0'
    }

    It 'Has no notice when maturity is omitted' {
        $collection = @{
            id          = 'test-default'
            name        = 'Test Default'
            description = 'A default collection'
        }
        $items = @(@{ Name = 'test-agent'; Description = 'desc'; Kind = 'agent' })
        $result = New-PluginReadmeContent -Collection $collection -Items $items
        $result | Should -Not -Match '\u26A0'
    }

    It 'Has no notice when maturity is null' {
        $collection = @{
            id          = 'test-null'
            name        = 'Test Null'
            description = 'A null maturity collection'
        }
        $items = @(@{ Name = 'test-agent'; Description = 'desc'; Kind = 'agent' })
        $result = New-PluginReadmeContent -Collection $collection -Items $items -Maturity $null
        $result | Should -Not -Match '\u26A0'
    }
}

Describe 'Get-PluginItemName' {
    It 'Strips .agent.md suffix' {
        $result = Get-PluginItemName -FileName 'task-researcher.agent.md' -Kind 'agent'
        $result | Should -Be 'task-researcher.md'
    }

    It 'Strips .prompt.md suffix' {
        $result = Get-PluginItemName -FileName 'gen-plan.prompt.md' -Kind 'prompt'
        $result | Should -Be 'gen-plan.md'
    }

    It 'Strips .instructions.md suffix' {
        $result = Get-PluginItemName -FileName 'csharp.instructions.md' -Kind 'instruction'
        $result | Should -Be 'csharp.md'
    }

    It 'Returns skill directory name unchanged' {
        $result = Get-PluginItemName -FileName 'video-to-gif' -Kind 'skill'
        $result | Should -Be 'video-to-gif'
    }
}

Describe 'Get-PluginSubdirectory' {
    It 'Maps agent to agents' {
        $result = Get-PluginSubdirectory -Kind 'agent'
        $result | Should -Be 'agents'
    }

    It 'Maps prompt to commands' {
        $result = Get-PluginSubdirectory -Kind 'prompt'
        $result | Should -Be 'commands'
    }

    It 'Maps instruction to instructions' {
        $result = Get-PluginSubdirectory -Kind 'instruction'
        $result | Should -Be 'instructions'
    }

    It 'Maps skill to skills' {
        $result = Get-PluginSubdirectory -Kind 'skill'
        $result | Should -Be 'skills'
    }
}

Describe 'Write-PluginDirectory - DryRun mode' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'wpd-repo'
        $script:pluginsDir = Join-Path $TestDrive 'wpd-plugins'
        New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:pluginsDir -Force | Out-Null

        # Create a valid agent file with frontmatter
        $agentDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentDir 'example.agent.md') -Value "---`ndescription: An example agent`n---`nAgent body"

        # Create a valid skill directory with SKILL.md
        $skillDir = Join-Path $script:repoRoot '.github/skills/test/my-skill'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value "---`ndescription: A skill`n---`nSkill body"

        # Create shared dirs
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'docs/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:repoRoot 'scripts/lib') -Force | Out-Null
    }

    It 'Completes DryRun without creating files for agents' {
        $collection = @{
            id          = 'dryrun-test'
            name        = 'DryRun Test'
            description = 'Testing DryRun mode'
            items       = @(
                @{
                    path = '.github/agents/test/example.agent.md'
                    kind = 'agent'
                }
            )
        }

        $result = Write-PluginDirectory -Collection $collection -PluginsDir $script:pluginsDir `
            -RepoRoot $script:repoRoot -Version '1.0.0' -DryRun

        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 1

        # Verify no actual files were created
        $pluginDir = Join-Path $script:pluginsDir 'dryrun-test'
        Test-Path -Path $pluginDir | Should -BeFalse
    }

    It 'Completes DryRun with skill items' {
        $collection = @{
            id          = 'dryrun-skill'
            name        = 'DryRun Skill'
            description = 'Testing DryRun with skills'
            items       = @(
                @{
                    path = '.github/skills/test/my-skill'
                    kind = 'skill'
                }
            )
        }

        $result = Write-PluginDirectory -Collection $collection -PluginsDir $script:pluginsDir `
            -RepoRoot $script:repoRoot -Version '1.0.0' -DryRun

        $result.Success | Should -BeTrue
        $result.SkillCount | Should -Be 1
    }

    It 'Handles source file not found for non-skill items' {
        $collection = @{
            id          = 'missing-source'
            name        = 'Missing Source'
            description = 'Non-existent source file'
            items       = @(
                @{
                    path = '.github/agents/test/nonexistent.agent.md'
                    kind = 'agent'
                }
            )
        }

        $result = Write-PluginDirectory -Collection $collection -PluginsDir $script:pluginsDir `
            -RepoRoot $script:repoRoot -Version '1.0.0' -DryRun

        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 1
    }

    It 'Warns when shared directory is missing' {
        $emptyRepo = Join-Path $TestDrive 'empty-repo'
        New-Item -ItemType Directory -Path $emptyRepo -Force | Out-Null

        # Create agent file but no shared directories
        $agentDir = Join-Path $emptyRepo '.github/agents/test'
        New-Item -ItemType Directory -Path $agentDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentDir 'a.agent.md') -Value "---`ndescription: test`n---"

        $collection = @{
            id          = 'no-shared'
            name        = 'No Shared'
            description = 'Missing shared dirs'
            items       = @(
                @{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                }
            )
        }

        $result = Write-PluginDirectory -Collection $collection -PluginsDir $script:pluginsDir `
            -RepoRoot $emptyRepo -Version '1.0.0' -DryRun

        $result.Success | Should -BeTrue
    }
}

Describe 'Test-SymlinkCapability' {
    It 'Returns a boolean' {
        $result = Test-SymlinkCapability
        $result | Should -BeOfType [bool]
    }

    It 'Cleans up probe directory' {
        $probeDirPattern = Join-Path ([System.IO.Path]::GetTempPath()) "hve-symlink-probe-$PID"
        Test-SymlinkCapability | Out-Null
        Test-Path $probeDirPattern | Should -BeFalse
    }
}

Describe 'New-PluginLink' {
    BeforeAll {
        $script:linkRoot = Join-Path $TestDrive 'link-test'
        New-Item -ItemType Directory -Path $script:linkRoot -Force | Out-Null
    }

    It 'Writes text stub when SymlinkCapable is false' {
        $src = Join-Path $script:linkRoot 'src-stub.txt'
        Set-Content -Path $src -Value 'content' -NoNewline
        $dest = Join-Path $script:linkRoot 'dest-stub.txt'

        New-PluginLink -SourcePath $src -DestinationPath $dest

        Test-Path $dest | Should -BeTrue
        $stubContent = [System.IO.File]::ReadAllText($dest)
        $expectedPath = [System.IO.Path]::GetRelativePath((Split-Path -Parent $dest), $src) -replace '\\', '/'
        $stubContent | Should -Be $expectedPath
    }

    It 'Creates parent directory when destination parent does not exist' {
        $src = Join-Path $script:linkRoot 'src-parent.txt'
        Set-Content -Path $src -Value 'data' -NoNewline
        $dest = Join-Path $script:linkRoot 'nested/deep/dest-parent.txt'

        New-PluginLink -SourcePath $src -DestinationPath $dest

        Test-Path $dest | Should -BeTrue
    }
}
