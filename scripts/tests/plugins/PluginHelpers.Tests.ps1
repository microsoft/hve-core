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
    It 'Strips .agent.md to .md for agents' {
        $result = Get-PluginItemName -FileName 'task-researcher.agent.md' -Kind 'agent'
        $result | Should -Be 'task-researcher.md'
    }

    It 'Strips .prompt.md to .md for prompts' {
        $result = Get-PluginItemName -FileName 'gen-plan.prompt.md' -Kind 'prompt'
        $result | Should -Be 'gen-plan.md'
    }

    It 'Preserves .instructions.md suffix' {
        $result = Get-PluginItemName -FileName 'csharp.instructions.md' -Kind 'instruction'
        $result | Should -Be 'csharp.instructions.md'
    }

    It 'Returns skill directory name unchanged' {
        $result = Get-PluginItemName -FileName 'video-to-gif' -Kind 'skill'
        $result | Should -Be 'video-to-gif'
    }
}

Describe 'Get-PluginItemSubpath' {
    It 'Extracts single-level collection subdirectory for agents' {
        $result = Get-PluginItemSubpath -Path '.github/agents/hve-core/rpi-agent.agent.md' -Kind 'agent'
        $result | Should -Be 'hve-core'
    }

    It 'Extracts nested subdirectory path for agent subagents' {
        $result = Get-PluginItemSubpath -Path '.github/agents/hve-core/subagents/researcher-subagent.agent.md' -Kind 'agent'
        $result | Should -Be 'hve-core/subagents'
    }

    It 'Returns empty string when item is at kind root' {
        $result = Get-PluginItemSubpath -Path '.github/agents/root-agent.agent.md' -Kind 'agent'
        $result | Should -Be ''
    }

    It 'Extracts subdirectory for instructions' {
        $result = Get-PluginItemSubpath -Path '.github/instructions/shared/hve-core-location.instructions.md' -Kind 'instruction'
        $result | Should -Be 'shared'
    }

    It 'Extracts subdirectory for skills' {
        $result = Get-PluginItemSubpath -Path '.github/skills/shared/pr-reference' -Kind 'skill'
        $result | Should -Be 'shared'
    }

    It 'Handles backslash-separated paths' {
        $result = Get-PluginItemSubpath -Path '.github\agents\hve-core\rpi-agent.agent.md' -Kind 'agent'
        $result | Should -Be 'hve-core'
    }

    It 'Extracts subdirectory for prompts' {
        $result = Get-PluginItemSubpath -Path '.github/prompts/hve-core/git-commit-message.prompt.md' -Kind 'prompt'
        $result | Should -Be 'hve-core'
    }

    It 'Returns empty string when path does not match kind prefix' {
        $result = Get-PluginItemSubpath -Path 'some/other/path/file.md' -Kind 'agent'
        $result | Should -Be ''
    }
}

Describe 'New-PluginManifestContent' {
    It 'Returns hashtable with name, description, and version' {
        $result = New-PluginManifestContent -CollectionId 'test-plugin' -Description 'A test plugin' -Version '2.0.0'
        $result.name | Should -Be 'test-plugin'
        $result.description | Should -Be 'A test plugin'
        $result.version | Should -Be '2.0.0'
    }

    It 'Includes explicit path arrays when provided' {
        $result = New-PluginManifestContent `
            -CollectionId 'with-paths' -Description 'desc' -Version '1.0.0' `
            -AgentPaths @('agents/core/') `
            -CommandPaths @('commands/core/', 'commands/ado/') `
            -SkillPaths @('skills/shared/')
        $result.agents | Should -Be @('agents/core/')
        $result.commands | Should -Be @('commands/ado/', 'commands/core/')
        $result.skills | Should -Be @('skills/shared/')
    }

    It 'Omits component keys when no paths provided' {
        $result = New-PluginManifestContent -CollectionId 'minimal' -Description 'desc' -Version '1.0.0'
        $result.Contains('agents') | Should -BeFalse
        $result.Contains('commands') | Should -BeFalse
        $result.Contains('skills') | Should -BeFalse
    }

    It 'Returns ordered hashtable' {
        $result = New-PluginManifestContent -CollectionId 'ordered-test' -Description 'desc' -Version '1.0.0'
        $result | Should -BeOfType [System.Collections.Specialized.OrderedDictionary]
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

    It 'Includes collection subdirectory in GeneratedFiles path' {
        $collection = @{
            id          = 'subpath-test'
            name        = 'Subpath Test'
            description = 'Testing subpath in destination'
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
        # GeneratedFiles should contain a path with the 'test' subdirectory preserved
        $agentPaths = @($result.GeneratedFiles | Where-Object { $_ -match 'agents' -and $_ -match 'example' })
        $agentPaths | Should -Not -BeNullOrEmpty
        $agentPaths[0] | Should -Match 'agents[/\\]test[/\\]example\.md$'
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

Describe 'Repair-PluginSymlinkIndex' {
    Context 'When PluginsDir does not exist' {
        It 'Returns 0' {
            $result = Repair-PluginSymlinkIndex `
                -PluginsDir (Join-Path $TestDrive 'nonexistent') `
                -RepoRoot $TestDrive
            $result | Should -Be 0
        }
    }

    Context 'In a git repository with text stubs' {
        BeforeAll {
            $script:repoRoot = Join-Path $TestDrive 'symlink-repo'
            New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null

            Push-Location $script:repoRoot
            try {
                git init --quiet 2>$null
                git config user.email 'test@test.com'
                git config user.name 'Test'

                $script:pluginsDir = Join-Path $script:repoRoot 'plugins'
                New-Item -ItemType Directory -Path $script:pluginsDir -Force | Out-Null

                # Valid text stub: small, starts with ../, no newlines
                [System.IO.File]::WriteAllText(
                    (Join-Path $script:pluginsDir 'valid-stub.md'),
                    '../some/source.md'
                )

                # Large file (>500 bytes) — skipped by size filter
                [System.IO.File]::WriteAllText(
                    (Join-Path $script:pluginsDir 'large-file.md'),
                    ('x' * 501)
                )

                # Non-stub content — skipped by pattern filter
                [System.IO.File]::WriteAllText(
                    (Join-Path $script:pluginsDir 'non-stub.md'),
                    '# Regular markdown'
                )

                # Stub with newline — skipped by newline filter
                [System.IO.File]::WriteAllText(
                    (Join-Path $script:pluginsDir 'newline-stub.md'),
                    "../path/file.md`n"
                )

                git add -- plugins/ 2>$null
                git commit -m 'initial' --quiet 2>$null
            } finally {
                Pop-Location
            }
        }

        It 'Counts only valid stubs in DryRun mode' {
            Push-Location $script:repoRoot
            try {
                $result = Repair-PluginSymlinkIndex `
                    -PluginsDir $script:pluginsDir `
                    -RepoRoot $script:repoRoot -DryRun
                $result | Should -Be 1
            } finally {
                Pop-Location
            }
        }

        It 'Does not modify index in DryRun mode' {
            Push-Location $script:repoRoot
            try {
                $before = git ls-files --stage -- plugins/valid-stub.md 2>$null
                Repair-PluginSymlinkIndex `
                    -PluginsDir $script:pluginsDir `
                    -RepoRoot $script:repoRoot -DryRun | Out-Null
                $after = git ls-files --stage -- plugins/valid-stub.md 2>$null
                $before | Should -Be $after
            } finally {
                Pop-Location
            }
        }

        It 'Re-indexes tracked text stub as mode 120000' {
            Push-Location $script:repoRoot
            try {
                $result = Repair-PluginSymlinkIndex `
                    -PluginsDir $script:pluginsDir `
                    -RepoRoot $script:repoRoot
                $result | Should -Be 1

                $lsOutput = git ls-files --stage -- plugins/valid-stub.md 2>$null
                $lsOutput | Should -Match '^120000'
            } finally {
                Pop-Location
            }
        }

        It 'Skips entries already at mode 120000' {
            Push-Location $script:repoRoot
            try {
                # Previous test fixed the stub; second run finds nothing new
                $result = Repair-PluginSymlinkIndex `
                    -PluginsDir $script:pluginsDir `
                    -RepoRoot $script:repoRoot
                $result | Should -Be 0
            } finally {
                Pop-Location
            }
        }
    }
}
