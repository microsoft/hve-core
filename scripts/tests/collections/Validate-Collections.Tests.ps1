#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../collections/Validate-Collections.ps1
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

Describe 'Invoke-CollectionValidation - collection-level maturity' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'maturity-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Create a valid artifact for items to reference
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'test.agent.md') -Value '---\ndescription: test agent\n---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Passes validation for collection with maturity: experimental' {
        $manifest = [ordered]@{
            id          = 'test-maturity-experimental'
            name        = 'Test'
            description = 'Tests experimental maturity'
            maturity    = 'experimental'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-experimental.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: stable' {
        $manifest = [ordered]@{
            id          = 'test-maturity-stable'
            name        = 'Test'
            description = 'Tests stable maturity'
            maturity    = 'stable'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-stable.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: preview' {
        $manifest = [ordered]@{
            id          = 'test-maturity-preview'
            name        = 'Test'
            description = 'Tests preview maturity'
            maturity    = 'preview'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-preview.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: deprecated' {
        $manifest = [ordered]@{
            id          = 'test-maturity-deprecated'
            name        = 'Test'
            description = 'Tests deprecated maturity'
            maturity    = 'deprecated'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-deprecated.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Fails validation for collection with invalid maturity: beta' {
        $manifest = [ordered]@{
            id          = 'test-maturity-beta'
            name        = 'Test'
            description = 'Tests invalid maturity'
            maturity    = 'beta'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-beta.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for collection with omitted maturity' {
        $manifest = [ordered]@{
            id          = 'test-maturity-omitted'
            name        = 'Test'
            description = 'Tests omitted maturity'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/test.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'test-maturity-omitted.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }
}

Describe 'Invoke-CollectionValidation - error paths' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'error-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Create valid artifacts for reference
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---\ndescription: agent a\n---'
        Set-Content -Path (Join-Path $agentsDir 'b.agent.md') -Value '---\ndescription: agent b\n---'

        $instrDir = Join-Path $script:repoRoot '.github/instructions/test'
        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        Set-Content -Path (Join-Path $instrDir 'test.instructions.md') -Value '---\ndescription: test\n---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Returns success with zero collections when directory is empty' {
        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.CollectionCount | Should -Be 0
    }

    It 'Fails when required field is missing' {
        $yaml = @"
name: No ID Collection
description: Missing id field
items:
  - path: .github/agents/test/a.agent.md
    kind: agent
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'no-id.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for invalid id format' {
        $manifest = [ordered]@{
            id          = 'INVALID_ID!'
            name        = 'Bad ID'
            description = 'Invalid id format'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'bad-id.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for duplicate ids across collections' {
        $manifest = [ordered]@{
            id          = 'dup-id'
            name        = 'First'
            description = 'First collection'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'dup1.collection.yml') -Value $yaml
        Set-Content -Path (Join-Path $script:collectionsDir 'dup2.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails when item path does not exist' {
        $manifest = [ordered]@{
            id          = 'missing-path'
            name        = 'Missing'
            description = 'Item path missing'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/nonexistent.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'missing-path.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails when item has no kind' {
        $yaml = @"
id: no-kind
name: No Kind
description: Item missing kind
items:
  - path: .github/agents/test/a.agent.md
"@
        Set-Content -Path (Join-Path $script:collectionsDir 'no-kind.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for invalid item maturity' {
        $manifest = [ordered]@{
            id          = 'bad-item-mat'
            name        = 'Bad Item Maturity'
            description = 'Item with invalid maturity'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'alpha'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'bad-item-mat.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for kind-suffix mismatch' {
        $manifest = [ordered]@{
            id          = 'suffix-mismatch'
            name        = 'Suffix Mismatch'
            description = 'Agent path with wrong suffix'
            items       = @(
                [ordered]@{
                    path = '.github/instructions/test/test.instructions.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'suffix-mismatch.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Fails for instruction kind with wrong suffix' {
        $manifest = [ordered]@{
            id          = 'instr-suffix'
            name        = 'Instruction Suffix'
            description = 'Instruction item with agent suffix'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'instruction'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'instr-suffix.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects duplicate artifact keys at distinct paths' {
        # Two agents at different paths that resolve to the same artifact key
        $agentsDir2 = Join-Path $script:repoRoot '.github/agents/other'
        New-Item -ItemType Directory -Path $agentsDir2 -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir2 'a.agent.md') -Value '---\ndescription: same name\n---'

        $manifest = [ordered]@{
            id          = 'dup-artifact'
            name        = 'Dup Artifact'
            description = 'Same artifact key from different paths'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                },
                [ordered]@{
                    path = '.github/agents/other/a.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml = ConvertTo-Yaml -Data $manifest
        Set-Content -Path (Join-Path $script:collectionsDir 'dup-artifact.collection.yml') -Value $yaml

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects shared item missing canonical entry' {
        # Two collections share the same item but neither is hve-core-all
        $manifest1 = [ordered]@{
            id          = 'share-one'
            name        = 'Share One'
            description = 'First sharer'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                }
            )
        }
        $manifest2 = [ordered]@{
            id          = 'share-two'
            name        = 'Share Two'
            description = 'Second sharer'
            items       = @(
                [ordered]@{
                    path = '.github/agents/test/a.agent.md'
                    kind = 'agent'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $manifest1
        $yaml2 = ConvertTo-Yaml -Data $manifest2
        Set-Content -Path (Join-Path $script:collectionsDir 'share-one.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'share-two.collection.yml') -Value $yaml2

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects maturity conflict with canonical collection' {
        # hve-core-all has the item as stable, another collection has it as experimental
        $canonical = [ordered]@{
            id          = 'hve-core-all'
            name        = 'All'
            description = 'Canonical collection'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'stable'
                }
            )
        }
        $other = [ordered]@{
            id          = 'conflict-col'
            name        = 'Conflict'
            description = 'Conflicting maturity'
            items       = @(
                [ordered]@{
                    path     = '.github/agents/test/a.agent.md'
                    kind     = 'agent'
                    maturity = 'experimental'
                }
            )
        }
        $yaml1 = ConvertTo-Yaml -Data $canonical
        $yaml2 = ConvertTo-Yaml -Data $other
        Set-Content -Path (Join-Path $script:collectionsDir 'hve-core-all.collection.yml') -Value $yaml1
        Set-Content -Path (Join-Path $script:collectionsDir 'conflict-col.collection.yml') -Value $yaml2

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }
}
