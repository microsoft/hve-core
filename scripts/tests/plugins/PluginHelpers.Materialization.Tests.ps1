#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../plugins/Modules/PluginHelpers.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {} -ModuleName PluginHelpers
    Mock Write-Warning {} -ModuleName PluginHelpers
}

Describe 'Assert-PluginStagingRoot' -Tag 'Unit' {
    BeforeAll {
        $script:stagingWorkspace = Join-Path $TestDrive 'staging-workspace'
        $script:stagingRepo = Join-Path $script:stagingWorkspace 'repo'
        New-Item -ItemType Directory -Path $script:stagingRepo -Force | Out-Null
    }

    It 'Accepts and normalizes an absolute sibling path' {
        $candidate = "$($script:stagingRepo)-packages"
        Assert-PluginStagingRoot -Path $candidate -RepoRoot $script:stagingRepo |
            Should -BeExactly ([System.IO.Path]::GetFullPath($candidate))
    }

    It 'Rejects a missing staging root' {
        { Assert-PluginStagingRoot -Path '' -RepoRoot $script:stagingRepo } |
            Should -Throw -ExpectedMessage '*A staging root is required*'
    }

    It 'Rejects a relative staging root' {
        { Assert-PluginStagingRoot -Path 'plugins' -RepoRoot $script:stagingRepo } |
            Should -Throw -ExpectedMessage "*must be an absolute path*"
    }

    It 'Rejects the repository root and a path below it' -ForEach @(
        @{ Candidate = { $script:stagingRepo } }
        @{ Candidate = { Join-Path $script:stagingRepo 'plugins' } }
    ) {
        $path = & $Candidate
        { Assert-PluginStagingRoot -Path $path -RepoRoot $script:stagingRepo } |
            Should -Throw -ExpectedMessage '*resolves inside the repository root*'
    }

    It 'Rejects a staging root that contains the repository' {
        { Assert-PluginStagingRoot -Path $script:stagingWorkspace -RepoRoot $script:stagingRepo } |
            Should -Throw -ExpectedMessage '*contains the repository root*'
    }
}

Describe 'Get-PluginTrackedPathIndex' -Tag 'Unit' {
    Context 'when the working tree mixes tracked and untracked content' {
        BeforeAll {
            $script:indexRepo = Join-Path $TestDrive 'tracked-index'
            New-PluginFixtureRepository -Path $script:indexRepo -SkipSharedResources -SkipAgentRoot -SkipDocumentationRoot | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:indexRepo -RelativePath '.github/skills/rpi/rpi-plan/SKILL.md' -Content "# Skill`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:indexRepo -RelativePath '.github/skills/rpi/rpi-plan/references/checklist.md' -Content "# Checklist`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:indexRepo -RelativePath '.github/skills/rpi/rpi-plan/.venv/lib/site.py' -Content "sentinel_venv`n" -Untracked | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:indexRepo -RelativePath '.github/skills/rpi/rpi-plan/__pycache__/cache.pyc' -Content "sentinel_pycache`n" -Untracked | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:indexRepo -RelativePath '.github/skills/rpi/rpi-plan/scratch.md' -Content "sentinel_scratch`n" -Untracked | Out-Null

            $script:trackedIndex = Get-PluginTrackedPathIndex -RepoRoot $script:indexRepo
        }

        It 'Returns exactly the staged paths' {
            @($script:trackedIndex.Paths | Sort-Object) | Should -Be @(
                @(
                    '.github/plugin.json',
                    '.github/skills/rpi/rpi-plan/SKILL.md',
                    '.github/skills/rpi/rpi-plan/references/checklist.md',
                    'package.json'
                ) | Sort-Object
            )
        }

        It 'Records only real files, never directories' {
            foreach ($trackedPath in $script:trackedIndex.Paths) {
                Test-Path -LiteralPath (Join-Path $script:indexRepo $trackedPath) -PathType Leaf | Should -BeTrue
            }
        }

        It 'Excludes the untracked sentinel <Path>' -ForEach @(
            @{ Path = '.github/skills/rpi/rpi-plan/.venv/lib/site.py' }
            @{ Path = '.github/skills/rpi/rpi-plan/__pycache__/cache.pyc' }
            @{ Path = '.github/skills/rpi/rpi-plan/scratch.md' }
        ) {
            $script:trackedIndex.Lookup.Contains($Path) | Should -BeFalse
        }

        It 'Exposes an ordinal lookup for tracked paths' {
            $script:trackedIndex.Lookup.Contains('package.json') | Should -BeTrue
            $script:trackedIndex.Lookup.Contains('PACKAGE.JSON') | Should -BeFalse
        }

        It 'Records the resolved working tree root' {
            $script:trackedIndex.RepoRoot | Should -BeExactly ([System.IO.Path]::GetFullPath($script:indexRepo))
        }
    }

    Context 'when the directory is not a git working tree' {
        It 'Refuses to build an allowlist' {
            $plainDirectory = Join-Path $TestDrive 'not-a-repo'
            New-Item -ItemType Directory -Path $plainDirectory -Force | Out-Null
            { Get-PluginTrackedPathIndex -RepoRoot $plainDirectory } |
                Should -Throw -ExpectedMessage '*Unable to enumerate git-tracked paths*'
        }
    }
}

Describe 'Copy-PluginSource' -Tag 'Unit' {
    BeforeEach {
        $script:sourceRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:sourceRepo -SkipSharedResources -SkipAgentRoot -SkipDocumentationRoot | Out-Null
        $script:destinationRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
    }

    Context 'when the source is a tracked file' {
        It 'Writes exactly one destination file with the working-tree bytes' {
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/agents/rpi/rpi-planner.agent.md' -Content "staged`n" | Out-Null
            $destination = Join-Path $script:destinationRoot 'agents/rpi/rpi-planner.md'

            $written = @(Copy-PluginSource -SourcePath (Join-Path $script:sourceRepo '.github/agents/rpi/rpi-planner.agent.md') `
                    -DestinationPath $destination -RepoRoot $script:sourceRepo)

            @($written) | Should -HaveCount 1
            Get-Content -LiteralPath $destination -Raw | Should -BeExactly "staged`n"
        }

        It 'Copies the current working-tree bytes of a modified tracked file' {
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/agents/rpi/rpi-planner.agent.md' -Content "staged`n" | Out-Null
            Set-Content -LiteralPath (Join-Path $script:sourceRepo '.github/agents/rpi/rpi-planner.agent.md') `
                -Value "modified working tree`n" -Encoding utf8NoBOM -NoNewline
            $destination = Join-Path $script:destinationRoot 'agents/rpi/rpi-planner.md'

            Copy-PluginSource -SourcePath (Join-Path $script:sourceRepo '.github/agents/rpi/rpi-planner.agent.md') `
                -DestinationPath $destination -RepoRoot $script:sourceRepo | Out-Null

            Get-Content -LiteralPath $destination -Raw | Should -BeExactly "modified working tree`n"
        }
    }

    Context 'when the source is a directory holding untracked residue' {
        BeforeEach {
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/SKILL.md' -Content "# Skill`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/references/deep/notes.md' -Content "# Notes`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/.venv/lib/site.py' -Content "sentinel_venv`n" -Untracked | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/__pycache__/cache.pyc' -Content "sentinel_pycache`n" -Untracked | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/scratch.md' -Content "sentinel_scratch`n" -Untracked | Out-Null
            New-Item -ItemType SymbolicLink -Force `
                -Path (Join-Path $script:sourceRepo '.github/skills/rpi/rpi-plan/linked.md') `
                -Target (Join-Path $script:sourceRepo '.github/skills/rpi/rpi-plan/SKILL.md') | Out-Null

            $script:skillDestination = Join-Path $script:destinationRoot 'skills/rpi/rpi-plan'
            $script:copied = @(Copy-PluginSource -SourcePath (Join-Path $script:sourceRepo '.github/skills/rpi/rpi-plan') `
                    -DestinationPath $script:skillDestination -RepoRoot $script:sourceRepo)
        }

        It 'Reconstructs the nested tracked subtree exactly' {
            @(Get-PluginFixtureInventory -Path $script:skillDestination) | Should -Be @(
                @('SKILL.md', 'references/deep/notes.md') | Sort-Object
            )
        }

        It 'Returns one destination path per materialized file' {
            @($script:copied) | Should -HaveCount 2
        }

        It 'Leaks no untracked sentinel content' {
            $materializedText = @(Get-ChildItem -LiteralPath $script:skillDestination -File -Recurse -Force |
                    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
            foreach ($sentinel in @('sentinel_venv', 'sentinel_pycache', 'sentinel_scratch')) {
                $materializedText | Should -Not -Match $sentinel
            }
        }

        It 'Materializes no symbolic link' {
            @(Get-PluginFixtureReparsePoint -Path $script:skillDestination) | Should -HaveCount 0
            Test-Path -LiteralPath (Join-Path $script:skillDestination 'linked.md') | Should -BeFalse
        }
    }

    Context 'when a staged path is absent from the working tree' {
        BeforeEach {
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/SKILL.md' -Content "# Skill`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/rpi-plan/ghost.md' -Content "# Ghost`n" | Out-Null
            Remove-Item -LiteralPath (Join-Path $script:sourceRepo '.github/skills/rpi/rpi-plan/ghost.md') -Force

            $script:ghostDestination = Join-Path $script:destinationRoot 'skills/rpi/rpi-plan'
            Copy-PluginSource -SourcePath (Join-Path $script:sourceRepo '.github/skills/rpi/rpi-plan') `
                -DestinationPath $script:ghostDestination -RepoRoot $script:sourceRepo | Out-Null
        }

        It 'Warns about the missing tracked source' {
            Should -Invoke Write-Warning -ModuleName PluginHelpers -Times 1 -Exactly -ParameterFilter {
                $Message -match 'Tracked source missing from the working tree' -and $Message -match 'ghost\.md'
            }
        }

        It 'Materializes the remaining tracked files' {
            @(Get-PluginFixtureInventory -Path $script:ghostDestination) | Should -Be @('SKILL.md')
        }
    }

    Context 'when the source has no tracked content' {
        BeforeEach {
            Add-PluginFixtureFile -RepoRoot $script:sourceRepo -RelativePath '.github/skills/rpi/orphan/notes.md' -Content "sentinel_orphan`n" -Untracked | Out-Null
            $script:orphanDestination = Join-Path $script:destinationRoot 'skills/rpi/orphan'
            $script:orphanResult = @(Copy-PluginSource -SourcePath (Join-Path $script:sourceRepo '.github/skills/rpi/orphan') `
                    -DestinationPath $script:orphanDestination -RepoRoot $script:sourceRepo)
        }

        It 'Returns no destination paths' {
            @($script:orphanResult) | Should -HaveCount 0
        }

        It 'Creates no destination directory' {
            Test-Path -LiteralPath $script:orphanDestination | Should -BeFalse
        }

        It 'Warns that no tracked content was found' {
            Should -Invoke Write-Warning -ModuleName PluginHelpers -Times 1 -Exactly -ParameterFilter {
                $Message -match 'No git-tracked content found for source'
            }
        }
    }

    Context 'when the source escapes the repository root' {
        It 'Refuses to materialize' {
            $outsidePath = Join-Path (Split-Path -Parent $script:sourceRepo) 'outside-source.md'
            Set-Content -LiteralPath $outsidePath -Value "outside`n" -Encoding utf8NoBOM -NoNewline
            { Copy-PluginSource -SourcePath $outsidePath -DestinationPath (Join-Path $script:destinationRoot 'x.md') `
                    -RepoRoot $script:sourceRepo } |
                Should -Throw -ExpectedMessage '*resolves outside the repository root*'
        }
    }
}

Describe 'Write-PluginDirectory' -Tag 'Unit' {
    BeforeAll {
        $script:packageItems = @(
            @{ Kind = 'agent'; Field = 'agents'; PackagePath = 'agents/rpi/rpi-planner.md'; SourcePath = '.github/agents/rpi/rpi-planner.agent.md' }
            @{ Kind = 'prompt'; Field = 'commands'; PackagePath = 'commands/rpi/rpi-plan.md'; SourcePath = '.github/prompts/rpi/rpi-plan.prompt.md' }
            @{ Kind = 'instruction'; Field = 'rules'; PackagePath = 'rules/shared/hve-core-location.instructions.md'; SourcePath = '.github/instructions/shared/hve-core-location.instructions.md' }
            @{ Kind = 'skill'; Field = 'skills'; PackagePath = 'skills/rpi/rpi-plan'; SourcePath = '.github/skills/rpi/rpi-plan' }
            @{ Kind = 'hook'; Field = 'hooks'; PackagePath = 'hooks/rpi/telemetry.json'; SourcePath = '.github/hooks/rpi/telemetry.json' }
        )
        $script:packageEntry = [ordered]@{
            name        = 'rpi'
            description = 'RPI workflow package'
            version     = '9.9.9'
            author      = [ordered]@{ name = 'Contoso'; url = 'https://contoso.example' }
            homepage    = 'https://contoso.example/hve'
            repository  = 'https://github.com/contoso/contoso-hve'
            license     = 'MIT'
            keywords    = @('rpi')
            'x-hve'     = [ordered]@{ displayName = 'Contoso - rpi'; documentation = 'docs/plugins/rpi.md' }
        }
    }

    BeforeEach {
        $script:writeRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:writeRepo -Version '9.9.9' | Out-Null
        Add-PluginFixtureArtifactSet -RepoRoot $script:writeRepo | Out-Null
        $script:pluginsDirectory = Join-Path $script:writeRepo 'plugins'
    }

    Context 'when materializing a package that declares every artifact kind' {
        BeforeEach {
            $script:writeResult = Write-PluginDirectory -Entry $script:packageEntry -Items $script:packageItems `
                -PluginsDir $script:pluginsDirectory -RepoRoot $script:writeRepo -Version '9.9.9'
            $script:packageRoot = Join-Path $script:pluginsDirectory 'rpi'
            $script:packageInventory = @(Get-PluginFixtureInventory -Path $script:packageRoot)
        }

        It 'Materializes exactly the expected package tree' {
            $script:packageInventory | Should -Be @(
                @(
                    'README.md',
                    'agents/rpi/rpi-planner.md',
                    'commands/rpi/rpi-plan.md',
                    'docs/templates/adr-template.md',
                    'hooks/rpi/telemetry.json',
                    'hooks/rpi/telemetry/collect.sh',
                    'plugin.json',
                    'rules/shared/hve-core-location.instructions.md',
                    'scripts/lib/Modules/Shared.psm1',
                    'skills/rpi/rpi-plan/SKILL.md',
                    'skills/rpi/rpi-plan/references/checklist.md'
                ) | Sort-Object
            )
        }

        It 'Reports exact per-kind counts' {
            $script:writeResult.Success | Should -BeTrue
            $script:writeResult.AgentCount | Should -Be 1
            $script:writeResult.CommandCount | Should -Be 1
            $script:writeResult.InstructionCount | Should -Be 1
            $script:writeResult.SkillCount | Should -Be 1
            $script:writeResult.HookCount | Should -Be 1
        }

        It 'Records every materialized file in GeneratedFiles' {
            foreach ($relativePath in $script:packageInventory) {
                $absolutePath = Join-Path -Path $script:packageRoot -ChildPath ($relativePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
                $script:writeResult.GeneratedFiles.Contains($absolutePath) | Should -BeTrue -Because "$relativePath must be tracked for orphan cleanup"
            }
        }

        It 'Renames agent and prompt artifacts to their package form' {
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'agents/rpi/rpi-planner.md') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'commands/rpi/rpi-plan.md') -PathType Leaf | Should -BeTrue
            $script:packageInventory | Should -Not -Contain 'agents/rpi/rpi-planner.agent.md'
            $script:packageInventory | Should -Not -Contain 'commands/rpi/rpi-plan.prompt.md'
        }

        It 'Keeps instruction, skill, and hook artifacts at their declared paths' {
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'rules/shared/hve-core-location.instructions.md') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'skills/rpi/rpi-plan/SKILL.md') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'hooks/rpi/telemetry.json') -PathType Leaf | Should -BeTrue
        }

        It 'Rewrites hook command paths to the plugin root placeholder' {
            $hookText = Get-Content -LiteralPath (Join-Path $script:packageRoot 'hooks/rpi/telemetry.json') -Raw
            $hookText | Should -Match '\$\{CLAUDE_PLUGIN_ROOT\}/hooks/rpi/telemetry/collect\.sh'
            $hookText | Should -Not -Match 'CLAUDE_PLUGIN_ROOT:-\.github'
            $hookText | Should -Not -Match '\.github/hooks/'
        }

        It 'Materializes the shared resource directories' {
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'docs/templates/adr-template.md') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:packageRoot 'scripts/lib/Modules/Shared.psm1') -PathType Leaf | Should -BeTrue
        }

        It 'Emits one root plugin.json and no nested or legacy manifest' {
            @(Get-ChildItem -LiteralPath $script:packageRoot -Filter 'plugin.json' -File -Recurse -Force) | Should -HaveCount 1
            $script:packageInventory | Should -Contain 'plugin.json'
            Test-Path -LiteralPath (Join-Path $script:packageRoot '.copilot') | Should -BeFalse
        }

        It 'Declares component paths and mirrored provenance in plugin.json' {
            $manifest = Get-Content -LiteralPath (Join-Path $script:packageRoot 'plugin.json') -Raw | ConvertFrom-Json -AsHashtable
            $manifest['name'] | Should -BeExactly 'rpi'
            $manifest['version'] | Should -BeExactly '9.9.9'
            @($manifest['agents']) | Should -Be @('agents/rpi/')
            @($manifest['commands']) | Should -Be @('commands/rpi/')
            @($manifest['rules']) | Should -Be @('rules/shared/')
            @($manifest['skills']) | Should -Be @('skills/rpi/rpi-plan/')
            $manifest['hooks'] | Should -BeExactly 'hooks/rpi/telemetry.json'
            $manifest['author']['name'] | Should -BeExactly 'Contoso'
            $manifest['homepage'] | Should -BeExactly 'https://contoso.example/hve'
            $manifest['license'] | Should -BeExactly 'MIT'
        }

        It 'Keeps the catalog overlay out of the generated manifest' {
            $manifestText = Get-Content -LiteralPath (Join-Path $script:packageRoot 'plugin.json') -Raw
            $manifestText | Should -Not -Match 'x-hve'
            $manifestText | Should -Not -Match 'displayName'
        }

        It 'Materializes no symbolic link' {
            @(Get-PluginFixtureReparsePoint -Path $script:packageRoot) | Should -HaveCount 0
        }
    }

    Context 'when a declared source file is absent' {
        BeforeEach {
            $script:missingItems = @(
                @{ Kind = 'agent'; Field = 'agents'; PackagePath = 'agents/rpi/absent.md'; SourcePath = '.github/agents/rpi/absent.agent.md' }
            )
            Write-PluginDirectory -Entry $script:packageEntry -Items $script:missingItems `
                -PluginsDir $script:pluginsDirectory -RepoRoot $script:writeRepo -Version '9.9.9' | Out-Null
        }

        It 'Warns that the source file was not found' {
            Should -Invoke Write-Warning -ModuleName PluginHelpers -Times 1 -Exactly -ParameterFilter {
                $Message -match 'Source file not found' -and $Message -match 'absent\.agent\.md'
            }
        }

        It 'Materializes no artifact file for the absent source' {
            Test-Path -LiteralPath (Join-Path $script:pluginsDirectory 'rpi/agents/rpi/absent.md') | Should -BeFalse
        }
    }

    Context 'when running as a dry run' {
        BeforeEach {
            $script:dryRunResult = Write-PluginDirectory -Entry $script:packageEntry -Items $script:packageItems `
                -PluginsDir $script:pluginsDirectory -RepoRoot $script:writeRepo -Version '9.9.9' -DryRun
        }

        It 'Creates no output directory' {
            Test-Path -LiteralPath $script:pluginsDirectory | Should -BeFalse
        }

        It 'Still reports the counts that would be produced' {
            $script:dryRunResult.AgentCount | Should -Be 1
            $script:dryRunResult.SkillCount | Should -Be 1
            $script:dryRunResult.HookCount | Should -Be 1
        }
    }
}

Describe 'Hook plugin root fallback' -Tag 'Unit' {
    BeforeAll {
        $script:hookRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:hookSourceText = Get-Content -LiteralPath (Join-Path $script:hookRepoRoot '.github/hooks/shared/telemetry.json') -Raw -Encoding utf8

        $script:hookRootExpression = '[string]::IsNullOrWhiteSpace($env:CLAUDE_PLUGIN_ROOT) ? ''.github'' : $env:CLAUDE_PLUGIN_ROOT'
        $script:hookRepositoryBash = '${CLAUDE_PLUGIN_ROOT:-.github}/hooks/shared/telemetry/telemetry-collector.sh'
        $script:hookRepositoryPwsh = "& (Join-Path ($script:hookRootExpression) 'hooks/shared/telemetry/Invoke-TelemetryCollector.ps1')"
        $script:hookInstalledBash = '${CLAUDE_PLUGIN_ROOT}/hooks/shared/telemetry/telemetry-collector.sh'
        $script:hookInstalledPwsh = '& (Join-Path $env:CLAUDE_PLUGIN_ROOT ''hooks/shared/telemetry/Invoke-TelemetryCollector.ps1'')'
        $script:hookEventNames = @(
            'sessionStart', 'userPromptSubmitted', 'userPromptSubmit', 'preToolUse', 'postToolUse',
            'subagentStart', 'subagentStop', 'sessionEnd', 'stop', 'agentStop', 'preCompact'
        )

        # Produce the installed form through the production writer so the
        # transform under test is exercised rather than a hand-written copy.
        $hookRepo = Join-Path $TestDrive 'hook-fallback'
        New-PluginFixtureRepository -Path $hookRepo -Version '9.9.9' | Out-Null
        Add-PluginFixtureFile -RepoRoot $hookRepo -RelativePath '.github/hooks/shared/telemetry.json' -Content $script:hookSourceText | Out-Null
        Add-PluginFixtureFile -RepoRoot $hookRepo -RelativePath '.github/hooks/shared/telemetry/telemetry-collector.sh' -Content "#!/usr/bin/env bash`nexit 0`n" | Out-Null
        Add-PluginFixtureFile -RepoRoot $hookRepo -RelativePath '.github/hooks/shared/telemetry/Invoke-TelemetryCollector.ps1' -Content "exit 0`n" | Out-Null

        Write-PluginDirectory -Entry ([ordered]@{ name = 'shared'; description = 'Shared telemetry package'; version = '9.9.9'; license = 'MIT' }) `
            -Items @(@{ Kind = 'hook'; Field = 'hooks'; PackagePath = 'hooks/shared/telemetry.json'; SourcePath = '.github/hooks/shared/telemetry.json' }) `
            -PluginsDir (Join-Path $hookRepo 'plugins') -RepoRoot $hookRepo -Version '9.9.9' | Out-Null

        $script:hookInstalledText = Get-Content -LiteralPath (Join-Path $hookRepo 'plugins/shared/hooks/shared/telemetry.json') -Raw -Encoding utf8
        $script:hookRepositoryEvents = (ConvertFrom-Json $script:hookSourceText -AsHashtable)['hooks']
        $script:hookInstalledEvents = (ConvertFrom-Json $script:hookInstalledText -AsHashtable)['hooks']
    }

    Context 'when the manifest runs from the repository' {
        It 'Declares every lifecycle event' {
            @($script:hookRepositoryEvents.Keys | Sort-Object) | Should -Be @($script:hookEventNames | Sort-Object)
        }

        It 'Gives every event the same bash and PowerShell fallback command' {
            foreach ($eventName in $script:hookRepositoryEvents.Keys) {
                foreach ($entry in $script:hookRepositoryEvents[$eventName]) {
                    $entry['bash'] | Should -BeExactly $script:hookRepositoryBash -Because "event '$eventName' must keep the bash fallback"
                    $entry['powershell'] | Should -BeExactly $script:hookRepositoryPwsh -Because "event '$eventName' must keep the PowerShell fallback"
                    $entry['type'] | Should -BeExactly 'command'
                    $entry['timeoutSec'] | Should -Be 10
                }
            }
        }

        It 'Resolves the fallback root to tracked collector scripts' {
            Test-Path -LiteralPath (Join-Path $script:hookRepoRoot '.github/hooks/shared/telemetry/telemetry-collector.sh') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:hookRepoRoot '.github/hooks/shared/telemetry/Invoke-TelemetryCollector.ps1') -PathType Leaf | Should -BeTrue
        }

        It 'Resolves the same root as bash for <Case>' -ForEach @(
            @{ Case = 'an unset root'; Value = $null; Expected = '.github' }
            @{ Case = 'an empty root'; Value = ''; Expected = '.github' }
            @{ Case = 'an explicit root'; Value = '/opt/hve/plugins/shared'; Expected = '/opt/hve/plugins/shared' }
        ) {
            $previousRoot = $env:CLAUDE_PLUGIN_ROOT
            try {
                $env:CLAUDE_PLUGIN_ROOT = $Value
                $powershellRoot = & ([scriptblock]::Create($script:hookRootExpression))
                # Mirrors ${CLAUDE_PLUGIN_ROOT:-.github}, which substitutes when unset or empty.
                $bashRoot = if ([string]::IsNullOrEmpty($env:CLAUDE_PLUGIN_ROOT)) { '.github' } else { $env:CLAUDE_PLUGIN_ROOT }

                $powershellRoot | Should -BeExactly $Expected
                $bashRoot | Should -BeExactly $Expected
            }
            finally {
                $env:CLAUDE_PLUGIN_ROOT = $previousRoot
            }
        }

        It 'Falls back on a whitespace-only root that bash would pass through' {
            $previousRoot = $env:CLAUDE_PLUGIN_ROOT
            try {
                $env:CLAUDE_PLUGIN_ROOT = '   '
                & ([scriptblock]::Create($script:hookRootExpression)) | Should -BeExactly '.github'
            }
            finally {
                $env:CLAUDE_PLUGIN_ROOT = $previousRoot
            }
        }
    }

    Context 'when the manifest is materialized into a plugin' {
        It 'Preserves every lifecycle event and its telemetry contract' {
            @($script:hookInstalledEvents.Keys | Sort-Object) | Should -Be @($script:hookEventNames | Sort-Object)
            foreach ($eventName in $script:hookInstalledEvents.Keys) {
                @($script:hookInstalledEvents[$eventName]) | Should -HaveCount @($script:hookRepositoryEvents[$eventName]).Count
                foreach ($entry in $script:hookInstalledEvents[$eventName]) {
                    $entry['type'] | Should -BeExactly 'command'
                    $entry['timeoutSec'] | Should -Be 10
                }
            }
        }

        It 'Resolves both host commands from the plugin root' {
            foreach ($eventName in $script:hookInstalledEvents.Keys) {
                foreach ($entry in $script:hookInstalledEvents[$eventName]) {
                    $entry['bash'] | Should -BeExactly $script:hookInstalledBash -Because "event '$eventName' must resolve from the plugin root"
                    $entry['powershell'] | Should -BeExactly $script:hookInstalledPwsh -Because "event '$eventName' must resolve from the plugin root"
                }
            }
        }

        It 'Removes every repository fallback' {
            $script:hookInstalledText | Should -Not -Match 'CLAUDE_PLUGIN_ROOT:-'
            $script:hookInstalledText | Should -Not -Match 'IsNullOrWhiteSpace'
            $script:hookInstalledText | Should -Not -Match '\.github'
        }
    }
}

AfterAll {
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
}
