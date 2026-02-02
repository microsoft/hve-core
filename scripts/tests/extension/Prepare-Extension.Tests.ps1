#Requires -Modules Pester

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

    Context 'Error handling' {
        It 'Handles malformed YAML frontmatter gracefully' {
            $testFile = Join-Path $script:tempDir 'malformed.md'
            @'
---
description: "unclosed quote
maturity: [invalid yaml
---
# Content
'@ | Set-Content -Path $testFile

            # Should not throw - function handles YAML errors with warning
            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback' 3>&1
            $result | Should -Not -BeNullOrEmpty
        }

        It 'Handles file without frontmatter' {
            $testFile = Join-Path $script:tempDir 'no-frontmatter.md'
            @'
# Just a heading
No frontmatter here
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'default-desc'
            $result.description | Should -Be 'default-desc'
            $result.maturity | Should -Be 'stable'
        }

        It 'Handles empty frontmatter' {
            $testFile = Join-Path $script:tempDir 'empty-frontmatter.md'
            @'
---
---
# Content
'@ | Set-Content -Path $testFile

            $result = Get-FrontmatterData -FilePath $testFile -FallbackDescription 'fallback'
            $result.description | Should -Be 'fallback'
        }
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

Describe 'Invoke-ExtensionPreparation' -Tag 'Unit' {
    BeforeEach {
        $script:originalLocation = Get-Location
        Set-Location $TestDrive

        # Create minimal valid extension structure
        New-Item -Path 'extension' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github/agents' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github/prompts' -ItemType Directory -Force | Out-Null
        New-Item -Path '.github/instructions' -ItemType Directory -Force | Out-Null

        $packageJson = @{
            name = 'test-extension'
            version = '1.0.0'
            publisher = 'test-publisher'
            engines = @{ vscode = '^1.80.0' }
            contributes = @{}
        }
        $packageJson | ConvertTo-Json -Depth 10 | Set-Content -Path 'extension/package.json'
    }

    AfterEach {
        Set-Location $script:originalLocation
    }

    Context 'Function availability' {
        It 'Function is accessible after script load' {
            Get-Command Invoke-ExtensionPreparation | Should -Not -BeNullOrEmpty
        }

        It 'Has expected parameter set' {
            $cmd = Get-Command Invoke-ExtensionPreparation
            $cmd.Parameters.Keys | Should -Contain 'Channel'
            $cmd.Parameters.Keys | Should -Contain 'DryRun'
            $cmd.Parameters.Keys | Should -Contain 'ChangelogPath'
        }

        It 'Channel parameter validates allowed values' {
            $cmd = Get-Command Invoke-ExtensionPreparation
            $channelParam = $cmd.Parameters['Channel']
            $validateSetAttr = $channelParam.Attributes | Where-Object { $_ -is [System.Management.Automation.ValidateSetAttribute] }
            $validateSetAttr.ValidValues | Should -Contain 'Stable'
            $validateSetAttr.ValidValues | Should -Contain 'PreRelease'
        }
    }

    Context 'Helper functions integration' {
        It 'Get-AllowedMaturities returns expected values for Stable' {
            $result = Get-AllowedMaturities -Channel 'Stable'
            $result | Should -Contain 'stable'
            $result | Should -Not -Contain 'preview'
        }

        It 'Get-AllowedMaturities returns expected values for PreRelease' {
            $result = Get-AllowedMaturities -Channel 'PreRelease'
            $result | Should -Contain 'stable'
            $result | Should -Contain 'preview'
            $result | Should -Contain 'experimental'
        }
    }
}
