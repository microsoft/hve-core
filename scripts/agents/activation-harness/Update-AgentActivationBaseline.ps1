#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Regenerates baseline.json for the agent activation harness.

.DESCRIPTION
    Computes activation fingerprints for every canonical scenario
    (CleanWorkspace, SteadyState, GovernEntry, AdoptTemplate) and writes
    the deterministic JSON payload consumed by
    scripts/tests/agents/activation-harness/Test-AdrCreationActivation.Tests.ps1.

    Use this script after intentional changes to the agent body, attached
    instructions, or any file referenced via #file: directives, so the
    drift gate compares against an updated baseline rather than failing
    on expected churn.

    Defaults target the @adr-creation agent. Override -AgentPath and
    -BaselinePath to manage baselines for additional agents.

.PARAMETER AgentPath
    Repo-relative or absolute path to the agent .agent.md file.

.PARAMETER BaselinePath
    Repo-relative or absolute path to the baseline JSON file to write.

.PARAMETER RepoRoot
    Absolute path to the repository root. Defaults to three levels above
    this script.

.PARAMETER DryRun
    Compute the new payload and report drift against the existing baseline,
    but do not write the file. Exits 1 when drift is detected so the
    command can be wired into CI as a staleness gate.

.EXAMPLE
    ./Update-AgentActivationBaseline.ps1

.EXAMPLE
    ./Update-AgentActivationBaseline.ps1 -DryRun

.NOTES
    The fingerprint module already returns ordered hashtables with sorted
    LoadedFiles, so ConvertTo-Json output is deterministic across runs and
    operating systems.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AgentPath = '.github/agents/project-planning/adr-creation.agent.md',

    [Parameter(Mandatory = $false)]
    [string]$BaselinePath = 'scripts/agents/activation-harness/baseline.json',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).Path
}

$modulePath = Join-Path $RepoRoot 'scripts/agents/activation-harness/Get-AgentActivationFingerprint.psm1'
Import-Module -Name $modulePath -Force

$resolvedAgentPath = if ([System.IO.Path]::IsPathRooted($AgentPath)) {
    $AgentPath
} else {
    Join-Path $RepoRoot $AgentPath
}

$resolvedBaselinePath = if ([System.IO.Path]::IsPathRooted($BaselinePath)) {
    $BaselinePath
} else {
    Join-Path $RepoRoot $BaselinePath
}

if (-not (Test-Path -LiteralPath $resolvedAgentPath -PathType Leaf)) {
    throw "Agent file not found: $resolvedAgentPath"
}

$scenarios = @('CleanWorkspace', 'SteadyState', 'GovernEntry', 'AdoptTemplate')

$payload = [ordered]@{}
foreach ($scenario in $scenarios) {
    $payload[$scenario] = Get-AgentActivationFingerprint `
        -AgentPath $resolvedAgentPath `
        -ScenarioName $scenario `
        -RepoRoot $RepoRoot
}

$newJson = (($payload | ConvertTo-Json -Depth 6) -replace "`r`n", "`n") + "`n"

$existingJson = if (Test-Path -LiteralPath $resolvedBaselinePath -PathType Leaf) {
    [System.IO.File]::ReadAllText($resolvedBaselinePath, [System.Text.Encoding]::UTF8) -replace "`r`n", "`n"
} else {
    ''
}

$drift = $newJson -ne $existingJson

if ($drift) {
    Write-Host 'Activation baseline drift detected:' -ForegroundColor Yellow
    foreach ($scenario in $scenarios) {
        $current = $payload[$scenario]
        Write-Host ("  {0,-15} ColdStartBytes={1}  Hash={2}" -f $scenario, $current.ColdStartBytes, $current.Hash)
    }
} else {
    Write-Host 'Activation baseline is up to date.' -ForegroundColor Green
}

if ($DryRun) {
    if ($drift) {
        Write-Host "Dry run: baseline file not written. Re-run without -DryRun to update $BaselinePath." -ForegroundColor Yellow
        exit 1
    }
    exit 0
}

if ($drift) {
    [System.IO.File]::WriteAllText($resolvedBaselinePath, $newJson, [System.Text.UTF8Encoding]::new($false))
    Write-Host "Wrote $BaselinePath" -ForegroundColor Green
}
