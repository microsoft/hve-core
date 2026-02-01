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

    It 'Extracts description and maturity from frontmatter' {
        $testFile = Join-Path $script:tempDir 'test.md'
        @'
---
description: "Test description"
maturity: preview
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
        $result.description | Should -Be 'Test description'
        $result.maturity | Should -Be 'preview'
    }

    It 'Uses fallback description when not in frontmatter' {
        $testFile = Join-Path $script:tempDir 'no-desc.md'
        @'
---
maturity: stable
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'My Fallback'
        $result.description | Should -Be 'My Fallback'
    }

    It 'Defaults maturity to stable when not specified' {
        $testFile = Join-Path $script:tempDir 'no-maturity.md'
        @'
---
description: "Desc"
---
# Content
'@ | Set-Content -Path $testFile

        $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
        $result.maturity | Should -Be 'stable'
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
maturity: stable
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'stable.agent.md')

        @'
---
description: "Preview agent"
maturity: preview
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
        $result = Get-DiscoveredAgents -AgentsDir $script:agentsDir -AllowedMaturities @('stable') -ExcludedAgents @()
        $result.Agents.Count | Should -Be 1
        $result.Skipped.Count | Should -Be 1
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
maturity: stable
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
maturity: stable
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

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents $agents -ChatPromptFiles $prompts -ChatInstructions $instructions
        $result.contributes | Should -Not -BeNullOrEmpty
    }

    It 'Handles empty arrays' {
        $packageJson = [PSCustomObject]@{
            name = 'test-extension'
            contributes = [PSCustomObject]@{}
        }

        $result = Update-PackageJsonContributes -PackageJson $packageJson -ChatAgents @() -ChatPromptFiles @() -ChatInstructions @()
        $result | Should -Not -BeNullOrEmpty
    }
}

Describe 'New-PrepareResult' {
    It 'Creates success result with counts' {
        $result = New-PrepareResult -Success $true -AgentCount 5 -PromptCount 10 -InstructionCount 15 -Version '1.0.0'
        $result.Success | Should -BeTrue
        $result.AgentCount | Should -Be 5
        $result.PromptCount | Should -Be 10
        $result.InstructionCount | Should -Be 15
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
maturity: stable
---
# Agent
'@ | Set-Content -Path (Join-Path $script:agentsDir 'test.agent.md')

        # Create test prompt
        @'
---
description: "Test prompt"
maturity: stable
---
# Prompt
'@ | Set-Content -Path (Join-Path $script:promptsDir 'test.prompt.md')

        # Create test instruction
        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
maturity: stable
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
maturity: preview
---
'@ | Set-Content -Path (Join-Path $script:agentsDir 'preview.agent.md')

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
maturity: experimental
---
'@ | Set-Content -Path (Join-Path $script:promptsDir 'experimental.prompt.md')

        # Add preview instruction
        @'
---
description: "Preview instruction"
applyTo: "**/*.js"
maturity: preview
---
'@ | Set-Content -Path (Join-Path $script:instrDir 'preview.instructions.md')

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

        # Stable should have fewer prompts and instructions than PreRelease
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
}
