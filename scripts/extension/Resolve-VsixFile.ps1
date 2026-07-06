#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Resolves the single VSIX file in a directory.

.DESCRIPTION
    Searches the supplied directory for .vsix files and throws unless exactly
    one file is present.

.PARAMETER DirectoryPath
    Directory to inspect for a single VSIX file.

.EXAMPLE
    ./Resolve-VsixFile.ps1 -DirectoryPath ./extension
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$DirectoryPath = $env:VSIX_DIRECTORY
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-VsixFile {
    <#
    .SYNOPSIS
        Returns the one VSIX file in a directory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('Path')]
        [string]$DirectoryPath
    )

    if (-not (Test-Path -Path $DirectoryPath -PathType Container)) {
        throw "Directory not found: $DirectoryPath"
    }

    $matchingFiles = @(Get-ChildItem -Path $DirectoryPath -Filter '*.vsix' -File)
    if ($matchingFiles.Count -eq 0) {
        throw "No VSIX file found in directory: $DirectoryPath"
    }

    if ($matchingFiles.Count -gt 1) {
        throw "Expected exactly one VSIX file but found $($matchingFiles.Count): $($matchingFiles.Name -join ', ')"
    }

    return [System.IO.Path]::GetFullPath($matchingFiles[0].FullName)
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $resolved = Resolve-VsixFile -DirectoryPath $DirectoryPath
        Write-Output $resolved
    }
    catch {
        Write-Error -ErrorAction Continue "Resolve-VsixFile failed: $($_.Exception.Message)"
        exit 1
    }
}
