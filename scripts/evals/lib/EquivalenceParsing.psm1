# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Shared parsing, aggregation, and rendering helpers for baseline-equivalence eval runs.

.DESCRIPTION
    Consolidates the `vally compare --output` JSONL and results.jsonl parsers used by
    `Invoke-BaselineEquivalence.ps1` and the dashboard generator
    `New-EquivalenceDashboard.ps1`. All public functions are exported via
    `Export-ModuleMember` at the bottom of the file.
#>

Set-StrictMode -Version Latest

function Measure-CompareTrials {
    <#
    .SYNOPSIS
        Aggregates comparison trials, summary statistics, and data-quality signals.
    .DESCRIPTION
        Tallies recognized winners and combines complete confidence-interval pairs
        conservatively by taking the maximum lower and minimum upper bounds.

        Records that cannot be scored are counted rather than skipped. A trial marked
        `errored` is a judge error, an unparseable line is a malformed record, and a
        trajectory present on only one side is unmatched. Each of these previously
        vanished silently, so a run whose comparisons mostly failed could report a
        healthy tie ratio computed from the few survivors. The counts returned here let
        the caller decide, rather than inferring success from absence of evidence.

        Optionally accepts a stimulus policy map. Stimuli tagged `documented-divergence`
        are expected to differ, so counting them against equivalence penalizes intended
        customization. When the map is supplied, equivalent-only tallies are reported
        alongside the totals.

        Optionally accepts the canonical stimulus names and the effective trial count.
        Structural counts detect records that arrived broken, but they cannot detect a
        record that never arrived: a comparison that produced no output for a stimulus
        leaves no malformed line, no judge error, and no unmatched trajectory. Supplying
        the expected population lets every observed (stimulus, trial) pair be reconciled
        against the expected Cartesian set, so a silently truncated run is a data-quality
        violation rather than a smaller denominator that still reports a healthy ratio.
    .PARAMETER Lines
        Raw JSONL lines emitted by `vally compare --output`.
    .PARAMETER StimulusPolicy
        Optional map of stimulus name to policy, used to separate equivalent-only tallies.
    .PARAMETER ExpectedStimulusName
        Optional canonical stimulus names. Reconciliation is skipped when omitted.
    .PARAMETER ExpectedTrialCount
        Optional effective trial count per stimulus. Reconciliation is skipped when zero.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$StimulusPolicy,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$ExpectedStimulusName,

        [Parameter(Mandatory = $false)]
        [int]$ExpectedTrialCount = 0
    )

    $ties = 0; $baselineWins = 0; $treatmentWins = 0; $total = 0
    $equivalentTies = 0; $equivalentTotal = 0
    $equivalentScores = [System.Collections.Generic.List[double]]::new()
    $divergenceTotal = 0
    $summaryCount = 0
    $judgeErrors = 0
    $malformedLines = 0
    $unmatchedBaseline = 0
    $unmatchedTreatment = 0
    $comparisonRecords = 0
    $duplicateTrials = 0
    $observedPairs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $perStimulus = @{}
    $meanScores = [System.Collections.Generic.List[double]]::new()
    $winRates = [System.Collections.Generic.List[double]]::new()
    $ciLows = [System.Collections.Generic.List[double]]::new()
    $ciHighs = [System.Collections.Generic.List[double]]::new()
    $diagnostics = [System.Collections.Generic.List[string]]::new()

    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $record = $line | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        }
        catch {
            # A malformed line is evidence of a broken run, not an empty one.
            $malformedLines++
            $diagnostics.Add('Malformed JSONL line could not be parsed as JSON.')
            continue
        }
        if (-not $record.PSObject.Properties['type'] -or $record.type -ne 'comparison') { continue }
        $comparisonRecords++

        $stimuli = if ($record.PSObject.Properties['stimuli'] -and $record.stimuli) { @($record.stimuli) } else { @() }
        foreach ($stimulus in $stimuli) {
            if (-not $stimulus) { continue }
            $name = if ($stimulus.PSObject.Properties['stimulusName']) { [string]$stimulus.stimulusName } else { '<unknown>' }
            if (-not $perStimulus.ContainsKey($name)) {
                $perStimulus[$name] = @{ Ties = 0; BaselineWins = 0; TreatmentWins = 0; JudgeErrors = 0; Scores = [System.Collections.Generic.List[double]]::new() }
            }

            $policy = if ($StimulusPolicy -and $StimulusPolicy.ContainsKey($name)) { [string]$StimulusPolicy[$name] } else { '' }
            $isEquivalent = ($policy -eq 'equivalent') -or (-not $StimulusPolicy)

            $seenIndices = [System.Collections.Generic.HashSet[string]]::new()
            $trials = if ($stimulus.PSObject.Properties['trials'] -and $stimulus.trials) { @($stimulus.trials) } else { @() }
            $trialPosition = -1
            foreach ($trial in $trials) {
                if (-not $trial) { continue }
                $trialPosition++

                # Recorded before any skip or error path, so a trial that arrived and
                # failed is distinguishable from one that never arrived at all.
                $observedIndex = if ($trial.PSObject.Properties['trialIndex'] -and $null -ne $trial.trialIndex) {
                    [string]$trial.trialIndex
                }
                else {
                    [string]$trialPosition
                }
                [void]$observedPairs.Add("$name`u{241F}$observedIndex")

                if ($trial.PSObject.Properties['trialIndex'] -and $null -ne $trial.trialIndex) {
                    $indexKey = [string]$trial.trialIndex
                    if (-not $seenIndices.Add($indexKey)) {
                        $duplicateTrials++
                        $diagnostics.Add("Duplicate trial index '$indexKey' for stimulus '$name'.")
                    }
                }

                if ($trial.PSObject.Properties['errored'] -and $trial.errored) {
                    $judgeErrors++
                    $perStimulus[$name].JudgeErrors += 1
                    $diagnostics.Add("Judge error on stimulus '$name'.")
                    continue
                }

                $winner = if ($trial.PSObject.Properties['winner']) { [string]$trial.winner } else { '' }
                $hasScore = $trial.PSObject.Properties['score'] -and $null -ne $trial.score
                switch ($winner) {
                    'tie' {
                        $ties++; $total++; $perStimulus[$name].Ties += 1
                        if ($isEquivalent) { $equivalentTies++; $equivalentTotal++ } else { $divergenceTotal++ }
                    }
                    'baseline' {
                        $baselineWins++; $total++; $perStimulus[$name].BaselineWins += 1
                        if ($isEquivalent) { $equivalentTotal++ } else { $divergenceTotal++ }
                    }
                    'treatment' {
                        $treatmentWins++; $total++; $perStimulus[$name].TreatmentWins += 1
                        if ($isEquivalent) { $equivalentTotal++ } else { $divergenceTotal++ }
                    }
                    default {
                        $malformedLines++
                        $diagnostics.Add("Unrecognized winner '$winner' for stimulus '$name'.")
                    }
                }
                if ($isEquivalent -and $winner -in @('tie', 'baseline', 'treatment')) {
                    if ($hasScore) {
                        $score = [double]$trial.score
                        $equivalentScores.Add($score)
                        $perStimulus[$name].Scores.Add($score)
                    }
                    else {
                        $malformedLines++
                        $diagnostics.Add("Equivalent comparison trial for stimulus '$name' has no signed score.")
                    }
                }
            }
        }

        # A trajectory present on only one side means the pair could not be compared.
        # Vally reports these outside the per-stimulus tally, so they are invisible to
        # any count derived from trials alone.
        if ($record.PSObject.Properties['unmatchedBaseline'] -and $record.unmatchedBaseline) {
            $entries = @($record.unmatchedBaseline)
            $unmatchedBaseline += $entries.Count
            foreach ($entry in $entries) { $diagnostics.Add("Unmatched baseline trajectory: $entry") }
        }
        if ($record.PSObject.Properties['unmatchedTreatment'] -and $record.unmatchedTreatment) {
            $entries = @($record.unmatchedTreatment)
            $unmatchedTreatment += $entries.Count
            foreach ($entry in $entries) { $diagnostics.Add("Unmatched treatment trajectory: $entry") }
        }

        if (-not ($record.PSObject.Properties['summary'] -and $record.summary)) { continue }
        $summary = $record.summary
        $hasCiPair = $summary.PSObject.Properties['ciLow'] -and
            $summary.PSObject.Properties['ciHigh'] -and
            $null -ne $summary.ciLow -and
            $null -ne $summary.ciHigh
        if ($hasCiPair) {
            $summaryCount++
            $ciLows.Add([double]$summary.ciLow)
            $ciHighs.Add([double]$summary.ciHigh)
        }
        if ($summary.PSObject.Properties['meanScore'] -and $null -ne $summary.meanScore) { $meanScores.Add([double]$summary.meanScore) }
        if ($summary.PSObject.Properties['winRate'] -and $null -ne $summary.winRate) { $winRates.Add([double]$summary.winRate) }
    }

    $meanScore = if ($meanScores.Count -gt 0) { ($meanScores | Measure-Object -Average).Average } else { 0.0 }
    $winRate = if ($winRates.Count -gt 0) { ($winRates | Measure-Object -Average).Average } else { 0.0 }

    # Reconcile the observed population against the expected Cartesian set. A stimulus
    # that produced no record at all is invisible to every structural counter above,
    # so absence is only detectable by comparing against what was supposed to run.
    $missingTrials = 0
    $unexpectedTrials = 0
    $populationReconciled = $false
    if ($ExpectedStimulusName -and @($ExpectedStimulusName).Count -gt 0 -and $ExpectedTrialCount -gt 0) {
        $populationReconciled = $true
        $expectedPairs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($expectedName in @($ExpectedStimulusName)) {
            if ([string]::IsNullOrWhiteSpace($expectedName)) { continue }
            for ($trialIndex = 0; $trialIndex -lt $ExpectedTrialCount; $trialIndex++) {
                [void]$expectedPairs.Add("$expectedName`u{241F}$trialIndex")
            }
        }

        foreach ($pair in $expectedPairs) {
            if (-not $observedPairs.Contains($pair)) {
                $missingTrials++
                $parts = $pair -split "`u{241F}"
                $diagnostics.Add("Missing comparison trial: stimulus '$($parts[0])' trial $($parts[1]) produced no record.")
            }
        }
        foreach ($pair in $observedPairs) {
            if (-not $expectedPairs.Contains($pair)) {
                $unexpectedTrials++
                $parts = $pair -split "`u{241F}"
                $diagnostics.Add("Unexpected comparison trial: stimulus '$($parts[0])' trial $($parts[1]) is not in the declared population.")
            }
        }
    }
    $ciLow = if ($ciLows.Count -gt 0) { ($ciLows | Measure-Object -Maximum).Maximum } else { 0.0 }
    $ciHigh = if ($ciHighs.Count -gt 0) { ($ciHighs | Measure-Object -Minimum).Minimum } else { 0.0 }

    # The judge-error rate is computed from every trial that was attempted, including
    # the ones that failed, so the denominator is not silently reduced by the failures
    # it is meant to measure.
    $attempted = $total + $judgeErrors
    $judgeErrorRate = if ($attempted -gt 0) { $judgeErrors / $attempted } else { 0.0 }
    $tieRatio = if ($equivalentTotal -gt 0) { $equivalentTies / $equivalentTotal } else { 0.0 }
    $equivalentMeanScore = if ($equivalentScores.Count -gt 0) { ($equivalentScores | Measure-Object -Average).Average } else { 0.0 }
    $equivalentVariance = if ($equivalentScores.Count -gt 1) {
        ($equivalentScores | ForEach-Object { [math]::Pow($_ - $equivalentMeanScore, 2) } | Measure-Object -Sum).Sum / ($equivalentScores.Count - 1)
    }
    else { 0.0 }
    $equivalentStdDev = [math]::Sqrt($equivalentVariance)
    $equivalentStandardError = if ($equivalentScores.Count -gt 0) { $equivalentStdDev / [math]::Sqrt($equivalentScores.Count) } else { 0.0 }
    $equivalentMargin = 1.96 * $equivalentStandardError
    $equivalentPerStimulus = @{}
    foreach ($name in $perStimulus.Keys) {
        $scores = @($perStimulus[$name].Scores)
        if ($scores.Count -eq 0) { continue }
        $stimulusMean = ($scores | Measure-Object -Average).Average
        $stimulusVariance = if ($scores.Count -gt 1) {
            ($scores | ForEach-Object { [math]::Pow($_ - $stimulusMean, 2) } | Measure-Object -Sum).Sum / ($scores.Count - 1)
        }
        else { 0.0 }
        $equivalentPerStimulus[$name] = [ordered]@{
            count   = $scores.Count
            mean    = [math]::Round($stimulusMean, 4)
            stdDev  = [math]::Round([math]::Sqrt($stimulusVariance), 4)
        }
    }
    $reportedPerStimulus = @{}
    foreach ($name in $perStimulus.Keys) {
        $reportedPerStimulus[$name] = [ordered]@{
            Ties          = $perStimulus[$name].Ties
            BaselineWins  = $perStimulus[$name].BaselineWins
            TreatmentWins = $perStimulus[$name].TreatmentWins
            JudgeErrors   = $perStimulus[$name].JudgeErrors
        }
    }

    return @{
        Total              = $total
        Ties               = $ties
        BaselineWins       = $baselineWins
        TreatmentWins      = $treatmentWins
        PerStimulus        = $reportedPerStimulus
        SummaryCount       = $summaryCount
        MeanScore          = [math]::Round($meanScore, 4)
        WinRate            = [math]::Round($winRate, 4)
        CiLow              = [math]::Round($ciLow, 4)
        CiHigh             = [math]::Round($ciHigh, 4)
        JudgeErrors        = $judgeErrors
        JudgeErrorRate     = [math]::Round($judgeErrorRate, 6)
        MalformedRecords   = $malformedLines
        UnmatchedBaseline  = $unmatchedBaseline
        UnmatchedTreatment = $unmatchedTreatment
        DuplicateTrials    = $duplicateTrials
        MissingTrials      = $missingTrials
        UnexpectedTrials   = $unexpectedTrials
        PopulationReconciled = $populationReconciled
        ComparisonRecords  = $comparisonRecords
        EquivalentTotal    = $equivalentTotal
        EquivalentTies     = $equivalentTies
        EquivalentScoreCount = $equivalentScores.Count
        EquivalentMeanScore = [math]::Round($equivalentMeanScore, 4)
        EquivalentStdDev   = [math]::Round($equivalentStdDev, 4)
        EquivalentCiLow    = [math]::Round($equivalentMeanScore - $equivalentMargin, 4)
        EquivalentCiHigh   = [math]::Round($equivalentMeanScore + $equivalentMargin, 4)
        EquivalentPerStimulus = $equivalentPerStimulus
        DivergenceTotal    = $divergenceTotal
        TieRatio           = [math]::Round($tieRatio, 4)
        Diagnostics        = @($diagnostics)
    }
}

function Resolve-ExpectedInstanceCount {
    <#
    .SYNOPSIS
        Builds the expected (stimulus, grader) instance counts for a declared manifest.
    .DESCRIPTION
        Scoping a reader to declared names answers "did any declared grader fail", but
        not "was every declared grader actually evaluated". A grader that is declared in
        the canonical library yet absent from the executable spec is never evaluated, so
        a name-scoped reader reports zero failures over a population that never ran.

        The expected count is the declared grader for each stimulus that declares it,
        multiplied by the effective trial count, so a run that produced fewer instances
        than declared is distinguishable from one that produced them all and passed.
    .OUTPUTS
        [hashtable] Key `stimulus||name`, value expected instance count.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [hashtable]$Manifest,

        [Parameter(Mandatory = $false)]
        [int]$ExpectedTrials = 1
    )

    $expected = @{}
    if (-not $Manifest) { return $expected }

    $multiplier = if ($ExpectedTrials -gt 0) { $ExpectedTrials } else { 1 }
    foreach ($stimulus in $Manifest.Keys) {
        foreach ($name in @($Manifest[$stimulus])) {
            if ([string]::IsNullOrWhiteSpace([string]$name)) { continue }
            $expected["$stimulus||$name"] = $multiplier
        }
    }

    return $expected
}

function Resolve-InvocationReadKind {
    <#
    .SYNOPSIS
        Classifies one tool call as a read of the expected agent file.
    .DESCRIPTION
        Invocation evidence must prove the agent file itself was read. Matching the
        expected path anywhere inside serialized arguments does not prove that, because
        a `.bak` sibling, a differently named agent, or a traversal path all contain the
        expected substring while naming something else.

        The target is therefore resolved per candidate path rather than by substring.
        Command shape is deliberately not constrained: the caller only treats a call as
        evidence when its correlated tool result returns the agent file's content, so
        the content is the operative proof and the composition of the command is not.
        Constraining shape rejected the composed reads both models routinely emit, such
        as `find -path ... -exec sed ...` and `pwd && sed -n ...`, and discarded valid
        trials without adding any measurement guarantee.
    .OUTPUTS
        [string] One of 'exact', 'wrong-path', or 'none'.
    .PARAMETER Arguments
        The tool call's arguments object as emitted in the trajectory.
    .PARAMETER ExpectedPath
        Workspace-relative path of the agent file, using forward separators.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Arguments,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        $ExpectedPath
    )

    if ($null -eq $Arguments) { return 'none' }

    $normalize = {
        param([string]$Candidate)
        if ([string]::IsNullOrWhiteSpace($Candidate)) { return '' }
        $value = $Candidate.Trim().Trim('"', "'")
        $value = $value -replace '\\', '/'
        $value = $value -replace '^\./', ''
        # Shell globs name the target without spelling its root.
        $value = $value -replace '^\*\*/', '' -replace '^\*/', ''
        return $value.TrimStart('/')
    }

    $expected = & $normalize ([string]$ExpectedPath)

    # Vally copies the workspace into a per-trial directory, so a recorded path may be
    # trial-rooted, repository-relative, or a trailing fragment produced by a glob.
    # Each is matched on whole segments, which still rejects a `.bak` sibling, a
    # differently named agent, a partial-segment name, and any traversal.
    $isTarget = {
        param([string]$Candidate)
        $value = & $normalize $Candidate
        if ([string]::IsNullOrEmpty($value)) { return $false }
        if ($value -match '(^|/)\.\.(/|$)') { return $false }
        if ($value -eq $expected) { return $true }
        if ($value.EndsWith("/$expected", [System.StringComparison]::OrdinalIgnoreCase)) { return $true }
        return $expected.EndsWith("/$value", [System.StringComparison]::OrdinalIgnoreCase)
    }

    foreach ($property in @('path', 'filePath', 'file', 'target', 'uri', 'filename')) {
        if ($Arguments.PSObject.Properties[$property] -and $Arguments.$property) {
            $candidate = [string]$Arguments.$property
            if (& $isTarget $candidate) { return 'exact' }
            if ($candidate -match 'rpi-agent\.agent\.md') { return 'wrong-path' }
            return 'none'
        }
    }

    foreach ($property in @('command', 'commandLine', 'script', 'cmd')) {
        if (-not ($Arguments.PSObject.Properties[$property] -and $Arguments.$property)) { continue }
        $command = [string]$Arguments.$property

        foreach ($token in @($command -split '[\s;|&()]+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })) {
            if (& $isTarget $token) { return 'exact' }
        }

        if ($command -match 'rpi-agent\.agent\.md') { return 'wrong-path' }
        return 'none'
    }

    # Delegated readers carry the target in prose rather than as an argument. The
    # correlated tool result still has to return agent content, so this only decides
    # which file the delegation named. Exactly one agent-file reference is required,
    # so a prompt naming both the agent and another file is not evidence.
    foreach ($property in @('prompt', 'instruction', 'input')) {
        if (-not ($Arguments.PSObject.Properties[$property] -and $Arguments.$property)) { continue }
        $prose = [string]$Arguments.$property
        $references = @([regex]::Matches($prose, '[A-Za-z0-9_./\\-]*\.agent\.md') | ForEach-Object { $_.Value })
        if ($references.Count -ne 1) {
            if ($prose -match 'rpi-agent\.agent\.md') { return 'wrong-path' }
            return 'none'
        }
        if (& $isTarget $references[0]) { return 'exact' }
        return 'wrong-path'
    }

    return 'none'
}

function Measure-AgentInvocationEvidence {
    <#
    .SYNOPSIS
        Reconciles successful RPI Agent file reads across a customized run.
    .DESCRIPTION
        A staged agent file is not evidence that the model loaded it. This parser
        requires one successful structured read per expected stimulus and trial. The
        tool call must target the exact staged agent path, the correlated result must
        succeed, and returned content must identify the RPI Agent artifact. The tool
        name is not restricted because Vally can satisfy the same read through
        view, shell readers, search tools, or a delegated tool.

        Missing, duplicate, failed, wrong-path, and malformed evidence is counted so
        callers can fail closed instead of treating absence as successful delivery.
        A single failed key receives a bounded structural reason code without retaining
        tool arguments, result content, transcript text, or absolute paths.
    .OUTPUTS
        [hashtable] Invocation evidence counts, diagnostics, and per-model identity.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RunDir,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$StimulusNames,

        [Parameter(Mandatory = $false)]
        [int]$ExpectedTrials = 1,

        [Parameter(Mandatory = $false)]
        [string]$AgentRelativePath = '.github/agents/hve-core/rpi-agent.agent.md'
    )

    $diagnostics = [System.Collections.Generic.List[string]]::new()
    $expectedKeys = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $observed = @{}
    $recordCounts = @{}
    $failureReasons = @{}
    $failed = 0
    $wrongPath = 0
    $malformed = 0
    $model = ''
    $trialCount = if ($ExpectedTrials -gt 0) { $ExpectedTrials } else { 1 }

    foreach ($stimulus in @($StimulusNames)) {
        if ([string]::IsNullOrWhiteSpace($stimulus)) { continue }
        for ($trial = 0; $trial -lt $trialCount; $trial++) {
            [void]$expectedKeys.Add("$stimulus||$trial")
        }
    }

    if ([string]::IsNullOrWhiteSpace($RunDir) -or -not (Test-Path -LiteralPath $RunDir -PathType Container)) {
        $diagnostics.Add('Customized run directory is missing for invocation evidence.')
        return @{
            Model = ''; Expected = $expectedKeys.Count; Observed = 0; Failed = 0
            Missing = $expectedKeys.Count; Duplicate = 0; WrongPath = 0; Malformed = 0
            FailedKey = $null; ReasonCode = $null
            HasCompleteEvidence = $false; Diagnostics = @($diagnostics)
        }
    }

    $files = @(Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        $diagnostics.Add('No results.jsonl found under the customized run directory for invocation evidence.')
    }

    $normalizedAgentPath = ($AgentRelativePath -replace '\\', '/').TrimStart('/')
    $contentMarker = '(?i)(name:\s*RPI Agent|#\s+RPI Agent)'

    foreach ($file in $files) {
        foreach ($line in Get-Content -LiteralPath $file.FullName -Encoding utf8) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $record = $line | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            }
            catch {
                $malformed++
                $diagnostics.Add('Malformed line in customized results.jsonl while reading invocation evidence.')
                continue
            }
            if (-not $record.PSObject.Properties['stimulus']) { continue }
            $trialIndex = $null
            if ($record.PSObject.Properties['trialIndex'] -and $null -ne $record.trialIndex) {
                $trialIndex = [int]$record.trialIndex
            }
            elseif ($record.PSObject.Properties['itemId'] -and [string]$record.itemId -match '::trial-(\d+)$') {
                $trialIndex = [int]$Matches[1]
            }
            if ($null -eq $trialIndex) {
                $malformed++
                $diagnostics.Add("Invocation record for stimulus '$($record.stimulus)' has no trial index.")
                continue
            }
            if ($record.PSObject.Properties['model'] -and $record.model) { $model = [string]$record.model }

            $key = "$([string]$record.stimulus)||$trialIndex"
            if (-not $expectedKeys.Contains($key)) { continue }
            $recordCounts[$key] = 1 + $(if ($recordCounts.ContainsKey($key)) { [int]$recordCounts[$key] } else { 0 })
            if (-not ($record.PSObject.Properties['trajectory'] -and $record.trajectory -and
                    $record.trajectory.PSObject.Properties['events'] -and $record.trajectory.events)) {
                $malformed++
                $failureReasons[$key] = 'malformed-record'
                $diagnostics.Add("Invocation record '$key' has no trajectory events.")
                continue
            }

            $candidateCalls = @{}
            $recordHasSuccessfulRead = $false
            $recordHasWrongPath = $false
            $recordHasCorrelatedResult = $false
            $recordHasFailedToolResult = $false
            $recordHasSuccessfulUnmarkedResult = $false
            foreach ($trajectoryEvent in @($record.trajectory.events)) {
                if (-not $trajectoryEvent -or -not $trajectoryEvent.PSObject.Properties['type'] -or -not $trajectoryEvent.PSObject.Properties['data']) { continue }
                if ($trajectoryEvent.type -eq 'tool_call') {
                    $callArguments = if ($trajectoryEvent.data.PSObject.Properties['arguments']) {
                        $trajectoryEvent.data.arguments
                    }
                    else { $null }
                    $readKind = Resolve-InvocationReadKind -Arguments $callArguments -ExpectedPath $normalizedAgentPath
                    if ($readKind -eq 'exact' -and $trajectoryEvent.data.PSObject.Properties['toolCallId']) {
                        $candidateCalls[[string]$trajectoryEvent.data.toolCallId] = $true
                    }
                    elseif ($readKind -eq 'wrong-path') {
                        $recordHasWrongPath = $true
                    }
                    continue
                }

                if ($trajectoryEvent.type -ne 'tool_result' -or -not $trajectoryEvent.data.PSObject.Properties['toolCallId']) { continue }
                $callId = [string]$trajectoryEvent.data.toolCallId
                if (-not $candidateCalls.ContainsKey($callId)) { continue }

                $recordHasCorrelatedResult = $true
                $success = $trajectoryEvent.data.PSObject.Properties['success'] -and [bool]$trajectoryEvent.data.success
                $resultText = if ($trajectoryEvent.data.PSObject.Properties['result'] -and $trajectoryEvent.data.result) {
                    $trajectoryEvent.data.result | ConvertTo-Json -Depth 30 -Compress
                }
                else { '' }
                if ($success -and $resultText -match $contentMarker) {
                    $recordHasSuccessfulRead = $true
                }
                elseif ($success) {
                    $recordHasSuccessfulUnmarkedResult = $true
                }
                else {
                    $recordHasFailedToolResult = $true
                }
            }
            if ($recordHasSuccessfulRead) {
                $observed[$key] = 1
            }
            elseif ($candidateCalls.Count -gt 0) {
                $failed++
                $failureReasons[$key] = if ($recordHasSuccessfulUnmarkedResult) {
                    'successful-result-without-agent-marker'
                }
                elseif ($recordHasFailedToolResult) {
                    'failed-tool-result'
                }
                elseif (-not $recordHasCorrelatedResult) {
                    'missing-correlated-result'
                }
                else {
                    'missing-correlated-result'
                }
                $diagnostics.Add("Invocation read for '$key' failed structural validation: $($failureReasons[$key]).")
            }
            elseif ($recordHasWrongPath) {
                $wrongPath++
                $failureReasons[$key] = 'wrong-path'
                $diagnostics.Add("Invocation record '$key' referenced an unexpected RPI Agent path.")
            }
        }
    }

    $missing = 0
    $duplicate = 0
    foreach ($key in $expectedKeys) {
        $recordCount = if ($recordCounts.ContainsKey($key)) { [int]$recordCounts[$key] } else { 0 }
        if ($recordCount -gt 1) {
            $duplicate += ($recordCount - 1)
            $diagnostics.Add("Invocation evidence for '$key' has $recordCount trial records; expected exactly one.")
        }
        if (-not $observed.ContainsKey($key)) {
            $missing++
            if (-not $failureReasons.ContainsKey($key)) {
                $failureReasons[$key] = 'no-exact-read'
            }
            $diagnostics.Add("Invocation evidence is missing for '$key'.")
        }
    }

    $observedCount = @($observed.Keys | Where-Object { [int]$observed[$_] -gt 0 }).Count
    $failedKeys = @($failureReasons.Keys | Where-Object { -not $observed.ContainsKey($_) } | Sort-Object)
    $failedKey = if ($failedKeys.Count -eq 1) { [string]$failedKeys[0] } else { $null }
    $reasonCode = if ($failedKey) { [string]$failureReasons[$failedKey] } else { $null }
    $complete = $expectedKeys.Count -gt 0 -and $observedCount -eq $expectedKeys.Count -and
        $failed -eq 0 -and $missing -eq 0 -and $duplicate -eq 0 -and $wrongPath -eq 0 -and $malformed -eq 0

    return @{
        Model = $model; Expected = $expectedKeys.Count; Observed = $observedCount
        Failed = $failed; Missing = $missing; Duplicate = $duplicate
        WrongPath = $wrongPath; Malformed = $malformed
        FailedKey = $failedKey; ReasonCode = $reasonCode
        HasCompleteEvidence = $complete; Diagnostics = @($diagnostics)
    }
}

function Compare-DeclaredInstanceCoverage {
    <#
    .SYNOPSIS
        Reconciles observed grader instances against an expected manifest, both ways.
    .DESCRIPTION
        Presence of a signal is not coverage. Fewer observed instances than declared
        means part of the population was never evaluated; more means duplicated or
        misplaced records. Both directions are data-quality violations, because either
        one makes a conformance claim over a population the run did not actually cover.
    .OUTPUTS
        [hashtable] With keys Missing, Duplicate, Unexpected, and Diagnostics.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [hashtable]$Expected,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [hashtable]$Observed
    )

    $diagnostics = [System.Collections.Generic.List[string]]::new()
    $missing = 0
    $duplicate = 0
    $unexpected = 0

    if (-not $Expected) { return @{ Missing = 0; Duplicate = 0; Unexpected = 0; Diagnostics = @() } }
    $seen = if ($Observed) { $Observed } else { @{} }

    foreach ($key in $Expected.Keys) {
        $want = [int]$Expected[$key]
        $got = if ($seen.ContainsKey($key)) { [int]$seen[$key] } else { 0 }
        if ($got -lt $want) {
            $missing += ($want - $got)
            $diagnostics.Add("Declared grader '$key' produced $got of $want expected result instances.")
        }
        elseif ($got -gt $want) {
            $duplicate += ($got - $want)
            $diagnostics.Add("Declared grader '$key' produced $got result instances, exceeding the $want expected.")
        }
    }

    foreach ($key in $seen.Keys) {
        if (-not $Expected.ContainsKey($key)) {
            $unexpected += [int]$seen[$key]
            $diagnostics.Add("Grader result '$key' was not declared for that stimulus.")
        }
    }

    return @{
        Missing     = $missing
        Duplicate   = $duplicate
        Unexpected  = $unexpected
        Diagnostics = @($diagnostics)
    }
}

function Measure-DeclaredInvariantFailures {
    <#
    .SYNOPSIS
        Counts declared-invariant failures from a run's structured results.
    .DESCRIPTION
        Reads `results.jsonl` rather than the rendered Markdown report, and reports
        whether it found any signal at all. Two defects motivate both choices.

        The Markdown scraper matches any table row ending in a verdict emoji and counts
        every non-pass as an invariant failure. That population includes the
        `response-quality` prompt grader, which is judged by an LLM. Because the driver
        fails outright when the invariant count is nonzero, the strictest half of the
        verdict was gated on a non-deterministic judge, and one subjective miss on a
        benign prompt could fail an entire run. Scoping to the named invariants declared
        in the canonical library keeps the fail-closed half deterministic.

        The scraper also returns no distinguishable value when the directory, the file,
        the read, or the parse fails, so a run that produced no report at all was
        indistinguishable from a run with zero failures. `HasSignal` separates those.

        `HasSignal` alone still only proves that something was evaluated. When an
        expected manifest is supplied, the observed instances are reconciled against it
        in both directions so a declared invariant that never ran cannot be reported as
        conformant.
    .OUTPUTS
        [hashtable] With keys HasSignal, Failed, Evaluated, MalformedRecords, Missing,
        Duplicate, Unexpected, and Diagnostics.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RunDir,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string[]]$InvariantNames,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$ExpectedManifest,

        [Parameter(Mandatory = $false)]
        [int]$ExpectedTrials = 1
    )

    $diagnostics = [System.Collections.Generic.List[string]]::new()
    $empty = @{ HasSignal = $false; Failed = 0; Evaluated = 0; MalformedRecords = 0; Missing = 0; Duplicate = 0; Unexpected = 0 }

    if ([string]::IsNullOrWhiteSpace($RunDir) -or -not (Test-Path -LiteralPath $RunDir)) {
        $diagnostics.Add('Invariant run directory is missing.')
        return ($empty + @{ Diagnostics = @($diagnostics) })
    }

    $files = @(Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        $diagnostics.Add('No results.jsonl found under the run directory.')
        return ($empty + @{ Diagnostics = @($diagnostics) })
    }

    $scoped = $null
    if ($InvariantNames) {
        $scoped = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($name in $InvariantNames) {
            if (-not [string]::IsNullOrWhiteSpace($name)) { [void]$scoped.Add($name) }
        }
        if ($scoped.Count -eq 0) { $scoped = $null }
    }

    $failed = 0
    $evaluated = 0
    $malformed = 0
    $observed = @{}

    foreach ($file in $files) {
        foreach ($line in (Get-Content -LiteralPath $file.FullName -Encoding utf8)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $record = $line | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            }
            catch {
                # A truncated record can hide a failing invariant. Counting it lets the
                # caller fail the run closed instead of scoring only the survivors.
                $malformed++
                $diagnostics.Add('Malformed line in results.jsonl.')
                continue
            }
            if (-not $record.PSObject.Properties['gradeResult'] -or -not $record.gradeResult) { continue }
            $grade = $record.gradeResult
            if (-not $grade.PSObject.Properties['details'] -or -not $grade.details) { continue }

            $stimulus = if ($grade.PSObject.Properties['stimulusName']) { [string]$grade.stimulusName } else { '<unknown>' }
            foreach ($detail in @($grade.details)) {
                if (-not $detail) { continue }
                $name = if ($detail.PSObject.Properties['name']) { [string]$detail.name } else { '' }
                if ($scoped -and -not $scoped.Contains($name)) { continue }
                if (-not $scoped) {
                    # Without a declared list, restrict to deterministic graders so an
                    # LLM judge cannot fail the strict half of the verdict.
                    $kind = if ($detail.PSObject.Properties['kind']) { [string]$detail.kind } else { '' }
                    if ($kind -ne 'code') { continue }
                }
                $evaluated++
                $key = "$stimulus||$name"
                $observed[$key] = 1 + $(if ($observed.ContainsKey($key)) { [int]$observed[$key] } else { 0 })
                $passed = $detail.PSObject.Properties['passed'] -and $detail.passed
                if (-not $passed) {
                    $failed++
                    $diagnostics.Add("Invariant '$name' failed on stimulus '$stimulus'.")
                }
            }
        }
    }

    $coverage = Compare-DeclaredInstanceCoverage `
        -Expected (Resolve-ExpectedInstanceCount -Manifest $ExpectedManifest -ExpectedTrials $ExpectedTrials) `
        -Observed $observed
    foreach ($entry in @($coverage.Diagnostics)) { $diagnostics.Add($entry) }

    if ($evaluated -eq 0) {
        $diagnostics.Add('No invariant graders were evaluated in this run.')
        return @{
            HasSignal        = $false
            Failed           = 0
            Evaluated        = 0
            MalformedRecords = $malformed
            Missing          = [int]$coverage.Missing
            Duplicate        = [int]$coverage.Duplicate
            Unexpected       = [int]$coverage.Unexpected
            Diagnostics      = @($diagnostics)
        }
    }

    return @{
        HasSignal        = $true
        Failed           = $failed
        Evaluated        = $evaluated
        MalformedRecords = $malformed
        Missing          = [int]$coverage.Missing
        Duplicate        = [int]$coverage.Duplicate
        Unexpected       = [int]$coverage.Unexpected
        Diagnostics      = @($diagnostics)
    }
}

function Measure-DivergenceGuardResults {
    <#
    .SYNOPSIS
        Counts declared divergence-guard failures from the customized run's results.
    .DESCRIPTION
        The documented-divergence gate asks whether the customization behaved the way
        the suite says it is allowed to. That question is answered by the
        `customized_required` and `customized_disallow` guards declared in the canonical
        library, and those results live in the customized run's `results.jsonl`.

        Before this existed the driver had no per-guard data at all. The only signal
        available to a divergence gate was a counter incremented by nonzero exit codes,
        missing run directories, and unparseable output, which measures operational
        health rather than guard conformance. A gate built on it could not detect the
        failures its name implies: a single guard failure among forty stimuli does not
        move the run's 0.7 scoring threshold, so it never reaches the exit code either.

        `HasSignal` distinguishes a run where no guard was evaluated from a run where
        every guard passed. Treating the former as clean would let a broken or empty
        customized run report perfect divergence conformance.

        Any-signal is still weaker than coverage: one passing guard elsewhere could
        stand in for a stimulus whose guard details never appeared. When an expected
        manifest is supplied, observed instances are reconciled against it in both
        directions so a partial population cannot produce a conformant result.
    .OUTPUTS
        [hashtable] With keys HasSignal, Failed, Evaluated, FailedGuards,
        MalformedRecords, Missing, Duplicate, Unexpected, and Diagnostics.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RunDir,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string[]]$GuardNames,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$ExpectedManifest,

        [Parameter(Mandatory = $false)]
        [int]$ExpectedTrials = 1
    )

    $diagnostics = [System.Collections.Generic.List[string]]::new()
    $failedGuards = [System.Collections.Generic.List[string]]::new()
    $empty = @{ HasSignal = $false; Failed = 0; Evaluated = 0; FailedGuards = @(); MalformedRecords = 0; Missing = 0; Duplicate = 0; Unexpected = 0 }

    if ([string]::IsNullOrWhiteSpace($RunDir) -or -not (Test-Path -LiteralPath $RunDir)) {
        $diagnostics.Add('Customized run directory is missing.')
        return ($empty + @{ Diagnostics = @($diagnostics) })
    }

    $scoped = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($name in @($GuardNames)) {
        if (-not [string]::IsNullOrWhiteSpace([string]$name)) { [void]$scoped.Add([string]$name) }
    }
    if ($scoped.Count -eq 0) {
        # No declared guards means there is nothing for this gate to assert. That is a
        # legitimate configuration, not a passing run, so it reports no signal.
        $diagnostics.Add('No divergence guards are declared in the canonical library.')
        return ($empty + @{ Diagnostics = @($diagnostics) })
    }

    $files = @(Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue)
    if ($files.Count -eq 0) {
        $diagnostics.Add('No results.jsonl found under the customized run directory.')
        return ($empty + @{ Diagnostics = @($diagnostics) })
    }

    $failed = 0
    $evaluated = 0
    $malformed = 0
    $observed = @{}

    foreach ($file in $files) {
        foreach ($line in (Get-Content -LiteralPath $file.FullName -Encoding utf8)) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $record = $line | ConvertFrom-Json -Depth 100 -ErrorAction Stop
            }
            catch {
                $malformed++
                $diagnostics.Add('Malformed line in customized results.jsonl.')
                continue
            }
            if (-not $record.PSObject.Properties['gradeResult'] -or -not $record.gradeResult) { continue }
            $grade = $record.gradeResult
            if (-not $grade.PSObject.Properties['details'] -or -not $grade.details) { continue }

            $stimulus = if ($grade.PSObject.Properties['stimulusName']) { [string]$grade.stimulusName } else { '<unknown>' }
            foreach ($detail in @($grade.details)) {
                if (-not $detail) { continue }
                $name = if ($detail.PSObject.Properties['name']) { [string]$detail.name } else { '' }
                if (-not $scoped.Contains($name)) { continue }
                $evaluated++
                $key = "$stimulus||$name"
                $observed[$key] = 1 + $(if ($observed.ContainsKey($key)) { [int]$observed[$key] } else { 0 })
                $passed = $detail.PSObject.Properties['passed'] -and $detail.passed
                if (-not $passed) {
                    $failed++
                    $failedGuards.Add("$stimulus/$name")
                    $diagnostics.Add("Divergence guard '$name' failed on stimulus '$stimulus'.")
                }
            }
        }
    }

    $coverage = Compare-DeclaredInstanceCoverage `
        -Expected (Resolve-ExpectedInstanceCount -Manifest $ExpectedManifest -ExpectedTrials $ExpectedTrials) `
        -Observed $observed
    foreach ($entry in @($coverage.Diagnostics)) { $diagnostics.Add($entry) }

    if ($evaluated -eq 0) {
        $diagnostics.Add('No divergence guards were evaluated in the customized run.')
        return @{
            HasSignal        = $false
            Failed           = 0
            Evaluated        = 0
            FailedGuards     = @()
            MalformedRecords = $malformed
            Missing          = [int]$coverage.Missing
            Duplicate        = [int]$coverage.Duplicate
            Unexpected       = [int]$coverage.Unexpected
            Diagnostics      = @($diagnostics)
        }
    }

    return @{
        HasSignal        = $true
        Failed           = $failed
        Evaluated        = $evaluated
        FailedGuards     = @($failedGuards)
        MalformedRecords = $malformed
        Missing          = [int]$coverage.Missing
        Duplicate        = [int]$coverage.Duplicate
        Unexpected       = [int]$coverage.Unexpected
        Diagnostics      = @($diagnostics)
    }
}

function Measure-InvariantFailures {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $ansi = [regex]'\x1B\[[0-9;]*[A-Za-z]'
    $pass = [char]::ConvertFromUtf32(0x2705)
    $fail = [char]::ConvertFromUtf32(0x274C)
    $warn = [char]::ConvertFromUtf32(0x1F7E1)
    $verdictAlt = "$pass|$fail|$warn"
    $rowPattern = "^\|\s*[^|\s][^|]*\|.*\|\s*(?<verdict>$verdictAlt)(?:\s|$|<)"
    $total = 0; $failed = 0
    foreach ($line in $Lines) {
        $clean = $ansi.Replace($line, '')
        if ($clean -match $rowPattern) {
            $total++
            if ($Matches.verdict -ne $pass) { $failed++ }
        }
    }
    return @{ Total = $total; Failed = $failed }
}

function Get-EquivalenceGateResults {
    <#
    .SYNOPSIS
        Computes authoritative evidence status and report-only comparison status.
    .DESCRIPTION
        Deterministic invariants, run health, delivery, and structural data quality are
        authoritative. Comparative estimates, tie ratio, and documented-divergence
        guards are report-only until valid post-launch evidence supports a calibrated
        non-inferiority policy.

        An empty equivalent population is a structural failure rather than a below-floor
        statistical result. A ratio computed from zero trials is not a low score; it is
        the absence of the measurement the gate exists to make, and reporting it as a
        statistical miss would send diagnosis toward the customization instead of the
        configuration that emptied the population.

        Data-quality violations and invariant failures fail closed regardless of tier,
        because an incomplete comparison cannot evidence equivalence and reporting a
        pass from the records that happened to survive would assert something the run
        did not measure.

        Tier controls local iteration severity. `devloop` downgrades invariant and run-
        health failures to warning; `calibration` and `ci` keep authoritative evidence
        blocking. Structural data-quality failures fail closed at every tier.

        The judge-error budget is deliberately not enforced. Its threshold is unresolved
        pending calibration, so judge errors are counted and reported without gating.
    .OUTPUTS
        [hashtable] With keys EquivalenceGate, DocumentedDivergenceGate, and Verdict.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][int]$Runs,
        [Parameter(Mandatory)][int]$InvariantFailures,
        [Parameter(Mandatory)][string]$Tier,
        [Parameter(Mandatory = $false)][double]$TieRatio = 0.0,
        [Parameter(Mandatory = $false)][int]$EquivalentTotal = 0,
        [Parameter(Mandatory = $false)][double]$TieRatioFloor = 0.80,
        [Parameter(Mandatory = $false)][int]$DataQualityViolations = 0,
        [Parameter(Mandatory = $false)][int]$DivergenceGuardFailures = 0,
        [Parameter(Mandatory = $false)][bool]$DivergenceHasSignal = $false,
        [Parameter(Mandatory = $false)][int]$RunHealthFailures = 0
    )

    $advisory = ($Tier -eq 'devloop')
    $downgrade = { param($state) if ($state -eq 'fail' -and $advisory) { 'warn' } else { $state } }

    # An equivalent population of zero cannot evidence equivalence. It is grouped with
    # the other structural conditions so it fails closed at both tiers.
    $emptyEquivalentPopulation = ($EquivalentTotal -le 0)

    # Authoritative deterministic and structural gate. Comparative statistics do not
    # participate until a separately approved margin and confidence policy exists.
    $equivalence = 'pass'
    if ($Runs -le 0) {
        $equivalence = 'fail'
    }
    elseif ($emptyEquivalentPopulation) {
        $equivalence = 'fail'
    }
    elseif ($InvariantFailures -gt 0 -or $DataQualityViolations -gt 0 -or $RunHealthFailures -gt 0) {
        $equivalence = 'fail'
    }

    # A structurally broken run fails closed at both tiers. Only a statistical or
    # guard-conformance result is advisory in devloop.
    $structural = ($Runs -le 0) -or ($DataQualityViolations -gt 0) -or $emptyEquivalentPopulation
    $equivalenceGate = if ($structural) { $equivalence } else { & $downgrade $equivalence }

    $divergenceGate = 'report-only'
    $verdict = $equivalenceGate

    return @{
        EquivalenceGate          = $equivalenceGate
        DocumentedDivergenceGate = $divergenceGate
        Verdict                  = $verdict
    }
}

function Get-OutputHash {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return -join ($hash | ForEach-Object { $_.ToString('x2') })
    }
    finally { $sha.Dispose() }
}

function ConvertFrom-EquivalenceResults {
    [CmdletBinding()]
    [OutputType([System.Collections.IList])]
    param(
        [Parameter(Mandatory)][string]$RunDir
    )

    if (-not (Test-Path -LiteralPath $RunDir)) {
        throw "Run directory not found: $RunDir"
    }

    $jsonlFiles = @(Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File)
    if ($jsonlFiles.Count -eq 0) {
        throw "No results.jsonl found under $RunDir"
    }

    $records = New-Object 'System.Collections.Generic.List[object]'
    $stimulusCounts = @{}
    $knownKinds = @('code', 'llm', 'human')

    foreach ($file in $jsonlFiles) {
        $lines = Get-Content -LiteralPath $file.FullName -Encoding utf8
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json -Depth 100

            # results.jsonl interleaves record kinds: vally writes one
            # `run-summary` line after the `trial-result` lines. Select on the
            # declared type rather than inferring trial-ness from the presence
            # of a trajectory, so a future record kind that carries one cannot
            # silently join the trial population and skew the tally. Records
            # with no `type`, or an empty one, predate the field and stay
            # eligible. This matches the record selection in VallyRunner.psm1.
            if ($obj.PSObject.Properties['type'] -and
                -not [string]::IsNullOrWhiteSpace([string]$obj.type) -and
                [string]$obj.type -ne 'trial-result') {
                continue
            }

            if (-not ($obj.PSObject.Properties['trajectory'])) { continue }
            $traj = $obj.trajectory
            $stim = if ($traj -and $traj.stimulus) { [string]$traj.stimulus.name } else { '<unknown>' }
            if (-not $stimulusCounts.ContainsKey($stim)) { $stimulusCounts[$stim] = 0 }
            $trial = $stimulusCounts[$stim]
            $stimulusCounts[$stim] = $trial + 1

            $output = if ($traj -and $null -ne $traj.output) { [string]$traj.output } else { '' }
            $wallMs = 0
            $totalTokens = 0
            if ($traj -and $traj.metrics) {
                if ($null -ne $traj.metrics.wallTimeMs) { $wallMs = [int]$traj.metrics.wallTimeMs }
                if ($traj.metrics.tokenUsage -and $null -ne $traj.metrics.tokenUsage.totalTokens) {
                    $totalTokens = [int]$traj.metrics.tokenUsage.totalTokens
                }
            }

            $passed = $false
            $score = 0.0
            $details = @{ code = @(); llm = @(); human = @(); other = @() }
            if ($obj.PSObject.Properties['gradeResult'] -and $obj.gradeResult) {
                $gr = $obj.gradeResult
                if ($null -ne $gr.passed) { $passed = [bool]$gr.passed }
                if ($null -ne $gr.score) { $score = [double]$gr.score }
                if ($gr.PSObject.Properties['details'] -and $gr.details) {
                    foreach ($d in @($gr.details)) {
                        $kind = if ($d.PSObject.Properties['kind'] -and $d.kind) { [string]$d.kind } else { 'other' }
                        if ($knownKinds -notcontains $kind) {
                            Write-Warning "ConvertFrom-EquivalenceResults: unknown grader kind '$kind' for stimulus '$stim' (trial $trial); bucketing under 'other'."
                            $details.other += $d
                        }
                        else {
                            $details[$kind] += $d
                        }
                    }
                }
            }

            $records.Add([pscustomobject]@{
                    stimulusName = $stim
                    trial        = $trial
                    output       = $output
                    outputHash   = Get-OutputHash -Text $output
                    passed       = $passed
                    score        = $score
                    wallTimeMs   = $wallMs
                    totalTokens  = $totalTokens
                    details      = $details
                }) | Out-Null
        }
    }

    return , $records
}

function Merge-EquivalenceStimuli {
    [CmdletBinding()]
    [OutputType([System.Collections.IList])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Baseline,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Customized,
        [Parameter(Mandatory)][hashtable]$Compare
    )

    $byStimBase = @{}
    foreach ($r in $Baseline) {
        if (-not $byStimBase.ContainsKey($r.stimulusName)) { $byStimBase[$r.stimulusName] = @() }
        $byStimBase[$r.stimulusName] += $r
    }
    $byStimCust = @{}
    foreach ($r in $Customized) {
        if (-not $byStimCust.ContainsKey($r.stimulusName)) { $byStimCust[$r.stimulusName] = @() }
        $byStimCust[$r.stimulusName] += $r
    }

    $perStim = if ($Compare.ContainsKey('PerStimulus')) { $Compare.PerStimulus } else { @{} }
    $nameSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($k in $byStimBase.Keys) { [void]$nameSet.Add($k) }
    foreach ($k in $byStimCust.Keys) { [void]$nameSet.Add($k) }
    $allNames = @($nameSet) | Sort-Object
    $merged = New-Object 'System.Collections.Generic.List[object]'

    foreach ($name in $allNames) {
        [object[]]$b = @(if ($byStimBase.ContainsKey($name)) { $byStimBase[$name] } else { @() })
        [object[]]$c = @(if ($byStimCust.ContainsKey($name)) { $byStimCust[$name] } else { @() })
        $trialCount = [math]::Max($b.Count, $c.Count)

        $identical = 0
        $wallDiffs = New-Object 'System.Collections.Generic.List[double]'
        $tokenDiffs = New-Object 'System.Collections.Generic.List[double]'
        $pairs = New-Object 'System.Collections.Generic.List[object]'
        for ($i = 0; $i -lt $trialCount; $i++) {
            $bi = if ($i -lt $b.Count) { $b[$i] } else { $null }
            $ci = if ($i -lt $c.Count) { $c[$i] } else { $null }
            if ($bi -and $ci -and $bi.outputHash -eq $ci.outputHash) { $identical++ }
            if ($bi -and $ci) {
                $wallDiffs.Add([double]($ci.wallTimeMs - $bi.wallTimeMs))
                $tokenDiffs.Add([double]($ci.totalTokens - $bi.totalTokens))
            }
            $pairs.Add([pscustomobject]@{
                    trial      = $i
                    baseline   = $bi
                    customized = $ci
                }) | Out-Null
        }

        $basePassed = @($b | Where-Object { $_.passed }).Count
        $custPassed = @($c | Where-Object { $_.passed }).Count

        $tally = if ($perStim.ContainsKey($name)) { $perStim[$name] } else { @{ Ties = 0; BaselineWins = 0; TreatmentWins = 0 } }

        $meanWall = if ($wallDiffs.Count -gt 0) { ($wallDiffs | Measure-Object -Average).Average } else { 0.0 }
        $meanTokens = if ($tokenDiffs.Count -gt 0) { ($tokenDiffs | Measure-Object -Average).Average } else { 0.0 }

        $merged.Add([pscustomobject]@{
                stimulusName       = $name
                baselineTrials     = $b.Count
                customizedTrials   = $c.Count
                baselinePassed     = $basePassed
                customizedPassed   = $custPassed
                baselinePassRate   = if ($b.Count -gt 0) { [math]::Round($basePassed / [double]$b.Count, 4) } else { 0.0 }
                customizedPassRate = if ($c.Count -gt 0) { [math]::Round($custPassed / [double]$c.Count, 4) } else { 0.0 }
                identicalCount     = $identical
                identicalTotal     = $trialCount
                ties               = [int]$tally.Ties
                baselineWins       = [int]$tally.BaselineWins
                treatmentWins      = [int]$tally.TreatmentWins
                meanWallTimeDeltaMs = [math]::Round($meanWall, 2)
                meanTokenDelta     = [math]::Round($meanTokens, 2)
                trials             = $pairs
            }) | Out-Null
    }

    return , $merged
}

function Edit-HtmlEscape {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;')
}

function Get-VariantMetadata {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$VariantYamlPath,
        [Parameter(Mandatory)]
        [hashtable]$Default
    )

    $variant = @{}
    foreach ($key in $Default.Keys) { $variant[$key] = $Default[$key] }

    if (-not (Test-Path -LiteralPath $VariantYamlPath)) { return $variant }
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) { return $variant }

    try {
        Import-Module powershell-yaml -ErrorAction Stop
        $raw = Get-Content -LiteralPath $VariantYamlPath -Raw
        $parsed = ConvertFrom-Yaml -Yaml $raw
        if ($parsed) {
            foreach ($key in @('kind', 'name', 'label', 'description', 'applied')) {
                if ($parsed.ContainsKey($key)) { $variant[$key] = $parsed[$key] }
            }
        }
    }
    catch {
        Write-Verbose "Failed to parse variant metadata at ${VariantYamlPath}: $($_.Exception.Message)"
    }

    if (-not $variant.ContainsKey('applied') -or $null -eq $variant.applied) { $variant.applied = @() }
    return $variant
}

function ConvertTo-EquivalenceHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Stimuli,
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$Agent,
        [hashtable]$Variants
    )

    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $totalStimuli = $Stimuli.Count
    # Measure-Object emits nothing for an empty collection and raises an error
    # when no input object carries the property, so neither the result nor Sum
    # can be read directly. Both degenerate cases render as a zero total.
    $trialsMeasure = $Stimuli | Measure-Object -Property identicalTotal -Sum -ErrorAction SilentlyContinue
    $totalTrials = if ($trialsMeasure) { [int]$trialsMeasure.Sum } else { 0 }
    $identicalMeasure = $Stimuli | Measure-Object -Property identicalCount -Sum -ErrorAction SilentlyContinue
    $totalIdentical = if ($identicalMeasure) { [int]$identicalMeasure.Sum } else { 0 }
    $identicalPct = if ($totalTrials -gt 0) { [math]::Round(100 * $totalIdentical / [double]$totalTrials, 1) } else { 0 }

    $defaultVariantA = @{ kind = 'baseline'; name = 'baseline';   label = 'Baseline (A)';   description = ''; applied = @() }
    $defaultVariantB = @{ kind = 'unknown';  name = 'customized'; label = 'Customized (B)'; description = ''; applied = @() }
    $variantA = if ($Variants -and $Variants.a) { $Variants.a } else { $defaultVariantA }
    $variantB = if ($Variants -and $Variants.b) { $Variants.b } else { $defaultVariantB }
    $subject  = if ($Variants -and $Variants.subject) { [string]$Variants.subject } else { [string]$variantB.name }

    $payload = [ordered]@{
        model        = $Model
        runId        = $RunId
        generatedAt  = $generatedAt
        totalStimuli = $totalStimuli
        totalTrials  = $totalTrials
        identicalPct = $identicalPct
        variants     = @{ a = $variantA; b = $variantB; subject = $subject }
        stimuli      = $Stimuli
    }
    $json = $payload | ConvertTo-Json -Depth 100 -Compress
    # Escape sequences that could break out of a <script> tag context (including '/' for </script> defense in depth).
    $json = $json -replace '<', '\u003c' -replace '>', '\u003e' -replace '&', '\u0026' -replace '/', '\/'

    $modelEsc = Edit-HtmlEscape $Model
    $runIdEsc = Edit-HtmlEscape $RunId
    $agentEsc = Edit-HtmlEscape $Agent
    $aLabelEsc = Edit-HtmlEscape ([string]$variantA.label)
    $bLabelEsc = Edit-HtmlEscape ([string]$variantB.label)
    $aKindEsc = Edit-HtmlEscape ([string]$variantA.kind)
    $bKindEsc = Edit-HtmlEscape ([string]$variantB.kind)
    $aDescEsc = Edit-HtmlEscape ([string]$variantA.description)
    $bDescEsc = Edit-HtmlEscape ([string]$variantB.description)
    $aAppliedList = if ($variantA.applied -and @($variantA.applied).Count -gt 0) { (@($variantA.applied) | ForEach-Object { '<li>' + (Edit-HtmlEscape ([string]$_)) + '</li>' }) -join '' } else { '<li><em>(none)</em></li>' }
    $bAppliedList = if ($variantB.applied -and @($variantB.applied).Count -gt 0) { (@($variantB.applied) | ForEach-Object { '<li>' + (Edit-HtmlEscape ([string]$_)) + '</li>' }) -join '' } else { '<li><em>(none)</em></li>' }
    $genEsc = Edit-HtmlEscape $generatedAt

    $css = @'
:root { color-scheme: light dark; }
body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; margin: 0; padding: 1rem; }
header { border-bottom: 1px solid #888; padding-bottom: 0.5rem; margin-bottom: 1rem; }
header h1 { margin: 0 0 0.25rem 0; font-size: 1.4rem; }
.meta { font-size: 0.85rem; color: #666; }
.totals { display: flex; gap: 1.5rem; margin-top: 0.5rem; }
.totals div { font-size: 0.9rem; }
.totals strong { font-size: 1.1rem; }
.variant-strip { display: flex; gap: 1rem; margin: 1rem 0; flex-wrap: wrap; }
.variant-card { flex: 1; min-width: 280px; padding: 0.75rem 1rem; background: #f3f6fb; border: 1px solid #d0d7e2; border-radius: 6px; font-size: 0.85rem; }
.variant-card strong { color: #1a3a6b; }
.variant-kind { font-size: 0.75rem; color: #555; }
.variant-desc { margin-top: 0.35rem; color: #444; }
.variant-applied { margin-top: 0.5rem; font-size: 0.8rem; }
.variant-applied ul { margin: 0.15rem 0 0 1rem; padding: 0; }
@media (prefers-color-scheme: dark) {
  .variant-card { background: #1a2230; border-color: #344056; }
  .variant-card strong { color: #8ab4ff; }
  .variant-kind { color: #aaa; }
  .variant-desc { color: #ddd; }
}
input[type=search] { padding: 0.35rem 0.5rem; width: 320px; max-width: 100%; margin-bottom: 0.5rem; }
table { border-collapse: collapse; width: 100%; font-size: 0.85rem; }
th, td { border: 1px solid #ccc; padding: 0.35rem 0.5rem; text-align: left; }
th { background: #f0f0f0; cursor: pointer; user-select: none; position: sticky; top: 0; }
tr.summary:hover { background: #f6f6ff; cursor: pointer; }
tr.details { display: none; background: #fafafa; }
tr.details.open { display: table-row; }
tr.details td { padding: 0.75rem; }
.kind-group { margin-bottom: 0.75rem; }
.kind-group h4 { margin: 0.25rem 0; font-size: 0.9rem; }
.grader { font-size: 0.8rem; margin-left: 1rem; }
.diff { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-top: 0.5rem; }
.diff h5 { margin: 0 0 0.25rem 0; font-size: 0.8rem; }
pre { background: #f5f5f5; padding: 0.5rem; border: 1px solid #ddd; overflow: auto; white-space: pre-wrap; max-height: 240px; margin: 0; }
.verdict-pass { color: #0a7d28; font-weight: bold; }
.verdict-warn { color: #b8860b; font-weight: bold; }
.verdict-fail { color: #b30000; font-weight: bold; }
th[data-key] { cursor: pointer; }
th[data-key]:focus-visible { outline: 3px solid #005fcc; outline-offset: -3px; }
@media (prefers-color-scheme: dark) {
  th { background: #2a2a2a; }
  tr.details { background: #1c1c1c; }
  pre { background: #161616; border-color: #333; }
  .meta { color: #aaa; }
}
'@

    $js = @'
(function () {
  var data = JSON.parse(document.getElementById('data').textContent);
  var tbody = document.getElementById('rows');
  var search = document.getElementById('search');
  var sortKey = 'stimulusName';
  var sortDir = 1;
  var aLabel = (data.variants && data.variants.a && data.variants.a.label) || 'Baseline';
  var bLabel = (data.variants && data.variants.b && data.variants.b.label) || 'Treatment';

  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function verdictGlyph(s) {
    if (s.identicalTotal === 0) return '<span class="verdict-warn">?</span>';
    var pct = s.identicalCount / s.identicalTotal;
    if (pct === 1 && s.baselinePassRate === s.customizedPassRate) return '<span class="verdict-pass">=</span>';
    if (pct >= 0.8) return '<span class="verdict-warn">~</span>';
    return '<span class="verdict-fail">!=</span>';
  }

  function renderRows() {
    var filter = search.value.toLowerCase();
    var rows = data.stimuli.filter(function (s) {
      return !filter || s.stimulusName.toLowerCase().indexOf(filter) !== -1;
    }).slice().sort(function (a, b) {
      var av = a[sortKey], bv = b[sortKey];
      if (typeof av === 'string') return av.localeCompare(bv) * sortDir;
      return ((av || 0) - (bv || 0)) * sortDir;
    });
    tbody.innerHTML = rows.map(function (s, i) {
      var trials = (s.trials || []).map(function (t) {
        var bi = t.baseline || {};
        var ci = t.customized || {};
        var detailsHtml = ['code', 'llm', 'human', 'other'].map(function (kind) {
          var bg = (bi.details && bi.details[kind]) || [];
          var cg = (ci.details && ci.details[kind]) || [];
          if (bg.length === 0 && cg.length === 0) return '';
          var fmt = function (g) {
            return '<div class="grader">' + escapeHtml(g.name || '') +
              ' &mdash; passed=' + escapeHtml(g.passed) +
              ' score=' + escapeHtml(g.score) +
              (g.evidence ? ' <em>' + escapeHtml(g.evidence) + '</em>' : '') +
              '</div>';
          };
          return '<div class="kind-group"><h4>' + escapeHtml(kind) + '</h4>' +
            '<div><strong>' + escapeHtml(aLabel) + ':</strong>' + bg.map(fmt).join('') + '</div>' +
            '<div><strong>' + escapeHtml(bLabel) + ':</strong>' + cg.map(fmt).join('') + '</div></div>';
        }).join('');
        return '<div><strong>Trial ' + t.trial + '</strong>' + detailsHtml +
          '<div class="diff"><div><h5>' + escapeHtml(aLabel) + ' output</h5><pre>' + escapeHtml(bi.output || '') + '</pre></div>' +
          '<div><h5>' + escapeHtml(bLabel) + ' output</h5><pre>' + escapeHtml(ci.output || '') + '</pre></div></div></div>';
      }).join('<hr/>');

      return '<tr class="summary" data-i="' + i + '">' +
        '<td>' + escapeHtml(s.stimulusName) + '</td>' +
        '<td>' + (s.baselinePassRate * 100).toFixed(1) + '%</td>' +
        '<td>' + (s.customizedPassRate * 100).toFixed(1) + '%</td>' +
        '<td>' + s.identicalCount + '/' + s.identicalTotal + '</td>' +
        '<td>' + s.ties + '</td><td>' + s.baselineWins + '</td><td>' + s.treatmentWins + '</td>' +
        '<td>' + s.meanWallTimeDeltaMs + '</td>' +
        '<td>' + s.meanTokenDelta + '</td>' +
        '<td>' + verdictGlyph(s) + '</td>' +
        '</tr>' +
        '<tr class="details" data-i="' + i + '"><td colspan="10">' + trials + '</td></tr>';
    }).join('');
  }

  tbody.addEventListener('click', function (e) {
    var tr = e.target.closest('tr.summary');
    if (!tr) return;
    var i = tr.getAttribute('data-i');
    var det = tbody.querySelector('tr.details[data-i="' + i + '"]');
    if (det) det.classList.toggle('open');
  });

  function applySort(k) {
    if (sortKey === k) { sortDir = -sortDir; } else { sortKey = k; sortDir = 1; }
    document.querySelectorAll('th[data-key]').forEach(function (h) {
      if (h.getAttribute('data-key') === sortKey) {
        h.setAttribute('aria-sort', sortDir === 1 ? 'ascending' : 'descending');
      } else {
        h.setAttribute('aria-sort', 'none');
      }
    });
    renderRows();
  }

  document.querySelectorAll('th[data-key]').forEach(function (th) {
    th.addEventListener('click', function () {
      applySort(th.getAttribute('data-key'));
    });
    th.addEventListener('keydown', function (e) {
      if (e.key === 'Enter' || e.key === ' ' || e.key === 'Spacebar') {
        e.preventDefault();
        applySort(th.getAttribute('data-key'));
      }
    });
  });

  search.addEventListener('input', renderRows);
  renderRows();
})();
'@

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Baseline Equivalence Dashboard &mdash; $modelEsc &mdash; $runIdEsc</title>
<style>
$css
</style>
</head>
<body>
<header>
<h1>Baseline Equivalence Dashboard</h1>
<div class="meta">Agent: <strong>$agentEsc</strong> &middot; Model: <strong>$modelEsc</strong> &middot; Run: <strong>$runIdEsc</strong> &middot; Generated: $genEsc</div>
<div class="totals">
<div>Stimuli: <strong>$totalStimuli</strong></div>
<div>Total trials: <strong>$totalTrials</strong></div>
<div>Identical outputs: <strong>${identicalPct}%</strong></div>
</div>
<div class="variant-strip">
<div class="variant-card">
<div><strong>Baseline &mdash; $aLabelEsc</strong> <span class="variant-kind">[$aKindEsc]</span></div>
<div class="variant-desc">$aDescEsc</div>
<div class="variant-applied"><div>Applied:</div><ul>$aAppliedList</ul></div>
</div>
<div class="variant-card">
<div><strong>Treatment &mdash; $bLabelEsc</strong> <span class="variant-kind">[$bKindEsc]</span></div>
<div class="variant-desc">$bDescEsc</div>
<div class="variant-applied"><div>Applied:</div><ul>$bAppliedList</ul></div>
</div>
</div>
</header>
<input id="search" type="search" placeholder="filter stimuli&hellip;">
<table>
<thead><tr>
<th data-key="stimulusName" tabindex="0" role="columnheader" scope="col" aria-sort="ascending">Stimulus</th>
<th data-key="baselinePassRate" tabindex="0" role="columnheader" scope="col" aria-sort="none">$aLabelEsc pass</th>
<th data-key="customizedPassRate" tabindex="0" role="columnheader" scope="col" aria-sort="none">$bLabelEsc pass</th>
<th data-key="identicalCount" tabindex="0" role="columnheader" scope="col" aria-sort="none">Identical</th>
<th data-key="ties" tabindex="0" role="columnheader" scope="col" aria-sort="none">Ties</th>
<th data-key="baselineWins" tabindex="0" role="columnheader" scope="col" aria-sort="none">$aLabelEsc wins</th>
<th data-key="treatmentWins" tabindex="0" role="columnheader" scope="col" aria-sort="none">$bLabelEsc wins</th>
<th data-key="meanWallTimeDeltaMs" tabindex="0" role="columnheader" scope="col" aria-sort="none">Wall &Delta; (ms)</th>
<th data-key="meanTokenDelta" tabindex="0" role="columnheader" scope="col" aria-sort="none">Tokens &Delta;</th>
<th scope="col">Verdict</th>
</tr></thead>
<tbody id="rows"></tbody>
</table>
<script id="data" type="application/json">$json</script>
<script>
$js
</script>
</body>
</html>
"@

    return $html
}

function Get-AppliedArtifacts {
    <#
    .SYNOPSIS
        Discovers the customization artifacts materialized under a workspace root.
    .PARAMETER WorkspaceRoot
        Absolute path to the materialized customized workspace (typically
        evals/baseline-equivalence/customized/workspace). When missing, empty,
        or not a directory the function returns an empty array without erroring.
    .OUTPUTS
        System.String[] of workspace-relative artifact paths using forward
        slashes, sorted and de-duplicated by exact path.
    .EXAMPLE
        Get-AppliedArtifacts -WorkspaceRoot 'C:/repo/evals/baseline-equivalence/customized/workspace'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$WorkspaceRoot
    )

    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { return @() }
    if (-not (Test-Path -LiteralPath $WorkspaceRoot -PathType Container)) { return @() }

    $kinds = @(
        @{ Anchor = '.github/agents';       Filter = '*.agent.md' },
        @{ Anchor = '.github/skills';       Filter = 'SKILL.md' },
        @{ Anchor = '.github/instructions'; Filter = '*.instructions.md' },
        @{ Anchor = '.github/prompts';      Filter = '*.prompt.md' }
    )

    $relatives = New-Object 'System.Collections.Generic.List[string]'
    foreach ($kind in $kinds) {
        $anchorPath = Join-Path $WorkspaceRoot $kind.Anchor
        if (-not (Test-Path -LiteralPath $anchorPath -PathType Container)) { continue }
        $files = Get-ChildItem -LiteralPath $anchorPath -Recurse -Filter $kind.Filter -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $rel = [IO.Path]::GetRelativePath($WorkspaceRoot, $file.FullName) -replace '\\', '/'
            $relatives.Add($rel)
        }
    }

    return @($relatives | Sort-Object -Unique)
}

Export-ModuleMember -Function `
    Measure-CompareTrials, `
    Resolve-InvocationReadKind, `
    Measure-AgentInvocationEvidence, `
    Measure-InvariantFailures, `
    Measure-DeclaredInvariantFailures, `
    Get-EquivalenceGateResults, `
    Measure-DivergenceGuardResults, `
    Get-OutputHash, `
    ConvertFrom-EquivalenceResults, `
    Merge-EquivalenceStimuli, `
    Edit-HtmlEscape, `
    Get-VariantMetadata, `
    ConvertTo-EquivalenceHtml, `
    Get-AppliedArtifacts
