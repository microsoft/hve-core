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
                [pscustomobject][ordered]@{ id = 'ordinary-01'; kind = 'agent'; expectedTrialWeight = 2; artifacts = @('agent:alpha'); runKeys = @('alpha.yaml') }
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
        $agent.perSpec = @([pscustomobject]@{ specPath = 'alpha.yaml'; tag = ''; diagnostics = (New-FanInDiagnostics 'alpha.yaml' 2) })
        $instruction = New-FanInSummary 'instruction-01' 'instruction' $Plan.planDigest
        $instruction.totals = [pscustomobject]@{ artifacts = 1; specs = 1; assertionsPassed = 1; assertionsFailed = 0; durationMs = 5; failedSpecs = 0 }
        $instruction.perArtifact = @([pscustomobject]@{ kind = 'instruction'; artifactId = 'beta' })
        $instruction.perSpec = @([pscustomobject]@{ specPath = 'instructions.yaml'; tag = 'instruction=beta'; diagnostics = (New-FanInDiagnostics 'instructions.yaml|instruction=beta' 1) })
        return @($agent, $instruction, (New-FanInSummary 'skill-01' 'skill' $Plan.planDigest), (New-FanInSummary prompt))
    }
    function New-FanInDiagnostics([string]$RunKey, [int]$Runs) {
        $inventory = [ordered]@{ synthetic = [ordered]@{ runs = $Runs; graders = @([ordered]@{ name = 'check'; type = 'program' }) } }
        $trials = @(foreach ($trialIndex in 0..($Runs - 1)) {
            [ordered]@{ stimulusName = 'synthetic'; trialIndex = $trialIndex; itemIdDigest = $null; identitySource = 'stimulus-trial-index'
                executionStatus = 'success'; score = 1.0; thresholdPassed = $true; allGradersPassed = $true; gradeStatus = 'success'
                endReason = 'completed'; configuredTurns = 1; observedTurns = 1; responseTurns = 1; wallTimeMs = 5
                graders = @([ordered]@{ name = 'check'; graderType = 'program'; score = 1.0; passed = $true; status = 'success' }) }
        })
        return [ordered]@{ schemaVersion = '1.0.0'; runKey = $RunKey; configurationStatus = 'available'; specDigest = ('sha256:' + 'a' * 64); inputDigest = ('sha256:' + 'b' * 64)
            inputDigestScope = 'spec-only'; selectionDigest = (Get-AgentEvalValueDigest -Value $inventory); checkout = $null; executorModel = 'model'; judgeModels = @()
            versions = @{}; threshold = 0.7; expectedStimuli = $inventory; selectedAttempt = 1
            attempts = @([ordered]@{ runKey = $RunKey; ordinal = 1; selected = $true; selectionReason = 'fewest-errors-first-on-tie'; exitCategory = 'success'
                assertionsPassed = $Runs; assertionsFailed = 0; erroredTrials = 0; observedTrials = $Runs; recordIssues = @(); trials = $trials
                perStimulus = @([ordered]@{ stimulusName = 'synthetic'; expectedTrials = $Runs; observedTrials = $Runs; aggregateScore = 1.0; aggregatePassed = $true }) }) }
    }
}

Describe 'Merge-EvalExecution.ps1' -Tag 'Unit' {
    Context 'explicit acceptance' -Tag 'Acceptance' {
                It 'projects only finite configured calibration verdicts and rejects poisoned or partial output' {
                        $helper = (Join-Path $PSScriptRoot '../../evals/invoke-eval-calibration.mjs') -replace '\\', '/'
                        $probe = @'
const { prepareCalibration, projectCalibrationGrade, executeCalibration } = await import(process.argv[2]);
const assert = await import('node:assert/strict');
const { createHash } = await import('node:crypto');
const { execFileSync } = await import('node:child_process');
const fs = await import('node:fs');
const os = await import('node:os');
const path = await import('node:path');
const repoRoot = process.argv[3];
const control = {id:'positive', graderName:'meaning', judgeModel:'judge', criterionCount:1};
const detail = {configuredName:'meaning', graderType:'prompt', passed:true, score:0.75, status:'success', evidence:'private', metadata:{model:'judge'},details:[{passed:true,score:0.75,evidence:'private'}]};
const record = {status:'success', gradeResult:{status:'success', details:[detail]}, trajectory:{output:'private'}};
assert.deepEqual(projectCalibrationGrade(control, JSON.stringify(record), 0), {id:'positive', status:'success', passed:true, score:0.75,criteria:[{index:0,passed:true,score:0.75}]});
for (const raw of ['invalid', JSON.stringify({...record, status:'error'}), JSON.stringify(record)+'\n'+JSON.stringify(record), JSON.stringify({...record, gradeResult:{details:[{...detail, status:'error'}]}}), JSON.stringify({...record, gradeResult:{details:[{...detail, status:'invalid'}]}})]) {
    assert.equal(projectCalibrationGrade(control, raw, 0).status, 'error');
}
assert.equal(projectCalibrationGrade(control, JSON.stringify(record), 1).status, 'error');
assert.equal(projectCalibrationGrade({...control,judgeModel:'wrong'}, JSON.stringify(record), 0).status, 'error');
assert.equal(projectCalibrationGrade({...control,criterionCount:2}, JSON.stringify(record), 0).status, 'error');
const workRoot = fs.mkdtempSync(path.join(os.tmpdir(), 'calibration-test-'));
const priorTemp = process.env.RUNNER_TEMP;
process.env.RUNNER_TEMP = workRoot;
try {
    const output = path.join(workRoot, 'safe.json');
    const profilePath = path.join(workRoot, 'profile.json');
    const manifestPath = path.join(workRoot, 'manifest.json');
    const installedVersion = JSON.parse(fs.readFileSync(path.join(repoRoot, 'node_modules/@microsoft/vally-cli/package.json'), 'utf8')).version;
    const profile = {executorModel:'gpt-6-luna',judgeModel:'claude-sonnet-5',vallyVersion:installedVersion,calibration:[{id:'positive'},{id:'negative'}]};
    const writeVersionProbe = value => {
        const bytes = Buffer.from(JSON.stringify({...profile,vallyVersion:value}));
        fs.writeFileSync(profilePath, bytes);
        fs.writeFileSync(manifestPath, JSON.stringify({acceptance:{checkout:execFileSync('git',['rev-parse','HEAD'],{cwd:repoRoot,encoding:'utf8'}).trim(),inventory:{profileDigest:`sha256:${createHash('sha256').update(bytes).digest('hex')}`,calibration:[],selections:[]}}}));
    };
    writeVersionProbe(installedVersion);
    assert.throws(() => prepareCalibration(profilePath, manifestPath, repoRoot), /Calibration control mismatch/);
    writeVersionProbe('0.0.0');
    assert.throws(() => prepareCalibration(profilePath, manifestPath, repoRoot), /Calibration Vally version mismatch/);
    const referenceText = 'Synthetic declarations '.repeat(80) + 'Reference end';
    const prepared = { acceptance: {inventory:{profileDigest:'sha256:test'},checkout:'test',inputDigest:'sha256:test'},judge:'judge',version:'0.16.0',cli:'never-executed',
        controls:[{...control,expectedPass:true,stimulusName:'synthetic',stimulus:{prompt:'Synthetic task'},specPath:'synthetic.yaml',output:'Synthetic answer',referenceText}] };
    let calls = 0;
    const runChild = (command, args, options) => {
        calls++;
        assert.equal(args[1], 'grade');
        assert.ok(!args.includes('--require-pass'));
        assert.equal(options.timeout, 180000);
        const input = JSON.parse(options.input);
        assert.equal(input.trajectory.events[0].data.simulated, true);
        const readResults = input.trajectory.events.filter(event => event.type === 'tool_result');
        assert.equal(readResults.map(event => event.data.result).join(''), referenceText);
        assert.ok(readResults.every(event => event.data.result.length <= 350));
        return {status:0,stdout:JSON.stringify(record),stderr:'private judge rationale'};
    };
    assert.deepEqual(executeCalibration(prepared, output, runChild), {passed:true,count:1});
    assert.equal(calls,1);
    assert.ok(!fs.readFileSync(output,'utf8').includes('private'));
    assert.throws(() => executeCalibration(prepared, output, runChild));
    assert.equal(calls,1);
} finally {
    if (priorTemp === undefined) delete process.env.RUNNER_TEMP; else process.env.RUNNER_TEMP = priorTemp;
    fs.rmSync(workRoot,{recursive:true,force:true});
}
console.log('PASS safe calibration projection');
'@
                        $repoRoot = (git rev-parse --show-toplevel) -replace '\\', '/'
                        $probe | & node --input-type=module - "file:///$helper" $repoRoot
                        $LASTEXITCODE | Should -Be 0
                }
        BeforeEach {
            $script:acceptanceDiagnostics = New-FanInDiagnostics 'alpha.yaml' 2
            $script:acceptanceDiagnostics.checkout = 'c' * 40
            $script:acceptanceDiagnostics.versions = @{ vally = '0.16.0'; 'vally-cli' = '0.16.0' }
            $script:acceptanceSummary = @{ perSpec = @(@{ specPath = 'alpha.yaml'; tag = ''; diagnostics = $script:acceptanceDiagnostics }) }
            $script:acceptanceContract = @{
                checkout = 'c' * 40; inputDigest = 'sha256:' + 'b' * 64
                inventory = @{ schemaVersion = '1.0.0'; profileDigest = 'sha256:' + 'd' * 64; executorModel = 'model'; judgeModel = 'judge'; vallyVersion = '0.16.0'
                    selections = @(@{ specPath = 'alpha.yaml'; tag = ''; specDigest = $script:acceptanceDiagnostics.specDigest; selectionDigest = $script:acceptanceDiagnostics.selectionDigest
                        threshold = 0.7; requiredStimuli = $script:acceptanceDiagnostics.expectedStimuli })
                    calibration = @(@{ id = 'positive'; expectedPass = $true }, @{ id = 'negative'; expectedPass = $false }) }
            }
            $script:acceptanceCalibration = @{ schemaVersion = '1.0.0'; profileDigest = 'sha256:' + 'd' * 64; checkout = 'c' * 40; inputDigest = 'sha256:' + 'b' * 64
                judgeModel = 'judge'; vallyVersion = '0.16.0'; controls = @(@{ id = 'positive'; status = 'success'; passed = $true; score = 1.0; criteria = @(@{ index = 0; passed = $true; score = 1.0 }) }, @{ id = 'negative'; status = 'success'; passed = $false; score = 0.0; criteria = @(@{ index = 0; passed = $false; score = 0.0 }) }) }
        }
        It 'accepts complete first-attempt checks and calibrated positive and negative controls' {
            $result = Test-EvalAcceptanceValue -Summary $script:acceptanceSummary -Acceptance $script:acceptanceContract -Calibration $script:acceptanceCalibration
            $result.passed | Should -BeTrue
            $result.requiredTrials | Should -Be 2
            $result.requiredScenarios | Should -Be 1
        }
        It 'writes a separate acceptance failure without changing ordinary aggregate totals' {
            $plan = New-FanInPlan
            $manifestPath = Join-Path $TestDrive 'acceptance-manifest.json'
            @{ acceptance = $script:acceptanceContract } | ConvertTo-Json -Depth 50 | Set-Content $manifestPath
            $plan.manifestDigests.changedSpecs = Get-AgentEvalFileDigest -Path $manifestPath
            $payload = [ordered]@{ schemaVersion = $plan.schemaVersion; manifestDigests = $plan.manifestDigests; baseline = $plan.baseline; ordinaryShards = @($plan.ordinaryShards); expectedProducers = @($plan.expectedProducers) }
            $plan.planDigest = Get-AgentEvalValueDigest -Value $payload
            $planPath = Join-Path $TestDrive 'acceptance-plan.json'
            $plan | ConvertTo-Json -Depth 50 | Set-Content $planPath
            $summaries = New-ValidFanInSummary $plan
            foreach ($summary in $summaries) {
                $summary.manifestDigests.changedSpecs = $plan.manifestDigests.changedSpecs
                $directory = Join-Path $TestDrive "acceptance-producers/$($summary.producer)"
                New-Item -ItemType Directory $directory -Force | Out-Null
                $summary | ConvertTo-Json -Depth 50 | Set-Content (Join-Path $directory 'eval-summary.json')
            }
            $outputPath = Join-Path $TestDrive 'acceptance-output/summary.json'
            & (Join-Path $PSScriptRoot '../../evals/Merge-EvalExecution.ps1') -PlanPath $planPath `
                -SummaryDirectory (Join-Path $TestDrive 'acceptance-producers') -OutputPath $outputPath `
                -AcceptanceManifestPath $manifestPath -CalibrationPath (Join-Path $TestDrive 'absent-calibration.json')
            $LASTEXITCODE | Should -Be 1
            $output = Get-Content -Raw $outputPath | ConvertFrom-Json -Depth 100
            $output.totals.failedSpecs | Should -Be 0
            $output.acceptance.passed | Should -BeFalse
            $output.acceptance.issues | Should -Contain 'calibration-missing'
        }
        It 'fails closed for <Mutation>' -ForEach @(
            @{ Mutation = 'missing-selection' }, @{ Mutation = 'duplicate-selection' }, @{ Mutation = 'retry' },
            @{ Mutation = 'source' }, @{ Mutation = 'missing-calibration' }, @{ Mutation = 'wrong-control' },
            @{ Mutation = 'duplicate-control' }, @{ Mutation = 'poisoned-control' }, @{ Mutation = 'missing-grader' }
        ) {
            switch ($Mutation) {
                'missing-selection' { $script:acceptanceSummary.perSpec = @() }
                'duplicate-selection' { $script:acceptanceSummary.perSpec += $script:acceptanceSummary.perSpec[0] }
                'retry' { $script:acceptanceDiagnostics.attempts += $script:acceptanceDiagnostics.attempts[0] }
                'source' { $script:acceptanceDiagnostics.checkout = 'e' * 40 }
                'missing-calibration' { $script:acceptanceCalibration = $null }
                'wrong-control' { $script:acceptanceCalibration.controls[1].passed = $true }
                'duplicate-control' { $script:acceptanceCalibration.controls[1].id = 'positive' }
                'poisoned-control' { $script:acceptanceCalibration.controls[0].rawOutput = 'private' }
                'missing-grader' { $script:acceptanceDiagnostics.attempts[0].trials[0].graders = @() }
            }
            (Test-EvalAcceptanceValue -Summary $script:acceptanceSummary -Acceptance $script:acceptanceContract -Calibration $script:acceptanceCalibration).passed | Should -BeFalse
        }
    }

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
    It 'rejects missing or poisoned ordinary diagnostic contracts' -ForEach @(
        @{ Mutation = 'missing' }
        @{ Mutation = 'poisoned' }
        @{ Mutation = 'wrong-owner' }
    ) {
        $plan = New-FanInPlan
        $summaries = New-ValidFanInSummary $plan
        switch ($Mutation) {
            'missing' { $summaries[0].perSpec[0].diagnostics = $null }
            'poisoned' { $summaries[0].perSpec[0].diagnostics['rawOutput'] = 'synthetic-private-output' }
            'wrong-owner' { $summaries[0].perSpec[0].diagnostics.runKey = 'wrong.yaml' }
        }
        { Merge-EvalSummaryValue -Plan $plan -Summary $summaries } | Should -Throw '*invalid diagnostic contract*'
    }
    It 'rejects duplicate producer evidence' {
        $plan = New-FanInPlan
        { Merge-EvalSummaryValue -Plan $plan -Summary @((New-FanInSummary prompt), (New-FanInSummary prompt)) } | Should -Throw '*Duplicate producer*'
    }
    It 'reports invalid selected evidence even when producer failure totals are zero' {
        $plan = New-FanInPlan
        $summaries = New-ValidFanInSummary $plan
        $summaries[0].perSpec[0].diagnostics.attempts[0].trials[1].trialIndex = 0
        $result = Merge-EvalSummaryValue -Plan $plan -Summary $summaries
        $result.totals.failedSpecs | Should -Be 1
        $spec = @($result.perSpec | Where-Object specPath -eq 'alpha.yaml')[0]
        $spec.status | Should -Be 'integrity-failure'
        $spec.integrity.integrityPassed | Should -BeFalse
        $spec.integrity.issues | Should -Contain 'duplicate-trial'
    }
    It 'preserves bounded completion evidence through authoritative fan-in' {
        $plan = New-FanInPlan
        $result = Merge-EvalSummaryValue -Plan $plan -Summary (New-ValidFanInSummary $plan)
        $trial = @($result.perSpec | Where-Object specPath -eq 'alpha.yaml')[0].diagnostics.attempts[0].trials[0]
        $trial.endReason | Should -Be 'completed'
        $trial.configuredTurns | Should -Be 1
        $trial.observedTurns | Should -Be 1
        $trial.responseTurns | Should -Be 1
        $trial.wallTimeMs | Should -Be 5
    }
    It 'rejects a self-consistent reduced population against the canonical plan' {
        $plan = New-FanInPlan
        $summaries = New-ValidFanInSummary $plan
        $summaries[0].perSpec[0].diagnostics = New-FanInDiagnostics 'alpha.yaml' 1
        { Merge-EvalSummaryValue -Plan $plan -Summary $summaries } | Should -Throw '*population differs from the canonical plan*'
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