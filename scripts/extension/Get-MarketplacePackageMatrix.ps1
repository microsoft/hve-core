#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Builds an extension package matrix from marketplace.json.
.DESCRIPTION
    Selects channel-eligible marketplace packages and emits sorted ID-only
    GitHub Actions matrix rows plus the matching package name list. This is the
    single package-discovery source for the extension and plugin lanes.
.PARAMETER Channel
    Stable or PreRelease channel.
.PARAMETER CatalogPath
    Marketplace catalog path.
.EXAMPLE
    ./Get-MarketplacePackageMatrix.ps1 -Channel Stable
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'Stable',

    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = (Join-Path $PSScriptRoot '../../.github/plugin/marketplace.json')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/MarketplaceHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

function Get-MarketplacePackageMatrixCore {
    <#
    .SYNOPSIS
    Returns a sorted ID-only matrix for eligible marketplace packages.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .PARAMETER CatalogPath
    Marketplace catalog path.
    .OUTPUTS
    [pscustomobject] Matrix JSON, items, names, and skipped packages.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [string]$CatalogPath
    )

    $catalog = Get-MarketplaceCatalog -Path $CatalogPath
    $matrixItems = @()
    $skipped = @()
    foreach ($entry in @($catalog['plugins']) | Sort-Object { $_['name'] }) {
        if (Test-MarketplaceEntryEligible -Entry $entry -Channel $Channel) {
            $matrixItems += @{ id = [string]$entry['name'] }
        }
        else {
            $skipped += @{
                Id = [string]$entry['name']
                Reason = "maturity: $(Get-MarketplaceEntryMaturity -Entry $entry)"
            }
        }
    }

    $names = [string[]]@($matrixItems | ForEach-Object { $_.id })
    if ($names.Count -eq 0) {
        throw "No publishable packages found in $CatalogPath"
    }
    if (@($names | Sort-Object -Unique).Count -ne $names.Count) {
        throw "Duplicate package names in $CatalogPath"
    }

    return [pscustomobject]@{
        MatrixJson = @{ include = $matrixItems } | ConvertTo-Json -Depth 4 -Compress
        MatrixItems = $matrixItems
        Names = $names
        NamesJson = $names | ConvertTo-Json -Compress -AsArray
        Skipped = $skipped
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $result = Get-MarketplacePackageMatrixCore -Channel $Channel -CatalogPath $CatalogPath
    foreach ($skip in $result.Skipped) {
        Write-CIAnnotation -Message "Skipping $($skip.Id): $($skip.Reason)" -Level Notice
    }
    Set-CIOutput -Name matrix -Value $result.MatrixJson
    Set-CIOutput -Name names -Value $result.NamesJson
    Write-Host "Discovered $($result.Names.Count) $Channel packages: $($result.Names -join ', ')"
}
