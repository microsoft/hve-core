#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Uploads Sigstore attestation bundles as release assets to improve OSSF Scorecard Signed-Releases score.

.DESCRIPTION
    Scorecard's releasesAreSigned probe checks for .sigstore.json files in release assets.
    This script downloads existing attestation bundles via the GitHub CLI and uploads them
    as named .sigstore.json assets alongside the original VSIX artifacts.

    Only non-draft releases with VSIX assets that have existing attestations are processed.
    Releases without attestations are skipped.

.PARAMETER Repository
    GitHub repository in owner/repo format (default: microsoft/hve-core)

.PARAMETER MaxReleases
    Maximum number of non-draft releases to process (default: 10)

.PARAMETER DryRun
    Show what would be done without making changes.

.EXAMPLE
    ./Add-SignedReleaseAssets.ps1 -DryRun
    Preview which releases and assets would be updated

.EXAMPLE
    ./Add-SignedReleaseAssets.ps1
    Upload .sigstore.json assets for all eligible non-draft releases
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [string]$Repository = 'microsoft/hve-core',
    [int]$MaxReleases = 10,
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

function Get-VsixAssetsNeedingSignature {
    <#
    .SYNOPSIS
        Returns VSIX asset names from a release that lack a corresponding .sigstore.json asset.
    #>
    param(
        [Parameter(Mandatory)]
        [object]$Release
    )

    $assetNames = @($Release.assets | ForEach-Object { $_.name })
    $vsixAssets = @($assetNames | Where-Object { $_ -like '*.vsix' })

    if ($vsixAssets.Count -eq 0) {
        return @()
    }

    $needed = @()
    foreach ($vsix in $vsixAssets) {
        $sigstoreName = "$vsix.sigstore.json"
        if ($sigstoreName -notin $assetNames) {
            $needed += $vsix
        }
    }
    return $needed
}

function Get-AttestationBundle {
    <#
    .SYNOPSIS
        Downloads the attestation bundle for an artifact and returns the bundle file path.
        Returns $null when no attestation is found.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$ArtifactPath,

        [Parameter(Mandatory)]
        [string]$Repository,

        [Parameter(Mandatory)]
        [string]$OutputDirectory
    )

    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
    gh attestation download $ArtifactPath -R $Repository -D $OutputDirectory 2>&1 | Out-Null
    $bundleFiles = Get-ChildItem -Path $OutputDirectory -Filter '*.jsonl' -ErrorAction SilentlyContinue

    if (-not $bundleFiles -or $bundleFiles.Count -eq 0) {
        return $null
    }
    return $bundleFiles[0].FullName
}

function Invoke-SignedReleaseAssetUpload {
    <#
    .SYNOPSIS
        Main orchestrator: fetches releases, downloads attestation bundles, and uploads .sigstore.json assets.
    #>
    param(
        [Parameter(Mandatory)]
        [string]$Repository,

        [int]$MaxReleases = 10,

        [switch]$DryRun
    )

    # Verify gh CLI is available and authenticated
    try {
        $null = gh auth status 2>&1
    } catch {
        Write-Error 'gh CLI is not authenticated. Run: gh auth login'
        return
    }

    Write-Host "Fetching non-draft releases from $Repository ..." -ForegroundColor Cyan
    $releaseJson = gh api "/repos/$Repository/releases?per_page=$MaxReleases" --jq '[.[] | select(.draft == false)]' 2>&1

    if (-not $releaseJson) {
        Write-Host 'No non-draft releases found.' -ForegroundColor Yellow
        return
    }

    $releases = $releaseJson | ConvertFrom-Json

    if (-not $releases -or $releases.Count -eq 0) {
        Write-Host 'No non-draft releases found.' -ForegroundColor Yellow
        return
    }

    Write-Host "Found $($releases.Count) non-draft release(s)" -ForegroundColor Cyan

    $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) "sigstore-upload-$([guid]::NewGuid().ToString('N').Substring(0,8))"
    New-Item -ItemType Directory -Path $tempDir -Force | Out-Null

    try {
        foreach ($release in $releases) {
            $tag = $release.tag_name
            $needed = Get-VsixAssetsNeedingSignature -Release $release

            if ($needed.Count -eq 0) {
                $hasVsix = @($release.assets | ForEach-Object { $_.name } | Where-Object { $_ -like '*.vsix' }).Count -gt 0
                if ($hasVsix) {
                    Write-Host "  [$tag] All VSIX assets already have .sigstore.json — skipping" -ForegroundColor DarkGray
                } else {
                    Write-Host "  [$tag] No VSIX assets — skipping" -ForegroundColor DarkGray
                }
                continue
            }

            Write-Host "  [$tag] Processing $($needed.Count) VSIX asset(s) ..." -ForegroundColor White

            foreach ($vsix in $needed) {
                $sigstoreName = "$vsix.sigstore.json"
                $downloadDir = Join-Path $tempDir $tag $vsix
                New-Item -ItemType Directory -Path $downloadDir -Force | Out-Null

                # Download the VSIX so gh can compute its digest for attestation lookup
                Write-Host "    $vsix — downloading VSIX ..." -ForegroundColor Gray
                $vsixPath = Join-Path $downloadDir $vsix
                gh release download $tag -R $Repository -p $vsix -D $downloadDir --clobber 2>&1 | Out-Null

                if (-not (Test-Path $vsixPath)) {
                    Write-Warning "    $vsix — VSIX download failed, skipping"
                    continue
                }

                # Download attestation bundle
                Write-Host "    $vsix — downloading attestation bundle ..." -ForegroundColor Gray
                $bundleDir = Join-Path $downloadDir 'bundles'
                $bundlePath = Get-AttestationBundle -ArtifactPath $vsixPath -Repository $Repository -OutputDirectory $bundleDir

                if (-not $bundlePath) {
                    Write-Host "    $vsix — no attestation found, skipping" -ForegroundColor Yellow
                    continue
                }

                $destPath = Join-Path $downloadDir $sigstoreName
                Copy-Item -Path $bundlePath -Destination $destPath

                if ($DryRun) {
                    Write-Host "    $vsix — [DRY RUN] would upload $sigstoreName" -ForegroundColor Magenta
                } else {
                    Write-Host "    $vsix — uploading $sigstoreName ..." -ForegroundColor Green
                    gh release upload $tag $destPath -R $Repository --clobber 2>&1 | Out-Null
                    Write-Host "    $vsix — uploaded $sigstoreName" -ForegroundColor Green
                }
            }
        }
    } finally {
        Remove-Item -Path $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    Write-Host "`nDone." -ForegroundColor Cyan
}

# Dot-source guard: skip main execution when dot-sourced for testing
if ($MyInvocation.InvocationName -ne '.') {
    Invoke-SignedReleaseAssetUpload -Repository $Repository -MaxReleases $MaxReleases -DryRun:$DryRun
}
