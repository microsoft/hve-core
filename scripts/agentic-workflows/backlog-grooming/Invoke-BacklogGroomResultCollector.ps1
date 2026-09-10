#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Collects candidate-addressed backlog grooming calls into one shard result.
.DESCRIPTION
    Reads normalized GH_AW_AGENT_OUTPUT, validates trusted shard context through
    the backlog grooming module, and writes the immutable v2 shard result.
.PARAMETER AgentOutputPath
    Path to normalized GH_AW_AGENT_OUTPUT JSON.
.PARAMETER ShardId
    Stable shard identifier from the orchestrator manifest.
.PARAMETER ManifestDigest
    SHA-256 digest of the canonical orchestrator manifest.
.PARAMETER OrderedCandidateIdsJson
    JSON array of issue numbers assigned to the shard.
.PARAMETER PriorityCandidateIdsJson
    JSON array of priority cohort issue numbers.
.PARAMETER RoundRobinCandidateIdsJson
    JSON array of round-robin cohort issue numbers.
.PARAMETER TotalOpenInventoryText
    Complete open non-pull-request inventory count.
.PARAMETER PriorCursorText
    Cursor immediately before the planned cohort.
.PARAMETER OrchestratorRunId
    Run identifier of the calling orchestrator.
.PARAMETER OrchestratorAttemptText
    Run attempt of the calling orchestrator.
.PARAMETER OutputPath
    Destination for the immutable shard result.
.EXAMPLE
    ./scripts/agentic-workflows/backlog-grooming/Invoke-BacklogGroomResultCollector.ps1
.NOTES
    Called by .github/workflows/backlog-groom.md.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$AgentOutputPath = $env:GH_AW_AGENT_OUTPUT,

    [Parameter(Mandatory = $false)]
    [string]$ShardId = $env:SHARD_ID,

    [Parameter(Mandatory = $false)]
    [string]$ManifestDigest = $env:MANIFEST_DIGEST,

    [Parameter(Mandatory = $false)]
    [string]$OrderedCandidateIdsJson = $env:ORDERED_CANDIDATE_IDS,

    [Parameter(Mandatory = $false)]
    [string]$PriorityCandidateIdsJson = $env:PRIORITY_CANDIDATE_IDS,

    [Parameter(Mandatory = $false)]
    [string]$RoundRobinCandidateIdsJson = $env:ROUND_ROBIN_CANDIDATE_IDS,

    [Parameter(Mandatory = $false)]
    [string]$TotalOpenInventoryText = $env:TOTAL_OPEN_INVENTORY,

    [Parameter(Mandatory = $false)]
    [string]$PriorCursorText = $env:PRIOR_CURSOR,

    [Parameter(Mandatory = $false)]
    [string]$OrchestratorRunId = $env:ORCHESTRATOR_RUN_ID,

    [Parameter(Mandatory = $false)]
    [string]$OrchestratorAttemptText = $env:ORCHESTRATOR_ATTEMPT,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path (Get-Location) 'result-output/shard-result.json')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/BacklogGrooming.psm1') -Force

#region Functions
<#
.SYNOPSIS
    Reads normalized agent output and writes one canonical shard result.
.PARAMETER AgentOutputPath
    Path to normalized GH_AW_AGENT_OUTPUT JSON.
.PARAMETER ShardId
    Stable shard identifier.
.PARAMETER ManifestDigest
    Canonical manifest SHA-256 digest.
.PARAMETER OrderedCandidateIdsJson
    Ordered candidate issue IDs as JSON.
.PARAMETER PriorityCandidateIdsJson
    Priority cohort issue IDs as JSON.
.PARAMETER RoundRobinCandidateIdsJson
    Round-robin cohort issue IDs as JSON.
.PARAMETER TotalOpenInventoryText
    Complete open inventory count as decimal text.
.PARAMETER PriorCursorText
    Prior cursor as decimal text.
.PARAMETER OrchestratorRunId
    Producing orchestrator run ID.
.PARAMETER OrchestratorAttemptText
    Producing orchestrator attempt as decimal text.
.PARAMETER OutputPath
    Destination shard result path.
.OUTPUTS
    System.String
#>
function Invoke-BacklogGroomResultCollection {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$AgentOutputPath,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$ShardId,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$ManifestDigest,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$OrderedCandidateIdsJson,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$PriorityCandidateIdsJson,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$RoundRobinCandidateIdsJson,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$TotalOpenInventoryText,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$PriorCursorText,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$OrchestratorRunId,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$OrchestratorAttemptText,
        [Parameter(Mandatory = $true)] [ValidateNotNullOrEmpty()] [string]$OutputPath
    )

    if (-not (Test-Path -LiteralPath $AgentOutputPath -PathType Leaf)) {
        throw 'Normalized agent output file was not found'
    }
    $StartedAt = [datetimeoffset]::UtcNow
    $AgentOutputDocument = [System.Text.Json.JsonDocument]::Parse(
        [System.IO.File]::ReadAllText($AgentOutputPath)
    )
    try {
        $AgentOutput = $AgentOutputDocument.RootElement.Clone()
    }
    finally {
        $AgentOutputDocument.Dispose()
    }

    $Result = ConvertTo-BacklogGroomingShardResult -AgentOutput $AgentOutput -ShardId $ShardId `
        -ManifestDigest $ManifestDigest -OrderedCandidateIdsJson $OrderedCandidateIdsJson `
        -PriorityCandidateIdsJson $PriorityCandidateIdsJson `
        -RoundRobinCandidateIdsJson $RoundRobinCandidateIdsJson `
        -TotalOpenInventoryText $TotalOpenInventoryText -PriorCursorText $PriorCursorText `
        -OrchestratorRunId $OrchestratorRunId -OrchestratorAttemptText $OrchestratorAttemptText `
        -StartedAt $StartedAt

    $OutputDirectory = Split-Path -Parent $OutputPath
    if (-not [string]::IsNullOrEmpty($OutputDirectory)) {
        $null = [System.IO.Directory]::CreateDirectory($OutputDirectory)
    }
    $Json = $Result | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText($OutputPath, $Json + "`n", [System.Text.UTF8Encoding]::new($false))
    return $OutputPath
}
#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $WrittenPath = Invoke-BacklogGroomResultCollection @PSBoundParameters
        Write-Information "Backlog grooming shard result written to $WrittenPath" -InformationAction Continue
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Backlog grooming result collection failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution