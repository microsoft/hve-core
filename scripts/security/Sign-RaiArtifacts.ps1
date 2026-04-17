#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a SHA-256 manifest for RAI planning artifacts and optionally signs it with cosign.

.DESCRIPTION
    Enumerates all files under the RAI planning artifact directory for a given project slug,
    computes SHA-256 hashes for each artifact, and writes a JSON manifest file. When cosign
    is available and requested, the manifest is signed using Sigstore keyless signing to
    provide cryptographic provenance.

.PARAMETER ProjectSlug
    The project slug identifying the RAI planning session. Corresponds to the subdirectory
    under .copilot-tracking/rai-plans/.

.PARAMETER OutputPath
    Path for the generated manifest file. Defaults to
    .copilot-tracking/rai-plans/{ProjectSlug}/artifact-manifest.json.

.PARAMETER IncludeCosign
    When specified, attempts to sign the manifest with cosign keyless signing after
    generation. Requires cosign to be available in PATH. Gracefully skips signing with
    a warning when cosign is not found.

.EXAMPLE
    ./scripts/security/Sign-RaiArtifacts.ps1 -ProjectSlug "contoso-ai"

    Generates a SHA-256 manifest for all artifacts under
    .copilot-tracking/rai-plans/contoso-ai/.

.EXAMPLE
    ./scripts/security/Sign-RaiArtifacts.ps1 -ProjectSlug "contoso-ai" -IncludeCosign

    Generates the manifest and signs it with cosign keyless signing.

.EXAMPLE
    npm run rai:sign -- -ProjectSlug "contoso-ai" -IncludeCosign

    Invokes the script through the npm wrapper with cosign signing enabled.

.NOTES
    The manifest excludes its own file (artifact-manifest.json) and any cosign signature
    files (.sig, .bundle) from the hash inventory to avoid circular references.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectSlug,

    [string]$OutputPath,

    [switch]$IncludeCosign
)

$ErrorActionPreference = 'Stop'

#region Helper Functions

function Get-ArtifactHash {
    <#
    .SYNOPSIS
        Computes the SHA-256 hash of a file and returns a lowercase hex string.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
}

#endregion

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {

$artifactDir = Join-Path -Path $PWD -ChildPath ".copilot-tracking/rai-plans/$ProjectSlug"

if (-not (Test-Path -Path $artifactDir -PathType Container)) {
    Write-Host "❌ Artifact directory not found: $artifactDir" -ForegroundColor Red
    exit 1
}

if (-not $OutputPath) {
    $OutputPath = Join-Path -Path $artifactDir -ChildPath 'artifact-manifest.json'
}

# File patterns to exclude from the manifest to avoid circular references
$excludePatterns = @(
    'artifact-manifest.json',
    '*.sig',
    '*.bundle'
)

Write-Host "🔐 Generating artifact manifest for project: $ProjectSlug" -ForegroundColor Cyan

$artifacts = Get-ChildItem -Path $artifactDir -File -Recurse |
    Where-Object {
        $fileName = $_.Name
        -not ($excludePatterns | Where-Object { $fileName -like $_ })
    } |
    Sort-Object FullName

if ($artifacts.Count -eq 0) {
    Write-Host "⚠️  No artifacts found in: $artifactDir" -ForegroundColor Yellow
    exit 0
}

Write-Host "📁 Found $($artifacts.Count) artifact(s) to hash" -ForegroundColor Cyan

$fileEntries = [System.Collections.Generic.List[object]]::new()

foreach ($file in $artifacts) {
    $relativePath = $file.FullName.Substring($artifactDir.Length + 1) -replace '\\', '/'
    $hash = Get-ArtifactHash -FilePath $file.FullName
    $fileEntries.Add(@{
        path      = $relativePath
        sha256    = $hash
        sizeBytes = $file.Length
    })
    Write-Host "  ✅ $relativePath" -ForegroundColor Green
}

$manifest = [ordered]@{
    version     = '1.0'
    projectSlug = $ProjectSlug
    generatedAt = (Get-Date -Format 'o')
    algorithm   = 'SHA256'
    fileCount   = $fileEntries.Count
    artifacts   = $fileEntries
}

$manifestJson = $manifest | ConvertTo-Json -Depth 4
Set-Content -Path $OutputPath -Value $manifestJson -Encoding utf8NoBOM

Write-Host "📋 Manifest written to: $OutputPath" -ForegroundColor Green
Write-Host "   Files hashed: $($fileEntries.Count)" -ForegroundColor Cyan

#endregion

#region Cosign Signing

if ($IncludeCosign) {
    $cosignCmd = Get-Command -Name 'cosign' -ErrorAction SilentlyContinue

    if (-not $cosignCmd) {
        Write-Host "⚠️  cosign not found in PATH. Skipping signature." -ForegroundColor Yellow
        Write-Host "   Install cosign from https://docs.sigstore.dev/cosign/system_config/installation/" -ForegroundColor Yellow
        exit 0
    }

    Write-Host "🔏 Signing manifest with cosign keyless signing..." -ForegroundColor Cyan

    try {
        & cosign sign-blob `
            --yes `
            --output-signature "$OutputPath.sig" `
            --bundle "$OutputPath.bundle" `
            $OutputPath

        Write-Host "✅ Manifest signed successfully" -ForegroundColor Green
        Write-Host "   Signature: $OutputPath.sig" -ForegroundColor Cyan
        Write-Host "   Bundle:    $OutputPath.bundle" -ForegroundColor Cyan
    }
    catch {
        Write-Host "❌ Cosign signing failed: $_" -ForegroundColor Red
        exit 2
    }
}

#endregion

Write-Host "🎉 Artifact signing complete" -ForegroundColor Green

}
#endregion Main Execution
