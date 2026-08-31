#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    First-line-of-defense content moderation over changed AI corpus markdown files.

.DESCRIPTION
    Reads the changed-AI-artifacts manifest produced by Get-ChangedAIArtifact.ps1,
    filters to `.github/{agents,prompts,instructions,skills}/**/*.md`, strips YAML
    frontmatter from each file body, and delegates to Invoke-ContentModeration.ps1
    with `-Scope corpus`. Fork-safe (no secrets required).

.PARAMETER ManifestPath
    Path to the changed-artifacts JSON manifest. Defaults to logs/changed-ai-artifacts.json.

.PARAMETER OutFile
    Output path for moderation results. Defaults to logs/moderation-corpus.json.

.PARAMETER Threshold
    Toxicity threshold (0.0-1.0). Defaults to 0.5.

.PARAMETER Model
    Detoxify model variant. Defaults to 'unbiased'.

.PARAMETER RepoRoot
    Repository root. Defaults to git toplevel.

.EXAMPLE
    ./Invoke-CorpusModeration.ps1 -ManifestPath logs/changed-ai-artifacts.json
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManifestPath = 'logs/changed-ai-artifacts.json',

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [double]$Threshold = 0.5,

    [Parameter(Mandatory = $false)]
    [ValidateSet('original', 'unbiased', 'multilingual')]
    [string]$Model = 'unbiased',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = $(
        $detectedRoot = git rev-parse --show-toplevel 2>$null
        if ($detectedRoot) { $detectedRoot } else { $PSScriptRoot }
    )
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/CorpusReader.psm1') -Force

if ($MyInvocation.InvocationName -eq '.') { return }

$resolvedManifest = if ([System.IO.Path]::IsPathRooted($ManifestPath)) {
    $ManifestPath
} else {
    Join-Path $RepoRoot $ManifestPath
}

if (-not $OutFile) {
    $OutFile = Join-Path $RepoRoot 'logs/moderation-corpus.json'
}

if (-not (Test-Path -LiteralPath $resolvedManifest)) {
    Write-Warning "Manifest not found: $resolvedManifest; emitting empty corpus moderation result."
    $empty = @{
        scope   = 'corpus'
        records = @()
        summary = @{ total = 0; flaggedCount = 0 }
    }
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    $empty | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding utf8NoBOM
    exit 0
}

$corpusPaths = Get-CorpusArtifactPaths -ManifestPath $resolvedManifest
if ($corpusPaths.Count -eq 0) {
    Write-Host "No corpus markdown changes detected; skipping moderation."
    $empty = @{
        scope   = 'corpus'
        records = @()
        summary = @{ total = 0; flaggedCount = 0 }
    }
    $outDir = Split-Path $OutFile -Parent
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null
    }
    $empty | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding utf8NoBOM
    exit 0
}

$records = foreach ($relPath in $corpusPaths) {
    $absPath = Join-Path $RepoRoot $relPath
    if (-not (Test-Path -LiteralPath $absPath)) {
        Write-Warning "Skipping missing corpus file: $relPath"
        continue
    }
    $body = Get-CorpusArtifactBody -Path $absPath
    @{ id = $relPath; text = $body }
}

$recordsArray = @($records | Where-Object { $null -ne $_ })
if ($recordsArray.Count -eq 0) {
    Write-Host "All listed corpus files missing or empty; skipping moderation."
    exit 0
}

$moderationScript = Join-Path $PSScriptRoot 'Invoke-ContentModeration.ps1'
$arguments = @{
    Records   = $recordsArray
    Scope     = 'corpus'
    Threshold = $Threshold
    Model     = $Model
    OutFile   = $OutFile
    RepoRoot  = $RepoRoot
}

& $moderationScript @arguments
exit $LASTEXITCODE
