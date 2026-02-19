#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../plugins/Validate-Collections.ps1
}

Describe 'Test-KindSuffix' {
    It 'Returns empty for valid agent path' {
        $result = Test-KindSuffix -Kind 'agent' -ItemPath '.github/agents/rpi-agent.agent.md' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns empty for valid prompt path' {
        $result = Test-KindSuffix -Kind 'prompt' -ItemPath '.github/prompts/gen-plan.prompt.md' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns empty for valid instruction path' {
        $result = Test-KindSuffix -Kind 'instruction' -ItemPath '.github/instructions/csharp.instructions.md' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns empty for valid skill path with SKILL.md' {
        $skillDir = Join-Path $TestDrive '.github/skills/video-to-gif'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        Set-Content -Path (Join-Path $skillDir 'SKILL.md') -Value '# Skill'

        $result = Test-KindSuffix -Kind 'skill' -ItemPath '.github/skills/video-to-gif' -RepoRoot $TestDrive
        $result | Should -BeNullOrEmpty
    }

    It 'Returns error for invalid agent suffix' {
        $result = Test-KindSuffix -Kind 'agent' -ItemPath '.github/agents/bad.prompt.md' -RepoRoot $TestDrive
        $result | Should -Match "kind 'agent' expects"
    }

    It 'Returns error for invalid prompt suffix' {
        $result = Test-KindSuffix -Kind 'prompt' -ItemPath '.github/prompts/bad.agent.md' -RepoRoot $TestDrive
        $result | Should -Match "kind 'prompt' expects"
    }

    It 'Returns error when SKILL.md missing for skill kind' {
        $emptySkillDir = Join-Path $TestDrive '.github/skills/no-skill'
        New-Item -ItemType Directory -Path $emptySkillDir -Force | Out-Null

        $result = Test-KindSuffix -Kind 'skill' -ItemPath '.github/skills/no-skill' -RepoRoot $TestDrive
        $result | Should -Match "kind 'skill' expects SKILL.md"
    }
}

Describe 'Resolve-ItemMaturity' {
    It 'Returns stable for null maturity' {
        $result = Resolve-ItemMaturity -Maturity $null
        $result | Should -Be 'stable'
    }

    It 'Returns stable for empty string' {
        $result = Resolve-ItemMaturity -Maturity ''
        $result | Should -Be 'stable'
    }

    It 'Returns stable for whitespace' {
        $result = Resolve-ItemMaturity -Maturity '   '
        $result | Should -Be 'stable'
    }

    It 'Passes through explicit value' {
        $result = Resolve-ItemMaturity -Maturity 'preview'
        $result | Should -Be 'preview'
    }

    It 'Passes through experimental value' {
        $result = Resolve-ItemMaturity -Maturity 'experimental'
        $result | Should -Be 'experimental'
    }
}

Describe 'Get-CollectionItemKey' {
    It 'Builds correct composite key' {
        $result = Get-CollectionItemKey -Kind 'agent' -ItemPath '.github/agents/rpi-agent.agent.md'
        $result | Should -Be 'agent|.github/agents/rpi-agent.agent.md'
    }

    It 'Builds key for instruction kind' {
        $result = Get-CollectionItemKey -Kind 'instruction' -ItemPath '.github/instructions/csharp.instructions.md'
        $result | Should -Be 'instruction|.github/instructions/csharp.instructions.md'
    }
}

Describe 'Invoke-CollectionValidation - repo-specific path rejection' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Create artifact directories and files
        $instrDir = Join-Path $script:repoRoot '.github/instructions'
        $agentsDir = Join-Path $script:repoRoot '.github/agents'
        $sharedDir = Join-Path $instrDir 'shared'
        $hveCoreAgentsDir = Join-Path $agentsDir 'hve-core'

        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null
        New-Item -ItemType Directory -Path $hveCoreAgentsDir -Force | Out-Null

        # Root-level (repo-specific) files
        Set-Content -Path (Join-Path $instrDir 'workflows.instructions.md') -Value '---\ndescription: repo-specific\n---'
        Set-Content -Path (Join-Path $agentsDir 'internal.agent.md') -Value '---\ndescription: repo-specific agent\n---'

        # Subdirectory (collection-scoped) files
        Set-Content -Path (Join-Path $sharedDir 'hve-core-location.instructions.md') -Value '---\ndescription: shared\n---'
        Set-Content -Path (Join-Path $hveCoreAgentsDir 'rpi-agent.agent.md') -Value '---\ndescription: distributable agent\n---'
    }

    BeforeEach {
        # Clear collection files between tests to prevent cross-contamination
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Fails validation for root-level instruction' {
        $manifest = [ordered]@{
            id          = 'test-reject-instr'
            name        = 'Test Reject Instruction'
            description = 'Tests repo-specific instruction rejection'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/workflows.instructions.md'
                    kind = 'instruction'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-reject-instr.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for instruction in subdirectory' {
        $manifest = [ordered]@{
            id          = 'test-allow-location'
            name        = 'Test Allow Location'
            description = 'Tests that subdirectory instructions are allowed'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/shared/hve-core-location.instructions.md'
                    kind = 'instruction'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-allow-location.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Fails validation for root-level agent' {
        $manifest = [ordered]@{
            id          = 'test-reject-agent'
            name        = 'Test Reject Agent'
            description = 'Tests repo-specific agent rejection'
            items       = @(
                [ordered]@{
                    path = '.github/agents/internal.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-reject-agent.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for agent in subdirectory' {
        $manifest = [ordered]@{
            id          = 'test-allow-agent'
            name        = 'Test Allow Agent'
            description = 'Tests that subdirectory agents pass'
            items       = @(
                [ordered]@{
                    path = '.github/agents/hve-core/rpi-agent.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-allow-agent.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }
}
