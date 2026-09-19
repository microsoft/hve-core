#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    . (Join-Path $PSScriptRoot '../../evals/Merge-EvalExecution.ps1')
    function New-FanInPlan {
        $plan = [pscustomobject][ordered]@{
            schemaVersion = '1.0.0'
            manifestDigests = [pscustomobject][ordered]@{ changedArtifacts = 'sha256:a'; changedSpecs = 'sha256:b' }
            planDigest = ''
            baseline = [pscustomobject][ordered]@{ required = $false; reason = 'agent-not-affected:rpi-agent'; models = @() }
            ordinaryShards = @([pscustomobject][ordered]@{ id = 'ordinary-01'; expectedTrialWeight = 1; artifacts = @('agent:alpha'); runKeys = @('alpha.yaml') })
            expectedProducers = @('ordinary-01', 'prompt', 'instruction', 'skill')
        }
        $payload = [ordered]@{ schemaVersion = $plan.schemaVersion; manifestDigests = [ordered]@{ changedArtifacts = $plan.manifestDigests.changedArtifacts; changedSpecs = $plan.manifestDigests.changedSpecs }; baseline = [ordered]@{ required = $false; reason = $plan.baseline.reason; models = @() }; ordinaryShards = @($plan.ordinaryShards); expectedProducers = @($plan.expectedProducers) }
        $plan.planDigest = Get-AgentEvalValueDigest -Value $payload
        return $plan
    }
    function New-FanInSummary([string]$Producer) {
        return [pscustomobject][ordered]@{ producer = $Producer; planDigest = $null; totals = [pscustomobject]@{ artifacts = 0; specs = 0; assertionsPassed = 0; assertionsFailed = 0; durationMs = 0; failedSpecs = 0 }; perArtifact = @(); perSpec = @(); equivalence = @(); phaseTimings = @() }
    }
}

Describe 'Merge-EvalExecution.ps1' -Tag 'Unit' {
    It 'merges the exact planned producer set in canonical order' {
        $plan = New-FanInPlan
        $ordinary = New-FanInSummary 'ordinary-01'
        $ordinary.planDigest = $plan.planDigest
        $ordinary.totals = [pscustomobject]@{ artifacts = 1; specs = 1; assertionsPassed = 2; assertionsFailed = 0; durationMs = 10; failedSpecs = 0 }
        $ordinary.perArtifact = @([pscustomobject]@{ kind = 'agent'; artifactId = 'alpha' })
        $ordinary.perSpec = @([pscustomobject]@{ specPath = 'alpha.yaml'; tag = '' })
        $result = Merge-EvalSummaryValue -Plan $plan -Summary @($ordinary, (New-FanInSummary prompt), (New-FanInSummary instruction), (New-FanInSummary skill))
        $result.totals.artifacts | Should -Be 1
        @($result.producers) | Should -Be @('instruction', 'ordinary-01', 'prompt', 'skill')
    }
    It 'merges non-agent producers when the plan has no ordinary shards' {
        $plan = New-FanInPlan
        $plan.ordinaryShards = @()
        $plan.expectedProducers = @('prompt', 'instruction', 'skill')
        $payload = [ordered]@{ schemaVersion = $plan.schemaVersion; manifestDigests = [ordered]@{ changedArtifacts = $plan.manifestDigests.changedArtifacts; changedSpecs = $plan.manifestDigests.changedSpecs }; baseline = [ordered]@{ required = $false; reason = $plan.baseline.reason; models = @() }; ordinaryShards = @(); expectedProducers = @($plan.expectedProducers) }
        $plan.planDigest = Get-AgentEvalValueDigest -Value $payload

        $result = Merge-EvalSummaryValue -Plan $plan -Summary @(
            (New-FanInSummary prompt),
            (New-FanInSummary instruction),
            (New-FanInSummary skill)
        )

        @($result.producers) | Should -Be @('instruction', 'prompt', 'skill')
    }
    It 'rejects missing producers' {
        $plan = New-FanInPlan
        $ordinary = New-FanInSummary 'ordinary-01'; $ordinary.planDigest = $plan.planDigest
        { Merge-EvalSummaryValue -Plan $plan -Summary @($ordinary) } | Should -Throw '*Producer set*'
    }
    It 'rejects duplicate producer evidence' {
        $plan = New-FanInPlan
        { Merge-EvalSummaryValue -Plan $plan -Summary @((New-FanInSummary prompt), (New-FanInSummary prompt)) } | Should -Throw '*Duplicate producer*'
    }
    It 'rejects an incomplete ordinary shard' {
        $plan = New-FanInPlan
        $ordinary = New-FanInSummary 'ordinary-01'; $ordinary.planDigest = $plan.planDigest
        { Merge-EvalSummaryValue -Plan $plan -Summary @($ordinary, (New-FanInSummary prompt), (New-FanInSummary instruction), (New-FanInSummary skill)) } | Should -Throw '*artifact evidence is incomplete*'
    }
    It 'rejects a wrong ordinary plan digest' {
        $plan = New-FanInPlan
        $ordinary = New-FanInSummary 'ordinary-01'; $ordinary.planDigest = 'wrong'
        { Merge-EvalSummaryValue -Plan $plan -Summary @($ordinary, (New-FanInSummary prompt), (New-FanInSummary instruction), (New-FanInSummary skill)) } | Should -Throw '*wrong plan digest*'
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
}