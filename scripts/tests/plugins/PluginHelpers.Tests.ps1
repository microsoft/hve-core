#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

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

Describe 'New-PluginReadmeContent - CollectionContent H1 stripping' {
    BeforeAll {
        $baseCollection = @{
            id          = 'test-h1'
            name        = 'Test Collection'
            description = 'A test collection'
        }
        $items = @(@{ Name = 'test-agent'; Description = 'desc'; Kind = 'agent' })
    }

    It 'Strips leading H1 from CollectionContent to avoid duplicate title' {
        $content = "# Test Collection`n`nBody text here.`n"
        $result = New-PluginReadmeContent -Collection $baseCollection -Items $items -CollectionContent $content
        $h1Matches = [regex]::Matches($result, '(?m)^# ')
        $h1Matches.Count | Should -Be 1
        $result | Should -Match 'Body text here\.'
    }

    It 'Preserves artifact markers and tables in CollectionContent' {
        $content = "# Test Collection`n`nBody text.`n`n## Included Artifacts`n`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`n`n### Chat Agents`n`n<!-- END AUTO-GENERATED ARTIFACTS -->`n"
        $result = New-PluginReadmeContent -Collection $baseCollection -Items $items -CollectionContent $content
        $result | Should -Match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
        $result | Should -Match '<!-- END AUTO-GENERATED ARTIFACTS -->'
        $result | Should -Match '## Included Artifacts'
        $includedArtifactMatches = [regex]::Matches($result, '(?m)^## Included Artifacts$')
        $includedArtifactMatches.Count | Should -Be 1
        $result | Should -Not -Match '(?m)^## Agents$'
    }

    It 'Does not duplicate sections when CollectionContent already holds rendered artifacts' {
        $content = "# Test Collection`n`nBody text.`n`n## Included Artifacts`n`n<!-- BEGIN AUTO-GENERATED ARTIFACTS -->`n`n### Chat Agents`n`n| Agent | Description |`n|-------|-------------|`n| test-agent | desc |`n`n<!-- END AUTO-GENERATED ARTIFACTS -->`n"
        $result = New-PluginReadmeContent -Collection $baseCollection -Items $items -CollectionContent $content
        [regex]::Matches($result, '(?m)^## Included Artifacts\r?$').Count | Should -Be 1
        [regex]::Matches($result, '(?m)^## Overview\r?$').Count | Should -Be 1
        [regex]::Matches($result, '(?m)^## Install\r?$').Count | Should -Be 1
        [regex]::Matches($result, '(?m)^# ').Count | Should -Be 1
        [regex]::Matches($result, '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->').Count | Should -Be 1
        $result | Should -Not -Match '(?m)^## Agents\r?$'
        $result | Should -Not -Match '(?m)^## Commands\r?$'
    }

    It 'Emits Overview section when CollectionContent has body text' {
        $content = "# Test Collection`n`nSome description.`n"
        $result = New-PluginReadmeContent -Collection $baseCollection -Items $items -CollectionContent $content
        $result | Should -Match '## Overview'
        $result | Should -Match 'Some description\.'
    }

    It 'Omits Overview section when CollectionContent is null' {
        $result = New-PluginReadmeContent -Collection $baseCollection -Items $items -CollectionContent $null
        $result | Should -Not -Match '## Overview'
    }

    It 'Omits Overview section when CollectionContent is whitespace' {
        $result = New-PluginReadmeContent -Collection $baseCollection -Items $items -CollectionContent '   '
        $result | Should -Not -Match '## Overview'
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

Describe 'New-PluginLink' {
    BeforeAll {
        $script:linkRoot = Join-Path $TestDrive 'link-test'
        New-Item -ItemType Directory -Path $script:linkRoot -Force | Out-Null
    }

    It 'Copies file content into destination without creating a stub' {
        $src = Join-Path $script:linkRoot 'src-file.txt'
        Set-Content -Path $src -Value 'payload' -NoNewline
        $dest = Join-Path $script:linkRoot 'dest-file.txt'

        New-PluginLink -SourcePath $src -DestinationPath $dest

        Test-Path $dest | Should -BeTrue
        (Get-Item -LiteralPath $dest).Attributes -band [System.IO.FileAttributes]::ReparsePoint | Should -Be 0
        [System.IO.File]::ReadAllText($dest) | Should -Be 'payload'
    }

    It 'Copies directory content into destination preserving nested files' {
        $srcDir = Join-Path $script:linkRoot 'src-dir'
        $nestedDir = Join-Path $srcDir 'nested'
        New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
        Set-Content -Path (Join-Path $srcDir 'root.txt') -Value 'root'
        Set-Content -Path (Join-Path $nestedDir 'child.txt') -Value 'child'
        $destDir = Join-Path $script:linkRoot 'dest-dir'

        New-PluginLink -SourcePath $srcDir -DestinationPath $destDir

        Test-Path (Join-Path $destDir 'root.txt') | Should -BeTrue
        Test-Path (Join-Path $destDir 'nested/child.txt') | Should -BeTrue
        [System.IO.File]::ReadAllText((Join-Path $destDir 'root.txt')).Trim() | Should -Be 'root'
        [System.IO.File]::ReadAllText((Join-Path $destDir 'nested/child.txt')).Trim() | Should -Be 'child'
    }

    It 'Creates parent directory when destination parent does not exist' {
        $src = Join-Path $script:linkRoot 'src-parent.txt'
        Set-Content -Path $src -Value 'data' -NoNewline
        $dest = Join-Path $script:linkRoot 'nested/deep/dest-parent.txt'

        New-PluginLink -SourcePath $src -DestinationPath $dest

        Test-Path $dest | Should -BeTrue
    }

    It 'Rejects a nested source link before modifying the destination' {
        $target = Join-Path $script:linkRoot 'nested-source-target.txt'
        Set-Content -Path $target -Value 'target' -NoNewline
        $src = Join-Path $script:linkRoot 'source-with-link'
        New-Item -ItemType Directory -Path $src -Force | Out-Null
        $nestedLink = Join-Path $src 'nested-link.txt'
        New-Item -ItemType SymbolicLink -Path $nestedLink -Target $target | Out-Null
        $dest = Join-Path $script:linkRoot 'preserved-destination'
        New-Item -ItemType Directory -Path $dest -Force | Out-Null
        Set-Content -Path (Join-Path $dest 'existing.txt') -Value 'existing' -NoNewline

        { New-PluginLink -SourcePath $src -DestinationPath $dest } |
            Should -Throw "*${nestedLink}*"

        Test-Path (Join-Path $dest 'existing.txt') | Should -BeTrue
        [System.IO.File]::ReadAllText($target) | Should -Be 'target'
    }
}

Describe 'New-PluginLink - tracked repository sources' {
    BeforeEach {
        $script:trackedRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:trackedRepo -Force | Out-Null
        Push-Location $script:trackedRepo
        git init --quiet
        git config user.email 'test@example.com'
        git config user.name 'Test User'
        Set-Content -Path '.gitignore' -Value "ignored.txt`nignored-only/*"
        git add .gitignore
        git commit --quiet -m 'initialize'
        Pop-Location
    }

    It 'Copies tracked files with spaces and tabs while excluding ignored content' {
        $source = Join-Path $script:trackedRepo 'source dir'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        $spaceFile = Join-Path $source 'space name.txt'
        $tabFile = Join-Path $source "tab`tname.txt"
        Set-Content -LiteralPath $spaceFile -Value 'space' -NoNewline
        Set-Content -LiteralPath $tabFile -Value 'tab' -NoNewline
        Set-Content -LiteralPath (Join-Path $source 'ignored.txt') -Value 'ignored' -NoNewline
        Push-Location $script:trackedRepo
        git add -- 'source dir'
        Pop-Location
        $destination = Join-Path $script:trackedRepo 'output'

        New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo

        [System.IO.File]::ReadAllText((Join-Path $destination 'space name.txt')) | Should -Be 'space'
        [System.IO.File]::ReadAllText((Join-Path $destination "tab`tname.txt")) | Should -Be 'tab'
        Test-Path -LiteralPath (Join-Path $destination 'ignored.txt') | Should -BeFalse
    }

    It 'Preserves an existing destination when a tracked file is missing' {
        $source = Join-Path $script:trackedRepo 'missing-source'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        $trackedFile = Join-Path $source 'tracked.txt'
        Set-Content -LiteralPath $trackedFile -Value 'tracked' -NoNewline
        Push-Location $script:trackedRepo
        git add -- 'missing-source/tracked.txt'
        Pop-Location
        Remove-Item -LiteralPath $trackedFile -Force
        $destination = Join-Path $script:trackedRepo 'preserved-missing'
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'existing' -NoNewline

        { New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo } |
            Should -Throw '*must be a real file*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
    }

    It 'Preserves an existing destination when the index contains a symlink' {
        $source = Join-Path $script:trackedRepo 'linked-source'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        $target = Join-Path $script:trackedRepo 'target.txt'
        Set-Content -LiteralPath $target -Value 'target' -NoNewline
        New-Item -ItemType SymbolicLink -Path (Join-Path $source 'link.txt') -Target $target | Out-Null
        Push-Location $script:trackedRepo
        git add -- 'linked-source/link.txt'
        Pop-Location
        $destination = Join-Path $script:trackedRepo 'preserved-link'
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'existing' -NoNewline

        { New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo } |
            Should -Throw '*unsupported tracked mode 120000*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
        [System.IO.File]::ReadAllText($target) | Should -Be 'target'
    }

    It 'Preserves an existing destination for an unsupported tracked mode' {
        $source = Join-Path $script:trackedRepo 'gitlink-source'
        New-Item -ItemType Directory -Path (Join-Path $source 'nested') -Force | Out-Null
        Push-Location $script:trackedRepo
        $commit = git rev-parse HEAD
        git update-index --add --cacheinfo "160000,$commit,gitlink-source/nested"
        Pop-Location
        $destination = Join-Path $script:trackedRepo 'preserved-gitlink'
        New-Item -ItemType Directory -Path $destination -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $destination 'existing.txt') -Value 'existing' -NoNewline

        { New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo } |
            Should -Throw '*unsupported tracked mode 160000*'

        Test-Path -LiteralPath (Join-Path $destination 'existing.txt') | Should -BeTrue
    }

    It 'Does not copy from a case-differing sibling directory on case-sensitive systems' -Skip:$IsWindows {
        $source = Join-Path $script:trackedRepo 'CaseSource'
        $sibling = Join-Path $script:trackedRepo 'casesource'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        New-Item -ItemType Directory -Path $sibling -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $sibling 'sibling.txt') -Value 'sibling' -NoNewline
        Push-Location $script:trackedRepo
        git add -- 'casesource/sibling.txt'
        Pop-Location
        $destination = Join-Path $script:trackedRepo 'case-output'

        New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo

        @(Get-ChildItem -LiteralPath $destination -Force).Count | Should -Be 0
    }

    It 'Creates only the selected root for an ignored-only directory' {
        $source = Join-Path $script:trackedRepo 'ignored-only'
        New-Item -ItemType Directory -Path $source -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $source 'local.txt') -Value 'local' -NoNewline
        $destination = Join-Path $script:trackedRepo 'empty-output'

        New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo

        Test-Path -LiteralPath $destination -PathType Container | Should -BeTrue
        @(Get-ChildItem -LiteralPath $destination -Force).Count | Should -Be 0
    }

    It 'Copies a direct repository file after preflight' {
        $source = Join-Path $script:trackedRepo 'direct.txt'
        Set-Content -LiteralPath $source -Value 'direct' -NoNewline
        $destination = Join-Path $script:trackedRepo 'direct-output.txt'

        New-PluginLink -SourcePath $source -DestinationPath $destination -RepoRoot $script:trackedRepo

        [System.IO.File]::ReadAllText($destination) | Should -Be 'direct'
        (Get-Item -LiteralPath $destination -Force).LinkType | Should -BeNullOrEmpty
    }
}

Describe 'Get-PluginItemName - hook kind' {
    It 'Returns the filename unchanged for a hook' {
        Get-PluginItemName -FileName 'telemetry.json' -Kind 'hook' | Should -Be 'telemetry.json'
    }
}

Describe 'Get-PluginItemSubpath - hook kind' {
    It 'Strips the .github/hooks prefix and returns the collection subpath' {
        $result = Get-PluginItemSubpath -Path '.github/hooks/shared/telemetry.json' -Kind 'hook'
        $result | Should -Be 'shared'
    }

    It 'Returns the nested subpath for deeper hook layouts' {
        $result = Get-PluginItemSubpath -Path '.github/hooks/shared/telemetry/config.json' -Kind 'hook'
        $result | Should -Be 'shared/telemetry'
    }

    It 'Returns empty string for a hook directly under the kind root' {
        $result = Get-PluginItemSubpath -Path '.github/hooks/telemetry.json' -Kind 'hook'
        $result | Should -Be ''
    }
}

Describe 'Get-PluginSubdirectory - hook kind' {
    It 'Returns hooks for the hook kind' {
        Get-PluginSubdirectory -Kind 'hook' | Should -Be 'hooks'
    }
}

Describe 'New-PluginManifestContent - hook paths' {
    It 'Emits a single hooks string for one hook path' {
        $manifest = New-PluginManifestContent -CollectionId 'shared' -Description 'desc' -Version '1.0.0' -HookPaths @('hooks/shared/telemetry.json')
        $manifest['hooks'] | Should -BeOfType [string]
        $manifest['hooks'] | Should -Be 'hooks/shared/telemetry.json'
    }

    It 'Uses the first sorted hook path and warns when multiple are declared' {
        $warnings = $null
        $manifest = New-PluginManifestContent -CollectionId 'shared' -Description 'desc' -Version '1.0.0' `
            -HookPaths @('hooks/shared/zeta.json', 'hooks/shared/alpha.json') -WarningVariable warnings -WarningAction SilentlyContinue
        $manifest['hooks'] | Should -Be 'hooks/shared/alpha.json'
        $warnings | Should -Not -BeNullOrEmpty
        ($warnings -join "`n") | Should -Match 'references only one'
    }

    It 'Omits the hooks key when no hook paths are provided' {
        $manifest = New-PluginManifestContent -CollectionId 'shared' -Description 'desc' -Version '1.0.0'
        $manifest.Contains('hooks') | Should -BeFalse
    }
}
