#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-VallyEvals.ps1'
    $script:RunnerModule = Join-Path $PSScriptRoot '../../evals/Modules/VallyRunner.psm1'
    $script:StubPath = Join-Path $PSScriptRoot 'fixtures/stub-vally.ps1'
    $script:RepositoryRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    $script:InstalledVallyVersion = [string](Get-Content -Raw (Join-Path $script:RepositoryRoot 'node_modules/@microsoft/vally-cli/package.json') | ConvertFrom-Json).version

    Import-Module $script:RunnerModule -Force
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Tests require the 'powershell-yaml' module to be installed."
    }
    Import-Module powershell-yaml -ErrorAction Stop
}

Describe 'Acceptance profile inventory' -Tag 'Unit', 'Acceptance' {
        BeforeEach {
                $script:AcceptanceRoot = Join-Path $TestDrive ([Guid]::NewGuid().ToString('N'))
                New-Item -ItemType Directory -Path $script:AcceptanceRoot -Force | Out-Null
                @{
                    defaults = @{ runs = 5; judge_model = 'claude-sonnet-5' }
                    stimuli = @(
                        @{ name = 'required-case'; tags = @{ agent = 'example' }; graders = @(@{ name = 'meaning'; type = 'prompt'; config = @{ threshold = 0.7 } }) }
                        @{ name = 'healthy-sibling'; tags = @{ agent = 'example' }; graders = @(@{ name = 'format'; type = 'output-matches' }) }
                    )
                } | ConvertTo-Yaml | Set-Content (Join-Path $script:AcceptanceRoot 'spec.yaml') -Encoding utf8NoBOM
                $script:AcceptanceProfile = [ordered]@{
                        schemaVersion = '1.0.0'; name = 'synthetic-acceptance'; executorModel = 'gpt-6-luna'
                        judgeModel = 'claude-sonnet-5'; vallyVersion = $script:InstalledVallyVersion
                        selections = @([ordered]@{ specPath = 'spec.yaml'; tag = 'agent=example'; runs = 5; stimuli = @('required-case') })
                        calibration = @(
                                [ordered]@{ id = 'positive'; specPath = 'spec.yaml'; stimulusName = 'required-case'; graderName = 'meaning'; expectedPass = $true; output = 'Synthetic positive' }
                                [ordered]@{ id = 'negative'; specPath = 'spec.yaml'; stimulusName = 'required-case'; graderName = 'meaning'; expectedPass = $false; output = 'Synthetic negative' }
                        )
                }
                $script:AcceptancePath = Join-Path $script:AcceptanceRoot 'profile.json'
        }
        It 'seals required checks while retaining selected healthy siblings and excluding synthetic text' {
                $script:AcceptanceProfile | ConvertTo-Json -Depth 10 | Set-Content $script:AcceptancePath
                $result = Get-VallyAcceptanceInventory -ProfilePath $script:AcceptancePath -EvalRoot $script:AcceptanceRoot
                $result.selections[0].requiredStimuli.Count | Should -Be 1
                $result.selections[0].expectedStimuli.Count | Should -Be 2
                $result.selections[0].requiredStimuli['required-case'].graders[0].name | Should -Be 'meaning'
                $result.profileDigest | Should -Match '^sha256:[a-f0-9]{64}$'
                ($result | ConvertTo-Json -Depth 30) | Should -Not -Match 'Synthetic positive|Synthetic negative'
        }
        It 'adds unchanged required owners while preserving existing delta metadata' {
            $inventory = @{ selections = @(@{ tag = 'agent=existing'; specPath = 'spec.yaml' }, @{ tag = 'agent=missing'; specPath = 'spec.yaml' }) }
            $artifact = [ordered]@{ kind = 'agent'; artifactId = 'existing'; status = 'M'; path = 'original.yaml' }
            $result = Merge-VallyAcceptanceArtifact -Artifact @($artifact) -Inventory $inventory
            $result.Count | Should -Be 2
            $result[0].path | Should -Be 'original.yaml'
            $result[1].artifactId | Should -Be 'missing'
            $result[1].path | Should -Be 'evals/spec.yaml'
        }
        It 'selects required owners for an empty delta' {
            $inventory = @{ selections = @(@{ tag = 'prompt=required'; specPath = 'spec.yaml' }) }
            $result = Merge-VallyAcceptanceArtifact -Artifact @() -Inventory $inventory
            $result.Count | Should -Be 1
            $result[0].kind | Should -Be 'prompt'
        }
        It 'rejects invalid profile boundary <Mutation>' -ForEach @(
                @{ Mutation = 'missing' }, @{ Mutation = 'duplicate' }, @{ Mutation = 'runs' },
                @{ Mutation = 'escape' }, @{ Mutation = 'judge' }, @{ Mutation = 'grader' },
                @{ Mutation = 'unpaired' }, @{ Mutation = 'duplicate-control' }, @{ Mutation = 'version' }
        ) {
                switch ($Mutation) {
                        'missing' { $script:AcceptanceProfile.selections[0].stimuli = @('absent') }
                        'duplicate' { $script:AcceptanceProfile.selections += $script:AcceptanceProfile.selections[0] }
                        'runs' { $script:AcceptanceProfile.selections[0].runs = 3 }
                        'escape' { $script:AcceptanceProfile.selections[0].specPath = '../spec.yaml' }
                        'judge' { $script:AcceptanceProfile.judgeModel = 'other' }
                        'version' { $script:AcceptanceProfile.vallyVersion = '0.0.0' }
                        'grader' { $script:AcceptanceProfile.calibration[0].graderName = 'absent' }
                        'unpaired' { $script:AcceptanceProfile.calibration[1].expectedPass = $true }
                        'duplicate-control' { $script:AcceptanceProfile.calibration[1].id = 'positive' }
                }
                $script:AcceptanceProfile | ConvertTo-Json -Depth 10 | Set-Content $script:AcceptancePath
                { Get-VallyAcceptanceInventory -ProfilePath $script:AcceptancePath -EvalRoot $script:AcceptanceRoot } | Should -Throw
        }
}

Describe 'VallyRunner module' -Tag 'Unit' {
    BeforeEach {
        $script:WorkRoot = Join-Path $TestDrive ('runner-' + [Guid]::NewGuid())
        New-Item -ItemType Directory -Path $script:WorkRoot -Force | Out-Null
    }

    Context 'Resolve-VallyRunDir' {
        It 'Returns $null when the output dir is missing' {
            (Resolve-VallyRunDir -OutputDir (Join-Path $script:WorkRoot 'missing')) | Should -BeNullOrEmpty
        }

        It 'Returns the newest timestamped subdirectory' {
            $outDir = Join-Path $script:WorkRoot 'out'
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null
            $older = New-Item -ItemType Directory -Path (Join-Path $outDir 'older') -Force
            $newer = New-Item -ItemType Directory -Path (Join-Path $outDir 'newer') -Force
            # Resolve-VallyRunDir sorts by LastWriteTime; set the timestamps
            # explicitly so ordering is deterministic regardless of filesystem
            # timestamp resolution on a loaded CI runner.
            $older.LastWriteTime = (Get-Date).AddMinutes(-5)
            $newer.LastWriteTime = (Get-Date)

            $resolved = Resolve-VallyRunDir -OutputDir $outDir
            $resolved | Should -Be $newer.FullName
            $resolved | Should -Not -Be $older.FullName
        }
    }

    Context 'Read-VallyResultsJsonl' {
        It 'Returns zero counts when the run dir is missing or null' {
            $result = Read-VallyResultsJsonl -RunDir ''
            $result.trials | Should -Be 0
            $result.assertionsPassed | Should -Be 0
            $result.assertionsFailed | Should -Be 0
            $result.resultsPath | Should -BeNullOrEmpty
        }

        It 'Returns zero counts when results.jsonl is absent' {
            $runDir = Join-Path $script:WorkRoot 'no-results'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $result = Read-VallyResultsJsonl -RunDir $runDir
            $result.trials | Should -Be 0
        }

        It 'Aggregates passed/failed counts and wall time from results.jsonl' {
            $runDir = Join-Path $script:WorkRoot 'run-1'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $rec1 = @{
                trajectory = @{ stimulus = @{ name = 's1' }; output = 'a'; metrics = @{ wallTimeMs = 10 } }
                gradeResult = @{ passed = $true }
            } | ConvertTo-Json -Depth 6 -Compress
            $rec2 = @{
                trajectory = @{ stimulus = @{ name = 's2' }; output = 'b'; metrics = @{ wallTimeMs = 15 } }
                gradeResult = @{ passed = $false }
            } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($rec1, $rec2) -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir
            $result.trials | Should -Be 2
            $result.assertionsPassed | Should -Be 1
            $result.assertionsFailed | Should -Be 1
            $result.durationMs | Should -Be 25
            $result.resultsPath | Should -Match 'results\.jsonl$'
        }

        It 'Treats a score above the configured threshold as passed even when gradeResult.passed is false' {
            $runDir = Join-Path $script:WorkRoot 'run-threshold'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $record = @{
                trajectory = @{ stimulus = @{ name = 'tool-trigger' }; output = 'customer-card-render'; metrics = @{ wallTimeMs = 20 } }
                gradeResult = @{ passed = $false; score = 0.6666666666666666; evidence = '2/3 graders passed' }
            } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($record) -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.6
            $result.trials | Should -Be 1
            $result.assertionsPassed | Should -Be 1
            $result.assertionsFailed | Should -Be 0
        }

        It 'Passes a stimulus whose mean trial score meets the threshold despite one dip' {
            $runDir = Join-Path $script:WorkRoot 'run-aggregate-pass'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $records = foreach ($score in @(1.0, 1.0, 1.0, 1.0, 0.0)) {
                @{
                    trajectory = @{ stimulus = @{ name = 'aggregate-stimulus' }; metrics = @{ wallTimeMs = 1 } }
                    gradeResult = @{ passed = ($score -ge 0.7); score = $score; details = @() }
                } | ConvertTo-Json -Depth 6 -Compress
            }
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value $records -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7
            $result.perStimulus['aggregate-stimulus'].aggregateScore | Should -Be 0.8
            $result.perStimulus['aggregate-stimulus'].aggregatePassed | Should -BeTrue
            $result.stimuliPassed | Should -Be 1
            $result.stimuliFailed | Should -Be 0
            $result.assertionsFailed | Should -Be 1
        }

        It 'Fails a stimulus whose mean trial score remains below the threshold' {
            $runDir = Join-Path $script:WorkRoot 'run-aggregate-fail'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $records = foreach ($score in @(0.6666666667, 0.6666666667, 0.6666666667, 0.6666666667, 0.6666666667)) {
                @{
                    trajectory = @{ stimulus = @{ name = 'aggregate-stimulus' }; metrics = @{ wallTimeMs = 1 } }
                    gradeResult = @{ passed = $false; score = $score; details = @() }
                } | ConvertTo-Json -Depth 6 -Compress
            }
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value $records -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7
            $result.perStimulus['aggregate-stimulus'].aggregatePassed | Should -BeFalse
            $result.stimuliPassed | Should -Be 0
            $result.stimuliFailed | Should -Be 1
        }

        It 'Treats a record without gradeResult as an errored trial (not failed)' {
            $runDir = Join-Path $script:WorkRoot 'run-missing-grade'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $record = @{
                trajectory = @{ stimulus = @{ name = 'missing-grade' }; output = 'ungrounded-output'; metrics = @{ wallTimeMs = 12 } }
            } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($record) -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir
            $result.trials | Should -Be 1
            $result.assertionsPassed | Should -Be 0
            $result.assertionsFailed | Should -Be 0
            $result.errored | Should -Be 1
            $result.durationMs | Should -Be 12
            $result.perStimulus['missing-grade'].trials | Should -Be 1
            $result.perStimulus['missing-grade'].errored | Should -Be 1
        }

        It 'Retains only safe failed and errored trial diagnostics' {
            $runDir = Join-Path $script:WorkRoot 'run-diagnostics'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $failedRecord = @{
                trajectory = @{ stimulus = @{ name = 'failed-stimulus' }; output = 'raw model output'; metrics = @{ wallTimeMs = 9 } }
                gradeResult = @{
                    passed = $false
                    score = 0.4
                    details = @(
                        @{ name = 'output-matches'; configuredName = 'required-marker'; kind = 'output-matches'; passed = $false; score = 0; evidence = 'raw evidence' }
                        @{ name = 'tool-calls'; configuredName = 'write-observed'; graderType = 'tool-calls'; passed = $true; score = 1; evidence = 'raw evidence' }
                    )
                }
            } | ConvertTo-Json -Depth 6 -Compress
            $erroredRecord = @{
                trajectory = @{ stimulus = @{ name = 'errored-stimulus' }; output = 'transient raw output' }
            } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($failedRecord, $erroredRecord) -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir

            $diagnostics = @($result.failedOrErroredTrials)
            $diagnostics | Should -HaveCount 2
            $diagnostics[0].ordinal | Should -Be 1
            $diagnostics[0].outcome | Should -Be 'failed'
            $diagnostics[0].stimulusName | Should -Be 'failed-stimulus'
            $diagnostics[0].score | Should -Be 0.4
            $diagnostics[0].passed | Should -BeFalse
            $diagnostics[0].errorState | Should -BeNullOrEmpty
            @($diagnostics[0].failedGraders) | Should -HaveCount 1
            $diagnostics[0].failedGraders[0].name | Should -Be 'required-marker'
            $diagnostics[0].failedGraders[0].graderType | Should -Be 'output-matches'
            $diagnostics[0].failedGraders[0].score | Should -Be 0
            $diagnostics[0].failedGraders[0].PSObject.Properties.Name | Should -Not -Contain 'evidence'
            $diagnostics[1].ordinal | Should -Be 2
            $diagnostics[1].outcome | Should -Be 'errored'
            $diagnostics[1].passed | Should -BeNullOrEmpty
            $diagnostics[1].errorState | Should -Be 'no-gradeable-verdict'
            $diagnostics[1].failedGraders | Should -BeNullOrEmpty
            $diagnostics[0].PSObject.Properties.Name | Should -Not -Contain 'trajectory'
            $diagnostics[0].PSObject.Properties.Name | Should -Not -Contain 'output'
            $diagnostics[0].PSObject.Properties.Name | Should -Not -Contain 'graderDetail'
        }

        It 'Retains configured checks inside a threshold-passing trial without private metadata' -Tag 'Diagnostic' {
            $runDir = Join-Path $script:WorkRoot 'run-all-checks'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $expectedStimuli = @{
                'configured-stimulus' = @{
                    runs = 1
                    graders = @(
                        @{ name = 'required-marker'; type = 'output-matches' }
                        @{ name = 'write-observed'; type = 'tool-calls' }
                    )
                }
            }
            $record = @{
                type = 'trial-result'
                trajectory = @{ stimulus = @{ name = 'configured-stimulus' }; output = 'synthetic-private-output' }
                gradeResult = @{
                    passed = $false
                    score = 0.75
                    evidence = 'synthetic-private-evidence'
                    details = @(
                        @{ configuredName = 'required-marker'; name = 'synthetic-private-name'; graderType = 'output-matches'; passed = $false; score = 0; metadata = @{ token = 'synthetic-private-token' } }
                        @{ configuredName = 'write-observed'; graderType = 'tool-calls'; passed = $true; score = 1 }
                    )
                }
            } | ConvertTo-Json -Depth 10 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value $record -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7 -ExpectedStimuli $expectedStimuli

            $result.assertionsPassed | Should -Be 1
            $result.assertionsFailed | Should -Be 0
            $result.failedOrErroredTrials | Should -BeNullOrEmpty
            @($result.trialDiagnostics) | Should -HaveCount 1
            $trial = $result.trialDiagnostics[0]
            $trial.stimulusName | Should -Be 'configured-stimulus'
            $trial.thresholdPassed | Should -BeTrue
            $trial.allGradersPassed | Should -BeFalse
            $trial.score | Should -Be 0.75
            $trial.gradeStatus | Should -Be 'success'
            $trial.trialIndex | Should -Be 0
            $trial.identitySource | Should -Be 'stimulus-trial-index'
            @($trial.graders) | Should -HaveCount 2
            $trial.graders[0].name | Should -Be 'required-marker'
            $trial.graders[0].graderType | Should -Be 'output-matches'
            $trial.graders[0].status | Should -Be 'success'
            $trial.graders[0].passed | Should -BeFalse
            ($result.trialDiagnostics | ConvertTo-Json -Depth 10) | Should -Not -Match 'synthetic-private'
        }

        It 'Projects bounded native completion evidence without response content' -Tag 'Diagnostic' {
            $runDir = Join-Path $script:WorkRoot 'native-completion'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            @{
                type = 'trial-result'; stimulus = 'native'; trialIndex = 0; status = 'success'
                trajectory = @{
                    stimulus = @{ name = 'native'; turns = @('first', 'second', 'third') }
                    endReason = 'agent_timeout'
                    output = 'synthetic-private-output'
                    metrics = @{ wallTimeMs = 123 }
                    events = @(
                        @{ type = 'assistant_message'; turn = 0; data = @{ content = 'synthetic-private-first' } }
                        @{ type = 'tool_call'; turn = 1; data = @{ toolName = 'synthetic-private-tool' } }
                    )
                }
                gradeResult = @{ status = 'success'; score = 1; passed = $true; details = @(
                    @{ configuredName = 'check'; graderType = 'program'; passed = $true; score = 1; status = 'success' }
                ) }
            } | ConvertTo-Json -Depth 10 -Compress | Set-Content (Join-Path $runDir 'results.jsonl')

            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7 -ExpectedStimuli @{
                native = @{ runs = 1; graders = @(@{ name = 'check'; type = 'program' }) }
            }

            $trial = $result.trialDiagnostics[0]
            $trial.endReason | Should -Be 'agent_timeout'
            $trial.configuredTurns | Should -Be 3
            $trial.observedTurns | Should -Be 2
            $trial.responseTurns | Should -Be 1
            $trial.wallTimeMs | Should -Be 123
            ($trial | ConvertTo-Json -Depth 10) | Should -Not -Match 'synthetic-private'
        }

        It 'Preserves native identity and classifies <Status> without leaking status text' -Tag 'Diagnostic' -ForEach @(
            @{ Status = 'error'; ExpectedStatus = 'error' }
            @{ Status = 'synthetic-private-status'; ExpectedStatus = 'invalid' }
        ) {
            $runDir = Join-Path $script:WorkRoot 'native-identity'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            @{
                type = 'trial-result'; itemId = 'synthetic-private-path::native::0'
                stimulus = 'native'; trialIndex = 0; totalTrials = 5; status = 'success'; trajectory = $null
                gradeResult = @{ status = $Status; score = 1; passed = $true; details = @(
                    @{ configuredName = 'check'; graderType = 'program'; passed = $true; score = 1; status = $Status }
                ) }
            } | ConvertTo-Json -Depth 10 -Compress | Set-Content (Join-Path $runDir 'results.jsonl')
            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7 -ExpectedStimuli @{
                native = @{ runs = 5; graders = @(@{ name = 'check'; type = 'program' }) }
            }
            $trial = $result.trialDiagnostics[0]
            $trial.stimulusName | Should -Be 'native'
            $trial.trialIndex | Should -Be 0
            $trial.identitySource | Should -Be 'native-item-id'
            $trial.itemIdDigest | Should -Be (Get-AgentEvalValueDigest -Value 'synthetic-private-path::native::0')
            $trial.gradeStatus | Should -Be $ExpectedStatus
            $trial.allGradersPassed | Should -BeFalse
            $trial.thresholdPassed | Should -BeTrue
            ($trial | ConvertTo-Json -Depth 10) | Should -Not -Match 'synthetic-private'
        }

        It 'Ignores typed non-trial records while accepting typed trial results' {
            $runDir = Join-Path $script:WorkRoot 'run-typed-summary'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $trial = @{
                type        = 'trial-result'
                trajectory  = @{ stimulus = @{ name = 'typed' }; output = 'ok'; metrics = @{ wallTimeMs = 9 } }
                gradeResult = @{ passed = $true; score = 1.0 }
            } | ConvertTo-Json -Depth 6 -Compress
            $summary = @{ type = 'run-summary'; passed = $true } | ConvertTo-Json -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($trial, $summary) -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7

            $result.trials | Should -Be 1
            $result.errored | Should -Be 0
            $result.assertionsPassed | Should -Be 1
        }

        It 'Skips malformed lines without throwing and retains their diagnostic category' -Tag 'Diagnostic' {
            $runDir = Join-Path $script:WorkRoot 'run-bad'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $good = @{ gradeResult = @{ passed = $true }; trajectory = @{ stimulus = @{ name = 's' } } } | ConvertTo-Json -Depth 4 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($good, '{not json', '') -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir
            $result.trials | Should -Be 1
            $result.assertionsPassed | Should -Be 1
            $result.recordIssues | Should -Contain 'malformed-record'
        }
    }

    Context 'Diagnostic configuration' {
        It 'Changes the input digest when an included source changes without exposing content' -Tag 'Diagnostic' {
            InModuleScope VallyRunner -Parameters @{ Root = $script:WorkRoot } {
                Mock git { $global:LASTEXITCODE = 0; @('source.txt') }
                Set-Content (Join-Path $Root 'source.txt') 'synthetic-private-first'
                $before = Get-VallyInputDigest -RepoRoot $Root
                Set-Content (Join-Path $Root 'source.txt') 'synthetic-private-second'
                $after = Get-VallyInputDigest -RepoRoot $Root
                $before | Should -Match '^sha256:[a-f0-9]{64}$'
                $after | Should -Match '^sha256:[a-f0-9]{64}$'
                $after | Should -Not -Be $before
                $after | Should -Not -Match 'synthetic-private|source.txt'
            }
        }

        It 'Separates <Case> integrity from the unchanged behavioral score' -Tag 'Diagnostic' -ForEach @(
            @{ Case = 'clean'; Expected = $true }
            @{ Case = 'duplicate'; Expected = $false }
            @{ Case = 'scored-error'; Expected = $false }
            @{ Case = 'malformed'; Expected = $false }
            @{ Case = 'missing-contract'; Expected = $false }
            @{ Case = 'poisoned-grader'; Expected = $false }
            @{ Case = 'wrong-mean'; Expected = $false }
            @{ Case = 'invalid-score'; Expected = $false }
            @{ Case = 'zero-output'; Expected = $false }
            @{ Case = 'extra-trial'; Expected = $false }
            @{ Case = 'missing-grader'; Expected = $false }
            @{ Case = 'empty-selection'; Expected = $true }
            @{ Case = 'clean-retry'; Expected = $true }
        ) {
            $inventory = [ordered]@{ synthetic = [ordered]@{ runs = 2; graders = @([ordered]@{ name = 'check'; type = 'program' }) } }
            $trials = @(0, 1 | ForEach-Object {
                [ordered]@{ stimulusName = 'synthetic'; trialIndex = $_; itemIdDigest = $null; identitySource = 'stimulus-trial-index'
                    executionStatus = 'success'; score = 1.0; thresholdPassed = $true; allGradersPassed = $true; gradeStatus = 'success'
                    graders = @([ordered]@{ name = 'check'; graderType = 'program'; score = 1.0; passed = $true; status = 'success' }) }
            })
            $attempt = [ordered]@{ runKey = 'synthetic.yaml'; ordinal = 1; selected = $true; selectionReason = 'fewest-errors-first-on-tie'; exitCategory = 'success'
                assertionsPassed = 2; assertionsFailed = 0; erroredTrials = 0; observedTrials = 2; recordIssues = @(); trials = $trials
                perStimulus = @([ordered]@{ stimulusName = 'synthetic'; expectedTrials = 2; observedTrials = 2; aggregateScore = 1.0; aggregatePassed = $true }) }
            $diagnostics = [ordered]@{ schemaVersion = '1.0.0'; runKey = 'synthetic.yaml'; configurationStatus = 'available'; specDigest = ('sha256:' + 'a' * 64); inputDigest = ('sha256:' + 'b' * 64)
                inputDigestScope = 'spec-only'; selectionDigest = (Get-AgentEvalValueDigest -Value $inventory); checkout = $null; executorModel = 'model'; judgeModels = @()
                versions = @{}; threshold = 0.7; expectedStimuli = $inventory; selectedAttempt = 1; attempts = @($attempt) }
            switch ($Case) {
                'duplicate' { $trials[1].trialIndex = 0 }
                'scored-error' { $trials[0].gradeStatus = 'error'; $trials[0].graders[0].status = 'error'; $trials[0].allGradersPassed = $false }
                'malformed' { $attempt.recordIssues = @('malformed-record') }
                'missing-contract' { $diagnostics.Remove('expectedStimuli') }
                'poisoned-grader' { $trials[0].graders[0]['rawOutput'] = 'synthetic-private' }
                'wrong-mean' { $attempt.perStimulus[0].aggregateScore = 0.8 }
                'invalid-score' { $trials[0].score = 'synthetic-private-score' }
                'zero-output' {
                    $attempt.trials = @(); $attempt.observedTrials = 0; $attempt.assertionsPassed = 0
                    $attempt.perStimulus[0].observedTrials = 0; $attempt.perStimulus[0].aggregateScore = $null; $attempt.perStimulus[0].aggregatePassed = $null
                }
                'extra-trial' { $attempt.trials += $trials[0] }
                'missing-grader' { $trials[0].graders = @(); $trials[0].allGradersPassed = $false }
                'empty-selection' {
                    $diagnostics.expectedStimuli = [ordered]@{}
                    $diagnostics.selectionDigest = Get-AgentEvalValueDigest -Value $diagnostics.expectedStimuli
                    $attempt.trials = @(); $attempt.perStimulus = @(); $attempt.observedTrials = 0; $attempt.assertionsPassed = 0
                }
                'clean-retry' {
                    $earlier = $attempt | ConvertTo-Json -Depth 20 | ConvertFrom-Json -AsHashtable -Depth 20
                    $earlier.selected = $false; $earlier.selectionReason = 'more-errors'
                    $earlier.assertionsPassed = 0; $earlier.erroredTrials = 2
                    foreach ($trial in $earlier.trials) {
                        $trial.executionStatus = 'error'; $trial.gradeStatus = 'missing'; $trial.score = $null
                        $trial.thresholdPassed = $null; $trial.allGradersPassed = $false
                        $trial.graders[0].status = 'missing'; $trial.graders[0].score = $null; $trial.graders[0].passed = $null
                    }
                    $earlier.perStimulus[0].aggregateScore = $null; $earlier.perStimulus[0].aggregatePassed = $null
                    $attempt.ordinal = 2; $diagnostics.selectedAttempt = 2; $diagnostics.attempts = @($earlier, $attempt)
                }
            }
            $result = Test-VallyDiagnosticEvidence -Diagnostics $diagnostics -RunKey 'synthetic.yaml'
            $result.integrityPassed | Should -Be $Expected
            $result.allChecksPassed | Should -Be $Expected
            if (-not $Expected) { $result.issues | Should -Not -BeNullOrEmpty }
        }

        It 'Uses configured identities and effective case-sensitive tag selection' -Tag 'Diagnostic' {
            $specPath = Join-Path $script:WorkRoot 'diagnostics.yaml'
            @{
                name = 'diagnostic-spec'
                defaults = @{ runs = 5; judge_model = 'declared-judge' }
                tags = @{ agent = 'selected' }
                stimuli = @(
                    @{ name = 'included'; prompt = 'synthetic'; graders = @(@{ name = 'authored'; type = 'output-matches' }, @{ type = 'tool-calls' }) }
                    @{ name = 'overridden'; prompt = 'synthetic'; tags = @{ agent = 'other' }; graders = @() }
                    @{ name = 'wrong-case'; prompt = 'synthetic'; tags = @{ agent = 'Selected' }; graders = @() }
                )
            } | ConvertTo-Yaml | Set-Content -LiteralPath $specPath -Encoding utf8

            $configuration = Get-VallyDiagnosticConfiguration -SpecPath $specPath -Tag 'agent=selected'

            $configuration.status | Should -Be 'available'
            @($configuration.stimuli.Keys) | Should -HaveCount 1
            $configuration.stimuli['included'].runs | Should -Be 5
            $configuration.stimuli['included'].graders[0].name | Should -Be 'authored'
            $configuration.stimuli['included'].graders[1].name | Should -Be 'tool-calls-1'
            $configuration.judgeModels | Should -Contain 'declared-judge'
            $configuration.selectionDigest | Should -Match '^sha256:[a-f0-9]{64}$'
        }
    }

    Context 'Selected evidence completeness' {
        It 'Rejects one graded pass and four executor errors without changing the behavioral mean' -Tag 'Diagnostic' {
            $runDir = Join-Path $script:WorkRoot 'low-sample'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $inventory = [ordered]@{ synthetic = [ordered]@{ runs = 5; graders = @([ordered]@{ name = 'check'; type = 'program' }) } }
            $records = @(foreach ($trialIndex in 0..4) {
                @{ type = 'trial-result'; stimulus = 'synthetic'; trialIndex = $trialIndex; status = $(if ($trialIndex -eq 0) { 'success' } else { 'error' })
                    trajectory = $null; gradeResult = $(if ($trialIndex -eq 0) {
                        @{ score = 1; passed = $true; details = @(@{ configuredName = 'check'; graderType = 'program'; score = 1; passed = $true }) }
                    } else { $null }) } | ConvertTo-Json -Depth 10 -Compress
            })
            Set-Content (Join-Path $runDir 'results.jsonl') $records
            $aggregate = Read-VallyResultsJsonl -RunDir $runDir -Threshold 0.7 -ExpectedStimuli $inventory
            $aggregate.perStimulus.synthetic.aggregateScore | Should -Be 1
            $aggregate.perStimulus.synthetic.aggregatePassed | Should -BeTrue
            $aggregate.errored | Should -Be 4
            $diagnostics = [ordered]@{ schemaVersion = '1.0.0'; runKey = 'synthetic.yaml'; configurationStatus = 'available'; specDigest = ('sha256:' + 'a' * 64); inputDigest = ('sha256:' + 'b' * 64)
                inputDigestScope = 'spec-only'; selectionDigest = (Get-AgentEvalValueDigest -Value $inventory); checkout = $null; executorModel = 'model'; judgeModels = @()
                versions = @{}; threshold = 0.7; expectedStimuli = $inventory; selectedAttempt = 1
                attempts = @([ordered]@{ runKey = 'synthetic.yaml'; ordinal = 1; selected = $true; selectionReason = 'fewest-errors-first-on-tie'; exitCategory = 'unknown'
                    assertionsPassed = 1; assertionsFailed = 0; erroredTrials = 4; observedTrials = 5; recordIssues = @(); trials = $aggregate.trialDiagnostics
                    perStimulus = @([ordered]@{ stimulusName = 'synthetic'; expectedTrials = 5; observedTrials = 5; aggregateScore = 1.0; aggregatePassed = $true }) }) }
            $evidence = Test-VallyDiagnosticEvidence -Diagnostics $diagnostics
            $evidence.contractValid | Should -BeTrue
            $evidence.integrityPassed | Should -BeFalse
            $evidence.issues | Should -Contain 'execution-error'
        }
    }

    Context 'Invoke-VallySpec (stub)' {
        It 'Emits a verifiable complete diagnostic contract using native-shaped records' -Tag 'DiagnosticIntegration' {
            $specPath = Join-Path $script:WorkRoot 'configured.yaml'
            @{
                name = 'configured'; defaults = @{ runs = 2 }; scoring = @{ threshold = 0.7 }
                stimuli = @(@{ name = 'synthetic'; prompt = 'synthetic'; graders = @(@{ name = 'check'; type = 'program' }) })
            } | ConvertTo-Yaml | Set-Content $specPath
            $env:STUB_VALLY_MODE = 'diagnostic'
            try {
                $result = Invoke-VallySpec -SpecPath $specPath -OutputDir (Join-Path $script:WorkRoot 'configured-output') `
                    -Model 'configured-model' -RunKey 'configured.yaml' -VallyCommand $script:StubPath -MaxErroredRetries 0
            }
            finally { Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue }
            $evidence = Test-VallyDiagnosticEvidence -Diagnostics $result.diagnostics -RunKey 'configured.yaml'
            $evidence.contractValid | Should -BeTrue
            $evidence.integrityPassed | Should -BeTrue
            $evidence.allChecksPassed | Should -BeTrue
            $result.diagnostics.versions.vally | Should -Be $script:InstalledVallyVersion
            $result.diagnostics.checkout | Should -Match '^[a-f0-9]{40}$'
            $trial = $result.diagnostics.attempts[0].trials[0]
            $trial.endReason | Should -Be 'completed'
            $trial.configuredTurns | Should -Be 1
            $trial.observedTurns | Should -Be 1
            $trial.responseTurns | Should -Be 1
            $trial.wallTimeMs | Should -Be 12
        }

        It 'Retains both attempts and selects <Selected> by errors rather than score' -Tag 'Diagnostic' -ForEach @(
            @{ Errors = @(1, 1); Selected = 1; Reason = 'later-tie' }
            @{ Errors = @(1, 0); Selected = 2; Reason = 'more-errors' }
        ) {
            InModuleScope VallyRunner -Parameters @{ Root = $script:WorkRoot; Errors = $Errors; Selected = $Selected; Reason = $Reason } {
                $script:DiagnosticAttempt = 0
                Mock Invoke-VallyProcess {
                    @{ ExitCode = 0; Worker = 'synthetic'; ElapsedMilliseconds = 1; ExitCategory = 'success' }
                }
                Mock Resolve-VallyRunDir { 'synthetic-run' }
                Mock Read-VallyResultsJsonl {
                    $current = $script:DiagnosticAttempt++
                    @{
                        assertionsPassed = $current; assertionsFailed = 1 - $current; errored = $Errors[$current]
                        durationMs = 1; trials = 2; stimuliPassed = $current; stimuliFailed = 1 - $current
                        resultsPath = 'synthetic-private-result'; perStimulus = @{}; failedOrErroredTrials = @(); trialDiagnostics = @(); recordIssues = @()
                    }
                }
                $result = Invoke-VallySpec -SpecPath (Join-Path $Root 'absent.yaml') -OutputDir (Join-Path $Root 'attempts') `
                    -Model 'configured-model' -RunKey 'spec.yaml|agent=synthetic' -MaxErroredRetries 1
                $result.diagnostics.selectedAttempt | Should -Be $Selected
                @($result.diagnostics.attempts) | Should -HaveCount 2
                @($result.diagnostics.attempts | Where-Object selected) | Should -HaveCount 1
                $discarded = @($result.diagnostics.attempts | Where-Object { -not $_.selected })[0]
                $discarded.selectionReason | Should -Be $Reason
                $result.diagnostics.attempts[0].runKey | Should -Be 'spec.yaml|agent=synthetic'
                ($result.diagnostics | ConvertTo-Json -Depth 20) | Should -Not -Match 'synthetic-private-result'
            }
        }

        It 'Returns aggregated counts after running the stub in pass mode' {
            $outDir = Join-Path $script:WorkRoot 'spec-pass'
            $env:STUB_VALLY_MODE = 'pass'
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'claude-opus-4.7' `
                    -VallyCommand $script:StubPath
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
            }

            $result.exitCode | Should -Be 0
            $result.trials | Should -Be 2
            $result.assertionsPassed | Should -Be 2
            $result.assertionsFailed | Should -Be 0
            $result.runDir | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath (Join-Path $result.runDir 'results.jsonl') | Should -BeTrue
            @($result.phaseTimings) | Should -HaveCount 1
            $result.phaseTimings[0].phase | Should -Be 'ordinary-eval'
            $result.phaseTimings[0].exitCategory | Should -Be 'success'
            $result.diagnostics.schemaVersion | Should -Be '1.0.0'
            $result.diagnostics.selectedAttempt | Should -Be 1
            @($result.diagnostics.attempts) | Should -HaveCount 1
            $result.diagnostics.attempts[0].selected | Should -BeTrue
            $result.diagnostics.attempts[0].selectionReason | Should -Be 'fewest-errors-first-on-tie'
        }

        It 'Propagates a non-zero exit code from the stub' {
            $outDir = Join-Path $script:WorkRoot 'spec-fail'
            $env:STUB_VALLY_MODE = 'fail'
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'claude-opus-4.7' `
                    -VallyCommand $script:StubPath
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
            }

            $result.exitCode | Should -Be 1
            $result.assertionsFailed | Should -Be 2
            $result.assertionsPassed | Should -Be 0
        }

        It 'Classifies no-verdict trials as errored and reports erroredTrials' {
            $outDir = Join-Path $script:WorkRoot 'spec-errored'
            $env:STUB_VALLY_MODE = 'errored'
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'claude-opus-4.7' `
                    -VallyCommand $script:StubPath `
                    -MaxErroredRetries 0
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
            }

            $result.erroredTrials | Should -Be 2
            $result.assertionsFailed | Should -Be 0
            $result.assertionsPassed | Should -Be 0
        }

        It 'Does not retry a typed run-summary as an errored trial' {
            $outDir = Join-Path $script:WorkRoot 'spec-typed-pass'
            $env:STUB_VALLY_MODE = 'typed-pass'
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'gpt-6-luna' `
                    -VallyCommand $script:StubPath
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
            }

            $result.trials | Should -Be 2
            $result.erroredTrials | Should -Be 0
            @(Get-ChildItem -LiteralPath $outDir -Directory).Count | Should -Be 1
        }

        It 'Tees stdout/stderr to the log file when -LogPath is supplied' {
            $outDir  = Join-Path $script:WorkRoot 'spec-log'
            $logPath = Join-Path $script:WorkRoot 'nested/log/run.log'
            $env:STUB_VALLY_MODE = 'pass'
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'claude-opus-4.7' `
                    -VallyCommand $script:StubPath `
                    -LogPath $logPath
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
            }

            $result.exitCode | Should -Be 0
            Test-Path -LiteralPath $logPath | Should -BeTrue
        }

        It 'withholds chatty child streams from public output' {
            $outDir = Join-Path $script:WorkRoot 'spec-chatty'
            $logPath = Join-Path $script:WorkRoot 'nested/log/chatty.log'
            $env:STUB_VALLY_MODE = 'chatty-pass'
            try {
                $publicOutput = @(& {
                        $script:ChattyResult = Invoke-VallySpec `
                            -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                            -OutputDir $outDir `
                            -Model 'gpt-6-luna' `
                            -VallyCommand $script:StubPath `
                            -LogPath $logPath
                    } 6>&1)
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
            }

            $script:ChattyResult.exitCode | Should -Be 0
            ($publicOutput -join "`n") | Should -Not -Match 'synthetic-private-stdout|synthetic-private-stderr'
            $withheld = Get-Content -LiteralPath $logPath -Raw
            $withheld | Should -Match 'synthetic-private-stdout'
            $withheld | Should -Match 'synthetic-private-stderr'
        }

        It 'Forwards tag and worker count while preserving progress worker identity' {
            $outDir   = Join-Path $script:WorkRoot 'spec-tag'
            $argvPath = Join-Path $script:WorkRoot 'spec-tag-argv.txt'
            $env:STUB_VALLY_MODE = 'pass'
            $env:STUB_VALLY_ARGV_OUT = $argvPath
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'claude-opus-4.7' `
                    -VallyCommand $script:StubPath `
                    -Tag 'agent=alpha' `
                    -Workers 3 `
                    -Worker 'agent-alpha' `
                    -HeartbeatIntervalSeconds 1
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
                Remove-Item Env:\STUB_VALLY_ARGV_OUT -ErrorAction SilentlyContinue
            }

            $result.exitCode | Should -Be 0
            $result.tag | Should -Be 'agent=alpha'
            $result.phaseTimings[0].worker | Should -Be 'agent-alpha'

            $argv = Get-Content -LiteralPath $argvPath
            $tagIndex = [array]::IndexOf($argv, '--tag')
            $tagIndex | Should -BeGreaterThan -1
            $argv[$tagIndex + 1] | Should -Be 'agent=alpha'
            $workersIndex = [array]::IndexOf($argv, '--workers')
            $workersIndex | Should -BeGreaterThan -1
            $argv[$workersIndex + 1] | Should -Be '3'
        }

        It 'Omits --tag and leaves the result tag empty when -Tag is not supplied' {
            $outDir   = Join-Path $script:WorkRoot 'spec-notag'
            $argvPath = Join-Path $script:WorkRoot 'spec-notag-argv.txt'
            $env:STUB_VALLY_MODE = 'pass'
            $env:STUB_VALLY_ARGV_OUT = $argvPath
            try {
                $result = Invoke-VallySpec `
                    -SpecPath (Join-Path $script:WorkRoot 'fake.yaml') `
                    -OutputDir $outDir `
                    -Model 'claude-opus-4.7' `
                    -VallyCommand $script:StubPath
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
                Remove-Item Env:\STUB_VALLY_ARGV_OUT -ErrorAction SilentlyContinue
            }

            $result.exitCode | Should -Be 0
            $result.tag | Should -BeNullOrEmpty

            $argv = Get-Content -LiteralPath $argvPath
            $argv | Should -Not -Contain '--tag'
            $workersIndex = [array]::IndexOf($argv, '--workers')
            $workersIndex | Should -BeGreaterThan -1
            $argv[$workersIndex + 1] | Should -Be '8'
        }
    }

    Context 'Test-SpecInputModeration (exit-code classification)' {
        BeforeEach {
            $script:StubModeration = Join-Path $PSScriptRoot 'fixtures/stub-moderation.ps1'
            $script:ModSpecPath = Join-Path $script:WorkRoot 'mod-spec.yaml'
            @(
                'stimuli:'
                '  - prompt: "first prompt"'
                '  - prompt: "second prompt"'
            ) -join "`n" | Set-Content -LiteralPath $script:ModSpecPath -Encoding utf8
        }

        AfterEach {
            Remove-Item Env:\STUB_MODERATION_EXIT -ErrorAction SilentlyContinue
            Remove-Item Env:\STUB_MODERATION_COUNT -ErrorAction SilentlyContinue
            Remove-Item Env:\STUB_MODERATION_FLAG_IDS -ErrorAction SilentlyContinue
            Remove-Item Env:\STUB_MODERATION_CAPTURE -ErrorAction SilentlyContinue
        }

        It 'Classifies a clean exit (0) as neither flagged nor error' {
            $env:STUB_MODERATION_EXIT = '0'
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeFalse
            $result.error | Should -BeFalse
        }

        It 'Classifies exit 1 as a genuine content flag, not an error' {
            $env:STUB_MODERATION_EXIT = '1'
            $env:STUB_MODERATION_COUNT = '1'
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeTrue
            $result.error | Should -BeFalse
        }

        It 'Classifies an infrastructure exit (>=2) as error, not a content flag' {
            $env:STUB_MODERATION_EXIT = '2'
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.error | Should -BeTrue
            $result.flagged | Should -BeFalse
        }

        It 'Treats higher infrastructure exit codes (>2) as error as well' {
            $env:STUB_MODERATION_EXIT = '3'
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.error | Should -BeTrue
            $result.flagged | Should -BeFalse
        }

        It 'Extracts stimulus prompts parsed from YAML (regression for hashtable key access)' {
            # ConvertFrom-Yaml returns a [hashtable]; the prior implementation
            # probed $spec.PSObject.Properties['stimuli'], which is always empty
            # on a hashtable, so stimuli were silently skipped and the
            # moderation script was never invoked. A non-null outputPath proves
            # the prompts were extracted and the moderation script ran.
            $env:STUB_MODERATION_EXIT = '0'
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.outputPath | Should -Not -BeNullOrEmpty
            Test-Path -LiteralPath $result.outputPath | Should -BeTrue
        }

        It 'Propagates flaggedCount from the moderation summary output' {
            $env:STUB_MODERATION_EXIT = '1'
            $env:STUB_MODERATION_COUNT = '2'
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flaggedCount | Should -Be 2
        }

        It 'Returns a non-flagged result when the spec file is missing' {
            $result = Test-SpecInputModeration `
                -SpecPath (Join-Path $script:WorkRoot 'no-such-spec.yaml') `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeFalse
            $result.flaggedCount | Should -Be 0
            $result.outputPath | Should -BeNullOrEmpty
        }

        It 'Skips moderation when the spec has no stimulus prompts' {
            $emptySpec = Join-Path $script:WorkRoot 'empty-spec.yaml'
            "model: claude-opus-4.7`nstimuli: []" | Set-Content -LiteralPath $emptySpec -Encoding utf8

            $result = Test-SpecInputModeration `
                -SpecPath $emptySpec `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeFalse
            $result.outputPath | Should -BeNullOrEmpty
        }

        It 'Reports an error when the moderation script cannot be invoked' {
            $result = Test-SpecInputModeration `
                -SpecPath $script:ModSpecPath `
                -ArtifactId 'unit' `
                -ModerationScript (Join-Path $script:WorkRoot 'does-not-exist.ps1') `
                -RepoRoot $script:WorkRoot

            $result.error | Should -BeTrue
            $result.flagged | Should -BeFalse
        }

    }

    Context 'Test-SpecOutputModeration (exit-code classification)' {
        BeforeEach {
            $script:StubModeration = Join-Path $PSScriptRoot 'fixtures/stub-moderation.ps1'
            $script:OutRunDir = Join-Path $script:WorkRoot 'out-run'
            New-Item -ItemType Directory -Path $script:OutRunDir -Force | Out-Null
            $rec1 = @{ trajectory = @{ stimulus = @{ name = 's1' }; output = 'first output' } } | ConvertTo-Json -Depth 6 -Compress
            $rec2 = @{ trajectory = @{ stimulus = @{ name = 's2' }; output = 'second output' } } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $script:OutRunDir 'results.jsonl') -Value @($rec1, $rec2) -Encoding utf8
        }

        AfterEach {
            Remove-Item Env:\STUB_MODERATION_EXIT -ErrorAction SilentlyContinue
            Remove-Item Env:\STUB_MODERATION_COUNT -ErrorAction SilentlyContinue
            Remove-Item Env:\STUB_MODERATION_FLAG_IDS -ErrorAction SilentlyContinue
            Remove-Item Env:\STUB_MODERATION_CAPTURE -ErrorAction SilentlyContinue
        }

        It 'Classifies a clean exit (0) as neither flagged nor error' {
            $env:STUB_MODERATION_EXIT = '0'
            $result = Test-SpecOutputModeration `
                -RunDir $script:OutRunDir `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeFalse
            $result.error | Should -BeFalse
        }

        It 'Classifies exit 1 as a genuine content flag, not an error' {
            $env:STUB_MODERATION_EXIT = '1'
            $env:STUB_MODERATION_COUNT = '1'
            $result = Test-SpecOutputModeration `
                -RunDir $script:OutRunDir `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeTrue
            $result.error | Should -BeFalse
            $result.flaggedCount | Should -Be 1
        }

        It 'Classifies an infrastructure exit (>=2) as error, not a content flag' {
            $env:STUB_MODERATION_EXIT = '2'
            $result = Test-SpecOutputModeration `
                -RunDir $script:OutRunDir `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.error | Should -BeTrue
            $result.flagged | Should -BeFalse
        }

        It 'Returns a non-flagged result when results.jsonl has no model outputs' {
            $emptyRunDir = Join-Path $script:WorkRoot 'out-run-empty'
            New-Item -ItemType Directory -Path $emptyRunDir -Force | Out-Null
            $noOutput = @{ trajectory = @{ stimulus = @{ name = 's1' } } } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $emptyRunDir 'results.jsonl') -Value @($noOutput) -Encoding utf8

            $result = Test-SpecOutputModeration `
                -RunDir $emptyRunDir `
                -ArtifactId 'unit' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $result.flagged | Should -BeFalse
            $result.outputPath | Should -BeNullOrEmpty
        }

        It 'Reports an error when the moderation script cannot be invoked' {
            $result = Test-SpecOutputModeration `
                -RunDir $script:OutRunDir `
                -ArtifactId 'unit' `
                -ModerationScript (Join-Path $script:WorkRoot 'does-not-exist.ps1') `
                -RepoRoot $script:WorkRoot

            $result.error | Should -BeTrue
            $result.flagged | Should -BeFalse
        }

        It 'Moderates multiple runs once and attributes flags by output id' {
            $secondRunDir = Join-Path $script:WorkRoot 'out-run-second'
            New-Item -ItemType Directory -Path $secondRunDir -Force | Out-Null
            $typedTrial = @{
                type       = 'trial-result'
                trajectory = @{ stimulus = @{ name = 's3' }; output = 'third output' }
            } | ConvertTo-Json -Depth 6 -Compress
            $typedSummary = @{ type = 'run-summary'; passed = $true } | ConvertTo-Json -Compress
            Set-Content -LiteralPath (Join-Path $secondRunDir 'results.jsonl') -Value @($typedTrial, $typedSummary) -Encoding utf8

            $capturePath = Join-Path $script:WorkRoot 'moderation-input.json'
            $env:STUB_MODERATION_CAPTURE = $capturePath
            $env:STUB_MODERATION_FLAG_IDS = 'output-2'
            $env:STUB_MODERATION_EXIT = '1'

            $result = Test-SpecOutputModerationBatch `
                -Run @(
                    @{ runKey = 'first'; runDir = $script:OutRunDir; threshold = 0.3 },
                    @{ runKey = 'second'; runDir = $secondRunDir; threshold = 0.9 }
                ) `
                -BatchId 'unit-batch' `
                -ModerationScript $script:StubModeration `
                -RepoRoot $script:WorkRoot

            $captured = @(Get-Content -LiteralPath $capturePath -Raw | ConvertFrom-Json)
            $captured.Count | Should -Be 3
            @($captured | Where-Object { $_.threshold -eq 0.3 }).Count | Should -Be 2
            @($captured | Where-Object { $_.threshold -eq 0.9 }).Count | Should -Be 1
            $result.byRun['first'].flagged | Should -BeFalse
            $result.byRun['second'].flagged | Should -BeTrue
            $result.byRun['second'].flaggedCount | Should -Be 1
        }
    }

    Context 'Get-VallySpecRunPlan' {
        It 'Runs a single-backlink spec untagged with runKey equal to specRel' {
            $plan = Get-VallySpecRunPlan `
                -Artifact @(
                    @{ kind = 'agent'; artifactId = 'solo'; path = 'a.md'; status = 'modified'; specs = @('specs/solo.yaml') }
                ) `
                -SpecBacklinkCount @{ 'specs/solo.yaml' = 1 } `
                -IndexRoot $script:WorkRoot

            $plan.uniqueSpecRuns.Keys | Should -Be 'specs/solo.yaml'
            $plan.uniqueSpecRuns['specs/solo.yaml'].tag | Should -BeNullOrEmpty
            $plan.uniqueSpecRuns['specs/solo.yaml'].specRel | Should -Be 'specs/solo.yaml'
            $plan.uniqueSpecRuns['specs/solo.yaml'].specAbs | Should -Be (Join-Path -Path $script:WorkRoot -ChildPath 'specs/solo.yaml')
            $plan.artifactPlan.Count | Should -Be 1
            $plan.artifactPlan[0].specRuns | Should -Be 'specs/solo.yaml'
            $plan.missingSpecs.Count | Should -Be 0
        }

        It 'Tags each artifact and emits one run per artifact when a spec is backlinked twice' {
            $plan = Get-VallySpecRunPlan `
                -Artifact @(
                    @{ kind = 'agent'; artifactId = 'alpha'; path = 'alpha.md'; status = 'modified'; specs = @('specs/shared.yaml') }
                    @{ kind = 'prompt'; artifactId = 'beta'; path = 'beta.md'; status = 'modified'; specs = @('specs/shared.yaml') }
                ) `
                -SpecBacklinkCount @{ 'specs/shared.yaml' = 2 } `
                -IndexRoot $script:WorkRoot

            $plan.uniqueSpecRuns.Count | Should -Be 2
            $plan.uniqueSpecRuns.ContainsKey('specs/shared.yaml|agent=alpha') | Should -BeTrue
            $plan.uniqueSpecRuns.ContainsKey('specs/shared.yaml|prompt=beta') | Should -BeTrue
            $plan.uniqueSpecRuns['specs/shared.yaml|agent=alpha'].tag | Should -Be 'agent=alpha'
            $plan.uniqueSpecRuns['specs/shared.yaml|prompt=beta'].tag | Should -Be 'prompt=beta'
            $plan.artifactPlan[0].specRuns | Should -Be 'specs/shared.yaml|agent=alpha'
            $plan.artifactPlan[1].specRuns | Should -Be 'specs/shared.yaml|prompt=beta'
        }

        It 'Deduplicates an identical runKey across artifacts into a single unique run' {
            $plan = Get-VallySpecRunPlan `
                -Artifact @(
                    @{ kind = 'agent'; artifactId = 'same'; path = 'a.md'; status = 'modified'; specs = @('specs/x.yaml') }
                    @{ kind = 'agent'; artifactId = 'same'; path = 'a.md'; status = 'modified'; specs = @('specs/x.yaml') }
                ) `
                -SpecBacklinkCount @{ 'specs/x.yaml' = 1 } `
                -IndexRoot $script:WorkRoot

            $plan.uniqueSpecRuns.Count | Should -Be 1
            $plan.uniqueSpecRuns.Keys | Should -Be 'specs/x.yaml'
        }

        It 'Collects artifacts with no covering spec into missingSpecs and excludes them from the plan' {
            $plan = Get-VallySpecRunPlan `
                -Artifact @(
                    @{ kind = 'agent'; artifactId = 'covered'; path = 'c.md'; status = 'modified'; specs = @('specs/c.yaml') }
                    @{ kind = 'agent'; artifactId = 'orphan'; path = 'o.md'; status = 'modified'; specs = @() }
                ) `
                -SpecBacklinkCount @{ 'specs/c.yaml' = 1 } `
                -IndexRoot $script:WorkRoot

            $plan.missingSpecs.Count | Should -Be 1
            $plan.missingSpecs[0].artifactId | Should -Be 'orphan'
            $plan.missingSpecs[0].path | Should -Be 'o.md'
            $plan.artifactPlan.Count | Should -Be 1
            $plan.artifactPlan[0].artifactId | Should -Be 'covered'
        }

        It 'Returns empty collections for an empty artifact set' {
            $plan = Get-VallySpecRunPlan `
                -Artifact @() `
                -SpecBacklinkCount @{} `
                -IndexRoot $script:WorkRoot

            $plan.uniqueSpecRuns.Count | Should -Be 0
            $plan.artifactPlan.Count | Should -Be 0
            $plan.missingSpecs.Count | Should -Be 0
        }
    }

    Context 'Get-VallySpecBacklinkCount' {
        It 'Returns an empty map when the index has no coverage key' {
            $counts = Get-VallySpecBacklinkCount -Index @{ root = $script:WorkRoot }
            $counts.Count | Should -Be 0
        }

        It 'Returns an empty map when coverage is null' {
            $counts = Get-VallySpecBacklinkCount -Index @{ coverage = $null }
            $counts.Count | Should -Be 0
        }

        It 'Counts a single coverage key as one backlink' {
            $counts = Get-VallySpecBacklinkCount -Index @{
                coverage = @{ 'skill:pr-reference' = @('specs/solo.yaml') }
            }
            $counts['specs/solo.yaml'] | Should -Be 1
        }

        It 'Tallies a spec backlinked by multiple coverage keys' {
            $counts = Get-VallySpecBacklinkCount -Index @{
                coverage = @{
                    'skill:pr-reference' = @('specs/shared.yaml')
                    'agent:sample-agent' = @('specs/shared.yaml')
                }
            }
            $counts['specs/shared.yaml'] | Should -Be 2
        }

        It 'Counts each spec independently when a coverage key maps to several specs' {
            $counts = Get-VallySpecBacklinkCount -Index @{
                coverage = @{
                    'agent:multi' = @('specs/a.yaml', 'specs/b.yaml')
                    'agent:other' = @('specs/b.yaml')
                }
            }
            $counts['specs/a.yaml'] | Should -Be 1
            $counts['specs/b.yaml'] | Should -Be 2
        }
    }
}

Describe 'Invoke-VallyEvals.ps1 entry script' -Tag 'Integration' {
    BeforeAll {
        function New-EvalFixture {
            param(
                [Parameter(Mandatory)][AllowEmptyCollection()][hashtable[]]$Artifacts,
                [Parameter(Mandatory)][AllowEmptyCollection()][hashtable[]]$Specs
            )

            $root = Join-Path $TestDrive ('case-' + [Guid]::NewGuid())
            New-Item -ItemType Directory -Path $root -Force | Out-Null

            $evalRoot = Join-Path $root 'evals'
            $logsDir  = Join-Path $root 'logs'
            New-Item -ItemType Directory -Path $evalRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $logsDir  -Force | Out-Null

            foreach ($spec in $Specs) {
                $specPath = Join-Path $evalRoot $spec.Name
                $specDir = Split-Path -Parent $specPath
                if (-not (Test-Path -LiteralPath $specDir)) {
                    New-Item -ItemType Directory -Path $specDir -Force | Out-Null
                }
                $configuration = $spec.Yaml | ConvertFrom-Yaml
                if ($configuration -is [System.Collections.IDictionary] -and $configuration.Contains('stimuli')) {
                    if (-not $configuration.Contains('defaults')) { $configuration.defaults = @{} }
                    if (-not $configuration.defaults.Contains('runs')) { $configuration.defaults.runs = 2 }
                    $fixtureYaml = $configuration | ConvertTo-Yaml
                }
                else { $fixtureYaml = $spec.Yaml }
                Set-Content -LiteralPath $specPath -Value $fixtureYaml -Encoding utf8
            }

            $manifestPath = Join-Path $root 'manifest.json'
            @{ artifacts = $Artifacts } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8
            $changedSpecManifestPath = Join-Path $root 'changed-spec.json'
            @{ artifacts = @() } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $changedSpecManifestPath -Encoding utf8

            return [pscustomobject]@{
                Root         = $root
                EvalRoot     = $evalRoot
                LogsDir      = $logsDir
                ManifestPath = $manifestPath
                ChangedSpecManifestPath = $changedSpecManifestPath
                SummaryPath  = Join-Path $logsDir 'eval-summary.json'
            }
        }
    }

    BeforeEach {
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_MODES_JSON -ErrorAction SilentlyContinue
    }

    It 'Exits 0 and writes an empty summary when the manifest has no artifacts' {
        $fx = New-EvalFixture -Artifacts @() -Specs @(@{ Name = 'noop.yaml'; Yaml = 'name: noop' })

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath *> $null
        $LASTEXITCODE | Should -Be 0

        Test-Path -LiteralPath $fx.SummaryPath | Should -BeTrue
        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 0
        $summary.totals.specs | Should -Be 0
        $summary.perArtifact.Count | Should -Be 0
    }

    It 'executes an empty canonical <Kind> shard without manufacturing ownership keys' -ForEach @(
        @{ Kind = 'instruction' }
        @{ Kind = 'skill' }
    ) {
        $fx = New-EvalFixture -Artifacts @() -Specs @(@{ Name = 'noop.yaml'; Yaml = 'name: noop' })
        $planPath = Join-Path $fx.Root 'agent-eval-plan.json'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1') `
            -ManifestPath $fx.ManifestPath `
            -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -EvalRoot $fx.EvalRoot `
            -OutputPath $planPath `
            -RepoRoot $fx.Root *> $null
        $LASTEXITCODE | Should -Be 0
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json -Depth 50
        $shard = @($plan.ordinaryShards | Where-Object { $_.kind -eq $Kind })[0]

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -PlanPath $planPath `
            -ShardId $shard.id `
            -Kind $Kind `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath *> $null

        $LASTEXITCODE | Should -Be 0
        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.producer | Should -Be $shard.id
        $summary.planDigest | Should -Be $plan.planDigest
        @($summary.perArtifact) | Should -HaveCount 0
        $summary.totals.artifacts | Should -Be 0
    }

    It 'Blocks <Case> selected evidence even for advisory stimuli' -Tag 'DiagnosticIntegration' -ForEach @(
        @{ Case = 'missing' }
        @{ Case = 'duplicate' }
        @{ Case = 'graded-errors' }
    ) {
        $spec = @{
            name = 'integrity'; defaults = @{ runs = 5 }; scoring = @{ threshold = 0.7 }
            stimuli = @(@{ name = 'synthetic'; prompt = 'synthetic'; tags = @{ skill = 'pr-reference'; advisory = 'true' }
                graders = @(@{ name = 'check'; type = 'program' }) })
        } | ConvertTo-Yaml
        $fx = New-EvalFixture -Artifacts @(@{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }) `
            -Specs @(@{ Name = 'integrity.yaml'; Yaml = $spec })
        $env:STUB_VALLY_MODE = 'diagnostic'
        $env:STUB_VALLY_DIAGNOSTIC_CASE = $Case
        try {
            & pwsh -NoProfile -File $script:ScriptPath -ManifestPath $fx.ManifestPath -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir -RepoRoot $fx.Root -VallyCommand $script:StubPath -SkipInputModeration -SkipOutputModeration *> $null
            $LASTEXITCODE | Should -Be 1
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE, Env:\STUB_VALLY_DIAGNOSTIC_CASE -ErrorAction SilentlyContinue
        }
        $summary = Get-Content -Raw $fx.SummaryPath | ConvertFrom-Json -Depth 50
        $summary.perSpec[0].status | Should -Be 'integrity-failure'
        $summary.perSpec[0].integrity.integrityPassed | Should -BeFalse
        $summary.perSpec[0].isAdvisory | Should -BeFalse
        $summary.perArtifact[0].status | Should -Be 'fail'
        $summary.totals.failedSpecs | Should -Be 1
        $summary.totals.assertionsFailed | Should -Be 0
    }

    It 'Exits 0 and aggregates passing trials per artifact' -Tag 'DiagnosticIntegration' {
        $spec = @'
name: skill-cover
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'skill-pr-reference.yaml'; Yaml = $spec })

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 1
        $summary.totals.specs | Should -Be 1
        $summary.totals.assertionsPassed | Should -Be 2
        $summary.totals.assertionsFailed | Should -Be 0
        $summary.totals.failedSpecs | Should -Be 0
        $summary.perArtifact[0].status | Should -Be 'pass'
        $summary.perArtifact[0].kind | Should -Be 'skill'
        $summary.perArtifact[0].artifactId | Should -Be 'pr-reference'

        $perArtifactFile = Join-Path $fx.LogsDir 'eval-results-skill-pr-reference.json'
        Test-Path -LiteralPath $perArtifactFile | Should -BeTrue
        $detail = Get-Content -LiteralPath $perArtifactFile -Raw | ConvertFrom-Json
        $detail.specs.Count | Should -Be 1
        $detail.specs[0].trials | Should -Be 2
        $detail.specs[0].diagnostics.schemaVersion | Should -Be '1.0.0'
        $summary.perSpec[0].diagnostics.runKey | Should -Be 'skill-pr-reference.yaml'
        @($summary.perSpec[0].diagnostics.attempts[0].trials) | Should -HaveCount 2
    }

    It 'Exits 1 when a spec fails, recording the failure per artifact' {
        $spec = @'
name: agent-cover
stimuli:
  - name: s1
    prompt: hi
    tags:
            agent: sample-agent
'@
        $artifacts = @(
                        @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
                $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent-sample-agent.yaml'; Yaml = $spec })

        $env:STUB_VALLY_MODE = 'fail'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.assertionsFailed | Should -Be 2
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perArtifact[0].status | Should -Be 'fail'
        $summary.perArtifact[0].assertionsFailed | Should -Be 2
        $summary.perArtifact[0].failedOrErroredTrials | Should -HaveCount 2

        $perArtifactFile = Join-Path $fx.LogsDir 'eval-results-agent-sample-agent.json'
        $detail = Get-Content -LiteralPath $perArtifactFile -Raw | ConvertFrom-Json
        $detail.failedOrErroredTrials | Should -HaveCount 2
        $detail.specs[0].failedOrErroredTrials | Should -HaveCount 2
        $detail.failedOrErroredTrials[0].PSObject.Properties.Name | Should -Not -Contain 'output'
        $detail.failedOrErroredTrials[0].PSObject.Properties.Name | Should -Not -Contain 'trajectory'
    }

    It 'Fails closed when Vally exits nonzero without a results file' {
        $spec = @'
name: advisory-cover
stimuli:
  - name: s1
    prompt: hi
    tags:
      instruction: sample-instruction
      advisory: true
'@
        $artifacts = @(
            @{ kind = 'instruction'; artifactId = 'sample-instruction'; path = '.github/instructions/hve-core/sample.instructions.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'instruction-sample.yaml'; Yaml = $spec })
        $noResultsCommand = Join-Path $fx.Root 'no-results.ps1'
        "param([Parameter(ValueFromRemainingArguments=`$true)]`$Arguments)`nexit 1" | Set-Content -LiteralPath $noResultsCommand -Encoding utf8

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $noResultsCommand `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'evaluator-error'
        $summary.perArtifact[0].status | Should -Be 'evaluator-error'
        $detail = Get-Content -LiteralPath (Join-Path $fx.LogsDir 'eval-results-instruction-sample-instruction.json') -Raw | ConvertFrom-Json
        $detail.specs[0].status | Should -Be 'evaluator-error'
        $detail.status | Should -Be 'evaluator-error'
    }

    It 'Exits 2 when a non-deleted artifact has no covering spec' {
        $spec = @'
name: unrelated
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: something-else
'@
        $artifacts = @(
            @{ kind = 'prompt'; artifactId = 'orphan'; path = '.github/prompts/hve-core/orphan.prompt.md'; status = 'A' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'unrelated.yaml'; Yaml = $spec })

        $output = & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath 2>&1
        $LASTEXITCODE | Should -Be 2

        $joined = $output -join "`n"
        $joined | Should -Match '::error file=.+orphan\.prompt\.md::No eval spec resolves prompt:orphan'
        $joined | Should -Match '::error::Cannot execute evals: 1 artifact\(s\) have no covering spec\.'
    }

    It 'Skips deleted artifacts and exits 0 when none remain' {
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'retired'; path = '.github/agents/hve-core/retired.agent.md'; status = 'D' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'noop.yaml'; Yaml = 'name: noop' })

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath *> $null
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 0
    }

    It 'executes exactly one canonical ordinary shard and stamps producer identity' {
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'beta'; path = '.github/agents/hve-core/beta.agent.md'; status = 'M' }
        )
        $specAlpha = "name: alpha`ndefaults:`n  runs: 1`nstimuli:`n  - name: alpha`n    prompt: hi`n    tags:`n      agent: alpha"
        $specBeta = "name: beta`ndefaults:`n  runs: 1`nstimuli:`n  - name: beta`n    prompt: hi`n    tags:`n      agent: beta"
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(
            @{ Name = 'alpha.yaml'; Yaml = $specAlpha }
            @{ Name = 'beta.yaml'; Yaml = $specBeta }
        )
        $planPath = Join-Path $fx.Root 'agent-eval-plan.json'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1') `
            -ManifestPath $fx.ManifestPath `
            -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -EvalRoot $fx.EvalRoot `
            -OutputPath $planPath `
            -RepoRoot $fx.Root *> $null
        $LASTEXITCODE | Should -Be 0
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json -Depth 50
        $shard = @($plan.ordinaryShards | Where-Object { @($_.artifacts) -contains 'agent:alpha' })[0]

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
                -PlanPath $planPath `
                -ShardId $shard.id `
                -Kind agent `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $LASTEXITCODE | Should -Be 0
        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.producer | Should -Be $shard.id
        $summary.planDigest | Should -Be $plan.planDigest
        @($summary.perArtifact) | Should -HaveCount 1
        $summary.perArtifact[0].artifactId | Should -Be 'alpha'
    }

    It 'executes one canonical <Kind> shard and stamps its planned producer identity' -ForEach @(
        @{ Kind = 'instruction'; ArtifactId = 'sample-instruction'; Path = '.github/instructions/test/sample-instruction.instructions.md' }
        @{ Kind = 'skill'; ArtifactId = 'sample-skill'; Path = '.github/skills/test/sample-skill/SKILL.md' }
    ) {
        $spec = "name: $ArtifactId`ndefaults:`n  runs: 1`nstimuli:`n  - name: $ArtifactId`n    prompt: hi`n    tags:`n      ${Kind}: $ArtifactId"
        $fx = New-EvalFixture `
            -Artifacts @(@{ kind = $Kind; artifactId = $ArtifactId; path = $Path; status = 'M' }) `
            -Specs @(@{ Name = "$Kind.yaml"; Yaml = $spec })
        $planPath = Join-Path $fx.Root 'agent-eval-plan.json'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1') `
            -ManifestPath $fx.ManifestPath `
            -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -EvalRoot $fx.EvalRoot `
            -OutputPath $planPath `
            -RepoRoot $fx.Root *> $null
        $LASTEXITCODE | Should -Be 0
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json -Depth 50
        $shard = @($plan.ordinaryShards | Where-Object { $_.kind -eq $Kind -and @($_.artifacts) -contains "${Kind}:$ArtifactId" })[0]

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
                -PlanPath $planPath `
                -ShardId $shard.id `
                -Kind $Kind `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $LASTEXITCODE | Should -Be 0
        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.producer | Should -Be $shard.id
        $summary.planDigest | Should -Be $plan.planDigest
        @($summary.perArtifact) | Should -HaveCount 1
        $summary.perArtifact[0].kind | Should -Be $Kind
        $summary.perArtifact[0].artifactId | Should -Be $ArtifactId
    }

    It 'rejects a matrix kind that differs from the canonical shard kind' {
        $artifactId = 'sample-instruction'
        $spec = "name: $artifactId`ndefaults:`n  runs: 1`nstimuli:`n  - name: $artifactId`n    prompt: hi`n    tags:`n      instruction: $artifactId"
        $fx = New-EvalFixture `
            -Artifacts @(@{ kind = 'instruction'; artifactId = $artifactId; path = '.github/instructions/test/sample-instruction.instructions.md'; status = 'M' }) `
            -Specs @(@{ Name = 'instruction.yaml'; Yaml = $spec })
        $planPath = Join-Path $fx.Root 'agent-eval-plan.json'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1') `
            -ManifestPath $fx.ManifestPath -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -EvalRoot $fx.EvalRoot -OutputPath $planPath -RepoRoot $fx.Root *> $null
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json -Depth 50
        $shard = @($plan.ordinaryShards | Where-Object { $_.kind -eq 'instruction' })[0]

        $output = & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -PlanPath $planPath -ShardId $shard.id -Kind skill `
            -EvalRoot $fx.EvalRoot -LogsDir $fx.LogsDir -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath -SkipInputModeration -SkipOutputModeration 2>&1

        $LASTEXITCODE | Should -Be 2
        $output -join "`n" | Should -Match "requires Kind 'instruction'"
    }

    It 'rejects manifest drift before canonical shard execution' {
        $spec = "name: alpha`ndefaults:`n  runs: 1`nstimuli:`n  - name: alpha`n    prompt: hi`n    tags:`n      agent: alpha"
        $fx = New-EvalFixture `
            -Artifacts @(@{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }) `
            -Specs @(@{ Name = 'alpha.yaml'; Yaml = $spec })
        $planPath = Join-Path $fx.Root 'agent-eval-plan.json'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1') `
            -ManifestPath $fx.ManifestPath -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -EvalRoot $fx.EvalRoot -OutputPath $planPath -RepoRoot $fx.Root *> $null
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json -Depth 50
        Add-Content -LiteralPath $fx.ManifestPath -Value ' ' -Encoding utf8

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -PlanPath $planPath -ShardId $plan.ordinaryShards[0].id -Kind agent `
            -EvalRoot $fx.EvalRoot -LogsDir $fx.LogsDir -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath -SkipInputModeration -SkipOutputModeration *> $null

        $LASTEXITCODE | Should -Be 2
    }

    It 'rejects re-signed duplicate ownership before canonical shard execution' {
        $spec = "name: alpha`ndefaults:`n  runs: 1`nstimuli:`n  - name: alpha`n    prompt: hi`n    tags:`n      agent: alpha"
        $fx = New-EvalFixture `
            -Artifacts @(@{ kind = 'agent'; artifactId = 'alpha'; path = '.github/agents/hve-core/alpha.agent.md'; status = 'M' }) `
            -Specs @(@{ Name = 'alpha.yaml'; Yaml = $spec })
        $planPath = Join-Path $fx.Root 'agent-eval-plan.json'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot '../../evals/New-AgentEvalPlan.ps1') `
            -ManifestPath $fx.ManifestPath -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -EvalRoot $fx.EvalRoot -OutputPath $planPath -RepoRoot $fx.Root *> $null
        $plan = Get-Content -LiteralPath $planPath -Raw | ConvertFrom-Json -Depth 50
        $duplicate = [pscustomobject][ordered]@{
            id = 'ordinary-02'
            expectedTrialWeight = $plan.ordinaryShards[0].expectedTrialWeight
            artifacts = @($plan.ordinaryShards[0].artifacts)
            runKeys = @($plan.ordinaryShards[0].runKeys)
        }
        $plan.ordinaryShards = @($plan.ordinaryShards) + @($duplicate)
        $payload = [ordered]@{
            schemaVersion = $plan.schemaVersion
            manifestDigests = [ordered]@{
                changedArtifacts = $plan.manifestDigests.changedArtifacts
                changedSpecs = $plan.manifestDigests.changedSpecs
            }
            baseline = [ordered]@{
                required = [bool]$plan.baseline.required
                reason = [string]$plan.baseline.reason
                models = @($plan.baseline.models)
            }
            ordinaryShards = @($plan.ordinaryShards)
            expectedProducers = @($plan.expectedProducers)
        }
        $plan.planDigest = Get-AgentEvalValueDigest -Value $payload
        $plan | ConvertTo-Json -Depth 50 | Set-Content -LiteralPath $planPath -Encoding utf8NoBOM

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath -ChangedSpecManifestPath $fx.ChangedSpecManifestPath `
            -PlanPath $planPath -ShardId 'ordinary-01' -Kind agent `
            -EvalRoot $fx.EvalRoot -LogsDir $fx.LogsDir -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath -SkipInputModeration -SkipOutputModeration *> $null

        $LASTEXITCODE | Should -Be 2
    }

    It 'Runs a shared spec once per artifact with a tag filter when multiple artifacts map to it' {
        $spec = @'
name: shared
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
  - name: s2
    prompt: hi
    tags:
      agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'shared.yaml'; Yaml = $spec })

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 2

        # A spec backlinked by two artifacts runs once per artifact with a
        # `kind=slug` tag filter so each artifact is scored only on its own stimuli.
        $summary.totals.specs | Should -Be 2
        $summary.perSpec.Count | Should -Be 2
        ($summary.perSpec.specPath | Sort-Object -Unique) | Should -Be 'shared.yaml'
        ($summary.perSpec.tag | Sort-Object) | Should -Be @('agent=sample-agent', 'skill=pr-reference')
    }

    It 'Totals assertions from unique spec runs instead of duplicated artifact rows' {
        $spec = @'
name: duplicate-artifact
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'duplicate-artifact.yaml'; Yaml = $spec })

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 2
        $summary.perSpec.Count | Should -Be 1
        $summary.perArtifact.Count | Should -Be 2
        $summary.totals.assertionsPassed | Should -Be 2
        $summary.totals.assertionsFailed | Should -Be 0
    }

    It 'Honors per-spec modes via STUB_VALLY_MODES_JSON for mixed outcomes' {
        $specA = @'
name: spec-a
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
'@
        $specB = @'
name: spec-b
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(
            @{ Name = 'spec-a.yaml'; Yaml = $specA },
            @{ Name = 'spec-b.yaml'; Yaml = $specB }
        )

        $env:STUB_VALLY_MODES_JSON = '{"spec-a.yaml":"pass","spec-b.yaml":"fail"}'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODES_JSON -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        ($summary.perArtifact | Where-Object { $_.artifactId -eq 'pr-reference' }).status | Should -Be 'pass'
        ($summary.perArtifact | Where-Object { $_.artifactId -eq 'sample-agent' }).status | Should -Be 'fail'
    }

    It 'Filters stimulus artifacts to the requested kind' {
        $specA = @'
name: spec-a
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
'@
        $specB = @'
name: spec-b
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(
            @{ Name = 'spec-a.yaml'; Yaml = $specA },
            @{ Name = 'spec-b.yaml'; Yaml = $specB }
        )

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -Kind skill `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 1
        $summary.perArtifact.Count | Should -Be 1
        $summary.perArtifact[0].kind | Should -Be 'skill'
        @($summary.kindFilter) | Should -Be @('skill')
    }

    It 'Exits 0 with an empty summary when no artifacts match the requested kind' {
        $spec = @'
name: skill-cover
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'skill-pr-reference.yaml'; Yaml = $spec })

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -Kind prompt `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.artifacts | Should -Be 0
        $summary.perArtifact.Count | Should -Be 0
        @($summary.kindFilter) | Should -Be @('prompt')
    }

    It 'Does not run baseline equivalence by default for agent artifacts' {
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $markerPath = Join-Path $fx.Root 'equivalence-called.txt'
        $equivalenceDriverPath = Join-Path $fx.Root 'fail-equivalence.ps1'
        $escapedMarkerPath = $markerPath.Replace("'", "''")
        $equivalenceDriver = @"
[CmdletBinding()]
param()

Set-Content -LiteralPath '$escapedMarkerPath' -Value 'called' -Encoding utf8
exit 9
"@
        Set-Content -LiteralPath $equivalenceDriverPath -Value $equivalenceDriver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $equivalenceDriverPath `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }
        $LASTEXITCODE | Should -Be 0
        Test-Path -LiteralPath $markerPath | Should -BeFalse

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        @($summary.equivalence).Count | Should -Be 0
    }

    It 'Reads the 2.0.0 equivalence contract and reports authoritative and advisory evidence separately' {
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'v2-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 12
    invariantFailures        = 0
    runHealthFailures        = 0
    divergenceGuardFailures  = 2
    dataQualityViolations    = 0
    equivalenceGate          = 'pass'
    documentedDivergenceGate = 'fail'
    verdict                  = 'fail'
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $entry = @($summary.equivalence)[0]
        $entry.trials | Should -Be 12
        $entry.verdict | Should -Be 'fail'
        $entry.equivalenceGate | Should -Be 'pass'
        $entry.documentedDivergenceGate | Should -Be 'fail'
        $entry.divergenceGuardFailures | Should -Be 2
        $entry.assertionsFailed | Should -Be 0
        $entry.advisoryAssertionsFailed | Should -Be 2
    }

    It 'Fails loudly on an unsupported equivalence contract version' {
        # The previous reader guarded every field against null over zero defaults, so a
        # renamed field silently produced runs=0 and verdict=unknown: a successful run
        # reported as an empty one. A version mismatch must be visible, not absorbed.
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'v1-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    runs               = 40
    aWins              = 1
    bWins              = 2
    invariantFailures  = 0
    divergenceFailures = 0
    verdict            = 'pass'
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $entry = @($summary.equivalence)[0]
        # A legacy summary must not read as a healthy run.
        $entry.verdict | Should -Be 'fail'
        $entry.trials | Should -Be 0
        # Reporting the failure is not enough: it has to count toward the job result,
        # otherwise the lane reports a contract mismatch and still exits green.
        $summary.totals.failedSpecs | Should -Be 1
    }

    It 'Counts a failing assertion toward failedSpecs even when the driver exits 0' {
        # The driver can complete cleanly while its own gates fail. Reading only the
        # exit code would let a failed equivalence gate pass the lane.
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'assertfail-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 10
    invariantFailures        = 3
    runHealthFailures        = 0
    divergenceGuardFailures  = 0
    dataQualityViolations    = 0
    equivalenceGate          = 'fail'
    documentedDivergenceGate = 'pass'
    verdict                  = 'fail'
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -EquivalenceTier ci `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        @($summary.equivalence)[0].assertionsFailed | Should -Be 3
        $summary.totals.failedSpecs | Should -Be 1
    }

    It 'Counts a nonzero driver exit toward failedSpecs even when no assertion failed' {
        # The mirror of the previous case: the driver can die before it measures
        # anything, reporting zero failures. Reading only assertion counts would let a
        # crashed run pass the lane.
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'crash-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 10
    invariantFailures        = 0
    runHealthFailures        = 0
    divergenceGuardFailures  = 0
    dataQualityViolations    = 0
    equivalenceGate          = 'pass'
    documentedDivergenceGate = 'pass'
    verdict                  = 'pass'
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 3
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -EquivalenceTier ci `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        @($summary.equivalence)[0].assertionsFailed | Should -Be 0
        @($summary.equivalence)[0].exitCode | Should -Be 3
        $summary.totals.failedSpecs | Should -Be 1
    }

    It 'Forwards calibration tier and keeps comparative guard failures advisory' {
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'calibration-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 120
    invariantFailures        = 0
    runHealthFailures        = 0
    divergenceGuardFailures  = 7
    dataQualityViolations    = 0
    equivalenceGate          = 'pass'
    documentedDivergenceGate = 'report-only'
    verdict                  = 'pass'
    receivedTier             = $Tier
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -EquivalenceTier calibration `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $entry = @($summary.equivalence)[0]
        $entry.tier | Should -Be 'calibration'
        $entry.assertionsFailed | Should -Be 0
        $entry.advisoryAssertionsFailed | Should -Be 7
        $summary.totals.failedSpecs | Should -Be 0
    }

    It 'Forwards the devloop tier and keeps a failing verdict advisory' {
        # This is the posture eval-validation.yml enables: the dispatch runs on every
        # eligible PR but must not gate, so a failing verdict is reported without
        # incrementing failedSpecs. The stub echoes its received tier so the
        # workflow argument is proven to reach the driver rather than assumed.
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'devloop-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 10
    invariantFailures        = 2
    runHealthFailures        = 0
    divergenceGuardFailures  = 0
    dataQualityViolations    = 0
    equivalenceGate          = 'warn'
    documentedDivergenceGate = 'pass'
    verdict                  = 'warn'
    receivedTier             = $Tier
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -EquivalenceTier devloop `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $equivPath = Join-Path $fx.LogsDir 'baseline-equivalence-sample-agent.json'
        (Get-Content -LiteralPath $equivPath -Raw | ConvertFrom-Json).receivedTier | Should -Be 'devloop'

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $entry = @($summary.equivalence)[0]
        $entry.tier | Should -Be 'devloop'
        $entry.assertionsFailed | Should -Be 2
        $summary.totals.failedSpecs | Should -Be 0
    }

    It 'Preserves a data-quality-only failure instead of reporting every trial passed' {
        # A structurally broken run can report dataQualityViolations as its only
        # nonzero counter. The dispatcher previously never read the field, so the
        # advisory tier summarized verdict fail alongside assertionsFailed 0 and all
        # ten trials counted as passed, which is unreadable exactly where the summary
        # is the only output the lane produces.
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'dataquality-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 10
    invariantFailures        = 0
    runHealthFailures        = 0
    divergenceGuardFailures  = 0
    dataQualityViolations    = 4
    equivalenceGate          = 'fail'
    documentedDivergenceGate = 'pass'
    verdict                  = 'fail'
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -EquivalenceTier devloop `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $entry = @($summary.equivalence)[0]
        $entry.dataQualityViolations | Should -Be 4
        $entry.assertionsFailed | Should -Be 4
        $entry.assertionsPassed | Should -Be 6
        $entry.verdict | Should -Be 'fail'
    }

    It 'Rejects a 2.x summary that omits dataQualityViolations' {
        # Absence must not read as zero. A summary claiming the 2.x contract while
        # dropping the field would hide the only evidence a structurally failed run
        # produces, which is the same silent-degradation defect the version check exists
        # to prevent.
        $spec = @'
name: agent-spec
stimuli:
  - name: s1
    prompt: hi
    tags:
        agent: sample-agent
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent.yaml'; Yaml = $spec })

        $driverPath = Join-Path $fx.Root 'missingfield-equivalence.ps1'
        $driver = @'
[CmdletBinding()]
param([string]$Agent, [string]$Tier, [string]$Model, [string]$RepoRoot, [string]$OutputPath)

$summary = [ordered]@{
    schemaVersion            = '2.0.0'
    runs                     = 10
    invariantFailures        = 0
    runHealthFailures        = 0
    divergenceGuardFailures  = 0
    equivalenceGate          = 'pass'
    documentedDivergenceGate = 'pass'
    verdict                  = 'pass'
}
$dir = Split-Path -Parent $OutputPath
if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
$summary | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding utf8
exit 0
'@
        Set-Content -LiteralPath $driverPath -Value $driver -Encoding utf8

        $env:STUB_VALLY_MODE = 'pass'
        try {
            & pwsh -NoProfile -File $script:ScriptPath `
                -ManifestPath $fx.ManifestPath `
                -EvalRoot $fx.EvalRoot `
                -LogsDir $fx.LogsDir `
                -RepoRoot $fx.Root `
                -VallyCommand $script:StubPath `
                -EquivalenceDriverPath $driverPath `
                -EnableBaselineEquivalence `
                -EquivalenceSubject 'sample-agent' `
                -EquivalenceTier devloop `
                -SkipInputModeration `
                -SkipOutputModeration *> $null
        }
        finally {
            Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        }

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        @($summary.equivalence)[0].verdict | Should -Be 'fail'
        $summary.totals.failedSpecs | Should -Be 1
    }
}

Describe 'Invoke-VallyEvals.ps1 moderation.threshold override' -Tag 'Integration' {
    BeforeAll {
        $script:RealRepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../../..')).Path
        $script:RealModerationScript = Join-Path $script:RealRepoRoot 'scripts/evals/Invoke-ContentModeration.ps1'
        $script:RealModerationRunner = Join-Path $script:RealRepoRoot 'scripts/evals/Modules/ModerationRunner.psm1'

        function New-ModerationFixture {
            param([Parameter(Mandatory)][string]$SpecThreshold)

            $root = Join-Path $TestDrive ('mod-' + [Guid]::NewGuid())
            $evalRoot = Join-Path $root 'evals'
            $logsDir  = Join-Path $root 'logs'
            $fakeScripts = Join-Path $root 'scripts/evals'
            $fakeModules = Join-Path $fakeScripts 'Modules'
            $fakeMod     = Join-Path $fakeScripts 'moderation'
            foreach ($d in @($evalRoot, $logsDir, $fakeScripts, $fakeModules, $fakeMod)) {
                New-Item -ItemType Directory -Path $d -Force | Out-Null
            }

            Copy-Item -LiteralPath $script:RealModerationScript -Destination $fakeScripts -Force
            Copy-Item -LiteralPath $script:RealModerationRunner -Destination $fakeModules -Force
            Set-Content -LiteralPath (Join-Path $fakeMod 'moderate.py') -Value '# placeholder' -Encoding utf8

            $specYaml = @"
name: skill-cover
defaults:
  executor: copilot-sdk
moderation:
  threshold: $SpecThreshold
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
    graders:
      - type: output-matches
        name: noop
        config: {pattern: '.*'}
"@
            Set-Content -LiteralPath (Join-Path $evalRoot 'skill-pr-reference.yaml') -Value $specYaml -Encoding utf8

            $artifacts = @(
                @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            )
            $manifestPath = Join-Path $root 'manifest.json'
            @{ artifacts = $artifacts } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8

            return [pscustomobject]@{
                Root         = $root
                EvalRoot     = $evalRoot
                LogsDir      = $logsDir
                ManifestPath = $manifestPath
                SummaryPath  = Join-Path $logsDir 'eval-summary.json'
            }
        }

        function New-PythonThresholdStub {
            $stubDir = Join-Path $TestDrive ('pystub-' + [Guid]::NewGuid().ToString('N'))
            New-Item -ItemType Directory -Path $stubDir -Force | Out-Null
            $markerPath = Join-Path $stubDir 'invocations.jsonl'

            $stubScript = Join-Path $stubDir 'python.ps1'
            $markerLiteral = $markerPath.Replace("'", "''")
@"
param([Parameter(ValueFromRemainingArguments=`$true)]`$Args)
`$inputIndex = [Array]::IndexOf(`$Args, '--input')
`$records = @()
if (`$inputIndex -ge 0) {
    `$records = @(Get-Content -LiteralPath `$Args[`$inputIndex + 1] | ForEach-Object { `$_ | ConvertFrom-Json })
}
`$rec = @{ args = @(`$Args | ForEach-Object { [string]`$_ }); records = @(`$records) } | ConvertTo-Json -Compress -Depth 6
Add-Content -LiteralPath '$markerLiteral' -Value `$rec -Encoding utf8
`$outIndex = [Array]::IndexOf(`$Args, '--output')
if (`$outIndex -ge 0) {
    `$outPath = `$Args[`$outIndex + 1]
    `$flagOutputs = `$env:HVE_TEST_MODERATION_FLAG -eq '1'
    `$outputRecords = @(`$records | ForEach-Object {
        [ordered]@{
            id = [string]`$_.id
            flagged = `$flagOutputs
            flaggedLabels = `$(if (`$flagOutputs) { @('toxicity') } else { @() })
        }
    })
    `$flaggedCount = if (`$flagOutputs) { `$outputRecords.Count } else { 0 }
    `$payload = @{
        records = `$outputRecords
        summary = @{ total = `$outputRecords.Count; flaggedCount = `$flaggedCount }
    } | ConvertTo-Json -Compress -Depth 6
    Set-Content -LiteralPath `$outPath -Value `$payload -Encoding utf8
    if (`$flagOutputs) { exit 1 }
}
exit 0
"@ | Set-Content -LiteralPath $stubScript -Encoding utf8

            $shim = Join-Path $stubDir 'python.cmd'
            "@pwsh -NoProfile -File `"$stubScript`" %*" | Set-Content -LiteralPath $shim -Encoding ascii

            return [pscustomobject]@{ Dir = $stubDir; MarkerPath = $markerPath; ScriptPath = $stubScript }
        }
    }

    BeforeEach {
        $script:OrigPath = $env:PATH
        $script:OrigModerationPython = $env:HVE_MODERATION_PYTHON
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\HVE_MODERATION_PYTHON -ErrorAction SilentlyContinue
        Remove-Item Env:\HVE_TEST_MODERATION_FLAG -ErrorAction SilentlyContinue
    }

    AfterEach {
        $env:PATH = $script:OrigPath
        if ($null -eq $script:OrigModerationPython) {
            Remove-Item Env:\HVE_MODERATION_PYTHON -ErrorAction SilentlyContinue
        }
        else {
            $env:HVE_MODERATION_PYTHON = $script:OrigModerationPython
        }
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\HVE_TEST_MODERATION_FLAG -ErrorAction SilentlyContinue
    }

    It 'Forwards per-spec moderation.threshold to Invoke-ContentModeration.ps1' {
        $fx = New-ModerationFixture -SpecThreshold '0.9'
        $stub = New-PythonThresholdStub
        $env:PATH = "$($stub.Dir);$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = $stub.ScriptPath
        $env:STUB_VALLY_MODE = 'pass'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -ModerationThreshold 0.5 `
            -VallyCommand $script:StubPath *> $null

        Test-Path -LiteralPath $stub.MarkerPath | Should -BeTrue
        $lines = Get-Content -LiteralPath $stub.MarkerPath
        $lines.Count | Should -BeGreaterOrEqual 1
        $thresholdsSeen = foreach ($line in $lines) {
            $rec = $line | ConvertFrom-Json
            $idx = [Array]::IndexOf($rec.args, '--threshold')
            if ($idx -ge 0) { [double]$rec.args[$idx + 1] }
        }
        $thresholdsSeen | Should -Contain 0.9
        $recordThresholds = foreach ($line in $lines) {
            $rec = $line | ConvertFrom-Json
            foreach ($record in @($rec.records)) {
                if ($record.PSObject.Properties.Name -contains 'threshold') { [double]$record.threshold }
            }
        }
        $recordThresholds | Should -Contain 0.9
    }

    It 'Falls back to default ModerationThreshold when spec omits override' {
        $fx = New-ModerationFixture -SpecThreshold '0.9'
        $specPath = Join-Path $fx.EvalRoot 'skill-pr-reference.yaml'
        $noOverride = @'
name: skill-cover
defaults:
  executor: copilot-sdk
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
    graders:
      - type: output-matches
        name: noop
        config: {pattern: '.*'}
'@
        Set-Content -LiteralPath $specPath -Value $noOverride -Encoding utf8

        $stub = New-PythonThresholdStub
        $env:PATH = "$($stub.Dir);$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = $stub.ScriptPath
        $env:STUB_VALLY_MODE = 'pass'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -ModerationThreshold 0.42 `
            -VallyCommand $script:StubPath *> $null

        Test-Path -LiteralPath $stub.MarkerPath | Should -BeTrue
        $lines = Get-Content -LiteralPath $stub.MarkerPath
        $thresholdsSeen = foreach ($line in $lines) {
            $rec = $line | ConvertFrom-Json
            $idx = [Array]::IndexOf($rec.args, '--threshold')
            if ($idx -ge 0) { [double]$rec.args[$idx + 1] }
        }
        $thresholdsSeen | Should -Contain 0.42
    }

    It 'Moderates outputs from distinct specs in one threshold-preserving batch' {
        $fx = New-ModerationFixture -SpecThreshold '0.9'
        $secondSpec = @'
name: skill-cover-two
defaults:
  executor: copilot-sdk
moderation:
  threshold: 0.4
stimuli:
  - name: s2
    prompt: hi
    tags:
      skill: hve-builder
    graders:
      - type: output-matches
        name: noop
        config: {pattern: '.*'}
'@
        Set-Content -LiteralPath (Join-Path $fx.EvalRoot 'skill-hve-builder.yaml') -Value $secondSpec -Encoding utf8
        @{
            artifacts = @(
                @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' },
                @{ kind = 'skill'; artifactId = 'hve-builder'; path = '.github/skills/hve-core/hve-builder/SKILL.md'; status = 'M' }
            )
        } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $fx.ManifestPath -Encoding utf8

        $stub = New-PythonThresholdStub
        $env:PATH = "$($stub.Dir);$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = $stub.ScriptPath
        $env:STUB_VALLY_MODE = 'pass'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -ModerationThreshold 0.5 `
            -VallyCommand $script:StubPath `
            -SkipInputModeration *> $null

        $LASTEXITCODE | Should -Be 0
        $lines = @(Get-Content -LiteralPath $stub.MarkerPath)
        $lines.Count | Should -Be 1
        $invocation = $lines[0] | ConvertFrom-Json
        $thresholds = @($invocation.records | ForEach-Object { [double]$_.threshold } | Sort-Object -Unique)
        @($thresholds | Where-Object { $_ -eq 0.4 }).Count | Should -BeGreaterThan 0
        @($thresholds | Where-Object { $_ -eq 0.9 }).Count | Should -BeGreaterThan 0
    }

    It 'Reconciles batched output flags into authoritative failure totals' -Tag 'IntegrityFixture' {
        $fx = New-ModerationFixture -SpecThreshold '0.9'
        $specPath = Join-Path $fx.EvalRoot 'skill-pr-reference.yaml'
        $authoritativeSpec = @'
name: skill-cover
defaults: { runs: 2, executor: copilot-sdk }
moderation:
  threshold: 0.9
stimuli:
  - name: s1
    prompt: hi
    tags:
      skill: pr-reference
      advisory: false
    graders:
      - type: output-matches
        name: noop
        config: {pattern: '.*'}
'@
        Set-Content -LiteralPath $specPath -Value $authoritativeSpec -Encoding utf8

        $stub = New-PythonThresholdStub
        $env:PATH = "$($stub.Dir);$($script:OrigPath)"
        $env:HVE_MODERATION_PYTHON = $stub.ScriptPath
        $env:HVE_TEST_MODERATION_FLAG = '1'
        $env:STUB_VALLY_MODE = 'pass'

        $runOutput = & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration 2>&1

        $LASTEXITCODE | Should -Be 1 -Because ($runOutput -join [Environment]::NewLine)
        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'content-moderation-output'
        $summary.perSpec[0].assertionsFailed | Should -Be 2
        $summary.perSpec[0].authoritativeFailed | Should -Be 2
        $summary.perSpec[0].advisoryFailed | Should -Be 0
    }
}

Describe 'Invoke-VallyEvals.ps1 per-stimulus advisory promotion' -Tag 'Integration' {
    BeforeAll {
        function New-PerStimFixture {
            param(
                [Parameter(Mandatory)][string]$SpecName,
                [Parameter(Mandatory)][string]$SpecYaml,
                [Parameter(Mandatory)][hashtable]$Artifact
            )

            $root = Join-Path $TestDrive ('perstim-' + [Guid]::NewGuid())
            $evalRoot = Join-Path $root 'evals'
            $logsDir  = Join-Path $root 'logs'
            New-Item -ItemType Directory -Path $evalRoot -Force | Out-Null
            New-Item -ItemType Directory -Path $logsDir  -Force | Out-Null

            $specFullPath = Join-Path $evalRoot $SpecName
            $specDir = Split-Path -Parent $specFullPath
            if (-not (Test-Path -LiteralPath $specDir)) {
                New-Item -ItemType Directory -Path $specDir -Force | Out-Null
            }
            Set-Content -LiteralPath $specFullPath -Value $SpecYaml -Encoding utf8

            $manifestPath = Join-Path $root 'manifest.json'
            @{ artifacts = @($Artifact) } | ConvertTo-Json -Depth 6 |
                Set-Content -LiteralPath $manifestPath -Encoding utf8

            return [pscustomobject]@{
                Root         = $root
                EvalRoot     = $evalRoot
                LogsDir      = $logsDir
                ManifestPath = $manifestPath
                SummaryPath  = Join-Path $logsDir 'eval-summary.json'
            }
        }
    }

    BeforeEach {
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_MODES_JSON -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_STIM_RESULTS_JSON -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_FAIL_ON_ANY -ErrorAction SilentlyContinue
    }

    AfterEach {
        Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_MODES_JSON -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_STIM_RESULTS_JSON -ErrorAction SilentlyContinue
        Remove-Item Env:\STUB_VALLY_FAIL_ON_ANY -ErrorAction SilentlyContinue
    }

    It 'Does not promote when only advisory stimuli fail' -Tag 'IntegrityRegression' {
        $spec = @'
name: skill-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
      skill: pr-reference
      advisory: true
  - name: stim-b
    prompt: hi
    tags:
      skill: pr-reference
      advisory: true
'@
        $fx = New-PerStimFixture `
            -SpecName 'advisory-only.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'per-stim'
        $env:STUB_VALLY_STIM_RESULTS_JSON = '{"stim-a":false,"stim-b":false}'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 0
        $summary.perSpec.Count | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'advisory-fail'
        $summary.perSpec[0].isAdvisory | Should -BeTrue
        $summary.perSpec[0].advisoryFailed | Should -Be 2
        $summary.perSpec[0].authoritativeFailed | Should -Be 0
        $summary.perArtifact[0].status | Should -Be 'advisory-fail'
        $summary.perArtifact[0].isAdvisory | Should -BeTrue
        $summary.perArtifact[0].advisoryFailed | Should -Be 2
        $summary.perArtifact[0].authoritativeFailed | Should -Be 0
    }

    It 'Blocks unidentified advisory evidence without reclassifying its behavioral failures' -Tag 'IntegrityRegression' {
        $spec = @'
name: skill-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
      skill: pr-reference
      advisory: true
'@
        $fx = New-PerStimFixture `
            -SpecName 'advisory-noname.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'fail-noname'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'integrity-failure'
        $summary.perSpec[0].advisoryFailed | Should -Be 2
        $summary.perSpec[0].authoritativeFailed | Should -Be 0
        $summary.perArtifact[0].status | Should -Be 'fail'
        $summary.perArtifact[0].advisoryFailed | Should -Be 2
        $summary.perArtifact[0].authoritativeFailed | Should -Be 0
    }

    It 'Promotes when an authoritative stimulus fails alongside an advisory one' {
        $spec = @'
name: skill-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
      skill: pr-reference
      advisory: true
  - name: stim-b
    prompt: hi
    tags:
      skill: pr-reference
'@
        $fx = New-PerStimFixture `
            -SpecName 'mixed-tags.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'per-stim'
        $env:STUB_VALLY_STIM_RESULTS_JSON = '{"stim-a":false,"stim-b":false}'
        $env:STUB_VALLY_FAIL_ON_ANY = '1'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'fail'
        $summary.perSpec[0].advisoryFailed | Should -Be 1
        $summary.perSpec[0].authoritativeFailed | Should -Be 1
        $summary.perSpec[0].isAdvisory | Should -BeFalse
        $summary.perArtifact[0].status | Should -Be 'fail'
        $summary.perArtifact[0].isAdvisory | Should -BeFalse
        $summary.perArtifact[0].authoritativeFailed | Should -Be 1
        $summary.perArtifact[0].advisoryFailed | Should -Be 1
    }

    It 'Gates authoritative trial failures even when vally exits 0' {
        # The harness threshold verdict is authoritative because --require-pass is absent.
        $spec = @'
name: skill-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
      skill: pr-reference
      advisory: true
  - name: stim-b
    prompt: hi
    tags:
      skill: pr-reference
'@
        $fx = New-PerStimFixture `
            -SpecName 'aggregate-pass.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'per-stim'
        $env:STUB_VALLY_STIM_RESULTS_JSON = '{"stim-a":false,"stim-b":false}'
        # No STUB_VALLY_FAIL_ON_ANY: vally exits 0 despite the failed trials.

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'fail'
        $summary.perSpec[0].authoritativeFailed | Should -Be 1
        $summary.perSpec[0].advisoryFailed | Should -Be 1
        $summary.perArtifact[0].status | Should -Be 'fail'
        $summary.perArtifact[0].authoritativeFailed | Should -Be 1
    }

    It 'Falls back to legacy spec-level advisory detection when no stimulus carries the tag' -Tag 'IntegrityFixture' {
        $spec = @'
name: agent-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
            agent: sample-agent
'@
        $configuration = $spec | ConvertFrom-Yaml
        $configuration.stimuli += @{ name = 'stim-b'; prompt = 'hi'; tags = @{ agent = 'sample-agent' } }
        $spec = $configuration | ConvertTo-Yaml
        $fx = New-PerStimFixture `
            -SpecName 'legacy.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'fail'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'fail'
        $summary.perSpec[0].isAdvisory | Should -BeFalse
        $summary.perSpec[0].authoritativeFailed | Should -Be 2
        $summary.perSpec[0].authoritativeStimuliFailed | Should -Be 2
        $summary.perSpec[0].advisoryFailed | Should -Be 0
        $summary.perSpec[0].toleratedFailed | Should -Be 0
    }

    It 'Gates a no-advisory spec on its own threshold verdict when vally exits 0' -Tag 'IntegrityFixture' {
        $spec = @'
name: agent-cover
defaults: { runs: 2 }
stimuli:
  - name: stim-a
    prompt: hi
    tags:
            agent: sample-agent
'@
        $fx = New-PerStimFixture `
            -SpecName 'no-advisory-aggregate-pass.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'mixed'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null
        $LASTEXITCODE | Should -Be 1

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 1
        $summary.totals.assertionsFailed | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'fail'
        $summary.perSpec[0].isAdvisory | Should -BeFalse
        $summary.perArtifact[0].status | Should -Be 'fail'
    }

    It 'Preserves <ExpectedStatus> for ordinary work alongside excluded baseline coverage' -Tag 'IntegrityRegression' -ForEach @(
        @{ Mode = 'pass'; Advisory = 'false'; ExpectedStatus = 'pass'; ExpectedExit = 0 }
        @{ Mode = 'fail'; Advisory = 'true'; ExpectedStatus = 'advisory-fail'; ExpectedExit = 0 }
        @{ Mode = 'fail'; Advisory = 'false'; ExpectedStatus = 'fail'; ExpectedExit = 1 }
        @{ Mode = 'crash'; Advisory = 'false'; ExpectedStatus = 'evaluator-error'; ExpectedExit = 1 }
    ) {
        $spec = [ordered]@{
            name = 'ordinary'
            stimuli = @(
                foreach ($stimulusName in @('stim-1', 'stim-2')) {
                    [ordered]@{
                        name = $stimulusName
                        prompt = 'hi'
                        tags = @{ agent = 'sample-agent'; advisory = $Advisory }
                    }
                }
            )
        } | ConvertTo-Yaml
        $fx = New-PerStimFixture `
            -SpecName 'ordinary.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }
        $baselineDir = Join-Path $fx.EvalRoot 'baseline-equivalence'
        New-Item -ItemType Directory -Path $baselineDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $baselineDir 'stimuli.yml') -Value $spec -Encoding utf8
        $env:STUB_VALLY_MODE = $Mode

        $runOutput = & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration 2>&1
        $LASTEXITCODE | Should -Be $ExpectedExit -Because ($runOutput -join [Environment]::NewLine)

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.perSpec.Count | Should -Be 1
        $summary.perSpec[0].status | Should -Be $ExpectedStatus
        $summary.perArtifact[0].status | Should -Be $ExpectedStatus
        $summary.perArtifact[0].specCount | Should -Be 1
        @($summary.perSpec | Where-Object { $_.specPath -match 'baseline-equivalence' }) | Should -BeNullOrEmpty
    }

    It 'Excludes a baseline-equivalence spec from the generic run plan' {
        # Stage 1 measures the equivalence corpus only through the dedicated harness,
        # which runs the full canonical population against a materialized customization
        # surface. Generic dispatch previously re-ran the same specs under a tag filter,
        # producing partial and zero-stimulus runs that reported success but could not
        # evidence equivalence. The spec must now be skipped entirely rather than run
        # and downgraded to advisory.
        $spec = @'
name: baseline-equivalence-stimuli
stimuli:
  - name: tool-trigger-list-scripts
    prompt: hi
    tags:
            agent: sample-agent
'@
        $fx = New-PerStimFixture `
            -SpecName 'baseline-equivalence/stimuli.yml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'sample-agent'; path = '.github/agents/hve-core/sample-agent.agent.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'fail'

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration `
            -SkipOutputModeration *> $null

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 0
        # The artifact still counts as covered, so the run does not fail for missing
        # coverage. It simply performs no generic baseline-equivalence execution.
        @($summary.perSpec | Where-Object { $_.specPath -match 'baseline-equivalence' }) | Should -BeNullOrEmpty
        $summary.totals.specs | Should -Be 0
        $summary.perArtifact[0].status | Should -Be 'skipped'
        $summary.perArtifact[0].specCount | Should -Be 0
    }
}

Describe 'Get-SpecStimulusAdvisoryMap tag scoping' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
        $script:MixedSpec = Join-Path $TestDrive 'mixed-agents.yaml'
        @'
name: agent-cover
stimuli:
- name: agent-a-stim-1
  prompt: hi
  tags:
    agent: agent-a
    advisory: "true"
- name: agent-a-stim-2
  prompt: hi
  tags:
    agent: agent-a
    advisory: "true"
- name: agent-b-authoritative
  prompt: hi
  tags:
    agent: agent-b
'@ | Set-Content -LiteralPath $script:MixedSpec -Encoding utf8
    }

    It 'Returns the full mixed map when no tag filter is supplied' {
        $map = Get-SpecStimulusAdvisoryMap -SpecPath $script:MixedSpec
        $map.Keys.Count | Should -Be 3
        $map['agent-a-stim-1'] | Should -BeTrue
        $map['agent-b-authoritative'] | Should -BeFalse
    }

    It 'Scopes posture to the tag-filtered agent so an all-advisory subset stays advisory' {
        $map = Get-SpecStimulusAdvisoryMap -SpecPath $script:MixedSpec -TagFilter 'agent=agent-a'
        $map.Keys.Count | Should -Be 2
        @($map.Values | Where-Object { -not $_ }).Count | Should -Be 0
    }

    It 'Falls back to the full set when the tag filter matches no stimulus' {
        $map = Get-SpecStimulusAdvisoryMap -SpecPath $script:MixedSpec -TagFilter 'agent=does-not-exist'
        $map.Keys.Count | Should -Be 3
    }
}

Describe 'Stage 1 equivalence dispatch boundary' -Tag 'Unit' {
    # The dispatcher schedules the dedicated baseline-equivalence harness and also
    # builds the generic Vally run plan. Both paths previously consumed backlinks
    # directly: the harness treated every backlinked agent as an equivalence subject,
    # and the generic plan re-ran the same specs as tag-filtered advisory evals. With
    # list-form backlinks now expanding correctly, an unbounded dispatcher would
    # schedule nine subjects against a corpus whose guards encode one agent's contract.
    BeforeAll {
        $script:DispatcherSource = Get-Content -LiteralPath (Resolve-Path (Join-Path $PSScriptRoot '../../evals/Invoke-VallyEvals.ps1')).Path -Raw
    }

    It 'Declares an explicit stage 1 equivalence subject default' {
        $script:DispatcherSource | Should -Match "EquivalenceSubject\s*=\s*@\(\s*'rpi-agent'\s*\)"
    }

    It 'Gates changed-artifact equivalence dispatch on the subject list' {
        $script:DispatcherSource | Should -Match 'EquivalenceSubjects -contains \$artifactId'
    }

    It 'Gates dependency-promoted equivalence dispatch on the subject list' {
        # Instruction, skill, and subagent changes promote parent agents through the
        # manifest. Without this gate the promotion path would reintroduce every
        # backlinked agent as an equivalence subject.
        $script:DispatcherSource | Should -Match 'EquivalenceSubjects -notcontains \$slug'
    }

    It 'Excludes baseline-equivalence specs from the generic run plan' {
        $script:DispatcherSource | Should -Match 'equivalenceRunKeys'
        $script:DispatcherSource | Should -Match "match '\(\^\|/\)baseline-equivalence/"
    }
}

Describe 'Stage 1 equivalence subject selection' -Tag 'Unit' {
    # Exercises the selection rule itself rather than the script text, so a future
    # refactor that keeps the constant but drops the filter still fails.
    BeforeAll {
        $script:Subjects = @('rpi-agent')
        $script:Backlinked = @(
            'backlog-manager', 'brd-builder', 'code-review', 'documentation',
            'issue-triage', 'prd-builder', 'rpi-agent'
        )
    }

    It 'Selects exactly one subject from the full backlinked set' {
        $selected = @($script:Backlinked | Where-Object { $script:Subjects -contains $_ })
        $selected.Count | Should -Be 1
        $selected[0] | Should -Be 'rpi-agent'
    }

    It 'Rejects a compound slug that a regressed parser could produce' {
        # 'documentation rpi-agent' was the observed corruption. It must not match the
        # subject list even though it contains the subject name as a substring.
        $script:Subjects -contains 'documentation rpi-agent' | Should -BeFalse
    }

    It 'Preserves every backlink record for stage 2 indexing' {
        $script:Backlinked.Count | Should -Be 7
    }
}
