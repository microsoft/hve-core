#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Find-CollectionManifests.ps1
#
# Purpose: Discover and filter collection manifests for extension packaging matrix
# Author: HVE Core Team

#Requires -Version 7.0
#Requires -Modules PowerShell-Yaml

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

#region Functions

function Find-CollectionManifestsCore {
    <#
    .SYNOPSIS
        Discovers collection manifest files and builds a GitHub Actions matrix.
    .DESCRIPTION
        Reads *.collection.yml files from the specified directory, parses each with
        ConvertFrom-Yaml, and filters by maturity against the release channel.
        Deprecated collections are always excluded; experimental collections are
        excluded for the Stable channel.
    .PARAMETER Channel
        Release channel controlling maturity filtering (default: Stable).
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

    $collectionFiles = Get-ChildItem -Path $CollectionsDir -Filter '*.collection.yml' -File -ErrorAction SilentlyContinue | Sort-Object Name
    if (-not $collectionFiles -or $collectionFiles.Count -eq 0) {
        Write-Warning "No collection manifest files found in $CollectionsDir"
        return [PSCustomObject]@{
            MatrixJson  = '{"include":[]}'
            MatrixItems = @()
            Skipped     = @()
        }
    }

    $matrixItems = @()
    $skipped = @()

    foreach ($file in $collectionFiles) {
        $content = Get-Content -Path $file.FullName -Raw
        $manifest = ConvertFrom-Yaml -Yaml $content

        $id = [string]$manifest.id
        $name = if ($manifest.ContainsKey('name')) { [string]$manifest.name } else { $id }
        $maturity = if ($manifest.ContainsKey('maturity') -and $manifest.maturity) { [string]$manifest.maturity } else { 'stable' }

        # Always skip deprecated
        if ($maturity -eq 'deprecated') {
            $skipped += [PSCustomObject]@{ Id = $id; Name = $name; Reason = 'deprecated' }
            Write-Verbose "Skipping deprecated collection: $name ($id)"
            continue
        }

        # Skip experimental for Stable channel
        if ($maturity -eq 'experimental' -and $channel -eq 'Stable') {
            $skipped += [PSCustomObject]@{ Id = $id; Name = $name; Reason = 'experimental (Stable channel)' }
            Write-Verbose "Skipping experimental collection for Stable channel: $name ($id)"
            continue
        }

        $matrixItems += @{
            id       = $id
            name     = $name
            manifest = $file.FullName -replace '\\', '/'
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
