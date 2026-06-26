#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
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

        It 'Treats a record without gradeResult as a failed trial' {
            $runDir = Join-Path $script:WorkRoot 'run-missing-grade'
            New-Item -ItemType Directory -Path $runDir -Force | Out-Null
            $record = @{
                trajectory = @{ stimulus = @{ name = 'missing-grade' }; output = 'ungrounded-output'; metrics = @{ wallTimeMs = 12 } }
            } | ConvertTo-Json -Depth 6 -Compress
            Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value @($record) -Encoding utf8

            $result = Read-VallyResultsJsonl -RunDir $runDir
            $result.trials | Should -Be 1
            $result.assertionsPassed | Should -Be 0
            $result.assertionsFailed | Should -Be 1
            $result.durationMs | Should -Be 12
            $result.perStimulus['missing-grade'].trials | Should -Be 1
            $result.perStimulus['missing-grade'].assertionsFailed | Should -Be 1
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

        & pwsh -NoProfile -File $script:ScriptPath `
            -ManifestPath $fx.ManifestPath `
            -EvalRoot $fx.EvalRoot `
            -LogsDir $fx.LogsDir `
            -RepoRoot $fx.Root `
            -VallyCommand $script:StubPath *> $null
        $LASTEXITCODE | Should -Be 2
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

    It 'Runs a shared spec only once when multiple artifacts map to it' {
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
        $summary.totals.specs | Should -Be 1
        $summary.perSpec.Count | Should -Be 1
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
`$rec = @{ args = @(`$Args | ForEach-Object { [string]`$_ }) } | ConvertTo-Json -Compress -Depth 3
Add-Content -LiteralPath '$markerLiteral' -Value `$rec -Encoding utf8
`$outIndex = [Array]::IndexOf(`$Args, '--output')
if (`$outIndex -ge 0) {
    `$outPath = `$Args[`$outIndex + 1]
    `$payload = '{"records":[],"summary":{"total":0,"flaggedCount":0}}'
    Set-Content -LiteralPath `$outPath -Value `$payload -Encoding utf8
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
        $thresholdsSeen | Should -Not -Contain 0.5
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

            Set-Content -LiteralPath (Join-Path $evalRoot $SpecName) -Value $SpecYaml -Encoding utf8

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
}
