#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Assert-NoTrackedPluginOutput.ps1')
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
}

Describe 'Assert-NoTrackedPluginOutput' -Tag 'Unit' {
    BeforeEach {
        $script:guardRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:guardRepo -Version '9.9.9' -SkipSharedResources | Out-Null
        Add-PluginFixtureFile -RepoRoot $script:guardRepo -RelativePath 'docs/plugins/rpi.md' -Content "# rpi`n" | Out-Null
        Add-PluginFixtureFile -RepoRoot $script:guardRepo -RelativePath '.github/agents/rpi/rpi-planner.agent.md' -Content "# agent`n" | Out-Null
    }

    Context 'when the index carries no generated output and no link' {
        BeforeEach {
            $script:cleanResult = Assert-NoTrackedPluginOutput -RepoRoot $script:guardRepo
        }

        It 'Inspects every staged entry' {
            $script:cleanResult.EntryCount | Should -Be 4
        }

        It 'Reports no violation' {
            $script:cleanResult.TrackedPluginPathCount | Should -Be 0
            $script:cleanResult.SymbolicLinkPathCount | Should -Be 0
        }

        It 'Returns only the inspection counters' {
            @($script:cleanResult.Keys | Sort-Object) | Should -Be @('EntryCount', 'SymbolicLinkPathCount', 'TrackedPluginPathCount')
        }

        It 'Ignores untracked generated output' {
            Add-PluginFixtureFile -RepoRoot $script:guardRepo -RelativePath 'plugins/rpi/plugin.json' -Content '{}' -Untracked | Out-Null
            { Assert-NoTrackedPluginOutput -RepoRoot $script:guardRepo } | Should -Not -Throw
        }
    }

    Context 'when generated output is staged' {
        It 'Fails for the tracked path <Path>' -ForEach @(
            @{ Path = 'plugins/rpi/plugin.json'; Content = '{}' }
            @{ Path = 'plugins/rpi/README.md'; Content = "# rpi`n" }
            @{ Path = 'plugins'; Content = "not a directory`n" }
        ) {
            Add-PluginFixtureFile -RepoRoot $script:guardRepo -RelativePath $Path -Content $Content | Out-Null
            { Assert-NoTrackedPluginOutput -RepoRoot $script:guardRepo } |
                Should -Throw -ExpectedMessage "*Tracked plugin output is forbidden: *$Path*"
        }
    }

    Context 'when a symbolic link is staged anywhere in the repository' {
        BeforeEach {
            New-Item -ItemType SymbolicLink -Force `
                -Path (Join-Path $script:guardRepo 'docs/plugins/linked.md') `
                -Target (Join-Path $script:guardRepo 'docs/plugins/rpi.md') | Out-Null
            Invoke-PluginFixtureGit -RepoRoot $script:guardRepo -Arguments @('add', '--force', '--', 'docs/plugins/linked.md') | Out-Null
        }

        It 'Fails on symbolic-link index mode' {
            { Assert-NoTrackedPluginOutput -RepoRoot $script:guardRepo } |
                Should -Throw -ExpectedMessage '*Symbolic-link mode 120000 is forbidden: docs/plugins/linked.md*'
        }

        It 'Reports both violations when generated output is also staged' {
            Add-PluginFixtureFile -RepoRoot $script:guardRepo -RelativePath 'plugins/rpi/plugin.json' -Content '{}' | Out-Null
            $thrownMessage = ''
            try {
                Assert-NoTrackedPluginOutput -RepoRoot $script:guardRepo
            }
            catch {
                $thrownMessage = $_.Exception.Message
            }
            $thrownMessage | Should -Match 'Tracked plugin output is forbidden'
            $thrownMessage | Should -Match 'Symbolic-link mode 120000 is forbidden'
        }
    }

    Context 'when the directory is not a git working tree' {
        It 'Refuses to report a clean index' {
            $plainDirectory = Join-Path $TestDrive 'guard-not-a-repo'
            New-Item -ItemType Directory -Path $plainDirectory -Force | Out-Null
            { Assert-NoTrackedPluginOutput -RepoRoot $plainDirectory } |
                Should -Throw -ExpectedMessage '*Unable to inspect the Git index*'
        }
    }
}

AfterAll {
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
}
