#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

[System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
param()

# Declared at discovery scope so the parameterized tests below are expanded.
$script:TombstoneComponents = @(
    @{
        PackagePath = 'skills/security/owasp-docker'
        SourcePath  = '.github/skills/security/owasp-docker/SKILL.md'
        Leaf        = 'owasp-docker'
        Sentinel    = 'sentinel_tombstone_docker'
    }
    @{
        PackagePath = 'agents/security/legacy-scanner.md'
        SourcePath  = '.github/agents/security/legacy-scanner.agent.md'
        Leaf        = 'legacy-scanner'
        Sentinel    = 'sentinel_tombstone_agent'
    }
)

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Generate-Plugins.ps1')
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {}
    Mock Write-Host {} -ModuleName PluginHelpers
    Mock Write-Warning {}
    Mock Write-Warning {} -ModuleName PluginHelpers

    function New-TombstoneFixture {
        <#
        .SYNOPSIS
        Builds a catalog whose package declares retired and retained components.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter()][switch]$WithoutTombstones
        )

        New-PluginFixtureRepository -Path $Root -Version '9.9.9' | Out-Null
        Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/skills/security/owasp-llm/SKILL.md' `
            -Content "---`nname: owasp-llm`ndescription: LLM security knowledge base`n---`n`n# OWASP LLM`n" | Out-Null
        Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/skills/security/owasp-docker/SKILL.md' `
            -Content "---`nname: owasp-docker`ndescription: Retired container knowledge base`n---`n`nsentinel_tombstone_docker`n" | Out-Null
        Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/agents/security/security-planner.agent.md' `
            -Content "---`ndescription: Plans security work`n---`n`n# Security Planner`n" | Out-Null
        Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/agents/security/legacy-scanner.agent.md' `
            -Content "---`ndescription: Retired scanner`n---`n`nsentinel_tombstone_agent`n" | Out-Null

        $overlay = if ($WithoutTombstones) {
            @{}
        }
        else {
            @{
                componentMaturity = @{
                    'skills/security/owasp-docker'      = 'removed'
                    'agents/security/legacy-scanner.md' = 'removed'
                }
            }
        }

        Add-PluginFixtureCatalog -RepoRoot $Root -Version '9.9.9' -Entries @(
            New-PluginFixtureEntry -Name 'security' -Description 'Security package' -Version '9.9.9' `
                -Agents @('agents/security/security-planner.md', 'agents/security/legacy-scanner.md') `
                -Skills @('skills/security/owasp-llm', 'skills/security/owasp-docker') `
                -Overlay $overlay
        ) | Out-Null

        return $Root
    }

    function Get-RemovedComponentTombstone {
        <#
        .SYNOPSIS
        Discovers removed component tombstones straight from a catalog file.

        .DESCRIPTION
        Reads the catalog JSON without consulting the marketplace helpers, so
        the tombstone set under test is derived independently of the projection
        the generator uses.
        #>
        param([Parameter(Mandatory)][string]$CatalogPath)

        $catalog = Get-Content -LiteralPath $CatalogPath -Raw | ConvertFrom-Json -AsHashtable
        $tombstones = [System.Collections.Generic.List[string]]::new()
        foreach ($entry in @($catalog['plugins'])) {
            if (-not $entry.Contains('x-hve') -or -not $entry['x-hve'].Contains('componentMaturity')) {
                continue
            }
            $componentMaturity = $entry['x-hve']['componentMaturity']
            foreach ($componentPath in @($componentMaturity.Keys)) {
                if ([string]$componentMaturity[$componentPath] -eq 'removed') {
                    $tombstones.Add([string]$componentPath)
                }
            }
        }
        return [string[]]@($tombstones | Sort-Object)
    }
}

Describe 'Removed component tombstones' -Tag 'Unit' {
    BeforeEach {
        $script:tombstoneRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
    }

    Context 'when the catalog retires components' {
        BeforeEach {
            New-TombstoneFixture -Root $script:tombstoneRepo | Out-Null
            $script:discoveredTombstones = Get-RemovedComponentTombstone -CatalogPath (Join-Path $script:tombstoneRepo '.github/plugin/marketplace.json')

            Invoke-PluginGeneration -RepoRoot $script:tombstoneRepo -Refresh | Out-Null
            $script:generatedRoot = Join-Path $script:tombstoneRepo 'plugins/security'
            $script:generatedPaths = @(Get-PluginFixtureInventory -Path $script:generatedRoot)
            $script:generatedText = @(Get-ChildItem -LiteralPath $script:generatedRoot -File -Recurse -Force |
                    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
        }

        It 'Discovers a non-empty tombstone set before any exclusion is applied' {
            @($script:discoveredTombstones) | Should -Not -BeNullOrEmpty
            @($script:discoveredTombstones) | Should -Be @(
                @('skills/security/owasp-docker', 'agents/security/legacy-scanner.md') | Sort-Object
            )
        }

        It 'Still generates the retained components' {
            $script:generatedPaths | Should -Contain 'skills/security/owasp-llm/SKILL.md'
            $script:generatedPaths | Should -Contain 'agents/security/security-planner.md'
        }

        It 'Leaks no package path for the tombstoned component <PackagePath>' -ForEach $script:TombstoneComponents {
            $componentPrefix = $PackagePath
            @($script:generatedPaths | Where-Object { $_ -eq $componentPrefix -or $_.StartsWith("$componentPrefix/") }) |
                Should -HaveCount 0
        }

        It 'Leaks no source leaf name for the tombstoned component <Leaf>' -ForEach $script:TombstoneComponents {
            @($script:generatedPaths | Where-Object { $_ -match [regex]::Escape($Leaf) }) | Should -HaveCount 0
        }

        It 'Leaks no content sentinel for the tombstoned component <Leaf>' -ForEach $script:TombstoneComponents {
            $script:generatedText | Should -Not -Match ([regex]::Escape($Sentinel))
            $script:generatedText | Should -Not -Match ([regex]::Escape($Leaf))
        }

        It 'Omits the tombstoned components from the generated README' {
            $readme = Get-Content -LiteralPath (Join-Path $script:generatedRoot 'README.md') -Raw
            $readme | Should -Match 'owasp-llm'
            $readme | Should -Match 'security-planner'
            $readme | Should -Not -Match 'owasp-docker'
            $readme | Should -Not -Match 'legacy-scanner'
        }

        It 'Omits the tombstoned components from the generated manifest' {
            $manifest = Get-Content -LiteralPath (Join-Path $script:generatedRoot 'plugin.json') -Raw
            $manifest | Should -Match 'skills/security/owasp-llm/'
            $manifest | Should -Not -Match 'owasp-docker'
            $manifest | Should -Not -Match 'legacy-scanner'
        }
    }

    Context 'when the same catalog declares no tombstone' {
        BeforeEach {
            New-TombstoneFixture -Root $script:tombstoneRepo -WithoutTombstones | Out-Null
            $script:controlTombstones = Get-RemovedComponentTombstone -CatalogPath (Join-Path $script:tombstoneRepo '.github/plugin/marketplace.json')
            Invoke-PluginGeneration -RepoRoot $script:tombstoneRepo -Refresh | Out-Null
            $script:controlPaths = @(Get-PluginFixtureInventory -Path (Join-Path $script:tombstoneRepo 'plugins/security'))
        }

        It 'Discovers an empty tombstone set' {
            @($script:controlTombstones) | Should -HaveCount 0
        }

        It 'Generates the components the tombstoned run excluded' {
            $script:controlPaths | Should -Contain 'skills/security/owasp-docker/SKILL.md'
            $script:controlPaths | Should -Contain 'agents/security/legacy-scanner.md'
        }
    }
}

AfterAll {
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}
