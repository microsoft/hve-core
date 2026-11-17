#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Deterministically computes stated monetary value, net value, BCR, and ROI from FinOps claims and HVE evidence.

.DESCRIPTION
    Evaluates structured 9-category FinOps benefit claims, cost evidence, and optional
    Collect-HveValueEvidence.ps1 snapshots using HveBenefitValuation.psm1 with zero LLM math.

.PARAMETER ClaimsPath
    Optional JSON file carrying benefit_claims, cost_evidence, fx_rates, and delivery_valuation.

.PARAMETER ClaimsJson
    Optional inline JSON string equivalent to ClaimsPath.

.PARAMETER EvidencePath
    Optional JSON snapshot emitted by Collect-HveValueEvidence.ps1.

.PARAMETER OutputPath
    Optional local file path (.md or .json) to write the valuation report.

.PARAMETER Format
    Output format written to stdout: json (default) or markdown.

.PARAMETER AsOf
    Optional YYYY-MM-DD override for reproducible output.

.EXAMPLE
    ./Measure-HveBenefitValue.ps1 -ClaimsPath ./claims.json -EvidencePath ../evidence.json
#>
[CmdletBinding()]
[OutputType([string])]
param(
    [Parameter(Mandatory = $false)]
    [string]$ClaimsPath = '',

    [Parameter(Mandatory = $false)]
    [string]$ClaimsJson = '',

    [Parameter(Mandatory = $false)]
    [string]$EvidencePath = '',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = '',

    [Parameter(Mandatory = $false)]
    [ValidateSet('json', 'markdown')]
    [string]$Format = 'json',

    [Parameter(Mandatory = $false)]
    [string]$AsOf = ''
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Get-Command -Name Get-HveBenefitValuation -ErrorAction SilentlyContinue)) {
    Import-Module (Join-Path $PSScriptRoot 'HveBenefitValuation.psm1')
}

if (-not [string]::IsNullOrWhiteSpace($ClaimsPath) -and -not [string]::IsNullOrWhiteSpace($ClaimsJson)) {
    throw (Get-HveBenefitValuationStop -Message 'Specify either -ClaimsPath or -ClaimsJson, not both.')
}
if ([string]::IsNullOrWhiteSpace($ClaimsPath) -and [string]::IsNullOrWhiteSpace($ClaimsJson) -and [string]::IsNullOrWhiteSpace($EvidencePath)) {
    throw (Get-HveBenefitValuationStop -Message 'Supply at least one input (-ClaimsPath, -ClaimsJson, or -EvidencePath).')
}

$inputDoc = $null
if (-not [string]::IsNullOrWhiteSpace($ClaimsPath)) {
    $safeClaims = Assert-HveSafePath -CandidatePath $ClaimsPath
    if (-not (Test-Path -LiteralPath $safeClaims -PathType Leaf)) {
        throw (Get-HveBenefitValuationStop -Message "ClaimsPath '$ClaimsPath' was not found.")
    }
    $inputDoc = [System.IO.File]::ReadAllText($safeClaims) | ConvertFrom-Json -Depth 32
}
elseif (-not [string]::IsNullOrWhiteSpace($ClaimsJson)) {
    $inputDoc = $ClaimsJson | ConvertFrom-Json -Depth 32
}

$evidenceDoc = $null
if (-not [string]::IsNullOrWhiteSpace($EvidencePath)) {
    $safeEv = Assert-HveSafePath -CandidatePath $EvidencePath
    if (-not (Test-Path -LiteralPath $safeEv -PathType Leaf)) {
        throw (Get-HveBenefitValuationStop -Message "EvidencePath '$EvidencePath' was not found.")
    }
    $evidenceDoc = [System.IO.File]::ReadAllText($safeEv) | ConvertFrom-Json -Depth 32
}

$model = Get-HveBenefitValuation -InputDocument $inputDoc -EvidenceDocument $evidenceDoc -AsOf $AsOf

if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
    if ($OutputPath -match '^[A-Za-z][A-Za-z0-9+.-]+://' -or $OutputPath -match '^(?:\\\\|//)') {
        throw (Get-HveBenefitValuationStop -Message "OutputPath '$OutputPath' must be a local filesystem path.")
    }
    $safeOut = Assert-HveSafePath -CandidatePath $OutputPath
    $parent = Split-Path -Parent $safeOut
    if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force | Out-Null
    }
    $body = if ($safeOut.EndsWith('.json', [System.StringComparison]::OrdinalIgnoreCase)) {
        ($model | ConvertTo-Json -Depth 20) + "`n"
    }
    else {
        ConvertTo-HveBenefitValuationMarkdown -Model $model
    }
    [System.IO.File]::WriteAllText($safeOut, $body, [System.Text.UTF8Encoding]::new($false))
    $model['artifactPath'] = $safeOut
}

if ($Format -eq 'markdown') {
    Write-Output (ConvertTo-HveBenefitValuationMarkdown -Model $model)
}
else {
    Write-Output ($model | ConvertTo-Json -Depth 20)
}
