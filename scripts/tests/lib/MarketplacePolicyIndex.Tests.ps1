#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force

    $script:PolicyRoot = Join-Path $TestDrive 'policy-repo'
    $agentDirectory = Join-Path $script:PolicyRoot '.github/agents/demo'
    New-Item -ItemType Directory -Path $agentDirectory -Force | Out-Null
    Set-Content -LiteralPath (Join-Path $agentDirectory 'shared.agent.md') -Value "---`nname: Shared Agent`n---`n" -NoNewline
    Set-Content -LiteralPath (Join-Path $agentDirectory 'solo.agent.md') -Value "---`nname: Solo Agent`n---`n" -NoNewline
}

Describe 'Get-MarketplaceSourceIndex' -Tag 'Unit' {
    BeforeAll {
        $script:FanOutCatalog = @{
            plugins = @(
                @{
                    name     = 'beta-pack'
                    agents   = @('agents/demo/shared.md')
                    commands = @('commands/demo/run.md')
                    skills   = @('skills/demo/toolkit')
                    hooks    = 'hooks/demo/hooks.json'
                    'x-hve'  = @{ componentMaturity = @{ 'commands/demo/run.md' = 'experimental' } }
                }
                @{
                    name   = 'alpha-pack'
                    agents = @('agents/demo/shared.md', 'agents/demo/solo.md')
                }
                @{
                    name    = 'retired-pack'
                    agents  = @('agents/demo/solo.md')
                    'x-hve' = @{ maturity = 'removed' }
                }
            )
        }
        $script:StableIndex = Get-MarketplaceSourceIndex -Catalog $script:FanOutCatalog -RepoRoot $script:PolicyRoot -Channel 'Stable'
        $script:PreReleaseIndex = Get-MarketplaceSourceIndex -Catalog $script:FanOutCatalog -RepoRoot $script:PolicyRoot -Channel 'PreRelease'
    }

    It 'Fans one shared source out to every package that carries it' {
        $records = @($script:StableIndex['.github/agents/demo/shared.agent.md'])
        $records.Count | Should -Be 2
        (($records | ForEach-Object { $_.PackageName }) | Sort-Object) -join '|' | Should -BeExactly 'alpha-pack|beta-pack'
    }

    It 'Records the package path, kind, and maturity for each carrier' {
        $records = @($script:StableIndex['.github/agents/demo/shared.agent.md'])
        foreach ($record in $records) {
            $record.PackagePath | Should -BeExactly 'agents/demo/shared.md'
            $record.Kind | Should -BeExactly 'agent'
            $record.Maturity | Should -BeExactly 'stable'
        }
    }

    It 'Omits packages that are ineligible for the channel' {
        $records = @($script:StableIndex['.github/agents/demo/solo.agent.md'])
        $records.Count | Should -Be 1
        $records[0].PackageName | Should -BeExactly 'alpha-pack'
        ($records | ForEach-Object { $_.PackageName }) | Should -Not -Contain 'retired-pack'
    }

    It 'Confirms the removed package really declares the shared source' {
        $retired = @($script:FanOutCatalog.plugins | Where-Object { $_['name'] -eq 'retired-pack' })
        $retired.Count | Should -Be 1
        @($retired[0]['agents']) | Should -Contain 'agents/demo/solo.md'
    }

    It 'Indexes hook manifests alongside other component kinds' {
        $records = @($script:StableIndex['.github/hooks/demo/hooks.json'])
        $records.Count | Should -Be 1
        $records[0].PackageName | Should -BeExactly 'beta-pack'
        $records[0].Kind | Should -BeExactly 'hook'
        $records[0].PackagePath | Should -BeExactly 'hooks/demo/hooks.json'
    }

    It 'Indexes skill directories by their canonical source path' {
        $records = @($script:StableIndex['.github/skills/demo/toolkit'])
        $records.Count | Should -Be 1
        $records[0].Kind | Should -BeExactly 'skill'
    }

    It 'Includes an experimental component in the Stable index' {
        $records = @($script:StableIndex['.github/prompts/demo/run.prompt.md'])
        $records.Count | Should -Be 1
        $records[0].Maturity | Should -BeExactly 'experimental'
        $records[0].PackageName | Should -BeExactly 'beta-pack'
    }

    It 'Includes an experimental component in the PreRelease index' {
        $records = @($script:PreReleaseIndex['.github/prompts/demo/run.prompt.md'])
        $records.Count | Should -Be 1
        $records[0].Maturity | Should -BeExactly 'experimental'
        $records[0].PackageName | Should -BeExactly 'beta-pack'
    }

    It 'Indexes exactly the eligible sources on the Stable channel' {
        ($script:StableIndex.Keys | Sort-Object) -join "`n" | Should -BeExactly (@(
                '.github/agents/demo/shared.agent.md'
                '.github/agents/demo/solo.agent.md'
                '.github/hooks/demo/hooks.json'
                '.github/prompts/demo/run.prompt.md'
                '.github/skills/demo/toolkit'
            ) -join "`n")
    }

    It 'Indexes the same sources on both channels' {
        ($script:StableIndex.Keys | Sort-Object) -join "`n" |
            Should -BeExactly (($script:PreReleaseIndex.Keys | Sort-Object) -join "`n")
    }
}

Describe 'Get-MarketplaceSourcePolicyIndex' -Tag 'Unit' {
    BeforeAll {
        $script:TombstoneCatalog = @{
            plugins = @(
                @{
                    name   = 'active-pack'
                    agents = @('agents/demo/shared.md')
                    hooks  = 'hooks/demo/hooks.json'
                }
                @{
                    name    = 'legacy-pack'
                    agents  = @('agents/demo/shared.md')
                    'x-hve' = @{
                        componentMaturity = @{
                            'agents/demo/shared.md'  = 'deprecated'
                            'skills/demo/retired'    = 'removed'
                            'commands/demo/gone.md'  = 'removed'
                            'docs/plugins/legacy.md' = 'removed'
                        }
                    }
                }
            )
        }
        $script:PolicyIndex = Get-MarketplaceSourcePolicyIndex -Catalog $script:TombstoneCatalog
        $script:ActiveIndex = Get-MarketplaceSourceIndex -Catalog $script:TombstoneCatalog -RepoRoot $script:PolicyRoot -Channel 'PreRelease'
        $script:TombstoneSources = @('.github/skills/demo/retired', '.github/prompts/demo/gone.prompt.md')
    }

    It 'Confirms the tombstone subject set is non-empty' {
        $script:TombstoneSources.Count | Should -Be 2
        foreach ($sourcePath in $script:TombstoneSources) {
            $script:PolicyIndex.ContainsKey($sourcePath) | Should -BeTrue -Because "'$sourcePath' is declared only through componentMaturity"
        }
    }

    It 'Indexes <SourcePath> as a removed tombstone' -ForEach @(
        @{ SourcePath = '.github/skills/demo/retired' }
        @{ SourcePath = '.github/prompts/demo/gone.prompt.md' }
    ) {
        $records = @($script:PolicyIndex[$SourcePath])
        $records.Count | Should -Be 1
        $records[0].PackageName | Should -BeExactly 'legacy-pack'
        $records[0].Maturity | Should -BeExactly 'removed'
    }

    It 'Keeps tombstones out of active package membership' {
        foreach ($sourcePath in $script:TombstoneSources) {
            $script:ActiveIndex.ContainsKey($sourcePath) | Should -BeFalse -Because "'$sourcePath' has no active membership"
        }
    }

    It 'Confirms the active index is populated so the tombstone check is not vacuous' {
        $script:ActiveIndex.Keys.Count | Should -BeGreaterThan 0
        $script:ActiveIndex.ContainsKey('.github/agents/demo/shared.agent.md') | Should -BeTrue
    }

    It 'Includes hook manifests in the policy index' {
        $records = @($script:PolicyIndex['.github/hooks/demo/hooks.json'])
        $records.Count | Should -Be 1
        $records[0].Kind | Should -BeExactly 'hook'
        $records[0].Maturity | Should -BeExactly 'stable'
    }

    It 'Ignores componentMaturity keys outside the component field set' {
        @($script:PolicyIndex.Keys | Where-Object { $_ -like '*legacy.md' }).Count | Should -Be 0
    }

    It 'Fans a shared source out to every declaring package including tombstoned membership' {
        $records = @($script:PolicyIndex['.github/agents/demo/shared.agent.md'])
        $records.Count | Should -Be 2
        (($records | ForEach-Object { $_.PackageName }) | Sort-Object) -join '|' | Should -BeExactly 'active-pack|legacy-pack'
        (($records | ForEach-Object { $_.Maturity }) | Sort-Object) -join '|' | Should -BeExactly 'deprecated|stable'
    }

    It 'Defaults a component without declared maturity to stable' {
        $records = @($script:PolicyIndex['.github/agents/demo/shared.agent.md'] | Where-Object { $_.PackageName -eq 'active-pack' })
        $records.Count | Should -Be 1
        $records[0].Maturity | Should -BeExactly 'stable'
    }

    It 'Indexes exactly the declared and tombstoned sources' {
        ($script:PolicyIndex.Keys | Sort-Object) -join "`n" | Should -BeExactly (@(
                '.github/agents/demo/shared.agent.md'
                '.github/hooks/demo/hooks.json'
                '.github/prompts/demo/gone.prompt.md'
                '.github/skills/demo/retired'
            ) -join "`n")
    }
}

Describe 'Get-MarketplaceSourceMaturity' -Tag 'Unit' {
    It 'Selects the most restrictive maturity across packages' {
        $catalog = @{
            plugins = @(
                @{ name = 'stable-pack'; agents = @('agents/demo/shared.md') }
                @{
                    name    = 'preview-pack'
                    agents  = @('agents/demo/shared.md')
                    'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = 'preview' } }
                }
            )
        }
        $index = Get-MarketplaceSourcePolicyIndex -Catalog $catalog
        @($index['.github/agents/demo/shared.agent.md']).Count | Should -Be 2
        Get-MarketplaceSourceMaturity -Index $index -SourcePath '.github/agents/demo/shared.agent.md' | Should -BeExactly 'preview'
    }

    It 'Selects <Expected> when packages declare <First> and <Second>' -ForEach @(
        @{ First = 'stable'; Second = 'preview'; Expected = 'preview' }
        @{ First = 'preview'; Second = 'experimental'; Expected = 'experimental' }
        @{ First = 'experimental'; Second = 'deprecated'; Expected = 'deprecated' }
        @{ First = 'deprecated'; Second = 'removed'; Expected = 'removed' }
        @{ First = 'removed'; Second = 'stable'; Expected = 'removed' }
    ) {
        $catalog = @{
            plugins = @(
                @{
                    name    = 'first-pack'
                    agents  = @('agents/demo/shared.md')
                    'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = $First } }
                }
                @{
                    name    = 'second-pack'
                    agents  = @('agents/demo/shared.md')
                    'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = $Second } }
                }
            )
        }
        $index = Get-MarketplaceSourcePolicyIndex -Catalog $catalog
        @($index['.github/agents/demo/shared.agent.md']).Count | Should -Be 2
        Get-MarketplaceSourceMaturity -Index $index -SourcePath '.github/agents/demo/shared.agent.md' | Should -BeExactly $Expected
    }

    It 'Ignores the order in which packages are declared' {
        $ascending = @{
            plugins = @(
                @{ name = 'aaa-pack'; agents = @('agents/demo/shared.md'); 'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = 'stable' } } }
                @{ name = 'zzz-pack'; agents = @('agents/demo/shared.md'); 'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = 'deprecated' } } }
            )
        }
        $descending = @{
            plugins = @(
                @{ name = 'zzz-pack'; agents = @('agents/demo/shared.md'); 'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = 'deprecated' } } }
                @{ name = 'aaa-pack'; agents = @('agents/demo/shared.md'); 'x-hve' = @{ componentMaturity = @{ 'agents/demo/shared.md' = 'stable' } } }
            )
        }
        $ascendingMaturity = Get-MarketplaceSourceMaturity -Index (Get-MarketplaceSourcePolicyIndex -Catalog $ascending) -SourcePath '.github/agents/demo/shared.agent.md'
        $descendingMaturity = Get-MarketplaceSourceMaturity -Index (Get-MarketplaceSourcePolicyIndex -Catalog $descending) -SourcePath '.github/agents/demo/shared.agent.md'
        $ascendingMaturity | Should -BeExactly 'deprecated'
        $descendingMaturity | Should -BeExactly 'deprecated'
    }

    It 'Returns null for a source that no package declares' {
        $catalog = @{ plugins = @(@{ name = 'demo'; agents = @('agents/demo/shared.md') }) }
        $index = Get-MarketplaceSourcePolicyIndex -Catalog $catalog
        $index.Keys.Count | Should -Be 1
        Get-MarketplaceSourceMaturity -Index $index -SourcePath '.github/agents/demo/never-declared.agent.md' | Should -BeNullOrEmpty
    }

    It 'Returns null for an empty index' {
        Get-MarketplaceSourceMaturity -Index @{} -SourcePath '.github/agents/demo/shared.agent.md' | Should -BeNullOrEmpty
    }
}

AfterAll {
    Remove-Module MarketplaceHelpers -Force -ErrorAction SilentlyContinue
}
