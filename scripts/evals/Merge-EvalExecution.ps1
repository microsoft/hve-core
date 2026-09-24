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
.PARAMETER AcceptanceManifestPath
    Optional changed-spec manifest containing the sealed acceptance contract.
.PARAMETER CalibrationPath
    Safe real-judge calibration results for the same sealed contract.
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
    [string]$StatusPath,
    [string]$AcceptanceManifestPath,
    [string]$CalibrationPath
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
        $trialWeight = 0
        foreach ($spec in @($summaryItem.perSpec)) {
            if (-not $spec.PSObject.Properties['diagnostics'] -or $null -eq $spec.diagnostics) { throw "Producer '$($shard.id)' has an invalid diagnostic contract." }
            $inventory = $spec.diagnostics.expectedStimuli
            $entries = if ($inventory -is [System.Collections.IDictionary]) { @($inventory.Values) }
            else { @($inventory.PSObject.Properties | ForEach-Object Value) }
            foreach ($entry in $entries) { $trialWeight += [int]$entry.runs }
        }
        if ($trialWeight -ne [int]$shard.expectedTrialWeight) { throw "Shard '$($shard.id)' configured trial population differs from the canonical plan." }
    }

    $totals = [ordered]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 0; durationMs = 0; failedSpecs = 0 }
    $perArtifact = [System.Collections.Generic.List[object]]::new()
    $perSpec = [System.Collections.Generic.List[object]]::new()
    $equivalence = [System.Collections.Generic.List[object]]::new()
    $phaseTimings = [System.Collections.Generic.List[object]]::new()
    foreach ($producer in @($expectedFanIn | Sort-Object)) {
        $summaryItem = $byProducer[$producer]
        $integrityFailures = 0
        if ($producer -cne 'equivalence') {
            foreach ($spec in @($summaryItem.perSpec)) {
                $runKey = [string]$spec.specPath
                if (-not [string]::IsNullOrWhiteSpace([string]$spec.tag)) { $runKey = "$runKey|$($spec.tag)" }
                $diagnostics = if ($spec.PSObject.Properties['diagnostics']) { $spec.diagnostics } else { $null }
                $evidence = Test-VallyDiagnosticEvidence -Diagnostics $diagnostics -RunKey $runKey
                if (-not $evidence.contractValid) { throw "Producer '$producer' has an invalid diagnostic contract." }
                $spec | Add-Member -NotePropertyName integrity -NotePropertyValue $evidence -Force
                if (-not $evidence.integrityPassed) {
                    $integrityFailures++
                    $spec | Add-Member -NotePropertyName status -NotePropertyValue 'integrity-failure' -Force
                    $spec | Add-Member -NotePropertyName isAdvisory -NotePropertyValue $false -Force
                }
            }
        }
        foreach ($name in @($totals.Keys)) { $totals[$name] += [int]$summaryItem.totals.$name }
        $totals.failedSpecs += [Math]::Max(0, $integrityFailures - [int]$summaryItem.totals.failedSpecs)
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

function Test-EvalAcceptanceValue {
    <#
    .SYNOPSIS
    Checks first-attempt acceptance separately from ordinary aggregate scoring.
    .PARAMETER Summary
    Validated ordinary merged summary.
    .PARAMETER Acceptance
    Sealed manifest acceptance contract.
    .PARAMETER Calibration
    Safe calibration evidence from the same checkout and profile.
    .OUTPUTS
    Bounded acceptance verdict and categorical issues.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory = $true)]$Summary,
        [Parameter(Mandatory = $true)]$Acceptance,
        [AllowNull()]$Calibration
    )
    $issues = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $requiredScenarios = 0
    $requiredTrials = 0
    try {
        $contract = $Acceptance | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
        $inventory = $contract.inventory
        if ($inventory.schemaVersion -cne '1.0.0' -or @($inventory.selections).Count -eq 0 -or
            $contract.checkout -cnotmatch '^[a-f0-9]{40}$' -or $contract.inputDigest -cnotmatch '^sha256:[a-f0-9]{64}$') {
            throw 'Invalid sealed acceptance contract.'
        }
        foreach ($selection in $inventory.selections) {
            $requiredScenarios += $selection.requiredStimuli.Count
            foreach ($required in $selection.requiredStimuli.Values) { $requiredTrials += [int]$required.runs }
            $matching = @($Summary.perSpec | Where-Object { $_.specPath -ceq $selection.specPath -and [string]$_.tag -ceq [string]$selection.tag })
            if ($matching.Count -ne 1) { [void]$issues.Add('required-selection-missing-or-duplicate'); continue }
            $diagnostics = $matching[0].diagnostics | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100
            $valid = Test-VallyDiagnosticEvidence -Diagnostics $diagnostics
            if (-not $valid.contractValid -or -not $valid.integrityPassed) { [void]$issues.Add('invalid-trial-evidence') }
            if ($diagnostics.checkout -cne $contract.checkout -or $diagnostics.inputDigest -cne $contract.inputDigest -or
                $diagnostics.specDigest -cne $selection.specDigest -or $diagnostics.selectionDigest -cne $selection.selectionDigest -or
                $diagnostics.executorModel -cne $inventory.executorModel -or
                $diagnostics.versions.vally -cne $inventory.vallyVersion -or $diagnostics.versions['vally-cli'] -cne $inventory.vallyVersion -or
                @($diagnostics.judgeModels | Where-Object { $_ -cne $inventory.judgeModel }).Count -gt 0 -or
                $diagnostics.threshold -ne $selection.threshold) { [void]$issues.Add('source-or-configuration-mismatch') }
            if (@($diagnostics.attempts).Count -ne 1 -or $diagnostics.selectedAttempt -ne 1 -or $diagnostics.attempts[0].ordinal -ne 1) {
                [void]$issues.Add('not-clean-first-attempt')
            }
            if (-not $valid.allChecksPassed) { [void]$issues.Add('required-check-failed') }
            foreach ($name in $selection.requiredStimuli.Keys) {
                if (-not $diagnostics.expectedStimuli.Contains($name) -or
                    (Get-AgentEvalValueDigest $diagnostics.expectedStimuli[$name]) -cne (Get-AgentEvalValueDigest $selection.requiredStimuli[$name])) {
                    [void]$issues.Add('required-grader-inventory-mismatch')
                }
            }
        }
        if ($null -eq $Calibration) { [void]$issues.Add('calibration-missing') }
        else {
            $result = $Calibration | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable -Depth 50
            $allowed = @('schemaVersion', 'profileDigest', 'checkout', 'inputDigest', 'judgeModel', 'vallyVersion', 'controls')
            if (@($result.Keys | Where-Object { $_ -cnotin $allowed }).Count -or @($allowed | Where-Object { -not $result.Contains($_) }).Count -or
                $result.schemaVersion -cne '1.0.0' -or $result.profileDigest -cne $inventory.profileDigest -or
                $result.checkout -cne $contract.checkout -or $result.inputDigest -cne $contract.inputDigest -or
                $result.judgeModel -cne $inventory.judgeModel -or $result.vallyVersion -cne $inventory.vallyVersion -or
                @($result.controls).Count -ne @($inventory.calibration).Count) { [void]$issues.Add('calibration-contract-mismatch') }
            foreach ($expected in $inventory.calibration) {
                $observed = @($result.controls | Where-Object { $_.id -ceq $expected.id })
                if ($observed.Count -ne 1) { [void]$issues.Add('calibration-control-missing-or-duplicate'); continue }
                $control = $observed[0]
                $controlAllowed = @('id', 'status', 'passed', 'score', 'criteria')
                if (@($control.Keys | Where-Object { $_ -cnotin $controlAllowed }).Count -or
                    @($controlAllowed | Where-Object { -not $control.Contains($_) }).Count -or
                    $control.status -cne 'success' -or $control.passed -isnot [bool] -or $control.passed -ne $expected.expectedPass -or
                    $control.score -isnot [ValueType] -or $control.score -is [bool] -or
                    -not [double]::IsFinite([double]$control.score) -or $control.score -lt 0 -or $control.score -gt 1) {
                    [void]$issues.Add('calibration-control-failed')
                }
                if (@($control.criteria).Count -eq 0) { [void]$issues.Add('calibration-criteria-missing') }
                $criterionIndex = 0
                foreach ($criterion in $control.criteria) {
                    if (@($criterion.Keys | Where-Object { $_ -cnotin @('index', 'passed', 'score') }).Count -or
                        $criterion.index -ne $criterionIndex -or $criterion.passed -isnot [bool] -or
                        $criterion.score -isnot [ValueType] -or $criterion.score -is [bool] -or
                        -not [double]::IsFinite([double]$criterion.score) -or $criterion.score -lt 0 -or $criterion.score -gt 1) {
                        [void]$issues.Add('calibration-criteria-invalid')
                    }
                    $criterionIndex++
                }
            }
        }
    }
    catch { [void]$issues.Add('invalid-acceptance-contract') }
    return [ordered]@{ passed = ($issues.Count -eq 0); requiredScenarios = $requiredScenarios; requiredTrials = $requiredTrials; issues = @($issues | Sort-Object) }
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
        $acceptanceFailed = $false
        if (-not [string]::IsNullOrWhiteSpace($AcceptanceManifestPath)) {
            if ((Get-AgentEvalFileDigest -Path $AcceptanceManifestPath) -cne $plan.manifestDigests.changedSpecs) { throw 'Acceptance manifest digest mismatch.' }
            $manifest = Get-Content -LiteralPath $AcceptanceManifestPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 100
            if (-not $manifest.PSObject.Properties['acceptance']) { throw 'Acceptance manifest omits the sealed contract.' }
            $calibration = if ($CalibrationPath -and (Test-Path -LiteralPath $CalibrationPath)) { Get-Content -LiteralPath $CalibrationPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 50 } else { $null }
            $merged.acceptance = Test-EvalAcceptanceValue -Summary $merged -Acceptance $manifest.acceptance -Calibration $calibration
            $acceptanceFailed = -not $merged.acceptance.passed
        }
        Write-EvalFanInJson -Value $merged -Path $OutputPath
        Write-Host "Merged eval execution: producers=$($merged.producers.Count) failedSpecs=$($merged.totals.failedSpecs)"
        if ($merged.totals.failedSpecs -gt 0 -or $acceptanceFailed) {
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