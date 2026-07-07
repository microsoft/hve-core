#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Exports attestation bundle data to the workflow's expected artifact files.

.DESCRIPTION
    Copies the attestation bundle to a .sigstore.json file and extracts the
    dsseEnvelope payload into a .intoto.jsonl file using PowerShell JSON parsing.

.PARAMETER BundlePath
    Path to the attestation bundle JSON file.

.PARAMETER SigstorePath
    Destination path for the copied bundle.

.PARAMETER IntotoPath
    Destination path for the extracted DSSE envelope.

.EXAMPLE
    ./Export-AttestationBundle.ps1 -BundlePath ./bundle.json -SigstorePath ./out.sigstore.json -IntotoPath ./out.intoto.jsonl
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BundlePath = $env:BUNDLE_PATH,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$SigstorePath = $env:SIGSTORE_PATH,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$IntotoPath = $env:INTOTO_PATH
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Export-AttestationBundle {
    <#
    .SYNOPSIS
        Copies and extracts attestation bundle content.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BundlePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SigstorePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$IntotoPath
    )

    if (-not (Test-Path -Path $BundlePath -PathType Leaf)) {
        throw "Bundle file not found: $BundlePath"
    }

    $sigstoreDirectory = Split-Path -Path $SigstorePath -Parent
    if ($sigstoreDirectory) {
        New-Item -Path $sigstoreDirectory -ItemType Directory -Force | Out-Null
    }

    $intotoDirectory = Split-Path -Path $IntotoPath -Parent
    if ($intotoDirectory) {
        New-Item -Path $intotoDirectory -ItemType Directory -Force | Out-Null
    }

    $bundle = Get-Content -Path $BundlePath -Raw | ConvertFrom-Json -Depth 20
    Copy-Item -Path $BundlePath -Destination $SigstorePath -Force

    $dsseEnvelope = $bundle.dsseEnvelope
    if ($null -eq $dsseEnvelope) {
        throw 'The attestation bundle does not contain a dsseEnvelope property.'
    }

    $json = $dsseEnvelope | ConvertTo-Json -Depth 20 -Compress
    Set-Content -Path $IntotoPath -Value $json -Encoding utf8NoBOM

    return [pscustomobject]@{
        SigstorePath = [System.IO.Path]::GetFullPath($SigstorePath)
        IntotoPath   = [System.IO.Path]::GetFullPath($IntotoPath)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Export-AttestationBundle -BundlePath $BundlePath -SigstorePath $SigstorePath -IntotoPath $IntotoPath
        Write-Output $result
    }
    catch {
        Write-Error -ErrorAction Continue "Export-AttestationBundle failed: $($_.Exception.Message)"
        exit 1
    }
}
