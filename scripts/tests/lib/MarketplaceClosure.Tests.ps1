#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force

    function New-TestAgentFile {
        param(
            [Parameter(Mandatory)][string]$RepoRoot,
            [Parameter(Mandatory)][string]$SourcePath,
            [Parameter(Mandatory)][string]$DisplayName,
            [Parameter()][string[]]$Handoffs = @(),
            [Parameter()][switch]$UseObjectHandoffs
        )

        $absolutePath = Join-Path $RepoRoot $SourcePath
        New-Item -ItemType Directory -Path (Split-Path -Path $absolutePath -Parent) -Force | Out-Null

        $lines = @('---', "name: $DisplayName")
        if ($Handoffs.Count -gt 0) {
            $lines += 'handoffs:'
            foreach ($target in $Handoffs) {
                $lines += if ($UseObjectHandoffs) { "  - agent: $target" } else { "  - $target" }
            }
        }
        $lines += @('---', '', '# Body')
        Set-Content -LiteralPath $absolutePath -Value (($lines -join "`n") + "`n") -NoNewline
    }
}

Describe 'ConvertTo-MarketplaceAgentKey' -Tag 'Unit' {
    It 'Normalizes <Name> to <Expected>' -ForEach @(
        @{ Name = 'Alpha Agent'; Expected = 'alpha-agent' }
        @{ Name = 'alpha-agent'; Expected = 'alpha-agent' }
        @{ Name = '  Code Review  '; Expected = 'code-review' }
        @{ Name = 'RPI: Plan/Implement'; Expected = 'rpi-plan-implement' }
        @{ Name = '__underscore__'; Expected = 'underscore' }
        @{ Name = 'ABC123'; Expected = 'abc123' }
        @{ Name = '---'; Expected = '' }
        @{ Name = ''; Expected = '' }
    ) {
        ConvertTo-MarketplaceAgentKey -Name $Name | Should -BeExactly $Expected
    }

    It 'Maps a file stem and its display name onto the same key' {
        $stemKey = ConvertTo-MarketplaceAgentKey -Name 'code-review'
        $displayKey = ConvertTo-MarketplaceAgentKey -Name 'Code Review'
        $stemKey | Should -BeExactly $displayKey
    }
}

Describe 'Marketplace agent index and handoff closure' -Tag 'Unit' {
    BeforeAll {
        $script:ClosureRoot = Join-Path $TestDrive 'closure-repo'

        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/demo/alpha.agent.md' -DisplayName 'Alpha Agent' -Handoffs @('Bravo Agent')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/demo/bravo.agent.md' -DisplayName 'Bravo Agent' -Handoffs @('charlie') -UseObjectHandoffs
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/demo/charlie.agent.md' -DisplayName 'Charlie Agent' -Handoffs @('delta')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/demo/delta.agent.md' -DisplayName 'Delta Agent'
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/demo/echo.agent.md' -DisplayName 'Echo Agent' -Handoffs @('Delta Agent')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/cycle/loop-one.agent.md' -DisplayName 'Loop One' -Handoffs @('loop-two')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/cycle/loop-two.agent.md' -DisplayName 'Loop Two' -Handoffs @('loop-one')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/cycle/mirror.agent.md' -DisplayName 'Mirror' -Handoffs @('mirror')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/broken/orphan.agent.md' -DisplayName 'Orphan' -Handoffs @('Nonexistent Agent')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/one/shared.agent.md' -DisplayName 'One Shared'
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/one/requester.agent.md' -DisplayName 'Requester' -Handoffs @('Shared')
        New-TestAgentFile -RepoRoot $script:ClosureRoot -SourcePath '.github/agents/two/other.agent.md' -DisplayName 'Shared'

        $script:ClosureCatalog = @{
            plugins = @(
                @{ name = 'chain'; agents = @('agents/demo/alpha.md', 'agents/demo/bravo.md', 'agents/demo/charlie.md', 'agents/demo/delta.md', 'agents/demo/echo.md') }
                @{ name = 'cycles'; agents = @('agents/cycle/loop-one.md', 'agents/cycle/loop-two.md', 'agents/cycle/mirror.md') }
                @{ name = 'broken'; agents = @('agents/broken/orphan.md') }
                @{ name = 'ambiguous'; agents = @('agents/one/shared.md', 'agents/one/requester.md', 'agents/two/other.md') }
            )
        }
        $script:ClosureIndex = Get-MarketplaceAgentIndex -Catalog $script:ClosureCatalog -RepoRoot $script:ClosureRoot
    }

    Context 'when the index is built' {
        It 'Indexes every declared agent under its file stem' {
            foreach ($stem in @('alpha', 'bravo', 'charlie', 'delta', 'echo', 'loop-one', 'loop-two', 'mirror', 'orphan', 'shared', 'requester', 'other')) {
                $script:ClosureIndex.Lookup.ContainsKey($stem) | Should -BeTrue -Because "'$stem' is a declared agent file stem"
            }
        }

        It 'Indexes agents under their frontmatter display name as well' {
            $script:ClosureIndex.Lookup['alpha-agent'].SourcePath | Should -BeExactly '.github/agents/demo/alpha.agent.md'
            $script:ClosureIndex.Lookup['delta-agent'].SourcePath | Should -BeExactly '.github/agents/demo/delta.agent.md'
            $script:ClosureIndex.Lookup['one-shared'].SourcePath | Should -BeExactly '.github/agents/one/shared.agent.md'
        }

        It 'Records both the package path and the source path for each agent' {
            $script:ClosureIndex.Lookup['alpha'].PackagePath | Should -BeExactly 'agents/demo/alpha.md'
            $script:ClosureIndex.Lookup['alpha'].SourcePath | Should -BeExactly '.github/agents/demo/alpha.agent.md'
        }

        It 'Reads string handoff targets' {
            $handoffs = @($script:ClosureIndex.Lookup['alpha'].Handoffs)
            $handoffs.Count | Should -Be 1
            $handoffs[0] | Should -BeExactly 'Bravo Agent'
        }

        It 'Reads object handoff targets' {
            $handoffs = @($script:ClosureIndex.Lookup['bravo'].Handoffs)
            $handoffs.Count | Should -Be 1
            $handoffs[0] | Should -BeExactly 'charlie'
        }

        It 'Records an empty handoff list for a terminal agent' {
            @($script:ClosureIndex.Lookup['delta'].Handoffs).Count | Should -Be 0
        }

        It 'Records exactly one ambiguous key' {
            @($script:ClosureIndex.Ambiguous.Keys).Count | Should -Be 1
            $script:ClosureIndex.Ambiguous.ContainsKey('shared') | Should -BeTrue
        }

        It 'Lists every source that competes for the ambiguous key' {
            (@($script:ClosureIndex.Ambiguous['shared']) -join ', ') |
                Should -BeExactly '.github/agents/one/shared.agent.md, .github/agents/two/other.agent.md'
        }
    }

    Context 'when a declared agent source is missing' {
        BeforeAll {
            $script:GhostCatalog = @{ plugins = @(@{ name = 'ghost'; agents = @('agents/ghost/missing.md') }) }
            $script:GhostIndex = Get-MarketplaceAgentIndex -Catalog $script:GhostCatalog -RepoRoot $script:ClosureRoot -WarningVariable capturedWarnings -WarningAction SilentlyContinue
            $script:GhostWarnings = @($capturedWarnings)
        }

        It 'Warns about the missing source' {
            $script:GhostWarnings | Should -Not -BeNullOrEmpty
            $script:GhostWarnings[0].Message | Should -BeExactly 'Declared agent source not found: .github/agents/ghost/missing.agent.md'
        }

        It 'Still indexes the agent with no handoffs' {
            $script:GhostIndex.Lookup.ContainsKey('missing') | Should -BeTrue
            @($script:GhostIndex.Lookup['missing'].Handoffs).Count | Should -Be 0
        }
    }

    Context 'when agent frontmatter cannot be parsed' {
        BeforeAll {
            $script:MalformedRoot = Join-Path $TestDrive 'malformed-repo'
            $malformedPath = Join-Path $script:MalformedRoot '.github/agents/demo/broken.agent.md'
            New-Item -ItemType Directory -Path (Split-Path -Path $malformedPath -Parent) -Force | Out-Null
            Set-Content -LiteralPath $malformedPath -Value "---`nname: Broken`n  bad: indentation`n---`n" -NoNewline

            $script:MalformedCatalog = @{ plugins = @(@{ name = 'malformed'; agents = @('agents/demo/broken.md') }) }
            $script:MalformedIndex = Get-MarketplaceAgentIndex -Catalog $script:MalformedCatalog -RepoRoot $script:MalformedRoot -WarningVariable capturedWarnings -WarningAction SilentlyContinue
            $script:MalformedWarnings = @($capturedWarnings)
        }

        It 'Warns and names the source path' {
            $script:MalformedWarnings | Should -Not -BeNullOrEmpty
            $script:MalformedWarnings[0].Message | Should -BeLike 'Failed to parse frontmatter from .github/agents/demo/broken.agent.md*'
        }

        It 'Falls back to the file stem key with no handoffs' {
            $script:MalformedIndex.Lookup.ContainsKey('broken') | Should -BeTrue
            @($script:MalformedIndex.Lookup['broken'].Handoffs).Count | Should -Be 0
        }
    }

    Context 'when transitive dependencies are closed' {
        It 'Follows a three-hop handoff chain to its terminal agent' {
            $closed = @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/demo/alpha.md') -PackageName 'chain')
            $closed.Count | Should -Be 4
            ($closed -join '|') | Should -BeExactly 'agents/demo/alpha.md|agents/demo/bravo.md|agents/demo/charlie.md|agents/demo/delta.md'
        }

        It 'Collapses a target reached from two independent seeds' {
            $closed = @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/demo/alpha.md', 'agents/demo/echo.md') -PackageName 'chain')
            $closed.Count | Should -Be 5
            @($closed | Where-Object { $_ -eq 'agents/demo/delta.md' }).Count | Should -Be 1
        }

        It 'Terminates on a two-agent cycle' {
            $closed = @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/cycle/loop-one.md') -PackageName 'cycles')
            $closed.Count | Should -Be 2
            ($closed -join '|') | Should -BeExactly 'agents/cycle/loop-one.md|agents/cycle/loop-two.md'
        }

        It 'Terminates on a self-referencing agent' {
            $closed = @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/cycle/mirror.md') -PackageName 'cycles')
            $closed.Count | Should -Be 1
            $closed[0] | Should -BeExactly 'agents/cycle/mirror.md'
        }

        It 'Returns nothing for an empty seed set' {
            @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @() -PackageName 'chain').Count |
                Should -Be 0
        }

        It 'Returns package paths in sorted order' {
            $closed = @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/demo/echo.md', 'agents/demo/alpha.md') -PackageName 'chain')
            ($closed -join '|') | Should -BeExactly (($closed | Sort-Object) -join '|')
        }
    }

    Context 'when closure cannot be resolved' {
        It 'Rejects a seed that is absent from the index' {
            { Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/demo/absent.md') -PackageName 'chain' } |
                Should -Throw -ExpectedMessage "Package 'chain' declares agent 'agents/demo/absent.md', which is absent from the catalog agent index."
        }

        It 'Names the package as unknown when none is supplied' {
            { Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/demo/absent.md') } |
                Should -Throw -ExpectedMessage "Package 'unknown' declares agent 'agents/demo/absent.md', which is absent from the catalog agent index."
        }

        It 'Rejects a handoff target that resolves to no catalog agent' {
            { Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/broken/orphan.md') -PackageName 'broken' } |
                Should -Throw -ExpectedMessage "Package 'broken': handoff target 'Nonexistent Agent' in '.github/agents/broken/orphan.agent.md' does not resolve to a catalog-declared agent."
        }

        It 'Rejects a handoff target whose key is ambiguous' {
            { Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/one/requester.md') -PackageName 'ambiguous' } |
                Should -Throw -ExpectedMessage "Package 'ambiguous': handoff target 'Shared' in '.github/agents/one/requester.agent.md' is ambiguous across .github/agents/one/shared.agent.md, .github/agents/two/other.agent.md."
        }
    }

    Context 'when an ambiguous key is never requested' {
        It 'Confirms the index really does carry an ambiguous key' {
            @($script:ClosureIndex.Ambiguous.Keys).Count | Should -BeGreaterThan 0
        }

        It 'Closes a package that never reaches the ambiguous key' {
            $closed = @(Expand-MarketplaceAgentDependency -Index $script:ClosureIndex -SeedPackagePaths @('agents/demo/delta.md') -PackageName 'chain')
            $closed.Count | Should -Be 1
            $closed[0] | Should -BeExactly 'agents/demo/delta.md'
        }
    }

    Context 'when a resolved recipe closes its agents' {
        It 'Adds every transitively reachable agent to the recipe' {
            $entry = @{ name = 'consumer'; agents = @('agents/demo/alpha.md') }
            $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $script:ClosureIndex)
            $recipe.Count | Should -Be 4
            ($recipe.PackagePath -join '|') | Should -BeExactly 'agents/demo/alpha.md|agents/demo/bravo.md|agents/demo/charlie.md|agents/demo/delta.md'
        }

        It 'Stamps closure-added agents as agent components in the agents field' {
            $entry = @{ name = 'consumer'; agents = @('agents/demo/alpha.md') }
            $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $script:ClosureIndex)
            $added = @($recipe | Where-Object { $_.PackagePath -ne 'agents/demo/alpha.md' })
            $added.Count | Should -Be 3
            foreach ($item in $added) {
                $item.Kind | Should -BeExactly 'agent'
                $item.Field | Should -BeExactly 'agents'
                $item.Maturity | Should -BeExactly 'stable'
                $item.SourcePath | Should -BeLike '.github/agents/demo/*.agent.md'
            }
        }

        It 'Preserves the declared maturity of a closure-added agent' {
            $entry = @{
                name    = 'consumer'
                agents  = @('agents/demo/alpha.md')
                'x-hve' = @{ componentMaturity = @{ 'agents/demo/bravo.md' = 'experimental' } }
            }
            $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'Stable' -AgentIndex $script:ClosureIndex)
            $recipe.Count | Should -Be 4

            $bravo = @($recipe | Where-Object { $_.PackagePath -eq 'agents/demo/bravo.md' })
            $bravo.Count | Should -Be 1
            $bravo[0].Maturity | Should -BeExactly 'experimental'
        }

        It 'Excludes a closure-added agent that is <Maturity>' -ForEach @(
            @{ Maturity = 'deprecated' }
            @{ Maturity = 'removed' }
        ) {
            $entry = @{
                name    = 'consumer'
                agents  = @('agents/demo/alpha.md')
                'x-hve' = @{ componentMaturity = @{ 'agents/demo/bravo.md' = $Maturity } }
            }
            $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $script:ClosureIndex)
            $recipe.PackagePath | Should -Not -Contain 'agents/demo/bravo.md'
        }

        It 'Resolves the same seeds and closure on both channels' {
            $entry = @{
                name    = 'consumer'
                agents  = @('agents/demo/alpha.md', 'agents/demo/echo.md')
                'x-hve' = @{ componentMaturity = @{ 'agents/demo/echo.md' = 'experimental' } }
            }

            $stableRecipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'Stable' -AgentIndex $script:ClosureIndex)
            $preReleaseRecipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $script:ClosureIndex)

            $stableRecipe.Count | Should -Be 5
            $stableRecipe.PackagePath | Should -Contain 'agents/demo/echo.md'
            @($stableRecipe | ForEach-Object { "$($_.PackagePath)=$($_.Maturity)" }) -join '|' |
                Should -BeExactly (@($preReleaseRecipe | ForEach-Object { "$($_.PackagePath)=$($_.Maturity)" }) -join '|')
        }

        It 'Preserves the declared maturity of seed agents' {
            $entry = @{
                name    = 'consumer'
                agents  = @('agents/demo/echo.md')
                'x-hve' = @{ componentMaturity = @{ 'agents/demo/echo.md' = 'preview' } }
            }
            $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $script:ClosureIndex)
            $echo = @($recipe | Where-Object { $_.PackagePath -eq 'agents/demo/echo.md' })
            $echo.Count | Should -Be 1
            $echo[0].Maturity | Should -BeExactly 'preview'
        }

        It 'Leaves non-agent components untouched by closure' {
            $entry = @{ name = 'consumer'; skills = @('skills/demo/toolkit') }
            $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel 'PreRelease' -AgentIndex $script:ClosureIndex)
            $recipe.Count | Should -Be 1
            $recipe[0].Kind | Should -BeExactly 'skill'
        }

        It 'Returns an empty recipe when the entry declares nothing' {
            @(Get-MarketplaceResolvedPackageRecipe -Entry @{ name = 'consumer' } -Channel 'PreRelease' -AgentIndex $script:ClosureIndex).Count |
                Should -Be 0
        }
    }
}

Describe 'Get-MarketplaceLiteralReference' -Tag 'Unit' {
    It 'Captures a relative and a repository-root reference' {
        $references = @(Get-MarketplaceLiteralReference -Body @'
Follow #file:../../instructions/demo/shared.instructions.md while planning.
Cross-cutting rules live in `#file:.github/instructions/demo/other.instructions.md`.
'@)
        $references | Should -Be @('../../instructions/demo/shared.instructions.md', '.github/instructions/demo/other.instructions.md')
    }

    It 'Ignores a bare directive mentioned in prose' {
        Get-MarketplaceLiteralReference -Body 'Do not use markdown links or `#file:` directives.' | Should -BeNullOrEmpty
        Get-MarketplaceLiteralReference -Body 'Do not use #file: directives here.' | Should -BeNullOrEmpty
    }

    It 'Strips trailing sentence punctuation' {
        Get-MarketplaceLiteralReference -Body 'See #file:./demo.instructions.md.' | Should -Be @('./demo.instructions.md')
    }

    It 'Returns each distinct reference once in first-seen order' {
        $references = @(Get-MarketplaceLiteralReference -Body '#file:./b.instructions.md #file:./a.instructions.md #file:./b.instructions.md')
        $references | Should -Be @('./b.instructions.md', './a.instructions.md')
    }
}

Describe 'Resolve-MarketplaceComponentSelection' -Tag 'Unit' {
    BeforeAll {
        $script:SelectionRoot = Join-Path $TestDrive 'selection-repo'

        function script:New-SelectionFile {
            param([string]$SourcePath, [string]$Content)
            $absolute = Join-Path $script:SelectionRoot $SourcePath
            New-Item -ItemType Directory -Path (Split-Path -Path $absolute -Parent) -Force | Out-Null
            Set-Content -LiteralPath $absolute -Value $Content -NoNewline
        }

        New-TestAgentFile -RepoRoot $script:SelectionRoot -SourcePath '.github/agents/select/helper.agent.md' -DisplayName 'Helper Agent'
        New-SelectionFile -SourcePath '.github/agents/select/root.agent.md' -Content @'
---
name: Root Agent
handoffs:
  - Helper Agent
---

Follow #file:../../instructions/select/shared.instructions.md while planning.
Read #file:.github/skills/select/toolkit/references/notes.md for the method notes.
Users may reference `#file:path/to/file.ext` in chat, and prose may mention `#file:` directly.
'@
        New-SelectionFile -SourcePath '.github/agents/select/dangling.agent.md' -Content @'
---
name: Dangling Agent
---

Follow #file:../../instructions/select/absent.instructions.md before acting.
'@
        New-SelectionFile -SourcePath '.github/agents/select/outsider.agent.md' -Content @'
---
name: Outsider Agent
---

Follow #file:../../instructions/select/unlisted.instructions.md before acting.
'@
        New-SelectionFile -SourcePath '.github/prompts/select/run.prompt.md' -Content '# Run'
        New-SelectionFile -SourcePath '.github/instructions/select/shared.instructions.md' -Content '# Shared'
        New-SelectionFile -SourcePath '.github/instructions/select/unlisted.instructions.md' -Content '# Unlisted'
        New-SelectionFile -SourcePath '.github/skills/select/toolkit/SKILL.md' -Content '# Toolkit'
        New-SelectionFile -SourcePath '.github/skills/select/toolkit/references/notes.md' -Content '# Notes'

        $script:SelectionEntry = @{
            name     = 'hve-core'
            agents   = @('agents/select/root.md', 'agents/select/helper.md', 'agents/select/dangling.md', 'agents/select/outsider.md')
            commands = @('commands/select/run.md')
            rules    = @('rules/select/shared.instructions.md')
            skills   = @('skills/select/toolkit')
            hooks    = 'hooks/select/telemetry.json'
            'x-hve'  = @{
                componentMaturity = @{ 'agents/select/helper.md' = 'experimental'; 'skills/select/toolkit' = 'preview' }
                profiles          = @{ starter = @('agents/select/root.md', 'commands/select/run.md') }
            }
        }
        $script:SelectionCatalog = @{ plugins = @($script:SelectionEntry) }
        $script:SelectionIndex = Get-MarketplaceAgentIndex -Catalog $script:SelectionCatalog -RepoRoot $script:SelectionRoot
    }

    Context 'Component index' {
        It 'Indexes the four installable kinds and excludes hooks' {
            $index = Get-MarketplaceComponentIndex -Entry $script:SelectionEntry

            @($index.Keys | Sort-Object) | Should -Be @(
                'agents/select/dangling.md'
                'agents/select/helper.md'
                'agents/select/outsider.md'
                'agents/select/root.md'
                'commands/select/run.md'
                'rules/select/shared.instructions.md'
                'skills/select/toolkit'
            )
            $index['commands/select/run.md'].SourcePath | Should -BeExactly '.github/prompts/select/run.prompt.md'
            $index['rules/select/shared.instructions.md'].SourcePath | Should -BeExactly '.github/instructions/select/shared.instructions.md'
            $index['skills/select/toolkit'].Kind | Should -BeExactly 'skill'
        }
    }

    Context 'Profile selection' {
        BeforeAll {
            $script:StarterSelection = @(Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry `
                    -RepoRoot $script:SelectionRoot -AgentIndex $script:SelectionIndex -ProfileName 'starter')
        }

        It 'Resolves declared members and their visible dependencies' {
            @($script:StarterSelection | ForEach-Object { $_.PackagePath }) | Should -Be @(
                'agents/select/helper.md'
                'agents/select/root.md'
                'commands/select/run.md'
                'rules/select/shared.instructions.md'
                'skills/select/toolkit'
            )
        }

        It 'Distinguishes selected members from dependency additions' {
            @($script:StarterSelection | Where-Object { $_.Origin -eq 'selected' } | ForEach-Object { $_.PackagePath }) |
                Should -Be @('agents/select/root.md', 'commands/select/run.md')
            @($script:StarterSelection | Where-Object { $_.Origin -eq 'dependency' } | ForEach-Object { $_.PackagePath }) |
                Should -Be @('agents/select/helper.md', 'rules/select/shared.instructions.md', 'skills/select/toolkit')
        }

        It 'Carries canonical maturity for selected and dependency components' {
            @($script:StarterSelection | Where-Object { $_.PackagePath -eq 'agents/select/helper.md' })[0].Maturity | Should -BeExactly 'experimental'
            @($script:StarterSelection | Where-Object { $_.PackagePath -eq 'skills/select/toolkit' })[0].Maturity | Should -BeExactly 'preview'
            @($script:StarterSelection | Where-Object { $_.PackagePath -eq 'agents/select/root.md' })[0].Maturity | Should -BeExactly 'stable'
        }

        It 'Resolves a reference inside a skill to the owning skill component' {
            @($script:StarterSelection | Where-Object { $_.PackagePath -eq 'skills/select/toolkit' })[0].SourcePath |
                Should -BeExactly '.github/skills/select/toolkit'
        }

        It 'Rejects an undeclared profile' {
            { Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -ProfileName 'absent' } |
                Should -Throw -ExpectedMessage "*declares no 'absent' selection profile*"
        }
    }

    Context 'Custom selection' {
        It 'Resolves a single component with no dependencies' {
            $selection = @(Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('commands/select/run.md'))

            @($selection | ForEach-Object { $_.PackagePath }) | Should -Be @('commands/select/run.md')
        }

        It 'Deduplicates a repeated component' {
            $selection = @(Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('skills/select/toolkit', 'skills/select/toolkit/'))

            $selection.Count | Should -Be 1
        }

        It 'Rejects a component outside recipe membership' {
            { Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('agents/select/absent.md') } |
                Should -Throw -ExpectedMessage '*is not declared membership*'
        }

        It 'Rejects a hook component' {
            { Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('hooks/select/telemetry.json') } |
                Should -Throw -ExpectedMessage '*is not declared membership*'
        }

        It 'Rejects a traversal component path' {
            { Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('agents/../../etc/passwd') } |
                Should -Throw -ExpectedMessage '*must not escape the package root*'
        }

        It 'Rejects an unresolved literal dependency' {
            { Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('agents/select/dangling.md') } |
                Should -Throw -ExpectedMessage '*does not resolve to a file*'
        }

        It 'Rejects a literal dependency outside recipe membership' {
            { Resolve-MarketplaceComponentSelection -Entry $script:SelectionEntry -RepoRoot $script:SelectionRoot `
                    -AgentIndex $script:SelectionIndex -Component @('agents/select/outsider.md') } |
                Should -Throw -ExpectedMessage '*is not declared marketplace membership*'
        }
    }
}

Describe 'Production starter profile selection' -Tag 'Unit' {
    BeforeAll {
        $script:ProductionRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $catalog = Get-MarketplaceCatalog -Path (Join-Path $script:ProductionRoot '.github/plugin/marketplace.json')
        $script:ProductionEntry = @($catalog['plugins']) | Where-Object { $_['name'] -eq 'hve-core-all' }
        $agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $script:ProductionRoot
        $script:ProductionStarter = @(Resolve-MarketplaceComponentSelection -Entry $script:ProductionEntry `
                -RepoRoot $script:ProductionRoot -AgentIndex $agentIndex -ProfileName 'starter')
    }

    It 'Resolves 24 direct components with no dependency additions' {
        $script:ProductionStarter.Count | Should -Be 24
        @($script:ProductionStarter | Where-Object { $_.Origin -ne 'selected' }) | Should -BeNullOrEmpty
    }

    It 'Resolves 6 agents, 15 skills, 1 prompt, and 2 instructions' {
        @($script:ProductionStarter | Where-Object { $_.Kind -eq 'agent' }).Count | Should -Be 6
        @($script:ProductionStarter | Where-Object { $_.Kind -eq 'skill' }).Count | Should -Be 15
        @($script:ProductionStarter | Where-Object { $_.Kind -eq 'prompt' }).Count | Should -Be 1
        @($script:ProductionStarter | Where-Object { $_.Kind -eq 'instruction' }).Count | Should -Be 2
    }

    It 'Discloses experimental starter content' {
        @($script:ProductionStarter | Where-Object { $_.Maturity -eq 'experimental' } | ForEach-Object { $_.PackagePath }) |
            Should -Contain 'skills/hve-core/vally-tests'
    }

    It 'Closes the full recipe without additions or unresolved references' {
        $index = Get-MarketplaceComponentIndex -Entry $script:ProductionEntry
        $agentIndex = Get-MarketplaceAgentIndex -Catalog @{ plugins = @($script:ProductionEntry) } -RepoRoot $script:ProductionRoot
        $selection = @(Resolve-MarketplaceComponentSelection -Entry $script:ProductionEntry -RepoRoot $script:ProductionRoot `
                -AgentIndex $agentIndex -Component @($index.Keys))

        $selection.Count | Should -Be $index.Count
    }
}

Describe 'Production focused package closure' -Tag 'Unit' {
    BeforeAll {
        $script:FocusedRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:FocusedCatalog = Get-MarketplaceCatalog -Path (Join-Path $script:FocusedRoot '.github/plugin/marketplace.json')
        $script:FocusedAgentIndex = Get-MarketplaceAgentIndex -Catalog $script:FocusedCatalog -RepoRoot $script:FocusedRoot
    }

    It 'Closes every package agent set entirely from declared membership' {
        foreach ($entry in @($script:FocusedCatalog['plugins'])) {
            $declared = @(
                $entry['agents'] |
                    Where-Object { $_ } |
                    ForEach-Object { (Resolve-MarketplaceComponentSource -PackagePath $_ -Field agents).PackagePath } |
                    Sort-Object
            )
            if ($declared.Count -eq 0) {
                continue
            }

            $closed = @(Expand-MarketplaceAgentDependency -Index $script:FocusedAgentIndex `
                    -SeedPackagePaths $declared -PackageName ([string]$entry['name']))
            $closed | Should -Be $declared -Because "package '$([string]$entry['name'])' must declare its complete handoff closure"
        }
    }

    It 'Declares the data-science security handoff cycle explicitly' {
        $entry = @($script:FocusedCatalog['plugins'] | Where-Object { $_['name'] -eq 'data-science' })[0]
        $declared = @(Get-MarketplacePackageRecipe -Entry $entry -Channel PreRelease | ForEach-Object { $_.PackagePath })
        $declared | Should -Contain 'agents/security/security-planner.md'
        $declared | Should -Contain 'agents/security/sssc-planner.md'
        @($script:FocusedAgentIndex.Lookup['rai-planner'].Handoffs) | Should -Contain 'Security Planner'
        @($script:FocusedAgentIndex.Lookup['security-planner'].Handoffs) | Should -Contain 'SSSC Planner'
        @($script:FocusedAgentIndex.Lookup['sssc-planner'].Handoffs) | Should -Contain 'Security Planner'
    }

    It 'Resolves data-science <PackagePath> as experimental on <Channel>' -ForEach @(
        @{ PackagePath = 'agents/security/security-planner.md'; Channel = 'Stable' }
        @{ PackagePath = 'agents/security/security-planner.md'; Channel = 'PreRelease' }
        @{ PackagePath = 'agents/security/sssc-planner.md'; Channel = 'Stable' }
        @{ PackagePath = 'agents/security/sssc-planner.md'; Channel = 'PreRelease' }
    ) {
        $entry = @($script:FocusedCatalog['plugins'] | Where-Object { $_['name'] -eq 'data-science' })[0]
        $recipe = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel $Channel -AgentIndex $script:FocusedAgentIndex)
        $item = @($recipe | Where-Object { $_.PackagePath -eq $PackagePath })
        $item.Count | Should -Be 1
        $item[0].Kind | Should -BeExactly 'agent'
        $item[0].Maturity | Should -BeExactly 'experimental'
    }
}

AfterAll {
    Remove-Module MarketplaceHelpers -Force -ErrorAction SilentlyContinue
}
