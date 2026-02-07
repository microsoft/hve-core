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

Describe 'Get-FrontmatterData' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Extracts description from frontmatter' {
        $testFile = Join-Path $script:tempDir 'test.md'
        @'
---
description: "Test description"
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
        $result.description | Should -Be 'Test description'
    }

    It 'Returns hashtable with only description key' {
        $testFile = Join-Path $script:tempDir 'desc-only.md'
        @'
---
description: "Desc"
maturity: preview
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
        $result.Keys | Should -Contain 'description'
        $result.Keys | Should -Not -Contain 'maturity'
    }

    It 'Uses fallback description when not in frontmatter' {
        $testFile = Join-Path $script:tempDir 'no-desc.md'
        @'
---
applyTo: "**"
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'My Fallback'
        $result.description | Should -Be 'My Fallback'
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

        $script:mockRegistry = @{
            agents = @{
                'stable' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'preview' = @{ maturity = 'preview'; personas = @('hve-core-all'); tags = @() }
            }
        }
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers agents matching allowed maturities' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @() -Registry $script:mockRegistry
        $result.DirectoryExists | Should -BeTrue
        $result.Agents.Count | Should -Be 2
    }

    It 'Filters agents by maturity' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -ExcludedAgents @() -Registry $script:mockRegistry
        $result.Agents.Count | Should -Be 1
        $result.Skipped.Count | Should -Be 1
    }

    It 'Excludes specified agents' {
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable', 'preview') -ExcludedAgents @('stable') -Registry $script:mockRegistry
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
}

Describe 'Get-RegistryData' {
    BeforeAll {
        $script:tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Loads registry from valid path' {
        $registryFile = Join-Path $script:tempDir 'registry.json'
        @{ agents = @{ 'test' = @{ maturity = 'stable' } } } | ConvertTo-Json -Depth 5 | Set-Content -Path $registryFile

        $result = Get-RegistryData -RegistryPath $registryFile
        $result | Should -Not -BeNullOrEmpty
    }

    It 'Throws when path does not exist' {
        $nonexistent = Join-Path $script:tempDir 'nonexistent.json'
        { Get-RegistryData -RegistryPath $nonexistent } | Should -Throw '*not found*'
    }

    It 'Returns hashtable with expected keys' {
        $registryFile = Join-Path $script:tempDir 'registry2.json'
        @{
            agents = @{ 'a' = @{ maturity = 'stable' } }
            prompts = @{ 'p' = @{ maturity = 'stable' } }
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $registryFile

        $result = Get-RegistryData -RegistryPath $registryFile
        $result.Keys | Should -Contain 'agents'
        $result.Keys | Should -Contain 'prompts'
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

        $script:mockRegistry = @{
            skills = @{
                'test-skill' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
        }
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Discovers skills in directory' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable') -Registry $script:mockRegistry
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

    It 'Filters skills by maturity from registry' {
        $previewRegistry = @{
            skills = @{
                'test-skill' = @{ maturity = 'preview'; personas = @('hve-core-all'); tags = @() }
            }
        }
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable') -Registry $previewRegistry
        $result.Skills.Count | Should -Be 0
        $result.Skipped.Count | Should -BeGreaterThan 0
    }

    It 'Skips directories without SKILL.md' {
        $result = Get-DiscoveredSkills -SkillsDir $script:skillsDir -AllowedMaturities @('stable') -Registry $script:mockRegistry
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

    It 'Loads collection manifest from valid path' {
        $manifestFile = Join-Path $script:tempDir 'test.collection.json'
        @{
            '$schema' = '../schemas/collection.schema.json'
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
        $manifestFile = Join-Path $script:tempDir 'keys.collection.json'
        @{
            '$schema' = '../schemas/collection.schema.json'
            id = 'keys'
            name = 'keys-ext'
            displayName = 'Keys'
            description = 'Keys test'
            personas = @('developer')
        } | ConvertTo-Json -Depth 5 | Set-Content -Path $manifestFile

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
    BeforeAll {
        $script:registry = @{
            agents = @{
                'dev-agent' = @{ maturity = 'stable'; personas = @('developer'); tags = @() }
                'all-agent' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'preview-dev' = @{ maturity = 'preview'; personas = @('developer'); tags = @() }
            }
            prompts = @{
                'dev-prompt' = @{ maturity = 'stable'; personas = @('developer'); tags = @() }
            }
            instructions = @{}
            skills = @{}
        }
    }

    It 'Filters by persona' {
        $collection = @{ personas = @('developer') }
        $result = Get-CollectionArtifacts -Registry $script:registry -Collection $collection -AllowedMaturities @('stable', 'preview')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Not -Contain 'all-agent'
    }

    It 'Applies include patterns' {
        $collection = @{
            personas = @('developer')
            include = @{ agents = @('dev-*') }
        }
        $result = Get-CollectionArtifacts -Registry $script:registry -Collection $collection -AllowedMaturities @('stable', 'preview')
        $result.Agents | Should -Contain 'dev-agent'
    }

    It 'Applies exclude patterns' {
        $collection = @{
            personas = @('developer')
            exclude = @{ agents = @('preview-*') }
        }
        $result = Get-CollectionArtifacts -Registry $script:registry -Collection $collection -AllowedMaturities @('stable', 'preview')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Not -Contain 'preview-dev'
    }

    It 'Respects maturity filter' {
        $collection = @{ personas = @('developer') }
        $result = Get-CollectionArtifacts -Registry $script:registry -Collection $collection -AllowedMaturities @('stable')
        $result.Agents | Should -Contain 'dev-agent'
        $result.Agents | Should -Not -Contain 'preview-dev'
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

        $script:mockRegistry = @{
            agents = @{
                'solo' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'parent' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'child' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'self-ref' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'chain-a' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'chain-b' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
        }
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Returns seed agents when no handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('solo') -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -Registry $script:mockRegistry
        $result | Should -Contain 'solo'
        $result.Count | Should -Be 1
    }

    It 'Resolves single-level handoff' {
        $result = Resolve-HandoffDependencies -SeedAgents @('parent') -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -Registry $script:mockRegistry
        $result | Should -Contain 'parent'
        $result | Should -Contain 'child'
    }

    It 'Handles self-referential handoffs' {
        $result = Resolve-HandoffDependencies -SeedAgents @('self-ref') -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -Registry $script:mockRegistry
        $result | Should -Contain 'self-ref'
        $result.Count | Should -Be 1
    }

    It 'Handles circular handoff chains' {
        $result = Resolve-HandoffDependencies -SeedAgents @('chain-a') -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -Registry $script:mockRegistry
        $result | Should -Contain 'chain-a'
        $result | Should -Contain 'chain-b'
        $result.Count | Should -Be 2
    }
}

Describe 'Resolve-RequiresDependencies' {
    It 'Resolves agent requires to include dependent prompts' {
        $registry = @{
            agents = @{
                'main' = @{
                    maturity = 'stable'
                    personas = @('hve-core-all')
                    requires = @{ prompts = @('dep-prompt') }
                }
            }
            prompts = @{
                'dep-prompt' = @{ maturity = 'stable'; personas = @('hve-core-all') }
            }
        }
        $result = Resolve-RequiresDependencies -ArtifactNames @{ agents = @('main') } -Registry $registry -AllowedMaturities @('stable')
        $result.Prompts | Should -Contain 'dep-prompt'
    }

    It 'Resolves transitive agent dependencies' {
        $registry = @{
            agents = @{
                'top' = @{
                    maturity = 'stable'
                    personas = @('hve-core-all')
                    requires = @{ agents = @('mid') }
                }
                'mid' = @{
                    maturity = 'stable'
                    personas = @('hve-core-all')
                    requires = @{ prompts = @('leaf-prompt') }
                }
            }
            prompts = @{
                'leaf-prompt' = @{ maturity = 'stable'; personas = @('hve-core-all') }
            }
        }
        $result = Resolve-RequiresDependencies -ArtifactNames @{ agents = @('top') } -Registry $registry -AllowedMaturities @('stable')
        $result.Agents | Should -Contain 'mid'
        $result.Prompts | Should -Contain 'leaf-prompt'
    }

    It 'Respects maturity filter on dependencies' {
        $registry = @{
            agents = @{
                'main' = @{
                    maturity = 'stable'
                    personas = @('hve-core-all')
                    requires = @{ prompts = @('exp-prompt') }
                }
            }
            prompts = @{
                'exp-prompt' = @{ maturity = 'experimental'; personas = @('hve-core-all') }
            }
        }
        $result = Resolve-RequiresDependencies -ArtifactNames @{ agents = @('main') } -Registry $registry -AllowedMaturities @('stable')
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

        # Create mock registry for all Invoke-PrepareExtension tests
        $registryContent = @{
            version = "1.0"
            personas = @{ definitions = @{ 'hve-core-all' = @{ name = 'All'; description = 'All artifacts' } } }
            agents = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
            prompts = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
            instructions = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
            skills = @{}
        }
        $registryContent | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:ghDir 'ai-artifacts-registry.json')
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

        # Update registry with preview agent
        $registryContent = @{
            version = "1.0"
            personas = @{ definitions = @{ 'hve-core-all' = @{ name = 'All'; description = 'All artifacts' } } }
            agents = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'preview' = @{ maturity = 'preview'; personas = @('hve-core-all'); tags = @() }
            }
            prompts = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
            instructions = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
            }
            skills = @{}
        }
        $registryContent | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:ghDir 'ai-artifacts-registry.json')

        $stableResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -DryRun

        $preReleaseResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'PreRelease' `
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

        # Update registry with all artifacts
        $registryContent = @{
            version = "1.0"
            personas = @{ definitions = @{ 'hve-core-all' = @{ name = 'All'; description = 'All artifacts' } } }
            agents = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'preview' = @{ maturity = 'preview'; personas = @('hve-core-all'); tags = @() }
            }
            prompts = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'experimental' = @{ maturity = 'experimental'; personas = @('hve-core-all'); tags = @() }
            }
            instructions = @{
                'test' = @{ maturity = 'stable'; personas = @('hve-core-all'); tags = @() }
                'preview' = @{ maturity = 'preview'; personas = @('hve-core-all'); tags = @() }
            }
            skills = @{}
        }
        $registryContent | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:ghDir 'ai-artifacts-registry.json')

        $stableResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'Stable' `
            -DryRun

        $preReleaseResult = Invoke-PrepareExtension `
            -ExtensionDirectory $script:extDir `
            -RepoRoot $script:tempDir `
            -Channel 'PreRelease' `
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

    Context 'Metadata override from collection manifest (Option A)' {
        BeforeAll {
            # Developer collection manifest with publisher
            $script:devCollectionPath = Join-Path $script:tempDir 'developer.collection.json'
            @{
                id          = 'developer'
                name        = 'hve-developer'
                displayName = 'HVE Core - Developer Edition'
                description = 'Developer edition'
                publisher   = 'ise-hve-essentials'
                personas    = @('developer')
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:devCollectionPath

            # hve-core-all collection manifest (default)
            $script:allCollectionPath = Join-Path $script:tempDir 'hve-core-all.collection.json'
            @{
                id          = 'hve-core-all'
                name        = 'hve-core'
                displayName = 'HVE Core'
                description = 'All artifacts'
                publisher   = 'ise-hve-essentials'
                personas    = @('hve-core-all')
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:allCollectionPath

            # Collection manifest missing required fields
            $script:incompleteCollectionPath = Join-Path $script:tempDir 'incomplete.collection.json'
            @{
                id          = 'incomplete'
                name        = 'incomplete'
                personas    = @('incomplete')
            } | ConvertTo-Json -Depth 5 | Set-Content -Path $script:incompleteCollectionPath

            # Update registry with developer persona entry
            $registryContent = @{
                version  = '1.0'
                personas = @{
                    definitions = @{
                        'hve-core-all' = @{ name = 'All'; description = 'All artifacts' }
                        'developer'    = @{ name = 'Developer'; description = 'Developer artifacts' }
                    }
                }
                agents       = @{
                    'test' = @{ maturity = 'stable'; personas = @('hve-core-all', 'developer'); tags = @(); description = 'Test agent' }
                }
                prompts      = @{
                    'test' = @{ maturity = 'stable'; personas = @('hve-core-all', 'developer'); tags = @(); description = 'Test prompt' }
                }
                instructions = @{
                    'test' = @{ maturity = 'stable'; personas = @('hve-core-all', 'developer'); tags = @(); description = 'Test instructions' }
                }
                skills       = @{}
            }
            $registryContent | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $script:ghDir 'ai-artifacts-registry.json')
        }

        BeforeEach {
            $script:originalPackageJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw
        }

        AfterEach {
            $script:originalPackageJson | Set-Content -Path (Join-Path $script:extDir 'package.json')
        }

        It 'Skips metadata override when no collection specified' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -DryRun

            $result.Success | Should -BeTrue
            $currentContent = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw
            $currentContent | Should -Be $script:originalPackageJson
        }

        It 'Skips metadata override for hve-core-all collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:allCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
        }

        It 'Returns error when collection manifest missing required fields' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:incompleteCollectionPath `
                -DryRun

            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -Match 'missing required fields'
        }

        It 'Applies metadata override from collection manifest for non-default collection' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:devCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $updatedJson = Get-Content -Path (Join-Path $script:extDir 'package.json') -Raw | ConvertFrom-Json
            $updatedJson.name | Should -Be 'hve-developer'
            $updatedJson.displayName | Should -Be 'HVE Core - Developer Edition'
            $updatedJson.description | Should -Be 'Developer edition'
            $updatedJson.publisher | Should -Be 'ise-hve-essentials'
        }

        It 'Does not create package.json.bak backup (Option A uses git restore)' {
            $result = Invoke-PrepareExtension `
                -ExtensionDirectory $script:extDir `
                -RepoRoot $script:tempDir `
                -Channel 'Stable' `
                -Collection $script:devCollectionPath `
                -DryRun

            $result.Success | Should -BeTrue
            $bakPath = Join-Path $script:extDir 'package.json.bak'
            Test-Path $bakPath | Should -BeFalse
        }
    }
}
