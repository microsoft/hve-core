#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Emits a JSON manifest of synthetic artifacts derived from changed eval specs.

.DESCRIPTION
    Diffs `evals/` between two git refs and resolves every added or modified
    stimulus to a synthetic artifact descriptor via the `ChangedSpecStimulus`
    module. The output mirrors the shape of `Get-ChangedAIArtifact.ps1`
    (`@{ baseRef; headRef; artifacts = @(...) }`) so `Invoke-VallyEvals.ps1` can
    union the entries into its execution set and run a changed test even when the
    underlying AI artifact is unchanged (issue #2297).

    Exit codes:
      0 = manifest written successfully (manifest may be empty).
      2 = git invocation failed.

.PARAMETER BaseRef
    Base git ref for the diff. Defaults to `origin/main`.

.PARAMETER HeadRef
    Head git ref for the diff. Defaults to `HEAD`.

.PARAMETER EvalRoot
    Eval spec root relative to the repository root. Defaults to `evals`.

.PARAMETER OutFile
    Output JSON path. Defaults to `logs/changed-spec-stimuli.json`.

.PARAMETER RepoRoot
    Repository root. Defaults to the git toplevel.

.EXAMPLE
    pwsh -File scripts/evals/Get-ChangedSpecStimulus.ps1
    Diff origin/main...HEAD and emit logs/changed-spec-stimuli.json.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$BaseRef = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$HeadRef = 'HEAD',

    [Parameter(Mandatory = $false)]
    [string]$EvalRoot = 'evals',

    [Parameter(Mandatory = $false)]
    [string]$OutFile,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/ChangedSpecStimulus.psm1') -Force

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
    catch {
        $null = $_
    }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).ProviderPath
}

$resolvedRepoRoot = Resolve-RepoRoot -Hint $RepoRoot

if ([string]::IsNullOrWhiteSpace($OutFile)) {
    $OutFile = Join-Path -Path $resolvedRepoRoot -ChildPath 'logs/changed-spec-stimuli.json'
}
elseif (-not [System.IO.Path]::IsPathRooted($OutFile)) {
    $OutFile = Join-Path -Path $resolvedRepoRoot -ChildPath $OutFile
}

try {
    $artifacts = Get-ChangedSpecStimulusArtifact -BaseRef $BaseRef -HeadRef $HeadRef -RepoRoot $resolvedRepoRoot -EvalRoot $EvalRoot
}
catch {
    Write-Error $_.Exception.Message
    exit 2
}

$manifest = @{
    baseRef   = $BaseRef
    headRef   = $HeadRef
    artifacts = @($artifacts)
}

$outDir = Split-Path -Path $OutFile -Parent
if (-not [string]::IsNullOrWhiteSpace($outDir) -and -not (Test-Path -LiteralPath $outDir -PathType Container)) {
    New-Item -ItemType Directory -Path $outDir -Force | Out-Null
}

$manifest | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding UTF8

Write-Host "Detected $($manifest.artifacts.Count) changed eval-spec stimulus artifact(s) between $BaseRef and $HeadRef."
Write-Host "Manifest: $OutFile"
exit 0
