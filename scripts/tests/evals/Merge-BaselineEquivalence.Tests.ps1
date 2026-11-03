#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Merge-BaselineEquivalence.ps1'
    . $script:ScriptPath

    function New-TestSummary {
        param(
            [string]$Model,
            [int]$Runs = 105,
            [int]$Ties = 80,
            [int]$BaselineWins = 15,
            [int]$TreatmentWins = 10,
            [double]$MeanScore = -0.05,
            [double]$CiLow = -0.1,
            [double]$CiHigh = 0.01,
            [double]$WinRate = 0.08,
            [int]$DivergenceGuardFailures = 2
        )

        return [ordered]@{
            schemaVersion = '2.2.0'; agent = 'rpi-agent'; tier = 'calibration'; model = $Model
            runs = $Runs; ties = $Ties; baselineWins = $BaselineWins; treatmentWins = $TreatmentWins
            meanScore = $MeanScore; ciLow = $CiLow; ciHigh = $CiHigh; winRate = $WinRate
            invariantFailures = 0; runHealthFailures = 0; executionDiagnostics = @(@{ model = $Model })
            invocationEvidence = @(@{ model = $Model; observed = 105 }); invocationFailures = 0
            divergenceGuardFailures = $DivergenceGuardFailures; divergenceGuardsEvaluated = 15
            failedDivergenceGuards = @("$Model-guard"); dataQualityViolations = 0
            judgeErrors = 0; equivalentTrials = $Runs; equivalentTies = $Ties; divergenceTrials = 0
            comparisonCalibration = @(@{ model = $Model; status = 'report-only' })
            comparisonStatus = 'report-only'; dataQualityDiagnostics = @("$Model-diagnostic")
            equivalenceGate = 'pass'; documentedDivergenceGate = 'report-only'; verdict = 'pass'
            variants = @{ subject = 'rpi-agent' }; compareLogs = @("$Model.log")
            invariantDiagnostics = @{ evaluated = 84; failed = 0; omittedFailureCount = 0; failures = @() }
        }
    }

    function Write-TestEnvelope {
        param(
            [string]$Path,
            [string]$Model,
            [int]$ProducerExitCode = 0,
            [string]$WorkflowRunId = '12345',
            [int]$WorkflowRunAttempt = 1,
            [string]$HeadSha = '0123456789abcdef0123456789abcdef01234567',
            [string]$Agent = 'rpi-agent',
            [string]$Tier = 'calibration',
            [string]$DriverRunId = 'driver-1',
            [psobject]$Summary
        )

        if ($null -eq $Summary) { $Summary = New-TestSummary -Model $Model }
        $Summary.runId = $DriverRunId
        [ordered]@{
            envelopeSchemaVersion = '1.0.0'
            workflowRunId = $WorkflowRunId
            workflowRunAttempt = $WorkflowRunAttempt
            headSha = $HeadSha
            agent = $Agent
            tier = $Tier
            selectedModel = $Model
            driverRunId = $DriverRunId
            producerExitCode = $ProducerExitCode
            summary = $Summary
        } | ConvertTo-Json -Depth 100 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
    }

    function Write-NotRequiredPlan {
        param([string]$Path, [bool]$Required = $false)
        $payload = [ordered]@{
            schemaVersion = '1.1.0'
            manifestDigests = [ordered]@{ changedArtifacts = 'sha256:a'; changedSpecs = 'sha256:b' }
            baseline = [ordered]@{ required = $Required; reason = 'test-plan'; models = @() }
            ordinaryShards = @(); expectedProducers = @('prompt')
        }
        $plan = [ordered]@{}
        foreach ($key in $payload.Keys) { $plan[$key] = $payload[$key] }
        $plan.planDigest = Get-AgentEvalValueDigest -Value $payload
        $plan | ConvertTo-Json -Depth 20 | Set-Content $Path
    }
}

Describe 'Merge-BaselineEquivalence.ps1' -Tag 'Unit' {
    BeforeEach {
        $script:GptPath = Join-Path $TestDrive "gpt-$([guid]::NewGuid()).json"
        $script:ClaudePath = Join-Path $TestDrive "claude-$([guid]::NewGuid()).json"
        $script:OutputPath = Join-Path $TestDrive "combined-$([guid]::NewGuid()).json"
        $script:EvalSummaryPath = Join-Path $TestDrive "eval-$([guid]::NewGuid()).json"
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -DriverRunId 'gpt-run'
        Write-TestEnvelope -Path $script:ClaudePath -Model 'claude-sonnet-5' -DriverRunId 'claude-run' -Summary (New-TestSummary -Model 'claude-sonnet-5' -Ties 81 -BaselineWins 22 -TreatmentWins 2 -MeanScore -0.12 -CiLow -0.11 -CiHigh -0.04 -WinRate 0.03 -DivergenceGuardFailures 5)
    }

    It 'reconstructs the serial two-model summary and reporting fragment' {
        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' `
            -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath `
            -EvalSummaryPath $script:EvalSummaryPath

        $LASTEXITCODE | Should -Be 0
        $combined = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $combined.runs | Should -Be 210
        $combined.ties | Should -Be 161
        $combined.baselineWins | Should -Be 37
        $combined.treatmentWins | Should -Be 12
        $combined.meanScore | Should -Be -0.085
        $combined.ciLow | Should -Be -0.1
        $combined.ciHigh | Should -Be -0.04
        $combined.winRate | Should -Be 0.055
        $combined.divergenceGuardFailures | Should -Be 7
        $combined.equivalenceGate | Should -Be 'pass'
        $combined.documentedDivergenceGate | Should -Be 'report-only'
        $combined.model | Should -Be 'gpt-6-luna'
        @($combined.models) | Should -Be @('gpt-6-luna', 'claude-sonnet-5')
        @($combined.driverRunIds) | Should -Be @('gpt-run', 'claude-run')

        $fragment = Get-Content -LiteralPath $script:EvalSummaryPath -Raw | ConvertFrom-Json
        $fragment.totals.artifacts | Should -Be 0
        $fragment.totals.specs | Should -Be 0
        $fragment.totals.failedSpecs | Should -Be 0
        $fragment.perArtifact | Should -HaveCount 0
        $fragment.equivalence | Should -HaveCount 1
        $fragment.equivalence[0].trials | Should -Be 210
    }

    It 'Preserves a valid failed <FailedModel> outcome with producer exit <ExitCode>' -ForEach @(
        @{ FailedModel = 'gpt-6-luna'; ExitCode = 1 }
        @{ FailedModel = 'claude-sonnet-5'; ExitCode = 1 }
        @{ FailedModel = 'both'; ExitCode = 1 }
        @{ FailedModel = 'gpt-6-luna'; ExitCode = 99 }
    ) {
        foreach ($model in @('gpt-6-luna', 'claude-sonnet-5')) {
            $summary = New-TestSummary -Model $model
            $failed = $FailedModel -in @($model, 'both')
            if ($failed) {
                $summary.invariantFailures = 1
                $summary.invariantDiagnostics.failed = 1
                $summary.invariantDiagnostics.failures = @(@{
                    variant = 'baseline'; stimulus = 'code-reverse-string-rust'; grader = 'rust-fn-syntax'; count = 1
                })
                $summary.verdict = 'fail'
                $summary.equivalenceGate = 'fail'
            }
            $summary.compareLogs = @('do-not-publish-this-fixture')
            $path = if ($model -eq 'gpt-6-luna') { $script:GptPath } else { $script:ClaudePath }
            Write-TestEnvelope -Path $path -Model $model -ProducerExitCode $(if ($failed) { $ExitCode } else { 0 }) -Summary $summary
        }
        $statusPath = Join-Path $TestDrive 'measured-status.json'
        & $script:ScriptPath -EnvelopePath $script:ClaudePath, $script:GptPath -ExpectedWorkflowRunId '12345' `
            -ExpectedWorkflowRunAttempt 1 -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath -StatusPath $statusPath
        $LASTEXITCODE | Should -Be 1
        (Get-Content $statusPath -Raw | ConvertFrom-Json).category | Should -Be 'evidence'
        $combinedText = Get-Content $script:OutputPath -Raw
        $combined = $combinedText | ConvertFrom-Json
        $combined.runs | Should -Be 210
        $combined.perModelEvidence | Should -HaveCount 2
        @($combined.perModelEvidence | Where-Object verdict -EQ 'fail').Count | Should -Be $(if ($FailedModel -eq 'both') { 2 } else { 1 })
        $combinedText | Should -Not -Match 'do-not-publish|compareLogs|dataQualityDiagnostics|variants'
        $fragment = Get-Content $script:EvalSummaryPath -Raw | ConvertFrom-Json
        $fragment.totals.failedSpecs | Should -Be 1
        $fragment.equivalence[0].exitCode | Should -Be 1
        $fragment.equivalence[0].assertionsPassed | Should -Be (168 - $combined.invariantFailures)
        $fragment.equivalence[0].dataQualityViolations | Should -Be 0
    }

    It 'Rejects invalid <Mutation> diagnostics without leaving an old healthy fragment' -ForEach @(
        @{ Mutation = 'unknown identity' }
        @{ Mutation = 'count mismatch' }
        @{ Mutation = 'missing diagnostics' }
        @{ Mutation = 'exit contradiction' }
    ) {
        $summary = New-TestSummary -Model 'gpt-6-luna'
        switch ($Mutation) {
            'unknown identity' {
                $summary.invariantDiagnostics.failures = @(@{
                    variant = 'baseline'; stimulus = 'do-not-publish-this-fixture'; grader = 'rust-fn-syntax'; count = 1
                })
            }
            'count mismatch' { $summary.invariantDiagnostics.failed = 1 }
            'missing diagnostics' { $summary.Remove('invariantDiagnostics') }
        }
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -Summary $summary `
            -ProducerExitCode $(if ($Mutation -eq 'exit contradiction') { 1 } else { 0 })
        '{}' | Set-Content $script:OutputPath
        '{}' | Set-Content $script:EvalSummaryPath
        $status = Join-Path $TestDrive 'invalid-status.json'
        & $script:ScriptPath -EnvelopePath $script:GptPath, $script:ClaudePath -ExpectedWorkflowRunId '12345' `
            -ExpectedWorkflowRunAttempt 1 -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath -StatusPath $status 2>$null
        $LASTEXITCODE | Should -Be 1
        (Get-Content $status -Raw | ConvertFrom-Json).category | Should -Be 'contract'
        Test-Path $script:EvalSummaryPath | Should -BeFalse
        Test-Path $script:OutputPath | Should -BeFalse
    }

    It 'weights model means and win rates by contributed trials' {
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -DriverRunId 'gpt-run' `
            -Summary (New-TestSummary -Model 'gpt-6-luna' -Runs 100 -Ties 75 -MeanScore 0.2 -WinRate 0.2)
        Write-TestEnvelope -Path $script:ClaudePath -Model 'claude-sonnet-5' -DriverRunId 'claude-run' `
            -Summary (New-TestSummary -Model 'claude-sonnet-5' -Runs 50 -Ties 25 -MeanScore -0.1 -WinRate 0.05)

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath

        $LASTEXITCODE | Should -Be 0
        $combined = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        $combined.meanScore | Should -Be 0.1
        $combined.winRate | Should -Be 0.15
    }

    It 'writes an explicit not-required reporting fragment without envelopes' {
        $planPath = Join-Path $TestDrive 'not-required-plan.json'
        Write-NotRequiredPlan -Path $planPath
        & $script:ScriptPath -NotRequired -PlanPath $planPath -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath

        $LASTEXITCODE | Should -Be 0
        (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).status | Should -Be 'not-required'
        $fragment = Get-Content -LiteralPath $script:EvalSummaryPath -Raw | ConvertFrom-Json
        $fragment.equivalenceStatus | Should -Be 'not-required'
        $fragment.totals.specs | Should -Be 0
    }

    It 'Does not let not-required evidence bypass a <PlanState> canonical plan' -ForEach @(
        @{ PlanState = 'required' }, @{ PlanState = 'missing' }, @{ PlanState = 'corrupt' }
    ) {
        $planPath = Join-Path $TestDrive 'rejected-not-required-plan.json'
        if ($PlanState -eq 'corrupt') { '{}' | Set-Content $planPath }
        elseif ($PlanState -eq 'required') { Write-NotRequiredPlan -Path $planPath -Required $true }
        & $script:ScriptPath -NotRequired -PlanPath $planPath -OutputPath $script:OutputPath `
            -EvalSummaryPath $script:EvalSummaryPath 2>$null
        $LASTEXITCODE | Should -Be 1
        Test-Path $script:EvalSummaryPath | Should -BeFalse
    }

    It 'discovers the exact model pair from an envelope directory' {
        $directory = Join-Path $TestDrive "envelopes-$([guid]::NewGuid())"
        New-Item -ItemType Directory -Path $directory -Force | Out-Null
        Copy-Item -LiteralPath $script:GptPath -Destination (Join-Path $directory 'model-evidence-gpt-6-luna.json')
        Copy-Item -LiteralPath $script:ClaudePath -Destination (Join-Path $directory 'model-evidence-claude-sonnet-5.json')

        & $script:ScriptPath `
            -EnvelopeDirectory $directory `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath

        $LASTEXITCODE | Should -Be 0
        (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).runs | Should -Be 210
    }

    It 'rejects a missing expected model envelope' {
        & $script:ScriptPath `
            -EnvelopePath $script:GptPath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
        Test-Path -LiteralPath $script:OutputPath | Should -BeFalse
    }

    It 'rejects duplicate model envelopes' {
        Write-TestEnvelope -Path $script:ClaudePath -Model 'gpt-6-luna' -DriverRunId 'gpt-run-2'

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
    }

    It 'rejects a passing summary paired with nonzero producer exit' {
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -ProducerExitCode 3

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
        (Get-Content -LiteralPath (Join-Path (Split-Path $script:EvalSummaryPath) 'merge-status.json') -Raw | ConvertFrom-Json).category | Should -Be 'contract'
    }

    It 'classifies a matched non-passing producer as an evidence failure' {
        $summary = New-TestSummary -Model 'gpt-6-luna'
        $summary.verdict = 'fail'
        $summary.equivalenceGate = 'fail'
        $summary.invariantFailures = 1
        $summary.invariantDiagnostics.failed = 1
        $summary.invariantDiagnostics.failures = @(@{
            variant = 'baseline'; stimulus = 'code-reverse-string-rust'; grader = 'rust-fn-syntax'; count = 1
        })
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -ProducerExitCode 1 -Summary $summary

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
        (Get-Content -LiteralPath (Join-Path (Split-Path $script:EvalSummaryPath) 'merge-status.json') -Raw | ConvertFrom-Json).category | Should -Be 'evidence'
        $fragment = Get-Content -LiteralPath $script:EvalSummaryPath -Raw | ConvertFrom-Json
        $fragment.totals.failedSpecs | Should -Be 1
        $fragment.equivalenceStatus | Should -Be 'complete'
        $fragment.equivalence[0].invariantFailures | Should -Be 1
        $fragment.equivalence[0].dataQualityViolations | Should -Be 0
    }

    It 'rejects mismatched <Field>' -ForEach @(
        @{ Field = 'workflow run'; Parameters = @{ WorkflowRunId = 'different' } }
        @{ Field = 'workflow attempt'; Parameters = @{ WorkflowRunAttempt = 2 } }
        @{ Field = 'head SHA'; Parameters = @{ HeadSha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' } }
        @{ Field = 'agent'; Parameters = @{ Agent = 'other-agent' } }
        @{ Field = 'tier'; Parameters = @{ Tier = 'ci' } }
        @{ Field = 'driver run'; Parameters = @{ DriverRunId = '' } }
    ) {
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' @Parameters

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
    }

    It 'rejects a summary whose model does not match its envelope' {
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -Summary (New-TestSummary -Model 'claude-sonnet-5')

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
    }

    It 'rejects malformed or incompatible evidence' -ForEach @(
        @{ Name = 'malformed'; Value = '{' }
        @{ Name = 'incompatible'; Value = '{"envelopeSchemaVersion":"2.0.0"}' }
    ) {
        Set-Content -LiteralPath $script:GptPath -Value $Value -Encoding utf8NoBOM

        & $script:ScriptPath `
            -EnvelopePath $script:GptPath, $script:ClaudePath `
            -ExpectedWorkflowRunId '12345' -ExpectedWorkflowRunAttempt 1 `
            -ExpectedHeadSha '0123456789abcdef0123456789abcdef01234567' `
            -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath 2>$null

        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'Eval validation workflow contract' -Tag 'Unit' {
    BeforeAll {
        $script:WorkflowPath = Join-Path $PSScriptRoot '../../../.github/workflows/eval-validation.yml'
        $script:Workflow = Get-Content -LiteralPath $script:WorkflowPath -Raw
        Import-Module powershell-yaml -ErrorAction Stop
        $script:EvalWorkflow = ConvertFrom-Yaml $script:Workflow
        $script:Caller = Get-Content (Join-Path $PSScriptRoot '../../../.github/workflows/pr-validation.yml') -Raw | ConvertFrom-Yaml
    }

    It 'Renders only validated baseline report data for <Scenario>' -ForEach @(
        @{ Scenario = 'gpt failure' }, @{ Scenario = 'claude failure' },
        @{ Scenario = 'unsafe row' }, @{ Scenario = 'missing evidence' },
        @{ Scenario = 'api failure' }
    ) {
        $summaries = @(
            foreach ($model in @('gpt-6-luna', 'claude-sonnet-5')) {
                $summary = New-TestSummary -Model $model
                $failedModel = if ($Scenario -eq 'claude failure') { 'claude-sonnet-5' } else { 'gpt-6-luna' }
                if ($model -eq $failedModel) {
                    $summary.invariantFailures = 1
                    $summary.verdict = 'fail'
                    $summary.equivalenceGate = 'fail'
                    $summary.invariantDiagnostics.failed = 1
                    $summary.invariantDiagnostics.failures = @(@{
                        variant = 'baseline'; stimulus = 'code-reverse-string-rust'; grader = 'rust-fn-syntax'; count = 1
                    })
                }
                [pscustomobject]$summary
            }
        )
        $combined = Merge-BaselineModelSummary -Summary $summaries
        $fragment = New-EvalSummaryFragment -Summary ([pscustomobject]$combined)
        $aggregate = [ordered]@{
            schemaVersion = '1.1.0'; producers = @('equivalence'); totals = $fragment.totals
            perArtifact = @(); equivalence = $fragment.equivalence
        }
        if ($Scenario -eq 'unsafe row') {
            $failedRow = @($aggregate.equivalence[0].perModelEvidence | Where-Object verdict -EQ 'fail')[0]
            $failedRow.invariantDiagnostics.failures[0].answer = 'do-not-publish-this-fixture'
        }
        $inputPath = Join-Path $TestDrive 'report-input.json'
        $aggregate | ConvertTo-Json -Depth 50 | Set-Content $inputPath
        $scriptPath = Join-Path $TestDrive 'report-script.js'
        ($script:EvalWorkflow.jobs['eval-report'].steps | Where-Object name -EQ 'Post aggregated eval summary comment').with.script |
            Set-Content $scriptPath
        $probe = @'
const fs = await import('node:fs');
const path = await import('node:path');
const source = fs.readFileSync(process.argv[1], 'utf8');
const input = fs.readFileSync(process.argv[2], 'utf8');
const scenario = process.argv[3];
const bodies = [], failures = [];
const fakeFs = { existsSync: () => scenario !== 'missing evidence', readdirSync: () => ['eval-authoritative'], readFileSync: () => input };
const github = { rest: { issues: {
    listComments: async () => ({ data: [{ id: 1, body: '<!-- eval-execute-summary --> Old passed report' }] }),
    updateComment: async value => { if (scenario === 'api failure') throw new Error('do-not-publish-this-fixture'); bodies.push(value.body); },
    createComment: async value => { bodies.push(value.body); }
} } };
const context = { repo: { owner: 'example', repo: 'example' }, payload: { pull_request: { number: 42, head: { sha: 'a'.repeat(40) } } } };
const core = { setFailed: value => failures.push(value) };
let error = null;
try {
    const AsyncFunction = Object.getPrototypeOf(async function () {}).constructor;
    await new AsyncFunction('require', 'github', 'context', 'core', source)(
        name => { if (name === 'fs') return fakeFs; if (name === 'path') return path; throw new Error('Unexpected dependency'); },
        github, context, core);
} catch (caught) { error = caught.message; }
console.log(JSON.stringify({ bodies, failures, error }));
'@
        $output = & node --input-type=module -e $probe $scriptPath $inputPath $Scenario
        $LASTEXITCODE | Should -Be 0
        $result = $output | ConvertFrom-Json
        $output | Should -Not -Match 'do-not-publish-this-fixture'
        if ($Scenario -in @('gpt failure', 'claude failure')) {
            $result.failures | Should -HaveCount 0
            $result.bodies | Should -HaveCount 1
            $result.bodies[0] | Should -Match 'Baseline evidence'
            $model = if ($Scenario -eq 'claude failure') { 'claude-sonnet-5' } else { 'gpt-6-luna' }
            $result.bodies[0] | Should -Match "\| $model \| baseline \| fail \| 105 \| 84 \| 1 \|"
            $result.bodies[0] | Should -Not -Match 'No changed AI artifacts required evaluation'
        }
        else {
            @($result.failures).Count | Should -BeGreaterThan 0
            if ($Scenario -eq 'api failure') {
                $result.error | Should -Be 'Eval report publication failed.'
            }
            else {
                $result.bodies | Should -HaveCount 1
                $result.bodies[0] | Should -Match 'Report withheld'
                $result.bodies[0] | Should -Not -Match 'Status.*Passed'
            }
        }
    }

    It 'passes the aggregate immutable range-or-full contract' {
        $inputs = $script:Caller.jobs['eval-validation'].with
        $inputs['change-mode'] | Should -BeExactly '${{ needs.change-range.outputs.mode }}'
        $inputs['base-sha'] | Should -BeExactly '${{ needs.change-range.outputs.base-sha }}'
        $inputs['head-sha'] | Should -BeExactly '${{ needs.change-range.outputs.head-sha }}'
        @($script:Caller.jobs['eval-validation'].needs) | Should -Contain 'change-range'
        foreach ($legacyInput in @('base-ref', 'head-ref', 'merge-ref')) {
            $inputs.ContainsKey($legacyInput) | Should -BeFalse
            $script:EvalWorkflow.on.workflow_call.inputs.ContainsKey($legacyInput) | Should -BeFalse
        }
        $script:EvalWorkflow.on.workflow_call.inputs['change-mode'].default | Should -Be 'full'
    }

    It 'generates and uploads exactly one canonical comparison before eligibility' {
        $steps = $script:EvalWorkflow.jobs['eval-validation'].steps
        $generation = @($steps | Where-Object { $_.run -match 'Get-EvalChangeSet.ps1' })
        $generation | Should -HaveCount 1
        $generation[0]['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $generation[0].run | Should -Match '-BaseRef \$env:INPUT_BASE_SHA -HeadRef \$env:INPUT_HEAD_SHA'
        $generation[0].run | Should -Match 'if \(\$LASTEXITCODE -ne 0\) \{ throw'
        $upload = @($steps | Where-Object { $_.with.name -eq 'eval-change-set' })
        $upload | Should -HaveCount 1
        $upload[0]['if'] | Should -BeExactly "inputs.change-mode == 'range'"
        $upload[0].with.path | Should -Be 'logs/eval-change-set.json'
        $upload[0].with['if-no-files-found'] | Should -Be 'error'
        $detect = $steps | Where-Object { $_.id -eq 'detect' }
        $steps.IndexOf($generation[0]) | Should -BeLessThan $steps.IndexOf($upload[0])
        $steps.IndexOf($upload[0]) | Should -BeLessThan $steps.IndexOf($detect)
        $detect.run | Should -Match 'Read-EvalChangeSet'
        $detect.run | Should -Match 'Test-EvalChangeSetRelevance'
        $detect.run | Should -Not -Match 'git diff|Could not compute diff|\$null -eq \$changed'
    }

    It 'carries the same change set through moderation to changed-spec selection' {
        $moderationSteps = $script:EvalWorkflow.jobs['content-moderation'].steps
        $download = $moderationSteps | Where-Object { $_.with.name -eq 'eval-change-set' }
        $artifact = $moderationSteps | Where-Object { $_.id -eq 'artifact-manifest' }
        $download.if | Should -BeExactly "inputs.change-mode == 'range'"
        $moderationSteps.IndexOf($download) | Should -BeLessThan $moderationSteps.IndexOf($artifact)
        $artifact.run | Should -Match '-ChangeSetPath logs/eval-change-set.json'
        $artifact.run | Should -Match 'if \(\$LASTEXITCODE -ne 0\) \{ throw'
        ($moderationSteps | Where-Object { $_.with.name -eq 'content-moderation-results' }).with.path |
            Should -Match 'logs/eval-change-set.json'
        $planSteps = $script:EvalWorkflow.jobs['agent-plan'].steps
        $planDownload = $planSteps | Where-Object { $_.with.name -eq 'content-moderation-results' }
        $spec = $planSteps | Where-Object { $_.run -match 'Get-ChangedSpecStimulus.ps1' }
        $planSteps.IndexOf($planDownload) | Should -BeLessThan $planSteps.IndexOf($spec)
        $spec.run | Should -Match '-ChangeSetPath logs/eval-change-set.json'
        $spec.run | Should -Match 'if \(\$LASTEXITCODE -ne 0\) \{ throw'
        $script:Workflow | Should -Not -Match '-HeadRef HEAD|baseBranch\.\.\.HEAD|inputs\.base-branch'
    }

    It 'preserves model-job eligibility gates and explicit full-suite mode' {
        foreach ($name in @('agent-plan', 'eval-execute', 'equivalence-execute', 'equivalence-fan-in', 'eval-fan-in')) {
            $script:EvalWorkflow.jobs[$name].if |
                Should -Match "needs\.eval-validation\.outputs\.eval-relevant == 'true'"
        }
        $detect = $script:EvalWorkflow.jobs['eval-validation'].steps | Where-Object { $_.id -eq 'detect' }
        $detect.run | Should -Match "INPUT_CHANGE_MODE -eq 'full'"
        $detect.run | Should -Match "INPUT_CHANGED_FILES_ONLY -ne 'true'"
        $detect.run | Should -Match '\$relevant = \$true'
        $checkouts = @($script:EvalWorkflow.jobs['eval-validation'].steps | Where-Object { $_.uses -like 'actions/checkout@*' })
        $checkouts[0].with['fetch-depth'] | Should -Be 0
        $checkouts[0].with.Contains('ref') | Should -BeFalse
    }

    It 'keeps baseline equivalence out of ordinary eval dispatch' {
        $ordinaryCommand = [regex]::Match($script:Workflow, 'npm run ci:eval:execute[^\r\n]+').Value
        $ordinaryCommand | Should -Not -BeNullOrEmpty
        $ordinaryCommand | Should -Not -Match 'EnableBaselineEquivalence|EquivalenceTier'
    }

    It 'defines the exact bounded fixed-model matrix' {
        $script:Workflow | Should -Match '(?s)equivalence-execute:.*?fail-fast: false.*?max-parallel: \$\{\{ inputs\.baseline-max-parallel \|\| 2 \}\}.*?model: gpt-6-luna.*?model: claude-sonnet-5'
        $script:Workflow | Should -Match 'CalibrationModel \$env:SELECTED_MODEL'
    }

    It 'defines a reversible compare shard control validated before model work' {
        $shardInput = $script:EvalWorkflow.on.workflow_call.inputs['compare-shard-count']
        $shardInput.type | Should -Be 'number'
        $shardInput.default | Should -Be 7
        $shardInput.required | Should -BeFalse
        $script:Workflow | Should -Match "COMPARE_SHARD_COUNT -notin @\('1', '5', '7'\)"
        $script:Workflow | Should -Match ([regex]::Escape("compare-shard-count must be 1, 5, or 7; received '"))
        $script:Workflow | Should -Match '(?s)agent-plan:.*?COMPARE_SHARD_COUNT: \$\{\{ inputs\.compare-shard-count \|\| 7 \}\}.*?equivalence-execute:'
        $script:Workflow | Should -Match '(?s)equivalence-execute:.*?COMPARE_SHARD_COUNT: \$\{\{ inputs\.compare-shard-count \|\| 7 \}\}.*?-CompareShardCount \(\[int\]\$env:COMPARE_SHARD_COUNT\)'
    }

    It 'defines a non-gating advisory lane control that defaults on' {
        $advisoryInput = $script:EvalWorkflow.on.workflow_call.inputs['advisory-equivalence']
        $advisoryInput.type | Should -Be 'boolean'
        $advisoryInput.default | Should -BeTrue
        $advisoryInput.required | Should -BeFalse
    }

    It 'runs the advisory model lane in parallel without any path into gating' {
        $jobs = $script:EvalWorkflow.jobs
        $advisory = $jobs['equivalence-advisory']
        $advisory | Should -Not -BeNullOrEmpty
        $advisory['continue-on-error'] | Should -BeTrue
        $advisory.permissions.contents | Should -Be 'read'
        $guard = 'inputs.advisory-equivalence != false && '
        $advisoryCondition = ([string]$advisory['if']).Trim()
        $advisoryCondition | Should -BeLike "$guard*"
        $advisoryCondition.Substring($guard.Length) | Should -BeExactly ([string]$jobs['equivalence-execute']['if']).Trim()
        @($advisory.needs) | Should -Not -Contain 'equivalence-execute'
        foreach ($jobName in @($jobs.Keys)) {
            @($jobs[$jobName].needs) | Should -Not -Contain 'equivalence-advisory' -Because "$jobName must not depend on the advisory lane"
        }
        @($advisory.strategy.matrix.include | ForEach-Object { $_.model }) | Should -Contain 'mai-code-1.1-flash'

        $run = (@($advisory.steps | Where-Object { $_.name -eq 'Execute advisory model' }))[0].run
        $run | Should -Match '-Tier devloop'
        $run | Should -Match '-Model \$env:ADVISORY_MODEL'
        $run | Should -Match '-CompareShardCount \(\[int\]\$env:COMPARE_SHARD_COUNT\)'
        $run | Should -Not -Match 'reasoning-effort'
    }

    It 'runs only catalogued models in the equivalence matrices' {
        $catalogPath = Join-Path $PSScriptRoot '../../linting/model-catalog.json'
        $catalogIds = @((Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json).models | ForEach-Object {
                (([string]$_.name -replace '\s*\(copilot\)\s*$', '').Trim().ToLowerInvariant() -replace '\s+', '-')
            })
        $models = @(foreach ($jobName in @('equivalence-execute', 'equivalence-advisory')) {
                @($script:EvalWorkflow.jobs[$jobName].strategy.matrix.include | ForEach-Object { [string]$_.model })
            })
        $models | Should -Not -BeNullOrEmpty
        foreach ($model in $models) {
            $catalogIds | Should -Contain $model -Because "workflow model '$model' must match an entry in scripts/linting/model-catalog.json"
        }
    }

    It 'publishes only the advisory summary under a name no fan-in downloads' {
        $jobs = $script:EvalWorkflow.jobs
        $upload = (@($jobs['equivalence-advisory'].steps | Where-Object { $_.uses -like 'actions/upload-artifact@*' }))[0]
        $artifactNames = @($jobs['equivalence-advisory'].strategy.matrix.include | ForEach-Object { ([string]$upload.with.name).Replace('${{ matrix.key }}', [string]$_.key) })
        ([string]$upload.with.path).Trim() | Should -BeExactly 'logs/advisory-equivalence-${{ matrix.model }}.json'

        $downloadFilters = @(foreach ($jobName in @('equivalence-fan-in', 'eval-fan-in', 'eval-report')) {
                foreach ($step in @($jobs[$jobName].steps | Where-Object { $_.uses -like 'actions/download-artifact@*' })) {
                    foreach ($key in @('pattern', 'name')) {
                        if ($step.with -and $step.with.ContainsKey($key)) { [string]$step.with[$key] }
                    }
                }
            })
        $downloadFilters | Should -Not -BeNullOrEmpty
        foreach ($artifactName in $artifactNames) {
            foreach ($filter in $downloadFilters) {
                $artifactName -like $filter | Should -BeFalse -Because "fan-in filter '$filter' must not match '$artifactName'"
            }
        }
    }

    It 'keeps ordinary manual execution enabled for dispatched callers' {
        $workflow = ConvertFrom-Yaml -Yaml $script:Workflow
        foreach ($jobName in @('agent-plan', 'eval-execute', 'equivalence-execute', 'equivalence-fan-in', 'eval-fan-in')) {
            $condition = [string]$workflow.jobs[$jobName]['if']
            $condition | Should -Match "github.event_name == 'workflow_dispatch'"
            $condition | Should -Match ([regex]::Escape("github.event_name == 'pull_request' && github.event.pull_request.head.repo.full_name == github.repository"))
            $condition | Should -Not -Match 'head\.repo\.fork'
        }
    }

    It 'uses one canonical plan for mixed execution and baseline applicability' {
        $script:Workflow | Should -Match '(?s)agent-plan:.*?New-AgentEvalPlan\.ps1.*?execution-matrix=\$matrix.*?baseline-required='
        $script:Workflow | Should -Match '(?s)eval-execute:.*?max-parallel: 6.*?matrix: \$\{\{ fromJSON\(needs\.agent-plan\.outputs\.execution-matrix\) \}\}'
        $script:Workflow | Should -Match "needs\.agent-plan\.outputs\.baseline-required == 'true'"
        $shardArguments = "'-PlanPath', 'logs/agent-eval-plan.json', '-ShardId', " + '$env:MATRIX_SHARD'
        $script:Workflow | Should -Match ([regex]::Escape($shardArguments))
    }

    It 'defines reversible target shard controls and derives target rows from the canonical plan' {
        $script:Workflow | Should -Match '(?s)instruction-shard-count:.*?default: 2.*?skill-shard-count:.*?default: 2'
        $script:Workflow | Should -Match "INSTRUCTION_SHARD_COUNT -notin @\('1', '2'\)"
        $script:Workflow | Should -Match "SKILL_SHARD_COUNT -notin @\('1', '2'\)"
        $script:Workflow | Should -Match ([regex]::Escape("instruction-shard-count must be 1 or 2; received '"))
        $script:Workflow | Should -Match ([regex]::Escape("skill-shard-count must be 1 or 2; received '"))
        $script:Workflow | Should -Match '-InstructionShardCount \(\[int\]\$env:INSTRUCTION_SHARD_COUNT\)'
        $script:Workflow | Should -Match '-SkillShardCount \(\[int\]\$env:SKILL_SHARD_COUNT\)'
        $script:Workflow | Should -Match ([regex]::Escape("`$include.Add([ordered]@{ kind = 'prompt'; producer = 'prompt'; shard = '' })"))
    }

    It 'emits planned producer rows heaviest first with a stable tie break' {
        $script:Workflow | Should -Match ([regex]::Escape("Expression = { [int]`$_.expectedTrialWeight }; Descending = `$true"))
        $script:Workflow | Should -Match ([regex]::Escape("Expression = { [string]`$_.id }; Ascending = `$true"))
        $script:Workflow | Should -Match ([regex]::Escape("foreach (`$shard in `$orderedShards)"))
        $script:Workflow | Should -Not -Match ([regex]::Escape("foreach (`$kind in @('instruction', 'skill', 'agent'))"))
    }

    It 'makes global fan-in authoritative for reporting' {
        $script:Workflow | Should -Match '(?s)eval-fan-in:.*?needs: \[eval-validation, agent-plan, eval-execute, equivalence-fan-in\]'
        $script:Workflow | Should -Match '(?s)eval-fan-in:.*?Merge-EvalExecution\.ps1.*?Authoritative eval fan-in failed closed'
        $script:Workflow | Should -Match '(?s)eval-report:.*?needs: \[eval-fan-in\].*?name: eval-authoritative'
    }

    It 'uploads unique model evidence and a distinct combined artifact' {
        $script:Workflow | Should -Match 'name: eval-equivalence-\$\{\{ matrix\.key \}\}'
        $script:Workflow | Should -Match 'name: eval-equivalence-combined'
        $script:Workflow | Should -Match "category -eq 'evidence'.*SOFT_FAIL -eq 'true'"
    }

    It 'encodes fail-closed producer, cancellation, upload, not-required, and reporting branches' {
        $script:Workflow | Should -Match '(?s)Upload eval execution results.*?if: always\(\).*?if-no-files-found: error'
        $script:Workflow | Should -Match '(?s)Upload isolated model evidence.*?if: always\(\).*?if-no-files-found: error'
        $script:Workflow | Should -Match "env\.EQUIVALENCE_FAILED == 'true' && !inputs\.soft-fail"
        $script:Workflow | Should -Match '(?s)equivalence-fan-in:.*?always\(\) && !cancelled\(\)'
        $script:Workflow | Should -Match "\$arguments \+= '-NotRequired'"
        $script:Workflow | Should -Match "EQUIVALENCE_REQUIRED -notin @\('true', 'false'\)"
        $script:Workflow | Should -Match "throw 'Baseline equivalence fan-in failed closed\.'"
        $script:Workflow | Should -Match '(?s)Download isolated model evidence.*?continue-on-error: true.*?Merge expected model evidence'
        $script:Workflow | Should -Match '(?s)Upload combined equivalence evidence.*?if: always\(\).*?if-no-files-found: error'
        $script:Workflow | Should -Match '(?s)Upload authoritative eval result.*?if: always\(\).*?if-no-files-found: error'
    }
}
