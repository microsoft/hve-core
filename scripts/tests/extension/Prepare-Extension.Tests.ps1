#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    # MarketplaceHelpers reloads its nested ArtifactHelpers dependency, so shared
    # modules load before the script whose own imports settle the session state.
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force
    . (Join-Path $PSScriptRoot '../../extension/Prepare-Extension.ps1')
    Import-Module (Join-Path $PSScriptRoot '../../extension/Modules/ExtensionIdentity.psm1') -Force
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force
    $script:PrepareScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../extension/Prepare-Extension.ps1')).Path
    Mock Write-Host {}
}

Describe 'Prepare-Extension package identity' -Tag 'Unit' {
    Context 'when resolving the package parameter default' {
        It 'Declares hve-core as the script default package ID' {
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:PrepareScriptPath, [ref]$null, [ref]$parseErrors)
            $parseErrors | Should -BeNullOrEmpty
            $packageParameter = @($ast.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'PackageId' })
            $packageParameter | Should -HaveCount 1
            $packageParameter[0].DefaultValue.Extent.Text | Should -Be "'hve-core'"
        }

        It 'Declares hve-core as the preparation function default package ID' {
            (Get-Command Invoke-PrepareExtension).Parameters['PackageId'] | Should -Not -BeNullOrEmpty
            $parseErrors = $null
            $ast = [System.Management.Automation.Language.Parser]::ParseFile($script:PrepareScriptPath, [ref]$null, [ref]$parseErrors)
            $function = @($ast.FindAll({ $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }, $true) |
                    Where-Object { $_.Name -eq 'Invoke-PrepareExtension' })
            $function | Should -HaveCount 1
            $parameter = @($function[0].Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'PackageId' })
            $parameter[0].DefaultValue.Extent.Text | Should -Be "'hve-core'"
        }
    }

    Context 'when mapping package IDs to extension identities' {
        It 'Maps <PackageId> to <Expected>' -ForEach @(
            @{ PackageId = 'hve-core'; Expected = 'hve-core' }
            @{ PackageId = 'security'; Expected = 'hve-security' }
            @{ PackageId = 'coding-standards'; Expected = 'hve-coding-standards' }
        ) {
            Get-ExtensionIdentity -PackageId $PackageId -TemplateName 'hve-core' | Should -BeExactly $Expected
        }

        It 'Prefixes the retired hve-core-all package ID instead of special-casing it' {
            Get-ExtensionIdentity -PackageId 'hve-core-all' -TemplateName 'hve-core' | Should -BeExactly 'hve-hve-core-all'
        }

        It 'Uses the template name only for the hve-core package' {
            Get-ExtensionIdentity -PackageId 'hve-core' -TemplateName 'renamed-core' | Should -BeExactly 'renamed-core'
            Get-ExtensionIdentity -PackageId 'jira' -TemplateName 'renamed-core' | Should -BeExactly 'hve-jira'
        }

        It 'Reads the repository template name when no override is supplied' {
            $templatePath = (Resolve-Path (Join-Path $PSScriptRoot '../../../extension/templates/package.template.json')).Path
            $templateName = [string]((Get-Content -LiteralPath $templatePath -Raw -Encoding utf8 | ConvertFrom-Json).name)
            $templateName | Should -Not -BeNullOrEmpty
            Get-ExtensionIdentity -PackageId 'hve-core' | Should -BeExactly $templateName
        }
    }

    Context 'when naming generated package files' {
        It 'Names <PackageName> manifest <ExpectedManifest> and README <ExpectedReadme>' -ForEach @(
            @{ PackageName = 'hve-core'; ExpectedManifest = 'package.json'; ExpectedReadme = 'README.md' }
            @{ PackageName = 'hve-core-all'; ExpectedManifest = 'package.hve-core-all.json'; ExpectedReadme = 'README.hve-core-all.md' }
            @{ PackageName = 'security'; ExpectedManifest = 'package.security.json'; ExpectedReadme = 'README.security.md' }
        ) {
            Get-ExtensionPackageFileName -PackageName $PackageName | Should -BeExactly $ExpectedManifest
            Get-ExtensionReadmeFileName -PackageName $PackageName | Should -BeExactly $ExpectedReadme
        }
    }
}

Describe 'Prepare-Extension contributions' -Tag 'Unit' {
    BeforeAll {
        $script:Fixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive 'contribution-repo')
        $script:Catalog = Get-MarketplaceCatalog -Path $script:Fixture.CatalogPath
        $script:AgentIndex = Get-MarketplaceAgentIndex -Catalog $script:Catalog -RepoRoot $script:Fixture.RepoRoot
        $script:Entries = @{}
        foreach ($entry in @($script:Catalog['plugins'])) { $script:Entries[[string]$entry['name']] = $entry }
    }

    Context 'when projecting the resolved recipe for the core package' {
        BeforeAll {
            $script:PreReleaseItems = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:Entries['hve-core'] -Channel PreRelease -AgentIndex $script:AgentIndex)
            $script:PreReleaseContributions = Get-ExtensionContributions -Items $script:PreReleaseItems
        }

        It 'Emits the exact agent contribution inventory' {
            @($script:PreReleaseContributions.Agents.name) | Should -Be @('alpha')
            @($script:PreReleaseContributions.Agents.path) | Should -Be @('./.github/agents/core/alpha.agent.md')
        }

        It 'Emits the exact prompt contribution inventory' {
            @($script:PreReleaseContributions.Prompts.name) | Should -Be @('build')
            @($script:PreReleaseContributions.Prompts.path) | Should -Be @('./.github/prompts/core/build.prompt.md')
        }

        It 'Suffixes instruction contribution names and keeps canonical paths' {
            @($script:PreReleaseContributions.Instructions.name) | Should -Be @('style-instructions')
            @($script:PreReleaseContributions.Instructions.path) | Should -Be @('./.github/instructions/core/style.instructions.md')
        }

        It 'Points skill contributions at the SKILL.md entry file' {
            @($script:PreReleaseContributions.Skills.name) | Should -Be @('toolkit')
            @($script:PreReleaseContributions.Skills.path) | Should -Be @('./.github/skills/core/toolkit/SKILL.md')
        }

        It 'Resolves the same components on the Stable channel' {
            $stableItems = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:Entries['hve-core'] -Channel Stable -AgentIndex $script:AgentIndex)
            $stableContributions = Get-ExtensionContributions -Items $stableItems
            @($stableContributions.Prompts.name) | Should -Be @('build')
            @($stableContributions.Agents.name) | Should -Be @('alpha')
            @($stableContributions.Instructions.name) | Should -Be @('style-instructions')
            @($stableContributions.Skills.name) | Should -Be @('toolkit')
        }

        It 'Carries the declared preview label into the resolved recipe' {
            $previewItems = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:Entries['hve-core'] -Channel Stable -AgentIndex $script:AgentIndex |
                    Where-Object { $_.PackagePath -eq 'commands/core/build.md' })
            @($previewItems).Count | Should -Be 1
            $previewItems[0].Maturity | Should -BeExactly 'preview'
        }
    }

    Context 'when the package recipe declares hooks' {
        BeforeAll {
            $script:HookItems = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:Entries['hve-core'] -Channel PreRelease -AgentIndex $script:AgentIndex |
                    Where-Object { $_.Kind -eq 'hook' })
            $script:HookContributions = Get-ExtensionContributions -Items $script:HookItems
        }

        It 'Resolves at least one hook component so the exclusion is observable' {
            @($script:HookItems).Count | Should -BeGreaterThan 0
            @($script:HookItems.SourcePath) | Should -Be @('.github/hooks/core/session.json')
        }

        It 'Contributes no VS Code entries for hook components' {
            @($script:HookContributions.Agents).Count +
            @($script:HookContributions.Prompts).Count +
            @($script:HookContributions.Instructions).Count +
            @($script:HookContributions.Skills).Count | Should -Be 0
        }

        It 'Exposes exactly the four VS Code contribution buckets' {
            @($script:HookContributions.Keys | Sort-Object) | Should -Be @('Agents', 'Instructions', 'Prompts', 'Skills')
        }
    }

    Context 'when the resolved recipe includes handoff closure agents' {
        It 'Includes closure agents that the package never declared' {
            $declared = @($script:Entries['sample']['agents'])
            $declared | Should -Be @('agents/core/beta.md')
            $items = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:Entries['sample'] -Channel Stable -AgentIndex $script:AgentIndex)
            $contributions = Get-ExtensionContributions -Items $items
            @($contributions.Agents.name) | Should -Be @('alpha', 'beta')
        }
    }

    Context 'when ordering contributions' {
        It 'Sorts entries by contribution name rather than recipe order' {
            $items = @(Get-MarketplaceResolvedPackageRecipe -Entry $script:Entries['hve-core-all'] -Channel PreRelease -AgentIndex $script:AgentIndex)
            @($items | Where-Object { $_.Kind -eq 'skill' } | ForEach-Object { $_.PackagePath }) |
                Should -Be @('skills/core/toolkit', 'skills/labs/probe')
            $contributions = Get-ExtensionContributions -Items $items
            @($contributions.Skills.name) | Should -Be @('probe', 'toolkit')
        }
    }
}

Describe 'Prepare-Extension manifest contributes' -Tag 'Unit' {
    BeforeAll {
        $script:BaseManifest = [pscustomobject]@{ name = 'hve-sample'; version = '1.2.3' }
        $script:Updated = Update-PackageJsonContributes -PackageJson $script:BaseManifest `
            -ChatAgents @([pscustomobject]@{ name = 'alpha'; path = './a' }) `
            -ChatPromptFiles @() `
            -ChatInstructions @([pscustomobject]@{ name = 'style-instructions'; path = './s' }) `
            -ChatSkills @([pscustomobject]@{ name = 'toolkit'; path = './t/SKILL.md' })
    }

    It 'Writes contribution keys in a deterministic order' {
        @($script:Updated.contributes.PSObject.Properties.Name) |
            Should -Be @('chatAgents', 'chatPromptFiles', 'chatInstructions', 'chatSkills')
    }

    It 'Serializes contribution keys in the same deterministic order' {
        $serialized = $script:Updated | ConvertTo-Json -Depth 20
        $order = @([regex]::Matches($serialized, '"(chatAgents|chatPromptFiles|chatInstructions|chatSkills)"') |
                ForEach-Object { $_.Groups[1].Value })
        $order | Should -Be @('chatAgents', 'chatPromptFiles', 'chatInstructions', 'chatSkills')
    }

    It 'Preserves empty contribution buckets' {
        $script:Updated.contributes.chatPromptFiles | Should -HaveCount 0
    }

    It 'Leaves the source manifest untouched' {
        $script:BaseManifest.PSObject.Properties['contributes'] | Should -BeNullOrEmpty
    }
}

Describe 'Prepare-Extension package selection' -Tag 'Unit' {
    BeforeEach {
        $script:SelectionFixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive "selection-$([guid]::NewGuid().ToString('N'))")
    }

    Context 'when the requested package is absent from the catalog' {
        It 'Fails with the missing package message' {
            $result = Invoke-PrepareExtension -ExtensionDirectory $script:SelectionFixture.ExtensionDirectory `
                -RepoRoot $script:SelectionFixture.RepoRoot -Channel Stable -PackageId 'not-a-package'
            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -BeExactly "Marketplace package 'not-a-package' was not found exactly once."
        }

        It 'Generates no package files for the missing package' {
            Invoke-PrepareExtension -ExtensionDirectory $script:SelectionFixture.ExtensionDirectory `
                -RepoRoot $script:SelectionFixture.RepoRoot -Channel Stable -PackageId 'not-a-package' | Out-Null
            Test-Path -LiteralPath (Join-Path $script:SelectionFixture.ExtensionDirectory 'package.sample.json') | Should -BeFalse
        }
    }

    Context 'when the requested package is ineligible for the channel' {
        BeforeEach {
            $script:IneligibleResult = Invoke-PrepareExtension -ExtensionDirectory $script:SelectionFixture.ExtensionDirectory `
                -RepoRoot $script:SelectionFixture.RepoRoot -Channel Stable -PackageId 'retired'
        }

        It 'Reports success with the catalog version and zero contribution counts' {
            $script:IneligibleResult.Success | Should -BeTrue
            $script:IneligibleResult.Version | Should -BeExactly '9.9.9'
            $script:IneligibleResult.AgentCount | Should -Be 0
            $script:IneligibleResult.PromptCount | Should -Be 0
            $script:IneligibleResult.InstructionCount | Should -Be 0
            $script:IneligibleResult.SkillCount | Should -Be 0
            $script:IneligibleResult.ErrorMessage | Should -BeExactly ''
        }

        It 'Returns before generating or pruning any package file' {
            Test-Path -LiteralPath (Join-Path $script:SelectionFixture.ExtensionDirectory 'package.obsolete.json') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:SelectionFixture.ExtensionDirectory 'README.obsolete.md') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $script:SelectionFixture.ExtensionDirectory 'package.sample.json') | Should -BeFalse
            Get-Content -LiteralPath (Join-Path $script:SelectionFixture.ExtensionDirectory 'package.json') -Raw |
                Should -BeExactly "{`n  `"name`": `"placeholder`"`n}`n"
        }
    }

    Context 'when the selected package manifest declares an invalid version' {
        It 'Fails with the invalid version message' {
            $catalog = Get-ExtensionCatalogFixture
            $templatePath = Join-Path $script:SelectionFixture.RepoRoot 'extension/templates/package.template.json'
            $template = Get-Content -LiteralPath $templatePath -Raw -Encoding utf8 | ConvertFrom-Json
            $template.version = '9.9'
            Set-FixtureFile -Path $templatePath -Value (($template | ConvertTo-Json -Depth 8) + "`n")
            $catalog.plugins | Should -Not -BeNullOrEmpty

            $result = Invoke-PrepareExtension -ExtensionDirectory $script:SelectionFixture.ExtensionDirectory `
                -RepoRoot $script:SelectionFixture.RepoRoot -Channel Stable -PackageId 'hve-core'
            $result.Success | Should -BeFalse
            $result.ErrorMessage | Should -BeExactly 'Invalid version format in package.json: 9.9'
        }
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module ExtensionIdentity -Force -ErrorAction SilentlyContinue
}
