#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Refreshes the model catalog by fetching current models from GitHub docs data.

.DESCRIPTION
    Fetches structured YAML data files from the github/docs repository that define
    Copilot model names, release status, and multipliers. Merges these into the
    local model-catalog.json. Reports additions, removals, and multiplier changes.

.PARAMETER CatalogPath
    Path to the model catalog JSON file to update.

.PARAMETER DryRun
    When specified, reports changes without modifying the catalog file.

.PARAMETER BaseUrl
    Base URL for raw YAML data files in the github/docs repository.

.EXAMPLE
    ./Update-ModelCatalog.ps1

.EXAMPLE
    ./Update-ModelCatalog.ps1 -DryRun

.NOTES
    Data files are structured YAML from github/docs and are more stable than
    rendered page scraping. If the file paths change, update BaseUrl or the
    file names in the script.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = 'scripts/linting/model-catalog.json',

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [string]$BaseUrl = 'https://raw.githubusercontent.com/github/docs/main/data/tables/copilot'
)

$ErrorActionPreference = 'Stop'

Import-Module PowerShell-Yaml -ErrorAction Stop

#region Functions

function Get-RemoteYaml {
    <#
    .SYNOPSIS
    Fetches and parses a remote YAML file.

    .PARAMETER Url
    URL to fetch.

    .OUTPUTS
    Parsed YAML content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    $response = Invoke-WebRequest -Uri $Url -UseBasicParsing -ErrorAction Stop
    return ConvertFrom-Yaml -Yaml $response.Content -AllDocuments
}

function Merge-ModelData {
    <#
    .SYNOPSIS
    Merges model release status and multiplier data into catalog entries.

    .PARAMETER ReleaseStatus
    Array of model release status objects from model-release-status.yml.

    .PARAMETER Multipliers
    Array of model multiplier objects from model-multipliers.yml.

    .OUTPUTS
    [hashtable[]] Array of merged model catalog entries.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ReleaseStatus,

        [Parameter(Mandatory = $true)]
        [object[]]$Multipliers
    )

    $multiplierLookup = @{}
    foreach ($m in $Multipliers) {
        $multiplierLookup[$m.name] = $m
    }

    $models = @()
    foreach ($model in $ReleaseStatus) {
        $name = $model.name
        $status = if ($model.release_status -eq 'GA') { 'ga' } else { 'preview' }

        # Look up multiplier (use paid multiplier as canonical)
        $multiplier = 1.0
        if ($multiplierLookup.ContainsKey($name)) {
            $mData = $multiplierLookup[$name]
            $paidVal = $mData.multiplier_paid
            if ($paidVal -is [string] -and $paidVal -eq 'Not applicable') {
                $multiplier = 0
            }
            elseif ($null -ne $paidVal) {
                $multiplier = [double]$paidVal
            }
        }

        # Determine tier from multiplier
        $tier = if ($multiplier -eq 0) { 'free' }
        elseif ($multiplier -le 0.33) { 'fast' }
        elseif ($multiplier -le 1) { 'standard' }
        elseif ($multiplier -le 5) { 'premium' }
        else { 'ultra' }

        $models += @{
            name       = "$name (copilot)"
            tier       = $tier
            multiplier = $multiplier
            status     = $status
        }
    }

    return $models
}

function Compare-Catalogs {
    <#
    .SYNOPSIS
    Compares current catalog models against newly discovered models.

    .PARAMETER Current
    Array of current catalog model objects.

    .PARAMETER Discovered
    Array of newly discovered model objects.

    .OUTPUTS
    [hashtable] With added, removed, and changed arrays.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$Current,

        [Parameter(Mandatory = $true)]
        [object[]]$Discovered
    )

    $currentNames = @($Current | ForEach-Object { $_.name })
    $discoveredNames = @($Discovered | ForEach-Object { $_.name })

    $added = @($Discovered | Where-Object { $_.name -notin $currentNames })
    $removed = @($Current | Where-Object { $_.name -notin $discoveredNames })

    $changed = @()
    foreach ($disc in $Discovered) {
        $curr = $Current | Where-Object { $_.name -eq $disc.name }
        if ($curr -and $curr.multiplier -ne $disc.multiplier) {
            $changed += @{
                name          = $disc.name
                oldMultiplier = $curr.multiplier
                newMultiplier = $disc.multiplier
            }
        }
    }

    return @{
        added   = $added
        removed = $removed
        changed = $changed
    }
}

#endregion Functions

#region Orchestration

function Invoke-ModelCatalogUpdate {
    <#
    .SYNOPSIS
    Orchestrates catalog update from fetched model data.

    .PARAMETER ReleaseStatus
    Array of model release status objects.

    .PARAMETER Multipliers
    Array of model multiplier objects.

    .PARAMETER CatalogPath
    Path to the catalog JSON file.

    .PARAMETER DryRun
    When true, reports changes without writing to disk.

    .OUTPUTS
    [hashtable] With status ('unchanged', 'updated', 'created', 'dryrun'), diff, and finalModels.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [object[]]$ReleaseStatus,

        [Parameter(Mandatory = $true)]
        [object[]]$Multipliers,

        [Parameter(Mandatory = $true)]
        [string]$CatalogPath,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $discoveredModels = Merge-ModelData -ReleaseStatus $ReleaseStatus -Multipliers $Multipliers
    Write-Host "  Discovered $($discoveredModels.Count) models from docs" -ForegroundColor Green

    $diff = $null
    $finalModels = $null

    # Load current catalog if it exists
    if (Test-Path -Path $CatalogPath) {
        $currentCatalog = Get-Content -Path $CatalogPath -Raw | ConvertFrom-Json
        $currentModels = @($currentCatalog.models)

        $diff = Compare-Catalogs -Current $currentModels -Discovered $discoveredModels

        if ($diff.added.Count -gt 0) {
            Write-Host "`n  Added models:" -ForegroundColor Green
            foreach ($m in $diff.added) { Write-Host "    + $($m['name']) (tier: $($m['tier']), multiplier: $($m['multiplier']))" -ForegroundColor Green }
        }
        if ($diff.removed.Count -gt 0) {
            Write-Host "`n  Removed models (marking as retiring):" -ForegroundColor Yellow
            foreach ($m in $diff.removed) { Write-Host "    - $($m.name)" -ForegroundColor Yellow }
        }
        if ($diff.changed.Count -gt 0) {
            Write-Host "`n  Multiplier changes:" -ForegroundColor Cyan
            foreach ($c in $diff.changed) { Write-Host "    ~ $($c.name): $($c.oldMultiplier) -> $($c.newMultiplier)" -ForegroundColor Cyan }
        }

        if ($diff.added.Count -eq 0 -and $diff.removed.Count -eq 0 -and $diff.changed.Count -eq 0) {
            Write-Host "`n  No changes detected. Catalog is current." -ForegroundColor Green
            if (-not $DryRun) {
                $currentCatalog.lastUpdated = (Get-Date -Format 'yyyy-MM-dd')
                $currentCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $CatalogPath -Encoding utf8
            }
            return @{ status = 'unchanged'; diff = $diff; finalModels = $currentModels }
        }

        # Mark removed models as retiring instead of deleting
        $finalModels = @()
        foreach ($curr in $currentModels) {
            if ($curr.name -in @($diff.removed | ForEach-Object { $_.name })) {
                $retiring = [PSCustomObject]@{
                    name        = $curr.name
                    tier        = $curr.tier
                    multiplier  = $curr.multiplier
                    status      = 'retiring'
                    retiredDate = (Get-Date).AddDays(60).ToString('yyyy-MM-dd')
                }
                $finalModels += $retiring
            }
            else {
                # Update multiplier if changed
                $change = $diff.changed | Where-Object { $_.name -eq $curr.name }
                if ($change) {
                    $curr.multiplier = $change.newMultiplier
                }
                $finalModels += $curr
            }
        }
        # Add new models
        $finalModels += $diff.added
    }
    else {
        Write-Host "  No existing catalog found. Creating new catalog." -ForegroundColor Yellow
        $finalModels = $discoveredModels
    }

    if ($DryRun) {
        Write-Host "`n  [DRY RUN] No changes written to disk." -ForegroundColor Yellow
        return @{ status = 'dryrun'; diff = $diff; finalModels = $finalModels }
    }

    # Write updated catalog
    $newCatalog = @{
        '$schema'   = './schemas/model-catalog.schema.json'
        lastUpdated = (Get-Date -Format 'yyyy-MM-dd')
        source      = 'https://docs.github.com/en/copilot/reference/ai-models/supported-models'
        models      = $finalModels
    }

    $outputDir = Split-Path -Path $CatalogPath -Parent
    if ($outputDir -and -not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $newCatalog | ConvertTo-Json -Depth 5 | Set-Content -Path $CatalogPath -Encoding utf8
    Write-Host "`n  Catalog updated: $CatalogPath" -ForegroundColor Green
    Write-Host "  Total models: $($finalModels.Count)" -ForegroundColor Green

    $resultStatus = if ($null -eq $diff) { 'created' } else { 'updated' }
    return @{ status = $resultStatus; diff = $diff; finalModels = $finalModels }
}

#endregion Orchestration

#region Main

# Only run main logic when executed directly
if ($MyInvocation.InvocationName -ne '.') {
    Write-Host "Fetching model data from github/docs YAML sources..." -ForegroundColor Cyan

    try {
        $releaseStatusUrl = "$BaseUrl/model-release-status.yml"
        $multipliersUrl = "$BaseUrl/model-multipliers.yml"

        Write-Host "  Fetching: $releaseStatusUrl"
        $releaseStatus = Get-RemoteYaml -Url $releaseStatusUrl

        Write-Host "  Fetching: $multipliersUrl"
        $multipliers = Get-RemoteYaml -Url $multipliersUrl
    }
    catch {
        Write-Warning "Failed to fetch source data: $_"
        Write-Warning "Model catalog not updated. Check network or source URLs."
        exit 1
    }

    if (-not $releaseStatus -or $releaseStatus.Count -eq 0) {
        Write-Warning "No models found in release status data. Source format may have changed."
        exit 1
    }

    $updateParams = @{
        ReleaseStatus = $releaseStatus
        Multipliers   = $multipliers
        CatalogPath   = $CatalogPath
    }
    if ($DryRun) { $updateParams['DryRun'] = $true }

    $result = Invoke-ModelCatalogUpdate @updateParams
    if ($result.status -eq 'unchanged' -or $result.status -eq 'dryrun') {
        exit 0
    }
    exit 0
}

#endregion Main
