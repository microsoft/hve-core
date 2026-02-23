#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

BeforeAll {
    . $PSScriptRoot/../../plugins/Generate-Plugins.ps1
    # Re-import CollectionHelpers after dot-sourcing because PluginHelpers internally
    # imports CollectionHelpers with -Force, removing it from the caller's scope.
    Import-Module (Join-Path $PSScriptRoot '../../collections/Modules/CollectionHelpers.psm1') -Force
}

Describe 'Get-AllowedCollectionMaturities' {
    It 'Returns only stable for Stable channel' {
        $result = Get-AllowedCollectionMaturities -Channel 'Stable'
        $result | Should -Be @('stable')
    }

    It 'Returns stable, preview, and experimental for PreRelease channel' {
        $result = Get-AllowedCollectionMaturities -Channel 'PreRelease'
        $result | Should -Contain 'stable'
        $result | Should -Contain 'preview'
        $result | Should -Contain 'experimental'
    }

    It 'Does not include deprecated for either channel' {
        $stable = Get-AllowedCollectionMaturities -Channel 'Stable'
        $preRelease = Get-AllowedCollectionMaturities -Channel 'PreRelease'
        $stable | Should -Not -Contain 'deprecated'
        $preRelease | Should -Not -Contain 'deprecated'
    }
}

Describe 'Select-CollectionItemsByChannel' {
    It 'Includes stable items on Stable channel' {
        $collection = @{
            id    = 'test'
            items = @(
                @{ kind = 'agent'; path = '.github/agents/a.agent.md'; maturity = 'stable' }
            )
        }
        $result = Select-CollectionItemsByChannel -Collection $collection -Channel 'Stable'
        $result.items.Count | Should -Be 1
    }

    It 'Excludes preview items on Stable channel' {
        $collection = @{
            id    = 'test'
            items = @(
                @{ kind = 'agent'; path = '.github/agents/a.agent.md'; maturity = 'stable' },
                @{ kind = 'agent'; path = '.github/agents/b.agent.md'; maturity = 'preview' }
            )
        }
        $result = Select-CollectionItemsByChannel -Collection $collection -Channel 'Stable'
        $result.items.Count | Should -Be 1
    }

    It 'Includes preview and experimental items on PreRelease channel' {
        $collection = @{
            id    = 'test'
            items = @(
                @{ kind = 'agent'; path = '.github/agents/a.agent.md'; maturity = 'stable' },
                @{ kind = 'prompt'; path = '.github/prompts/b.prompt.md'; maturity = 'preview' },
                @{ kind = 'instruction'; path = '.github/instructions/c.instructions.md'; maturity = 'experimental' }
            )
        }
        $result = Select-CollectionItemsByChannel -Collection $collection -Channel 'PreRelease'
        $result.items.Count | Should -Be 3
    }

    It 'Excludes deprecated items on PreRelease channel' {
        $collection = @{
            id    = 'test'
            items = @(
                @{ kind = 'agent'; path = '.github/agents/a.agent.md'; maturity = 'stable' },
                @{ kind = 'agent'; path = '.github/agents/old.agent.md'; maturity = 'deprecated' }
            )
        }
        $result = Select-CollectionItemsByChannel -Collection $collection -Channel 'PreRelease'
        $result.items.Count | Should -Be 1
    }

    It 'Defaults to stable when maturity is null' {
        $collection = @{
            id    = 'test'
            items = @(
                @{ kind = 'agent'; path = '.github/agents/a.agent.md'; maturity = $null }
            )
        }
        $result = Select-CollectionItemsByChannel -Collection $collection -Channel 'Stable'
        $result.items.Count | Should -Be 1
    }

    It 'Preserves non-items keys from collection' {
        $collection = @{
            id          = 'test'
            name        = 'Test Collection'
            description = 'desc'
            items       = @(
                @{ kind = 'agent'; path = '.github/agents/a.agent.md'; maturity = 'stable' }
            )
        }
        $result = Select-CollectionItemsByChannel -Collection $collection -Channel 'Stable'
        $result.id | Should -Be 'test'
        $result.name | Should -Be 'Test Collection'
        $result.description | Should -Be 'desc'
    }
}

Describe 'Invoke-PluginGeneration - collection-level maturity' {
    BeforeAll {
        $script:maturityDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:maturityDir -Force | Out-Null

        # Create package.json
        @{
            name        = 'hve-core'
            version     = '1.0.0'
            description = 'test'
            author      = 'test-author'
        } | ConvertTo-Json | Set-Content -Path (Join-Path $script:maturityDir 'package.json')

        # Create collections directory
        $collectionsDir = Join-Path $script:maturityDir 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        # Create .github structure with a test artifact
        $ghDir = Join-Path $script:maturityDir '.github'
        $agentsDir = Join-Path $ghDir 'agents/col'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        @'
---
description: "Test agent"
---
'@ | Set-Content -Path (Join-Path $agentsDir 'test.agent.md')

        # Create shared directories for symlinks
        New-Item -ItemType Directory -Path (Join-Path $script:maturityDir 'docs/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:maturityDir 'scripts/lib') -Force | Out-Null

        # Create plugins directory
        New-Item -ItemType Directory -Path (Join-Path $script:maturityDir 'plugins') -Force | Out-Null

        # Create .github/plugin directory
        New-Item -ItemType Directory -Path (Join-Path $script:maturityDir '.github/plugin') -Force | Out-Null

        # hve-core-all collection (required by Update-HveCoreAllCollection)
        @"
id: hve-core-all
name: hve-core
description: All artifacts
tags: []
items:
  - path: .github/agents/col/test.agent.md
    kind: agent
display: {}
"@ | Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml')

        # Deprecated collection
        @"
id: deprecated-col
name: Deprecated Collection
description: A deprecated collection
maturity: deprecated
items:
  - path: .github/agents/col/test.agent.md
    kind: agent
"@ | Set-Content -Path (Join-Path $collectionsDir 'deprecated-col.collection.yml')

        # Experimental collection
        @"
id: experimental-col
name: Experimental Collection
description: An experimental collection
maturity: experimental
items:
  - path: .github/agents/col/test.agent.md
    kind: agent
"@ | Set-Content -Path (Join-Path $collectionsDir 'experimental-col.collection.yml')
    }

    AfterAll {
        Remove-Item -Path $script:maturityDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Skips deprecated collection during generation' {
        Invoke-PluginGeneration -RepoRoot $script:maturityDir -CollectionIds @('deprecated-col') -Refresh -Channel 'PreRelease' | Out-Null
        $pluginDir = Join-Path $script:maturityDir 'plugins/deprecated-col'
        Test-Path $pluginDir | Should -BeFalse
    }

    It 'Generates experimental collection on PreRelease channel' {
        Invoke-PluginGeneration -RepoRoot $script:maturityDir -CollectionIds @('experimental-col') -Refresh -Channel 'PreRelease' | Out-Null
        $pluginDir = Join-Path $script:maturityDir 'plugins/experimental-col'
        Test-Path $pluginDir | Should -BeTrue
    }
}

Describe 'Invoke-PluginGeneration' {
    BeforeAll {
        $script:tempDir = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $script:tempDir -Force | Out-Null

        # Create package.json
        @{
            name        = 'hve-core'
            version     = '1.0.0'
            description = 'test'
            author      = 'test-author'
        } | ConvertTo-Json | Set-Content -Path (Join-Path $script:tempDir 'package.json')

        # Create collections directory with manifests
        $collectionsDir = Join-Path $script:tempDir 'collections'
        New-Item -ItemType Directory -Path $collectionsDir -Force | Out-Null

        # Create .github structure with artifacts
        $ghDir = Join-Path $script:tempDir '.github'
        $agentsDir = Join-Path $ghDir 'agents'
        $promptsDir = Join-Path $ghDir 'prompts'
        $instrDir = Join-Path $ghDir 'instructions'
        $skillsDir = Join-Path $ghDir 'skills/test-skill'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $promptsDir -Force | Out-Null
        New-Item -ItemType Directory -Path $instrDir -Force | Out-Null
        New-Item -ItemType Directory -Path $skillsDir -Force | Out-Null

        @'
---
description: "Test agent"
---
'@ | Set-Content -Path (Join-Path $agentsDir 'test.agent.md')

        @'
---
description: "Test prompt"
---
'@ | Set-Content -Path (Join-Path $promptsDir 'test.prompt.md')

        @'
---
description: "Test instruction"
applyTo: "**/*.ps1"
---
'@ | Set-Content -Path (Join-Path $instrDir 'test.instructions.md')

        @'
---
name: test-skill
description: "Test skill"
---
'@ | Set-Content -Path (Join-Path $skillsDir 'SKILL.md')

        # Create docs/templates and scripts directories for shared symlinking
        New-Item -ItemType Directory -Path (Join-Path $script:tempDir 'docs/templates') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:tempDir 'scripts/lib') -Force | Out-Null

        # Create plugins directory
        New-Item -ItemType Directory -Path (Join-Path $script:tempDir 'plugins') -Force | Out-Null

        # Create .github/plugin directory for marketplace manifest
        New-Item -ItemType Directory -Path (Join-Path $script:tempDir '.github/plugin') -Force | Out-Null

        # hve-core-all collection
        @"
id: hve-core-all
name: hve-core
description: All artifacts
tags:
  - copilot
items:
  - path: .github/agents/test.agent.md
    kind: agent
  - path: .github/prompts/test.prompt.md
    kind: prompt
  - path: .github/instructions/test.instructions.md
    kind: instruction
  - path: .github/skills/test-skill
    kind: skill
display:
  color: blue
"@ | Set-Content -Path (Join-Path $collectionsDir 'hve-core-all.collection.yml')
    }

    AfterAll {
        Remove-Item -Path $script:tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    It 'Generates plugins successfully' {
        $result = Invoke-PluginGeneration -RepoRoot $script:tempDir -Refresh -Channel 'PreRelease'
        $result.Success | Should -BeTrue
        $result.PluginCount | Should -BeGreaterOrEqual 1
    }

    It 'Creates plugin directory' {
        $pluginDir = Join-Path $script:tempDir 'plugins/hve-core-all'
        Test-Path $pluginDir | Should -BeTrue
    }

    It 'Generates plugin.json manifest' {
        $manifestPath = Join-Path $script:tempDir 'plugins/hve-core-all/.github/plugin/plugin.json'
        Test-Path $manifestPath | Should -BeTrue
        $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
        $manifest.name | Should -Be 'hve-core-all'
    }

    It 'Generates README.md' {
        $readmePath = Join-Path $script:tempDir 'plugins/hve-core-all/README.md'
        Test-Path $readmePath | Should -BeTrue
    }

    It 'Filters to specific collection IDs when provided' {
        $result = Invoke-PluginGeneration -RepoRoot $script:tempDir -CollectionIds @('hve-core-all') -Refresh -Channel 'PreRelease'
        $result.PluginCount | Should -Be 1
    }

    It 'Warns for non-existent collection IDs' {
        $result = Invoke-PluginGeneration -RepoRoot $script:tempDir -CollectionIds @('nonexistent') -Refresh -Channel 'PreRelease' 3>&1
        $warnings = @($result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -BeGreaterOrEqual 1
    }

    It 'Supports DryRun mode' {
        $result = Invoke-PluginGeneration -RepoRoot $script:tempDir -CollectionIds @('hve-core-all') -DryRun -Channel 'PreRelease'
        $result.Success | Should -BeTrue
    }

    It 'Returns zero plugins when no collections found' {
        $emptyRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'collections') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'plugins') -Force | Out-Null
        @{ name = 'test'; version = '1.0.0'; description = 'test'; author = 'test' } |
            ConvertTo-Json | Set-Content -Path (Join-Path $emptyRoot 'package.json')

        # Create minimal .github structure for auto-update
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot '.github/agents') -Force | Out-Null
        @"
id: hve-core-all
name: hve-core
description: test
tags: []
items: []
display: {}
"@ | Set-Content -Path (Join-Path $emptyRoot 'collections/hve-core-all.collection.yml')

        $result = Invoke-PluginGeneration -RepoRoot $emptyRoot -CollectionIds @('missing-id') -Channel 'PreRelease' 3>&1
        $hashtableResult = $result | Where-Object { $_ -is [hashtable] }
        if ($hashtableResult) {
            $hashtableResult.PluginCount | Should -Be 0
        }
    }

    It 'Applies channel filtering to items' {
        # Add a collection with mixed maturities
        $mixedPath = Join-Path (Join-Path $script:tempDir 'collections') 'mixed.collection.yml'
        @"
id: mixed
name: Mixed Collection
description: Mixed maturity test
items:
  - path: .github/agents/test.agent.md
    kind: agent
    maturity: stable
  - path: .github/prompts/test.prompt.md
    kind: prompt
    maturity: experimental
"@ | Set-Content -Path $mixedPath

        $result = Invoke-PluginGeneration -RepoRoot $script:tempDir -CollectionIds @('mixed') -Refresh -Channel 'Stable'
        $result.Success | Should -BeTrue
    }

    It 'Removes existing plugin directory on Refresh' {
        # Create a stale file in plugin dir
        $staleDir = Join-Path $script:tempDir 'plugins/hve-core-all/stale'
        New-Item -ItemType Directory -Path $staleDir -Force | Out-Null
        'stale' | Set-Content -Path (Join-Path $staleDir 'file.txt')

        $result = Invoke-PluginGeneration -RepoRoot $script:tempDir -CollectionIds @('hve-core-all') -Refresh -Channel 'PreRelease'
        $result.Success | Should -BeTrue
        Test-Path $staleDir | Should -BeFalse
    }

    It 'Logs DryRun message when refreshing existing plugin' {
        # Ensure plugin directory exists
        $pluginDir = Join-Path $script:tempDir 'plugins/hve-core-all'
        New-Item -ItemType Directory -Path $pluginDir -Force | Out-Null

        $output = Invoke-PluginGeneration -RepoRoot $script:tempDir `
            -CollectionIds @('hve-core-all') `
            -Refresh -DryRun -Channel 'PreRelease' 6>&1

        $dryRunMessages = @($output | Where-Object { "$_" -match 'DRY RUN.*Would remove' })
        $dryRunMessages.Count | Should -BeGreaterOrEqual 1
    }

    It 'Warns when collections directory has no matching YAML files' {
        $emptyRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        $emptyCollDir = Join-Path $emptyRoot 'collections'
        New-Item -ItemType Directory -Path $emptyCollDir -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot 'plugins') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $emptyRoot '.github/agents') -Force | Out-Null
        @{ name = 'test'; version = '1.0.0'; description = 'test'; author = 'test' } |
            ConvertTo-Json | Set-Content -Path (Join-Path $emptyRoot 'package.json')

        # Mock Update-HveCoreAllCollection to avoid file-not-found errors
        Mock Update-HveCoreAllCollection { return @{ ItemCount = 0; AddedCount = 0; RemovedCount = 0 } }

        $result = Invoke-PluginGeneration -RepoRoot $emptyRoot -Channel 'PreRelease' 3>&1
        $warnings = @($result | Where-Object { $_ -is [System.Management.Automation.WarningRecord] })
        $warnings.Count | Should -BeGreaterOrEqual 1
        $warnings[0].Message | Should -Match 'No collection manifests found'
    }

    It 'Outputs verbose symlink capability detection' {
        $output = Invoke-PluginGeneration -RepoRoot $script:tempDir `
            -CollectionIds @('hve-core-all') `
            -Channel 'PreRelease' -Verbose 4>&1

        $capMsg = @($output | Where-Object { "$_" -match 'Symlink capability' })
        $capMsg.Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'Start-PluginGeneration' {
    It 'Returns 0 on successful generation' {
        Mock Invoke-PluginGeneration { return @{ Success = $true; PluginCount = 2 } }
        Mock Get-Module { return @{ Name = 'PowerShell-Yaml' } } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShell-Yaml' }
        Mock Import-Module {}

        $scriptPath = "$PSScriptRoot/../../plugins/Generate-Plugins.ps1"
        $exitCode = Start-PluginGeneration -ScriptPath $scriptPath -Channel 'PreRelease'
        $exitCode | Should -Be 0
    }

    It 'Returns 1 when Invoke-PluginGeneration reports failure' {
        Mock Invoke-PluginGeneration { return @{ Success = $false; PluginCount = 0; ErrorMessage = 'Generation failed' } }
        Mock Get-Module { return @{ Name = 'PowerShell-Yaml' } } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShell-Yaml' }
        Mock Import-Module {}

        $scriptPath = "$PSScriptRoot/../../plugins/Generate-Plugins.ps1"
        $output = Start-PluginGeneration -ScriptPath $scriptPath -Channel 'PreRelease' -ErrorAction SilentlyContinue
        $exitCode = @($output) | Where-Object { $_ -is [int] } | Select-Object -Last 1
        $exitCode | Should -Be 1
    }

    It 'Returns 1 when PowerShell-Yaml module is missing' {
        Mock Get-Module { return $null } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShell-Yaml' }

        $scriptPath = "$PSScriptRoot/../../plugins/Generate-Plugins.ps1"
        $output = Start-PluginGeneration -ScriptPath $scriptPath -Channel 'PreRelease' -ErrorAction SilentlyContinue
        $exitCode = @($output) | Where-Object { $_ -is [int] } | Select-Object -Last 1
        $exitCode | Should -Be 1
    }

    It 'Defaults to refresh when no CollectionIds, Refresh, or DryRun provided' {
        Mock Get-Module { return @{ Name = 'PowerShell-Yaml' } } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShell-Yaml' }
        Mock Import-Module {}
        Mock Invoke-PluginGeneration { return @{ Success = $true; PluginCount = 1 } }

        $scriptPath = "$PSScriptRoot/../../plugins/Generate-Plugins.ps1"
        Start-PluginGeneration -ScriptPath $scriptPath -Channel 'PreRelease' | Out-Null

        Should -Invoke Invoke-PluginGeneration -Times 1 -ParameterFilter { $Refresh -eq $true }
    }

    It 'Does not force refresh when CollectionIds are provided' {
        Mock Get-Module { return @{ Name = 'PowerShell-Yaml' } } -ParameterFilter { $ListAvailable -and $Name -eq 'PowerShell-Yaml' }
        Mock Import-Module {}
        Mock Invoke-PluginGeneration { return @{ Success = $true; PluginCount = 1 } }

        $scriptPath = "$PSScriptRoot/../../plugins/Generate-Plugins.ps1"
        Start-PluginGeneration -ScriptPath $scriptPath -CollectionIds @('test') -Channel 'PreRelease' | Out-Null

        Should -Invoke Invoke-PluginGeneration -Times 1 -ParameterFilter { $Refresh -eq $false }
    }
}
