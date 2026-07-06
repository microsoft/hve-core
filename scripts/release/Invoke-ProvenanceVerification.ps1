#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Verifies release artifact provenance using the same semantics as the release workflow.

.DESCRIPTION
    Scans a directory of downloaded release artifacts and runs gh attestation verify
    with the correct signer workflow and predicate arguments for VSIX, plugin zip,
    and VEX files.

.PARAMETER ArtifactDirectory
    Directory containing downloaded release artifacts.

.PARAMETER Repository
    GitHub repository in owner/name format.

.EXAMPLE
    ./Invoke-ProvenanceVerification.ps1 -ArtifactDirectory ./artifacts -Repository microsoft/hve-core
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ArtifactDirectory = $env:ARTIFACT_DIRECTORY,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Repository = $env:REPOSITORY
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-ExternalCommand {
    <#
    .SYNOPSIS
        Runs an external command and throws on non-zero exit code.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $Command @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $Command $($Arguments -join ' ')"
    }
}

function Invoke-ProvenanceVerification {
    <#
    .SYNOPSIS
        Verifies provenance for downloaded release artifacts.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ArtifactDirectory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Repository
    )

    if (-not (Test-Path -Path $ArtifactDirectory -PathType Container)) {
        throw "Artifact directory not found: $ArtifactDirectory"
    }

    $artifacts = @(Get-ChildItem -Path $ArtifactDirectory -File | Sort-Object Name)
    if ($artifacts.Count -eq 0) {
        throw "No release artifacts found in $ArtifactDirectory"
    }

    foreach ($artifact in $artifacts) {
        $fullPath = [System.IO.Path]::GetFullPath($artifact.FullName)
        if ($artifact.Name -like '*.vsix') {
            Invoke-ExternalCommand -Command 'gh' -Arguments @('attestation', 'verify', $fullPath, '--repo', $Repository, '--signer-workflow', "$Repository/.github/workflows/extension-provenance.yml")
        }
        elseif ($artifact.Name -like '*.zip') {
            Invoke-ExternalCommand -Command 'gh' -Arguments @('attestation', 'verify', $fullPath, '--repo', $Repository)
        }
        elseif ($artifact.Name -eq 'hve-core.openvex.json') {
            Invoke-ExternalCommand -Command 'gh' -Arguments @('attestation', 'verify', $fullPath, '--repo', $Repository, '--signer-workflow', "$Repository/.github/workflows/vex-attest.yml", '--predicate-type', 'https://openvex.dev/ns/v0.2.0')
        }
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Invoke-ProvenanceVerification -ArtifactDirectory $ArtifactDirectory -Repository $Repository
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-ProvenanceVerification failed: $($_.Exception.Message)"
        exit 1
    }
}
