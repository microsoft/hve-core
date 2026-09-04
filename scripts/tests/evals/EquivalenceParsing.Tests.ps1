#Requires -Modules Pester
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

BeforeAll {
    $script:ModulePath = Join-Path $PSScriptRoot '../../evals/lib/EquivalenceParsing.psm1'
    Import-Module $script:ModulePath -Force
    $script:FixturesRoot = Join-Path $PSScriptRoot 'fixtures/equivalence'
}

Describe 'Measure-CompareTrials' -Tag 'Unit' {
    BeforeAll {
        $script:Lines = Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.jsonl')
        $script:Tally = Measure-CompareTrials -Lines $script:Lines
    }

    It 'Counts the total number of non-errored trials' {
        $script:Tally.Total | Should -Be 4
    }

    It 'Counts ties' {
        $script:Tally.Ties | Should -Be 2
    }

    It 'Counts baseline wins' {
        $script:Tally.BaselineWins | Should -Be 1
    }

    It 'Counts treatment wins' {
        $script:Tally.TreatmentWins | Should -Be 1
    }

    It 'Groups results per stimulus' {
        $script:Tally.PerStimulus.Keys | Should -Contain 'test-stim-a'
        $script:Tally.PerStimulus.Keys | Should -Contain 'test-stim-b'
        $script:Tally.PerStimulus['test-stim-a'].Ties | Should -Be 1
        $script:Tally.PerStimulus['test-stim-a'].BaselineWins | Should -Be 1
        $script:Tally.PerStimulus['test-stim-b'].TreatmentWins | Should -Be 1
    }

    It 'Excludes errored trials from the per-stimulus tally' {
        $script:Tally.PerStimulus['test-stim-a'].Ties | Should -Be 1
        $script:Tally.PerStimulus['test-stim-a'].BaselineWins | Should -Be 1
        $script:Tally.PerStimulus['test-stim-a'].TreatmentWins | Should -Be 0
    }

    It 'Carries the summary mean score and confidence interval' {
        $script:Tally.MeanScore | Should -Be 0.0
        $script:Tally.CiLow | Should -Be -0.3
        $script:Tally.CiHigh | Should -Be 0.3
    }

    It 'Carries the summary win rate' {
        $script:Tally.WinRate | Should -Be 0.25
    }

    It 'Reports a summary count for records carrying confidence-interval statistics' {
        $script:Tally.SummaryCount | Should -Be 1
    }

    It 'Reports zero summary count when a comparison record carries trials but no summary' {
        $record = '{"type":"comparison","stimuli":[{"stimulusName":"test-stim-a","trials":[{"trialIndex":0,"winner":"baseline"},{"trialIndex":1,"winner":"treatment"}]}]}'
        $result = Measure-CompareTrials -Lines @($record)
        $result.Total | Should -Be 2
        $result.SummaryCount | Should -Be 0
        $result.CiLow | Should -Be 0.0
        $result.CiHigh | Should -Be 0.0
    }

    It 'Excludes trials with an unrecognized winner from the total tally' {
        $record = '{"type":"comparison","stimuli":[{"stimulusName":"test-stim-a","trials":[{"trialIndex":0,"winner":"tie"},{"trialIndex":1,"winner":"unknown"}]}]}'
        $result = Measure-CompareTrials -Lines @($record)
        $result.Total | Should -Be 1
        $result.Ties | Should -Be 1
    }

    It 'Ignores non-JSON and non-comparison lines' {
        $result = Measure-CompareTrials -Lines @('not json', '{"type":"other"}')
        $result.Total | Should -Be 0
        $result.MeanScore | Should -Be 0.0
    }

    It 'Returns zeros for empty input' {
        $empty = Measure-CompareTrials -Lines @()
        $empty.Total | Should -Be 0
        $empty.Ties | Should -Be 0
        $empty.MeanScore | Should -Be 0.0
        $empty.CiLow | Should -Be 0.0
        $empty.CiHigh | Should -Be 0.0
        $empty.SummaryCount | Should -Be 0
    }

    It 'Returns zeros for null input from an empty file read' {
        $empty = Measure-CompareTrials -Lines $null
        $empty.Total | Should -Be 0
        $empty.SummaryCount | Should -Be 0
    }

    It 'Handles absent optional comparison properties under strict mode' {
        $record = '{"type":"comparison","stimuli":[{}, {"stimulusName":"test-stim","trials":[{}]}],"summary":{}}'
        { Measure-CompareTrials -Lines @($record) } | Should -Not -Throw
        $result = Measure-CompareTrials -Lines @($record)
        $result.Total | Should -Be 0
        $result.SummaryCount | Should -Be 0
    }

    It 'Combines confidence intervals across multiple comparison records' {
        $records = @(
            '{"type":"comparison","summary":{"meanScore":-0.1,"ciLow":-0.4,"ciHigh":0.2,"winRate":0.4}}',
            '{"type":"comparison","summary":{"meanScore":0.1,"ciLow":-0.1,"ciHigh":0.5,"winRate":0.6}}'
        )
        $result = Measure-CompareTrials -Lines $records
        $result.SummaryCount | Should -Be 2
        $result.MeanScore | Should -Be 0.0
        $result.WinRate | Should -Be 0.5
        $result.CiLow | Should -Be -0.1
        $result.CiHigh | Should -Be 0.2
    }

    It 'Excludes incomplete confidence intervals from aggregate bounds' {
        $records = @(
            '{"type":"comparison","summary":{"ciLow":0.9}}',
            '{"type":"comparison","summary":{"ciLow":-0.3,"ciHigh":0.4}}'
        )
        $result = Measure-CompareTrials -Lines $records
        $result.SummaryCount | Should -Be 1
        $result.CiLow | Should -Be -0.3
        $result.CiHigh | Should -Be 0.4
    }
}

Describe 'Measure-CompareTrials against captured Vally 0.10 output' -Tag 'Unit' {
    # Fixture provenance: captured from Vally CLI 0.10.0 by running two temporary
    # eval specs (benign arithmetic and geography prompts, executor copilot-sdk,
    # model gpt-5.6-luna) and comparing the two run directories with
    # `vally compare --baseline <dir> --treatment <dir> --judge-model claude-haiku-4.5`.
    # Judge and grader rationale text was replaced during sanitization; every
    # structural field the parser reads is preserved verbatim.
    #
    # Capture limitation: the temporary specs lived outside the `paths.evals`
    # root configured in .vally.yaml. These fixtures are evidence of record shape
    # only, not of eval-spec path or skill-resolution behavior.
    BeforeAll {
        $script:V010Lines = @(Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-0.10-comparison.jsonl'))
        $script:V010Tally = Measure-CompareTrials -Lines $script:V010Lines
        $script:V010Record = $script:V010Lines[0] | ConvertFrom-Json -Depth 100
    }

    It 'Parses the 0.10 comparison record without contract changes' {
        $script:V010Tally.Total | Should -Be 2
        $script:V010Tally.Ties | Should -Be 2
        $script:V010Tally.BaselineWins | Should -Be 0
        $script:V010Tally.TreatmentWins | Should -Be 0
    }

    It 'Consumes native 0.10 summary statistics' {
        $script:V010Tally.SummaryCount | Should -Be 1
        $script:V010Tally.MeanScore | Should -Be 0.0
        $script:V010Tally.WinRate | Should -Be 0.0
        $script:V010Tally.CiLow | Should -Be 0.0
        $script:V010Tally.CiHigh | Should -Be 0.0
    }

    It 'Groups 0.10 trials per stimulus' {
        $script:V010Tally.PerStimulus.Keys | Should -Contain 'smoke-arithmetic'
        $script:V010Tally.PerStimulus.Keys | Should -Contain 'smoke-capital'
    }

    It 'Retains the 0.10 unmatched arrays that the tally does not currently count' {
        # Total reflects matched pairs only, so the unmatched arrays have to be
        # preserved on the record for the data-quality assertion below to read.
        @($script:V010Record.unmatchedBaseline).Count | Should -Be 1
        @($script:V010Record.unmatchedTreatment).Count | Should -Be 1
        $script:V010Tally.Total | Should -Be 2
    }

    It 'Counts the unmatched trajectories as data-quality signals' {
        # The counterpart to the assertion above. Total still reflects matched pairs
        # only, but the unmatched trajectories are now reported instead of vanishing,
        # so an incomplete comparison cannot present itself as a complete one.
        $script:V010Tally.UnmatchedBaseline | Should -Be 1
        $script:V010Tally.UnmatchedTreatment | Should -Be 1
    }

    It 'Exposes the 0.10 summary fields the reporting contract depends on' {
        $summary = $script:V010Record.summary
        $summary.trialCount | Should -Be 2
        $summary.erroredCount | Should -Be 0
        $summary.PSObject.Properties.Name | Should -Contain 'wins'
        $summary.PSObject.Properties.Name | Should -Contain 'losses'
        $summary.PSObject.Properties.Name | Should -Contain 'mcnemar'
        $summary.PSObject.Properties.Name | Should -Contain 'metricDeltas'
    }
}

Describe 'Measure-CompareTrials data-quality accounting' -Tag 'Unit' {
    Context 'Judge errors' {
        It 'Counts an errored trial instead of skipping it silently' {
            # Previously a bare continue dropped these, so a run whose comparisons
            # mostly errored could report a healthy tie ratio from the survivors.
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"winner":"tie"},{"trialIndex":1,"errored":true}]}]}'
            $result = Measure-CompareTrials -Lines @($record)
            $result.Total | Should -Be 1
            $result.JudgeErrors | Should -Be 1
        }

        It 'Computes the error rate against every attempted trial' {
            # The denominator must include the failures, or the rate shrinks as the
            # failures it measures increase.
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"winner":"tie"},{"trialIndex":1,"errored":true},{"trialIndex":2,"errored":true}]}]}'
            $result = Measure-CompareTrials -Lines @($record)
            $result.JudgeErrors | Should -Be 2
            $result.JudgeErrorRate | Should -Be ([math]::Round(2 / 3, 6))
        }

        It 'Reports a zero error rate when nothing errored' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"winner":"tie"}]}]}'
            (Measure-CompareTrials -Lines @($record)).JudgeErrorRate | Should -Be 0.0
        }

        It 'Attributes judge errors to their stimulus' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"errored":true}]}]}'
            (Measure-CompareTrials -Lines @($record)).PerStimulus['s'].JudgeErrors | Should -Be 1
        }
    }

    Context 'Structural violations' {
        It 'Counts a malformed line rather than ignoring it' {
            $result = Measure-CompareTrials -Lines @('{not valid json', '{"type":"comparison","summary":{}}')
            $result.MalformedRecords | Should -Be 1
        }

        It 'Counts an unrecognized winner as malformed' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"winner":"maybe"}]}]}'
            $result = Measure-CompareTrials -Lines @($record)
            $result.Total | Should -Be 0
            $result.MalformedRecords | Should -Be 1
        }

        It 'Counts unmatched trajectories on both sides' {
            $record = '{"type":"comparison","stimuli":[],"unmatchedBaseline":["a (trial 0)","b (trial 0)"],"unmatchedTreatment":["c (trial 0)"]}'
            $result = Measure-CompareTrials -Lines @($record)
            $result.UnmatchedBaseline | Should -Be 2
            $result.UnmatchedTreatment | Should -Be 1
        }

        It 'Counts a duplicate trial index' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"winner":"tie"},{"trialIndex":0,"winner":"tie"}]}]}'
            (Measure-CompareTrials -Lines @($record)).DuplicateTrials | Should -Be 1
        }

        It 'Records a diagnostic for each violation' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"s","trials":[{"trialIndex":0,"errored":true}]}],"unmatchedBaseline":["x (trial 0)"]}'
            $result = Measure-CompareTrials -Lines @($record)
            @($result.Diagnostics).Count | Should -BeGreaterThan 1
            ($result.Diagnostics -join ' ') | Should -Match 'Judge error'
            ($result.Diagnostics -join ' ') | Should -Match 'Unmatched baseline'
        }

        It 'Counts comparison records so a missing pair is detectable' {
            $result = Measure-CompareTrials -Lines @('{"type":"comparison","summary":{}}')
            $result.ComparisonRecords | Should -Be 1
        }
    }

    Context 'Population reconciliation' {
        It 'Reports a stimulus that produced no record at all as missing' {
            # The defining case: a truncated run leaves no malformed line, no judge
            # error, and no unmatched trajectory, so only reconciliation can see it.
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"alpha","trials":[{"trialIndex":0,"winner":"tie","score":0.0}]}]}'
            $result = Measure-CompareTrials -Lines @($record) -ExpectedStimulusName @('alpha', 'beta') -ExpectedTrialCount 1
            $result.MissingTrials | Should -Be 1
            $result.MalformedRecords | Should -Be 0
            $result.UnmatchedBaseline | Should -Be 0
            ($result.Diagnostics -join ' ') | Should -Match "stimulus 'beta' trial 0 produced no record"
        }

        It 'Reports a partially delivered stimulus as missing per absent trial' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"alpha","trials":[{"trialIndex":0,"winner":"tie","score":0.0}]}]}'
            $result = Measure-CompareTrials -Lines @($record) -ExpectedStimulusName @('alpha') -ExpectedTrialCount 3
            $result.MissingTrials | Should -Be 2
        }

        It 'Counts an errored trial as delivered rather than missing' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"alpha","trials":[{"trialIndex":0,"errored":true}]}]}'
            $result = Measure-CompareTrials -Lines @($record) -ExpectedStimulusName @('alpha') -ExpectedTrialCount 1
            $result.MissingTrials | Should -Be 0
            $result.JudgeErrors | Should -Be 1
        }

        It 'Reports a stimulus outside the declared population as unexpected' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"stray","trials":[{"trialIndex":0,"winner":"tie","score":0.0}]}]}'
            $result = Measure-CompareTrials -Lines @($record) -ExpectedStimulusName @('alpha') -ExpectedTrialCount 1
            $result.UnexpectedTrials | Should -Be 1
            $result.MissingTrials | Should -Be 1
        }

        It 'Reports a complete population as fully reconciled with no violations' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"alpha","trials":[{"trialIndex":0,"winner":"tie","score":0.0},{"trialIndex":1,"winner":"tie","score":0.0}]}]}'
            $result = Measure-CompareTrials -Lines @($record) -ExpectedStimulusName @('alpha') -ExpectedTrialCount 2
            $result.PopulationReconciled | Should -BeTrue
            $result.MissingTrials | Should -Be 0
            $result.UnexpectedTrials | Should -Be 0
        }

        It 'Skips reconciliation and flags it when no expected population is supplied' {
            $record = '{"type":"comparison","stimuli":[{"stimulusName":"alpha","trials":[{"trialIndex":0,"winner":"tie","score":0.0}]}]}'
            $result = Measure-CompareTrials -Lines @($record)
            $result.PopulationReconciled | Should -BeFalse
            $result.MissingTrials | Should -Be 0
        }
    }

    Context 'Comparison policy denominator' {
        BeforeAll {
            $script:PolicyMap = @{ 'equal-one' = 'equivalent'; 'equal-two' = 'equivalent'; 'diverges' = 'documented-divergence' }
            $script:PolicyRecord = '{"type":"comparison","stimuli":[' +
                '{"stimulusName":"equal-one","trials":[{"trialIndex":0,"winner":"tie"}]},' +
                '{"stimulusName":"equal-two","trials":[{"trialIndex":0,"winner":"treatment"}]},' +
                '{"stimulusName":"diverges","trials":[{"trialIndex":0,"winner":"treatment"}]}]}'
        }

        It 'Excludes documented-divergence stimuli from the equivalence denominator' {
            # A stimulus expected to differ must not count against equivalence, which
            # is the scoring defect the policy tag exists to fix.
            $result = Measure-CompareTrials -Lines @($script:PolicyRecord) -StimulusPolicy $script:PolicyMap
            $result.EquivalentTotal | Should -Be 2
            $result.DivergenceTotal | Should -Be 1
        }

        It 'Computes the tie ratio over equivalent stimuli only' {
            $result = Measure-CompareTrials -Lines @($script:PolicyRecord) -StimulusPolicy $script:PolicyMap
            $result.TieRatio | Should -Be 0.5
        }

        It 'Still counts every trial in the overall total' {
            $result = Measure-CompareTrials -Lines @($script:PolicyRecord) -StimulusPolicy $script:PolicyMap
            $result.Total | Should -Be 3
        }

        It 'Treats all stimuli as equivalent when no policy map is supplied' {
            $result = Measure-CompareTrials -Lines @($script:PolicyRecord)
            $result.EquivalentTotal | Should -Be 3
            $result.DivergenceTotal | Should -Be 0
        }
    }
}

Describe 'Measure-CompareTrials equivalent-only calibration estimates' -Tag 'Unit' {
    It 'Excludes documented-divergence scores from the calibration estimate' {
        $record = [ordered]@{
            type    = 'comparison'
            summary = [ordered]@{ meanScore = 0.9; ciLow = 0.8; ciHigh = 1.0; winRate = 1.0 }
            stimuli = @(
                [ordered]@{
                    stimulusName = 'equivalent-stimulus'
                    trials = @(
                        [ordered]@{ trialIndex = 0; winner = 'tie'; score = 0.0 },
                        [ordered]@{ trialIndex = 1; winner = 'baseline'; score = -0.4 },
                        [ordered]@{ trialIndex = 2; winner = 'treatment'; score = 0.4 }
                    )
                },
                [ordered]@{
                    stimulusName = 'expected-divergence'
                    trials = @(
                        [ordered]@{ trialIndex = 0; winner = 'treatment'; score = 1.0 },
                        [ordered]@{ trialIndex = 1; winner = 'treatment'; score = 1.0 },
                        [ordered]@{ trialIndex = 2; winner = 'treatment'; score = 1.0 }
                    )
                }
            )
        }
        $policies = @{ 'equivalent-stimulus' = 'equivalent'; 'expected-divergence' = 'documented-divergence' }
        $result = Measure-CompareTrials -Lines @($record | ConvertTo-Json -Depth 10 -Compress) -StimulusPolicy $policies

        $result.MeanScore | Should -Be 0.9
        $result.EquivalentScoreCount | Should -Be 3
        $result.EquivalentMeanScore | Should -Be 0.0
        $result.EquivalentStdDev | Should -Be 0.4
        $result.EquivalentPerStimulus.Keys | Should -Contain 'equivalent-stimulus'
        $result.EquivalentPerStimulus.Keys | Should -Not -Contain 'expected-divergence'
    }

    It 'Counts an equivalent winner without a signed score as malformed' {
        $record = [ordered]@{
            type    = 'comparison'
            stimuli = @([ordered]@{
                    stimulusName = 'equivalent-stimulus'
                    trials = @([ordered]@{ trialIndex = 0; winner = 'tie' })
                })
        }
        $result = Measure-CompareTrials `
            -Lines @($record | ConvertTo-Json -Depth 10 -Compress) `
            -StimulusPolicy @{ 'equivalent-stimulus' = 'equivalent' }

        $result.MalformedRecords | Should -Be 1
        $result.EquivalentScoreCount | Should -Be 0
    }
}

Describe 'Resolve-InvocationReadKind' -Tag 'Unit' {
    BeforeAll {
        $script:Expected = '.github/agents/hve-core/rpi-agent.agent.md'
    }

    It 'Accepts a structured read of the trial-rooted agent path' {
        $callArgs = [pscustomobject]@{ path = "/tmp/trial/$script:Expected" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Rejects a .bak sibling that contains the expected path as a prefix' {
        $callArgs = [pscustomobject]@{ path = "/tmp/trial/$script:Expected.bak" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'wrong-path'
    }

    It 'Rejects a sibling agent in the same directory' {
        $callArgs = [pscustomobject]@{ path = '/tmp/trial/.github/agents/hve-core/other-agent.agent.md' }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'none'
    }

    It 'Rejects a partial-segment suffix that is not a whole path segment' {
        $callArgs = [pscustomobject]@{ path = '/tmp/trial/.github/agents/hve-core/evil-rpi-agent.agent.md' }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'wrong-path'
    }

    It 'Rejects a traversal path even when it ends with the expected suffix' {
        $callArgs = [pscustomobject]@{ path = "/tmp/trial/../../$script:Expected" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'wrong-path'
    }

    It 'Accepts an unambiguous single-operand shell read' {
        $callArgs = [pscustomobject]@{ command = "cat $script:Expected" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a shell read with options preceding the operand' {
        $callArgs = [pscustomobject]@{ command = "sed -n '1,240p' /tmp/trial/$script:Expected" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    # The forms below are taken verbatim from captured trajectories. Both models compose
    # reads this way, so rejecting composed commands discarded valid trials.
    It 'Accepts a find -exec read naming the target through a glob' {
        $callArgs = [pscustomobject]@{ command = "find . -path '*/$script:Expected' -print -exec sed -n '1,240p' {} \;" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a find -exec read naming only the file name through a glob' {
        $callArgs = [pscustomobject]@{ command = "find . -path '*/rpi-agent.agent.md' -print -exec sed -n '1,240p' {} \;" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a chained read preceded by an unrelated command' {
        $callArgs = [pscustomobject]@{ command = "pwd && sed -n '1,240p' $script:Expected" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a semicolon-separated read' {
        $callArgs = [pscustomobject]@{ command = "pwd; sed -n '1,240p' $script:Expected" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a guarded read inside a shell conditional' {
        $callArgs = [pscustomobject]@{ command = "if [ -f $script:Expected ]; then sed -n '1,240p' $script:Expected; else printf 'FILE_NOT_FOUND'; fi" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a read with a redirected fallback' {
        $callArgs = [pscustomobject]@{ command = "cat /tmp/trial/$script:Expected 2>/dev/null || find . -name rpi-agent.agent.md" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Accepts a piped read' {
        $callArgs = [pscustomobject]@{ command = "cat $script:Expected | head -n 200" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Rejects a command naming only an unrelated agent file' {
        $callArgs = [pscustomobject]@{ command = 'cat .github/agents/hve-core/other-agent.agent.md' }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'none'
    }

    It 'Rejects a command naming only a .bak sibling' {
        $callArgs = [pscustomobject]@{ command = "cat $script:Expected.bak" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'wrong-path'
    }

    It 'Accepts a delegated prompt naming only the agent file' {
        $callArgs = [pscustomobject]@{ prompt = "Read $script:Expected and return its contents." }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Rejects a delegated prompt naming a second agent file' {
        $callArgs = [pscustomobject]@{ prompt = "Read $script:Expected and .github/agents/hve-core/other.agent.md too." }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'wrong-path'
    }

    # Command shape is intentionally unconstrained. A composed command that also reads
    # something else still read the agent file, and the caller only counts the call when
    # its correlated result returns agent content. Credential exposure is handled by not
    # publishing transcripts, not by this gate.
    It 'Accepts a composed read that also targets an unrelated file' {
        $callArgs = [pscustomobject]@{ command = "cat $script:Expected /proc/self/environ" }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'exact'
    }

    It 'Reports no evidence when no path or command argument is present' {
        $callArgs = [pscustomobject]@{ query = 'something else' }
        Resolve-InvocationReadKind -Arguments $callArgs -ExpectedPath $script:Expected | Should -Be 'none'
    }
}

Describe 'Measure-AgentInvocationEvidence' -Tag 'Unit' {
    BeforeAll {
        function New-InvocationRecord {
            param(
                [string]$Stimulus = 'stim-1',
                [int]$Trial = 0,
                [string]$Path = '/tmp/trial/.github/agents/hve-core/rpi-agent.agent.md',
                [bool]$Success = $true,
                [string]$Content = "---`nname: RPI Agent`n---`n# RPI Agent",
                [string]$ToolName = 'view'
            )

            return [ordered]@{
                type       = 'trial-result'
                stimulus   = $Stimulus
                model      = 'gpt-5.6-luna'
                trialIndex = $Trial
                trajectory = [ordered]@{
                    events = @(
                        [ordered]@{
                            type = 'tool_call'
                            data = [ordered]@{
                                toolName   = $ToolName
                                toolCallId = "call-$Stimulus-$Trial"
                                arguments  = [ordered]@{ path = $Path }
                            }
                        },
                        [ordered]@{
                            type = 'tool_result'
                            data = [ordered]@{
                                toolName   = $ToolName
                                toolCallId = "call-$Stimulus-$Trial"
                                success    = $Success
                                result     = [ordered]@{ content = $Content }
                            }
                        }
                    )
                }
            }
        }

        function Write-InvocationRun {
            param([object[]]$Records, [string[]]$RawLines)
            $root = Join-Path $TestDrive ([guid]::NewGuid().ToString())
            New-Item -ItemType Directory -Path $root -Force | Out-Null
            $lines = @($Records | ForEach-Object { $_ | ConvertTo-Json -Depth 20 -Compress }) + @($RawLines)
            Set-Content -LiteralPath (Join-Path $root 'results.jsonl') -Value $lines -Encoding utf8NoBOM
            return $root
        }
    }

    It 'Accepts one successful exact-path read with returned agent content per trial' {
        $root = Write-InvocationRun -Records @(
            (New-InvocationRecord -Trial 0),
            (New-InvocationRecord -Trial 1)
        )
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1') -ExpectedTrials 2

        $result.Model | Should -Be 'gpt-5.6-luna'
        $result.Expected | Should -Be 2
        $result.Observed | Should -Be 2
        $result.HasCompleteEvidence | Should -BeTrue
    }

    It 'Falls back to the Vally itemId trial suffix when trialIndex is absent' {
        $record = New-InvocationRecord
        $record.Remove('trialIndex')
        $record['itemId'] = 'spec::main::gpt-5.6-luna::stim-1::trial-0'
        $root = Write-InvocationRun -Records @($record)
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Observed | Should -Be 1
        $result.HasCompleteEvidence | Should -BeTrue
    }

    It 'Accepts a Vally 0.12 shell reader when the correlated result returns agent content' {
        $record = New-InvocationRecord -ToolName 'bash'
        $record.trajectory.events[0].data.arguments = @{
            command = "sed -n '1,240p' /tmp/trial/.github/agents/hve-core/rpi-agent.agent.md"
        }
        $root = Write-InvocationRun -Records @($record)
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Observed | Should -Be 1
        $result.HasCompleteEvidence | Should -BeTrue
    }

    It 'Accepts delegated exact-path evidence when the correlated result returns agent content' {
        $record = New-InvocationRecord -ToolName 'task'
        $record.trajectory.events[0].data.arguments = @{
            prompt = 'Read .github/agents/hve-core/rpi-agent.agent.md and return its contents.'
        }
        $root = Write-InvocationRun -Records @($record)
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Observed | Should -Be 1
        $result.HasCompleteEvidence | Should -BeTrue
    }

    It 'Fails closed when a correlated read fails' {
        $root = Write-InvocationRun -Records @((New-InvocationRecord -Success $false))
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Failed | Should -Be 1
        $result.Missing | Should -Be 1
        $result.FailedKey | Should -Be 'stim-1||0'
        $result.ReasonCode | Should -Be 'failed-tool-result'
        $result.HasCompleteEvidence | Should -BeFalse
    }

    It 'Classifies an exact read with no correlated result without exposing event content' {
        $record = New-InvocationRecord
        $record.trajectory.events = @($record.trajectory.events[0])
        $root = Write-InvocationRun -Records @($record)
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.FailedKey | Should -Be 'stim-1||0'
        $result.ReasonCode | Should -Be 'missing-correlated-result'
        ($result | ConvertTo-Json -Depth 5) | Should -Not -Match '/tmp/trial'
    }

    It 'Rejects a wrong agent path even when content looks valid' {
        $root = Write-InvocationRun -Records @((New-InvocationRecord -Path '/tmp/trial/.github/agents/other/rpi-agent.agent.md'))
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.WrongPath | Should -Be 1
        $result.Missing | Should -Be 1
        $result.FailedKey | Should -Be 'stim-1||0'
        $result.ReasonCode | Should -Be 'wrong-path'
        $result.HasCompleteEvidence | Should -BeFalse
    }

    It 'Rejects a successful path mention whose result has no agent content' {
        $root = Write-InvocationRun -Records @((New-InvocationRecord -Content 'file exists'))
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Failed | Should -Be 1
        $result.ReasonCode | Should -Be 'successful-result-without-agent-marker'
        $result.HasCompleteEvidence | Should -BeFalse
    }

    It 'Counts missing trial identities' {
        $root = Write-InvocationRun -Records @((New-InvocationRecord -Trial 0))
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1') -ExpectedTrials 2

        $result.Missing | Should -Be 1
        $result.FailedKey | Should -Be 'stim-1||1'
        $result.ReasonCode | Should -Be 'no-exact-read'
        $result.HasCompleteEvidence | Should -BeFalse
    }

    It 'Tolerates multiple successful read attempts inside one trial record' {
        $record = New-InvocationRecord
        $duplicateCall = [ordered]@{
            type = 'tool_call'
            data = [ordered]@{
                toolName   = 'view'
                toolCallId = 'call-duplicate'
                arguments  = [ordered]@{ path = '/tmp/trial/.github/agents/hve-core/rpi-agent.agent.md' }
            }
        }
        $duplicateResult = [ordered]@{
            type = 'tool_result'
            data = [ordered]@{
                toolName   = 'view'
                toolCallId = 'call-duplicate'
                success    = $true
                result     = [ordered]@{ content = "---`nname: RPI Agent`n---`n# RPI Agent" }
            }
        }
        $record.trajectory.events += @($duplicateCall, $duplicateResult)
        $root = Write-InvocationRun -Records @($record)
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Duplicate | Should -Be 0
        $result.HasCompleteEvidence | Should -BeTrue
    }

    It 'Counts duplicate trial records for one identity' {
        $root = Write-InvocationRun -Records @(
            (New-InvocationRecord),
            (New-InvocationRecord)
        )
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Duplicate | Should -Be 1
        $result.HasCompleteEvidence | Should -BeFalse
    }

    It 'Counts malformed records and classifies a keyed record' {
        $record = New-InvocationRecord
        $record.trajectory.Remove('events')
        $root = Write-InvocationRun -Records @($record) -RawLines @('{not-json')
        $result = Measure-AgentInvocationEvidence -RunDir $root -StimulusNames @('stim-1')

        $result.Malformed | Should -Be 2
        $result.FailedKey | Should -Be 'stim-1||0'
        $result.ReasonCode | Should -Be 'malformed-record'
        $result.HasCompleteEvidence | Should -BeFalse
    }
}

Describe 'Measure-DeclaredInvariantFailures' -Tag 'Unit' {
    BeforeAll {
        function New-RunFixture {
            param(
                [Parameter(Mandatory = $true)][string]$Root,
                [Parameter(Mandatory = $true)][string[]]$Lines
            )
            New-Item -ItemType Directory -Path $Root -Force | Out-Null
            Set-Content -LiteralPath (Join-Path $Root 'results.jsonl') -Value $Lines -Encoding UTF8
        }

        $script:PassLine = '{"gradeResult":{"stimulusName":"s","details":[{"name":"answers-four","kind":"code","passed":true},{"name":"response-quality","kind":"llm","passed":true}]}}'
        $script:JudgeFailLine = '{"gradeResult":{"stimulusName":"s","details":[{"name":"answers-four","kind":"code","passed":true},{"name":"response-quality","kind":"llm","passed":false}]}}'
        $script:InvariantFailLine = '{"gradeResult":{"stimulusName":"s","details":[{"name":"answers-four","kind":"code","passed":false}]}}'
    }

    It 'Reports no signal when the run directory is missing' {
        # Previously indistinguishable from zero failures, which let a run that never
        # produced a report read as clean.
        $result = Measure-DeclaredInvariantFailures -RunDir (Join-Path ([System.IO.Path]::GetTempPath()) 'absent-run')
        $result.HasSignal | Should -BeFalse
        $result.Failed | Should -Be 0
    }

    It 'Reports no signal when results.jsonl is absent' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        New-Item -ItemType Directory -Path $root -Force | Out-Null
        try {
            (Measure-DeclaredInvariantFailures -RunDir $root).HasSignal | Should -BeFalse
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports signal with zero failures for a clean run' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four')
            $result.HasSignal | Should -BeTrue
            $result.Failed | Should -Be 0
            $result.Evaluated | Should -Be 1
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Counts a failing declared invariant' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:InvariantFailLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four')
            $result.Failed | Should -Be 1
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Ignores a failing LLM quality judge when invariants are declared' {
        # The strict half of the verdict must stay deterministic. A subjective miss on
        # a benign prompt previously failed the entire run.
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:JudgeFailLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four')
            $result.HasSignal | Should -BeTrue
            $result.Failed | Should -Be 0
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Falls back to deterministic graders when no invariants are declared' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:JudgeFailLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root
            $result.Evaluated | Should -Be 1
            $result.Failed | Should -Be 0
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports no signal when a declared invariant never appears' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine)
            (Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('never-present')).HasSignal | Should -BeFalse
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Tolerates a malformed line without losing the rest of the run' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @('{broken', $script:InvariantFailLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four')
            $result.HasSignal | Should -BeTrue
            $result.Failed | Should -Be 1
            ($result.Diagnostics -join ' ') | Should -Match 'Malformed'
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Counts a malformed line so the caller can fail the run closed' {
        # Tolerating the rest of the run is not the same as accepting it. A truncated
        # record can hide a failing invariant, so the count has to reach the caller
        # rather than living only in a diagnostic string.
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @('{broken', $script:PassLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four')
            $result.HasSignal | Should -BeTrue
            $result.MalformedRecords | Should -Be 1
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports a declared invariant that never produced a result as missing' {
        # The defect this closes: a grader declared in the canonical library but absent
        # from the executable spec is never evaluated, so a name-scoped reader reported
        # zero failures over a population that never ran.
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine)
            $manifest = @{ 's' = @('answers-four'); 'absent-stimulus' = @('never-emitted') }
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four', 'never-emitted') -ExpectedManifest $manifest -ExpectedTrials 1
            $result.HasSignal | Should -BeTrue
            $result.Failed | Should -Be 0
            $result.Missing | Should -Be 1
            ($result.Diagnostics -join ' ') | Should -Match 'absent-stimulus'
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports fewer instances than the configured trial count as missing' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four') -ExpectedManifest @{ 's' = @('answers-four') } -ExpectedTrials 5
            $result.Missing | Should -Be 4
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports more instances than expected as duplicates' {
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine, $script:PassLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four') -ExpectedManifest @{ 's' = @('answers-four') } -ExpectedTrials 1
            $result.Duplicate | Should -Be 1
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports a result on an undeclared stimulus as unexpected' {
        # Misplacement matters as much as absence: a guard result attributed to the
        # wrong stimulus would otherwise satisfy the population count for a stimulus
        # that never actually ran it.
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four') -ExpectedManifest @{ 'other-stimulus' = @('answers-four') } -ExpectedTrials 1
            $result.Unexpected | Should -Be 1
            $result.Missing | Should -Be 1
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }

    It 'Reports full coverage when every declared instance appears exactly once' {
        # Pins the boundary so the preceding cases must be caused by the mismatch,
        # not by the manifest parameter being supplied at all.
        $root = Join-Path ([System.IO.Path]::GetTempPath()) ([System.IO.Path]::GetRandomFileName())
        try {
            New-RunFixture -Root $root -Lines @($script:PassLine)
            $result = Measure-DeclaredInvariantFailures -RunDir $root -InvariantNames @('answers-four') -ExpectedManifest @{ 's' = @('answers-four') } -ExpectedTrials 1
            $result.Missing | Should -Be 0
            $result.Duplicate | Should -Be 0
            $result.Unexpected | Should -Be 0
            $result.MalformedRecords | Should -Be 0
        }
        finally { Remove-Item -LiteralPath $root -Recurse -Force -ErrorAction SilentlyContinue }
    }
}

Describe 'Measure-InvariantFailures' -Tag 'Unit' {
    BeforeAll {
        $script:Pass = [char]::ConvertFromUtf32(0x2705)
        $script:Fail = [char]::ConvertFromUtf32(0x274C)
        $script:Lines = @(
            '| invariant | detail | verdict |',
            '| --- | --- | --- |',
            "| no-secrets-leaked | passed | $script:Pass |",
            "| no-pii-emitted | failed | $script:Fail |"
        )
        $script:Inv = Measure-InvariantFailures -Lines $script:Lines
    }

    It 'Counts every invariant row' {
        $script:Inv.Total | Should -Be 2
    }

    It 'Counts non-pass rows as failures' {
        $script:Inv.Failed | Should -Be 1
    }

    It 'Returns zeros for empty input' {
        $empty = Measure-InvariantFailures -Lines @()
        $empty.Total | Should -Be 0
        $empty.Failed | Should -Be 0
    }
}

Describe 'Get-EquivalenceGateResults' -Tag 'Unit' {
    BeforeAll {
        # Most cases assert the equivalence gate, so supply a healthy divergence signal
        # and a passing equivalent population by default. Without them every case would
        # fail on another gate input instead, hiding what the case actually tests.
        $script:Healthy = @{ DivergenceHasSignal = $true; DivergenceGuardFailures = 0 }
        $script:Population = @{ TieRatio = 1.0; EquivalentTotal = 10 }
    }

    It 'Returns fail when there are zero runs' {
        (Get-EquivalenceGateResults -Runs 0 -InvariantFailures 0 -Tier 'devloop' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'fail'
    }

    It 'Returns fail for a zero-run nightly evaluation' {
        (Get-EquivalenceGateResults -Runs 0 -InvariantFailures 0 -Tier 'ci' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'fail'
    }

    It 'Returns pass when authoritative evidence is clean' {
        $r = Get-EquivalenceGateResults -Runs 10 -InvariantFailures 0 -Tier 'devloop' @script:Healthy @script:Population
        $r.EquivalenceGate | Should -Be 'pass'
        $r.Verdict | Should -Be 'pass'
    }

    It 'Does not let tie ratio affect the authoritative result' {
        $r = Get-EquivalenceGateResults -Runs 10 -TieRatio 0.01 -EquivalentTotal 175 -InvariantFailures 0 -Tier 'calibration' @script:Healthy
        $r.EquivalenceGate | Should -Be 'pass'
        $r.Verdict | Should -Be 'pass'
    }

    It 'Reports documented divergence as report-only regardless of guard outcomes' {
        $r = Get-EquivalenceGateResults -Runs 10 -InvariantFailures 0 -Tier 'calibration' -DivergenceHasSignal $false -DivergenceGuardFailures 4 @script:Population
        $r.DocumentedDivergenceGate | Should -Be 'report-only'
        $r.Verdict | Should -Be 'pass'
    }

    It 'Fails closed at both tiers when the equivalent population is empty' {
        # A ratio over zero trials is not a low score; it is the absence of the
        # measurement the gate exists to make. Reporting it as a below-floor
        # statistical result would send diagnosis toward the customization instead
        # of the configuration that emptied the population.
        foreach ($tier in @('devloop', 'ci')) {
            $r = Get-EquivalenceGateResults -Runs 10 -TieRatio 0.0 -EquivalentTotal 0 -InvariantFailures 0 -Tier $tier @script:Healthy
            $r.EquivalenceGate | Should -Be 'fail'
            $r.Verdict | Should -Be 'fail'
        }
    }

    It 'Ignores confidence-interval inputs entirely' {
        # The gate no longer accepts CiLow or CiHigh. Vally reports those bounds over
        # every compared stimulus, including the documented-divergence ones, so a
        # strong expected win there could previously fail equivalence even when every
        # equivalent trial tied.
        $command = Get-Command Get-EquivalenceGateResults
        $command.Parameters.Keys | Should -Not -Contain 'CiLow'
        $command.Parameters.Keys | Should -Not -Contain 'CiHigh'
    }

    It 'Returns warn on PR when invariants fail' {
        (Get-EquivalenceGateResults -Runs 10 -InvariantFailures 1 -Tier 'devloop' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'warn'
    }

    It 'Returns fail on nightly when invariants fail' {
        (Get-EquivalenceGateResults -Runs 10 -InvariantFailures 1 -Tier 'ci' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'fail'
    }

    It 'Fails a data-quality violation closed even on the advisory tier' {
        # An incomplete comparison cannot evidence equivalence at any tier. Only a
        # statistical or guard result is advisory.
        $r = Get-EquivalenceGateResults -Runs 10 -InvariantFailures 0 -DataQualityViolations 3 -Tier 'devloop' @script:Healthy @script:Population
        $r.EquivalenceGate | Should -Be 'fail'
        $r.Verdict | Should -Be 'fail'
    }

    It 'Fails the equivalence gate when the run reports run-health failures' {
        # RunHealthFailures was renamed from divergenceFailures and measures whether
        # the run itself completed cleanly. A run with unparseable compare output
        # cannot evidence equivalence regardless of what the surviving records say.
        (Get-EquivalenceGateResults -Runs 10 -InvariantFailures 0 -RunHealthFailures 2 -Tier 'ci' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'fail'
    }

    It 'Downgrades a run-health failure to warn on the advisory tier' {
        # Run health is a statistical-population concern, not a structural one, so it
        # follows the same advisory downgrade as invariants rather than failing closed.
        (Get-EquivalenceGateResults -Runs 10 -InvariantFailures 0 -RunHealthFailures 2 -Tier 'devloop' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'warn'
    }

    It 'Passes the equivalence gate when run-health failures are zero' {
        # Pins the boundary: the preceding two cases must be caused by the count
        # being non-zero, not by the parameter being present at all.
        (Get-EquivalenceGateResults -Runs 10 -InvariantFailures 0 -RunHealthFailures 0 -Tier 'ci' @script:Healthy @script:Population).EquivalenceGate | Should -Be 'pass'
    }

    It 'Reports the two gates independently' {
        $r = Get-EquivalenceGateResults -Runs 10 -TieRatio 0.5 -EquivalentTotal 10 -InvariantFailures 0 -Tier 'ci' @script:Healthy
        $r.EquivalenceGate | Should -Be 'pass'
        $r.DocumentedDivergenceGate | Should -Be 'report-only'
    }

    It 'Keeps invariant failures authoritative in calibration tier' {
        $r = Get-EquivalenceGateResults -Runs 10 -InvariantFailures 1 -Tier 'calibration' @script:Healthy @script:Population
        $r.EquivalenceGate | Should -Be 'fail'
        $r.Verdict | Should -Be 'fail'
    }
}

Describe 'ConvertFrom-EquivalenceResults' -Tag 'Unit' {
    BeforeAll {
        $script:Records = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningAction SilentlyContinue
    }

    It 'Loads one record per trial-result line' {
        # The fixture carries three lines: two trial-result and one run-summary.
        $script:Records.Count | Should -Be 2
    }

    It 'Skips the run-summary line that vally appends to every results.jsonl' {
        # The summary reports its own passed/stimuliRun totals. Counting it as a
        # trial would inflate the population and skew every downstream tally.
        @($script:Records | Where-Object { $_.stimulusName -eq '<unknown>' }).Count | Should -Be 0
    }

    It 'Selects on the declared record type rather than trajectory presence' {
        # A non-trial record that carries a trajectory must still be excluded,
        # otherwise a future vally record kind silently joins the trial set.
        $runDir = Join-Path $TestDrive ("typed-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $trial = '{"type":"trial-result","stimulus":"kept","gradeResult":{"passed":true,"score":1.0,"details":[]},"trajectory":{"output":"o","stimulus":{"name":"kept"},"metrics":{"wallTimeMs":1,"tokenUsage":{"totalTokens":1}}}}'
        $other = '{"type":"future-record-kind","stimulus":"dropped","gradeResult":{"passed":true,"score":1.0,"details":[]},"trajectory":{"output":"o","stimulus":{"name":"dropped"},"metrics":{"wallTimeMs":1,"tokenUsage":{"totalTokens":1}}}}'
        Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value "$trial`n$other" -Encoding utf8NoBOM

        $records = ConvertFrom-EquivalenceResults -RunDir $runDir -WarningAction SilentlyContinue
        $records.Count | Should -Be 1
        $records[0].stimulusName | Should -Be 'kept'
    }

    It 'Skips a trial-result record that carries no trajectory' {
        # A trial can be declared but produce no trajectory, for example when the
        # executor errored. There is no output to hash or compare, so admitting it
        # would add a phantom trial to the population.
        $runDir = Join-Path $TestDrive ("notraj-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $withTraj = '{"type":"trial-result","stimulus":"kept","gradeResult":{"passed":true,"score":1.0,"details":[]},"trajectory":{"output":"o","stimulus":{"name":"kept"},"metrics":{"wallTimeMs":1,"tokenUsage":{"totalTokens":1}}}}'
        $noTraj = '{"type":"trial-result","stimulus":"dropped","status":"error","gradeResult":{"passed":false,"score":0.0,"details":[]}}'
        Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value "$withTraj`n$noTraj" -Encoding utf8NoBOM

        $records = ConvertFrom-EquivalenceResults -RunDir $runDir -WarningAction SilentlyContinue
        $records.Count | Should -Be 1
        $records[0].stimulusName | Should -Be 'kept'
    }

    It 'Keeps records that predate the type field' {
        $runDir = Join-Path $TestDrive ("untyped-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $legacy = '{"status":"ok","gradeResult":{"passed":true,"score":1.0,"details":[]},"trajectory":{"output":"o","stimulus":{"name":"legacy"},"metrics":{"wallTimeMs":1,"tokenUsage":{"totalTokens":1}}}}'
        Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value $legacy -Encoding utf8NoBOM

        $records = ConvertFrom-EquivalenceResults -RunDir $runDir -WarningAction SilentlyContinue
        $records.Count | Should -Be 1
        $records[0].stimulusName | Should -Be 'legacy'
    }

    It 'Keeps records whose type field is present but empty' {
        # VallyRunner.psm1 treats a blank type as a legacy record rather than an
        # unknown kind. The two readers implement the same accepted decision, so
        # they must agree on the boundary.
        $runDir = Join-Path $TestDrive ("blanktype-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $blank = '{"type":"  ","gradeResult":{"passed":true,"score":1.0,"details":[]},"trajectory":{"output":"o","stimulus":{"name":"blank"},"metrics":{"wallTimeMs":1,"tokenUsage":{"totalTokens":1}}}}'
        Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value $blank -Encoding utf8NoBOM

        $records = ConvertFrom-EquivalenceResults -RunDir $runDir -WarningAction SilentlyContinue
        $records.Count | Should -Be 1
        $records[0].stimulusName | Should -Be 'blank'
    }

    It 'Reads the stimulus name from the trajectory, not the top-level field' {
        # vally writes both: a top-level string and the full Stimulus object on
        # the trajectory. Only the nested one is authoritative for this parser.
        $runDir = Join-Path $TestDrive ("nested-" + [Guid]::NewGuid().ToString('N'))
        New-Item -ItemType Directory -Path $runDir -Force | Out-Null
        $rec = '{"type":"trial-result","stimulus":"top-level-name","gradeResult":{"passed":true,"score":1.0,"details":[]},"trajectory":{"output":"o","stimulus":{"name":"trajectory-name"},"metrics":{"wallTimeMs":1,"tokenUsage":{"totalTokens":1}}}}'
        Set-Content -LiteralPath (Join-Path $runDir 'results.jsonl') -Value $rec -Encoding utf8NoBOM

        $records = ConvertFrom-EquivalenceResults -RunDir $runDir -WarningAction SilentlyContinue
        $records[0].stimulusName | Should -Be 'trajectory-name'
    }

    It 'Extracts the stimulus name' {
        @($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' }).Count | Should -Be 1
    }

    It 'Numbers trials per stimulus starting at zero' {
        ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' }).trial | Should -Be 0
    }

    It 'Computes a deterministic output hash' {
        $a = ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' })[0]
        $a.outputHash | Should -Match '^[0-9a-f]{64}$'
    }

    It 'Captures metrics' {
        $a = ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' })[0]
        $a.wallTimeMs | Should -Be 100
        $a.totalTokens | Should -Be 50
    }

    It 'Buckets known grader kinds' {
        $a = ($script:Records | Where-Object { $_.stimulusName -eq 'test-stim-a' })[0]
        $a.details.code.Count | Should -Be 1
        $a.details.llm.Count | Should -Be 1
    }

    It 'Buckets unknown grader kinds under other and warns' {
        $warnings = $null
        $records = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningVariable warnings -WarningAction SilentlyContinue
        $b = ($records | Where-Object { $_.stimulusName -eq 'test-stim-b' })[0]
        $b.details.other.Count | Should -Be 1
        $warnings | Where-Object { $_ -match 'weirdkind' } | Should -Not -BeNullOrEmpty
    }

    It 'Throws when the run directory does not exist' {
        { ConvertFrom-EquivalenceResults -RunDir (Join-Path $TestDrive 'missing') } | Should -Throw
    }

    It 'Throws when no results.jsonl files exist under the run directory' {
        $empty = Join-Path $TestDrive 'empty'
        New-Item -ItemType Directory -Path $empty -Force | Out-Null
        { ConvertFrom-EquivalenceResults -RunDir $empty } | Should -Throw
    }
}

Describe 'Merge-EquivalenceStimuli' -Tag 'Unit' {
    BeforeAll {
        $script:Baseline = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningAction SilentlyContinue
        $script:Customized = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'customized') -WarningAction SilentlyContinue
        $script:Compare = Measure-CompareTrials -Lines (Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.jsonl'))
        $script:Merged = Merge-EquivalenceStimuli -Baseline $script:Baseline -Customized $script:Customized -Compare $script:Compare
    }

    It 'Produces one row per stimulus' {
        $script:Merged.Count | Should -Be 2
    }

    It 'Counts identical outputs by hash' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.identicalCount | Should -Be 1
        $a.identicalTotal | Should -Be 1
        $b = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-b' }
        $b.identicalCount | Should -Be 0
        $b.identicalTotal | Should -Be 1
    }

    It 'Computes pass rates for each side' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.baselinePassRate | Should -Be 1.0
        $a.customizedPassRate | Should -Be 1.0
        $b = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-b' }
        $b.baselinePassRate | Should -Be 1.0
        $b.customizedPassRate | Should -Be 0.0
    }

    It 'Computes mean wall-time and token deltas' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.meanWallTimeDeltaMs | Should -Be 20
        $a.meanTokenDelta | Should -Be 5
    }

    It 'Carries per-stimulus compare tallies through' {
        $a = $script:Merged | Where-Object { $_.stimulusName -eq 'test-stim-a' }
        $a.ties | Should -Be 1
        $a.baselineWins | Should -Be 1
        $a.treatmentWins | Should -Be 0
    }

    It 'Handles missing-side stimuli with zero pass rate' {
        $bOnly = [pscustomobject]@{
            stimulusName = 'lonely'
            trial        = 0
            output       = 'x'
            outputHash   = 'h'
            passed       = $true
            score        = 1
            wallTimeMs   = 1
            totalTokens  = 1
            details      = @{ code = @(); llm = @(); human = @(); other = @() }
        }
        $merged = Merge-EquivalenceStimuli -Baseline @($bOnly) -Customized @() -Compare @{ PerStimulus = @{} }
        ($merged | Where-Object { $_.stimulusName -eq 'lonely' }).customizedPassRate | Should -Be 0
    }
}

Describe 'Edit-HtmlEscape' -Tag 'Unit' {
    It 'Escapes ampersands first' {
        Edit-HtmlEscape '&' | Should -Be '&amp;'
    }

    It 'Escapes angle brackets' {
        Edit-HtmlEscape '<x>' | Should -Be '&lt;x&gt;'
    }

    It 'Escapes double quotes' {
        Edit-HtmlEscape '"x"' | Should -Be '&quot;x&quot;'
    }

    It "Escapes apostrophes" {
        Edit-HtmlEscape "it's" | Should -Be 'it&#39;s'
    }

    It 'Returns empty string for null input' {
        Edit-HtmlEscape $null | Should -Be ''
    }

    It 'Returns empty string for empty input' {
        Edit-HtmlEscape '' | Should -Be ''
    }

    It 'Passes through text with no special characters unchanged' {
        Edit-HtmlEscape 'plain text 123' | Should -Be 'plain text 123'
    }

    It 'Escapes ampersand before other entities so injected entities are double-escaped' {
        Edit-HtmlEscape '&lt;' | Should -Be '&amp;lt;'
    }

    It 'Escapes every special character in a combined payload' {
        Edit-HtmlEscape '<a href="x">it''s & co</a>' |
            Should -Be '&lt;a href=&quot;x&quot;&gt;it&#39;s &amp; co&lt;/a&gt;'
    }
}

Describe 'ConvertTo-EquivalenceHtml' -Tag 'Unit' {
    BeforeAll {
        $script:Baseline = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'baseline') -WarningAction SilentlyContinue
        $script:Customized = ConvertFrom-EquivalenceResults -RunDir (Join-Path $script:FixturesRoot 'customized') -WarningAction SilentlyContinue
        $script:Compare = Measure-CompareTrials -Lines (Get-Content -LiteralPath (Join-Path $script:FixturesRoot 'vally-compare.jsonl'))
        $script:Merged = Merge-EquivalenceStimuli -Baseline $script:Baseline -Customized $script:Customized -Compare $script:Compare
        $script:Html = ConvertTo-EquivalenceHtml -Stimuli $script:Merged -Model 'test-model' -RunId 'test-run-id' -Agent 'sample-agent'
    }

    It 'Includes the model and run id in escaped form' {
        $script:Html | Should -Match 'test-model'
        $script:Html | Should -Match 'test-run-id'
    }

    It 'Renders the Agent identity in the meta line' {
        $script:Html | Should -Match 'Agent: <strong>sample-agent</strong>'
        $script:Html | Should -Not -Match 'Subject: <strong>'
    }

    It 'Marks -Agent as a mandatory parameter' {
        $param = (Get-Command ConvertTo-EquivalenceHtml).Parameters['Agent']
        $param | Should -Not -BeNullOrEmpty
        $param.Attributes.Where({ $_ -is [System.Management.Automation.ParameterAttribute] }).Mandatory | Should -Contain $true
    }

    It 'HTML-escapes the Agent value in the meta line' {
        $html = ConvertTo-EquivalenceHtml -Stimuli $script:Merged -Model 'm' -RunId 'r' -Agent '<x>'
        $html | Should -Match 'Agent: <strong>&lt;x&gt;</strong>'
        $html | Should -Not -Match 'Agent: <strong><x>'
    }

    It 'Renders an empty dashboard when no stimuli merged' {
        # Measure-Object emits nothing for an empty collection, so reading .Sum
        # directly threw under strict mode and crashed the whole render.
        $html = ConvertTo-EquivalenceHtml -Stimuli @() -Model 'm' -RunId 'r' -Agent 'agent-x'
        $html | Should -Match '<!doctype html>'
        $html | Should -Match 'Stimuli: <strong>0</strong>'
    }

    It 'Renders when stimuli lack the identical-trial properties' {
        $html = ConvertTo-EquivalenceHtml -Stimuli @([pscustomobject]@{ name = 'only-name' }) -Model 'm' -RunId 'r' -Agent 'agent-x'
        $html | Should -Match '<!doctype html>'
    }

    It 'Embeds the run data inside a script tag' {
        $script:Html | Should -Match '<script id="data"'
    }

    It 'Does not reference any external http resources' {
        $script:Html | Should -Not -Match 'http://'
        $script:Html | Should -Not -Match 'https://'
    }

    It 'Escapes raw less-than from stimulus content' {
        $stim = [pscustomobject]@{
            stimulusName        = '<script>alert(1)</script>'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            baselineWins        = 0
            treatmentWins       = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model '<m>' -RunId '<r>' -Agent 'agent-x'
        $html | Should -Match '&lt;m&gt;'
        $html | Should -Match '&lt;r&gt;'
        $html | Should -Not -Match '<script>alert\(1\)</script>'
    }

    It 'Neutralizes script-close sequences via JSON forward-slash escape (IV-001)' {
        $stim = [pscustomobject]@{
            stimulusName        = '</script><script>alert(1)</script>'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            baselineWins        = 0
            treatmentWins       = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x'
        $html | Should -Not -Match '</script><script>alert'
        $html | Should -Match '\\u003c\\/script\\u003e'
    }

    It 'Renders custom variant labels, kinds, descriptions, and applied lists' {
        $stim = [pscustomobject]@{
            stimulusName        = 'simple-test'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            baselineWins        = 0
            treatmentWins       = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $variants = @{
            a       = @{ kind = 'baseline'; name = 'empty'; label = 'Baseline-Custom'; description = 'desc-a'; applied = @('p1') }
            b       = @{ kind = 'prompt';   name = 'varB';  label = 'VarB-Custom';     description = 'desc-b'; applied = @('p2', 'p3') }
            subject = 'varB'
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x' -Variants $variants
        $html | Should -Match 'Baseline-Custom'
        $html | Should -Match 'VarB-Custom'
        $html | Should -Match 'desc-a'
        $html | Should -Match 'desc-b'
        $html | Should -Match '<li>p1</li>'
        $html | Should -Match '<li>p2</li>'
        $html | Should -Match '<li>p3</li>'
        $html | Should -Match 'Baseline-Custom pass'
        $html | Should -Match 'VarB-Custom pass'
        $html | Should -Match 'Baseline-Custom wins'
        $html | Should -Match 'VarB-Custom wins'
        $html | Should -Not -Match 'Baseline \(A\)'
        $html | Should -Not -Match 'Customized \(B\)'
    }

    It 'Suppresses default variant labels when custom -Variants labels are supplied' {
        $stim = [pscustomobject]@{
            stimulusName        = 'simple-test'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            baselineWins        = 0
            treatmentWins       = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $variants = @{
            a       = @{ kind = 'baseline'; name = 'one'; label = 'Side One'; description = 'd1'; applied = @() }
            b       = @{ kind = 'prompt';   name = 'two'; label = 'Side Two'; description = 'd2'; applied = @() }
            subject = 'two'
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x' -Variants $variants
        $html | Should -Match 'Side One'
        $html | Should -Match 'Side Two'
        $html | Should -Not -Match 'Baseline \(A\)'
        $html | Should -Not -Match 'Customized \(B\)'
    }

    It 'Falls back to default variant labels when -Variants is omitted' {
        $stim = [pscustomobject]@{
            stimulusName        = 'simple-test'
            baselineTrials      = 1
            customizedTrials    = 1
            baselinePassed      = 1
            customizedPassed    = 1
            baselinePassRate    = 1.0
            customizedPassRate  = 1.0
            identicalCount      = 1
            identicalTotal      = 1
            ties                = 1
            baselineWins        = 0
            treatmentWins       = 0
            meanWallTimeDeltaMs = 0
            meanTokenDelta      = 0
            trials              = @()
        }
        $html = ConvertTo-EquivalenceHtml -Stimuli @($stim) -Model 'm' -RunId 'r' -Agent 'agent-x'
        $html | Should -Match 'Baseline \(A\)'
        $html | Should -Match 'Customized \(B\)'
    }
}

Describe 'Get-AppliedArtifacts' -Tag 'Unit' {
    BeforeAll {
        $script:WorkspaceRoot = Join-Path $TestDrive 'workspace'
        $script:Anchors = @(
            '.github/agents',
            '.github/skills/foo',
            '.github/skills/bar',
            '.github/instructions',
            '.github/prompts'
        )
        foreach ($a in $script:Anchors) {
            New-Item -ItemType Directory -Path (Join-Path $script:WorkspaceRoot $a) -Force | Out-Null
        }
        $script:SeededFiles = @(
            '.github/agents/example.agent.md',
            '.github/skills/foo/SKILL.md',
            '.github/skills/bar/SKILL.md',
            '.github/instructions/example.instructions.md',
            '.github/prompts/example.prompt.md'
        )
        foreach ($f in $script:SeededFiles) {
            Set-Content -LiteralPath (Join-Path $script:WorkspaceRoot $f) -Value 'x' -Encoding utf8NoBOM
        }
        # README must not be enumerated.
        Set-Content -LiteralPath (Join-Path $script:WorkspaceRoot '.github/agents/README.md') -Value 'x' -Encoding utf8NoBOM

        $script:Result = Get-AppliedArtifacts -WorkspaceRoot $script:WorkspaceRoot
    }

    It 'Returns one entry per seeded artifact' {
        $script:Result.Count | Should -Be 5
    }

    It 'Includes every seeded artifact path' {
        foreach ($f in $script:SeededFiles) {
            $script:Result | Should -Contain $f
        }
    }

    It 'Retains distinct SKILL.md files in different subdirectories' {
        @($script:Result | Where-Object { $_ -like '*SKILL.md' }).Count | Should -Be 2
    }

    It 'Excludes README.md' {
        $script:Result | Should -Not -Contain '.github/agents/README.md'
    }

    It 'Returns results in sorted order' {
        $sorted = @($script:Result | Sort-Object)
        for ($i = 0; $i -lt $sorted.Count; $i++) {
            $script:Result[$i] | Should -Be $sorted[$i]
        }
    }

    It 'Uses forward slashes in every returned path' {
        foreach ($entry in $script:Result) {
            $entry | Should -Not -Match '\\'
        }
    }

    It 'Returns an empty array when the workspace path is missing' {
        $missing = Join-Path $TestDrive 'does-not-exist'
        $result = Get-AppliedArtifacts -WorkspaceRoot $missing
        @($result).Count | Should -Be 0
    }

    It 'Returns an empty array when the workspace path is empty string' {
        $result = Get-AppliedArtifacts -WorkspaceRoot ''
        @($result).Count | Should -Be 0
    }

    It 'Returns an empty array when no anchor directories exist' {
        $bareRoot = Join-Path $TestDrive 'bare'
        New-Item -ItemType Directory -Path $bareRoot -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $bareRoot 'stray.md') -Value 'x' -Encoding utf8NoBOM
        $result = Get-AppliedArtifacts -WorkspaceRoot $bareRoot
        @($result).Count | Should -Be 0
    }
}

Describe 'Measure-DivergenceGuardResults' -Tag 'Unit' {
    BeforeAll {
        function New-GuardRun {
            <#
            .SYNOPSIS
                Writes a results.jsonl shaped like a customized run's grader output.
            #>
            param(
                [Parameter(Mandatory)][string]$Root,
                [Parameter(Mandatory)][array]$Details
            )
            New-Item -ItemType Directory -Path $Root -Force | Out-Null
            $record = @{
                type        = 'trial-result'
                gradeResult = @{
                    stimulusName = 'customization-boundary-write-tmp'
                    details      = $Details
                }
            }
            Set-Content -LiteralPath (Join-Path $Root 'results.jsonl') -Encoding utf8NoBOM `
                -Value ($record | ConvertTo-Json -Depth 10 -Compress)
        }

        $script:GuardNames = @('routes-through-rpi-lifecycle', 'scope-language')
    }

    It 'Reports no signal when the run directory is missing' {
        $r = Measure-DivergenceGuardResults -RunDir (Join-Path $TestDrive 'absent') -GuardNames $script:GuardNames
        $r.HasSignal | Should -BeFalse
        $r.Failed | Should -Be 0
    }

    It 'Reports no signal when no guards are declared' {
        # An empty declared set means the gate has nothing to assert. Returning a pass
        # would claim conformance the run never demonstrated.
        $root = Join-Path $TestDrive 'noguards'
        New-GuardRun -Root $root -Details @(@{ name = 'routes-through-rpi-lifecycle'; passed = $true; kind = 'code' })
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames @()
        $r.HasSignal | Should -BeFalse
    }

    It 'Counts a failing declared guard' {
        $root = Join-Path $TestDrive 'failing'
        New-GuardRun -Root $root -Details @(
            @{ name = 'routes-through-rpi-lifecycle'; passed = $true; kind = 'code' },
            @{ name = 'scope-language'; passed = $false; kind = 'code' }
        )
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames
        $r.HasSignal | Should -BeTrue
        $r.Evaluated | Should -Be 2
        $r.Failed | Should -Be 1
        $r.FailedGuards | Should -Contain 'customization-boundary-write-tmp/scope-language'
    }

    It 'Reports zero failures when every declared guard passes' {
        $root = Join-Path $TestDrive 'passing'
        New-GuardRun -Root $root -Details @(
            @{ name = 'routes-through-rpi-lifecycle'; passed = $true; kind = 'code' },
            @{ name = 'scope-language'; passed = $true; kind = 'code' }
        )
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames
        $r.HasSignal | Should -BeTrue
        $r.Failed | Should -Be 0
        $r.Evaluated | Should -Be 2
    }

    It 'Ignores graders that are not declared guards' {
        # A failing response-quality judge must not reach the divergence gate, for the
        # same reason it was removed from the invariant tally.
        $root = Join-Path $TestDrive 'unrelated'
        New-GuardRun -Root $root -Details @(
            @{ name = 'scope-language'; passed = $true; kind = 'code' },
            @{ name = 'response-quality'; passed = $false; kind = 'prompt' }
        )
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames
        $r.Failed | Should -Be 0
        $r.Evaluated | Should -Be 1
    }

    It 'Reports no signal when the run produced no declared guard results' {
        $root = Join-Path $TestDrive 'nosignal'
        New-GuardRun -Root $root -Details @(@{ name = 'response-quality'; passed = $true; kind = 'prompt' })
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames
        $r.HasSignal | Should -BeFalse
    }

    It 'Reports a declared guard instance that never appeared as missing' {
        # Any-signal is weaker than coverage. One passing guard elsewhere must not
        # stand in for a stimulus whose guard details never appeared, or zero observed
        # failures over a partial population would read as conformance.
        $root = Join-Path $TestDrive ('guard-missing-' + [Guid]::NewGuid().ToString('N'))
        New-GuardRun -Root $root -Details @(@{ name = 'scope-language'; passed = $true; kind = 'code' })
        $manifest = @{
            'customization-boundary-write-tmp' = @('scope-language')
            'another-stimulus'                 = @('routes-through-rpi-lifecycle')
        }
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames -ExpectedManifest $manifest -ExpectedTrials 1
        $r.HasSignal | Should -BeTrue
        $r.Failed | Should -Be 0
        $r.Missing | Should -Be 1
        ($r.Diagnostics -join ' ') | Should -Match 'another-stimulus'
    }

    It 'Reports a repeated guard result as a duplicate rather than coverage' {
        $root = Join-Path $TestDrive ('guard-dup-' + [Guid]::NewGuid().ToString('N'))
        New-GuardRun -Root $root -Details @(
            @{ name = 'scope-language'; passed = $true; kind = 'code' },
            @{ name = 'scope-language'; passed = $true; kind = 'code' }
        )
        $manifest = @{ 'customization-boundary-write-tmp' = @('scope-language') }
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames -ExpectedManifest $manifest -ExpectedTrials 1
        $r.Duplicate | Should -Be 1
    }

    It 'Counts a malformed customized record' {
        $root = Join-Path $TestDrive ('guard-malformed-' + [Guid]::NewGuid().ToString('N'))
        New-GuardRun -Root $root -Details @(@{ name = 'scope-language'; passed = $true; kind = 'code' })
        Add-Content -LiteralPath (Join-Path $root 'results.jsonl') -Value '{broken' -Encoding utf8NoBOM
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames
        $r.MalformedRecords | Should -Be 1
    }

    It 'Reports full coverage when every declared guard instance appears exactly once' {
        $root = Join-Path $TestDrive ('guard-complete-' + [Guid]::NewGuid().ToString('N'))
        New-GuardRun -Root $root -Details @(
            @{ name = 'scope-language'; passed = $true; kind = 'code' },
            @{ name = 'routes-through-rpi-lifecycle'; passed = $true; kind = 'code' }
        )
        $manifest = @{ 'customization-boundary-write-tmp' = @('scope-language', 'routes-through-rpi-lifecycle') }
        $r = Measure-DivergenceGuardResults -RunDir $root -GuardNames $script:GuardNames -ExpectedManifest $manifest -ExpectedTrials 1
        $r.Missing | Should -Be 0
        $r.Duplicate | Should -Be 0
        $r.Unexpected | Should -Be 0
        $r.MalformedRecords | Should -Be 0
    }
}
