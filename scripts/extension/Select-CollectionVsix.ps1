#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#!
.SYNOPSIS
    Selects the unique VSIX asset matching a collection ID from a directory.

.DESCRIPTION
    Scans the supplied directory for .vsix files, filters for those whose name
    contains the requested collection ID, and throws unless exactly one match is
    found.

.PARAMETER AssetDirectory
    Directory containing downloaded VSIX assets.

.PARAMETER CollectionId
    Collection identifier that should appear in the selected VSIX filename.

.EXAMPLE
    ./Select-CollectionVsix.ps1 -AssetDirectory ./dist -CollectionId foo
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AssetDirectory = $env:ASSET_DIRECTORY,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$CollectionId = $env:COLLECTION_ID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Select-CollectionVsix {
    <#
    .SYNOPSIS
        Resolves the single VSIX asset for a collection.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('DirectoryPath')]
        [string]$AssetDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('RequestedCollectionId')]
        [string]$CollectionId
    )

    if (-not (Test-Path -Path $AssetDirectory -PathType Container)) {
        throw "Asset directory not found: $AssetDirectory"
    }

    $matchingFiles = @(
        Get-ChildItem -Path $AssetDirectory -Filter '*.vsix' -File | Where-Object {
            $_.Name -like "*$CollectionId*"
        }
    )

    if ($matchingFiles.Count -eq 0) {
        throw "No VSIX assets matched collection $CollectionId in $AssetDirectory"
    }

    if ($matchingFiles.Count -gt 1) {
        throw "Multiple VSIX assets matched collection ${CollectionId}: $($matchingFiles.Name -join ', ')"
    }

    return [System.IO.Path]::GetFullPath($matchingFiles[0].FullName)
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $selectedPath = Select-CollectionVsix -AssetDirectory $AssetDirectory -CollectionId $CollectionId
        Write-Output $selectedPath
    }
    catch {
        Write-Error -ErrorAction Continue "Select-CollectionVsix failed: $($_.Exception.Message)"
        exit 1
    }
}
