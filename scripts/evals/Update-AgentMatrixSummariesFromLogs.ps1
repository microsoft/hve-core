#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Rebuilds per-agent matrix JSON summaries from existing vally logs without re-running `npx vally`.

.DESCRIPTION
    Iterates the per-agent JSON files in a matrix output directory, locates the matching
    `logs/agent-matrix/<slug>-*.log`, re-parses graders (✔/✘ format), reads the linked
    `results.jsonl` for stimulus prompt, agent output, and grader evidence, then rewrites
    the per-agent JSON in place. The aggregate `agent-matrix-summary.json` is regenerated
    from the updated per-agent files.

    Use this to backfill richer drill-down data after upgrading the parser in
    `Invoke-AgentMatrix.ps1`, without paying the cost of another live matrix run.

.NOTES
    Maintenance-only utility. Run it ad hoc when refreshing matrix summaries from
    existing logs; it is not referenced by package.json eval scripts, CI workflows,
    or other eval scripts.

.PARAMETER MatrixDir
    Path to the matrix output directory (e.g. `evals/results/agent-matrix/2026-05-28`).
    Defaults to the most recent dated directory under `evals/results/agent-matrix/`.

.PARAMETER LogsDir
    Root of the agent-matrix logs. Defaults to `<RepoRoot>/logs/agent-matrix`.

.PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

.EXAMPLE
    ./Update-AgentMatrixSummariesFromLogs.ps1

    Backfills the latest matrix run using sibling logs and JSONL trajectories.

.EXAMPLE
    ./Update-AgentMatrixSummariesFromLogs.ps1 -MatrixDir evals/results/agent-matrix/2026-05-28

    Backfills the specified matrix run.
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [string]$MatrixDir,

    [Parameter(Mandatory = $false)]
    [string]$LogsDir,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Import helpers from Invoke-AgentMatrix.ps1 in-place via dot-source guard.
# That script's main block is skipped when sourced (InvocationName -eq '.').
. (Join-Path $PSScriptRoot 'Invoke-AgentMatrix.ps1')

function Resolve-MatrixDir {
    param([string]$Hint, [string]$Root)
    if ($Hint) { return (Resolve-Path -LiteralPath $Hint).Path }
    $base = Join-Path $Root 'evals/results/agent-matrix'
    if (-not (Test-Path -LiteralPath $base)) { throw "No matrix results root at $base." }
    $latest = Get-ChildItem -LiteralPath $base -Directory |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object Name -Descending |
        Select-Object -First 1
    if (-not $latest) { throw "No dated matrix run directories under $base." }
    return $latest.FullName
}

$root = Resolve-RepoRoot -Hint $RepoRoot
$matrixDirResolved = Resolve-MatrixDir -Hint $MatrixDir -Root $root
if (-not $LogsDir) { $LogsDir = Join-Path $root 'logs/agent-matrix' }
if (-not (Test-Path -LiteralPath $LogsDir)) { throw "Logs directory not found: $LogsDir" }

$perAgentFiles = Get-ChildItem -LiteralPath $matrixDirResolved -Filter '*.json' -File |
    Where-Object { $_.Name -ne 'agent-matrix-summary.json' }
Write-Host "Backfill: matrix dir=$matrixDirResolved slugs=$($perAgentFiles.Count)" -ForegroundColor Cyan

$updated = [System.Collections.Generic.List[hashtable]]::new()
foreach ($file in $perAgentFiles) {
    $slug = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
    $existing = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 12

    $agentEntry = @{
        slug      = $slug
        class     = if ($existing.PSObject.Properties['class'])     { [string]$existing.class }     else { '' }
        cost_tier = if ($existing.PSObject.Properties['cost_tier']) { [string]$existing.cost_tier } else { 'unknown' }
    }

    # Use the slug's most recent log so re-runs of the same slug are reflected.
    $logCandidate = Get-ChildItem -LiteralPath $LogsDir -Filter "$slug-*.log" -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $logCandidate) {
        Write-Warning "[$slug] no log found under $LogsDir; skipping"
        $updated.Add(@{ slug = $slug; overall = if ($existing.PSObject.Properties['overall']) { [string]$existing.overall } else { 'unknown' }; obj = $existing })
        continue
    }

    $lines = [System.IO.File]::ReadAllLines($logCandidate.FullName)
    $graders = Get-GraderStatusesFromLog -Lines $lines
    if ($null -eq $graders) { $graders = [System.Collections.Generic.List[hashtable]]::new() }

    $vallyOutDir = Get-VallyOutputDirFromLog -Lines $lines
    $details = Read-VallyTrajectoryDetails -OutputDir $vallyOutDir
    if ($details['richGraders'] -and $details['richGraders'].Count -gt 0) {
        $graders = Merge-GraderDetails -LogGraders $graders -RichGraders $details['richGraders']
    }

    $exitCode = if ($existing.PSObject.Properties['exitCode']) { [int]$existing.exitCode } else { 0 }
    $logPath  = if ($existing.PSObject.Properties['logPath'])  { [string]$existing.logPath } else { $logCandidate.FullName }

    $summary = New-AgentSummary -AgentEntry $agentEntry -ExitCode $exitCode -Graders $graders `
        -LogPath $logPath -OutputDir $vallyOutDir `
        -StimulusPrompt $details['stimulusPrompt'] -Output $details['output']

    if ($PSCmdlet.ShouldProcess($file.FullName, "Rewrite enriched per-agent summary")) {
        Write-SummaryJson -Summary $summary -Path $file.FullName
    }
    $updated.Add(@{ slug = $slug; overall = [string]$summary['overall']; obj = $summary })

    $failingNames = @($graders | Where-Object { $_['status'] -eq 'fail' } | ForEach-Object { $_['name'] })
    $failPart = if ($failingNames.Count -gt 0) { " failing=$($failingNames -join ',')" } else { '' }
    Write-Host "[$slug] graders=$($graders.Count) overall=$($summary['overall'])$failPart" -ForegroundColor DarkGray
}

# Rebuild the aggregate summary from the (now enriched) per-agent files.
$aggPath = Join-Path $matrixDirResolved 'agent-matrix-summary.json'
$aggExisting = if (Test-Path -LiteralPath $aggPath) {
    Get-Content -LiteralPath $aggPath -Raw | ConvertFrom-Json -Depth 12
} else { $null }

$resultsList = [System.Collections.Generic.List[hashtable]]::new()
foreach ($u in ($updated | Sort-Object { $_.slug })) {
    # $u.obj is an OrderedDictionary returned by New-AgentSummary; copy entries by key
    # (PSObject.Properties on an OrderedDictionary returns CLR members like Count/Keys,
    # not the dictionary entries themselves).
    $h = @{}
    foreach ($k in $u.obj.Keys) { $h[$k] = $u.obj[$k] }
    $resultsList.Add($h)
}

$tier = if ($aggExisting -and $aggExisting.PSObject.Properties['tier']) { [string]$aggExisting.tier } else { 'pr' }
$mode = if ($aggExisting -and $aggExisting.PSObject.Properties['mode']) { [string]$aggExisting.mode } else { 'all' }
$planned = if ($aggExisting -and $aggExisting.PSObject.Properties['plannedCommands']) { @($aggExisting.plannedCommands) } else { @() }
$aggSummary = New-MatrixSummary -Tier $tier -Mode $mode -Results $resultsList -PlannedCommands $planned

if ($PSCmdlet.ShouldProcess($aggPath, "Rewrite aggregate matrix summary")) {
    Write-SummaryJson -Summary $aggSummary -Path $aggPath
}
Write-Host "Backfill complete: overall=$($aggSummary['overall']) failures=$($aggSummary['failures'].Count)" -ForegroundColor Green
