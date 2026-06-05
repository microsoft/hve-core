#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Find-CollectionManifests.ps1
#
# Purpose: Discover and filter collection manifests for extension packaging matrix
# Author: HVE Core Team

#Requires -Version 7.0
#Requires -Modules @{ ModuleName='PowerShell-Yaml'; RequiredVersion='0.4.7' }

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Channel = 'Stable',

    [Parameter(Mandatory = $false)]
    [string]$CollectionsDir = (Join-Path $PSScriptRoot '../../collections')
)

$ErrorActionPreference = 'Stop'

# Import CI helpers for output writing
Import-Module (Join-Path $PSScriptRoot "../lib/Modules/CIHelpers.psm1") -Force
Import-Module (Join-Path $PSScriptRoot "../collections/Modules/CoreManifestHelpers.psm1") -Force

#region Functions

function Find-CollectionManifestsCore {
    <#
    .SYNOPSIS
        Discovers collection manifest files and builds a GitHub Actions matrix.
    .DESCRIPTION
        Reads collection metadata from core-manifest.yml in the specified directory,
        and filters out collections whose maturity is deprecated
        or removed. Per-item maturity gating (stable/preview/experimental) is
        enforced downstream by Prepare-Extension via Get-AllowedMaturities;
        collections themselves are not channel-gated as a whole.
    .PARAMETER Channel
        Release channel passed through for downstream consumers (default: Stable).
        No longer used to filter experimental collections at discovery time.
    .PARAMETER CollectionsDir
        Directory containing *.collection.yml manifest files.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Channel = 'Stable',

        [Parameter(Mandatory = $false)]
        [string]$CollectionsDir = 'collections'
    )

    $channel = $Channel.Trim()
    if (-not $channel) { $channel = 'Stable' }

    $coreManifestPath = Join-Path -Path $CollectionsDir -ChildPath 'core-manifest.yml'
    if (-not (Test-Path -Path $coreManifestPath -PathType Leaf)) {
        Write-Warning "No core manifest found in $CollectionsDir"
        return [PSCustomObject]@{
            MatrixJson  = '{"include":[]}'
            MatrixItems = @()
            Skipped     = @()
        }
    }

    $repoRoot = Split-Path -Path $CollectionsDir -Parent
    $coreManifest = Read-CoreManifest -ManifestPath $coreManifestPath
    $collections = @(ConvertTo-CollectionManifestFromCore -CoreManifest $coreManifest -All -RepoRoot $repoRoot | Sort-Object { $_.id })

    $matrixItems = @()
    $skipped = @()

    foreach ($manifest in $collections) {
        $id = [string]$manifest.id
        $name = if ($manifest.Contains('name') -and -not [string]::IsNullOrWhiteSpace([string]$manifest.name)) { [string]$manifest.name } else { $id }
        $maturity = if ($manifest.Contains('maturity') -and $manifest.maturity) { [string]$manifest.maturity } else { 'stable' }

        # Always skip removed
        if ($maturity -eq 'removed') {
            $skipped += [PSCustomObject]@{ Id = $id; Name = $name; Reason = 'removed' }
            Write-Verbose "Skipping removed collection: $name ($id)"
            continue
        }

        # Always skip deprecated
        if ($maturity -eq 'deprecated') {
            $skipped += [PSCustomObject]@{ Id = $id; Name = $name; Reason = 'deprecated' }
            Write-Verbose "Skipping deprecated collection: $name ($id)"
            continue
        }

        # Per-item maturity gating (stable/preview/experimental) is enforced by
        # Prepare-Extension via Get-AllowedMaturities; collections themselves are
        # not channel-gated as a whole.

        $matrixItems += @{
            id       = $id
            name     = $name
            manifest = (Join-Path -Path $CollectionsDir -ChildPath "$id.collection.yml") -replace '\\', '/'
            maturity = $maturity
        }
    }

    $matrixJson = @{ include = $matrixItems } | ConvertTo-Json -Depth 5 -Compress

    return [PSCustomObject]@{
        MatrixJson  = $matrixJson
        MatrixItems = $matrixItems
        Skipped     = $skipped
    }
}

#endregion

# Script guard: only execute CI output when run directly, not when dot-sourced
if ($MyInvocation.InvocationName -ne '.') {
    $result = Find-CollectionManifestsCore -Channel $Channel -CollectionsDir $CollectionsDir

    # Report skipped collections
    foreach ($skip in $result.Skipped) {
        Write-CIAnnotation -Message "Skipping $($skip.Name) ($($skip.Id)): $($skip.Reason)" -Level Notice
    }

    Write-Host "Discovered collections:"
    $result.MatrixJson | ConvertFrom-Json | ConvertTo-Json -Depth 5

    # Write CI output using injection-safe helpers
    Set-CIOutput -Name 'matrix' -Value $result.MatrixJson
}
