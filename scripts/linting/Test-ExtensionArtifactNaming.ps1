#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates consistency of extension VSIX artifact names across producer and consumer workflows.

.DESCRIPTION
    Reads the extension packaging workflow and marketplace publish workflow to
    ensure the upload-artifact producer name and download-artifact consumer names
    remain aligned.

.PARAMETER RepoRoot
    Repository root to scan.

.EXAMPLE
    ./Test-ExtensionArtifactNaming.ps1 -RepoRoot .
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Test-ExtensionArtifactNaming {
    <#
    .SYNOPSIS
        Confirms that producer and consumer extension artifact names are consistent.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [Alias('RepositoryRoot')]
        [string]$RepoRoot
    )

    $producerPath = Join-Path $RepoRoot '.github/workflows/extension-package.yml'
    $consumerPath = Join-Path $RepoRoot '.github/workflows/extension-marketplace-publish.yml'
    $issues = [System.Collections.Generic.List[string]]::new()

    if (-not (Test-Path -Path $producerPath -PathType Leaf)) {
        throw "Producer workflow not found: $producerPath"
    }

    if (-not (Test-Path -Path $consumerPath -PathType Leaf)) {
        throw "Consumer workflow not found: $consumerPath"
    }

    $producerContent = Get-Content -Path $producerPath -Raw
    $consumerContent = Get-Content -Path $consumerPath -Raw

    $producerNames = @([regex]::Matches($producerContent, 'name:\s*(extension-vsix-[^\r\n]+)') | ForEach-Object { $_.Groups[1].Value })
    $consumerNames = @([regex]::Matches($consumerContent, 'name:\s*(extension-vsix-[^\r\n]+)') | ForEach-Object { $_.Groups[1].Value })

    if ($producerNames.Count -eq 0) {
        $issues.Add('Producer workflow does not declare a matching extension-vsix artifact name.')
    }

    if ($consumerNames.Count -eq 0) {
        $issues.Add('Consumer workflow does not declare a matching extension-vsix artifact name.')
    }

    if ($producerNames.Count -gt 0 -and $consumerNames.Count -gt 0 -and $producerNames[0] -ne $consumerNames[0]) {
        $issues.Add('Producer and consumer artifact names differ: producer uses ' + $producerNames[0] + ' but consumer uses ' + $consumerNames[0])
    }

    return @{
        Passed = ($issues.Count -eq 0)
        Issues = $issues.ToArray()
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Test-ExtensionArtifactNaming -RepoRoot $RepoRoot
        if (-not $result.Passed) {
            foreach ($issue in $result.Issues) {
                Write-Error -ErrorAction Continue $issue
            }
            exit 1
        }

        Write-Host 'Extension artifact naming check passed.' -ForegroundColor Green
    }
    catch {
        Write-Error -ErrorAction Continue "Test-ExtensionArtifactNaming failed: $($_.Exception.Message)"
        exit 1
    }
}
