#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../extension/Prepare-Extension.ps1
}

Describe 'Get-AllowedMaturities' {
    It 'Returns only stable for Stable channel' {
        $result = Get-AllowedMaturities -Channel 'Stable'
        $result | Should -Be @('stable')
    }

    It 'Returns all maturities for PreRelease channel' {
        $result = Get-AllowedMaturities -Channel 'PreRelease'
        $result | Should -Contain 'stable'
        $result | Should -Contain 'preview'
        $result | Should -Contain 'experimental'
    }

}

Describe 'Test-CollectionMaturityEligible' {
    It 'Returns eligible for stable collection on Stable channel' {
        $manifest = @{ id = 'test'; maturity = 'stable' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
        $result.Reason | Should -BeNullOrEmpty
    }

    It 'Returns eligible for stable collection on PreRelease channel' {
        $manifest = @{ id = 'test'; maturity = 'stable' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns eligible for preview collection on Stable channel' {
        $manifest = @{ id = 'test'; maturity = 'preview' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns eligible for preview collection on PreRelease channel' {
        $manifest = @{ id = 'test'; maturity = 'preview' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns ineligible for experimental collection on Stable channel' {
        $manifest = @{ id = 'exp-coll'; maturity = 'experimental' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'experimental.*excluded from Stable'
    }

    It 'Returns eligible for experimental collection on PreRelease channel' {
        $manifest = @{ id = 'exp-coll'; maturity = 'experimental' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns ineligible for deprecated collection on Stable channel' {
        $manifest = @{ id = 'old-coll'; maturity = 'deprecated' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'deprecated.*excluded from all channels'
    }

    It 'Returns ineligible for deprecated collection on PreRelease channel' {
        $manifest = @{ id = 'old-coll'; maturity = 'deprecated' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'deprecated.*excluded from all channels'
    }

    It 'Defaults to stable when maturity key is absent' {
        $manifest = @{ id = 'no-maturity' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
    }

    It 'Defaults to stable when maturity value is empty string' {
        $manifest = @{ id = 'empty-maturity'; maturity = '' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.IsEligible | Should -BeTrue
    }

    It 'Returns ineligible for unknown maturity value' {
        $manifest = @{ id = 'bad-coll'; maturity = 'alpha' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'PreRelease'
        $result.IsEligible | Should -BeFalse
        $result.Reason | Should -Match 'invalid maturity value'
    }

    It 'Returns hashtable with expected keys' {
        $manifest = @{ id = 'test'; maturity = 'stable' }
        $result = Test-CollectionMaturityEligible -CollectionManifest $manifest -Channel 'Stable'
        $result.Keys | Should -Contain 'IsEligible'
        $result.Keys | Should -Contain 'Reason'
    }
}

Describe 'Test-PathsExist' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
        $script:extDir = Join-Path $script:tempDir 'extension'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null
        $script:pkgJson = Join-Path $script:extDir 'package.json'
        '{}' | Set-Content -Path $script:pkgJson
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns valid when all paths exist' {
        $result = Test-PathsExist -ExtensionDir $script:extDir -PackageJsonPath $script:pkgJson -GitHubDir $script:ghDir
        $result.IsValid | Should -BeTrue
        $result.MissingPaths | Should -BeNullOrEmpty
    }

    It 'Returns invalid when extension dir missing' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-ext-dir-12345')
        $result = Test-PathsExist -ExtensionDir $nonexistentPath -PackageJsonPath $script:pkgJson -GitHubDir $script:ghDir
        $result.IsValid | Should -BeFalse
        $result.MissingPaths | Should -Contain $nonexistentPath
    }

    It 'Collects multiple missing paths' {
        $missing1 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-1')
        $missing2 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-2')
        $missing3 = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'missing-path-3')
        $result = Test-PathsExist -ExtensionDir $missing1 -PackageJsonPath $missing2 -GitHubDir $missing3
        $result.IsValid | Should -BeFalse
        $result.MissingPaths.Count | Should -Be 3
    }
}

Describe 'Get-DiscoveredAgents' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Create test agent files
        @'
---
description: "Stable agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'stable.agent.md')

        @'
---
description: "Preview agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'preview.agent.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers agents matching allowed maturities' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @()
        $result.DirectoryExists | Should -BeTrue
        $result.Agents.Count | Should -Be 2
    }

    It 'Filters agents by maturity' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('preview') -ExcludedAgents @()
        $result.Agents.Count | Should -Be 0
        $result.Skipped.Count | Should -Be 2
    }

    It 'Excludes specified agents' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @('stable')
        $result.Agents.Count | Should -Be 1
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-agents-dir-12345')
        $result = Get-DiscoveredAgents -AgentsDir $nonexistentPath -AllowedMaturities @('stable') -ExcludedAgents @()
        $result.DirectoryExists | Should -BeFalse
        $result.Agents | Should -BeNullOrEmpty
    }
}

Describe 'Get-DiscoveredPrompts' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:promptsDir = Join-Path $script:tempDir 'prompts'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:promptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test prompt"
---
'@ | Set-Content -Path (Join-Path $script:promptsDir 'test.prompt.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers prompts in directory' {
        $result = Get-DiscoveredPrompts -PromptsDir $script:promptsDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Prompts.Count | Should -BeGreaterThan 0
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-prompts-dir-12345')
        $result = Get-DiscoveredPrompts -PromptsDir $nonexistentPath -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
    }
}

Describe 'Get-DiscoveredInstructions' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:instrDir = Join-Path $script:tempDir 'instructions'
        $script:ghDir = Join-Path $script:tempDir '.github'
        New-Item -ItemType Directory -Path $script:instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:ghDir -Force | Out-Null

        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'test.instructions.md')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers instructions in directory' {
        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Instructions.Count | Should -BeGreaterThan 0
    }

    It 'Returns empty when directory does not exist' {
        $nonexistentPath = [System.IO.Path]::Combine([System.IO.Path]::GetTempPath(), 'nonexistent-instr-dir-12345')
        $result = Get-DiscoveredInstructions -InstructionsDir $nonexistentPath -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
    }

    It 'Skips repo-specific instructions in hve-core subdirectory' {
        $hveCoreDir = Join-Path $script:instrDir 'hve-core'
        New-Item -ItemType Directory -Path $hveCoreDir -Force | Out-Null
        @'
---
description: "Repo-specific workflow instruction"
applyTo: "**/.github/workflows/*.yml"
---
'@ | Set-Content -Path (Join-Path $hveCoreDir 'workflows.instructions.md')

        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $instrNames = $result.Instructions | ForEach-Object { $_.name }
        $instrNames | Should -Not -Contain 'workflows-instructions'
        $result.Skipped | Where-Object { $_.Reason -match 'repo-specific' } | Should -Not -BeNullOrEmpty
    }

    It 'Still discovers instructions in other subdirectories' {
        $hveCoreDir = Join-Path $script:instrDir 'hve-core'
        $otherDir = Join-Path $script:instrDir 'csharp'
        New-Item -ItemType Directory -Path $hveCoreDir -Force | Out-Null
        New-Item -ItemType Directory -Path $otherDir -Force | Out-Null
        @'
---
description: "Repo-specific"
applyTo: "**/.github/workflows/*.yml"
---
'@ | Set-Content -Path (Join-Path $hveCoreDir 'workflows.instructions.md')
        @'
---
description: "C# instruction"
applyTo: "**/*.cs"
---
'@ | Set-Content -Path (Join-Path $otherDir 'csharp.instructions.md')

        $result = Get-DiscoveredInstructions -InstructionsDir $script:instrDir -GitHubDir $script:ghDir -AllowedMaturities @('stable')
        $instrNames = $result.Instructions | ForEach-Object { $_.name }
        $instrNames | Should -Contain 'csharp-instructions'
        $instrNames | Should -Not -Contain 'workflows-instructions'
    }
}

Describe 'Get-DiscoveredSkills' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:skillsDir = Join-Path $script:tempDir 'skills'
        New-Item -ItemType Directory -Path $script:skillsDir -Force | Out-Null

        # Create test skill
        $skillDir = Join-Path $script:skillsDir 'test-skill'
        New-Item -ItemType Directory -Path $skillDir -Force | Out-Null
        @'
---
name: test-skill
description: "Test skill"
---
# Skill
'@ | Set-Content -Path (Join-Path $skillDir 'SKILL.md')

        # Create empty skill directory (no SKILL.md)
        $emptySkillDir = Join-Path $script:skillsDir 'empty-skill'
        New-Item -ItemType Directory -Path $emptySkillDir -Force | Out-Null

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers skills in directory' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeTrue
        $result.Skills.Count | Should -Be 1
        $result.Skills[0].name | Should -Be 'test-skill'
    }

    It 'Returns empty when directory does not exist' {
        $nonexistent = Join-Path $script:tempDir 'nonexistent-skills'
        $result = Get-DiscoveredSkills -SkillsDir $nonexistent -AllowedMaturities @('stable')
        $result.DirectoryExists | Should -BeFalse
        $result.Skills | Should -BeNullOrEmpty
    }

    It 'Filters skills when stable is not an allowed maturity' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('preview')
        $result.Skills.Count | Should -Be 0
        $result.Skipped.Count | Should -BeGreaterThan 0
    }

    It 'Skips directories without SKILL.md' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable')
        $skippedNames = $result.Skipped | ForEach-Object { $_.Name }
        $skippedNames | Should -Contain 'empty-skill'
    }
}

Describe 'Get-CollectionManifest' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Loads collection manifest from valid YAML path' {
        $manifestFile = Join-Path $script:tempDir 'test.collection.yml'
        @"
id: test
name: test-ext
displayName: Test Extension
description: Test
personas:
  - hve-core-all
"@ | Set-Content -Path $manifestFile

        $result = Get-CollectionManifest -CollectionPath $manifestFile
        $result | Should -Not -BeNullOrEmpty
        $result.id | Should -Be 'test'
    }

    It 'Loads collection manifest from valid JSON path' {
        $manifestFile = Join-Path $script:tempDir 'test.collection.json'
        @{
            '\$schema' = '../schemas/collection.schema.json'
            id = 'test'
            name = 'test-ext'
            displayName = 'Test Extension'
            description = 'Test'
            personas = @('hve-core-all')
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestFile

        $result = Get-CollectionManifest -CollectionPath $manifestFile
        $result | Should -Not -BeNullOrEmpty
        $result.id | Should -Be 'test'
    }

    It 'Throws when path does not exist' {
        $nonexistent = Join-Path $script:tempDir 'nonexistent.json'
        { Get-CollectionManifest -CollectionPath $nonexistent } | Should -Throw '*not found*'
    }

    It 'Returns hashtable with expected keys' {
        $manifestFile = Join-Path $script:tempDir 'keys.collection.yml'
        @"
id: keys
name: keys-ext
displayName: Keys
description: Keys test
personas:
  - developer
"@ | Set-Content -Path $manifestFile

        $result = Get-CollectionManifest -CollectionPath $manifestFile
        $result.Keys | Should -Contain 'id'
        $result.Keys | Should -Contain 'name'
        $result.Keys | Should -Contain 'personas'
    }
}

Describe 'Test-GlobMatch' {
    It 'Returns true for matching wildcard pattern' {
        $result = Test-GlobMatch -Name 'rpi-agent' -Patterns @('rpi-*')
        $result | Should -BeTrue
    }

    It 'Returns false for non-matching pattern' {
        $result = Test-GlobMatch -Name 'memory' -Patterns @('rpi-*')
        $result | Should -BeFalse
    }

    It 'Matches against multiple patterns' {
        $result = Test-GlobMatch -Name 'memory' -Patterns @('rpi-*', 'mem*')
        $result | Should -BeTrue
    }

    It 'Handles exact name match' {
        $result = Test-GlobMatch -Name 'memory' -Patterns @('memory')
        $result | Should -BeTrue
    }
}

Describe 'Get-CollectionArtifacts' {
    It 'Returns artifacts from collection items across supported kinds' {
        $collection = @{
            items = @(
                @{ kind = 'agent'; path = '.github/agents/dev-agent.agent.md' },
                @{ kind = 'prompt'; path = '.github/prompts/dev-prompt.prompt.md' },
                @{ kind = 'instruction'; path = '.github/instructions/dev/dev.instructions.md' },
                @{ kind = 'skill'; path = '.github/skills/video-to-gif/' }
            )
        }

        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable', 'preview')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Prompts | Should -Contain 'dev-prompt'
        $result.Instructions | Should -Contain 'dev/dev'
        $result.Skills | Should -Contain 'video-to-gif'
    }

    It 'Uses item maturity when provided' {
        $collection = @{
            items = @(
                @{ kind = 'agent'; path = '.github/agents/dev-agent.agent.md'; maturity = 'stable' },
                @{ kind = 'agent'; path = '.github/agents/preview-dev.agent.md'; maturity = 'preview' }
            )
        }

        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Not -Contain 'preview-dev'
    }

    It 'Defaults to stable maturity when item maturity is omitted' {
        $collection = @{
            items = @(
                @{ kind = 'agent'; path = '.github/agents/dev-agent.agent.md' },
                @{ kind = 'agent'; path = '.github/agents/preview-dev.agent.md' }
            )
        }

        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Contain 'preview-dev'
    }

    It 'Returns empty when collection has no items' {
        $collection = @{ id = 'empty' }
        $result = Get-CollectionArtifacts -Collection $collection -AllowedMaturities @('stable')
        $result.Agents.Count | Should -Be 0
        $result.Prompts.Count | Should -Be 0
        $result.Instructions.Count | Should -Be 0
        $result.Skills.Count | Should -Be 0
    }
}

Describe 'Resolve-HandoffDependencies' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        $script:agentsDir = Join-Path $script:tempDir 'agents'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null

        # Agent with no handoffs
        @'
---
description: "Solo agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'solo.agent.md')

        # Agent with single handoff (object format matching real agents)
        @'
---
description: "Parent agent"
handoffs:
  - label: "Go to child"
    agent: child
    prompt: Continue
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'parent.agent.md')

        @'
---
description: "Child agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'child.agent.md')

        # Self-referential agent (object format)
        @'
---
description: "Self agent"
handoffs:
  - label: "Self"
    agent: self-ref
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'self-ref.agent.md')

        # Circular chain (object format)
        @'
---
description: "Chain A"
handoffs:
  - label: "To B"
    agent: chain-b
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'chain-a.agent.md')

        @'
---
description: "Chain B"
handoffs:
  - label: "To A"
    agent: chain-a
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'chain-b.agent.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns seed agents when no handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('solo') -AgentsDir $script:agentsDir
        $result | Should -Contain 'solo'
        $result.Count | Should -Be 1
    }

    It 'Resolves single-level handoff' {
        $result = Resolve-HandoffDependencies -SeedAgents @('parent') -AgentsDir $script:agentsDir
        $result | Should -Contain 'parent'
        $result | Should -Contain 'child'
    }

    It 'Handles self-referential handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('self-ref') -AgentsDir $script:agentsDir
        $result | Should -Contain 'self-ref'
        $result.Count | Should -Be 1
    }

    It 'Handles circular handoff chains' {
        $result = Resolve-HandoffDependencies -SeedAgents @('chain-a') -AgentsDir $script:agentsDir
        $result | Should -Contain 'chain-a'
        $result | Should -Contain 'chain-b'
        $result.Count | Should -Be 2
    }
}

Describe 'Resolve-RequiresDependencies' {
    It 'Resolves agent requires to include dependent prompts' {
        $result = Resolve-RequiresDependencies `
            -ArtifactNames @{ agents = @('main') } `
            -AllowedMaturities @('stable') `
            -CollectionRequires @{ agents = @{ 'main' = @{ prompts = @('dep-prompt') } } } `
            -CollectionMaturities @{ prompts = @{ 'dep-prompt' = 'stable' } }
        $result.Prompts | Should -Contain 'dep-prompt'
    }

    It 'Resolves transitive agent dependencies' {
        $result = Resolve-RequiresDependencies `
            -ArtifactNames @{ agents = @('top') } `
            -AllowedMaturities @('stable') `
            -CollectionRequires @{ agents = @{ 'top' = @{ agents = @('mid') }; 'mid' = @{ prompts = @('leaf-prompt') } } } `
            -CollectionMaturities @{ agents = @{ 'mid' = 'stable' }; prompts = @{ 'leaf-prompt' = 'stable' } }
        $result.Agents | Should -Contain 'mid'
        $result.Prompts | Should -Contain 'leaf-prompt'
    }

    It 'Respects maturity filter on dependencies' {
        $result = Resolve-RequiresDependencies `
            -ArtifactNames @{ agents = @('main') } `
            -AllowedMaturities @('stable') `
            -CollectionRequires @{ agents = @{ 'main' = @{ prompts = @('exp-prompt') } } } `
            -CollectionMaturities @{ prompts = @{ 'exp-prompt' = 'experimental' } }
        $result.Prompts | Should -Not -Contain 'exp-prompt'
    }
}

Describe 'Update-PackageJsonContributes' {
    It 'Updates contributes section with chat participants' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }
        $agents = @(
            @{ name = 'agent1'; description = 'Desc 1' }
        )
        $prompts = @(
            @{ name = 'prompt1'; description = 'Prompt desc' }
        )
        $instructions = @(
            @{ name = 'instr1'; description = 'Instr desc' }
        )

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles $prompts -ChatInstructions $instructions -ChatSkills @()
        $result.contributes | Should -Not -BeNullOrEmpty
    }

    It 'Handles empty arrays' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @() -ChatSkills @()
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'New-PrepareResult' {
    It 'Creates success result with counts' {
        $result = New-PrepareResult -Success $true -AgentCount 5 -PromptCount 10 -InstructionCount 15 -SkillCount 3 -Version '1.0.0'
        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 5
        $result.PromptCount | Should -Be 10
        $result.InstructionCount | Should -Be 15
        $result.SkillCount | Should -Be 3
        $result.Version | Should -Be '1.0.0'
        $result.ErrorMessage | Should -BeNullOrEmpty
    }

    It 'Creates failure result with error message' {
        $result = New-PrepareResult -Success $false -ErrorMessage 'Something went wrong'
        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Be 'Something went wrong'
        $result.AgentCount | Should -Be 0
        $result.PromptCount | Should -Be 0
        $result.InstructionCount | Should -Be 0
    }

    It 'Returns hashtable with all expected keys' {
        $result = New-PrepareResult -Success $true
        $result.Keys | Should -Contain 'Success'
        $result.Keys | Should -Contain 'AgentCount'
        $result.Keys | Should -Contain 'PromptCount'
        $result.Keys | Should -Contain 'InstructionCount'
        $result.Keys | Should -Contain 'SkillCount'
        $result.Keys | Should -Contain 'Version'
        $result.Keys | Should -Contain 'ErrorMessage'
    }
}

Describe 'Invoke-PrepareExtension' {
    BeforeAll {
        $script:tempDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Create extension directory with package.json
        $script:extDir = Join-Path $script:tempDir 'extension'
        New-Item -ItemType Directory -Path $script:extDir -Force | Out-Null
        @'
{
    "name": "test-extension",
    "version": "1.2.3",
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:extDir 'package.json')

        # Create .github structure
        $script:ghDir = Join-Path $script:tempDir '.github'
        $script:agentsDir = Join-Path $script:ghDir 'agents'
        $script:promptsDir = Join-Path $script:ghDir 'prompts'
        $script:instrDir = Join-Path $script:ghDir 'instructions'
        New-Item -ItemType Directory -Path $script:agentsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:promptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $script:instrDir -Force | Out-Null

        # Create test agent
        @'
---
description: "Test agent"
---
# Agent
'@ | Set-Content -Path (Join-Path $script:agentsDir 'test.agent.md')

        # Create test prompt
        @'
---
description: "Test prompt"
---
# Prompt
'@ | Set-Content -Path (Join-Path $script:promptsDir 'test.prompt.md')

        # Create test instruction
        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
---
# Instruction
'@ | Set-Content -Path (Join-Path $script:instrDir 'test.instructions.md')

    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns success result with correct counts' {
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -DryRun

        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 1
        $result.PromptCount | Should -Be 1
        $result.InstructionCount | Should -Be 1
        $result.Version | Should -Be '1.2.3'
    }

    It 'Fails when extension directory missing' {
        $nonexistentPath = Join-Path $TestDrive 'nonexistent-ext-dir-12345'
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $nonexistentPath `
            -RepoRoot $script:tempDir `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Required paths not found'
    }

    It 'Respects channel filtering' {
        # Add preview agent
        @'
---
description: "Preview agent"
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'preview.agent.md')

        $collectionPath = Join-Path $script:tempDir 'channel-filter.collection.yml'
        @"
id: hve-core-all
name: hve-core-all
displayName: HVE Core - All
description: Channel filtering test
personas:
  - hve-core-all
items:
  - kind: agent
    path: .github/agents/test.agent.md
    maturity: stable
  - kind: agent
    path: .github/agents/preview.agent.md
    maturity: preview
"@ | Set-Content -Path $collectionPath

        $stableResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'PreRelease' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult.AgentCount | Should -BeGreaterThan $stableResult.AgentCount
    }

    It 'Filters prompts and instructions by maturity' {
        # Add experimental prompt
        @'
---
description: "Experimental prompt"
---
'@ | Set-Content -Path (Join-Path $script:promptsDir 'experimental.prompt.md')

        # Add preview instruction
        @'
---
description: "Preview instruction"
applyTo: "**/*.js"
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'preview.instructions.md')

        $collectionPath = Join-Path $script:tempDir 'prompt-instruction-filter.collection.yml'
        @"
id: hve-core-all
name: hve-core-all
displayName: HVE Core - All
description: Prompt/instruction filtering test
personas:
  - hve-core-all
items:
  - kind: agent
    path: .github/agents/test.agent.md
    maturity: stable
  - kind: prompt
    path: .github/prompts/test.prompt.md
    maturity: stable
  - kind: prompt
    path: .github/prompts/experimental.prompt.md
    maturity: experimental
  - kind: instruction
    path: .github/instructions/test.instructions.md
    maturity: stable
  - kind: instruction
    path: .github/instructions/preview.instructions.md
    maturity: preview
"@ | Set-Content -Path $collectionPath

        $stableResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'PreRelease' `
            -Collection $collectionPath `
            -DryRun

        $preReleaseResult.PromptCount | Should -BeGreaterThan $stableResult.PromptCount
        $preReleaseResult.InstructionCount | Should -BeGreaterThan $stableResult.InstructionCount
    }

    It 'Updates package.json when not DryRun' {
        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -DryRun:$false

        $result.Success | Should -BeTrue

        $pkgJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
        $pkgJson.contributes.chatAgents | Should -Not -BeNullOrEmpty
    }

    It 'Copies changelog when path provided' {
        $changelogPath = Join-Path $script:tempDir 'CHANGELOG.md'
        '# Changelog' | Set-Content -Path $changelogPath

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -ChangelogPath $changelogPath `
            -DryRun:$false

        $result.Success | Should -BeTrue
        Test-Path (Join-Path $script:extDir 'CHANGELOG.md') | Should -BeTrue
    }

    It 'Fails when package.json has invalid JSON' {
        $badJsonDir = Join-Path $TestDrive 'bad-json-ext'
        New-Item -ItemType Directory -Path $badJsonDir -Force | Out-Null
        '{ invalid json }' | Set-Content -Path (Join-Path $badJsonDir 'package.json')

        # Create .github structure for this test
        $badGhDir = Join-Path (Split-Path $badJsonDir -Parent) '.github'
        New-Item -ItemType Directory -Path (Join-Path $badGhDir 'agents') -Force | Out-Null

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $badJsonDir `
            -RepoRoot (Split-Path $badJsonDir -Parent) `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Failed to parse package.json'
    }

    It 'Fails when package.json missing version field' {
        $noVersionDir = Join-Path $TestDrive 'no-version-ext'
        New-Item -ItemType Directory -Path $noVersionDir -Force | Out-Null
        '{"name": "test"}' | Set-Content -Path (Join-Path $noVersionDir 'package.json')

        # Create .github structure for this test
        $noVersionGhDir = Join-Path (Split-Path $noVersionDir -Parent) '.github'
        New-Item -ItemType Directory -Path (Join-Path $noVersionGhDir 'agents') -Force | Out-Null

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $noVersionDir `
            -RepoRoot (Split-Path $noVersionDir -Parent) `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match "does not contain a 'version' field"
    }

    It 'Fails when version format is invalid' {
        $badVersionDir = Join-Path $TestDrive 'bad-version-ext'
        New-Item -ItemType Directory -Path $badVersionDir -Force | Out-Null
        '{"name": "test", "version": "invalid"}' | Set-Content -Path (Join-Path $badVersionDir 'package.json')

        # Create .github structure for this test
        $badVersionGhDir = Join-Path (Split-Path $badVersionDir -Parent) '.github'
        New-Item -ItemType Directory -Path (Join-Path $badVersionGhDir 'agents') -Force | Out-Null

        $result = Invoke-PrepareExtension `
            -ExtensionDirectory $badVersionDir `
            -RepoRoot (Split-Path $badVersionDir -Parent) `
            -Channel 'Stable'

        $result.Success | Should -BeFalse
        $result.ErrorMessage | Should -Match 'Invalid version format'
    }

    Context 'Persona template copy' {
        BeforeAll {
            # Developer collection manifest
            $script:devCollectionPath = Join-Path $script:tempDir 'developer.collection.yml'
            @"
id: developer
name: hve-developer
displayName: HVE Core - Developer Edition
description: Developer edition
personas:
  - developer
"@ | Set-Content -Path $script:devCollectionPath

            # hve-core-all collection manifest (default)
            $script:allCollectionPath = Join-Path $script:tempDir 'hve-core-all.collection.yml'
            @"
id: hve-core-all
name: hve-core-all
displayName: HVE Core - All
description: All artifacts
personas:
  - hve-core-all
"@ | Set-Content -Path $script:allCollectionPath

            # Collection manifest referencing a missing template
            $script:missingCollectionPath = Join-Path $script:tempDir 'nonexistent.collection.yml'
            @"
id: nonexistent
name: nonexistent
displayName: Nonexistent
description: Missing template
personas:
  - nonexistent
"@ | Set-Content -Path $script:missingCollectionPath

            # Persona template for developer collection
            @'
{
    "name": "hve-developer",
    "version": "1.2.3",
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:extDir 'package.developer.json')

        }

        BeforeEach {
            $script:originalPackageJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw
        }

        AfterEach {
            $script:originalPackageJson | Set-Content -Path (Join-Path $script:extDir 'package.json')
            $bakPath = Join-Path $script:extDir 'package.json.bak'
            if (Test-Path $bakPath) {
                Remove-Item -Path $bakPath -Force
            }
        }

        It 'Skips template copy when no collection specified' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -DryRun

            $result.Success | Should -BeTrue
            $currentContent = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw
            $currentContent | Should -Be $script:originalPackageJson
            Test-Path (Join-Path $script:extDir 'package.json.bak') | Should -BeFalse
        }

        It 'Skips template copy for hve-core-all collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:allCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            Test-Path (Join-Path $script:extDir 'package.json.bak') | Should -BeFalse
        }

        It 'Returns error when persona template file missing' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:missingCollectionPath `
                -DryRun

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'Persona template not found'
        }

        It 'Copies template to package.json for non-default collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:devCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $updatedJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $updatedJson.name | Should -Be 'hve-developer'
        }

        It 'Creates package.json.bak backup before template copy' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:devCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $bakPath = Join-Path $script:extDir 'package.json.bak'
            Test-Path $bakPath | Should -BeTrue
            $bakContent = Get-Content -Path $bakPath -Raw
            $bakContent | Should -Be $script:originalPackageJson
        }
    }

    Context 'Collection maturity gating' {
        BeforeAll {
            # Deprecated collection manifest
            $script:deprecatedCollectionPath = Join-Path $script:tempDir 'deprecated.collection.yml'
            @"
id: deprecated-coll
name: deprecated-ext
displayName: Deprecated Collection
description: Deprecated collection for testing
personas:
  - hve-core-all
maturity: deprecated
"@ | Set-Content -Path $script:deprecatedCollectionPath

            # Experimental collection manifest
            $script:experimentalCollectionPath = Join-Path $script:tempDir 'experimental.collection.yml'
            @"
id: experimental-coll
name: experimental-ext
displayName: Experimental Collection
description: Experimental collection for testing
personas:
  - hve-core-all
maturity: experimental
"@ | Set-Content -Path $script:experimentalCollectionPath

            # Persona template for experimental collection
            @'
{
    "name": "experimental-ext",
    "version": "1.2.3",
    "contributes": {}
}
'@ | Set-Content -Path (Join-Path $script:extDir 'package.experimental-coll.json')
        }

        It 'Returns early success for deprecated collection on Stable channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:deprecatedCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -Be 0
        }

        It 'Returns early success for deprecated collection on PreRelease channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'PreRelease' `
                -Collection $script:deprecatedCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -Be 0
        }

        It 'Returns early success for experimental collection on Stable channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:experimentalCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.AgentCount | Should -Be 0
        }

        It 'Processes experimental collection on PreRelease channel' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'PreRelease' `
                -Collection $script:experimentalCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $result.ErrorMessage | Should -Be ''
        }
    }
}
