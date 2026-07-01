#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Content-moderation pre-job for all eval specs plus changed AI artifacts.

.DESCRIPTION
    Enumerates every stimulus / eval spec file under the eval root and combines
    them with the agent/prompt/instruction/skill files in the PR change set
    (read from the changed-artifact manifest). The combined, de-duplicated file
    list is moderated whole-file via Invoke-ContentModeration.ps1.

    Designed to run as an isolated pre-job before vally eval execution so that
    flagged content blocks the pipeline with a dedicated, clean log. Exit code
    is propagated from the moderation wrapper: 0 clean, 1 flagged (block),
    2 error.

.PARAMETER ManifestPath
    Path to the changed-artifact manifest. Defaults to
    logs/changed-ai-artifacts.json. When absent, only eval specs are moderated.

.PARAMETER EvalRoot
    Root directory of eval specs. Defaults to evals.

.PARAMETER OutFile
    Output path for moderation results. Defaults to
    logs/moderation-artifacts.json.

.PARAMETER Threshold
    Toxicity threshold (0.0-1.0). Defaults to 0.5.

.PARAMETER Model
    Detoxify model variant: original, unbiased, multilingual. Defaults to
    unbiased.

.PARAMETER RepoRoot
    Repository root directory. Defaults to git repo root or script directory.

.NOTES
    Runs via: npm run eval:moderate:artifacts
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$EvalRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [double]$Threshold = 0.5,

    [Parameter(Mandatory = $false)]
    [ValidateSet('original', 'unbiased', 'multilingual')]
    [string]$Model = 'unbiased',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Hint)

    if (-not [string]::IsNullOrWhiteSpace($Hint)) {
        return (Resolve-Path -LiteralPath $Hint).ProviderPath
    }

    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -LiteralPath $gitRoot.Trim()).ProviderPath
        }
    }
    catch { $null = $_ }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..')).ProviderPath
}

function Resolve-PathFromRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path -Path $RepoRoot -ChildPath $Path)
}

if ($MyInvocation.InvocationName -eq '.') { return }

$resolvedRoot = Resolve-RepoRoot -Hint $RepoRoot

if ([string]::IsNullOrWhiteSpace($ManifestPath)) { $ManifestPath = 'logs/changed-ai-artifacts.json' }
if ([string]::IsNullOrWhiteSpace($EvalRoot))     { $EvalRoot     = 'evals' }
if ([string]::IsNullOrWhiteSpace($OutFile))      { $OutFile      = 'logs/moderation-artifacts.json' }

$resolvedManifest = Resolve-PathFromRoot -Path $ManifestPath -RepoRoot $resolvedRoot
$resolvedEvalRoot = Resolve-PathFromRoot -Path $EvalRoot     -RepoRoot $resolvedRoot
$resolvedOutFile  = Resolve-PathFromRoot -Path $OutFile      -RepoRoot $resolvedRoot

if (-not (Test-Path -LiteralPath $resolvedEvalRoot -PathType Container)) {
    Write-Host "::error::Eval root not found: $resolvedEvalRoot"
    exit 2
}

$outDir = Split-Path -Parent $resolvedOutFile
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$fileSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

# Collect every stimulus / eval spec file under the eval root.
$specFiles = Get-ChildItem -LiteralPath $resolvedEvalRoot -Recurse -File -Include '*.yaml', '*.yml' -ErrorAction SilentlyContinue
foreach ($spec in $specFiles) {
    $null = $fileSet.Add($spec.FullName)
}

# Collect changed artifact files from the manifest (skip deletions and missing files).
if (Test-Path -LiteralPath $resolvedManifest -PathType Leaf) {
    $manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
    $artifacts = @()
    if ($null -ne $manifest -and $null -ne $manifest.artifacts) {
        $artifacts = @($manifest.artifacts | Where-Object { [string]$_.status -ne 'D' })
    }

    foreach ($artifact in $artifacts) {
        $artifactPath = [string]$artifact.path
        if ([string]::IsNullOrWhiteSpace($artifactPath)) { continue }
        $absolute = Resolve-PathFromRoot -Path $artifactPath -RepoRoot $resolvedRoot
        if (Test-Path -LiteralPath $absolute -PathType Leaf) {
            $null = $fileSet.Add(((Resolve-Path -LiteralPath $absolute).ProviderPath))
        }
        else {
            Write-Warning "Artifact file not found: $artifactPath"
        }
    }
}
else {
    Write-Warning "Manifest not found: $resolvedManifest; moderating eval specs only."
}

$files = @($fileSet)

if ($files.Count -eq 0) {
    $empty = [ordered]@{
        scope     = 'artifacts'
        model     = $Model
        threshold = $Threshold
        flagged   = $false
        results   = @()
    }
    $empty | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $resolvedOutFile -Encoding utf8NoBOM
    Write-Host "No eval specs or changed AI artifacts to moderate. Empty log written to $resolvedOutFile"
    exit 0
}

Write-Host "Moderating $($files.Count) file(s) (all eval specs + changed artifacts)."

$moderationScript = Join-Path $PSScriptRoot 'Invoke-ContentModeration.ps1'
& $moderationScript -FileList $files -Scope 'artifacts' -OutFile $resolvedOutFile -Threshold $Threshold -Model $Model -RepoRoot $resolvedRoot
$exitCode = $LASTEXITCODE

exit $exitCode
