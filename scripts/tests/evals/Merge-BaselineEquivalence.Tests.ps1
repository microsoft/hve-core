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
            schemaVersion = '2.1.0'; agent = 'rpi-agent'; tier = 'calibration'; model = $Model
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

    It 'weights model means and win rates by contributed trials' {
        Write-TestEnvelope -Path $script:GptPath -Model 'gpt-6-luna' -DriverRunId 'gpt-run' `
            -Summary (New-TestSummary -Model 'gpt-6-luna' -Runs 100 -MeanScore 0.2 -WinRate 0.2)
        Write-TestEnvelope -Path $script:ClaudePath -Model 'claude-sonnet-5' -DriverRunId 'claude-run' `
            -Summary (New-TestSummary -Model 'claude-sonnet-5' -Runs 50 -MeanScore -0.1 -WinRate 0.05)

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
        & $script:ScriptPath -NotRequired -OutputPath $script:OutputPath -EvalSummaryPath $script:EvalSummaryPath

        $LASTEXITCODE | Should -Be 0
        (Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json).status | Should -Be 'not-required'
        $fragment = Get-Content -LiteralPath $script:EvalSummaryPath -Raw | ConvertFrom-Json
        $fragment.equivalenceStatus | Should -Be 'not-required'
        $fragment.totals.specs | Should -Be 0
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
        $fragment.equivalenceStatus | Should -Be 'failed-evidence'
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

    It 'keeps acceptance opt-in and separates calibration from ordinary dispatch' {
        $script:Workflow | Should -Match '(?s)workflow_call:.*?acceptance-profile:.*?default: ""'
        $script:Workflow | Should -Match "ACCEPTANCE_PROFILE -notin @\('', 'pr-2951'\)"
        $script:Workflow | Should -Match "matrix.kind != 'calibration'"
        $script:Workflow | Should -Match "matrix.kind == 'calibration'"
        $script:Workflow | Should -Match 'npm run ci:eval:calibrate -- --profile evals/acceptance/pr-2951.json'
        $script:Workflow | Should -Match "'-AcceptanceManifestPath', 'plan-input/changed-spec-stimuli.json'"
        $script:Workflow | Should -Match "'-CalibrationPath', 'producer-results/eval-execution-results-calibration/eval-calibration.json'"
        $script:Workflow | Should -Match "github.event_name == 'workflow_dispatch' && inputs.acceptance-profile == 'pr-2951'"
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
