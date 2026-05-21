#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a SHA-256 manifest for planner artifacts (RAI or SSSC) and optionally signs it with cosign.

.DESCRIPTION
    Enumerates all files under a planner session directory, computes SHA-256 hashes for each
    artifact, and writes a JSON manifest file. Supports RAI sessions via -ProjectSlug (resolved
    to .copilot-tracking/rai-plans/{ProjectSlug}/) and arbitrary planner sessions via -SessionPath
    (an absolute or repo-relative directory, e.g., .copilot-tracking/sssc-plans/{slug}/). When
    cosign is available and requested, the manifest is signed using Sigstore keyless signing to
    provide cryptographic provenance.

.PARAMETER ProjectSlug
    The project slug identifying an RAI planning session. Corresponds to the subdirectory under
    .copilot-tracking/rai-plans/. Mutually exclusive with -SessionPath.

.PARAMETER SessionPath
    Direct path to a planner session directory (absolute, or relative to the repository root).
    Use this for SSSC sessions or any non-RAI planner. Mutually exclusive with -ProjectSlug.

.PARAMETER ManifestName
    File name for the generated manifest written inside the session directory. Defaults to
    'artifact-manifest.json'. Ignored when -OutputPath is supplied.

.PARAMETER OutputPath
    Full path for the generated manifest file. When omitted, the manifest is written inside the
    resolved session directory using -ManifestName.

.PARAMETER IncludeCosign
    When specified, attempts to sign the manifest with cosign keyless signing after
    generation. Requires cosign to be available in PATH. Gracefully skips signing with
    a warning when cosign is not found.

.EXAMPLE
    ./scripts/security/Sign-PlannerArtifacts.ps1 -ProjectSlug "contoso-ai"

    Generates a SHA-256 manifest for all artifacts under
    .copilot-tracking/rai-plans/contoso-ai/.

.EXAMPLE
    ./scripts/security/Sign-PlannerArtifacts.ps1 -ProjectSlug "contoso-ai" -IncludeCosign

    Generates the manifest and signs it with cosign keyless signing.

.EXAMPLE
    npm run rai:sign -- -ProjectSlug "contoso-ai" -IncludeCosign

    Invokes the script through the npm wrapper with cosign signing enabled.

.EXAMPLE
    ./scripts/security/Sign-PlannerArtifacts.ps1 -SessionPath '.copilot-tracking/sssc-plans/contoso-supply-chain' -ManifestName 'sssc-manifest.json'

    Generates a manifest named sssc-manifest.json for an SSSC planner session.

.NOTES
    The manifest excludes its own file and any cosign signature files (.sig, .bundle) from the
    hash inventory to avoid circular references.
#>

[CmdletBinding(DefaultParameterSetName = 'ByProjectSlug')]
param(
    [Parameter(Mandatory, ParameterSetName = 'ByProjectSlug')]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectSlug,

    [Parameter(Mandatory, ParameterSetName = 'BySessionPath')]
    [ValidateNotNullOrEmpty()]
    [string]$SessionPath,

    [Parameter(Mandatory = $false)]
    [string]$ManifestName = 'artifact-manifest.json',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$IncludeCosign
)

$ErrorActionPreference = 'Stop'

#region Helper Functions

function Get-ArtifactHash {
    <#
    .SYNOPSIS
        Computes the SHA-256 hash of a file and returns a lowercase hex string.
    .OUTPUTS
        [string] Lowercase hex SHA-256 digest.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    (Get-FileHash -Path $FilePath -Algorithm SHA256).Hash.ToLower()
}

#endregion Helper Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        #region Artifact Generation

        $repoRoot = & git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($repoRoot)) {
            $repoRoot = $PWD.Path
        }

        if ($PSCmdlet.ParameterSetName -eq 'BySessionPath') {
            if ([System.IO.Path]::IsPathRooted($SessionPath)) {
                $artifactDir = $SessionPath
            }
            else {
                $artifactDir = Join-Path -Path $repoRoot -ChildPath $SessionPath
            }
            $sessionLabel = Split-Path -Path $artifactDir -Leaf
        }
        else {
            $artifactDir = Join-Path -Path $repoRoot -ChildPath ".copilot-tracking/rai-plans/$ProjectSlug"
            $sessionLabel = $ProjectSlug
        }

        if (-not (Test-Path -Path $artifactDir -PathType Container)) {
            Write-Host "❌ Artifact directory not found: $artifactDir" -ForegroundColor Red
            exit 1
        }

        if (-not $OutputPath) {
            $OutputPath = Join-Path -Path $artifactDir -ChildPath $ManifestName
        }

        $manifestFileName = Split-Path -Path $OutputPath -Leaf

        # File patterns to exclude from the manifest to avoid circular references
        $excludePatterns = @(
            $manifestFileName,
            '*.sig',
            '*.bundle'
        )

        Write-Host "🔐 Generating artifact manifest for session: $sessionLabel" -ForegroundColor Cyan

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

        $repoRootBoundary = if ($repoRoot.EndsWith([IO.Path]::DirectorySeparatorChar)) { $repoRoot } else { $repoRoot + [IO.Path]::DirectorySeparatorChar }
        $manifest = [ordered]@{
            version     = '1.0'
            projectSlug = $sessionLabel
            sessionPath = if ($artifactDir.Equals($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                ''
            } elseif ($artifactDir.StartsWith($repoRootBoundary, [System.StringComparison]::OrdinalIgnoreCase)) {
                ($artifactDir.Substring($repoRootBoundary.Length) -replace '\\','/')
            } else {
                ($artifactDir -replace '\\','/')
            }
            generatedAt = [DateTime]::UtcNow.ToString("yyyy-MM-ddTHH:mm:ss.fffffffZ")
            algorithm   = 'SHA256'
            fileCount   = $fileEntries.Count
            artifacts   = $fileEntries.ToArray()
        }

        $manifestJson = $manifest | ConvertTo-Json -Depth 10
        Set-Content -Path $OutputPath -Value $manifestJson -Encoding utf8NoBOM

        Write-Host "📋 Manifest written to: $OutputPath" -ForegroundColor Green
        Write-Host "   Files hashed: $($fileEntries.Count)" -ForegroundColor Cyan

        #endregion Artifact Generation

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

        #endregion Cosign Signing

        Write-Host "🎉 Artifact signing complete" -ForegroundColor Green
    }
    catch {
        Write-Error "Sign-PlannerArtifacts failed: $($_.Exception.Message)" -ErrorAction Continue
        exit 1
    }
}
#endregion Main Execution
