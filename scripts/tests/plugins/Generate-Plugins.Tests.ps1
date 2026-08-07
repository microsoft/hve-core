#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Generate-Plugins.ps1')
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/CIHelpers.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force

    $script:GeneratorHostLog = [System.Collections.Generic.List[string]]::new()
    Mock Write-Host { $script:GeneratorHostLog.Add([string]$Object) }
    Mock Write-Host {} -ModuleName PluginHelpers
    Mock Write-Warning {}
    Mock Write-Warning {} -ModuleName PluginHelpers
    $script:OriginalPluginStagingRoot = $env:HVE_PLUGIN_STAGING_ROOT

    function New-GeneratorFixture {
        <#
        .SYNOPSIS
        Builds a fixture repository with one catalog entry per supplied entry set.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][AllowEmptyCollection()][array]$Entries,
            [Parameter()][switch]$SkipCatalog
        )

        New-PluginFixtureRepository -Path $Root -Version '9.9.9' | Out-Null
        Add-PluginFixtureArtifactSet -RepoRoot $Root | Out-Null
        if (-not $SkipCatalog) {
            Add-PluginFixtureCatalog -RepoRoot $Root -Entries $Entries -Version '9.9.9' | Out-Null
        }
        return $Root
    }

    function New-RpiEntry {
        <#
        .SYNOPSIS
        Builds the standard fixture entry that declares every artifact kind.
        #>
        param(
            [Parameter()][string]$Name = 'rpi',
            [Parameter()][hashtable]$Overlay
        )

        return New-PluginFixtureEntry -Name $Name -Description 'RPI workflow package' -Version '9.9.9' `
            -Agents @('agents/rpi/rpi-planner.agent.md') `
            -Commands @('prompts/rpi/rpi-plan.prompt.md') `
            -Rules @('instructions/shared/hve-core-location.instructions.md') `
            -Skills @('skills/rpi/rpi-plan') `
            -Hook 'hooks/rpi/telemetry.json' `
            -Overlay $Overlay
    }
}

Describe 'New-PluginDocumentationBlock' -Tag 'Unit' {
    BeforeAll {
        $script:blockRepo = Join-Path $TestDrive 'documentation-block'
        New-PluginFixtureRepository -Path $script:blockRepo -Version '9.9.9' | Out-Null
        Add-PluginFixtureArtifactSet -RepoRoot $script:blockRepo | Out-Null

        $script:blockItems = @(
            @{ Kind = 'hook'; SourcePath = '.github/hooks/rpi/telemetry.json' }
            @{ Kind = 'skill'; SourcePath = '.github/skills/rpi/rpi-plan'; Maturity = 'stable' }
            @{ Kind = 'instruction'; SourcePath = '.github/instructions/shared/hve-core-location.instructions.md'; Maturity = 'preview' }
            @{ Kind = 'prompt'; SourcePath = '.github/prompts/rpi/rpi-plan.prompt.md'; Maturity = 'experimental' }
            @{ Kind = 'agent'; SourcePath = '.github/agents/rpi/rpi-planner.agent.md'; Maturity = 'stable' }
        )
        $script:documentationBlock = New-PluginDocumentationBlock -Items $script:blockItems -RepoRoot $script:blockRepo
    }

    Context 'when every artifact kind is declared' {
        It 'Renders the block exactly' {
            $script:documentationBlock | Should -BeExactly (@(
                    '### Chat Agents'
                    ''
                    '| Name | Maturity | Description |'
                    '|------|----------|-------------|'
                    '| **rpi-planner** | stable | Plans RPI work |'
                    ''
                    '### Prompts'
                    ''
                    '| Name | Maturity | Description |'
                    '|------|----------|-------------|'
                    '| **rpi-plan** | experimental | Creates an RPI plan |'
                    ''
                    '### Instructions'
                    ''
                    '| Name | Maturity | Description |'
                    '|------|----------|-------------|'
                    '| **shared/hve-core-location** | preview | Locates hve-core artifacts |'
                    ''
                    '### Skills'
                    ''
                    '| Name | Maturity | Description |'
                    '|------|----------|-------------|'
                    '| **rpi-plan** | stable | Builds evidence-based plans |'
                    ''
                    '### Hooks'
                    ''
                    '| Name | Maturity | Description |'
                    '|------|----------|-------------|'
                    '| **telemetry** | stable | Records RPI telemetry |'
                ) -join "`n")
        }

        It 'Orders sections independently of the supplied item order' {
            $sectionOrder = @([regex]::Matches($script:documentationBlock, '(?m)^### (.+)$') | ForEach-Object { $_.Groups[1].Value })
            $sectionOrder | Should -Be @('Chat Agents', 'Prompts', 'Instructions', 'Skills', 'Hooks')
        }

        It 'Reads a skill description from its SKILL.md rather than its directory' {
            $script:documentationBlock | Should -Match '\| \*\*rpi-plan\*\* \| stable \| Builds evidence-based plans \|'
        }

        It 'Discloses every canonical lifecycle label present in the recipe' {
            foreach ($label in @('stable', 'preview', 'experimental')) {
                $script:documentationBlock | Should -Match "(?m)^\| \*\*[^|]+\*\* \| $label \|"
            }
        }
    }

    Context 'when only some kinds are declared' {
        It 'Emits sections for declared kinds only' {
            $partialBlock = New-PluginDocumentationBlock -RepoRoot $script:blockRepo -Items @(
                @{ Kind = 'agent'; SourcePath = '.github/agents/rpi/rpi-planner.agent.md' }
            )
            $partialBlock | Should -Match '### Chat Agents'
            $partialBlock | Should -Not -Match '### Skills'
            $partialBlock | Should -Not -Match '### Hooks'
        }
    }
}

Describe 'Update-PluginDocumentationSource' -Tag 'Unit' {
    BeforeEach {
        $script:documentRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-PluginFixtureRepository -Path $script:documentRepo -Version '9.9.9' | Out-Null
        Add-PluginFixtureArtifactSet -RepoRoot $script:documentRepo | Out-Null
        $script:documentItems = @(
            @{ Kind = 'agent'; SourcePath = '.github/agents/rpi/rpi-planner.agent.md'; Maturity = 'stable' }
        )
        $script:documentPath = Join-Path $script:documentRepo 'docs/plugins/rpi.md'
        $script:expectedBlock = @(
            '### Chat Agents'
            ''
            '| Name | Maturity | Description |'
            '|------|----------|-------------|'
            '| **rpi-planner** | stable | Plans RPI work |'
        ) -join "`n"
    }

    Context 'when the document declares the auto-generation markers' {
        BeforeEach {
            Add-PluginFixtureFile -RepoRoot $script:documentRepo -RelativePath 'docs/plugins/rpi.md' -Content (@(
                    '---'
                    'title: Contoso RPI'
                    '---'
                    ''
                    'Durable prose.'
                    ''
                    '## Included Artifacts'
                    ''
                    '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
                    ''
                    'stale inventory'
                    ''
                    '<!-- END AUTO-GENERATED ARTIFACTS -->'
                    ''
                    'Footer prose.'
                    ''
                ) -join "`n") | Out-Null
            $script:updateResult = Update-PluginDocumentationSource -DocumentPath $script:documentPath `
                -Items $script:documentItems -RepoRoot $script:documentRepo
            $script:updatedContent = Get-Content -LiteralPath $script:documentPath -Raw -Encoding utf8
        }

        It 'Reports that the document was rewritten' {
            $script:updateResult | Should -BeTrue
        }

        It 'Replaces the stale block and preserves intro and footer' {
            $script:updatedContent | Should -BeExactly ((@(
                            '---'
                            'title: Contoso RPI'
                            '---'
                            ''
                            'Durable prose.'
                            ''
                            '## Included Artifacts'
                            ''
                            '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
                            ''
                            $script:expectedBlock
                            ''
                            '<!-- END AUTO-GENERATED ARTIFACTS -->'
                            ''
                            'Footer prose.'
                        ) -join "`n") + "`n")
        }

        It 'Terminates the document with exactly one newline' {
            $script:updatedContent | Should -Not -Match "`n`n$"
            $script:updatedContent.EndsWith("`n") | Should -BeTrue
        }

        It 'Is a no-op on the second pass' {
            $secondResult = Update-PluginDocumentationSource -DocumentPath $script:documentPath `
                -Items $script:documentItems -RepoRoot $script:documentRepo
            $secondResult | Should -BeFalse
            Get-Content -LiteralPath $script:documentPath -Raw -Encoding utf8 | Should -BeExactly $script:updatedContent
        }
    }

    Context 'when the intro omits the Included Artifacts heading' {
        It 'Inserts the heading above the generated block' {
            Add-PluginFixtureFile -RepoRoot $script:documentRepo -RelativePath 'docs/plugins/rpi.md' -Content (@(
                    'Durable prose.'
                    ''
                    '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
                    '<!-- END AUTO-GENERATED ARTIFACTS -->'
                    ''
                ) -join "`n") | Out-Null

            Update-PluginDocumentationSource -DocumentPath $script:documentPath -Items $script:documentItems -RepoRoot $script:documentRepo |
                Should -BeTrue
            Get-Content -LiteralPath $script:documentPath -Raw -Encoding utf8 | Should -BeExactly ((@(
                            'Durable prose.'
                            ''
                            '## Included Artifacts'
                            ''
                            '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
                            ''
                            $script:expectedBlock
                            ''
                            '<!-- END AUTO-GENERATED ARTIFACTS -->'
                        ) -join "`n") + "`n")
        }
    }

    Context 'when the document cannot supply a generated block' {
        It 'Returns false for a missing document' {
            Update-PluginDocumentationSource -DocumentPath (Join-Path $script:documentRepo 'docs/plugins/absent.md') `
                -Items $script:documentItems -RepoRoot $script:documentRepo | Should -BeFalse
        }

        It 'Returns false for an empty document without throwing' {
            Add-PluginFixtureFile -RepoRoot $script:documentRepo -RelativePath 'docs/plugins/rpi.md' -Content '' | Out-Null
            $emptyResult = $null
            { $script:emptyResult = Update-PluginDocumentationSource -DocumentPath $script:documentPath `
                    -Items $script:documentItems -RepoRoot $script:documentRepo } | Should -Not -Throw
            $script:emptyResult | Should -BeFalse
            (Get-Item -LiteralPath $script:documentPath).Length | Should -Be 0
            $emptyResult | Should -BeNullOrEmpty
        }

        It 'Leaves a marker-free document untouched' {
            $handAuthored = "---`ntitle: Contoso RPI`n---`n`nHand-authored prose only.`n"
            Add-PluginFixtureFile -RepoRoot $script:documentRepo -RelativePath 'docs/plugins/rpi.md' -Content $handAuthored | Out-Null
            Update-PluginDocumentationSource -DocumentPath $script:documentPath -Items $script:documentItems -RepoRoot $script:documentRepo |
                Should -BeFalse
            Get-Content -LiteralPath $script:documentPath -Raw -Encoding utf8 | Should -BeExactly $handAuthored
        }
    }
}

Describe 'Assert-PluginOutputSize' -Tag 'Unit' {
    BeforeEach {
        $script:sizeRoot = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())

        function New-SizedPackage {
            param([string]$Name, [int]$Bytes)
            $packageDirectory = Join-Path $script:sizeRoot $Name
            New-Item -ItemType Directory -Path $packageDirectory -Force | Out-Null
            [System.IO.File]::WriteAllBytes((Join-Path $packageDirectory 'payload.bin'), [byte[]]::new($Bytes))
        }
    }

    Context 'when the output directory does not exist' {
        It 'Reports an empty zero-byte tree' {
            $report = Assert-PluginOutputSize -PluginsDir (Join-Path $script:sizeRoot 'absent') -MaxTotalSizeMB 1
            $report.TotalMB | Should -Be 0
            @($report.Plugins) | Should -HaveCount 0
        }
    }

    Context 'when the output is within the ceiling' {
        BeforeEach {
            New-SizedPackage -Name 'bravo' -Bytes 100
            New-SizedPackage -Name 'alpha' -Bytes 300
            New-SizedPackage -Name 'charlie' -Bytes 200
            $script:sizeReport = Assert-PluginOutputSize -PluginsDir $script:sizeRoot -MaxTotalSizeMB 1
        }

        It 'Orders packages from largest to smallest' {
            @($script:sizeReport.Plugins | ForEach-Object { $_.Name }) | Should -Be @('alpha', 'charlie', 'bravo')
        }

        It 'Reports exact per-package byte totals' {
            @($script:sizeReport.Plugins | ForEach-Object { $_.Bytes }) | Should -Be @(300, 200, 100)
        }

        It 'Reports the combined size in megabytes' {
            $script:sizeReport.TotalMB | Should -Be (600 / 1MB)
        }
    }

    Context 'when the output exceeds the ceiling' {
        BeforeEach {
            New-SizedPackage -Name 'huge' -Bytes 900000
            New-SizedPackage -Name 'large' -Bytes 400000
            New-SizedPackage -Name 'medium' -Bytes 200000
            New-SizedPackage -Name 'small' -Bytes 100
        }

        It 'Throws and names the three largest packages' {
            { Assert-PluginOutputSize -PluginsDir $script:sizeRoot -MaxTotalSizeMB 1 } |
                Should -Throw -ExpectedMessage '*exceeding the 1 MB ceiling. Largest plugins: huge*large*medium*'
        }

        It 'Omits packages outside the three largest from the failure' {
            $thrownMessage = ''
            try {
                Assert-PluginOutputSize -PluginsDir $script:sizeRoot -MaxTotalSizeMB 1
            }
            catch {
                $thrownMessage = $_.Exception.Message
            }
            $thrownMessage | Should -Not -Match 'small'
        }
    }
}

Describe 'Invoke-PluginGeneration' -Tag 'Unit' {
    BeforeEach {
        $script:GeneratorHostLog.Clear()
        $script:generatorRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        $script:generatorStagingRoot = Join-Path $TestDrive "$([System.Guid]::NewGuid())-staging"
        $env:HVE_PLUGIN_STAGING_ROOT = $script:generatorStagingRoot
    }

    Context 'when the staging root is unavailable or unsafe' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
        }

        It 'Rejects a missing staging root' {
            $env:HVE_PLUGIN_STAGING_ROOT = ''
            { Invoke-PluginGeneration -RepoRoot $script:generatorRepo } |
                Should -Throw -ExpectedMessage '*A staging root is required*'
        }

        It 'Rejects a staging root inside the fixture repository' {
            { Invoke-PluginGeneration -RepoRoot $script:generatorRepo `
                    -StagingRoot (Join-Path $script:generatorRepo 'plugins') } |
                Should -Throw -ExpectedMessage '*resolves inside the repository root*'
        }

        It 'Accepts an explicit sibling path and creates no repository output' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -StagingRoot $script:generatorStagingRoot | Out-Null
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi/plugin.json') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:generatorRepo 'plugins') | Should -BeFalse
        }
    }

    Context 'when generating a package that declares every artifact kind' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:generatorRepo -RelativePath '.github/skills/rpi/rpi-plan/.venv/lib/site.py' -Content "sentinel_venv`n" -Untracked | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:generatorRepo -RelativePath '.github/skills/rpi/rpi-plan/__pycache__/cache.pyc' -Content "sentinel_pycache`n" -Untracked | Out-Null

            $script:generationResult = Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh
            $script:generatedRoot = Join-Path $script:generatorStagingRoot 'rpi'
            $script:generatedInventory = @(Get-PluginFixtureInventory -Path $script:generatedRoot)
        }

        It 'Reports one generated package' {
            $script:generationResult.Success | Should -BeTrue
            $script:generationResult.PluginCount | Should -Be 1
            @($script:generationResult.Keys | Sort-Object) | Should -Be @('ErrorMessage', 'PluginCount', 'Success')
        }

        It 'Generates exactly the declared package tree' {
            $script:generatedInventory | Should -Be @(
                @(
                    'README.md',
                    'agents/rpi/rpi-planner.md',
                    'commands/rpi/rpi-plan.md',
                    'docs/templates/adr-template.md',
                    'hooks/rpi/telemetry.json',
                    'hooks/rpi/telemetry/collect.sh',
                    'plugin.json',
                    'rules/shared/hve-core-location.instructions.md',
                    'scripts/lib/Modules/Shared.psm1',
                    'skills/rpi/rpi-plan/SKILL.md',
                    'skills/rpi/rpi-plan/references/checklist.md'
                ) | Sort-Object
            )
        }

        It 'Places instructions under the rules component directory' {
            Test-Path -LiteralPath (Join-Path $script:generatedRoot 'rules/shared/hve-core-location.instructions.md') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:generatedRoot 'instructions') | Should -BeFalse
        }

        It 'Needs no collections directory' {
            Test-Path -LiteralPath (Join-Path $script:generatorRepo 'collections') | Should -BeFalse
        }

        It 'Excludes untracked residue and its sentinels' {
            $generatedText = @(Get-ChildItem -LiteralPath $script:generatedRoot -File -Recurse -Force |
                    ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
            foreach ($sentinel in @('sentinel_venv', 'sentinel_pycache')) {
                $generatedText | Should -Not -Match $sentinel
            }
            $script:generatedInventory | Should -Not -Contain 'skills/rpi/rpi-plan/.venv/lib/site.py'
            $script:generatedInventory | Should -Not -Contain 'skills/rpi/rpi-plan/__pycache__/cache.pyc'
        }

        It 'Emits no symbolic link' {
            @(Get-PluginFixtureReparsePoint -Path $script:generatorStagingRoot) | Should -HaveCount 0
        }

        It 'Emits no catalog overlay anywhere in the output' {
            foreach ($generatedFile in Get-ChildItem -LiteralPath $script:generatedRoot -File -Recurse -Force) {
                (Get-Content -LiteralPath $generatedFile.FullName -Raw) | Should -Not -Match 'x-hve'
            }
        }

        It 'Produces byte-identical output on a second refresh' {
            $firstDigest = Get-PluginFixtureTreeDigest -Path $script:generatorStagingRoot
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
            Get-PluginFixtureTreeDigest -Path $script:generatorStagingRoot | Should -BeExactly $firstDigest
        }
    }

    Context 'when resolving the catalog path' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            Add-PluginFixtureCatalog -RepoRoot $script:generatorRepo -Entries @(New-RpiEntry -Name 'alt') `
                -Version '9.9.9' -RelativePath 'alt/marketplace.json' | Out-Null
        }

        It 'Defaults to the repository catalog' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi/plugin.json') -PathType Leaf | Should -BeTrue
        }

        It 'Accepts a repository-relative catalog path' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -CatalogPath 'alt/marketplace.json' | Out-Null
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'alt/plugin.json') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi') | Should -BeFalse
        }

        It 'Accepts an absolute catalog path' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh `
                -CatalogPath (Join-Path $script:generatorRepo 'alt/marketplace.json') | Out-Null
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'alt/plugin.json') -PathType Leaf | Should -BeTrue
        }
    }

    Context 'when the catalog declares no package' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @() | Out-Null
            $script:emptyCatalogResult = Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh
        }

        It 'Returns a successful zero-package result' {
            $script:emptyCatalogResult.Success | Should -BeTrue
            $script:emptyCatalogResult.PluginCount | Should -Be 0
            $script:emptyCatalogResult.ErrorMessage | Should -BeExactly ''
        }

        It 'Creates no output directory' {
            Test-Path -LiteralPath $script:generatorStagingRoot | Should -BeFalse
        }

        It 'Warns that the catalog declares no package' {
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'No packages declared in' }
        }
    }

    Context 'when an unknown package name is requested' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            $script:filteredResult = Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -PackageNames @('rpi', 'ghost')
        }

        It 'Warns about the missing package name' {
            Should -Invoke Write-Warning -Times 1 -Exactly -ParameterFilter { $Message -match 'Packages not found: ghost' }
        }

        It 'Generates only the packages that exist' {
            $script:filteredResult.PluginCount | Should -Be 1
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name }) |
                Should -Be @('rpi')
        }
    }

    Context 'when the catalog declares several packages' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(
                New-RpiEntry -Name 'zulu'
                New-RpiEntry -Name 'alpha'
                New-RpiEntry -Name 'mike'
            ) | Out-Null
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
        }

        It 'Generates packages in sorted order' {
            $generationLines = @($script:GeneratorHostLog | Where-Object { $_ -match '^  \S+ \(\d+ items\)$' })
            $generationLines | Should -Be @('  alpha (5 items)', '  mike (5 items)', '  zulu (5 items)')
        }

        It 'Creates one directory per package' {
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name } | Sort-Object) |
                Should -Be @('alpha', 'mike', 'zulu')
        }
    }

    Context 'when a package is deprecated or removed' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(
                New-RpiEntry -Name 'active'
                New-RpiEntry -Name 'retired' -Overlay @{ maturity = 'deprecated' }
                New-RpiEntry -Name 'deleted' -Overlay @{ maturity = 'removed' }
            ) | Out-Null
            $script:maturityResult = Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh
        }

        It 'Generates only the active package' {
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name }) |
                Should -Be @('active')
            $script:maturityResult.PluginCount | Should -Be 1
        }
    }

    Context 'when a component declares a non-stable maturity' {
        BeforeEach {
            New-PluginFixtureRepository -Path $script:generatorRepo -Version '9.9.9' | Out-Null
            Add-PluginFixtureArtifactSet -RepoRoot $script:generatorRepo | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:generatorRepo -RelativePath '.github/skills/rpi/rpi-lab/SKILL.md' `
                -Content "---`nname: rpi-lab`ndescription: Experimental lab skill`n---`n`n# Lab`n" | Out-Null
            Add-PluginFixtureCatalog -RepoRoot $script:generatorRepo -Version '9.9.9' -Entries @(
                New-PluginFixtureEntry -Name 'rpi' -Description 'RPI workflow package' -Version '9.9.9' `
                    -Skills @('skills/rpi/rpi-plan', 'skills/rpi/rpi-lab') `
                    -Overlay @{ componentMaturity = @{ 'skills/rpi/rpi-lab' = 'experimental' } }
            ) | Out-Null
        }

        It 'Includes the experimental component on the <Channel> channel' -ForEach @(
            @{ Channel = 'Stable' }
            @{ Channel = 'PreRelease' }
        ) {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -Channel $Channel | Out-Null
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi/skills/rpi/rpi-plan/SKILL.md') -PathType Leaf | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi/skills/rpi/rpi-lab/SKILL.md') -PathType Leaf | Should -BeTrue
        }
    }

    Context 'when refreshing over stale output' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            $script:staleFile = Join-Path $script:generatorStagingRoot 'rpi/stale/orphan.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $script:staleFile) -Force | Out-Null
            Set-Content -LiteralPath $script:staleFile -Value "sentinel_orphan`n" -Encoding utf8NoBOM -NoNewline
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
        }

        It 'Removes the orphaned file' {
            Test-Path -LiteralPath $script:staleFile | Should -BeFalse
        }

        It 'Removes the directory the orphan left empty' {
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi/stale') | Should -BeFalse
        }
    }

    Context 'when a package is dropped from the catalog' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(
                New-RpiEntry -Name 'hve-core'
                New-RpiEntry -Name 'ado'
                New-RpiEntry -Name 'security'
            ) | Out-Null
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null

            Add-PluginFixtureCatalog -RepoRoot $script:generatorRepo -Version '9.9.9' -Entries @(
                New-RpiEntry -Name 'hve-core'
            ) | Out-Null
        }

        It 'Leaves only the declared package root' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name } | Sort-Object) |
                Should -Be @('hve-core')
        }

        It 'Converges on repeated generation' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name }) |
                Should -Be @('hve-core')
        }

        It 'Removes a stale root that was never declared' {
            $undeclared = Join-Path $script:generatorStagingRoot 'hve-core-all/plugin.json'
            New-Item -ItemType Directory -Path (Split-Path -Parent $undeclared) -Force | Out-Null
            Set-Content -LiteralPath $undeclared -Value "{}`n" -Encoding utf8NoBOM -NoNewline
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
            Test-Path -LiteralPath (Join-Path $script:generatorStagingRoot 'hve-core-all') | Should -BeFalse
        }

        It 'Preserves a stale root when generating a named subset' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -PackageNames 'hve-core' | Out-Null
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name } | Sort-Object) |
                Should -Be @('ado', 'hve-core', 'security')
        }

        It 'Reports the stale roots without deleting them on a dry run' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -DryRun | Out-Null
            $script:GeneratorHostLog | Should -Contain '  [DRY RUN] Would remove stale plugin root: ado'
            @(Get-ChildItem -LiteralPath $script:generatorStagingRoot -Directory | ForEach-Object { $_.Name } | Sort-Object) |
                Should -Be @('ado', 'hve-core', 'security')
        }
    }

    Context 'when a component is dropped from the catalog' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null

            Add-PluginFixtureCatalog -RepoRoot $script:generatorRepo -Version '9.9.9' -Entries @(
                New-PluginFixtureEntry -Name 'rpi' -Description 'RPI workflow package' -Version '9.9.9' `
                    -Agents @('agents/rpi/rpi-planner.agent.md')
            ) | Out-Null
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh | Out-Null
        }

        It 'Removes the dropped component from the package tree' {
            @(Get-PluginFixtureInventory -Path (Join-Path $script:generatorStagingRoot 'rpi')) | Should -Be @(
                @(
                    'README.md',
                    'agents/rpi/rpi-planner.md',
                    'docs/templates/adr-template.md',
                    'plugin.json',
                    'scripts/lib/Modules/Shared.psm1'
                ) | Sort-Object
            )
        }
    }

    Context 'when projecting a marketplace snapshot' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            $script:catalogPath = Join-Path $script:generatorRepo '.github/plugin/marketplace.json'
            $script:catalogBytesBefore = [System.IO.File]::ReadAllBytes($script:catalogPath)
        }

        It 'Refuses a release tag without an explicit destination' {
            { Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -ReleaseTag 'plugins-v4.5.6' } |
                Should -Throw -ExpectedMessage '*requires -MarketplaceOutputPath*'
            [System.IO.File]::ReadAllBytes($script:catalogPath) | Should -Be $script:catalogBytesBefore
        }

        It 'Writes the pinned snapshot to the explicit destination' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -ReleaseTag 'plugins-v4.5.6' `
                -MarketplaceOutputPath 'out/marketplace.json' | Out-Null
            $snapshot = Get-Content -LiteralPath (Join-Path $script:generatorRepo 'out/marketplace.json') -Raw | ConvertFrom-Json -AsHashtable
            @($snapshot['plugins'] | ForEach-Object { $_['source']['ref'] }) | Should -Be @('plugins-v4.5.6')
        }

        It 'Projects the release version into the catalog and plugin manifest' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -ReleaseTag 'plugins-v4.5.6' `
                -MarketplaceOutputPath 'out/marketplace.json' | Out-Null
            $snapshot = Get-Content -LiteralPath (Join-Path $script:generatorRepo 'out/marketplace.json') -Raw | ConvertFrom-Json -AsHashtable
            $pluginManifest = Get-Content -LiteralPath (Join-Path $script:generatorStagingRoot 'rpi/plugin.json') -Raw | ConvertFrom-Json -AsHashtable

            [string]$snapshot['metadata']['version'] | Should -BeExactly '4.5.6'
            @($snapshot['plugins'] | ForEach-Object { [string]$_['version'] }) | Should -Be @('4.5.6')
            [string]$pluginManifest['version'] | Should -BeExactly '4.5.6'
            [System.IO.File]::ReadAllBytes($script:catalogPath) | Should -Be $script:catalogBytesBefore
        }

        It 'Leaves the production catalog byte-identical' {
            Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -ReleaseTag 'plugins-v4.5.6' `
                -MarketplaceOutputPath 'out/marketplace.json' | Out-Null
            [System.IO.File]::ReadAllBytes($script:catalogPath) | Should -Be $script:catalogBytesBefore
        }
    }

    Context 'when running as a dry run' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            $script:dryRunGeneration = Invoke-PluginGeneration -RepoRoot $script:generatorRepo -DryRun `
                -MarketplaceOutputPath 'out/marketplace.json'
        }

        It 'Reports the packages it would generate' {
            $script:dryRunGeneration.PluginCount | Should -Be 1
        }

        It 'Writes nothing to disk' {
            Test-Path -LiteralPath $script:generatorStagingRoot | Should -BeFalse
            Test-Path -LiteralPath (Join-Path $script:generatorRepo 'out') | Should -BeFalse
        }
    }

    Context 'when the generated output exceeds the size ceiling' {
        BeforeEach {
            New-GeneratorFixture -Root $script:generatorRepo -Entries @(New-RpiEntry) | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:generatorRepo -RelativePath '.github/skills/rpi/rpi-plan/payload.txt' `
                -Content ('x' * 1400000) | Out-Null
        }

        It 'Fails generation and names the offending package' {
            { Invoke-PluginGeneration -RepoRoot $script:generatorRepo -Refresh -MaxTotalSizeMB 1 } |
                Should -Throw -ExpectedMessage '*exceeding the 1 MB ceiling. Largest plugins: rpi*'
        }
    }
}

Describe 'Start-PluginGeneration' -Tag 'Unit' {
    BeforeEach {
        $script:GeneratorHostLog.Clear()
        $script:entryRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
        New-GeneratorFixture -Root $script:entryRepo -Entries @(New-RpiEntry) | Out-Null
        $script:entryScriptPath = Add-PluginFixtureFile -RepoRoot $script:entryRepo `
            -RelativePath 'scripts/plugins/Generate-Plugins.ps1' -Content "# fixture entry point`n"
        $script:entryStagingRoot = Join-Path $TestDrive "$([System.Guid]::NewGuid())-staging"
        Mock Write-CIAnnotation {}
    }

    Context 'when generation succeeds' {
        It 'Returns the success exit code' {
            Start-PluginGeneration -ScriptPath $script:entryScriptPath -StagingRoot $script:entryStagingRoot | Should -Be 0
        }

        It 'Defaults to refreshing every package' {
            $orphanFile = Join-Path $script:entryStagingRoot 'rpi/stale/orphan.md'
            New-Item -ItemType Directory -Path (Split-Path -Parent $orphanFile) -Force | Out-Null
            Set-Content -LiteralPath $orphanFile -Value "orphan`n" -Encoding utf8NoBOM -NoNewline

            Start-PluginGeneration -ScriptPath $script:entryScriptPath -StagingRoot $script:entryStagingRoot | Should -Be 0
            Test-Path -LiteralPath $orphanFile | Should -BeFalse
        }
    }

    Context 'when generation fails' {
        It 'Returns the failure exit code' {
            Start-PluginGeneration -ScriptPath $script:entryScriptPath -StagingRoot $script:entryStagingRoot -CatalogPath 'absent/marketplace.json' -ErrorAction SilentlyContinue |
                Should -Be 1
        }

        It 'Emits a CI annotation for the failure' {
            Start-PluginGeneration -ScriptPath $script:entryScriptPath -StagingRoot $script:entryStagingRoot -CatalogPath 'absent/marketplace.json' -ErrorAction SilentlyContinue | Out-Null
            Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter { $Level -eq 'Error' }
        }
    }

    Context 'when the YAML prerequisite is unavailable' {
        It 'Fails before generating anything' {
            Mock Get-Module { } -ParameterFilter { $ListAvailable.IsPresent -and $Name -contains 'PowerShell-Yaml' }

            Start-PluginGeneration -ScriptPath $script:entryScriptPath -StagingRoot $script:entryStagingRoot -ErrorAction SilentlyContinue | Should -Be 1
            Test-Path -LiteralPath (Join-Path $script:entryRepo 'plugins') | Should -BeFalse
            Should -Invoke Write-CIAnnotation -Times 1 -Exactly -ParameterFilter { $Message -match "PowerShell-Yaml' is not installed" }
        }
    }
}

AfterAll {
    $env:HVE_PLUGIN_STAGING_ROOT = $script:OriginalPluginStagingRoot
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module PluginHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}
