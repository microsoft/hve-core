#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Merges isolated baseline-equivalence model summaries.
.DESCRIPTION
    Validates exactly one current-run evidence envelope for each fixed calibration
    model, reconstructs the existing combined schema-2 summary, and writes an eval
    summary fragment for the PR report. Missing, duplicate, stale, incompatible, or
    non-passing evidence fails closed.
.PARAMETER EnvelopePath
    Paths to the per-model evidence envelopes. Exactly two are required unless
    NotRequired is set.
.PARAMETER EnvelopeDirectory
    Directory searched recursively for per-model evidence envelopes. This avoids
    ambiguous array binding when the script is invoked through a nested pwsh process.
.PARAMETER ExpectedWorkflowRunId
    Expected GitHub Actions workflow run identifier.
.PARAMETER ExpectedWorkflowRunAttempt
    Expected GitHub Actions workflow attempt number.
.PARAMETER ExpectedHeadSha
    Expected 40-character pull-request head commit SHA.
.PARAMETER ExpectedAgent
    Expected agent slug. Defaults to rpi-agent.
.PARAMETER ExpectedTier
    Expected equivalence tier. Defaults to calibration.
.PARAMETER PlanPath
    Optional canonical agent eval plan. When supplied, it must require baseline
    equivalence and each envelope must carry its matching plan digest.
.PARAMETER OutputPath
    Destination for the combined baseline-equivalence summary.
.PARAMETER EvalSummaryPath
    Destination for the eval-report summary fragment.
.PARAMETER StatusPath
    Destination for a bounded merge status used to distinguish evidence failures
    from infrastructure and contract failures.
.PARAMETER NotRequired
    Writes explicit empty not-required summaries without reading model envelopes.
.EXAMPLE
    ./Merge-BaselineEquivalence.ps1 -EnvelopePath logs/model-*.json `
        -ExpectedWorkflowRunId 123 -ExpectedWorkflowRunAttempt 1 `
        -ExpectedHeadSha 0123456789012345678901234567890123456789 `
        -OutputPath logs/baseline-equivalence-rpi-agent.json `
        -EvalSummaryPath logs/eval-summary.json
.NOTES
    Runs from the authoritative baseline-equivalence fan-in job.
#>
[CmdletBinding()]
param(
    [string[]]$EnvelopePath = @(),
    [string]$EnvelopeDirectory,
    [string]$ExpectedWorkflowRunId,
    [int]$ExpectedWorkflowRunAttempt,
    [string]$ExpectedHeadSha,
    [string]$ExpectedAgent = 'rpi-agent',
    [string]$ExpectedTier = 'calibration',
    [string]$PlanPath,
    [string]$OutputPath,
    [string]$EvalSummaryPath,
    [string]$StatusPath,
    [switch]$NotRequired
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'lib/EquivalenceParsing.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/VallyRunner.psm1') -Force

#region Functions
function Write-JsonDocument {
    <#
    .SYNOPSIS
        Writes one JSON document, creating its parent directory when needed.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path -LiteralPath $directory)) {
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
    }
    $Value | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

function Assert-Property {
    <#
    .SYNOPSIS
        Returns a required object property or fails the evidence contract.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)][psobject]$InputObject,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)][string]$Context
    )

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $property -or $null -eq $property.Value) {
        throw "$Context omits required field '$Name'."
    }
    return $property.Value
}

function Read-ModelEnvelope {
    <#
    .SYNOPSIS
        Reads and validates one current-run model evidence envelope.
    #>
    [CmdletBinding()]
    [OutputType([psobject])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$WorkflowRunId,
        [Parameter(Mandatory = $true)][int]$WorkflowRunAttempt,
        [Parameter(Mandatory = $true)][string]$HeadSha,
        [Parameter(Mandatory = $true)][string]$Agent,
        [Parameter(Mandatory = $true)][string]$Tier,
        [string]$ExpectedPlanDigest
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Model envelope not found: $Path"
    }
    try {
        $envelope = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100 -ErrorAction Stop
    }
    catch {
        throw "Model envelope is unreadable: $Path"
    }

    $context = "Model envelope '$Path'"
    $envelopeVersion = [string](Assert-Property -InputObject $envelope -Name 'envelopeSchemaVersion' -Context $context)
    if (($envelopeVersion -split '\.')[0] -ne '1') { throw "$context has unsupported envelope schema '$envelopeVersion'." }

    $expectedIdentity = [ordered]@{
        workflowRunId      = $WorkflowRunId
        workflowRunAttempt = $WorkflowRunAttempt
        headSha            = $HeadSha
        agent              = $Agent
        tier               = $Tier
    }
    foreach ($name in $expectedIdentity.Keys) {
        $observed = Assert-Property -InputObject $envelope -Name $name -Context $context
        if ([string]$observed -cne [string]$expectedIdentity[$name]) {
            throw "$context has $name '$observed'; expected '$($expectedIdentity[$name])'."
        }
    }

    $selectedModel = [string](Assert-Property -InputObject $envelope -Name 'selectedModel' -Context $context)
    if ($selectedModel -notin @('gpt-5.6-luna', 'claude-sonnet-5')) {
        throw "$context has unexpected selectedModel '$selectedModel'."
    }
    $driverRunId = [string](Assert-Property -InputObject $envelope -Name 'driverRunId' -Context $context)
    if ([string]::IsNullOrWhiteSpace($driverRunId)) { throw "$context has an empty driverRunId." }
    $producerExitCode = [int](Assert-Property -InputObject $envelope -Name 'producerExitCode' -Context $context)
    if (-not [string]::IsNullOrWhiteSpace($ExpectedPlanDigest)) {
        $planDigest = [string](Assert-Property -InputObject $envelope -Name 'planDigest' -Context $context)
        if ($planDigest -cne $ExpectedPlanDigest) { throw "$context has a mismatched planDigest." }
    }

    $summary = Assert-Property -InputObject $envelope -Name 'summary' -Context $context
    $summaryVersion = [string](Assert-Property -InputObject $summary -Name 'schemaVersion' -Context "$context summary")
    if (($summaryVersion -split '\.')[0] -ne '2') { throw "$context summary has unsupported schema '$summaryVersion'." }

    foreach ($name in @(
            'runId', 'agent', 'tier', 'model', 'runs', 'ties', 'baselineWins', 'treatmentWins',
            'meanScore', 'ciLow', 'ciHigh', 'winRate', 'invariantFailures',
            'runHealthFailures', 'invocationFailures', 'divergenceGuardFailures',
            'divergenceGuardsEvaluated', 'dataQualityViolations', 'judgeErrors',
            'equivalentTrials', 'equivalentTies', 'divergenceTrials', 'comparisonCalibration',
            'comparisonStatus', 'equivalenceGate', 'documentedDivergenceGate', 'verdict',
            'executionDiagnostics', 'invocationEvidence', 'failedDivergenceGuards',
            'dataQualityDiagnostics', 'variants', 'compareLogs')) {
        $null = Assert-Property -InputObject $summary -Name $name -Context "$context summary"
    }

    if ([string]$summary.agent -cne $Agent -or [string]$summary.tier -cne $Tier -or [string]$summary.model -cne $selectedModel) {
        throw "$context summary identity does not match its envelope."
    }
    if ([string]$summary.runId -cne $driverRunId) { throw "$context summary runId does not match its envelope." }
    $summaryPassed = [string]$summary.verdict -eq 'pass' -and [string]$summary.equivalenceGate -eq 'pass'
    if ($producerExitCode -ne 0 -and -not $summaryPassed) {
        throw "EVIDENCE_FAILURE: $context records a non-passing authoritative result."
    }
    if ($producerExitCode -ne 0 -or -not $summaryPassed) {
        throw "$context has inconsistent producer exit and summary verdict evidence."
    }

    return $envelope
}

function Merge-ModelSummaries {
    <#
    .SYNOPSIS
        Reconstructs the serial fixed-pair summary from validated model envelopes.
    #>
    [CmdletBinding()]
    [OutputType([ordered])]
    param(
        [Parameter(Mandatory = $true)][psobject[]]$Envelope
    )

    $orderedEnvelopes = @($Envelope | Sort-Object { if ($_.selectedModel -eq 'gpt-5.6-luna') { 0 } else { 1 } })
    return Merge-BaselineModelSummary `
        -Summary @($orderedEnvelopes | ForEach-Object { $_.summary }) `
        -DriverRunId @($orderedEnvelopes.driverRunId)
}

function New-EvalSummaryFragment {
    <#
    .SYNOPSIS
        Creates the report-compatible combined or not-required summary fragment.
    #>
    [CmdletBinding()]
    [OutputType([ordered])]
    param(
        [psobject]$Summary,
        [switch]$NotRequired
    )

    if ($NotRequired) {
        return [ordered]@{
            manifestPath = $null
            evalRoot = $null
            model = $null
            kindFilter = @('equivalence')
            totals = [ordered]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 0; durationMs = 0; failedSpecs = 0 }
            perArtifact = @()
            perSpec = @()
            equivalence = @()
            equivalenceStatus = 'not-required'
        }
    }

    $authoritativeFailures = [int]$Summary.invariantFailures + [int]$Summary.runHealthFailures + [int]$Summary.dataQualityViolations
    $entry = [ordered]@{
        agent = $Summary.agent
        tier = $Summary.tier
        verdict = $Summary.verdict
        equivalenceGate = $Summary.equivalenceGate
        documentedDivergenceGate = $Summary.documentedDivergenceGate
        exitCode = 0
        trials = $Summary.runs
        assertionsPassed = [math]::Max(0, [int]$Summary.runs - $authoritativeFailures)
        assertionsFailed = $authoritativeFailures
        advisoryAssertionsFailed = [int]$Summary.divergenceGuardFailures
        invariantFailures = [int]$Summary.invariantFailures
        runHealthFailures = [int]$Summary.runHealthFailures
        divergenceGuardFailures = [int]$Summary.divergenceGuardFailures
        dataQualityViolations = [int]$Summary.dataQualityViolations
        invocationFailures = [int]$Summary.invocationFailures
        resultsPath = 'logs/baseline-equivalence-rpi-agent.json'
    }
    return [ordered]@{
        manifestPath = $null
        evalRoot = $null
        model = $Summary.model
        kindFilter = @('equivalence')
        totals = [ordered]@{
            artifacts = 0
            specs = 0
            assertionsPassed = 0
            assertionsFailed = 0
            durationMs = 0
            failedSpecs = if ($entry.verdict -eq 'pass') { 0 } else { 1 }
        }
        perArtifact = @()
        perSpec = @()
        equivalence = @($entry)
        equivalenceStatus = 'complete'
    }
}

function New-FailedEvalSummaryFragment {
    <#
    .SYNOPSIS
        Creates a bounded report fragment for a soft-failed evidence verdict.
    #>
    [CmdletBinding()]
    [OutputType([ordered])]
    param()

    return [ordered]@{
        manifestPath = $null
        evalRoot = $null
        model = 'gpt-5.6-luna'
        kindFilter = @('equivalence')
        totals = [ordered]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 1; durationMs = 0; failedSpecs = 1 }
        perArtifact = @()
        perSpec = @()
        equivalence = @([ordered]@{
                agent = 'rpi-agent'
                tier = 'calibration'
                verdict = 'fail'
                equivalenceGate = 'fail'
                documentedDivergenceGate = 'report-only'
                exitCode = 1
                trials = 0
                assertionsPassed = 0
                assertionsFailed = 1
                advisoryAssertionsFailed = 0
                invariantFailures = 0
                runHealthFailures = 0
                divergenceGuardFailures = 0
                dataQualityViolations = 1
                invocationFailures = 0
                resultsPath = 'logs/baseline-equivalence-rpi-agent.json'
            })
        equivalenceStatus = 'failed-evidence'
    }
}
#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        if ([string]::IsNullOrWhiteSpace($OutputPath) -or [string]::IsNullOrWhiteSpace($EvalSummaryPath)) {
            throw 'OutputPath and EvalSummaryPath are required.'
        }
        if ([string]::IsNullOrWhiteSpace($StatusPath)) {
            $StatusPath = Join-Path (Split-Path -Parent $EvalSummaryPath) 'merge-status.json'
        }
        if ($NotRequired) {
            Write-JsonDocument -Value ([ordered]@{ schemaVersion = '2.1.0'; agent = $ExpectedAgent; tier = $ExpectedTier; status = 'not-required'; runs = 0; verdict = 'not-required' }) -Path $OutputPath
            Write-JsonDocument -Value (New-EvalSummaryFragment -NotRequired) -Path $EvalSummaryPath
            Write-JsonDocument -Value ([ordered]@{ schemaVersion = '1.0.0'; status = 'not-required'; category = 'none' }) -Path $StatusPath
            Write-Host "Baseline equivalence is not required; empty reporting fragment written."
            exit 0
        }

        if ([string]::IsNullOrWhiteSpace($ExpectedWorkflowRunId) -or
            $ExpectedWorkflowRunAttempt -le 0 -or
            $ExpectedHeadSha -notmatch '^[0-9a-f]{40}$') {
            throw 'Expected workflow run, attempt, and 40-character lowercase head SHA are required.'
        }
        if (-not [string]::IsNullOrWhiteSpace($EnvelopeDirectory)) {
            if (-not (Test-Path -LiteralPath $EnvelopeDirectory -PathType Container)) {
                throw "Model envelope directory not found: $EnvelopeDirectory"
            }
            $EnvelopePath = @(Get-ChildItem -LiteralPath $EnvelopeDirectory -Filter 'model-evidence-*.json' -Recurse -File | Select-Object -ExpandProperty FullName)
        }
        if ($EnvelopePath.Count -ne 2) { throw "Expected exactly two model envelopes; found $($EnvelopePath.Count)." }

        $expectedPlanDigest = $null
        if (-not [string]::IsNullOrWhiteSpace($PlanPath)) {
            $plan = Get-Content -LiteralPath $PlanPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 50 -ErrorAction Stop
            if (-not (Test-AgentEvalPlanDigest -Plan $plan) -or -not [bool]$plan.baseline.required) {
                throw 'Canonical agent eval plan is invalid or does not require baseline equivalence.'
            }
            $expectedPlanDigest = [string]$plan.planDigest
        }

        $envelopes = @(
            foreach ($path in $EnvelopePath) {
                Read-ModelEnvelope `
                    -Path $path `
                    -WorkflowRunId $ExpectedWorkflowRunId `
                    -WorkflowRunAttempt $ExpectedWorkflowRunAttempt `
                    -HeadSha $ExpectedHeadSha `
                    -Agent $ExpectedAgent `
                    -Tier $ExpectedTier `
                    -ExpectedPlanDigest $expectedPlanDigest
            }
        )
        $models = @($envelopes.selectedModel | Sort-Object -Unique)
        if ($models.Count -ne 2 -or $models[0] -ne 'claude-sonnet-5' -or $models[1] -ne 'gpt-5.6-luna') {
            throw "Expected exactly one envelope for each fixed model; found '$($models -join ',')'."
        }

        $combined = Merge-ModelSummaries -Envelope $envelopes
        if ($combined.verdict -ne 'pass') { throw "Combined equivalence verdict is '$($combined.verdict)'." }
        Write-JsonDocument -Value $combined -Path $OutputPath
        Write-JsonDocument -Value (New-EvalSummaryFragment -Summary $combined) -Path $EvalSummaryPath
        Write-JsonDocument -Value ([ordered]@{ schemaVersion = '1.0.0'; status = 'pass'; category = 'none' }) -Path $StatusPath
        Write-Host "Merged baseline equivalence: models=$($models -join ',') runs=$($combined.runs) verdict=$($combined.verdict)"
        exit 0
    }
    catch {
        $category = if ($_.Exception.Message -like 'EVIDENCE_FAILURE:*') { 'evidence' } else { 'contract' }
        if (-not [string]::IsNullOrWhiteSpace($StatusPath)) {
            Write-JsonDocument -Value ([ordered]@{ schemaVersion = '1.0.0'; status = 'fail'; category = $category }) -Path $StatusPath
        }
        if ($category -eq 'evidence' -and -not [string]::IsNullOrWhiteSpace($EvalSummaryPath)) {
            Write-JsonDocument -Value (New-FailedEvalSummaryFragment) -Path $EvalSummaryPath
        }
        Write-Error -ErrorAction Continue "Merge-BaselineEquivalence failed: $($_.Exception.Message)"
        exit 1
    }
}
#endregion Main Execution
