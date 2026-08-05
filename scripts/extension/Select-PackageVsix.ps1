#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#!
.SYNOPSIS
    Selects the unique VSIX asset matching a package ID from a directory.

.DESCRIPTION
    Resolves the package ID to its VS Code extension identity, scans the
    supplied directory for .vsix files whose name matches that identity plus a
    version segment, and throws unless exactly one match is found.

.PARAMETER AssetDirectory
    Directory containing downloaded VSIX assets.

.PARAMETER PackageId
    Marketplace package identifier whose extension VSIX is selected.

.EXAMPLE
    ./Select-PackageVsix.ps1 -AssetDirectory ./dist -PackageId foo
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$AssetDirectory = $env:ASSET_DIRECTORY,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageId = $env:PACKAGE_ID
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/ExtensionIdentity.psm1') -Force

function Select-PackageVsix {
    <#
    .SYNOPSIS
        Resolves the single VSIX asset for a package.
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
        [string]$PackageId
    )

    if (-not (Test-Path -Path $AssetDirectory -PathType Container)) {
        throw "Asset directory not found: $AssetDirectory"
    }

    $identity = Get-ExtensionIdentity -PackageId $PackageId
    $pattern = Get-ExtensionVsixPattern -ExtensionIdentity $identity
    $matchingFiles = @(
        Get-ChildItem -Path $AssetDirectory -Filter '*.vsix' -File | Where-Object {
            $_.Name -match $pattern
        }
    )

    if ($matchingFiles.Count -eq 0) {
        throw "No VSIX assets matched extension ${identity} for package ${PackageId} in ${AssetDirectory}"
    }

    if ($matchingFiles.Count -gt 1) {
        throw "Multiple VSIX assets matched extension ${identity} for package ${PackageId}: $($matchingFiles.Name -join ', ')"
    }

    return [System.IO.Path]::GetFullPath($matchingFiles[0].FullName)
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $selectedPath = Select-PackageVsix -AssetDirectory $AssetDirectory -PackageId $PackageId
        Write-Output $selectedPath
    }
    catch {
        Write-Error -ErrorAction Continue "Select-PackageVsix failed: $($_.Exception.Message)"
        exit 1
    }
}
