#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Merges all planned eval producer summaries into one authoritative result.
.DESCRIPTION
    Validates the canonical plan, exact producer set, ordinary shard identity and
    ownership, then writes one deterministic eval summary and bounded status.
.PARAMETER PlanPath
    Canonical agent eval plan.
.PARAMETER SummaryDirectory
    Directory recursively containing one eval-summary.json per producer.
.PARAMETER OutputPath
    Canonical merged eval summary destination.
.PARAMETER StatusPath
    Bounded fan-in status destination.
.EXAMPLE
    ./Merge-EvalExecution.ps1 -PlanPath logs/agent-eval-plan.json `
        -SummaryDirectory shard-results -OutputPath logs/eval-summary.json
.NOTES
    Runs in the authoritative Eval Validation fan-in job.
#>
[CmdletBinding()]
param(
    [string]$PlanPath,
    [string]$SummaryDirectory,
    [string]$OutputPath,
    [string]$StatusPath
)

$ErrorActionPreference = 'Stop'
Import-Module (Join-Path $PSScriptRoot 'Modules/VallyRunner.psm1') -Force

function Write-EvalFanInJson {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)]$Value, [Parameter(Mandatory = $true)][string]$Path)
    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) { New-Item -ItemType Directory -Path $directory -Force | Out-Null }
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Merge-EvalSummaryValue {
    [CmdletBinding()]
    [OutputType([ordered])]
    param([Parameter(Mandatory = $true)][psobject]$Plan, [Parameter(Mandatory = $true)][psobject[]]$Summary)

    if (-not (Test-AgentEvalPlanDigest -Plan $Plan)) { throw 'Canonical plan digest is invalid.' }
    $byProducer = @{}
    foreach ($summaryItem in $Summary) {
        $producer = [string]$summaryItem.producer
        if ([string]::IsNullOrWhiteSpace($producer)) {
            $producer = if (@($summaryItem.kindFilter) -contains 'equivalence') { 'equivalence' } else { throw 'A summary omits producer identity.' }
        }
        if ($byProducer.ContainsKey($producer)) { throw "Duplicate producer summary '$producer'." }
        $byProducer[$producer] = $summaryItem
    }

    $expected = @($Plan.expectedProducers | ForEach-Object { [string]$_ })
    $expectedFanIn = @($expected | Where-Object { $_ -notlike 'baseline:*' })
    if ([bool]$Plan.baseline.required) { $expectedFanIn += 'equivalence' }
    $observed = @($byProducer.Keys | Sort-Object)
    if (@(Compare-Object -ReferenceObject @($expectedFanIn | Sort-Object) -DifferenceObject $observed).Count -gt 0) {
        throw "Producer set does not match the canonical plan. Expected '$($expectedFanIn -join ',')'; observed '$($observed -join ',')'."
    }

    $artifactOwners = @{}
    $runOwners = @{}
    foreach ($shard in @($Plan.ordinaryShards)) {
        $summaryItem = $byProducer[[string]$shard.id]
        if ([string]$summaryItem.planDigest -cne [string]$Plan.planDigest) { throw "Shard '$($shard.id)' has the wrong plan digest." }
        $summaryKinds = @($summaryItem.kindFilter | ForEach-Object { [string]$_ })
        if ($summaryKinds.Count -ne 1 -or $summaryKinds[0] -cne [string]$shard.kind) {
            throw "Shard '$($shard.id)' has the wrong kind."
        }
        if ([string]$summaryItem.manifestDigests.changedArtifacts -cne [string]$Plan.manifestDigests.changedArtifacts -or
            [string]$summaryItem.manifestDigests.changedSpecs -cne [string]$Plan.manifestDigests.changedSpecs) {
            throw "Shard '$($shard.id)' has the wrong manifest digests."
        }
        foreach ($artifact in @($summaryItem.perArtifact)) {
            $key = "$([string]$artifact.kind):$([string]$artifact.artifactId)"
            if ($artifactOwners.ContainsKey($key)) { throw "Duplicate artifact evidence '$key'." }
            $artifactOwners[$key] = [string]$shard.id
        }
        foreach ($spec in @($summaryItem.perSpec)) {
            $key = [string]$spec.specPath
            if (-not [string]::IsNullOrWhiteSpace([string]$spec.tag)) { $key = "$key|$([string]$spec.tag)" }
            if ($runOwners.ContainsKey($key)) { throw "Duplicate run-key evidence '$key'." }
            $runOwners[$key] = [string]$shard.id
        }
        if (@(Compare-Object -ReferenceObject @($shard.artifacts | Sort-Object) -DifferenceObject @($artifactOwners.Keys | Where-Object { $artifactOwners[$_] -eq $shard.id } | Sort-Object)).Count -gt 0) {
            throw "Shard '$($shard.id)' artifact evidence is incomplete."
        }
        if (@(Compare-Object -ReferenceObject @($shard.runKeys | Sort-Object) -DifferenceObject @($runOwners.Keys | Where-Object { $runOwners[$_] -eq $shard.id } | Sort-Object)).Count -gt 0) {
            throw "Shard '$($shard.id)' run-key evidence is incomplete."
        }
    }

    $totals = [ordered]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 0; durationMs = 0; failedSpecs = 0 }
    $perArtifact = [System.Collections.Generic.List[object]]::new()
    $perSpec = [System.Collections.Generic.List[object]]::new()
    $equivalence = [System.Collections.Generic.List[object]]::new()
    $phaseTimings = [System.Collections.Generic.List[object]]::new()
    foreach ($producer in @($expectedFanIn | Sort-Object)) {
        $summaryItem = $byProducer[$producer]
        foreach ($name in @($totals.Keys)) { $totals[$name] += [int]$summaryItem.totals.$name }
        foreach ($item in @($summaryItem.perArtifact)) { $perArtifact.Add($item) }
        foreach ($item in @($summaryItem.perSpec)) { $perSpec.Add($item) }
        foreach ($item in @($summaryItem.equivalence)) { $equivalence.Add($item) }
        foreach ($item in @($summaryItem.phaseTimings)) { $phaseTimings.Add($item) }
    }
    return [ordered]@{
        schemaVersion = '1.0.0'; planDigest = $Plan.planDigest; producers = @($expectedFanIn | Sort-Object)
        totals = $totals
        perArtifact = @($perArtifact | Sort-Object kind, artifactId)
        perSpec = @($perSpec | Sort-Object specPath, tag)
        equivalence = @($equivalence)
        phaseTimings = @($phaseTimings)
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    if ([string]::IsNullOrWhiteSpace($PlanPath) -or [string]::IsNullOrWhiteSpace($SummaryDirectory) -or [string]::IsNullOrWhiteSpace($OutputPath)) {
        Write-Error -ErrorAction Continue 'PlanPath, SummaryDirectory, and OutputPath are required.'
        exit 2
    }
    if ([string]::IsNullOrWhiteSpace($StatusPath)) { $StatusPath = Join-Path (Split-Path -Parent $OutputPath) 'eval-fan-in-status.json' }
    try {
        $plan = Get-Content -LiteralPath $PlanPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        $paths = @(Get-ChildItem -LiteralPath $SummaryDirectory -Filter 'eval-summary.json' -Recurse -File | Select-Object -ExpandProperty FullName)
        $summaries = @($paths | ForEach-Object { Get-Content -LiteralPath $_ -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100 -ErrorAction Stop })
        $merged = Merge-EvalSummaryValue -Plan $plan -Summary $summaries
        Write-EvalFanInJson -Value $merged -Path $OutputPath
        Write-Host "Merged eval execution: producers=$($merged.producers.Count) failedSpecs=$($merged.totals.failedSpecs)"
        if ($merged.totals.failedSpecs -gt 0) {
            Write-EvalFanInJson -Value ([ordered]@{ schemaVersion = '1.0.0'; status = 'fail'; category = 'evidence' }) -Path $StatusPath
            exit 1
        }
        Write-EvalFanInJson -Value ([ordered]@{ schemaVersion = '1.0.0'; status = 'pass'; category = 'none' }) -Path $StatusPath
        exit 0
    }
    catch {
        if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
            Write-EvalFanInJson -Value ([ordered]@{
                    schemaVersion = '1.0.0'
                    planDigest = $null
                    producers = @()
                    totals = [ordered]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 1; durationMs = 0; failedSpecs = 1 }
                    perArtifact = @()
                    perSpec = @()
                    equivalence = @()
                    phaseTimings = @()
                    fanInStatus = 'contract-failure'
                }) -Path $OutputPath
        }
        Write-EvalFanInJson -Value ([ordered]@{ schemaVersion = '1.0.0'; status = 'fail'; category = 'contract' }) -Path $StatusPath
        Write-Error -ErrorAction Continue "Merge-EvalExecution failed: $($_.Exception.Message)"
        exit 2
    }
}