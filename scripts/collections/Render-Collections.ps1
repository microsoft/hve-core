#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Renders collection YAML manifests and Markdown READMEs from the central
    core-manifest.yml and (optionally) runs Validate-Collections.ps1 against
    the rendered output. Provides an inner dev loop for human evaluation.

.DESCRIPTION
    For every collection id declared in collections/core-manifest.yml, this
    script projects the YAML manifest and Markdown body using the shared
    helpers in CoreManifestHelpers.psm1 and writes them to OutputDirectory.

    Each file is compared byte-for-byte (LF-normalized) against the committed
    copy in collections/, and the per-file status is printed. Unless
    -SkipValidation is set, the rendered files are then staged into a scratch
    repo root and passed through Validate-Collections.ps1 so the projection
    can be validated independently of the committed files.

    Intended for local iteration when the automation gate breaks or drifts.

.PARAMETER OutputDirectory
    Destination directory for rendered *.collection.{yml,md} files.
    Defaults to logs/collections-rendered/ under RepoRoot.

.PARAMETER RepoRoot
    Repository root. Defaults to the parent of the script's parent directory.

.PARAMETER ManifestPath
    Path to collections/core-manifest.yml. Defaults to the canonical location.

.PARAMETER CollectionsRoot
    Directory containing committed collections/*.collection.{yml,md} files.
    Used only for the side-by-side comparison summary.

.PARAMETER SkipValidation
    Skip running Validate-Collections.ps1 against the rendered output.

.PARAMETER Clean
    Remove OutputDirectory before rendering. Default behaviour leaves
    pre-existing files in place so diff tooling can surface stale outputs.

.EXAMPLE
    ./Render-Collections.ps1

.EXAMPLE
    ./Render-Collections.ps1 -OutputDirectory ./tmp/collections -Clean

.OUTPUTS
    Exits 0 when rendering succeeds (and validation passes when run).
    Exits 1 when projection fails or validation reports errors.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputDirectory,

    [Parameter()]
    [string]$RepoRoot = (Get-Item (Join-Path $PSScriptRoot '../..')).FullName,

    [Parameter()]
    [string]$ManifestPath,

    [Parameter()]
    [string]$CollectionsRoot,

    [Parameter()]
    [switch]$SkipValidation,

    [Parameter()]
    [switch]$Clean
)

$ErrorActionPreference = 'Stop'

if (-not $ManifestPath) {
    $ManifestPath = Join-Path $RepoRoot 'collections/core-manifest.yml'
}
if (-not $CollectionsRoot) {
    $CollectionsRoot = Join-Path $RepoRoot 'collections'
}
if (-not $OutputDirectory) {
    $OutputDirectory = Join-Path $RepoRoot 'logs/collections-rendered'
}

Import-Module (Join-Path $PSScriptRoot 'Modules/CoreManifestHelpers.psm1') -Force
Import-Module powershell-yaml -Force

if (-not (Test-Path -LiteralPath $ManifestPath)) {
    throw "Core manifest not found at: $ManifestPath"
}

if ($Clean -and (Test-Path -LiteralPath $OutputDirectory)) {
    Remove-Item -LiteralPath $OutputDirectory -Recurse -Force
}
if (-not (Test-Path -LiteralPath $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

function ConvertTo-LfText {
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    return ($Text -replace "`r`n", "`n")
}

Write-Host "Rendering collection projection from core-manifest..." -ForegroundColor Cyan
Write-Host "  RepoRoot:        $RepoRoot"
Write-Host "  ManifestPath:    $ManifestPath"
Write-Host "  OutputDirectory: $OutputDirectory"
Write-Host ''

$core = Read-CoreManifest -ManifestPath $ManifestPath
$collectionsMap = Get-CoreManifestProperty -InputObject $core -Name 'collections'
if ($null -eq $collectionsMap) {
    throw "Core manifest is missing the 'collections' metadata section."
}

$collectionIds = @(Get-CoreManifestKeys -InputObject $collectionsMap)
if ($collectionIds.Count -eq 0) {
    throw "Core manifest defines no collections."
}

$renderResults = [System.Collections.Generic.List[object]]::new()
$projectionFailed = $false

foreach ($id in $collectionIds) {
    $yamlPath = Join-Path $OutputDirectory "$id.collection.yml"
    $mdPath = Join-Path $OutputDirectory "$id.collection.md"
    $diskYaml = Join-Path $CollectionsRoot "$id.collection.yml"
    $diskMd = Join-Path $CollectionsRoot "$id.collection.md"

    try {
        $manifest = ConvertTo-CollectionManifestFromCore -CoreManifest $core -CollectionId $id -RepoRoot $RepoRoot
        $projectedYaml = ConvertTo-Yaml -Data $manifest
        $projectedMd = New-CollectionReadmeBodyFromCore -CoreManifest $core -CollectionId $id -RepoRoot $RepoRoot
    }
    catch {
        $projectionFailed = $true
        Write-Host "  [ERROR]    $id - projection failed: $($_.Exception.Message)" -ForegroundColor Red
        continue
    }

    Set-Content -LiteralPath $yamlPath -Value $projectedYaml -Encoding utf8 -NoNewline
    Set-Content -LiteralPath $mdPath -Value $projectedMd -Encoding utf8 -NoNewline

    foreach ($pair in @(
        @{ Kind = 'yaml';     Out = $yamlPath; Disk = $diskYaml; Body = $projectedYaml },
        @{ Kind = 'markdown'; Out = $mdPath;   Disk = $diskMd;   Body = $projectedMd }
    )) {
        $status = 'Rendered'
        if (Test-Path -LiteralPath $pair.Disk) {
            $diskText = ConvertTo-LfText -Text (Get-Content -LiteralPath $pair.Disk -Raw -Encoding utf8)
            $renderedText = ConvertTo-LfText -Text $pair.Body
            if ([string]::Equals($diskText, $renderedText, [System.StringComparison]::Ordinal)) {
                $status = 'Match'
            }
            else {
                $status = 'Drift'
            }
        }
        else {
            $status = 'NoBaseline'
        }
        $renderResults.Add([pscustomobject]@{
            CollectionId = $id
            Kind = $pair.Kind
            OutputPath = $pair.Out
            DiskPath = $pair.Disk
            Status = $status
        })
    }
}

foreach ($r in $renderResults) {
    $rel = $r.OutputPath
    if ($rel.StartsWith($RepoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        $rel = $rel.Substring($RepoRoot.Length).TrimStart('\','/')
    }
    switch ($r.Status) {
        'Match'      { Write-Host "  [MATCH]    $rel" -ForegroundColor Green }
        'Drift'      { Write-Host "  [DRIFT]    $rel" -ForegroundColor Yellow }
        'NoBaseline' { Write-Host "  [NEW]      $rel" -ForegroundColor Cyan }
        default      { Write-Host "  [$($r.Status.ToUpper())] $rel" }
    }
}

if ($projectionFailed) {
    Write-Host ''
    Write-Host 'Projection errors above prevented full render. Exiting.' -ForegroundColor Red
    exit 1
}

$driftCount = @($renderResults | Where-Object { $_.Status -eq 'Drift' }).Count
Write-Host ''
Write-Host ("Rendered {0} files ({1} match committed, {2} drift)." -f $renderResults.Count, @($renderResults | Where-Object Status -eq 'Match').Count, $driftCount)

if ($SkipValidation) {
    Write-Host ''
    Write-Host 'Validation skipped (-SkipValidation).' -ForegroundColor Yellow
    exit 0
}

Write-Host ''
Write-Host 'Validating rendered projection in scratch repo...' -ForegroundColor Cyan

$scratchRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("hve-core-render-" + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $scratchRoot -Force | Out-Null

try {
    $copySpecs = @(
        @{ Source = '.github';      Required = $true  }
        @{ Source = 'scripts';      Required = $true  }
        @{ Source = 'package.json'; Required = $true  }
        @{ Source = 'extension';    Required = $false }
    )
    foreach ($spec in $copySpecs) {
        $src = Join-Path $RepoRoot $spec.Source
        if (-not (Test-Path -LiteralPath $src)) {
            if ($spec.Required) { throw "Required path not found for scratch copy: $src" }
            continue
        }
        $dst = Join-Path $scratchRoot $spec.Source
        $dstParent = Split-Path -Parent $dst
        if ($dstParent -and -not (Test-Path -LiteralPath $dstParent)) {
            New-Item -ItemType Directory -Path $dstParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $src -Destination $dst -Recurse -Force
    }

    $scratchCollections = Join-Path $scratchRoot 'collections'
    New-Item -ItemType Directory -Path $scratchCollections -Force | Out-Null

    $manifestDest = Join-Path $scratchCollections 'core-manifest.yml'
    Copy-Item -LiteralPath $ManifestPath -Destination $manifestDest -Force

    foreach ($r in $renderResults) {
        $leaf = Split-Path -Leaf $r.OutputPath
        Copy-Item -LiteralPath $r.OutputPath -Destination (Join-Path $scratchCollections $leaf) -Force
    }

    $validatorPath = Join-Path $scratchRoot 'scripts/collections/Validate-Collections.ps1'
    $validatorOutput = Join-Path $OutputDirectory 'collection-validation-results.json'

    & pwsh -NoProfile -File $validatorPath -OutputPath $validatorOutput
    $validatorExit = $LASTEXITCODE

    Write-Host ''
    if ($validatorExit -eq 0) {
        Write-Host 'Validate-Collections.ps1 passed against rendered projection.' -ForegroundColor Green
    }
    else {
        Write-Host "Validate-Collections.ps1 failed against rendered projection (exit $validatorExit)." -ForegroundColor Red
        Write-Host "Results: $validatorOutput"
        exit 1
    }
}
finally {
    if (Test-Path -LiteralPath $scratchRoot) {
        Remove-Item -LiteralPath $scratchRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

exit 0
