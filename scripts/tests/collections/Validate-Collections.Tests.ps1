#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../collections/Validate-Collections.ps1

    # Builds a collections/core-manifest.yml fixture from collection-intent hashtables.
    # The rewritten validator reads only core-manifest.yml and projects per-collection
    # manifests via ConvertTo-CollectionManifestFromCore, so tests express their intent
    # as central-manifest data rather than committed .collection.yml files.
    #
    # Each input collection: @{ id; name; descriptions=@(@{channel;text});
    #   maturity?(scalar); notice?; tags?; display?; items=@(@{path;kind;maturity}) }
    # Artifacts are keyed by path within their kind section; a path shared across
    # multiple input collections merges into a single entry whose collections[] lists
    # every owning id.
    function global:New-CoreManifestFixture {
        param(
            [Parameter(Mandatory)] [string]$CollectionsDir,
            [AllowEmptyCollection()] [object[]]$Collections = @()
        )

        Import-Module PowerShell-Yaml -ErrorAction Stop

        $sectionForKind = @{
            agent       = 'agents'
            prompt      = 'prompts'
            instruction = 'instructions'
            skill       = 'skills'
        }

        $collectionsMap = [ordered]@{}
        $sections = [ordered]@{
            agents       = [ordered]@{}
            prompts      = [ordered]@{}
            instructions = [ordered]@{}
            skills       = [ordered]@{}
        }

        foreach ($collection in $Collections) {
            $id = [string]$collection.id

            $meta = [ordered]@{ name = [string]$collection.name }
            if ($collection.Contains('descriptions') -and $null -ne $collection.descriptions) {
                $meta['descriptions'] = @($collection.descriptions | ForEach-Object {
                        [ordered]@{ channel = [string]$_.channel; text = [string]$_.text }
                    })
            }
            if ($collection.Contains('maturity') -and $collection.maturity) {
                $meta['maturity'] = [string]$collection.maturity
            }
            if ($collection.Contains('notice') -and $collection.notice) {
                $meta['notice'] = [string]$collection.notice
            }
            if ($collection.Contains('tags') -and $null -ne $collection.tags) {
                $meta['tags'] = @($collection.tags)
            }
            if ($collection.Contains('display') -and $null -ne $collection.display) {
                $meta['display'] = $collection.display
            }
            $collectionsMap[$id] = $meta

            if ($collection.Contains('items') -and $null -ne $collection.items) {
                foreach ($item in $collection.items) {
                    $kind = [string]$item.kind
                    $section = $sectionForKind[$kind]
                    if (-not $section) { throw "Unknown item kind '$kind' in fixture." }
                    $path = [string]$item.path

                    if ($sections[$section].Contains($path)) {
                        $entry = $sections[$section][$path]
                        if ($entry.collections -notcontains $id) {
                            $entry.collections = @($entry.collections) + $id
                        }
                    }
                    else {
                        $sections[$section][$path] = [ordered]@{
                            path        = $path
                            maturity    = [string]$item.maturity
                            collections = @($id)
                        }
                    }
                }
            }
        }

        $manifest = [ordered]@{
            schemaVersion = '1.0'
            collections   = $collectionsMap
            agents        = $sections.agents
            prompts       = $sections.prompts
            instructions  = $sections.instructions
            skills        = $sections.skills
        }

        if (-not (Test-Path -Path $CollectionsDir)) {
            New-Item -ItemType Directory -Path $CollectionsDir -Force | Out-Null
        }
        $manifestPath = Join-Path $CollectionsDir 'core-manifest.yml'
        Set-Content -Path $manifestPath -Value (ConvertTo-Yaml -Data $manifest) -Force
        return $manifestPath
    }
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
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-reject-instr'; name = 'Test Reject Instruction'
                descriptions = @(@{ channel = 'stable'; text = 'Tests repo-specific instruction rejection' })
                items = @(@{ path = '.github/instructions/workflows.instructions.md'; kind = 'instruction'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for instruction in subdirectory' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-allow-location'; name = 'Test Allow Location'
                descriptions = @(@{ channel = 'stable'; text = 'Tests that subdirectory instructions are allowed' })
                items = @(@{ path = '.github/instructions/shared/hve-core-location.instructions.md'; kind = 'instruction'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Fails validation for root-level agent' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-reject-agent'; name = 'Test Reject Agent'
                descriptions = @(@{ channel = 'stable'; text = 'Tests repo-specific agent rejection' })
                items = @(@{ path = '.github/agents/internal.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for agent in subdirectory' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-allow-agent'; name = 'Test Allow Agent'
                descriptions = @(@{ channel = 'stable'; text = 'Tests that subdirectory agents pass' })
                items = @(@{ path = '.github/agents/hve-core/rpi-agent.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

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
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test(exp)`ndescription: test agent`n---"
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-maturity-experimental'; name = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'Tests experimental maturity' })
                maturity = 'experimental'
                items = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'experimental' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: stable' {
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-maturity-stable'; name = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'Tests stable maturity' })
                maturity = 'stable'
                items = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: preview' {
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test(pre)`ndescription: test agent`n---"
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-maturity-preview'; name = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'Tests preview maturity' })
                maturity = 'preview'
                items = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'preview' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Passes validation for collection with maturity: deprecated' {
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-maturity-deprecated'; name = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'Tests deprecated maturity' })
                maturity = 'deprecated'
                items = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    It 'Fails validation for collection with invalid maturity: beta' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-maturity-beta'; name = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'Tests invalid maturity' })
                maturity = 'beta'
                items = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes validation for collection with omitted maturity' {
        Set-Content -Path (Join-Path $script:repoRoot '.github/agents/test/test.agent.md') -Value "---`nname: Test`ndescription: test agent`n---"
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'test-maturity-omitted'; name = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'Tests omitted maturity' })
                items = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }
}

Describe 'Invoke-CollectionValidation - collection-to-folder name consistency' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'folder-consistency-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Matching folder structure
        $matchDir = Join-Path $script:repoRoot '.github/agents/my-collection'
        New-Item -ItemType Directory -Path $matchDir -Force | Out-Null
        Set-Content -Path (Join-Path $matchDir 'match.agent.md') -Value '---\ndescription: matching agent\n---'

        # Mismatched folder structure
        $mismatchDir = Join-Path $script:repoRoot '.github/agents/wrong-folder'
        New-Item -ItemType Directory -Path $mismatchDir -Force | Out-Null
        Set-Content -Path (Join-Path $mismatchDir 'mismatch.agent.md') -Value '---\ndescription: mismatched agent\n---'

        # Shared folder structure
        $sharedDir = Join-Path $script:repoRoot '.github/instructions/shared'
        New-Item -ItemType Directory -Path $sharedDir -Force | Out-Null
        Set-Content -Path (Join-Path $sharedDir 'shared.instructions.md') -Value '---\ndescription: shared instruction\n---'

        # rai-planning sub-domain folder structure (shared across themed collections)
        $raiPlanningDir = Join-Path $script:repoRoot '.github/instructions/rai-planning'
        New-Item -ItemType Directory -Path $raiPlanningDir -Force | Out-Null
        Set-Content -Path (Join-Path $raiPlanningDir 'rai.instructions.md') -Value '---\ndescription: rai-planning instruction\n---'

        # hve-core folder structure (cross-collection reference allowed without warning)
        $hveCoreDir = Join-Path $script:repoRoot '.github/agents/hve-core'
        New-Item -ItemType Directory -Path $hveCoreDir -Force | Out-Null
        Set-Content -Path (Join-Path $hveCoreDir 'core.agent.md') -Value '---\ndescription: hve-core agent\n---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Passes when collection-id matches folder name' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'my-collection'; name = 'My Collection'
                descriptions = @(@{ channel = 'stable'; text = 'Collection with matching folder' })
                items = @(@{ path = '.github/agents/my-collection/match.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection.*my-collection'
        }
    }

    It 'Warns but does not fail when collection-id does not match folder name' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'my-collection'; name = 'My Collection'
                descriptions = @(@{ channel = 'stable'; text = 'Collection with mismatched folder' })
                items = @(@{ path = '.github/agents/wrong-folder/mismatch.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection.*wrong-folder'
        }
    }

    It 'Allows items from hve-core/ folder in any collection' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'my-collection'; name = 'My Collection'
                descriptions = @(@{ channel = 'stable'; text = 'Collection referencing hve-core item' })
                items = @(@{ path = '.github/agents/hve-core/core.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core'; name = 'HVE Core'
                descriptions = @(@{ channel = 'stable'; text = 'HVE Core collection' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Allows items from shared/ folder in any collection' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'my-collection'; name = 'My Collection'
                descriptions = @(@{ channel = 'stable'; text = 'Collection referencing shared item' })
                items = @(@{ path = '.github/instructions/shared/shared.instructions.md'; kind = 'instruction'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Allows items from rai-planning/ folder in any collection' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'my-collection'; name = 'My Collection'
                descriptions = @(@{ channel = 'stable'; text = 'Collection referencing rai-planning item' })
                items = @(@{ path = '.github/instructions/rai-planning/rai.instructions.md'; kind = 'instruction'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Allows hve-core-all to reference items from any folder' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'hve-core-all'; name = 'HVE Core All'
                descriptions = @(@{ channel = 'stable'; text = 'Aggregate collection' })
                items = @(
                    @{ path = '.github/agents/my-collection/match.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/wrong-folder/mismatch.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/instructions/shared/shared.instructions.md'; kind = 'instruction'; maturity = 'stable' },
                    @{ path = '.github/instructions/rai-planning/rai.instructions.md'; kind = 'instruction'; maturity = 'stable' },
                    @{ path = '.github/agents/hve-core/core.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Not -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection'
        }
    }

    It 'Emits warning output for mismatched folder name without failing' {
        Mock Write-Host {}

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'my-collection'; name = 'My Collection'
                descriptions = @(@{ channel = 'stable'; text = 'Mismatch for warning output test' })
                items = @(@{ path = '.github/agents/wrong-folder/mismatch.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        # Advisory warning uses Write-Host WARN; validation still passes
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
        Should -Invoke Write-Host -ParameterFilter {
            $Object -match 'WARN collection.*wrong-folder'
        }
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

    It 'Returns success with zero collections when manifest defines none' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @() | Out-Null

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.CollectionCount | Should -Be 0
    }

    It 'Fails when item path does not exist' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'missing-path'; name = 'Missing'
                descriptions = @(@{ channel = 'stable'; text = 'Item path missing' })
                items = @(@{ path = '.github/agents/test/nonexistent.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects duplicate artifact keys at distinct paths' {
        # Two agents at different paths that resolve to the same artifact key
        $agentsDir2 = Join-Path $script:repoRoot '.github/agents/other'
        New-Item -ItemType Directory -Path $agentsDir2 -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir2 'a.agent.md') -Value '---\ndescription: same name\n---'

        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'dup-artifact'; name = 'Dup Artifact'
                descriptions = @(@{ channel = 'stable'; text = 'Same artifact key from different paths' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/other/a.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }

    It 'Detects shared item missing canonical entry' {
        # Two collections share the same item but neither is hve-core-all;
        # hve-core-all exists but does not include a.agent.md - Check 4 fires.
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'share-one'; name = 'Share One'
                descriptions = @(@{ channel = 'stable'; text = 'First sharer' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'share-two'; name = 'Share Two'
                descriptions = @(@{ channel = 'stable'; text = 'Second sharer' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical - missing a.agent.md' })
                items = @(
                    @{ path = '.github/agents/test/b.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/instructions/test/test.instructions.md'; kind = 'instruction'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
    }
}

Describe 'Invoke-CollectionValidation - new checks' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'new-checks-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'

        # Standard artifact - used by most tests
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---' -Force

        # Orphan artifact - on disk but not necessarily in manifests
        $orphanDir = Join-Path $script:repoRoot '.github/agents/orphan'
        New-Item -ItemType Directory -Path $orphanDir -Force | Out-Null
        Set-Content -Path (Join-Path $orphanDir 'orphan.agent.md') -Value '---' -Force
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) { Remove-Item -Path $script:collectionsDir -Recurse -Force }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null

        # Reset agent dirs to pristine state - prevents artifact leakage between tests
        $agentsBaseDir = Join-Path $script:repoRoot '.github/agents'
        if (Test-Path $agentsBaseDir) { Remove-Item -Path $agentsBaseDir -Recurse -Force }
        New-Item -ItemType Directory -Path (Join-Path $agentsBaseDir 'test') -Force | Out-Null
        Set-Content -Path (Join-Path $agentsBaseDir 'test/a.agent.md') -Value '---' -Force
        New-Item -ItemType Directory -Path (Join-Path $agentsBaseDir 'orphan') -Force | Out-Null
        Set-Content -Path (Join-Path $agentsBaseDir 'orphan/orphan.agent.md') -Value '---' -Force
    }

    # Check 4: hve-core-all coverage

    It 'Fails when a themed collection item is absent from hve-core-all' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'themed-only'; name = 'Themed Only'
                descriptions = @(@{ channel = 'stable'; text = 'Item not in hve-core-all' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                # Canonical exists but does NOT include a.agent.md - only orphan - so Check 4 fires
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical - missing themed item' })
                items = @(@{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Passes when all themed items are present in hve-core-all' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'themed-covered'; name = 'Themed Covered'
                descriptions = @(@{ channel = 'stable'; text = 'Covered by canonical' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
    }

    # Check 1: orphan detection

    It 'Fails when an on-disk artifact is absent from hve-core-all' {
        # manifest and canonical cover a.agent.md but NOT orphan/orphan.agent.md
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'partial-coverage'; name = 'Partial'
                descriptions = @(@{ channel = 'stable'; text = 'Missing orphan' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical - missing orphan' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeFalse
        $result.ErrorCount | Should -BeGreaterOrEqual 1
    }

    It 'Warns but passes when artifact is in hve-core-all but not in any themed collection' {
        # Themed covers only a.agent.md; canonical covers both - orphan is canonical-only
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'themed-partial'; name = 'Themed Partial'
                descriptions = @(@{ channel = 'stable'; text = 'Missing orphan in themed' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical - covers orphan' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }
}

Describe 'Invoke-CollectionValidation - marker validation' -Tag 'Unit' {
    BeforeAll {
        $script:repoRoot = Join-Path $TestDrive 'marker-validation'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        # Create artifact directories
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---' -Force
        $orphanDir = Join-Path $script:repoRoot '.github/agents/orphan'
        New-Item -ItemType Directory -Path $orphanDir -Force | Out-Null
        Set-Content -Path (Join-Path $orphanDir 'orphan.agent.md') -Value '---' -Force
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Passes with well-formed auto-generation markers in the projected README body' {
        # The validator no longer reads committed .collection.md files; it validates the
        # README body projected from core-manifest.yml, which always emits a matched,
        # correctly ordered BEGIN/END AUTO-GENERATED ARTIFACTS marker pair.
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'valid-markers'; name = 'Valid Markers'
                descriptions = @(@{ channel = 'stable'; text = 'Matched markers' })
                items = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $result.Success | Should -BeTrue
        $result.ErrorCount | Should -Be 0
    }
}

Describe 'Collection validation JSON reporting' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop
        $script:repoRoot = Join-Path $TestDrive 'json-reporting-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'a.agent.md') -Value '---' -Force
        $orphanDir = Join-Path $script:repoRoot '.github/agents/orphan'
        New-Item -ItemType Directory -Path $orphanDir -Force | Out-Null
        Set-Content -Path (Join-Path $orphanDir 'orphan.agent.md') -Value '---' -Force
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Exports JSON report with expected schema' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $outputPath = Join-Path $TestDrive 'collection-validation-results.json'
        Export-CollectionValidationReport -ValidationResult $result -OutputPath $outputPath
        $report = Get-Content -Path $outputPath -Raw | ConvertFrom-Json

        $report.Timestamp | Should -Not -BeNullOrEmpty
        $report.TotalCollections | Should -Be 1
        $report.ErrorCount | Should -Be 0
        $report.PSObject.Properties.Name | Should -Contain 'Results'
        $report.Results | ForEach-Object {
            $_.PSObject.Properties.Name | Should -Contain 'Collection'
            $_.PSObject.Properties.Name | Should -Contain 'Severity'
            $_.PSObject.Properties.Name | Should -Contain 'ErrorType'
            $_.PSObject.Properties.Name | Should -Contain 'Message'
        }
    }

    It 'Differentiates Severity between warnings and errors in results' {
        # PathNotFound (Error) from a themed collection referencing a missing file,
        # alongside CanonicalOnlyArtifact (Warning) from an artifact present only in
        # the canonical collection.
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'themed'; name = 'Themed'
                descriptions = @(@{ channel = 'stable'; text = 'Has a path-not-found error' })
                items = @(@{ path = '.github/agents/test/nonexistent.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical' })
                items = @(
                    @{ path = '.github/agents/test/nonexistent.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $errors = @($result.Results | Where-Object { $_.Severity -eq 'Error' })
        $warnings = @($result.Results | Where-Object { $_.Severity -eq 'Warning' })

        $errors | Should -Not -BeNullOrEmpty
        $warnings | Should -Not -BeNullOrEmpty
        $errors | Where-Object { $_.ErrorType -eq 'PathNotFound' } | Should -Not -BeNullOrEmpty
        $warnings | Where-Object { $_.ErrorType -eq 'CanonicalOnlyArtifact' } | Should -Not -BeNullOrEmpty
    }

    It 'Creates output directory when it does not exist' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot
        $newDir = Join-Path $TestDrive 'nonexistent-logs-dir'
        $outputPath = Join-Path $newDir 'results.json'

        Test-Path $newDir | Should -BeFalse
        Export-CollectionValidationReport -ValidationResult $result -OutputPath $outputPath
        Test-Path $newDir | Should -BeTrue
        Test-Path $outputPath | Should -BeTrue
    }

    It 'Captures multiple distinct ErrorType values in a single run' {
        # PathNotFound from a missing themed file, plus OrphanArtifact from an on-disk
        # agent that is absent from the canonical collection.
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'themed'; name = 'Themed'
                descriptions = @(@{ channel = 'stable'; text = 'Has a path-not-found error' })
                items = @(@{ path = '.github/agents/test/nonexistent.agent.md'; kind = 'agent'; maturity = 'stable' })
            },
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical missing the orphan' })
                items = @(
                    @{ path = '.github/agents/test/nonexistent.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        $errorTypes = $result.Results | Select-Object -ExpandProperty ErrorType
        $errorTypes | Should -Contain 'PathNotFound'
        $errorTypes | Should -Contain 'OrphanArtifact'
    }

    It 'Returns a Results key even when a collection passes validation' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id = 'hve-core-all'; name = 'All'
                descriptions = @(@{ channel = 'stable'; text = 'Canonical' })
                items = @(
                    @{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = 'stable' },
                    @{ path = '.github/agents/orphan/orphan.agent.md'; kind = 'agent'; maturity = 'stable' }
                )
            }
        )

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeTrue
        $result.Keys | Should -Contain 'Results'
    }
}

Describe 'Invoke-CollectionValidation - AgentMaturityLabelMismatch diagnostic' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'maturity-label-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $script:agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        function script:Set-AgentFrontmatter {
            param(
                [Parameter(Mandatory)] [string]$Name,
                [switch]$OmitName
            )
            $path = Join-Path $script:agentsDir 'a.agent.md'
            if ($OmitName) {
                Set-Content -Path $path -Value "---`ndescription: test agent`n---"
            } else {
                Set-Content -Path $path -Value "---`nname: $Name`ndescription: test agent`n---"
            }
        }

        function script:Set-CollectionManifest {
            param(
                [Parameter(Mandatory)] [string]$Id,
                [string]$Maturity,
                [string]$ItemMaturity
            )
            $itemMat = if ($ItemMaturity) { $ItemMaturity } elseif ($Maturity) { $Maturity } else { 'stable' }
            $collection = @{
                id           = $Id
                name         = 'Test'
                descriptions = @(@{ channel = 'stable'; text = 'maturity label test' })
                items        = @(@{ path = '.github/agents/test/a.agent.md'; kind = 'agent'; maturity = $itemMat })
            }
            if ($Maturity) { $collection['maturity'] = $Maturity }
            New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @($collection) | Out-Null
        }
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    # --- Step 2.1 positive cases ---

    It 'Fires AgentMaturityLabelMismatch for experimental agent missing (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test'
        Set-CollectionManifest -Id 'exp-missing' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $mismatches = @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' })
        $mismatches.Count | Should -BeGreaterOrEqual 1
    }

    It 'Does not fire AgentMaturityLabelMismatch for experimental agent with (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test(exp)'
        Set-CollectionManifest -Id 'exp-ok' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    It 'Fires AgentMaturityLabelMismatch for preview agent missing (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test'
        Set-CollectionManifest -Id 'pre-missing' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Does not fire AgentMaturityLabelMismatch for preview agent with (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'pre-ok' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    It 'Does not fire AgentMaturityLabelMismatch for stable agent without suffix' {
        Set-AgentFrontmatter -Name 'Test'
        Set-CollectionManifest -Id 'stable-ok' -Maturity 'stable'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    It 'Item-level maturity overrides collection-level when validating suffix' {
        # Collection is stable but item override is preview -> requires (pre) suffix
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'override-ok' -Maturity 'stable' -ItemMaturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -Be 0
    }

    # --- Step 2.2 negative cases ---

    It 'Fires AgentMaturityLabelMismatch for experimental agent with wrong (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'exp-wrong' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for preview agent with wrong (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test(exp)'
        Set-CollectionManifest -Id 'pre-wrong' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for experimental agent with obsolete (Experimental) full word' {
        Set-AgentFrontmatter -Name 'Test(Experimental)'
        Set-CollectionManifest -Id 'exp-fullword' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for preview agent with obsolete (Preview) full word' {
        Set-AgentFrontmatter -Name 'Test(Preview)'
        Set-CollectionManifest -Id 'pre-fullword' -Maturity 'preview'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for stable agent with stale (exp) suffix' {
        Set-AgentFrontmatter -Name 'Test(exp)'
        Set-CollectionManifest -Id 'stable-stale-exp' -Maturity 'stable'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for stable agent with stale (pre) suffix' {
        Set-AgentFrontmatter -Name 'Test(pre)'
        Set-CollectionManifest -Id 'stable-stale-pre' -Maturity 'stable'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch for agent name ending with stacked (exp)(pre)' {
        Set-AgentFrontmatter -Name 'Test(exp)(pre)'
        Set-CollectionManifest -Id 'stacked' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }

    It 'Fires AgentMaturityLabelMismatch when name field is missing on non-stable agent' {
        Set-AgentFrontmatter -OmitName -Name 'unused'
        Set-CollectionManifest -Id 'missing-name' -Maturity 'experimental'

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'AgentMaturityLabelMismatch' }).Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Invoke-CollectionValidation - MissingPrereleaseDescription diagnostic' {
    BeforeAll {
        Import-Module PowerShell-Yaml -ErrorAction Stop

        $script:repoRoot = Join-Path $TestDrive 'missing-prerelease-desc-repo'
        $script:collectionsDir = Join-Path $script:repoRoot 'collections'
        $agentsDir = Join-Path $script:repoRoot '.github/agents/test'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -Path (Join-Path $agentsDir 'test.agent.md') -Value '---'
    }

    BeforeEach {
        if (Test-Path $script:collectionsDir) {
            Remove-Item -Path $script:collectionsDir -Recurse -Force
        }
        New-Item -ItemType Directory -Path $script:collectionsDir -Force | Out-Null
    }

    It 'Does not fire MissingPrereleaseDescription when descriptions.prerelease is populated' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id           = 'test-has-prerelease'
                name         = 'Test'
                maturity     = 'experimental'
                descriptions = @(
                    @{ channel = 'stable'; text = 'Stable description' },
                    @{ channel = 'prerelease'; text = 'Experimental: pre-release description' }
                )
                items        = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'experimental' })
            }
        ) | Out-Null

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        @($result.Results | Where-Object { $_.ErrorType -eq 'MissingPrereleaseDescription' }).Count | Should -Be 0
    }

    It 'Fires MissingPrereleaseDescription as a Warning when no prerelease entry is present' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id           = 'test-missing-descriptions'
                name         = 'Test'
                maturity     = 'experimental'
                descriptions = @(@{ channel = 'stable'; text = 'Tests missing prerelease entry' })
                items        = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'experimental' })
            }
        ) | Out-Null

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $warnings = @($result.Results | Where-Object { $_.ErrorType -eq 'MissingPrereleaseDescription' })
        $warnings.Count | Should -BeGreaterOrEqual 1
        $warnings[0].Severity | Should -Be 'Warning'
    }

    It 'Fires InvalidDescriptions when a prerelease entry text is whitespace-only' {
        New-CoreManifestFixture -CollectionsDir $script:collectionsDir -Collections @(
            @{
                id           = 'test-whitespace-prerelease'
                name         = 'Test'
                maturity     = 'experimental'
                descriptions = @(
                    @{ channel = 'stable'; text = 'Stable description' },
                    @{ channel = 'prerelease'; text = '   ' }
                )
                items        = @(@{ path = '.github/agents/test/test.agent.md'; kind = 'agent'; maturity = 'experimental' })
            }
        ) | Out-Null

        $result = Invoke-CollectionValidation -RepoRoot $script:repoRoot

        $result.Success | Should -BeFalse
        @($result.Results | Where-Object { $_.ErrorType -eq 'InvalidDescriptions' }).Count | Should -BeGreaterOrEqual 1
    }
}
