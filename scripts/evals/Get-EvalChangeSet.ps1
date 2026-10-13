#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Writes a canonical immutable comparison for all eval change selectors.
.DESCRIPTION
    Resolves explicit base/head revisions and their merge base. Empty comparisons
    succeed with changes: []. Git and manifest failures exit 2 with diagnostics.
.PARAMETER BaseRef
    Explicit base revision. Workflows pass the change-range resolver's verified
    base commit.
.PARAMETER HeadRef
    Explicit head revision.
.PARAMETER RepoRoot
    Repository directory, defaulting to the repository containing this script.
.PARAMETER OutFile
    Manifest destination relative to RepoRoot, or an absolute path.
.EXAMPLE
    ./Get-EvalChangeSet.ps1 -BaseRef origin/main -HeadRef feature-branch
.NOTES
    Used by eval-validation.yml before eligibility and artifact selection.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$BaseRef,
    [Parameter(Mandatory)][string]$HeadRef,
    [string]$RepoRoot = (Join-Path $PSScriptRoot '../..'),
    [string]$OutFile = 'logs/eval-change-set.json'
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest
Import-Module (Join-Path $PSScriptRoot 'Modules/EvalChangeSet.psm1') -Force

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $Result = New-EvalChangeSet -BaseRef $BaseRef -HeadRef $HeadRef -RepoRoot $RepoRoot
        if (-not [System.IO.Path]::IsPathRooted($OutFile)) { $OutFile = Join-Path $RepoRoot $OutFile }
        $null = New-Item -ItemType Directory -Path (Split-Path $OutFile -Parent) -Force
        $Result | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding utf8NoBOM
        Write-Host "Selected $($Result.changes.Count) change(s): $($Result.comparisonBase)..$($Result.headRef)"
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Eval change-set generation failed: $($_.Exception.Message)"
        exit 2
    }
}
