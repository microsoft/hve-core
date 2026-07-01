#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Renders a self-contained HTML dashboard for a local baseline-equivalence eval run.

.DESCRIPTION
    Parses results.jsonl from baseline and customized run directories along with the
    sibling vally compare log, then writes a self-contained HTML file (offline, no CDN)
    summarizing pass rates, identical-output ratios, pairwise tallies, and per-trial
    output diffs. The HTML supports search, sort, and click-to-expand drill-down.

    Variant identity (which agent or customization is materialized into each side) is
    read from `variant.yaml` files sitting beside the eval specs under
    `evals/baseline-equivalence/{baseline,customized}/`. The dashboard surfaces those
    labels in the header instead of accepting an agent name as input.

.PARAMETER RunId
    Run identifier (timestamped folder under the model directory), e.g.
    `20260523T182312033Z`.

.PARAMETER Model
    Model label, e.g. `claude-opus-4.7`. Determines the model directory under
    the results root.

.PARAMETER Agent
    Agent identity rendered in the dashboard meta line, e.g. `task-researcher`.
    Required; replaces the previous derived-from-variant `Subject:` field.

.PARAMETER RepoRoot
    Optional repository root. Defaults to the git toplevel, falling back to the
    repo root inferred from this script's location.

.PARAMETER ResultsRoot
    Optional path to the baseline-equivalence results root. Defaults to
    `evals/results/baseline-equivalence` under the repo root.

.PARAMETER OutPath
    Optional output path. Defaults to
    `logs/equivalence-dashboard-<Model>-<RunId>.html` under the repo root.

.PARAMETER Open
    When set, attempts to open the generated HTML in the default browser.

.NOTES
    The variant.b.applied list is recomputed at render time by walking the
    materialized customized workspace (evals/baseline-equivalence/customized/workspace).
    It reflects the workspace as it exists at render time, not a snapshot of the
    workspace at the original run time. Re-rendering an older run against a
    materially different workspace will therefore show the current set of
    artifacts in that section.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$RunId,

    [Parameter(Mandatory)]
    [string]$Model,

    [Parameter(Mandatory)]
    [string]$Agent,

    [string]$RepoRoot,

    [string]$ResultsRoot,

    [string]$OutPath,

    [switch]$Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'lib/EquivalenceParsing.psm1') -Force

if (-not $RepoRoot) {
    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        $RepoRoot = $gitRoot.Trim()
    }
    else {
        $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
    }
}
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).ProviderPath

if (-not $ResultsRoot) {
    $ResultsRoot = Join-Path $RepoRoot 'evals/results/baseline-equivalence'
}

$runRoot = Join-Path $ResultsRoot "$Model/$RunId"
if (-not (Test-Path -LiteralPath $runRoot)) {
    throw "Run directory not found: $runRoot"
}

$baselineDir = Join-Path $runRoot 'baseline'
$customizedDir = Join-Path $runRoot 'customized'
if (-not (Test-Path -LiteralPath $baselineDir)) { throw "Missing baseline directory: $baselineDir" }
if (-not (Test-Path -LiteralPath $customizedDir)) { throw "Missing customized directory: $customizedDir" }

foreach ($variantDir in @($baselineDir, $customizedDir)) {
    $resultsFiles = @(Get-ChildItem -LiteralPath $variantDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue)
    if ($resultsFiles.Count -eq 0) {
        throw "Missing results.jsonl under variant directory: $variantDir"
    }
}

$baseline = ConvertFrom-EquivalenceResults -RunDir $baselineDir
$customized = ConvertFrom-EquivalenceResults -RunDir $customizedDir

$compareLog = Join-Path $RepoRoot "logs/vally-compare-$Model-$RunId.log"
if (Test-Path -LiteralPath $compareLog) {
    $lines = Get-Content -LiteralPath $compareLog -Encoding utf8
    $compare = Measure-CompareTrials -Lines $lines
}
else {
    Write-Warning "Compare log not found at $compareLog; pairwise tally will be zero."
    $compare = @{ Total = 0; Ties = 0; AWins = 0; BWins = 0; PerStimulus = @{} }
}

$defaultVariantA = @{ kind = 'baseline'; name = 'baseline';   label = 'Baseline (A)';   description = ''; applied = @() }
$defaultVariantB = @{ kind = 'unknown';  name = 'customized'; label = 'Customized (B)'; description = ''; applied = @() }
$variantA = Get-VariantMetadata -VariantYamlPath (Join-Path $RepoRoot 'evals/baseline-equivalence/baseline/variant.yaml') -Default $defaultVariantA
$variantB = Get-VariantMetadata -VariantYamlPath (Join-Path $RepoRoot 'evals/baseline-equivalence/customized/variant.yaml') -Default $defaultVariantB
$workspaceRoot = Join-Path $RepoRoot 'evals/baseline-equivalence/customized/workspace'
$variantB.applied = @(Get-AppliedArtifacts -WorkspaceRoot $workspaceRoot)
$variants = @{ a = $variantA; b = $variantB; subject = [string]$variantB.name }

$merged = Merge-EquivalenceStimuli -Baseline $baseline -Customized $customized -Compare $compare
$html = ConvertTo-EquivalenceHtml -Stimuli $merged -Model $Model -RunId $RunId -Agent $Agent -Variants $variants

if (-not $OutPath) {
    $OutPath = Join-Path $RepoRoot "logs/equivalence-dashboard-$Model-$RunId.html"
}

$outDir = Split-Path -Parent $OutPath
if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}
Set-Content -LiteralPath $OutPath -Value $html -Encoding utf8NoBOM

Write-Host "Wrote $OutPath"

if ($Open) {
    try {
        Start-Process -FilePath $OutPath -ErrorAction Stop
    }
    catch {
        Write-Warning "Could not open browser automatically: $($_.Exception.Message). Open the file manually: $OutPath"
    }
}
