#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ScriptPath = Join-Path $PSScriptRoot '../../evals/Invoke-BaselineEquivalence.ps1'
    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..') | Select-Object -ExpandProperty Path
}

Describe 'Invoke-BaselineEquivalence.ps1 (dry-run)' -Tag 'Unit' {
    BeforeEach {
        $script:OutputPath = Join-Path $TestDrive "summary-$([Guid]::NewGuid()).json"
    }

    Context 'Unsupported subject preflight' {
        It 'Refuses an unsupported agent before any model-backed execution' {
            # Parameter binding fails, so the script body never runs and no vally
            # invocation can occur for a subject this corpus cannot score.
            {
                & $script:ScriptPath `
                    -Agent 'not-a-real-agent' `
                    -Tier 'devloop' `
                    -RepoRoot $script:RepoRoot `
                    -OutputPath $script:OutputPath `
                    -WhatIf *> $null
            } | Should -Throw

            Test-Path -LiteralPath $script:OutputPath | Should -BeFalse
        }

        It 'Accepts the only supported subject' {
            {
                & $script:ScriptPath `
                    -Agent 'rpi-agent' `
                    -Tier 'devloop' `
                    -RepoRoot $script:RepoRoot `
                    -OutputPath $script:OutputPath `
                    -WhatIf *> $null
            } | Should -Not -Throw
        }
    }

    Context 'Devloop tier defaults' {
        BeforeEach {
            & $script:ScriptPath `
                -Tier 'devloop' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        }

        It 'Exits with code 0' {
            $LASTEXITCODE | Should -Be 0
        }

        It 'Writes a summary JSON to the requested path' {
            Test-Path -LiteralPath $script:OutputPath | Should -BeTrue
        }

        It 'Records the agent slug' {
            $script:Summary.agent | Should -Be 'rpi-agent'
        }

        It 'Records tier=devloop' {
            $script:Summary.tier | Should -Be 'devloop'
        }

        It 'Selects exactly one PR-tier model' {
            $script:Summary.model | Should -Not -BeNullOrEmpty
            $script:Summary.plannedCommands.Count | Should -Be 3
        }

        It 'Includes workspace and skill-dir flags for baseline and customized runs' {
            $baselineCommand = $script:Summary.plannedCommands[0]
            $customizedCommand = $script:Summary.plannedCommands[1]

            $baselineCommand | Should -Match '--workspace'
            $baselineCommand | Should -Match '--skill-dir'
            $customizedCommand | Should -Match '--workspace'
            $customizedCommand | Should -Match '--skill-dir'
        }

        It 'Isolates the baseline run with empty workspace and skill-dir arguments' {
            $baselineCommand = $script:Summary.plannedCommands[0]

            $baselineCommand | Should -Match '--workspace ""'
            $baselineCommand | Should -Match '--skill-dir ""'
        }

        It 'Points the customized run at populated workspace and skill-dir paths' {
            $customizedCommand = $script:Summary.plannedCommands[1]

            $customizedCommand | Should -Match '--workspace "[^"]+"'
            # The customized skill directory is materialized per agent under the run
            # output root. Pointing it at the whole .github/skills tree would load every
            # skill for every agent, so two different agents would produce identical
            # customized runs and the comparison could not distinguish them.
            $customizedCommand | Should -Match '--skill-dir "[^"]+customized-skill-dir"'
            $customizedCommand | Should -Not -Match '--skill-dir "[^"]*\.github[/\\]skills"'
        }

        It 'Reports zeroed run/aggregate counters' {
            $script:Summary.runs | Should -Be 0
            $script:Summary.ties | Should -Be 0
            $script:Summary.baselineWins | Should -Be 0
            $script:Summary.treatmentWins | Should -Be 0
            $script:Summary.invariantFailures | Should -Be 0
            $script:Summary.runHealthFailures | Should -Be 0
            $script:Summary.divergenceGuardFailures | Should -Be 0
        }

        It 'Declares the reporting contract version' {
            # Consumers reject an unsupported major version rather than reading absent
            # fields as zeros, so the dry-run summary must carry it too.
            $script:Summary.schemaVersion | Should -Be '2.1.0'
        }

        It 'Carries no legacy A/B keys' {
            $script:Summary.PSObject.Properties.Name | Should -Not -Contain 'aWins'
            $script:Summary.PSObject.Properties.Name | Should -Not -Contain 'bWins'
            $script:Summary.PSObject.Properties.Name | Should -Not -Contain 'divergenceFailures'
        }

        It 'Sets verdict to dry-run' {
            $script:Summary.verdict | Should -Be 'dry-run'
        }

        It 'Records variant metadata for baseline (A) and customized (B)' {
            $script:Summary.variants | Should -Not -BeNullOrEmpty
            $script:Summary.variants.a | Should -Not -BeNullOrEmpty
            $script:Summary.variants.b | Should -Not -BeNullOrEmpty
            $script:Summary.variants.a.kind | Should -Be 'baseline'
            $script:Summary.variants.b.name | Should -Be 'rpi-agent'
            $script:Summary.variants.subject | Should -Be 'rpi-agent'
        }
    }

    Context 'CI tier expansion' {
        BeforeEach {
            & $script:ScriptPath `
                -Agent 'rpi-agent' `
                -Tier 'ci' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        }

        It 'Records tier=ci' {
            $script:Summary.tier | Should -Be 'ci'
        }

        It 'Plans commands for two ci models' {
            $script:Summary.plannedCommands.Count | Should -Be 6
        }

        It 'Selects gpt-5.6-luna as the primary ci model' {
            $script:Summary.model | Should -Be 'gpt-5.6-luna'
        }

        It 'Gives every model its own customized skill directory' {
            # The sweep materializes a surface per model. Reusing the first model's
            # directory for the second would evaluate it against a surface it
            # did not build, so the comparison would not be attributable to the model.
            $customized = @($script:Summary.plannedCommands | Where-Object { $_ -match 'customized/eval\.yaml' })
            $customized.Count | Should -Be 2
            foreach ($model in @('gpt-5.6-luna', 'claude-sonnet-4.6')) {
                $line = @($customized | Where-Object { $_ -match "--model $([regex]::Escape($model)) " })
                $line.Count | Should -Be 1
                $line[0] | Should -Match "--skill-dir [^ ]*$([regex]::Escape($model))[\\/][^ ]*customized-skill-dir"
            }
        }

        It 'Uses distinct customized skill directories' {
            $skillDirs = @($script:Summary.plannedCommands |
                    Where-Object { $_ -match 'customized/eval\.yaml' } |
                    ForEach-Object { ($_ -split '--skill-dir ')[1] })
            ($skillDirs | Sort-Object -Unique).Count | Should -Be 2
        }

        It 'Pins an explicit sonnet version rather than a floating alias' {
            # `claude-sonnet-latest` produced no trajectories in CI. A floating alias
            # can resolve to a model the account cannot execute, which surfaces as an
            # empty run rather than as a model-selection error.
            ($script:Summary.plannedCommands -join "`n") | Should -Not -Match 'claude-sonnet-latest'
        }

        It 'Passes the canonical comparison spec to every compare command' {
            # Without --eval-spec, vally compare falls back to the rubric embedded in
            # the baseline trajectory and then to a general preference rubric. A
            # preference judge picks a winner between two runs of the same
            # configuration, so the tie ratio would measure judge tie-breaking rather
            # than equivalence.
            $compare = @($script:Summary.plannedCommands | Where-Object { $_ -match '^vally compare ' })
            $compare.Count | Should -Be 2
            foreach ($line in $compare) {
                $line | Should -Match '--eval-spec evals/baseline-equivalence/compare\.eval\.yml'
                $line | Should -Match '--judge-model claude-haiku-4\.5'
            }
        }
    }

    Context 'Calibration tier expansion' {
        BeforeEach {
            & $script:ScriptPath `
                -Agent 'rpi-agent' `
                -Tier 'calibration' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null
            $script:Summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
        }

        It 'Plans the fixed two-model population' {
            $script:Summary.tier | Should -Be 'calibration'
            $script:Summary.plannedCommands.Count | Should -Be 6
            ($script:Summary.plannedCommands -join "`n") | Should -Match 'gpt-5\.6-luna'
            ($script:Summary.plannedCommands -join "`n") | Should -Match 'claude-sonnet-4\.6'
        }
    }

    Context 'Retired parameters and tiers' {
        BeforeAll {
            . $script:ScriptPath
        }

        It 'Rejects the removed StimulusFilter parameter' {
            # It was a no-op: it only appended a comment to dry-run command text and was
            # never passed to Vally, so a run believed to be filtered ran the full suite.
            { & $script:ScriptPath `
                    -Agent 'rpi-agent' `
                    -Tier 'devloop' `
                    -StimulusFilter '^code-' `
                    -RepoRoot $script:RepoRoot `
                    -OutputPath $script:OutputPath `
                    -WhatIf *> $null } | Should -Throw
        }

        It 'Rejects the retired pr tier by name' {
            # No alias: pr and nightly carried different exit policies, so silently
            # mapping one onto a new name would change a caller's gating behavior.
            $err = { Assert-SupportedTier -Tier 'pr' } | Should -Throw -PassThru
            $err.Exception.Message | Should -Match 'devloop'
        }

        It 'Rejects the retired nightly tier by name' {
            $err = { Assert-SupportedTier -Tier 'nightly' } | Should -Throw -PassThru
            $err.Exception.Message | Should -Match "'-Tier ci'"
        }

        It 'Accepts the supported tiers' {
            { Assert-SupportedTier -Tier 'devloop' } | Should -Not -Throw
            { Assert-SupportedTier -Tier 'ci' } | Should -Not -Throw
        }

        It 'Rejects an unknown tier without suggesting a migration' {
            $err = { Assert-SupportedTier -Tier 'staging' } | Should -Throw -PassThru
            $err.Exception.Message | Should -Match 'Unsupported tier'
        }
    }

    Context 'Model override' {
        It 'Pins the PR-tier model to the supplied override' {
            & $script:ScriptPath `
                -Agent 'rpi-agent' `
                -Tier 'devloop' `
                -Model 'gpt-5-mini' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null

            $summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $summary.model | Should -Be 'gpt-5-mini'
            ($summary.plannedCommands -join "`n") | Should -Match 'gpt-5-mini'
        }

        It 'Ignores the override for the ci tier' {
            & $script:ScriptPath `
                -Agent 'rpi-agent' `
                -Tier 'ci' `
                -Model 'gpt-5-mini' `
                -RepoRoot $script:RepoRoot `
                -OutputPath $script:OutputPath `
                -WhatIf *> $null

            $summary = Get-Content -LiteralPath $script:OutputPath -Raw | ConvertFrom-Json
            $summary.model | Should -Be 'gpt-5.6-luna'
        }
    }

    Context 'Parameter validation' {
        It 'Rejects an unknown tier' {
            # Assert-SupportedTier throws, but the script's outer catch converts it to exit 3.
            & $script:ScriptPath -Tier 'weekly' -RepoRoot $script:RepoRoot -OutputPath $script:OutputPath -WhatIf *> $null
            $LASTEXITCODE | Should -Be 3
        }
    }
}

Describe 'Measure-InvariantFailures' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
        $script:Pass = [char]::ConvertFromUtf32(0x2705)
        $script:Fail = [char]::ConvertFromUtf32(0x274C)
        $script:Warn = [char]::ConvertFromUtf32(0x1F7E1)
        $script:Header = '| Stimulus | Graders | Pass Rate | pass@k | pass^k | Duration | Tokens | Verdict |'
        $script:Sep = '|---|---|---|---|---|---|---|---|'
    }

    It 'Returns zero failures when all rows pass' {
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | $script:Pass g 5/5 | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | $script:Pass g 5/5 | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 2
        $result.Failed | Should -Be 0
    }

    It 'Counts failed and warned rows as failures' {
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | g | 0%   | 0.00 | 0.00 | 1s | 10 | $script:Fail |",
            "| s3 | g | 60%  | 0.60 | 0.30 | 1s | 10 | $script:Warn |",
            "| s4 | g | 0%   | 0.00 | 0.00 | 1s | 10 | $script:Fail |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 4
        $result.Failed | Should -Be 3
    }

    It 'Ignores header and separator rows' {
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 1
        $result.Failed | Should -Be 0
    }

    It 'Strips ANSI escape sequences before matching' {
        $ansiLine = "`e[32m| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Fail |`e[0m"
        $result = Measure-InvariantFailures -Lines @($ansiLine)
        $result.Total | Should -Be 1
        $result.Failed | Should -Be 1
    }

    It 'Handles empty input' {
        $result = Measure-InvariantFailures -Lines @()
        $result.Total | Should -Be 0
        $result.Failed | Should -Be 0
    }

    It 'Ignores non-table lines' {
        $lines = @(
            '# Eval Results',
            '',
            'Some prose here.',
            $script:Header,
            $script:Sep,
            "| s1 | g | 0% | 0.00 | 0.00 | 1s | 10 | $script:Fail |"
        )
        $result = Measure-InvariantFailures -Lines $lines
        $result.Total | Should -Be 1
        $result.Failed | Should -Be 1
    }
}

Describe 'Resolve-ModelList' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
    }

    It 'Uses GPT-5.6 Luna as the low-cost PR default' {
        $models = Resolve-ModelList -Tier 'devloop' -Hint '' -ModelOverride ''

        $models | Should -Be @('gpt-5.6-luna')
    }
}

Describe 'Comparison judge pin' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
    }

    It 'Defaults to the reviewed low-cost judge' {
        # The pin previously lived only inside compare.eval.yml. That file is retired, so
        # this default is the sole carrier and a silent change to it would alter what the
        # comparison measures without any recorded decision.
        $param = (Get-Command $script:ScriptPath).Parameters['ComparisonJudgeModel']
        $param | Should -Not -BeNullOrEmpty

        $driverText = Get-Content -LiteralPath $script:ScriptPath -Raw
        $driverText | Should -Match "ComparisonJudgeModel\s*=\s*'claude-haiku-4\.5'"
    }

    It 'Passes the judge model on the compare invocation' {
        $driverText = Get-Content -LiteralPath $script:ScriptPath -Raw
        $driverText | Should -Match "'--judge-model',\s*\`$ComparisonJudgeModel"
    }

    It 'No longer renders or reads a compare eval spec' {
        # Asserts on executable surface, not prose. The driver retains comments
        # explaining why the judge pin moved, and those must not fail this check.
        $driverText = Get-Content -LiteralPath $script:ScriptPath -Raw
        $driverText | Should -Not -Match 'New-RenderedCompareSpec'
        $driverText | Should -Not -Match 'Resolve-AgentSurfaceSignaturePath'
        $driverText | Should -Not -Match 'surface_signatures'
        $driverText | Should -Not -Match "'--eval-spec',\s*\`$renderedSpecRelative"
    }
}

Describe 'Test-CustomizationCollapse' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
    }

    # A total collapse is the fingerprint of an undelivered customization surface:
    # the customized variant runs as the baseline, so the comparison reports
    # equivalence rather than an error. The boundary cases matter as much as the
    # positive one: flagging partial failure would make the check noise, and
    # flagging an empty guard set would flag runs that declared none.
    It 'Flags a run where every evaluated guard failed' {
        Test-CustomizationCollapse -Evaluated 12 -Failed 12 | Should -BeTrue
    }

    It 'Ignores a partial failure, which is an ordinary behavioral result' {
        Test-CustomizationCollapse -Evaluated 12 -Failed 11 | Should -BeFalse
    }

    It 'Ignores a fully passing run' {
        Test-CustomizationCollapse -Evaluated 12 -Failed 0 | Should -BeFalse
    }

    It 'Ignores a run with no declared guards' {
        Test-CustomizationCollapse -Evaluated 0 -Failed 0 | Should -BeFalse
    }
}

Describe 'Invoke-BaselineEquivalence.ps1 (stubbed nightly run)' -Tag 'Unit' {
    BeforeEach {
        $script:StubRepoRoot = Join-Path $TestDrive 'repo'
        $baselineRoot = Join-Path $script:StubRepoRoot 'evals/baseline-equivalence'
        $workspaceRoot = Join-Path $baselineRoot 'customized/workspace'
        New-Item -ItemType Directory -Path $workspaceRoot -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:StubRepoRoot '.github/skills') -Force | Out-Null
        # The driver materializes a per-agent customized environment, so the stub repo
        # needs the agent file it will look for. Without it the run records a
        # materialization failure and this test would count that instead of the compare
        # failures it exists to measure.
        $stubAgentsDir = Join-Path $script:StubRepoRoot '.github/agents/hve-core'
        New-Item -ItemType Directory -Path $stubAgentsDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $stubAgentsDir 'rpi-agent.agent.md') -Encoding UTF8 -Value "---`nname: RPI Agent`n---`n`nStub agent for driver tests."

        # vally copies this fixture into each trial via environment.files, and the
        # driver folds its content into the baseline cache key. The stub repo carries
        # one so that key is computed over the same shape as a real run.
        $script:StubSeedDir = Join-Path $baselineRoot 'seed-workspace'
        New-Item -ItemType Directory -Path $script:StubSeedDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $script:StubSeedDir 'README.md') -Encoding UTF8 -Value '# Stub seed'

        # The driver resolves the comparison contract before any model-backed work, so
        # the stub repo carries one. Its absence is a hard failure by design: without
        # it, `vally compare` would fall back to a preference rubric that cannot
        # measure equivalence.
        Set-Content -LiteralPath (Join-Path $baselineRoot 'compare.eval.yml') -Encoding UTF8 -Value @'
name: stub-compare
type: capability
defaults:
  executor: copilot-sdk
stimuli:
  - name: stub-stimulus
    prompt: "Stub prompt."
    tags: {category: baseline-equivalence, policy: equivalent}
    rubric:
      - Score a tie when both responses satisfy the same contract.
    graders:
      - {type: prompt, name: equivalence-judgement, config: {prompt: "Equivalent?"}}
'@

        # The driver reads the canonical stimulus library and the executable specs before
        # any model-backed work and fails loudly when either is unreadable, so the stub
        # repo carries both rather than relying on a silent default.
        Set-Content -LiteralPath (Join-Path $baselineRoot 'stimuli.yml') -Encoding UTF8 -Value @'
stimuli:
  - name: stub-stimulus
    prompt: "Stub prompt."
    invariants: [stub-invariant]
    customized_required: [stub-guard]
    tags: {category: baseline-equivalence, policy: equivalent}
'@
        foreach ($variantDir in @('baseline', 'customized')) {
            $variantPath = Join-Path $baselineRoot $variantDir
            New-Item -ItemType Directory -Path $variantPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $variantPath 'eval.yaml') -Encoding UTF8 -Value @'
name: stub-spec
type: capability
defaults:
  runs: 1
  executor: copilot-sdk
'@
        }

        $script:StubOutputPath = Join-Path $script:StubRepoRoot 'logs/summary.json'
        $stubVally = Join-Path $PSScriptRoot 'fixtures/stub-vally.ps1'
        Set-Alias -Name vally -Value $stubVally -Scope Global
        $env:STUB_VALLY_COMPARE_MODE = 'fail-empty'
    }

    AfterEach {
        Remove-Item Alias:vally -Force -ErrorAction SilentlyContinue
        Remove-Item Env:STUB_VALLY_COMPARE_MODE, Env:STUB_VALLY_BASELINE_MODE, Env:STUB_VALLY_CUSTOMIZED_MODES, Env:STUB_VALLY_CUSTOMIZED_COUNT_PATH, Env:STUB_VALLY_CALL_LOG -ErrorAction SilentlyContinue
    }

    It 'Counts each failed empty compare once across ci models' {
        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'ci' `
            -RepoRoot $script:StubRepoRoot `
            -OutputPath $script:StubOutputPath *> $null

        $summary = Get-Content -LiteralPath $script:StubOutputPath -Raw | ConvertFrom-Json
        $summary.runHealthFailures | Should -Be 2
        $summary.runs | Should -Be 0
        $summary.verdict | Should -Be 'fail'
        $LASTEXITCODE | Should -Be 1
    }

    It 'Materializes the customization surface where the spec reads it' {
        # The surface must land in customized/surface/.github, because that is the
        # only path the customized spec copies into each trial. Writing it to the
        # workspace root leaves the agent with no customization at all while every
        # run still reports success.
        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'ci' `
            -RepoRoot $script:StubRepoRoot `
            -OutputPath $script:StubOutputPath *> $null

        $surfaceAgent = Join-Path $script:StubRepoRoot 'evals/baseline-equivalence/customized/surface/.github/agents/hve-core/rpi-agent.agent.md'
        Test-Path -LiteralPath $surfaceAgent | Should -BeTrue

        $workspaceAgent = Join-Path $script:StubRepoRoot 'evals/baseline-equivalence/customized/workspace/.github/agents/hve-core/rpi-agent.agent.md'
        Test-Path -LiteralPath $workspaceAgent | Should -BeFalse
    }

    It 'Exits 0 on the advisory tier despite the same failing verdict' {
        # devloop is advisory: it reports the failure but must not gate. Without this
        # case the tier check in the exit path could be deleted and the ci test above
        # would still pass, so nothing would pin that local runs stay non-blocking.
        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'devloop' `
            -RepoRoot $script:StubRepoRoot `
            -OutputPath $script:StubOutputPath *> $null

        $summary = Get-Content -LiteralPath $script:StubOutputPath -Raw | ConvertFrom-Json
        $summary.verdict | Should -Be 'fail'
        $LASTEXITCODE | Should -Be 0
    }

    It 'Retries one eligible customized GPT attempt and makes the retry authoritative' {
        $env:STUB_VALLY_BASELINE_MODE = 'invocation-pass'
        $env:STUB_VALLY_CUSTOMIZED_MODES = 'invocation-failed-tool,invocation-pass'
        $env:STUB_VALLY_CUSTOMIZED_COUNT_PATH = Join-Path $TestDrive "customized-count-$([Guid]::NewGuid()).txt"
        $env:STUB_VALLY_CALL_LOG = Join-Path $TestDrive 'vally-calls.jsonl'
        $env:STUB_VALLY_COMPARE_MODE = 'pass'

        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'calibration' `
            -RepoRoot $script:StubRepoRoot `
            -OutputPath $script:StubOutputPath `
            -NoBaselineCache *> $null

        $summary = Get-Content -LiteralPath $script:StubOutputPath -Raw | ConvertFrom-Json
        $gptAttempts = @($summary.invocationEvidence | Where-Object { $_.model -eq 'gpt-5.6-luna' })
        $calls = @(Get-Content -LiteralPath $env:STUB_VALLY_CALL_LOG | ForEach-Object { , ($_ | ConvertFrom-Json) })
        $baselineCalls = @($calls | Where-Object { $_[0] -eq 'eval' -and $_[2] -match '[/\\]baseline[/\\]' })
        $customizedCalls = @($calls | Where-Object { $_[0] -eq 'eval' -and $_[2] -match '[/\\]customized[/\\]' })

        $gptAttempts.Count | Should -Be 2
        $gptAttempts[0].reasonCode | Should -Be 'failed-tool-result'
        $gptAttempts[1].hasCompleteEvidence | Should -BeTrue
        $summary.invocationFailures | Should -Be 0
        $baselineCalls.Count | Should -Be 2
        $customizedCalls.Count | Should -Be 3
    }

    It 'Does not retry an ineligible missing exact read' {
        $env:STUB_VALLY_BASELINE_MODE = 'invocation-pass'
        $env:STUB_VALLY_CUSTOMIZED_MODES = 'invocation-no-exact-read'
        $env:STUB_VALLY_CUSTOMIZED_COUNT_PATH = Join-Path $TestDrive "customized-count-$([Guid]::NewGuid()).txt"
        $env:STUB_VALLY_COMPARE_MODE = 'pass'

        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'calibration' `
            -RepoRoot $script:StubRepoRoot `
            -OutputPath $script:StubOutputPath `
            -NoBaselineCache *> $null

        $summary = Get-Content -LiteralPath $script:StubOutputPath -Raw | ConvertFrom-Json
        $gptAttempts = @($summary.invocationEvidence | Where-Object { $_.model -eq 'gpt-5.6-luna' })

        $gptAttempts.Count | Should -Be 1
        $gptAttempts[0].reasonCode | Should -Be 'no-exact-read'
        $summary.invocationFailures | Should -BeGreaterThan 0
        [int](Get-Content -LiteralPath $env:STUB_VALLY_CUSTOMIZED_COUNT_PATH -Raw) | Should -Be 2
    }

    It 'Fails closed without reusing attempt one when the retry creates no run' {
        $env:STUB_VALLY_BASELINE_MODE = 'invocation-pass'
        $env:STUB_VALLY_CUSTOMIZED_MODES = 'invocation-failed-tool,silent-crash'
        $env:STUB_VALLY_CUSTOMIZED_COUNT_PATH = Join-Path $TestDrive "customized-count-$([Guid]::NewGuid()).txt"
        $env:STUB_VALLY_COMPARE_MODE = 'pass'

        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'calibration' `
            -RepoRoot $script:StubRepoRoot `
            -OutputPath $script:StubOutputPath `
            -NoBaselineCache *> $null

        $summary = Get-Content -LiteralPath $script:StubOutputPath -Raw | ConvertFrom-Json
        $gptAttempts = @($summary.invocationEvidence | Where-Object { $_.model -eq 'gpt-5.6-luna' })

        $gptAttempts.Count | Should -Be 2
        $gptAttempts[0].reasonCode | Should -Be 'failed-tool-result'
        $gptAttempts[1].observed | Should -Be 0
        $gptAttempts[1].failedKey | Should -BeNullOrEmpty
        $summary.invocationFailures | Should -BeGreaterThan 0
        $summary.runHealthFailures | Should -BeGreaterThan 0
        $summary.verdict | Should -Be 'fail'
    }
}

Describe 'Customized run exit code and guard signal' -Tag 'Unit' {
    # `vally eval` exits nonzero whenever any grader on any trial fails, and those
    # failures are already counted precisely as invariant and guard failures. Counting
    # the exit code as run health too made runHealthFailures nonzero on every real run,
    # so the equivalence gate could never report pass no matter how the guards behaved.
    # The exit code is run-health evidence only when no guard signal survived.
    BeforeEach {
        $script:GuardRepoRoot = Join-Path $TestDrive 'guard-repo'
        $guardRoot = Join-Path $script:GuardRepoRoot 'evals/baseline-equivalence'
        New-Item -ItemType Directory -Path (Join-Path $guardRoot 'customized/workspace') -Force | Out-Null
        New-Item -ItemType Directory -Path (Join-Path $script:GuardRepoRoot '.github/skills') -Force | Out-Null
        $agentsDir = Join-Path $script:GuardRepoRoot '.github/agents/hve-core'
        New-Item -ItemType Directory -Path $agentsDir -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $agentsDir 'rpi-agent.agent.md') -Encoding UTF8 -Value "---`nname: RPI Agent`n---`n`nStub agent."
        New-Item -ItemType Directory -Path (Join-Path $guardRoot 'seed-workspace') -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $guardRoot 'seed-workspace/README.md') -Encoding UTF8 -Value '# seed'

        Set-Content -LiteralPath (Join-Path $guardRoot 'compare.eval.yml') -Encoding UTF8 -Value @'
name: stub-compare
type: capability
stimuli:
  - name: guarded-stimulus
    prompt: "Stub prompt."
    tags: {category: baseline-equivalence, policy: documented-divergence}
    rubric:
      - Score the customized variant higher on documented divergence; score a tie otherwise.
'@

        # One stimulus declaring one invariant and one guard, both of which the stub
        # reports as passing. Any residual failure therefore comes from the exit code.
        Set-Content -LiteralPath (Join-Path $guardRoot 'stimuli.yml') -Encoding UTF8 -Value @'
name: stub-stimuli
stimuli:
  - name: guarded-stimulus
    prompt: "Stub prompt."
    invariants: [stub-invariant]
    customized_required: [stub-guard]
    tags: {category: baseline-equivalence, policy: documented-divergence}
'@

        # The driver reads the executable specs for the effective trial count and fails
        # loudly when they are unreadable, so the guard repo carries both.
        foreach ($variantDir in @('baseline', 'customized')) {
            $variantPath = Join-Path $guardRoot $variantDir
            New-Item -ItemType Directory -Path $variantPath -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $variantPath 'eval.yaml') -Encoding UTF8 -Value @'
name: stub-spec
type: capability
defaults:
  runs: 1
  executor: copilot-sdk
'@
        }

        $script:GuardOutputPath = Join-Path $script:GuardRepoRoot 'logs/summary.json'
        Set-Alias -Name vally -Value (Join-Path $PSScriptRoot 'fixtures/stub-vally.ps1') -Scope Global
        $env:STUB_VALLY_MODE = 'graded-nonzero'
        $env:STUB_VALLY_COMPARE_MODE = 'pass'
        $env:STUB_VALLY_GRADED_STIMULUS = 'guarded-stimulus'
        $env:STUB_VALLY_GRADED_PASSING = 'stub-invariant,stub-guard'
    }

    AfterEach {
        Remove-Item Alias:vally -Force -ErrorAction SilentlyContinue
        Remove-Item Env:STUB_VALLY_MODE, Env:STUB_VALLY_COMPARE_MODE, Env:STUB_VALLY_GRADED_STIMULUS, Env:STUB_VALLY_GRADED_PASSING -ErrorAction SilentlyContinue
    }

    It 'Does not count a nonzero customized exit as run health when guards reported' {
        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'ci' `
            -RepoRoot $script:GuardRepoRoot `
            -OutputPath $script:GuardOutputPath `
            -NoBaselineCache *> $null

        $summary = Get-Content -LiteralPath $script:GuardOutputPath -Raw | ConvertFrom-Json
        $summary.runHealthFailures | Should -Be 0
        $summary.divergenceGuardFailures | Should -Be 0
        $summary.divergenceGuardsEvaluated | Should -BeGreaterThan 0
    }

    It 'Still counts a nonzero customized exit as run health when no guard reported' {
        # Removing the guard declaration leaves the gate with no signal, so the exit
        # code is the only remaining evidence about the run and must be honored.
        Set-Content -LiteralPath (Join-Path $script:GuardRepoRoot 'evals/baseline-equivalence/stimuli.yml') -Encoding UTF8 -Value @'
name: stub-stimuli
stimuli:
  - name: guarded-stimulus
    prompt: "Stub prompt."
    invariants: [stub-invariant]
    tags: {category: baseline-equivalence, policy: equivalent}
'@

        & $script:ScriptPath `
            -Agent 'rpi-agent' `
            -Tier 'ci' `
            -RepoRoot $script:GuardRepoRoot `
            -OutputPath $script:GuardOutputPath `
            -NoBaselineCache *> $null

        $summary = Get-Content -LiteralPath $script:GuardOutputPath -Raw | ConvertFrom-Json
        $summary.runHealthFailures | Should -BeGreaterThan 0
    }
}

Describe 'Get-InvariantFailureCount' -Tag 'Unit' {
    BeforeAll {
        . $script:ScriptPath
        $script:Pass = [char]::ConvertFromUtf32(0x2705)
        $script:Fail = [char]::ConvertFromUtf32(0x274C)
        $script:Warn = [char]::ConvertFromUtf32(0x1F7E1)
        $script:Header = '| Stimulus | Graders | Pass Rate | pass@k | pass^k | Duration | Tokens | Verdict |'
        $script:Sep = '|---|---|---|---|---|---|---|---|'
    }

    It 'Returns $null when RunDir is empty' {
        Get-InvariantFailureCount -RunDir '' | Should -BeNullOrEmpty
    }

    It 'Returns $null when RunDir does not exist' {
        Get-InvariantFailureCount -RunDir (Join-Path $TestDrive 'nope') | Should -BeNullOrEmpty
    }

    It 'Returns $null when eval-results.md is missing' {
        $dir = Join-Path $TestDrive 'no-md'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        Get-InvariantFailureCount -RunDir $dir | Should -BeNullOrEmpty
    }

    It 'Returns $null when the markdown table has no data rows' {
        $dir = Join-Path $TestDrive 'empty-table'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $md = Join-Path $dir 'eval-results.md'
        Set-Content -LiteralPath $md -Value @($script:Header, $script:Sep) -Encoding utf8NoBOM
        Get-InvariantFailureCount -RunDir $dir | Should -BeNullOrEmpty
    }

    It 'Returns the failed-stimulus count parsed from eval-results.md' {
        $dir = Join-Path $TestDrive 'with-failures'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $md = Join-Path $dir 'eval-results.md'
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | g | 0%   | 0.00 | 0.00 | 1s | 10 | $script:Fail |",
            "| s3 | g | 60%  | 0.60 | 0.30 | 1s | 10 | $script:Warn |"
        )
        Set-Content -LiteralPath $md -Value $lines -Encoding utf8NoBOM
        Get-InvariantFailureCount -RunDir $dir | Should -Be 2
    }

    It 'Returns 0 when all stimuli pass' {
        $dir = Join-Path $TestDrive 'all-pass'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        $md = Join-Path $dir 'eval-results.md'
        $lines = @(
            $script:Header,
            $script:Sep,
            "| s1 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |",
            "| s2 | g | 100% | 1.00 | 1.00 | 1s | 10 | $script:Pass |"
        )
        Set-Content -LiteralPath $md -Value $lines -Encoding utf8NoBOM
        Get-InvariantFailureCount -RunDir $dir | Should -Be 0
    }
}
