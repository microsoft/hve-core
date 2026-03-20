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

Describe 'New-PluginSourceMap' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'srcmap-repo'
        $script:pluginRoot = Join-Path $TestDrive 'srcmap-plugins' 'test-col'
        New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:pluginRoot -Force | Out-Null
    }

    It 'Maps agent items to agents subdirectory' {
        $collection = @{
            id    = 'col'
            items = @(
                @{ path = '.github/agents/hve/task-planner.agent.md'; kind = 'agent' }
            )
        }

        $result = New-PluginSourceMap -Collection $collection `
            -PluginRoot $script:pluginRoot -RepoRoot $script:repoRoot

        $expectedSource = [System.IO.Path]::GetFullPath(
            (Join-Path $script:repoRoot '.github/agents/hve/task-planner.agent.md'))
        $result.ContainsKey($expectedSource) | Should -BeTrue
        $result[$expectedSource] | Should -BeLike '*agents*task-planner.md'
    }

    It 'Maps prompt items to commands subdirectory' {
        $collection = @{
            id    = 'col'
            items = @(
                @{ path = '.github/prompts/hve/gen-plan.prompt.md'; kind = 'prompt' }
            )
        }

        $result = New-PluginSourceMap -Collection $collection `
            -PluginRoot $script:pluginRoot -RepoRoot $script:repoRoot

        $expectedSource = [System.IO.Path]::GetFullPath(
            (Join-Path $script:repoRoot '.github/prompts/hve/gen-plan.prompt.md'))
        $result[$expectedSource] | Should -BeLike '*commands*gen-plan.md'
    }

    It 'Maps instruction items to instructions subdirectory' {
        $collection = @{
            id    = 'col'
            items = @(
                @{ path = '.github/instructions/hve/csharp.instructions.md'; kind = 'instruction' }
            )
        }

        $result = New-PluginSourceMap -Collection $collection `
            -PluginRoot $script:pluginRoot -RepoRoot $script:repoRoot

        $expectedSource = [System.IO.Path]::GetFullPath(
            (Join-Path $script:repoRoot '.github/instructions/hve/csharp.instructions.md'))
        $result[$expectedSource] | Should -BeLike '*instructions*csharp.md'
    }

    It 'Skips skill items' {
        $collection = @{
            id    = 'col'
            items = @(
                @{ path = '.github/skills/hve/video-to-gif'; kind = 'skill' }
                @{ path = '.github/agents/hve/planner.agent.md'; kind = 'agent' }
            )
        }

        $result = New-PluginSourceMap -Collection $collection `
            -PluginRoot $script:pluginRoot -RepoRoot $script:repoRoot

        $result.Count | Should -Be 1
    }

    It 'Returns empty hashtable for empty items' {
        $collection = @{ id = 'col'; items = @() }

        $result = New-PluginSourceMap -Collection $collection `
            -PluginRoot $script:pluginRoot -RepoRoot $script:repoRoot

        $result.Count | Should -Be 0
    }

    It 'Maps multiple items of different kinds' {
        $collection = @{
            id    = 'col'
            items = @(
                @{ path = '.github/agents/hve/a.agent.md'; kind = 'agent' }
                @{ path = '.github/prompts/hve/b.prompt.md'; kind = 'prompt' }
                @{ path = '.github/instructions/hve/c.instructions.md'; kind = 'instruction' }
                @{ path = '.github/skills/hve/my-skill'; kind = 'skill' }
            )
        }

        $result = New-PluginSourceMap -Collection $collection `
            -PluginRoot $script:pluginRoot -RepoRoot $script:repoRoot

        $result.Count | Should -Be 3
    }
}

Describe 'Resolve-PluginFileReferences' {
    BeforeAll {
        # Set up directory structure for source map resolution
        $script:repoRoot = Join-Path $TestDrive 'resolve-repo'
        $script:pluginRoot = Join-Path $TestDrive 'resolve-plugins' 'col'
        New-Item -ItemType Directory -Path $script:repoRoot -Force | Out-Null
        New-Item -ItemType Directory -Path $script:pluginRoot -Force | Out-Null

        # Source paths
        $script:agentSource = Join-Path $script:repoRoot '.github/agents/hve/my-agent.agent.md'
        $script:instrSource = Join-Path $script:repoRoot '.github/instructions/hve/commit-msg.instructions.md'

        # Plugin destination paths
        $script:agentDest = Join-Path $script:pluginRoot 'agents/my-agent.md'
        $script:instrDest = Join-Path $script:pluginRoot 'instructions/commit-msg.md'

        # Build source map
        $script:sourceMap = @{}
        $script:sourceMap[[System.IO.Path]::GetFullPath($script:agentSource)] = $script:agentDest
        $script:sourceMap[[System.IO.Path]::GetFullPath($script:instrSource)] = $script:instrDest
    }

    It 'Rewrites a resolvable #file: reference' {
        $content = 'Follow the rules in #file:../../instructions/hve/commit-msg.instructions.md for commits.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '#file:\.\./instructions/commit-msg\.md'
        $result.Warnings.Count | Should -Be 0
    }

    It 'Leaves unresolvable references unchanged and emits warning' {
        $content = 'See #file:../unknown/missing.md for details.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '#file:\.\./unknown/missing\.md'
        $result.Warnings.Count | Should -Be 1
        $result.Warnings[0] | Should -Match 'Unresolved'
    }

    It 'Does not rewrite references inside fenced code blocks' {
        $content = "Before`n`````n#file:../instructions/hve/commit-msg.instructions.md`n`````nAfter"

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '#file:\.\./instructions/hve/commit-msg\.instructions\.md'
        $result.Warnings.Count | Should -Be 0
    }

    It 'Does not rewrite references inside inline backtick spans' {
        $content = 'Use `#file:../instructions/hve/commit-msg.instructions.md` in your config.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '`#file:\.\./instructions/hve/commit-msg\.instructions\.md`'
        $result.Warnings.Count | Should -Be 0
    }

    It 'Strips trailing comma and preserves it after the rewritten reference' {
        $content = 'See #file:../../instructions/hve/commit-msg.instructions.md, and also this.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '#file:\.\./instructions/commit-msg\.md,'
        $result.Warnings.Count | Should -Be 0
    }

    It 'Strips trailing semicolon from references' {
        $content = 'Ref #file:../../instructions/hve/commit-msg.instructions.md; next.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '#file:\.\./instructions/commit-msg\.md;'
        $result.Warnings.Count | Should -Be 0
    }

    It 'Handles multiple references in the same content' {
        $content = 'See #file:commit-msg.instructions.md and #file:../../agents/hve/my-agent.agent.md for details.'

        # Use instruction source as the origin so both refs resolve
        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:instrSource `
            -DestinationFilePath $script:instrDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Match '#file:commit-msg\.md'
        $result.Content | Should -Match '#file:\.\./agents/my-agent\.md'
        $result.Warnings.Count | Should -Be 0
    }

    It 'Returns content unchanged when no #file: references are present' {
        $content = 'This is plain markdown with no file references.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap $script:sourceMap

        $result.Content | Should -Be $content
        $result.Warnings.Count | Should -Be 0
    }

    It 'Returns content unchanged with empty source map' {
        $content = 'See #file:some-file.md for info.'

        $result = Resolve-PluginFileReferences -Content $content `
            -SourceFilePath $script:agentSource `
            -DestinationFilePath $script:agentDest `
            -SourceMap @{}

        $result.Content | Should -Be $content
        $result.Warnings.Count | Should -Be 1
    }
}
