#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Generates a SHA-256 manifest for planner artifacts and optionally signs it with cosign.

.DESCRIPTION
    Enumerates all files under a planner artifact directory, computes SHA-256 hashes for
    each artifact, and writes a JSON manifest file. The artifact directory is resolved
    from -PlanRoot when supplied, otherwise from the legacy -ProjectSlug + -Scope rai
    convention. When cosign is available and requested, the manifest is signed using
    Sigstore keyless signing to provide cryptographic provenance.

.PARAMETER Scope
    Planner family scope. One of 'rai', 'sssc', 'security', 'all'. Used to derive the
    default planner tracking root when -ProjectSlug is supplied without -PlanRoot.

.PARAMETER PlanRoot
    Path to a single planner instance (e.g. '.copilot-tracking/sssc-plans/{slug}').
    Takes precedence over -ProjectSlug when supplied.

.PARAMETER ProjectSlug
    Legacy. The project slug identifying the planner session. Combined with -Scope to
    derive the artifact directory when -PlanRoot is not supplied.

.PARAMETER OutputPath
    Path for the generated manifest file. Defaults to '{PlanRoot}/artifact-manifest.json'.

.PARAMETER IncludeCosign
    When specified, attempts to sign the manifest with cosign keyless signing after
    generation. Requires cosign to be available in PATH. Gracefully skips signing with
    a warning when cosign is not found.

.EXAMPLE
    ./scripts/security/Sign-PlannerArtifacts.ps1 -Scope sssc -PlanRoot .copilot-tracking/sssc-plans/contoso-sssc

.EXAMPLE
    ./scripts/security/Sign-PlannerArtifacts.ps1 -ProjectSlug "contoso-ai" -IncludeCosign

.EXAMPLE
    npm run sign:planner -- -Scope sssc -PlanRoot .copilot-tracking/sssc-plans/contoso-sssc -IncludeCosign

.NOTES
    The manifest excludes its own file (artifact-manifest.json) and any cosign signature
    files (.sig, .bundle) from the hash inventory to avoid circular references.
#>

[CmdletBinding(DefaultParameterSetName = 'PlanRoot')]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('rai', 'sssc', 'security', 'all')]
    [string]$Scope = 'rai',

    [Parameter(Mandatory = $false, ParameterSetName = 'PlanRoot')]
    [string]$PlanRoot,

    [Parameter(Mandatory = $true, ParameterSetName = 'ProjectSlug')]
    [ValidateNotNullOrEmpty()]
    [string]$ProjectSlug,

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

        $scopeRootMap = @{
            rai      = '.copilot-tracking/rai-plans'
            sssc     = '.copilot-tracking/sssc-plans'
            security = '.copilot-tracking/security-plans'
        }

        if ($PSBoundParameters.ContainsKey('PlanRoot') -and -not [string]::IsNullOrWhiteSpace($PlanRoot)) {
            $artifactDir = if ([System.IO.Path]::IsPathRooted($PlanRoot)) {
                $PlanRoot
            }
            else {
                Join-Path -Path $PWD -ChildPath $PlanRoot
            }
            if (-not $ProjectSlug) {
                $ProjectSlug = Split-Path -Path $PlanRoot -Leaf
            }
        }
        elseif ($ProjectSlug) {
            if ($Scope -eq 'all' -or -not $scopeRootMap.ContainsKey($Scope)) {
                Write-Host "❌ -ProjectSlug requires -Scope to be one of: $($scopeRootMap.Keys -join ', ')" -ForegroundColor Red
                exit 1
            }
            $artifactDir = Join-Path -Path $PWD -ChildPath "$($scopeRootMap[$Scope])/$ProjectSlug"
        }
        else {
            Write-Host '❌ Either -PlanRoot or -ProjectSlug must be supplied.' -ForegroundColor Red
            exit 1
        }

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

        Write-Host "🔐 Generating artifact manifest for project: $ProjectSlug (scope=$Scope)" -ForegroundColor Cyan

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
            scope       = $Scope
            projectSlug = $ProjectSlug
            planRoot    = $artifactDir
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
