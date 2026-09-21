#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../evals/Merge-EvalExecution.ps1')
    function New-FanInPlan {
        $plan = [pscustomobject][ordered]@{
            schemaVersion = '1.1.0'
            manifestDigests = [pscustomobject][ordered]@{ changedArtifacts = 'sha256:a'; changedSpecs = 'sha256:b' }
            planDigest = ''
            baseline = [pscustomobject][ordered]@{ required = $false; reason = 'agent-not-affected:rpi-agent'; models = @() }
            ordinaryShards = @(
                [pscustomobject][ordered]@{ id = 'ordinary-01'; kind = 'agent'; expectedTrialWeight = 1; artifacts = @('agent:alpha'); runKeys = @('alpha.yaml') }
                [pscustomobject][ordered]@{ id = 'instruction-01'; kind = 'instruction'; expectedTrialWeight = 1; artifacts = @('instruction:beta'); runKeys = @('instructions.yaml|instruction=beta') }
                [pscustomobject][ordered]@{ id = 'skill-01'; kind = 'skill'; expectedTrialWeight = 0; artifacts = @(); runKeys = @() }
            )
            expectedProducers = @('ordinary-01', 'instruction-01', 'skill-01', 'prompt')
        }
        $payload = [ordered]@{ schemaVersion = $plan.schemaVersion; manifestDigests = [ordered]@{ changedArtifacts = $plan.manifestDigests.changedArtifacts; changedSpecs = $plan.manifestDigests.changedSpecs }; baseline = [ordered]@{ required = $false; reason = $plan.baseline.reason; models = @() }; ordinaryShards = @($plan.ordinaryShards); expectedProducers = @($plan.expectedProducers) }
        $plan.planDigest = Get-AgentEvalValueDigest -Value $payload
        return $plan
    }
    function New-FanInSummary([string]$Producer, [string]$Kind = '', [string]$PlanDigest = $null) {
        return [pscustomobject][ordered]@{
            producer = $Producer
            planDigest = $PlanDigest
            manifestDigests = [pscustomobject][ordered]@{ changedArtifacts = 'sha256:a'; changedSpecs = 'sha256:b' }
            kindFilter = if ([string]::IsNullOrWhiteSpace($Kind)) { @() } else { @($Kind) }
            totals = [pscustomobject]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 0; durationMs = 0; failedSpecs = 0 }
            perArtifact = @()
            perSpec = @()
            equivalence = @()
            phaseTimings = @()
        }
    }
    function New-ValidFanInSummary([psobject]$Plan) {
        $agent = New-FanInSummary 'ordinary-01' 'agent' $Plan.planDigest
        $agent.totals = [pscustomobject]@{ artifacts = 1; specs = 1; assertionsPassed = 2; assertionsFailed = 0; durationMs = 10; failedSpecs = 0 }
        $agent.perArtifact = @([pscustomobject]@{ kind = 'agent'; artifactId = 'alpha' })
        $agent.perSpec = @([pscustomobject]@{ specPath = 'alpha.yaml'; tag = '' })
        $instruction = New-FanInSummary 'instruction-01' 'instruction' $Plan.planDigest
        $instruction.totals = [pscustomobject]@{ artifacts = 1; specs = 1; assertionsPassed = 1; assertionsFailed = 0; durationMs = 5; failedSpecs = 0 }
        $instruction.perArtifact = @([pscustomobject]@{ kind = 'instruction'; artifactId = 'beta' })
        $instruction.perSpec = @([pscustomobject]@{ specPath = 'instructions.yaml'; tag = 'instruction=beta' })
        return @($agent, $instruction, (New-FanInSummary 'skill-01' 'skill' $Plan.planDigest), (New-FanInSummary prompt))
    }
}

Describe 'Merge-EvalExecution.ps1' -Tag 'Unit' {
    It 'merges the exact planned producer set in canonical order' {
        $plan = New-FanInPlan
        $result = Merge-EvalSummaryValue -Plan $plan -Summary (New-ValidFanInSummary -Plan $plan)
        $result.totals.artifacts | Should -Be 2
        @($result.producers) | Should -Be @('instruction-01', 'ordinary-01', 'prompt', 'skill-01')
    }
    It 'merges the prompt producer when the plan has no planned shards' {
        $plan = New-FanInPlan
        $plan.ordinaryShards = @()
        $plan.expectedProducers = @('prompt')
        $payload = [ordered]@{ schemaVersion = $plan.schemaVersion; manifestDigests = [ordered]@{ changedArtifacts = $plan.manifestDigests.changedArtifacts; changedSpecs = $plan.manifestDigests.changedSpecs }; baseline = [ordered]@{ required = $false; reason = $plan.baseline.reason; models = @() }; ordinaryShards = @(); expectedProducers = @($plan.expectedProducers) }
        $plan.planDigest = Get-AgentEvalValueDigest -Value $payload

        $result = Merge-EvalSummaryValue -Plan $plan -Summary @((New-FanInSummary prompt))

        @($result.producers) | Should -Be @('prompt')
    }
    It 'rejects missing producers' {
        $plan = New-FanInPlan
        $ordinary = New-FanInSummary 'ordinary-01' 'agent' $plan.planDigest
        { Merge-EvalSummaryValue -Plan $plan -Summary @($ordinary) } | Should -Throw '*Producer set*'
    }
    It 'rejects duplicate producer evidence' {
        $plan = New-FanInPlan
        { Merge-EvalSummaryValue -Plan $plan -Summary @((New-FanInSummary prompt), (New-FanInSummary prompt)) } | Should -Throw '*Duplicate producer*'
    }
    It 'rejects an incomplete ordinary shard' {
        $plan = New-FanInPlan
        $summaries = @(New-ValidFanInSummary -Plan $plan)
        $summaries[0].perArtifact = @()
        { Merge-EvalSummaryValue -Plan $plan -Summary $summaries } | Should -Throw '*artifact evidence is incomplete*'
    }
    It 'rejects a wrong ordinary plan digest' {
        $plan = New-FanInPlan
        $summaries = @(New-ValidFanInSummary -Plan $plan)
        $summaries[0].planDigest = 'wrong'
        { Merge-EvalSummaryValue -Plan $plan -Summary $summaries } | Should -Throw '*wrong plan digest*'
    }
    It 'rejects a planned target shard with the wrong kind or manifest digests' {
        $plan = New-FanInPlan
        $summaries = @(New-ValidFanInSummary -Plan $plan)
        $summaries[1].kindFilter = @('skill')
        { Merge-EvalSummaryValue -Plan $plan -Summary $summaries } | Should -Throw '*wrong kind*'

        $summaries = @(New-ValidFanInSummary -Plan $plan)
        $summaries[1].manifestDigests.changedSpecs = 'sha256:wrong'
        { Merge-EvalSummaryValue -Plan $plan -Summary $summaries } | Should -Throw '*wrong manifest digests*'
    }

    It 'writes bounded summary and status evidence on contract failure' {
        $planPath = Join-Path $TestDrive 'plan.json'
        $summaryDirectory = Join-Path $TestDrive 'summaries'
        $outputPath = Join-Path $TestDrive 'out/eval-summary.json'
        $statusPath = Join-Path $TestDrive 'out/status.json'
        New-Item -ItemType Directory -Path $summaryDirectory -Force | Out-Null
        New-FanInPlan | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $planPath -Encoding utf8NoBOM

        & (Join-Path $PSScriptRoot '../../evals/Merge-EvalExecution.ps1') `
            -PlanPath $planPath -SummaryDirectory $summaryDirectory `
            -OutputPath $outputPath -StatusPath $statusPath 2>$null

        $LASTEXITCODE | Should -Be 2
        (Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json).fanInStatus | Should -Be 'contract-failure'
        (Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json).category | Should -Be 'contract'
    }

    It 'reports an evidence-category failure when a planned target shard fails specs' {
        $planPath = Join-Path $TestDrive 'evidence-plan.json'
        $summaryDirectory = Join-Path $TestDrive 'evidence-summaries'
        $outputPath = Join-Path $TestDrive 'evidence-out/eval-summary.json'
        $statusPath = Join-Path $TestDrive 'evidence-out/status.json'
        $plan = New-FanInPlan
        New-Item -ItemType Directory -Path $summaryDirectory -Force | Out-Null
        $plan | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $planPath -Encoding utf8NoBOM

        # Ownership, digests, and the producer set stay valid so the run fails on evidence, not contract.
        $summaries = New-ValidFanInSummary $plan
        $failing = @($summaries | Where-Object { $_.producer -eq 'instruction-01' })[0]
        $failing.totals.failedSpecs = 1
        $failing.totals.assertionsFailed = 1
        foreach ($summary in $summaries) {
            $producerDirectory = Join-Path $summaryDirectory ([string]$summary.producer)
            New-Item -ItemType Directory -Path $producerDirectory -Force | Out-Null
            $summary | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath (Join-Path $producerDirectory 'eval-summary.json') -Encoding utf8NoBOM
        }

        & (Join-Path $PSScriptRoot '../../evals/Merge-EvalExecution.ps1') `
            -PlanPath $planPath -SummaryDirectory $summaryDirectory `
            -OutputPath $outputPath -StatusPath $statusPath 2>$null

        $LASTEXITCODE | Should -Be 1
        $status = Get-Content -LiteralPath $statusPath -Raw | ConvertFrom-Json
        $status.status | Should -Be 'fail'
        $status.category | Should -Be 'evidence'
        (Get-Content -LiteralPath $outputPath -Raw | ConvertFrom-Json).totals.failedSpecs | Should -Be 1
    }
}