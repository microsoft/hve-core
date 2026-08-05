#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force
}

Describe 'Get-MarketplaceEntryOverlayValue' -Tag 'Unit' {
    It 'Returns null when the entry has no overlay' {
        Get-MarketplaceEntryOverlayValue -Entry @{ name = 'demo' } -Key 'maturity' | Should -BeNullOrEmpty
    }

    It 'Returns null when the overlay is not an object' {
        Get-MarketplaceEntryOverlayValue -Entry @{ name = 'demo'; 'x-hve' = 'preview' } -Key 'maturity' | Should -BeNullOrEmpty
    }

    It 'Returns null when the overlay omits the key' {
        Get-MarketplaceEntryOverlayValue -Entry @{ name = 'demo'; 'x-hve' = @{ displayName = 'Demo' } } -Key 'maturity' |
            Should -BeNullOrEmpty
    }

    It 'Returns the declared overlay value' {
        Get-MarketplaceEntryOverlayValue -Entry @{ name = 'demo'; 'x-hve' = @{ maturity = 'preview' } } -Key 'maturity' |
            Should -BeExactly 'preview'
    }

    It 'Distinguishes a declared empty value from an absent key' {
        $value = Get-MarketplaceEntryOverlayValue -Entry @{ name = 'demo'; 'x-hve' = @{ displayName = '' } } -Key 'displayName'
        $value -is [string] | Should -BeTrue
        $value | Should -BeExactly ''
        Get-MarketplaceEntryOverlayValue -Entry @{ name = 'demo'; 'x-hve' = @{} } -Key 'displayName' | Should -BeNullOrEmpty
    }

    It 'Returns the componentMaturity dictionary intact' {
        $value = Get-MarketplaceEntryOverlayValue -Entry @{
            name    = 'demo'
            'x-hve' = @{ componentMaturity = @{ 'agents/demo/first.md' = 'preview' } }
        } -Key 'componentMaturity'
        $value | Should -BeOfType [System.Collections.IDictionary]
        $value['agents/demo/first.md'] | Should -BeExactly 'preview'
    }
}

Describe 'Get-MarketplaceEntryMaturity' -Tag 'Unit' {
    It 'Defaults to stable when no overlay is declared' {
        Get-MarketplaceEntryMaturity -Entry @{ name = 'demo' } | Should -BeExactly 'stable'
    }

    It 'Defaults to stable when the overlay omits maturity' {
        Get-MarketplaceEntryMaturity -Entry @{ name = 'demo'; 'x-hve' = @{ displayName = 'Demo' } } | Should -BeExactly 'stable'
    }

    It 'Defaults to stable when maturity is whitespace' {
        Get-MarketplaceEntryMaturity -Entry @{ name = 'demo'; 'x-hve' = @{ maturity = '   ' } } | Should -BeExactly 'stable'
    }

    It 'Returns declared maturity <Value>' -ForEach @(
        @{ Value = 'stable' }
        @{ Value = 'preview' }
        @{ Value = 'experimental' }
        @{ Value = 'deprecated' }
        @{ Value = 'removed' }
    ) {
        Get-MarketplaceEntryMaturity -Entry @{ name = 'demo'; 'x-hve' = @{ maturity = $Value } } | Should -BeExactly $Value
    }
}

Describe 'Test-MarketplaceEntryEligible' -Tag 'Unit' {
    It 'Treats <Maturity> on <Channel> as <Expected>' -ForEach @(
        @{ Maturity = 'stable'; Channel = 'Stable'; Expected = $true }
        @{ Maturity = 'stable'; Channel = 'PreRelease'; Expected = $true }
        @{ Maturity = 'preview'; Channel = 'Stable'; Expected = $true }
        @{ Maturity = 'preview'; Channel = 'PreRelease'; Expected = $true }
        @{ Maturity = 'experimental'; Channel = 'Stable'; Expected = $true }
        @{ Maturity = 'experimental'; Channel = 'PreRelease'; Expected = $true }
        @{ Maturity = 'deprecated'; Channel = 'Stable'; Expected = $false }
        @{ Maturity = 'deprecated'; Channel = 'PreRelease'; Expected = $false }
        @{ Maturity = 'removed'; Channel = 'Stable'; Expected = $false }
        @{ Maturity = 'removed'; Channel = 'PreRelease'; Expected = $false }
    ) {
        $entry = @{ name = 'demo'; 'x-hve' = @{ maturity = $Maturity } }
        Test-MarketplaceEntryEligible -Entry $entry -Channel $Channel | Should -Be $Expected
    }

    It 'Resolves <Maturity> identically on both channels' -ForEach @(
        @{ Maturity = 'stable' }
        @{ Maturity = 'preview' }
        @{ Maturity = 'experimental' }
        @{ Maturity = 'deprecated' }
        @{ Maturity = 'removed' }
    ) {
        $entry = @{ name = 'demo'; 'x-hve' = @{ maturity = $Maturity } }
        Test-MarketplaceEntryEligible -Entry $entry -Channel 'Stable' |
            Should -Be (Test-MarketplaceEntryEligible -Entry $entry -Channel 'PreRelease')
    }

    It 'Treats an undeclared package maturity as stable on <Channel>' -ForEach @(
        @{ Channel = 'Stable' }
        @{ Channel = 'PreRelease' }
    ) {
        Test-MarketplaceEntryEligible -Entry @{ name = 'demo' } -Channel $Channel | Should -BeTrue
    }

    It 'Rejects an unsupported channel' {
        { Test-MarketplaceEntryEligible -Entry @{ name = 'demo' } -Channel 'Nightly' } |
            Should -Throw -ExpectedMessage '*does not belong to the set*'
    }
}

Describe 'Get-MarketplacePackageRecipe component maturity filtering' -Tag 'Unit' {
    BeforeAll {
        $script:MatrixEntry = @{
            name    = 'matrix'
            agents  = @(
                'agents/demo/declared-stable.md'
                'agents/demo/declared-preview.md'
                'agents/demo/declared-experimental.md'
                'agents/demo/declared-deprecated.md'
                'agents/demo/declared-removed.md'
                'agents/demo/undeclared.md'
            )
            'x-hve' = @{
                componentMaturity = @{
                    'agents/demo/declared-stable.md'       = 'stable'
                    'agents/demo/declared-preview.md'      = 'preview'
                    'agents/demo/declared-experimental.md' = 'experimental'
                    'agents/demo/declared-deprecated.md'   = 'deprecated'
                    'agents/demo/declared-removed.md'      = 'removed'
                }
            }
        }
        $script:StableRecipe = @(Get-MarketplacePackageRecipe -Entry $script:MatrixEntry -Channel 'Stable')
        $script:PreReleaseRecipe = @(Get-MarketplacePackageRecipe -Entry $script:MatrixEntry -Channel 'PreRelease')
    }

    It 'Declares six candidate components before filtering' {
        $script:MatrixEntry.agents.Count | Should -Be 6
    }

    It 'Keeps stable, preview, and experimental components on the Stable channel' {
        $script:StableRecipe.Count | Should -Be 4
        ($script:StableRecipe.PackagePath | Sort-Object) -join '|' |
            Should -BeExactly 'agents/demo/declared-experimental.md|agents/demo/declared-preview.md|agents/demo/declared-stable.md|agents/demo/undeclared.md'
    }

    It 'Keeps stable, preview, and experimental components on the PreRelease channel' {
        $script:PreReleaseRecipe.Count | Should -Be 4
        ($script:PreReleaseRecipe.PackagePath | Sort-Object) -join '|' |
            Should -BeExactly 'agents/demo/declared-experimental.md|agents/demo/declared-preview.md|agents/demo/declared-stable.md|agents/demo/undeclared.md'
    }

    It 'Resolves the same components and maturity on both channels' {
        $stable = @($script:StableRecipe | Sort-Object PackagePath | ForEach-Object { "$($_.PackagePath)=$($_.Maturity)" })
        $preRelease = @($script:PreReleaseRecipe | Sort-Object PackagePath | ForEach-Object { "$($_.PackagePath)=$($_.Maturity)" })
        ($stable -join '|') | Should -BeExactly ($preRelease -join '|')
    }

    It 'Excludes deprecated and removed components from both channels' {
        $script:StableRecipe.PackagePath | Should -Not -Contain 'agents/demo/declared-deprecated.md'
        $script:StableRecipe.PackagePath | Should -Not -Contain 'agents/demo/declared-removed.md'
        $script:PreReleaseRecipe.PackagePath | Should -Not -Contain 'agents/demo/declared-deprecated.md'
        $script:PreReleaseRecipe.PackagePath | Should -Not -Contain 'agents/demo/declared-removed.md'
    }

    It 'Defaults an undeclared component to stable maturity' {
        $undeclared = @($script:PreReleaseRecipe | Where-Object { $_.PackagePath -eq 'agents/demo/undeclared.md' })
        $undeclared.Count | Should -Be 1
        $undeclared[0].Maturity | Should -BeExactly 'stable'
    }

    It 'Carries the declared maturity onto <PackagePath>' -ForEach @(
        @{ PackagePath = 'agents/demo/declared-preview.md'; Maturity = 'preview' }
        @{ PackagePath = 'agents/demo/declared-experimental.md'; Maturity = 'experimental' }
    ) {
        $item = @($script:PreReleaseRecipe | Where-Object { $_.PackagePath -eq $PackagePath })
        $item.Count | Should -Be 1
        $item[0].Maturity | Should -BeExactly $Maturity
    }

    It 'Resolves every surviving component to its canonical source' {
        $sources = @($script:StableRecipe | ForEach-Object { $_.SourcePath } | Sort-Object)
        $sources -join '|' | Should -BeExactly '.github/agents/demo/declared-experimental.agent.md|.github/agents/demo/declared-preview.agent.md|.github/agents/demo/declared-stable.agent.md|.github/agents/demo/undeclared.agent.md'
    }
}

Describe 'Get-MarketplacePackageRecipe membership handling' -Tag 'Unit' {
    It 'Returns no components when the entry declares no membership' {
        @(Get-MarketplacePackageRecipe -Entry @{ name = 'demo' } -Channel 'PreRelease').Count | Should -Be 0
    }

    It 'Skips fields explicitly set to null' {
        @(Get-MarketplacePackageRecipe -Entry @{ name = 'demo'; agents = $null; skills = $null } -Channel 'PreRelease').Count |
            Should -Be 0
    }

    It 'Collapses duplicate declarations within a field' {
        $recipe = @(Get-MarketplacePackageRecipe -Entry @{
                name   = 'demo'
                agents = @('agents/demo/first.md', 'agents/demo/first.md')
            } -Channel 'PreRelease')
        $recipe.Count | Should -Be 1
        $recipe[0].PackagePath | Should -BeExactly 'agents/demo/first.md'
    }

    It 'Projects a single hooks string into one component' {
        $recipe = @(Get-MarketplacePackageRecipe -Entry @{ name = 'demo'; hooks = 'hooks/demo/hooks.json' } -Channel 'Stable')
        $recipe.Count | Should -Be 1
        $recipe[0].Kind | Should -BeExactly 'hook'
        $recipe[0].Field | Should -BeExactly 'hooks'
        $recipe[0].SourcePath | Should -BeExactly '.github/hooks/demo/hooks.json'
    }
}

Describe 'Marketplace recipe ordering' -Tag 'Unit' {
    BeforeAll {
        $script:OrderingRoot = Join-Path $TestDrive 'ordering-repo'
        $agentDirectory = Join-Path $script:OrderingRoot '.github/agents/demo'
        New-Item -ItemType Directory -Path $agentDirectory -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $agentDirectory 'alpha.agent.md') -Value "---`nname: Alpha`n---`n" -NoNewline
        Set-Content -LiteralPath (Join-Path $agentDirectory 'zulu.agent.md') -Value "---`nname: Zulu`n---`n" -NoNewline

        $script:OrderingEntry = @{
            name     = 'ordering'
            agents   = @('agents/demo/zulu.md', 'agents/demo/alpha.md')
            commands = @('commands/demo/run.md')
            rules    = @('rules/demo/style.instructions.md')
            skills   = @('skills/demo/toolkit')
            hooks    = 'hooks/demo/hooks.json'
        }
        $script:OrderingCatalog = @{ plugins = @($script:OrderingEntry) }
        $script:OrderingIndex = Get-MarketplaceAgentIndex -Catalog $script:OrderingCatalog -RepoRoot $script:OrderingRoot
    }

    It 'Emits unresolved recipes in field-map order with paths sorted inside each field' {
        $recipe = @(Get-MarketplacePackageRecipe -Entry $script:OrderingEntry -Channel 'PreRelease')
        $recipe.Count | Should -Be 6
        ($recipe.PackagePath -join '|') | Should -BeExactly (@(
                'agents/demo/alpha.md'
                'agents/demo/zulu.md'
                'commands/demo/run.md'
                'rules/demo/style.instructions.md'
                'skills/demo/toolkit'
                'hooks/demo/hooks.json'
            ) -join '|')
    }

    It 'Emits resolved recipes ordered by field then package path' {
        $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:OrderingEntry -Channel 'PreRelease' -AgentIndex $script:OrderingIndex)
        $recipe.Count | Should -Be 6
        ($recipe.PackagePath -join '|') | Should -BeExactly (@(
                'agents/demo/alpha.md'
                'agents/demo/zulu.md'
                'commands/demo/run.md'
                'hooks/demo/hooks.json'
                'rules/demo/style.instructions.md'
                'skills/demo/toolkit'
            ) -join '|')
        ($recipe.Field -join '|') | Should -BeExactly 'agents|agents|commands|hooks|rules|skills'
    }

    It 'Produces identical ordering on repeated projections' {
        $first = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:OrderingEntry -Channel 'PreRelease' -AgentIndex $script:OrderingIndex)
        $second = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:OrderingEntry -Channel 'PreRelease' -AgentIndex $script:OrderingIndex)
        ($first.PackagePath -join '|') | Should -BeExactly ($second.PackagePath -join '|')
    }
}

Describe 'Get-MarketplaceCatalog' -Tag 'Unit' {
    BeforeAll {
        $script:CatalogRoot = Join-Path $TestDrive 'catalogs'
        New-Item -ItemType Directory -Path $script:CatalogRoot -Force | Out-Null

        $script:ValidCatalogPath = Join-Path $script:CatalogRoot 'valid.json'
        Set-Content -LiteralPath $script:ValidCatalogPath -Value '{ "plugins": [ { "name": "demo", "agents": ["agents/demo/first.md"] } ] }' -NoNewline

        $script:NoPluginsPath = Join-Path $script:CatalogRoot 'no-plugins.json'
        Set-Content -LiteralPath $script:NoPluginsPath -Value '{ "packages": [] }' -NoNewline

        $script:NullCatalogPath = Join-Path $script:CatalogRoot 'null.json'
        Set-Content -LiteralPath $script:NullCatalogPath -Value 'null' -NoNewline

        $script:EmptyPluginsPath = Join-Path $script:CatalogRoot 'empty-plugins.json'
        Set-Content -LiteralPath $script:EmptyPluginsPath -Value '{ "plugins": [] }' -NoNewline
    }

    It 'Parses a catalog into a dictionary of packages' {
        $catalog = Get-MarketplaceCatalog -Path $script:ValidCatalogPath
        $catalog | Should -BeOfType [System.Collections.IDictionary]
        @($catalog['plugins']).Count | Should -Be 1
        $catalog['plugins'][0]['name'] | Should -BeExactly 'demo'
        @($catalog['plugins'][0]['agents']) -join '|' | Should -BeExactly 'agents/demo/first.md'
    }

    It 'Accepts a catalog that declares an empty plugins array' {
        $catalog = Get-MarketplaceCatalog -Path $script:EmptyPluginsPath
        @($catalog['plugins']).Count | Should -Be 0
    }

    It 'Rejects a missing catalog file' {
        $missingPath = Join-Path $script:CatalogRoot 'absent.json'
        { Get-MarketplaceCatalog -Path $missingPath } |
            Should -Throw -ExpectedMessage 'Marketplace catalog not found: *absent.json'
    }

    It 'Rejects a directory in place of a catalog file' {
        { Get-MarketplaceCatalog -Path $script:CatalogRoot } |
            Should -Throw -ExpectedMessage 'Marketplace catalog not found: *'
    }

    It 'Rejects a catalog without a plugins array' {
        { Get-MarketplaceCatalog -Path $script:NoPluginsPath } |
            Should -Throw -ExpectedMessage "*does not declare a plugins array."
    }

    It 'Rejects a catalog that parses to null' {
        { Get-MarketplaceCatalog -Path $script:NullCatalogPath } |
            Should -Throw -ExpectedMessage "*does not declare a plugins array."
    }
}

AfterAll {
    Remove-Module MarketplaceHelpers -Force -ErrorAction SilentlyContinue
}
