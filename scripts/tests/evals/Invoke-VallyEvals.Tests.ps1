#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-VallyEvals.ps1'
    $script:RunnerModule = Join-Path $PSScriptRoot '../../evals/Modules/VallyRunner.psm1'
    $script:StubPath = Join-Path $PSScriptRoot 'fixtures/stub-vally.ps1'

    Import-Module $script:RunnerModule -Force
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Tests require the 'powershell-yaml' module to be installed."
    }
    Import-Module powershell-yaml -ErrorAction Stop
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

        It 'Skips malformed lines without throwing' {
            $runDir = Join-Path $script:WorkRoot 'run-bad'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $good = @{ gradeResult = @{ passed = $true }; trajectory = @{ stimulus = @{ name = 's' } } } | ConvertTo-Json -Depth 4 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($good, '{not json', '') -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir
            $result.trials | Should -Be 1
            $result.assertionsPassed | Should -Be 1
        }
    }

    Context 'Invoke-VallySpec (stub)' {
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
                    -Model 'gpt-5.6-luna' `
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

        It 'Forwards -Tag to the vally CLI as --tag and echoes it in the result' {
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
                    -Tag 'agent=alpha'
            }
            finally {
                Remove-Item Env:\STUB_VALLY_MODE -ErrorAction SilentlyContinue
                Remove-Item Env:\STUB_VALLY_ARGV_OUT -ErrorAction SilentlyContinue
            }

            $result.exitCode | Should -Be 0
            $result.tag | Should -Be 'agent=alpha'

            $argv = Get-Content -LiteralPath $argvPath
            $tagIndex = [array]::IndexOf($argv, '--tag')
            $tagIndex | Should -BeGreaterThan -1
            $argv[$tagIndex + 1] | Should -Be 'agent=alpha'
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
                    'agent:task-research' = @('specs/shared.yaml')
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
                Set-Content -LiteralPath $specPath -Value $spec.Yaml -Encoding utf8
            }

            $manifestPath = Join-Path $root 'manifest.json'
            @{ artifacts = $Artifacts } | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $manifestPath -Encoding utf8

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

    It 'Exits 0 and aggregates passing trials per artifact' {
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
    }

    It 'Exits 1 when a spec fails, recording the failure per artifact' {
        $spec = @'
name: agent-cover
stimuli:
  - name: s1
    prompt: hi
    tags:
      agent: task-research
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }
        )
        $fx = New-EvalFixture -Artifacts $artifacts -Specs @(@{ Name = 'agent-task-research.yaml'; Yaml = $spec })

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
      agent: task-research
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }
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
        ($summary.perSpec.tag | Sort-Object) | Should -Be @('agent=task-research', 'skill=pr-reference')
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
      agent: task-research
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }
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
        ($summary.perArtifact | Where-Object { $_.artifactId -eq 'task-research' }).status | Should -Be 'fail'
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
      agent: task-research
'@
        $artifacts = @(
            @{ kind = 'skill'; artifactId = 'pr-reference'; path = '.github/skills/shared/pr-reference/SKILL.md'; status = 'M' }
            @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }
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
      agent: task-research
'@
        $artifacts = @(
            @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }
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

    It 'Reconciles batched output flags into authoritative failure totals' {
        $fx = New-ModerationFixture -SpecThreshold '0.9'
        $specPath = Join-Path $fx.EvalRoot 'skill-pr-reference.yaml'
        $authoritativeSpec = @'
name: skill-cover
defaults:
  executor: copilot-sdk
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

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath `
            -SkipInputModeration *> $null

        $LASTEXITCODE | Should -Be 1
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

    It 'Does not promote when only advisory stimuli fail' {
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

    It 'Does not promote an all-advisory spec when results carry no per-stimulus name' {
        # Reproduces the CI advisory-leak: results.jsonl with failing trials but no
        # resolvable stimulus name leaves perStimulus empty, so attribution must
        # reconcile the failures as advisory rather than letting the exit-code
        # fallback gate the build.
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
        $LASTEXITCODE | Should -Be 0

        $summary = Get-Content -LiteralPath $fx.SummaryPath -Raw | ConvertFrom-Json
        $summary.totals.failedSpecs | Should -Be 0
        $summary.perSpec[0].status | Should -Be 'advisory-fail'
        $summary.perSpec[0].advisoryFailed | Should -Be 2
        $summary.perSpec[0].authoritativeFailed | Should -Be 0
        $summary.perArtifact[0].status | Should -Be 'advisory-fail'
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

    It 'Does not gate sub-threshold trial dips when the spec passes aggregate (exit 0)' {
        # An authoritative stimulus whose per-trial score dips but whose aggregate
        # still meets threshold (vally exit 0) must not gate: the failure is
        # sub-threshold noise, demoted to advisory.
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
        # No STUB_VALLY_FAIL_ON_ANY: vally exits 0 (aggregate passed).

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
        $summary.perSpec[0].status | Should -Be 'advisory-fail'
        $summary.perSpec[0].authoritativeFailed | Should -Be 0
        $summary.perSpec[0].advisoryFailed | Should -Be 2
        $summary.perArtifact[0].status | Should -Be 'advisory-fail'
        $summary.perArtifact[0].authoritativeFailed | Should -Be 0
    }

    It 'Falls back to legacy spec-level advisory detection when no stimulus carries the tag' {
        $spec = @'
name: agent-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
      agent: task-research
'@
        $fx = New-PerStimFixture `
            -SpecName 'legacy.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }

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
        $summary.perSpec[0].PSObject.Properties.Name | Should -Not -Contain 'authoritativeFailed'
        $summary.perSpec[0].PSObject.Properties.Name | Should -Not -Contain 'advisoryFailed'
    }

    It 'Does not gate a no-advisory spec when vally exits 0 despite a per-trial dip' {
        # Regression: a spec with no advisory-tagged stimulus (for example
        # baseline-equivalence/stimuli.yml resolved via an agent tag) must not gate
        # the build on a sub-threshold per-trial dip when vally reports an aggregate
        # pass (exit 0). The 'mixed' stub mode emits one passing and one failing
        # trial and exits 0.
        $spec = @'
name: agent-cover
stimuli:
  - name: stim-a
    prompt: hi
    tags:
      agent: task-research
'@
        $fx = New-PerStimFixture `
            -SpecName 'no-advisory-aggregate-pass.yaml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'mixed'

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
        $summary.totals.assertionsFailed | Should -Be 1
        $summary.perSpec[0].status | Should -Be 'advisory-fail'
        $summary.perSpec[0].isAdvisory | Should -BeFalse
        $summary.perArtifact[0].status | Should -Be 'advisory-fail'
    }

    It 'Treats a tag-resolved baseline-equivalence spec as advisory even on a hard vally failure' {
        # Per DD-01 the equivalence corpus is advisory at PR tier. Its stimuli are
        # tag-resolved into the authoritative path and run at a perfect-score
        # threshold against a small model, so a hard vally failure (exit 1) on a
        # single grader must surface as advisory rather than gate the build.
        $spec = @'
name: baseline-equivalence-stimuli
stimuli:
  - name: tool-trigger-list-scripts
    prompt: hi
    tags:
      agent: task-research
'@
        $fx = New-PerStimFixture `
            -SpecName 'baseline-equivalence/stimuli.yml' `
            -SpecYaml $spec `
            -Artifact @{ kind = 'agent'; artifactId = 'task-research'; path = '.github/agents/hve-core/task-research.agent.md'; status = 'M' }

        $env:STUB_VALLY_MODE = 'fail'

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
        $summary.perSpec[0].status | Should -Be 'advisory-fail'
        $summary.perSpec[0].isAdvisory | Should -BeTrue
        $summary.perArtifact[0].status | Should -Be 'advisory-fail'
        $summary.perArtifact[0].isAdvisory | Should -BeTrue
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

