#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../plugins/Validate-Marketplace.ps1')
    Import-Module (Join-Path $PSScriptRoot 'PluginTestFixtures.psm1') -Force
    Mock Write-Host {}
    Mock Write-Warning {}
    Mock Write-Warning {} -ModuleName MarketplaceHelpers

    $script:ComponentPaths = @{
        Agents   = @('agents/rpi/rpi-planner.md')
        Commands = @('commands/rpi/rpi-plan.md')
        Rules    = @('rules/shared/hve-core-location.instructions.md')
        Skills   = @('skills/rpi/rpi-plan')
        Hook     = 'hooks/rpi/telemetry.json'
    }

    function New-ValidatorFixture {
        <#
        .SYNOPSIS
        Builds a repository fixture whose catalog satisfies every contract rule.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter()][hashtable]$PackageOverlay,
            [Parameter()][switch]$SkipAgentRoot,
            [Parameter()][switch]$SkipDocumentationRoot,
            [Parameter()][switch]$AddSecondPackage
        )

        New-PluginFixtureRepository -Path $Root -Version '9.9.9' `
            -SkipAgentRoot:$SkipAgentRoot -SkipDocumentationRoot:$SkipDocumentationRoot | Out-Null
        Add-PluginFixtureArtifactSet -RepoRoot $Root | Out-Null

        $packageOverlayValues = @{
            componentMaturity = @{ 'skills/rpi/rpi-retired' = 'removed' }
            profiles          = @{ starter = @($script:ComponentPaths.Agents[0], $script:ComponentPaths.Skills[0]) }
        }
        if ($PackageOverlay) {
            foreach ($key in @($PackageOverlay.Keys)) { $packageOverlayValues[$key] = $PackageOverlay[$key] }
        }

        $entries = @(
            New-PluginFixtureEntry -Name 'rpi' -Description 'RPI workflow package' -Version '9.9.9' `
                -Agents $script:ComponentPaths.Agents -Commands $script:ComponentPaths.Commands `
                -Rules $script:ComponentPaths.Rules -Skills $script:ComponentPaths.Skills `
                -Hook $script:ComponentPaths.Hook -Overlay $packageOverlayValues
        )
        if ($AddSecondPackage) {
            Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/agents/ops/ops-auditor.agent.md' `
                -Content "---`nname: Ops Auditor`ndescription: Audits operations`n---`n`n# Ops Auditor`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/prompts/ops/ops-audit.prompt.md' `
                -Content "---`ndescription: Runs an ops audit`n---`n`n# Ops Audit`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/instructions/ops/ops-baseline.instructions.md' `
                -Content "---`ndescription: Ops baseline rules`n---`n`n# Ops Baseline`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/skills/ops/ops-toolkit/SKILL.md' `
                -Content "---`nname: ops-toolkit`ndescription: Ops toolkit`n---`n`n# Ops Toolkit`n" | Out-Null
            Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/hooks/ops/audit.json' `
                -Content '{"description":"Records ops audits","hooks":{"SessionStart":[{"command":".github/hooks/ops/audit/collect.sh"}]}}' | Out-Null
            Add-PluginFixtureFile -RepoRoot $Root -RelativePath '.github/hooks/ops/audit/collect.sh' `
                -Content "#!/usr/bin/env bash`necho audit`n" | Out-Null

            $entries += New-PluginFixtureEntry -Name 'ops' -Description 'Ops audit package' -Version '9.9.9' `
                -Agents @('agents/ops/ops-auditor.md') -Commands @('commands/ops/ops-audit.md') `
                -Rules @('rules/ops/ops-baseline.instructions.md') -Skills @('skills/ops/ops-toolkit') `
                -Hook 'hooks/ops/audit.json'
        }
        Add-PluginFixtureCatalog -RepoRoot $Root -Entries $entries -Version '9.9.9' `
            -SkipDocuments:$SkipDocumentationRoot | Out-Null
        return $Root
    }

    function Get-ValidationReport {
        <#
        .SYNOPSIS
        Runs validation and returns the parsed structured report.
        #>
        param([Parameter(Mandatory)][string]$Root)

        $reportPath = Join-Path $Root 'logs/marketplace-validation-results.json'
        $outcome = Invoke-MarketplaceValidation -RepoRoot $Root -OutputPath 'logs/marketplace-validation-results.json'
        return @{
            Outcome = $outcome
            Report  = (Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -AsHashtable)
        }
    }

    function Get-ReportError {
        <#
        .SYNOPSIS
        Flattens every error message recorded in a structured report.
        #>
        param([Parameter(Mandatory)][hashtable]$Report)

        return [string[]]@($Report['Results'] | ForEach-Object { $_['Errors'] })
    }

    function Set-CatalogEntry {
        <#
        .SYNOPSIS
        Rewrites the fixture catalog after applying a mutation to its entries.
        #>
        param(
            [Parameter(Mandatory)][string]$Root,
            [Parameter(Mandatory)][scriptblock]$Mutation
        )

        $catalogPath = Join-Path $Root '.github/plugin/marketplace.json'
        $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -AsHashtable
        & $Mutation $catalog
        Set-Content -LiteralPath $catalogPath -Value (($catalog | ConvertTo-Json -Depth 12) + "`n") -Encoding utf8NoBOM -NoNewline
    }
}

Describe 'Test-PluginSourcePath' -Tag 'Unit' {
    Context 'when the package path is well formed' {
        It 'Accepts <Path>' -ForEach @(
            @{ Path = 'plugins/rpi' }
            @{ Path = 'plugins/nested/rpi' }
        ) {
            Test-PluginSourcePath -Path $Path | Should -BeExactly ''
        }
    }

    Context 'when the package path is malformed' {
        It 'Rejects <Label>' -ForEach @(
            @{ Label = 'a backslash separator'; Path = 'plugins\rpi'; Pattern = 'must use forward slashes' }
            @{ Label = 'a rooted path'; Path = '/plugins/rpi'; Pattern = 'must be relative to the repository root' }
            @{ Label = 'a drive-qualified path'; Path = 'C:/plugins/rpi'; Pattern = 'must be relative to the repository root' }
            @{ Label = 'an empty segment'; Path = 'plugins//rpi'; Pattern = 'must not contain empty path segments' }
            @{ Label = 'an escaping segment'; Path = 'plugins/../etc'; Pattern = 'must not escape the source repository' }
            @{ Label = 'a relative segment'; Path = 'plugins/./rpi'; Pattern = 'must not contain relative path segments' }
        ) {
            Test-PluginSourcePath -Path $Path | Should -Match $Pattern
        }
    }
}

Describe 'Test-PluginObjectSource' -Tag 'Unit' {
    Context 'when the locator is immutable and complete' {
        It 'Reports no error' {
            $sourceErrors = @(Test-PluginObjectSource -Source ([ordered]@{
                        source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9'
                    }))
            $sourceErrors | Should -HaveCount 0
        }
    }

    Context 'when the locator is incomplete or mutable' {
        It 'Rejects <Label>' -ForEach @(
            @{ Label = 'a missing source type'; Source = @{ repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9' }; Pattern = "missing required field 'source'" }
            @{ Label = 'an unsupported source type'; Source = @{ source = 'gitlab'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9' }; Pattern = 'is not supported \(expected: github\)' }
            @{ Label = 'a missing repository'; Source = @{ source = 'github'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9' }; Pattern = "missing required field 'repo'" }
            @{ Label = 'a malformed repository'; Source = @{ source = 'github'; repo = 'contoso'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9' }; Pattern = "must use 'owner/name' form" }
            @{ Label = 'a missing package path'; Source = @{ source = 'github'; repo = 'contoso/contoso-hve'; ref = 'plugins-v9.9.9' }; Pattern = "missing required field 'path'" }
            @{ Label = 'an escaping package path'; Source = @{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/../etc'; ref = 'plugins-v9.9.9' }; Pattern = 'must not escape the source repository' }
            @{ Label = 'a missing ref'; Source = @{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi' }; Pattern = "'ref' must be a non-empty string" }
            @{ Label = 'a branch ref'; Source = @{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = 'main' }; Pattern = "must use the immutable 'plugins-v<version>' tag form" }
            @{ Label = 'a sha ref'; Source = @{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = '0123456789abcdef0123456789abcdef01234567' }; Pattern = "must use the immutable 'plugins-v<version>' tag form" }
            @{ Label = 'a sha field'; Source = @{ source = 'github'; repo = 'contoso/contoso-hve'; path = 'plugins/rpi'; ref = 'plugins-v9.9.9'; sha = '0123456789abcdef0123456789abcdef01234567' }; Pattern = "'sha' is not supported" }
        ) {
            $sourceErrors = @(Test-PluginObjectSource -Source $Source)
            $sourceErrors | Should -Not -BeNullOrEmpty
            ($sourceErrors -join ' ') | Should -Match $Pattern
        }
    }
}

Describe 'Invoke-MarketplaceValidation' -Tag 'Unit' {
    BeforeEach {
        $script:validatorRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
    }

    Context 'when the catalog satisfies every contract rule' {
        BeforeEach {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            $script:cleanRun = Get-ValidationReport -Root $script:validatorRepo
        }

        It 'Reports success with no error' {
            $script:cleanRun.Outcome.Success | Should -BeTrue
            $script:cleanRun.Outcome.ErrorCount | Should -Be 0
        }

        It 'Writes a structured report with one result per package' {
            @($script:cleanRun.Report.Keys | Sort-Object) | Should -Be @('ErrorCount', 'Results', 'Timestamp')
            @($script:cleanRun.Report['Results'] | ForEach-Object { $_['PluginName'] } | Sort-Object) |
                Should -Be @('rpi')
            foreach ($result in $script:cleanRun.Report['Results']) {
                $result['IsValid'] | Should -BeTrue
                @($result['Errors']) | Should -HaveCount 0
                @($result.Keys | Sort-Object) | Should -Be @('Errors', 'IsValid', 'PluginName', 'Warnings')
            }
        }

        It 'Records a parsable ISO 8601 timestamp' {
            { [datetime]::Parse($script:cleanRun.Report['Timestamp']) } | Should -Not -Throw
        }
    }

    Context 'when the catalog file is absent' {
        BeforeEach {
            New-PluginFixtureRepository -Path $script:validatorRepo -Version '9.9.9' | Out-Null
            $script:missingRun = Get-ValidationReport -Root $script:validatorRepo
        }

        It 'Fails with a single finding' {
            $script:missingRun.Outcome.Success | Should -BeFalse
            $script:missingRun.Outcome.ErrorCount | Should -Be 1
        }

        It 'Short-circuits with a marketplace-scoped result' {
            @($script:missingRun.Report['Results']) | Should -HaveCount 1
            $script:missingRun.Report['Results'][0]['PluginName'] | Should -BeExactly 'marketplace'
            @($script:missingRun.Report['Results'][0]['Errors']) | Should -Be @('marketplace.json not found')
        }
    }

    Context 'when the catalog is not valid JSON' {
        BeforeEach {
            New-PluginFixtureRepository -Path $script:validatorRepo -Version '9.9.9' | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:validatorRepo -RelativePath '.github/plugin/marketplace.json' -Content '{ "plugins": [ ' | Out-Null
            $script:invalidJsonRun = Get-ValidationReport -Root $script:validatorRepo
        }

        It 'Fails with a single parse finding' {
            $script:invalidJsonRun.Outcome.Success | Should -BeFalse
            $script:invalidJsonRun.Outcome.ErrorCount | Should -Be 1
        }

        It 'Reports the parse failure without evaluating later rules' {
            @($script:invalidJsonRun.Report['Results']) | Should -HaveCount 1
            (Get-ReportError -Report $script:invalidJsonRun.Report) -join ' ' | Should -Match 'invalid JSON'
        }
    }

    Context 'when a required top-level field is absent' {
        It 'Reports the missing field <Field> and short-circuits' -ForEach @(
            @{ Field = 'owner' }
            @{ Field = 'metadata' }
            @{ Field = 'plugins' }
            @{ Field = 'name' }
        ) {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog.Remove($Field) }

            $run = Get-ValidationReport -Root $script:validatorRepo
            $run.Outcome.Success | Should -BeFalse
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "missing required field '$Field'"
        }
    }

    Context 'when catalog metadata or owner is incomplete' {
        It 'Reports the missing metadata field <Field>' -ForEach @(
            @{ Field = 'description' }
            @{ Field = 'version' }
            @{ Field = 'pluginRoot' }
        ) {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog['metadata'].Remove($Field) }

            $run = Get-ValidationReport -Root $script:validatorRepo
            $run.Outcome.Success | Should -BeFalse
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "missing required metadata field '$Field'"
        }

        It 'Reports a blank owner name' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog['owner']['name'] = '  ' }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "missing required owner field 'name'"
        }
    }

    Context 'when versions disagree with package.json' {
        It 'Reports a catalog metadata version mismatch' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog['metadata']['version'] = '1.0.0' }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "metadata.version '1.0.0' does not match package.json version '9.9.9'"
        }

        It 'Reports a package version mismatch' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog['plugins'][0]['version'] = '1.0.0' }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "version '1\.0\.0' does not match package.json version '9\.9\.9'"
        }
    }

    Context 'when two packages share a name' {
        It 'Reports the duplicate' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation {
                param($catalog)
                $catalog['plugins'] = @($catalog['plugins'][0], $catalog['plugins'][0])
            }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "duplicate plugin name 'rpi'"
        }
    }

    Context 'when a package source is not an immutable object locator' {
        It 'Reports <Label>' -ForEach @(
            @{ Label = 'a bare package name'; Value = 'rpi'; Pattern = 'source must be an immutable github locator object' }
            @{ Label = 'a blank source'; Value = ''; Pattern = "missing required field 'source'" }
        ) {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            $sourceValue = $Value
            Set-CatalogEntry -Root $script:validatorRepo -Mutation {
                param($catalog)
                $catalog['plugins'][0]['source'] = $sourceValue
            }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match $Pattern
        }
    }

    Context 'when the object locator disagrees with package identity by case' {
        It 'Reports a case-mismatched package path' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog['plugins'][0]['source']['path'] = 'plugins/RPI' }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "object source path must match package name 'plugins/rpi'"
        }

        It 'Reports a case-mismatched release ref' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation { param($catalog) $catalog['plugins'][0]['source']['ref'] = 'Plugins-v9.9.9' }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "object source ref must match package version 'plugins-v9\.9\.9'"
        }

        It 'Reports a sha locator field' {
            New-ValidatorFixture -Root $script:validatorRepo | Out-Null
            Set-CatalogEntry -Root $script:validatorRepo -Mutation {
                param($catalog)
                $catalog['plugins'][0]['source']['sha'] = '0123456789abcdef0123456789abcdef01234567'
            }

            $run = Get-ValidationReport -Root $script:validatorRepo
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match "'sha' is not supported"
        }
    }
}

Describe 'Test-MarketplaceRepositoryContract' -Tag 'Unit' {
    BeforeEach {
        $script:contractRepo = Join-Path $TestDrive ([System.Guid]::NewGuid().ToString())
    }

    Context 'when a canonical root is absent' {
        It 'Fails instead of returning no finding for <Label>' -ForEach @(
            @{ Label = 'a missing agent root'; SkipAgents = $true; SkipDocumentation = $false; Pattern = "canonical artifact root '\.github/agents' is missing" }
            @{ Label = 'a missing documentation root'; SkipAgents = $false; SkipDocumentation = $true; Pattern = "package documentation root 'docs/plugins' is missing" }
        ) {
            New-ValidatorFixture -Root $script:contractRepo -SkipAgentRoot:$SkipAgents -SkipDocumentationRoot:$SkipDocumentation | Out-Null
            if ($SkipAgents) {
                Remove-Item -LiteralPath (Join-Path $script:contractRepo '.github/agents') -Recurse -Force
            }

            $run = Get-ValidationReport -Root $script:contractRepo
            $run.Outcome.Success | Should -BeFalse
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match $Pattern
        }
    }

    Context 'when the documented package set and the catalog disagree' {
        It 'Reports a package document with no catalog package' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:contractRepo -RelativePath 'docs/plugins/ghost.md' `
                -Content "---`ntitle: Ghost`ndescription: Ghost`n---`n`nProse.`n" | Out-Null

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package document 'docs/plugins/ghost\.md' does not match any marketplace package"
        }

        It 'Reports a catalog package with no package document' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Remove-Item -LiteralPath (Join-Path $script:contractRepo 'docs/plugins/rpi.md') -Force

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' has no package document under docs/plugins"
        }
    }

    Context 'when package metadata is incomplete' {
        It 'Reports a blank display name' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation { param($catalog) $catalog['plugins'][0]['x-hve']['displayName'] = '  ' }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' must declare non-empty x-hve\.displayName"
        }

        It 'Reports an undeclared documentation path' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation { param($catalog) $catalog['plugins'][0]['x-hve'].Remove('documentation') }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' must declare x-hve\.documentation"
        }

        It 'Reports a documentation description that disagrees with the catalog' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:contractRepo -RelativePath 'docs/plugins/rpi.md' `
                -Content "---`ntitle: Contoso rpi`ndescription: Something else`n---`n`nProse.`n" | Out-Null

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' description does not match docs/plugins/rpi\.md"
        }

        It 'Reports a documentation file with no frontmatter' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:contractRepo -RelativePath 'docs/plugins/rpi.md' -Content "# Contoso rpi`n`nProse.`n" | Out-Null

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' documentation has no frontmatter"
        }
    }

    Context 'when a declared component source is absent' {
        It 'Reports the missing canonical source' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Remove-Item -LiteralPath (Join-Path $script:contractRepo '.github/prompts/rpi/rpi-plan.prompt.md') -Force

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' source is missing: \.github/prompts/rpi/rpi-plan\.prompt\.md"
        }
    }

    Context 'when a generated plugin manifest is present' {
        It 'Reports a manifest that does not mirror catalog identity' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:contractRepo -RelativePath 'plugins/rpi/plugin.json' `
                -Content '{"name":"rpi","version":"1.0.0"}' -Untracked | Out-Null

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' root plugin\.json identity does not mirror the catalog"
        }

        It 'Reports a manifest that carries the catalog overlay' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Add-PluginFixtureFile -RepoRoot $script:contractRepo -RelativePath 'plugins/rpi/plugin.json' `
                -Content '{"name":"rpi","version":"9.9.9","x-hve":{"displayName":"Contoso - rpi"}}' -Untracked | Out-Null

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: package 'rpi' root plugin\.json must not contain x-hve"
        }
    }

    Context 'when no removed component tombstone is declared' {
        It 'Reports the empty tombstone set' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation { param($catalog) $catalog['plugins'][0]['x-hve'].Remove('componentMaturity') }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match 'repository contract: repository marketplace must declare at least one removed component tombstone'
        }
    }

    Context 'when the catalog declares one or many ordinary recipes' {
        It 'Accepts a single-recipe catalog' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null

            $run = Get-ValidationReport -Root $script:contractRepo
            $run.Outcome.Success | Should -BeTrue
            $run.Outcome.ErrorCount | Should -Be 0
            @($run.Report['Results'] | ForEach-Object { $_['PluginName'] }) | Should -Be @('rpi')
        }

        It 'Accepts two recipes that each declare their own hook manifest' {
            New-ValidatorFixture -Root $script:contractRepo -AddSecondPackage | Out-Null
            $catalog = Get-Content -LiteralPath (Join-Path $script:contractRepo '.github/plugin/marketplace.json') -Raw |
                ConvertFrom-Json -AsHashtable
            @($catalog['plugins'] | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_['hooks']) }).Count |
                Should -Be 2

            $run = Get-ValidationReport -Root $script:contractRepo
            $run.Outcome.Success | Should -BeTrue
            $run.Outcome.ErrorCount | Should -Be 0
            @($run.Report['Results'] | ForEach-Object { $_['PluginName'] } | Sort-Object) | Should -Be @('ops', 'rpi')
        }

        It 'Reports conflicting maturity for a source shared by two packages' {
            New-ValidatorFixture -Root $script:contractRepo -AddSecondPackage | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation {
                param($catalog)
                $sharedComponent = 'agents/rpi/rpi-planner.md'
                $catalog['plugins'][1]['agents'] += $sharedComponent
                $catalog['plugins'][1]['x-hve']['componentMaturity'] = @{ $sharedComponent = 'preview' }
            }

            $run = Get-ValidationReport -Root $script:contractRepo
            $run.Outcome.Success | Should -BeFalse
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "repository contract: source '\.github/agents/rpi/rpi-planner\.agent\.md' must declare identical maturity across packages: ops=preview, rpi=stable"
        }

        It 'Keeps documentation, source identity, unique membership, and tombstones valid across both recipes' {
            New-ValidatorFixture -Root $script:contractRepo -AddSecondPackage | Out-Null
            $catalog = Get-Content -LiteralPath (Join-Path $script:contractRepo '.github/plugin/marketplace.json') -Raw |
                ConvertFrom-Json -AsHashtable

            $declared = @()
            foreach ($entry in @($catalog['plugins'])) {
                Join-Path $script:contractRepo ([string]$entry['x-hve']['documentation']) | Should -Exist
                [string]$entry['source']['path'] | Should -BeExactly "plugins/$([string]$entry['name'])"
                [string]$entry['source']['ref'] | Should -BeExactly "plugins-v$([string]$entry['version'])"
                $declared += @('agents', 'commands', 'rules', 'skills', 'hooks') |
                    ForEach-Object { @($entry[$_]) } | Where-Object { $_ }
            }
            @($declared | Sort-Object -Unique).Count | Should -Be $declared.Count
            @($catalog['plugins'] | Where-Object {
                    $_['x-hve'].Contains('componentMaturity') -and
                    @($_['x-hve']['componentMaturity'].Values) -contains 'removed'
                }).Count | Should -Be 1
        }

        It 'Still rejects an empty catalog' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation { param($catalog) $catalog['plugins'] = @() }

            $run = Get-ValidationReport -Root $script:contractRepo
            $run.Outcome.Success | Should -BeFalse
            (Get-ReportError -Report $run.Report) -join ' ' | Should -Match 'plugins array is empty or missing'
        }
    }

    Context 'when membership breaks one-recipe hygiene' {
        It 'Reports a root-level repository artifact' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation {
                param($catalog)
                $catalog['plugins'][0]['agents'] = @('agents/rpi/rpi-planner.md', 'agents/root-only.md')
            }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "component path 'agents/root-only\.md' is a root-level repository artifact and must not be declared"
        }

        It 'Reports an unlabeled experimental-namespace component' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation {
                param($catalog)
                $catalog['plugins'][0]['agents'] = @('agents/rpi/rpi-planner.md', 'agents/experimental/preview-only.md')
            }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "component path 'agents/experimental/preview-only\.md' is under an experimental namespace and must declare a non-stable x-hve\.componentMaturity"
        }

        It 'Reports a profile reference outside declared membership' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation {
                param($catalog)
                $catalog['plugins'][0]['x-hve']['profiles'] = @{ starter = @('agents/rpi/absent.md') }
            }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "x-hve\.profiles\['starter'\] references 'agents/rpi/absent\.md', which is not declared component membership"
        }

        It 'Reports a hook declared in an installer profile' {
            New-ValidatorFixture -Root $script:contractRepo | Out-Null
            Set-CatalogEntry -Root $script:contractRepo -Mutation {
                param($catalog)
                $catalog['plugins'][0]['x-hve']['profiles'] = @{ starter = @('agents/rpi/rpi-planner.md', 'hooks/rpi/telemetry.json') }
            }

            $run = Get-ValidationReport -Root $script:contractRepo
            (Get-ReportError -Report $run.Report) -join ' ' |
                Should -Match "x-hve\.profiles\['starter'\] references 'hooks/rpi/telemetry\.json' from non-installable field 'hooks'"
        }
    }
}

AfterAll {
    Remove-Module PluginTestFixtures -Force -ErrorAction SilentlyContinue
    Remove-Module MarketplaceHelpers -Force -ErrorAction SilentlyContinue
    Remove-Module CIHelpers -Force -ErrorAction SilentlyContinue
}
