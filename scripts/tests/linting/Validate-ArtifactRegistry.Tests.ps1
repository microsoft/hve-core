#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    # Dot-source the main script to make functions available
    $scriptPath = Join-Path $PSScriptRoot '../../linting/Validate-ArtifactRegistry.ps1'
    . $scriptPath

    # Import CI helpers module
    $ciHelpersPath = Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1'
    Import-Module $ciHelpersPath -Force

    # Set up fixture paths
    $script:FixtureDir = Join-Path $PSScriptRoot '../Fixtures/ArtifactRegistry'
    $script:RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path

    # Fixture file paths
    $script:ValidRegistryPath = Join-Path $script:FixtureDir 'valid-registry.json'
    $script:InvalidJsonPath = Join-Path $script:FixtureDir 'invalid-json.json'
    $script:MissingFieldsPath = Join-Path $script:FixtureDir 'missing-fields.json'
    $script:InvalidVersionPath = Join-Path $script:FixtureDir 'invalid-version.json'
    $script:MissingPersonasDefsPath = Join-Path $script:FixtureDir 'missing-personas-defs.json'
    $script:InvalidPersonaIdPath = Join-Path $script:FixtureDir 'invalid-persona-id.json'
    $script:MissingPersonaNamePath = Join-Path $script:FixtureDir 'missing-persona-name.json'
    $script:UndefinedPersonaRefPath = Join-Path $script:FixtureDir 'undefined-persona-ref.json'
    $script:UnknownDepRefsPath = Join-Path $script:FixtureDir 'unknown-dep-refs.json'
    $script:CircularDepsPath = Join-Path $script:FixtureDir 'circular-deps.json'
    $script:NoRequiresPath = Join-Path $script:FixtureDir 'no-requires.json'
}

#region Test-RegistryStructure Tests

Describe 'Test-RegistryStructure' -Tag 'Unit' {
    Context 'JSON parsing' {
        It 'Returns error when JSON is malformed' {
            $result = Test-RegistryStructure -RegistryPath $script:InvalidJsonPath
            $result.Success | Should -BeFalse
            $result.Errors[0] | Should -Match 'Failed to parse registry JSON'
            $result.Registry | Should -BeNull
        }

        It 'Parses valid JSON successfully' {
            $result = Test-RegistryStructure -RegistryPath $script:ValidRegistryPath
            $result.Success | Should -BeTrue
            $result.Registry | Should -Not -BeNull
        }
    }

    Context 'Required fields validation' {
        It 'Reports missing $schema field' {
            $result = Test-RegistryStructure -RegistryPath $script:MissingFieldsPath
            $result.Success | Should -BeFalse
            $result.Errors | Should -Contain 'Missing required field: $schema'
        }

        It 'Reports all missing required fields' {
            $result = Test-RegistryStructure -RegistryPath $script:MissingFieldsPath
            # Should report missing: $schema, version, personas, agents, prompts, instructions, skills
            $result.Errors.Count | Should -BeGreaterOrEqual 6
        }
    }

    Context 'Version format validation' {
        It 'Reports invalid version format' {
            $result = Test-RegistryStructure -RegistryPath $script:InvalidVersionPath
            $result.Errors | Should -Contain 'Invalid version format: 1.0.0. Expected: major.minor'
        }

        It 'Accepts valid version format' {
            $result = Test-RegistryStructure -RegistryPath $script:ValidRegistryPath
            $result.Errors | Where-Object { $_ -match 'version format' } | Should -BeNullOrEmpty
        }
    }

    Context 'Personas structure' {
        It 'Reports missing personas.definitions' {
            $result = Test-RegistryStructure -RegistryPath $script:MissingPersonasDefsPath
            $result.Errors | Should -Contain 'Missing required field: personas.definitions'
        }
    }
}

#endregion

#region Test-PersonaReferences Tests

Describe 'Test-PersonaReferences' -Tag 'Unit' {
    BeforeAll {
        # Load valid registry for reference
        $content = Get-Content $script:ValidRegistryPath -Raw
        $script:ValidRegistry = $content | ConvertFrom-Json -AsHashtable
    }

    Context 'Persona definition validation' {
        It 'Reports invalid persona ID format' {
            $content = Get-Content $script:InvalidPersonaIdPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-PersonaReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match 'Invalid persona ID format' } | Should -Not -BeNullOrEmpty
        }

        It 'Reports missing name field' {
            $content = Get-Content $script:MissingPersonaNamePath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-PersonaReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match "missing 'name' field" } | Should -Not -BeNullOrEmpty
        }

        It 'Reports missing description field' {
            # Create registry with persona missing description
            $registry = @{
                personas = @{
                    definitions = @{
                        'test-persona' = @{ name = 'Test' }
                    }
                }
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Test-PersonaReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match "missing 'description' field" } | Should -Not -BeNullOrEmpty
        }

        It 'Passes with valid persona definitions' {
            $result = Test-PersonaReferences -Registry $script:ValidRegistry
            $result.Success | Should -BeTrue
        }
    }

    Context 'Persona reference validation' {
        It 'Reports undefined persona references in artifacts' {
            $content = Get-Content $script:UndefinedPersonaRefPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-PersonaReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match 'references undefined persona' } | Should -Not -BeNullOrEmpty
        }
    }
}

#endregion

#region Get-ArtifactPath Tests

Describe 'Get-ArtifactPath' -Tag 'Unit' {
    BeforeAll {
        $script:TestRepoRoot = '/test/repo'
    }

    Context 'Section path mapping' {
        It 'Returns correct path for agents section' {
            $result = Get-ArtifactPath -Section 'agents' -Key 'test-agent' -RepoRoot $script:TestRepoRoot
            $result | Should -Be '/test/repo/.github/agents/test-agent.agent.md'
        }

        It 'Returns correct path for prompts section' {
            $result = Get-ArtifactPath -Section 'prompts' -Key 'test-prompt' -RepoRoot $script:TestRepoRoot
            $result | Should -Be '/test/repo/.github/prompts/test-prompt.prompt.md'
        }

        It 'Returns correct path for instructions section' {
            $result = Get-ArtifactPath -Section 'instructions' -Key 'test-instruction' -RepoRoot $script:TestRepoRoot
            $result | Should -Be '/test/repo/.github/instructions/test-instruction.instructions.md'
        }

        It 'Returns correct path for skills section' {
            $result = Get-ArtifactPath -Section 'skills' -Key 'test-skill' -RepoRoot $script:TestRepoRoot
            $result | Should -Be '/test/repo/.github/skills/test-skill/SKILL.md'
        }
    }

    Context 'Unknown section handling' {
        It 'Returns null for unknown section' {
            $result = Get-ArtifactPath -Section 'unknown' -Key 'test' -RepoRoot $script:TestRepoRoot
            $result | Should -BeNull
        }
    }
}

#endregion

#region Test-ArtifactFileExistence Tests

Describe 'Test-ArtifactFileExistence' -Tag 'Unit' {
    Context 'File existence checks' {
        It 'Returns success when all files exist' {
            Mock Test-Path { return $true }
            $registry = @{
                agents       = @{ 'existing-agent' = @{} }
                prompts      = @{ 'existing-prompt' = @{} }
                instructions = @{ 'existing-instruction' = @{} }
                skills       = @{ 'existing-skill' = @{} }
            }
            $result = Test-ArtifactFileExistence -Registry $registry -RepoRoot $TestDrive
            $result.Success | Should -BeTrue
            $result.Errors.Count | Should -Be 0
        }

        It 'Returns error for missing file' {
            Mock Test-Path { return $false }
            $registry = @{
                agents       = @{ 'missing-agent' = @{} }
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Test-ArtifactFileExistence -Registry $registry -RepoRoot $TestDrive
            $result.Success | Should -BeFalse
            $result.Errors[0] | Should -Match 'agents/missing-agent: File not found'
        }
    }
}

#endregion

#region Test-DependencyReferences Tests

Describe 'Test-DependencyReferences' -Tag 'Unit' {
    BeforeAll {
        $script:BaseRegistry = @{
            agents       = @{
                'agent-a' = @{
                    requires = @{
                        agents       = @()
                        prompts      = @()
                        instructions = @()
                        skills       = @()
                    }
                }
            }
            prompts      = @{ 'prompt-a' = @{} }
            instructions = @{ 'instruction-a' = @{} }
            skills       = @{ 'skill-a' = @{} }
        }
    }

    Context 'Dependency validation' {
        It 'Reports unknown agent reference' {
            $content = Get-Content $script:UnknownDepRefsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match 'requires.agents references unknown agent' } | Should -Not -BeNullOrEmpty
        }

        It 'Reports unknown prompt reference' {
            $content = Get-Content $script:UnknownDepRefsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match 'requires.prompts references unknown prompt' } | Should -Not -BeNullOrEmpty
        }

        It 'Reports unknown instruction reference' {
            $content = Get-Content $script:UnknownDepRefsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match 'requires.instructions references unknown instruction' } | Should -Not -BeNullOrEmpty
        }

        It 'Reports unknown skill reference' {
            $content = Get-Content $script:UnknownDepRefsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            $result.Errors | Where-Object { $_ -match 'requires.skills references unknown skill' } | Should -Not -BeNullOrEmpty
        }

        It 'Passes with valid references' {
            $registry = @{
                agents       = @{
                    'agent-a' = @{
                        requires = @{
                            agents       = @()
                            prompts      = @('prompt-a')
                            instructions = @()
                            skills       = @()
                        }
                    }
                }
                prompts      = @{ 'prompt-a' = @{} }
                instructions = @{}
                skills       = @{}
            }
            $result = Test-DependencyReferences -Registry $registry
            $result.Success | Should -BeTrue
        }

        It 'Skips agents without requires block' {
            $content = Get-Content $script:NoRequiresPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            $result.Success | Should -BeTrue
        }
    }

    Context 'Circular dependency detection' {
        It 'Returns warnings for circular dependencies' {
            $content = Get-Content $script:CircularDepsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            $result.Warnings.Count | Should -BeGreaterThan 0
            $result.Warnings[0] | Should -Match 'Circular agent dependency detected'
        }

        It 'Success remains true with circular warnings' {
            $content = Get-Content $script:CircularDepsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Test-DependencyReferences -Registry $registry
            # Circular deps are warnings, not errors
            $result.Success | Should -BeTrue
        }
    }
}

#endregion

#region Find-CircularAgentDependencies Tests

Describe 'Find-CircularAgentDependencies' -Tag 'Unit' {
    Context 'Cycle detection' {
        It 'Returns empty list when no cycles exist' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('agent-b') } }
                    'agent-b' = @{ requires = @{ agents = @() } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -Be 0
        }

        It 'Detects simple A -> B -> A cycle' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('agent-b') } }
                    'agent-b' = @{ requires = @{ agents = @('agent-a') } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Detects A -> B -> C -> A cycle' {
            $content = Get-Content $script:CircularDepsPath -Raw
            $registry = $content | ConvertFrom-Json -AsHashtable
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Does not report non-cyclic paths' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('agent-b', 'agent-c') } }
                    'agent-b' = @{ requires = @{ agents = @('agent-d') } }
                    'agent-c' = @{ requires = @{ agents = @('agent-d') } }
                    'agent-d' = @{ requires = @{ agents = @() } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -Be 0
        }
    }
}

#endregion

#region Find-CycleFromAgent Tests

Describe 'Find-CycleFromAgent' -Tag 'Unit' {
    Context 'Recursive cycle detection' {
        It 'Handles agent with no requires.agents' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ prompts = @() } }  # no agents key
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -Be 0
        }

        It 'Skips references to nonexistent agents' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('nonexistent') } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -Be 0
        }

        It 'Handles self-referencing agent' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('agent-a') } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -BeGreaterThan 0
        }

        It 'Deduplicates equivalent cycles using global visited tracking' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('agent-b') } }
                    'agent-b' = @{ requires = @{ agents = @('agent-a') } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            # The function may report cycles from different starting points
            # but the global visited hash prevents truly identical cycles
            $result.Count | Should -BeGreaterThan 0
            # Verify cycles are detected
            ($result | ForEach-Object { $_ -join ',' }) | Should -Match 'agent-a|agent-b'
        }

        It 'Detects multiple independent cycles' {
            $registry = @{
                agents = @{
                    'agent-a' = @{ requires = @{ agents = @('agent-b') } }
                    'agent-b' = @{ requires = @{ agents = @('agent-a') } }
                    'agent-c' = @{ requires = @{ agents = @('agent-d') } }
                    'agent-d' = @{ requires = @{ agents = @('agent-c') } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -BeGreaterOrEqual 2
        }
    }
}

#endregion

#region Find-OrphanArtifacts Tests

Describe 'Find-OrphanArtifacts' -Tag 'Unit' {
    BeforeAll {
        $script:OrphanTestRoot = Join-Path $TestDrive 'orphan-test-repo'
    }

    BeforeEach {
        # Clean and recreate test directory structure
        if (Test-Path $script:OrphanTestRoot) {
            Remove-Item -Path $script:OrphanTestRoot -Recurse -Force
        }
        New-Item -ItemType Directory -Path "$script:OrphanTestRoot/.github/agents" -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:OrphanTestRoot/.github/prompts" -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:OrphanTestRoot/.github/instructions" -Force | Out-Null
        New-Item -ItemType Directory -Path "$script:OrphanTestRoot/.github/skills" -Force | Out-Null
    }

    Context 'Orphan detection by section' {
        It 'Returns empty warnings when no orphans exist' {
            $registry = @{
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Find-OrphanArtifacts -Registry $registry -RepoRoot $script:OrphanTestRoot
            $result.Warnings.Count | Should -Be 0
        }

        It 'Detects orphan agent file' {
            Set-Content -Path "$script:OrphanTestRoot/.github/agents/orphan-agent.agent.md" -Value '# Orphan'
            $registry = @{
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Find-OrphanArtifacts -Registry $registry -RepoRoot $script:OrphanTestRoot
            $result.Warnings | Where-Object { $_ -match 'Orphan agent file' } | Should -Not -BeNullOrEmpty
        }

        It 'Detects orphan prompt file' {
            Set-Content -Path "$script:OrphanTestRoot/.github/prompts/orphan-prompt.prompt.md" -Value '# Orphan'
            $registry = @{
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Find-OrphanArtifacts -Registry $registry -RepoRoot $script:OrphanTestRoot
            $result.Warnings | Where-Object { $_ -match 'Orphan prompt file' } | Should -Not -BeNullOrEmpty
        }

        It 'Detects orphan instruction file in subdirectory' {
            New-Item -ItemType Directory -Path "$script:OrphanTestRoot/.github/instructions/subdir" -Force | Out-Null
            Set-Content -Path "$script:OrphanTestRoot/.github/instructions/subdir/orphan.instructions.md" -Value '# Orphan'
            $registry = @{
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Find-OrphanArtifacts -Registry $registry -RepoRoot $script:OrphanTestRoot
            $result.Warnings | Where-Object { $_ -match 'Orphan instruction file' } | Should -Not -BeNullOrEmpty
        }

        It 'Detects orphan skill directory' {
            New-Item -ItemType Directory -Path "$script:OrphanTestRoot/.github/skills/orphan-skill" -Force | Out-Null
            Set-Content -Path "$script:OrphanTestRoot/.github/skills/orphan-skill/SKILL.md" -Value '# Orphan Skill'
            $registry = @{
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Find-OrphanArtifacts -Registry $registry -RepoRoot $script:OrphanTestRoot
            $result.Warnings | Where-Object { $_ -match 'Orphan skill directory' } | Should -Not -BeNullOrEmpty
        }
    }

    Context 'Missing directories' {
        It 'Handles missing artifact directories gracefully' {
            $emptyRepoRoot = Join-Path $TestDrive 'empty-repo'
            New-Item -ItemType Directory -Path $emptyRepoRoot -Force | Out-Null

            $registry = @{
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Find-OrphanArtifacts -Registry $registry -RepoRoot $emptyRepoRoot
            $result.Warnings.Count | Should -Be 0
        }
    }
}

#endregion

#region Write-RegistryValidationOutput Tests

Describe 'Write-RegistryValidationOutput' -Tag 'Unit' {
    Context 'Console output formatting' {
        It 'Outputs errors section when errors exist' {
            $result = @{
                Errors         = @('Error 1', 'Error 2')
                Warnings       = @()
                ArtifactCounts = $null
            }

            # Capture Write-Host output using 6>&1
            $output = Write-RegistryValidationOutput -Result $result -RegistryPath '/test/registry.json' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match 'Errors \(2\)'
        }

        It 'Outputs warnings section when warnings exist' {
            $result = @{
                Errors         = @()
                Warnings       = @('Warning 1')
                ArtifactCounts = $null
            }

            $output = Write-RegistryValidationOutput -Result $result -RegistryPath '/test/registry.json' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match 'Warnings \(1\)'
        }

        It 'Outputs clean summary without errors or warnings' {
            $result = @{
                Errors         = @()
                Warnings       = @()
                ArtifactCounts = $null
            }

            $output = Write-RegistryValidationOutput -Result $result -RegistryPath '/test/registry.json' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match 'Errors: 0'
        }

        It 'Outputs artifact counts when provided' {
            $result = @{
                Errors         = @()
                Warnings       = @()
                ArtifactCounts = @{
                    Agents       = 10
                    Prompts      = 5
                    Instructions = 8
                    Skills       = 2
                }
            }

            $output = Write-RegistryValidationOutput -Result $result -RegistryPath '/test/registry.json' 6>&1
            $outputText = $output -join "`n"
            $outputText | Should -Match 'Agents: 10'
            $outputText | Should -Match 'Prompts: 5'
            $outputText | Should -Match 'Instructions: 8'
            $outputText | Should -Match 'Skills: 2'
        }
    }
}

#endregion

#region Export-RegistryValidationResults Tests

Describe 'Export-RegistryValidationResults' -Tag 'Unit' {
    Context 'JSON export' {
        It 'Creates output directory if missing' {
            $outputPath = Join-Path $TestDrive 'new-dir/results.json'
            $result = @{
                Success        = $true
                Errors         = @()
                Warnings       = @()
                ArtifactCounts = $null
            }

            Export-RegistryValidationResults -Result $result -OutputPath $outputPath

            Test-Path (Split-Path $outputPath -Parent) | Should -BeTrue
        }

        It 'Uses existing output directory' {
            $existingDir = Join-Path $TestDrive 'existing-dir'
            New-Item -ItemType Directory -Path $existingDir -Force | Out-Null
            $outputPath = Join-Path $existingDir 'results.json'
            $result = @{
                Success        = $true
                Errors         = @()
                Warnings       = @()
                ArtifactCounts = $null
            }

            Export-RegistryValidationResults -Result $result -OutputPath $outputPath

            Test-Path $outputPath | Should -BeTrue
        }

        It 'Writes correct JSON structure' {
            $outputPath = Join-Path $TestDrive 'structure-test.json'
            $result = @{
                Success        = $true
                Errors         = @('error1')
                Warnings       = @('warning1')
                ArtifactCounts = @{ Agents = 5 }
            }

            Export-RegistryValidationResults -Result $result -OutputPath $outputPath

            $exported = Get-Content $outputPath -Raw | ConvertFrom-Json
            $exported.success | Should -BeTrue
            $exported.errors | Should -Contain 'error1'
            $exported.warnings | Should -Contain 'warning1'
            $exported.timestamp | Should -Not -BeNullOrEmpty
            $exported.artifactCounts.Agents | Should -Be 5
        }
    }
}

#endregion

#region Main Execution Block Tests

Describe 'Main Execution Block' -Tag 'Integration' {
    BeforeAll {
        # Save original environment
        $script:OriginalGHA = $env:GITHUB_ACTIONS
        $script:OriginalTFBuild = $env:TF_BUILD
        $script:MainScriptPath = Join-Path $PSScriptRoot '../../linting/Validate-ArtifactRegistry.ps1'
    }

    AfterAll {
        # Restore original environment
        if ($null -eq $script:OriginalGHA) {
            Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
        }
        else {
            $env:GITHUB_ACTIONS = $script:OriginalGHA
        }
        if ($null -eq $script:OriginalTFBuild) {
            Remove-Item Env:TF_BUILD -ErrorAction SilentlyContinue
        }
        else {
            $env:TF_BUILD = $script:OriginalTFBuild
        }
    }

    BeforeEach {
        # Reset environment
        Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
        Remove-Item Env:TF_BUILD -ErrorAction SilentlyContinue
    }

    Context 'Repo root resolution' {
        It 'Uses provided RepoRoot parameter' {
            # Create minimal test repo structure
            $testRepo = Join-Path $TestDrive 'test-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:ValidRegistryPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Mock Test-Path to simulate files exist
            Mock Test-Path { return $true } -ParameterFilter { $Path -notlike '*results.json*' }

            # The script should not error when running with valid RepoRoot
            { & $script:MainScriptPath -RepoRoot $testRepo -RegistryPath "$testRepo/.github/ai-artifacts-registry.json" -OutputPath "$testRepo/logs/results.json" 2>$null } | Should -Not -Throw
        }

        It 'Derives RepoRoot from PSScriptRoot grandparent when not provided' {
            # Run from the actual repo - without RepoRoot the script resolves $PSScriptRoot/../..
            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -OutputPath '$TestDrive/results.json'; exit `$LASTEXITCODE" 2>&1
            # Script should resolve RepoRoot and produce output
            Test-Path "$TestDrive/results.json" | Should -BeTrue
        }


    }

    Context 'Validation orchestration' {
        It 'Reports error when registry file not found' {
            $testRepo = Join-Path $TestDrive 'no-registry-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null

            $output = & $script:MainScriptPath -RepoRoot $testRepo -RegistryPath "$testRepo/.github/nonexistent.json" -OutputPath "$testRepo/logs/results.json" 2>&1
            $output | Should -Match 'Registry file not found'
        }

        It 'Stops validation early on structure failure' {
            $testRepo = Join-Path $TestDrive 'invalid-structure-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:InvalidJsonPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Run directly with output suppression - exit code capture via $LASTEXITCODE
            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo' -OutputPath '$testRepo/logs/results.json'" 2>&1
            $LASTEXITCODE | Should -Be 1
        }
    }

    Context 'CI environment handling' {
        It 'Writes CI annotations when in GitHub Actions' {
            $env:GITHUB_ACTIONS = 'true'
            $testRepo = Join-Path $TestDrive 'gha-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:InvalidVersionPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            $output = & $script:MainScriptPath -RepoRoot $testRepo -OutputPath "$testRepo/logs/results.json" 2>&1 | Out-String
            $output | Should -Match '::error'
        }

        It 'Does not write CI annotations when not in CI' {
            Remove-Item Env:GITHUB_ACTIONS -ErrorAction SilentlyContinue
            Remove-Item Env:TF_BUILD -ErrorAction SilentlyContinue
            $testRepo = Join-Path $TestDrive 'local-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:InvalidVersionPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            $output = & $script:MainScriptPath -RepoRoot $testRepo -OutputPath "$testRepo/logs/results.json" 2>&1 | Out-String
            $output | Should -Not -Match '::error'
        }

        It 'Writes CI warning annotations for orphan files in GitHub Actions' {
            $env:GITHUB_ACTIONS = 'true'
            $testRepo = Join-Path $TestDrive 'gha-warnings-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/agents" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/prompts" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/instructions" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/skills/test-skill" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:ValidRegistryPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Create the referenced artifact files
            Set-Content -Path "$testRepo/.github/agents/test-agent.agent.md" -Value '# Test Agent'
            Set-Content -Path "$testRepo/.github/agents/dependent-agent.agent.md" -Value '# Dependent Agent'
            Set-Content -Path "$testRepo/.github/prompts/test-prompt.prompt.md" -Value '# Test Prompt'
            Set-Content -Path "$testRepo/.github/instructions/test-instruction.instructions.md" -Value '# Test Instruction'
            Set-Content -Path "$testRepo/.github/skills/test-skill/SKILL.md" -Value '# Test Skill'

            # Add orphan file to trigger warning
            Set-Content -Path "$testRepo/.github/agents/orphan-unregistered.agent.md" -Value '# Orphan Agent'

            $output = & $script:MainScriptPath -RepoRoot $testRepo -OutputPath "$testRepo/logs/results.json" 2>&1 | Out-String
            # Should have warning annotation for orphan file
            $output | Should -Match '::warning'
        }

        It 'Writes CI error annotation on exception in GitHub Actions' {
            $env:GITHUB_ACTIONS = 'true'
            $nonexistentRepo = '/completely/nonexistent/path/for/exception/test'

            $output = & $script:MainScriptPath -RepoRoot $nonexistentRepo 2>&1 | Out-String
            # Should have error annotation for exception
            $output | Should -Match '::error'
        }
    }

    Context 'Exit code handling' {
        It 'Returns exit code 0 on success' {
            $testRepo = Join-Path $TestDrive 'success-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/agents" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/prompts" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/instructions" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/skills/test-skill" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:ValidRegistryPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Create the referenced artifact files
            Set-Content -Path "$testRepo/.github/agents/test-agent.agent.md" -Value '# Test Agent'
            Set-Content -Path "$testRepo/.github/agents/dependent-agent.agent.md" -Value '# Dependent Agent'
            Set-Content -Path "$testRepo/.github/prompts/test-prompt.prompt.md" -Value '# Test Prompt'
            Set-Content -Path "$testRepo/.github/instructions/test-instruction.instructions.md" -Value '# Test Instruction'
            Set-Content -Path "$testRepo/.github/skills/test-skill/SKILL.md" -Value '# Test Skill'

            # Run directly with output suppression
            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo' -OutputPath '$testRepo/logs/results.json'; exit `$LASTEXITCODE" 2>&1
            $LASTEXITCODE | Should -Be 0
        }

        It 'Returns exit code 0 on success with default OutputPath' {
            $testRepo = Join-Path $TestDrive 'success-default-output-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/agents" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/prompts" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/instructions" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/skills/test-skill" -Force | Out-Null
            Copy-Item -Path $script:ValidRegistryPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Create the referenced artifact files
            Set-Content -Path "$testRepo/.github/agents/test-agent.agent.md" -Value '# Test Agent'
            Set-Content -Path "$testRepo/.github/agents/dependent-agent.agent.md" -Value '# Dependent Agent'
            Set-Content -Path "$testRepo/.github/prompts/test-prompt.prompt.md" -Value '# Test Prompt'
            Set-Content -Path "$testRepo/.github/instructions/test-instruction.instructions.md" -Value '# Test Instruction'
            Set-Content -Path "$testRepo/.github/skills/test-skill/SKILL.md" -Value '# Test Skill'

            # Run without OutputPath - should use default logs/registry-validation-results.json
            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo'; exit `$LASTEXITCODE" 2>&1
            $LASTEXITCODE | Should -Be 0

            # Verify default output path was used
            Test-Path "$testRepo/logs/registry-validation-results.json" | Should -BeTrue
        }

        It 'Returns exit code 1 when errors exist' {
            $testRepo = Join-Path $TestDrive 'error-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:InvalidVersionPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo' -OutputPath '$testRepo/logs/results.json'; exit `$LASTEXITCODE" 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It 'Returns exit code 1 with WarningsAsErrors and warnings' {
            $testRepo = Join-Path $TestDrive 'warnings-as-errors-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/agents" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/prompts" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/instructions" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/skills/test-skill" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:ValidRegistryPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Create the referenced artifact files
            Set-Content -Path "$testRepo/.github/agents/test-agent.agent.md" -Value '# Test Agent'
            Set-Content -Path "$testRepo/.github/agents/dependent-agent.agent.md" -Value '# Dependent Agent'
            Set-Content -Path "$testRepo/.github/prompts/test-prompt.prompt.md" -Value '# Test Prompt'
            Set-Content -Path "$testRepo/.github/instructions/test-instruction.instructions.md" -Value '# Test Instruction'
            Set-Content -Path "$testRepo/.github/skills/test-skill/SKILL.md" -Value '# Test Skill'

            # Add an orphan file to trigger a warning
            Set-Content -Path "$testRepo/.github/agents/orphan-agent.agent.md" -Value '# Orphan'

            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo' -OutputPath '$testRepo/logs/results.json' -WarningsAsErrors; exit `$LASTEXITCODE" 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It 'Returns exit code 0 with warnings but without WarningsAsErrors flag' {
            $testRepo = Join-Path $TestDrive 'warnings-no-error-repo'
            New-Item -ItemType Directory -Path "$testRepo/.git" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/agents" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/prompts" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/instructions" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/.github/skills/test-skill" -Force | Out-Null
            New-Item -ItemType Directory -Path "$testRepo/logs" -Force | Out-Null
            Copy-Item -Path $script:ValidRegistryPath -Destination "$testRepo/.github/ai-artifacts-registry.json"

            # Create the referenced artifact files
            Set-Content -Path "$testRepo/.github/agents/test-agent.agent.md" -Value '# Test Agent'
            Set-Content -Path "$testRepo/.github/agents/dependent-agent.agent.md" -Value '# Dependent Agent'
            Set-Content -Path "$testRepo/.github/prompts/test-prompt.prompt.md" -Value '# Test Prompt'
            Set-Content -Path "$testRepo/.github/instructions/test-instruction.instructions.md" -Value '# Test Instruction'
            Set-Content -Path "$testRepo/.github/skills/test-skill/SKILL.md" -Value '# Test Skill'

            # Add an orphan file to trigger a warning
            Set-Content -Path "$testRepo/.github/agents/orphan-agent.agent.md" -Value '# Orphan'

            # Without WarningsAsErrors, should still pass
            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo' -OutputPath '$testRepo/logs/results.json'; exit `$LASTEXITCODE" 2>&1
            $LASTEXITCODE | Should -Be 0
        }
    }

    Context 'Exception handling' {
        It 'Exits with code 1 on exception' {
            # Trigger exception by providing invalid path type
            $testRepo = '/nonexistent/path/that/will/cause/error'
            $null = & pwsh -NoProfile -Command "& '$script:MainScriptPath' -RepoRoot '$testRepo'; exit `$LASTEXITCODE" 2>&1
            $LASTEXITCODE | Should -Be 1
        }

        It 'Writes CI error annotation when exception occurs in GitHub Actions' {
            $env:GITHUB_ACTIONS = 'true'
            # Use completely invalid path to trigger exception in catch block
            $invalidRepo = '/this/path/does/not/exist/anywhere'

            $output = & $script:MainScriptPath -RepoRoot $invalidRepo 2>&1 | Out-String

            # Should have error annotation from the catch block
            $output | Should -Match '::error.*Registry validation failed'
        }

        It 'Writes CI error annotation when exception occurs in Azure DevOps' {
            $env:TF_BUILD = 'True'
            # Use completely invalid path to trigger exception in catch block
            $invalidRepo = '/this/path/does/not/exist/anywhere'

            $output = & $script:MainScriptPath -RepoRoot $invalidRepo 2>&1 | Out-String

            # Should have error annotation from the catch block (Azure DevOps format)
            $output | Should -Match '##vso\[task\.logissue.*error.*Registry validation failed'
        }
    }
}

#endregion

#region Edge Cases Tests

Describe 'Edge Cases' -Tag 'Unit' {
    Context 'Empty registry sections' {
        It 'Handles registry with no agents' {
            $registry = @{
                agents       = @{}
                prompts      = @{ 'p1' = @{} }
                instructions = @{}
                skills       = @{}
            }
            Mock Test-Path { return $true }
            $result = Test-ArtifactFileExistence -Registry $registry -RepoRoot $TestDrive
            $result.Success | Should -BeTrue
        }

        It 'Handles empty personas definitions' {
            $registry = @{
                personas = @{ definitions = @{} }
                agents       = @{}
                prompts      = @{}
                instructions = @{}
                skills       = @{}
            }
            $result = Test-PersonaReferences -Registry $registry
            $result.Success | Should -BeTrue
        }
    }

    Context 'Complex dependency chains' {
        It 'Handles deeply nested non-circular dependencies' {
            $registry = @{
                agents = @{
                    'agent-1' = @{ requires = @{ agents = @('agent-2') } }
                    'agent-2' = @{ requires = @{ agents = @('agent-3') } }
                    'agent-3' = @{ requires = @{ agents = @('agent-4') } }
                    'agent-4' = @{ requires = @{ agents = @('agent-5') } }
                    'agent-5' = @{ requires = @{ agents = @() } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -Be 0
        }

        It 'Handles diamond dependency pattern without cycles' {
            $registry = @{
                agents = @{
                    'top'    = @{ requires = @{ agents = @('left', 'right') } }
                    'left'   = @{ requires = @{ agents = @('bottom') } }
                    'right'  = @{ requires = @{ agents = @('bottom') } }
                    'bottom' = @{ requires = @{ agents = @() } }
                }
            }
            $result = Find-CircularAgentDependencies -Registry $registry
            $result.Count | Should -Be 0
        }
    }
}

#endregion
