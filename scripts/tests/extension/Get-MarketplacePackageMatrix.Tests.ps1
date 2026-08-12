#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    # MarketplaceHelpers reloads its nested ArtifactHelpers dependency, so shared
    # modules load before the script whose own imports settle the session state.
    Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force
    . (Join-Path $PSScriptRoot '../../extension/Get-MarketplacePackageMatrix.ps1')
    Import-Module (Join-Path $PSScriptRoot 'ExtensionTestFixtures.psm1') -Force

    $script:RepositoryRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
    $script:MatrixScriptPath = (Resolve-Path (Join-Path $PSScriptRoot '../../extension/Get-MarketplacePackageMatrix.ps1')).Path
    $script:RepositoryCatalogPath = Join-Path $script:RepositoryRoot '.github/plugin/marketplace.json'
    $script:WorkflowDirectory = Join-Path $script:RepositoryRoot '.github/workflows'

    function Get-CatalogEligibleName {
        <#
        .SYNOPSIS
        Returns catalog package names eligible for a channel, computed independently.
        .PARAMETER CatalogPath
        Marketplace catalog path.
        .PARAMETER Channel
        Stable or PreRelease channel.
        .OUTPUTS
        [string[]] Sorted eligible package names.
        #>
        [CmdletBinding()]
        [OutputType([string[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$CatalogPath,

            [Parameter(Mandatory = $true)]
            [ValidateSet('Stable', 'PreRelease')]
            [string]$Channel
        )

        $document = Get-Content -LiteralPath $CatalogPath -Raw -Encoding utf8 | ConvertFrom-Json
        $names = foreach ($entry in $document.plugins) {
            $maturity = if ($entry.'x-hve'.maturity) { [string]$entry.'x-hve'.maturity } else { 'stable' }
            if ($maturity -in @('deprecated', 'removed')) { continue }
            [string]$entry.name
        }
        $sorted = [string[]]@($names)
        [array]::Sort($sorted, [System.StringComparer]::Ordinal)
        return $sorted
    }

    function Get-PackageMatrixConsumer {
        <#
        .SYNOPSIS
        Returns workflow jobs whose strategy matrix consumes a discovered package matrix.
        .PARAMETER WorkflowDirectory
        Workflow directory to scan.
        .OUTPUTS
        [hashtable[]] Workflow, job, source, and referenced matrix keys.
        #>
        [CmdletBinding()]
        [OutputType([hashtable[]])]
        param(
            [Parameter(Mandatory = $true)]
            [string]$WorkflowDirectory
        )

        $consumers = @()
        foreach ($workflow in Get-ChildItem -LiteralPath $WorkflowDirectory -File -Filter '*.yml' | Where-Object { $_.Name -notlike '*.lock.yml' }) {
            $document = Get-Content -LiteralPath $workflow.FullName -Raw | ConvertFrom-Yaml
            if ($document -isnot [System.Collections.IDictionary] -or -not $document.Contains('jobs')) { continue }
            foreach ($job in $document['jobs'].GetEnumerator()) {
                if ($job.Value -isnot [System.Collections.IDictionary] -or -not $job.Value.Contains('strategy')) { continue }
                $strategy = $job.Value['strategy']
                if ($strategy -isnot [System.Collections.IDictionary] -or -not $strategy.Contains('matrix')) { continue }
                $source = $strategy['matrix']
                if ($source -isnot [string] -or $source -notmatch 'fromJson\(') { continue }
                if ($source -notmatch 'packages-matrix|discover-packages\.outputs\.matrix') { continue }

                $serialized = $job.Value | ConvertTo-Json -Depth 25
                $keys = @([regex]::Matches($serialized, 'matrix\.([A-Za-z0-9_-]+)') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
                $consumers += @{
                    Workflow = $workflow.Name
                    Job      = [string]$job.Key
                    Source   = $source
                    Keys     = $keys
                }
            }
        }
        return [hashtable[]]$consumers
    }
}

Describe 'Get-MarketplacePackageMatrixCore' -Tag 'Unit' {
    BeforeAll {
        $script:Fixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive 'matrix-repo')
        $script:FixtureStable = Get-MarketplacePackageMatrixCore -Channel Stable -CatalogPath $script:Fixture.CatalogPath
        $script:FixturePreRelease = Get-MarketplacePackageMatrixCore -Channel PreRelease -CatalogPath $script:Fixture.CatalogPath
    }

    Context 'when selecting eligible packages' {
        It 'Emits Stable rows that include experimental packages' {
            @($script:FixtureStable.Names) | Should -Be @('hve-core', 'hve-core-all', 'labs', 'sample')
        }

        It 'Emits the same rows on both channels' {
            @($script:FixturePreRelease.Names) | Should -Be @($script:FixtureStable.Names)
        }

        It 'Emits a non-empty matrix for both channels' {
            @($script:FixtureStable.MatrixItems).Count | Should -BeGreaterThan 0
            @($script:FixturePreRelease.MatrixItems).Count | Should -BeGreaterThan 0
        }

        It 'Reports every skipped package with its maturity reason' {
            @($script:FixtureStable.Skipped | ForEach-Object { "$($_.Id)=$($_.Reason)" }) |
                Should -Be @('retired=maturity: removed')
            @($script:FixturePreRelease.Skipped | ForEach-Object { "$($_.Id)=$($_.Reason)" }) |
                Should -Be @('retired=maturity: removed')
        }
    }

    Context 'when shaping matrix rows' {
        It 'Emits ID-only rows' {
            foreach ($row in $script:FixturePreRelease.MatrixItems) {
                @($row.Keys) | Should -Be @('id')
            }
        }

        It 'Serializes a compact include array in sorted order' {
            $script:FixtureStable.MatrixJson |
                Should -BeExactly '{"include":[{"id":"hve-core"},{"id":"hve-core-all"},{"id":"labs"},{"id":"sample"}]}'
        }

        It 'Serializes names as a JSON array' {
            $script:FixtureStable.NamesJson | Should -BeExactly '["hve-core","hve-core-all","labs","sample"]'
        }
    }

    Context 'when the catalog yields no publishable packages' {
        It 'Throws the no-publishable-packages message' {
            $catalog = Get-ExtensionCatalogFixture
            foreach ($entry in $catalog.plugins) { $entry['x-hve']['maturity'] = 'removed' }
            $emptyCatalogPath = Join-Path $TestDrive 'empty-catalog.json'
            Set-FixtureFile -Path $emptyCatalogPath -Value (($catalog | ConvertTo-Json -Depth 12) + "`n")
            { Get-MarketplacePackageMatrixCore -Channel Stable -CatalogPath $emptyCatalogPath } |
                Should -Throw "No publishable packages found in $emptyCatalogPath"
        }
    }

    Context 'when the catalog declares duplicate package names' {
        It 'Throws the duplicate-names message' {
            $catalog = Get-ExtensionCatalogFixture
            $duplicate = [ordered]@{
                name        = 'sample'
                description = 'Duplicate fixture package'
                version     = '9.9.9'
                'x-hve'     = [ordered]@{ displayName = 'Duplicate'; maturity = 'stable' }
            }
            $catalog.plugins = @($catalog.plugins) + @($duplicate)
            $duplicateCatalogPath = Join-Path $TestDrive 'duplicate-catalog.json'
            Set-FixtureFile -Path $duplicateCatalogPath -Value (($catalog | ConvertTo-Json -Depth 12) + "`n")
            { Get-MarketplacePackageMatrixCore -Channel Stable -CatalogPath $duplicateCatalogPath } |
                Should -Throw "Duplicate package names in $duplicateCatalogPath"
        }
    }
}

Describe 'Get-MarketplacePackageMatrix repository catalog' -Tag 'Unit' {
    It 'Matches independently derived <Channel> eligibility' -ForEach @(
        @{ Channel = 'Stable' }
        @{ Channel = 'PreRelease' }
    ) {
        $expected = Get-CatalogEligibleName -CatalogPath $script:RepositoryCatalogPath -Channel $Channel
        @($expected).Count | Should -BeGreaterThan 0
        $actual = Get-MarketplacePackageMatrixCore -Channel $Channel -CatalogPath $script:RepositoryCatalogPath
        @($actual.Names) | Should -Be @($expected)
    }

    It 'Selects the same packages on both channels' {
        $stable = @((Get-MarketplacePackageMatrixCore -Channel Stable -CatalogPath $script:RepositoryCatalogPath).Names)
        $preRelease = @((Get-MarketplacePackageMatrixCore -Channel PreRelease -CatalogPath $script:RepositoryCatalogPath).Names)
        $stable | Should -Be $preRelease
    }

    It 'Emits one matrix row per active catalog entry on <Channel>' -ForEach @(
        @{ Channel = 'Stable' }
        @{ Channel = 'PreRelease' }
    ) {
        $expected = @(Get-CatalogEligibleName -CatalogPath $script:RepositoryCatalogPath -Channel $Channel)
        $result = Get-MarketplacePackageMatrixCore -Channel $Channel -CatalogPath $script:RepositoryCatalogPath
        @($result.Names) | Should -Be $expected
        @($result.MatrixItems | ForEach-Object { $_.id }) | Should -Be $expected
        $result.NamesJson | Should -BeExactly (ConvertTo-Json -InputObject $expected -Compress)
        $expectedMatrix = [ordered]@{ include = @($expected | ForEach-Object { [ordered]@{ id = $_ } }) }
        $result.MatrixJson | Should -BeExactly (ConvertTo-Json -InputObject $expectedMatrix -Depth 4 -Compress)
    }
}

Describe 'Get-MarketplacePackageMatrix command line' -Tag 'Unit' {
    BeforeAll {
        $script:CliFixture = New-ExtensionFixtureRepo -Path (Join-Path $TestDrive 'matrix-cli-repo')
        $script:CliOutputPath = Join-Path $TestDrive 'github-output.txt'
        Set-FixtureFile -Path $script:CliOutputPath -Value ''
        $savedActions = $env:GITHUB_ACTIONS
        $savedOutput = $env:GITHUB_OUTPUT
        try {
            $env:GITHUB_ACTIONS = 'true'
            $env:GITHUB_OUTPUT = $script:CliOutputPath
            $script:CliMessages = @(& $script:MatrixScriptPath -Channel Stable -CatalogPath $script:CliFixture.CatalogPath *>&1 |
                    ForEach-Object { $_.ToString() })
        }
        finally {
            $env:GITHUB_ACTIONS = $savedActions
            $env:GITHUB_OUTPUT = $savedOutput
        }
        $script:CliOutputLines = @(Get-Content -LiteralPath $script:CliOutputPath)
    }

    It 'Writes a notice annotation for every skipped package' {
        $script:CliMessages | Should -Contain '::notice::Skipping retired: maturity: removed'
    }

    It 'Writes no notice annotation for eligible packages' {
        @($script:CliMessages | Where-Object { $_ -like '::notice::Skipping hve-core*' }) | Should -HaveCount 0
        @($script:CliMessages | Where-Object { $_ -like '::notice::Skipping labs*' }) | Should -HaveCount 0
    }

    It 'Publishes the matrix output' {
        $script:CliOutputLines | Should -Contain 'matrix={"include":[{"id":"hve-core"},{"id":"hve-core-all"},{"id":"labs"},{"id":"sample"}]}'
    }

    It 'Publishes the names output for plugin discovery parity' {
        $script:CliOutputLines | Should -Contain 'names=["hve-core","hve-core-all","labs","sample"]'
    }
}

Describe 'Package matrix workflow consumers' -Tag 'Unit' {
    BeforeAll {
        $script:Consumers = @(Get-PackageMatrixConsumer -WorkflowDirectory $script:WorkflowDirectory)
        $script:EmittedKeys = @((Get-MarketplacePackageMatrixCore -Channel PreRelease -CatalogPath $script:RepositoryCatalogPath).MatrixItems[0].Keys)
    }

    # The reusable publisher's `verify` job is the direct `inputs.packages-matrix`
    # consumer; `publish` fans out over the verification-derived
    # `needs.collect.outputs.verified-matrix`, which is not a caller input.
    It 'Finds every workflow job that consumes a discovered package matrix' {
        @($script:Consumers).Count | Should -BeGreaterThan 0
        @($script:Consumers | ForEach-Object { "$($_.Workflow)/$($_.Job)" } | Sort-Object) | Should -Be @(
            'extension-marketplace-publish.yml/verify'
            'extension-package.yml/package'
            'extension-provenance.yml/attest'
            'plugin-package.yml/package'
            'release-prerelease.yml/upload-plugin-packages'
            'release-stable-publish.yml/upload-plugin-packages'
        )
    }

    It 'Emits exactly the id key' {
        @($script:EmittedKeys) | Should -Be @('id')
    }

    It 'References only emitted matrix keys in <Workflow>/<Job>' -ForEach @(
        @{ Workflow = 'extension-marketplace-publish.yml'; Job = 'verify' }
        @{ Workflow = 'extension-package.yml'; Job = 'package' }
        @{ Workflow = 'extension-provenance.yml'; Job = 'attest' }
        @{ Workflow = 'plugin-package.yml'; Job = 'package' }
        @{ Workflow = 'release-prerelease.yml'; Job = 'upload-plugin-packages' }
        @{ Workflow = 'release-stable-publish.yml'; Job = 'upload-plugin-packages' }
    ) {
        $consumer = @($script:Consumers | Where-Object { $_.Workflow -eq $Workflow -and $_.Job -eq $Job })
        $consumer | Should -HaveCount 1
        @($consumer[0].Keys).Count | Should -BeGreaterThan 0
        foreach ($key in $consumer[0].Keys) {
            $script:EmittedKeys | Should -Contain $key -Because "$Workflow job '$Job' reads matrix.$key, which the package matrix must emit"
        }
    }
}

AfterAll {
    Remove-Module ExtensionTestFixtures -Force -ErrorAction SilentlyContinue
}
