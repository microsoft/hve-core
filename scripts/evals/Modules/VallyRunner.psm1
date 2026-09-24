# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# VallyRunner.psm1
#
# Purpose: Spawn `vally eval` for a single spec, locate the timestamped run
#          directory vally writes under --output-dir, and aggregate the
#          resulting results.jsonl into pass/fail counts suitable for the
#          PR-time eval-summary report.
# Author: HVE Core Team

#Requires -Version 7.4

Set-StrictMode -Version Latest

function Resolve-VallyRunDir {
    <#
    .SYNOPSIS
    Returns the most recently written subdirectory of an `--output-dir`.

    .DESCRIPTION
    `vally eval` writes each invocation under a timestamped subdirectory of
    the directory passed to `--output-dir`. Callers need the latest such
    directory to locate `results.jsonl`.

    .PARAMETER OutputDir
    Directory that was passed to `vally eval --output-dir`.

    .OUTPUTS
    [string] Full path to the newest subdirectory, or $null when none exists.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputDir
    )

    if (-not (Test-Path -LiteralPath $OutputDir -PathType Container)) { return $null }

    $latest = Get-ChildItem -LiteralPath $OutputDir -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1

    if (-not $latest) { return $null }
    return $latest.FullName
}

function Get-VallySpecThreshold {
    <#
    .SYNOPSIS
    Reads an eval spec's scoring.threshold value when available.

    .DESCRIPTION
    Some evals report trial success through `gradeResult.score` rather than a
    hard `gradeResult.passed` boolean. When the spec contains
    `scoring.threshold`, the runner uses that threshold to interpret those
    scores.

    .PARAMETER SpecPath
    Path to the eval spec YAML file.

    .OUTPUTS
    [double] The configured threshold, or $null when absent.
    #>
    [CmdletBinding()]
    [OutputType([double])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SpecPath
    )

    if ([string]::IsNullOrWhiteSpace($SpecPath) -or -not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
        return $null
    }

    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        return $null
    }

    try {
        Import-Module powershell-yaml -ErrorAction Stop | Out-Null
    }
    catch {
        return $null
    }

    try {
        $spec = Get-Content -LiteralPath $SpecPath -Raw -Encoding utf8 | ConvertFrom-Yaml
    }
    catch {
        return $null
    }

    if ($null -eq $spec) { return $null }

    if ($spec -is [System.Collections.IDictionary]) {
        if ($spec.Contains('scoring')) {
            $scoring = $spec['scoring']
            if ($scoring -is [System.Collections.IDictionary] -and $scoring.Contains('threshold')) {
                return [double]$scoring['threshold']
            }
        }
        return $null
    }

    $scoring = $spec.PSObject.Properties['scoring']
    if ($null -eq $scoring -or $null -eq $scoring.Value) { return $null }

    $threshold = $scoring.Value.PSObject.Properties['threshold']
    if ($null -eq $threshold -or $null -eq $threshold.Value) { return $null }

    return [double]$threshold.Value
}

function Get-VallyDiagnosticConfiguration {
    <#
    .SYNOPSIS
    Projects selected YAML configuration into a bounded diagnostic inventory.
    .PARAMETER SpecPath
    YAML spec passed to Vally.
    .PARAMETER Tag
    Optional CLI tag selection using key=value[,value] syntax.
    .OUTPUTS
    Configuration status, hashes, configured identities and trial counts.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [string]$Tag
    )

    $result = @{
        status = 'unavailable'
        specDigest = $null
        selectionDigest = $null
        judgeModels = @()
        stimuli = [System.Collections.Specialized.OrderedDictionary]::new([StringComparer]::Ordinal)
    }
    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { return $result }
    try {
        Import-Module powershell-yaml -ErrorAction Stop | Out-Null
        $spec = Get-Content -LiteralPath $SpecPath -Raw -Encoding utf8 | ConvertFrom-Yaml
        $result.specDigest = Get-AgentEvalFileDigest -Path $SpecPath
        if ($spec -isnot [System.Collections.IDictionary] -or -not $spec.Contains('stimuli') -or
            $spec.stimuli -isnot [System.Collections.IList]) { return $result }
        $defaults = if ($spec.Contains('defaults')) { $spec.defaults } else { @{} }
        $runs = if ($defaults.Contains('runs')) { $defaults.runs } else { 1 }
        if ($runs -isnot [ValueType] -or $runs -is [bool] -or $runs -lt 1 -or $runs -ne [math]::Truncate($runs)) { return $result }
        $filterKey = $null
        $filterValues = @()
        $exclude = $false
        if (-not [string]::IsNullOrWhiteSpace($Tag)) {
            $delimiter = $Tag.IndexOf('=')
            if ($delimiter -lt 1) { return $result }
            $filterKey = $Tag.Substring(0, $delimiter).Trim()
            $exclude = $filterKey.EndsWith('!')
            if ($exclude) { $filterKey = $filterKey.Substring(0, $filterKey.Length - 1) }
            $filterValues = @($Tag.Substring($delimiter + 1).Split(',').Trim() | Where-Object { $_ })
            if (-not $filterKey -or $filterValues.Count -eq 0) { return $result }
        }
        $judges = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        if ($defaults.Contains('judge_model')) { [void]$judges.Add([string]$defaults.judge_model) }
        foreach ($stimulus in $spec.stimuli) {
            if ($filterKey) {
                $tagValues = if ($stimulus.Contains('tags') -and $stimulus.tags.Contains($filterKey)) { @($stimulus.tags[$filterKey]) }
                elseif ($spec.Contains('tags') -and $spec.tags.Contains($filterKey)) { @($spec.tags[$filterKey]) }
                else { @() }
                $matched = @($tagValues | Where-Object { $_ -cin $filterValues }).Count -gt 0
                if (($exclude -and $matched) -or (-not $exclude -and -not $matched)) { continue }
            }
            $name = [string]$stimulus.name
            if ([string]::IsNullOrWhiteSpace($name) -or $result.stimuli.Contains($name)) { return $result }
            $configuredGraders = if ($stimulus.Contains('graders')) { $stimulus.graders } else { @() }
            $graders = @(
                $index = 0
                foreach ($grader in $configuredGraders) {
                    $configuredName = if ($grader.Contains('name')) { [string]$grader.name } else { $null }
                    [ordered]@{
                        name = if ($configuredName) { $configuredName } else { "$($grader.type)-$index" }
                        configuredName = $configuredName
                        type = [string]$grader.type
                        index = $index
                    }
                    if ($grader.Contains('model')) { [void]$judges.Add([string]$grader.model) }
                    if ($grader.Contains('config') -and $grader.config -is [System.Collections.IDictionary] -and $grader.config.Contains('model')) {
                        [void]$judges.Add([string]$grader.config.model)
                    }
                    $index++
                }
            )
            $result.stimuli.Add($name, [ordered]@{ runs = [int]$runs; graders = $graders })
        }
        $result.judgeModels = @($judges | Sort-Object -CaseSensitive)
        $result.selectionDigest = Get-AgentEvalValueDigest -Value $result.stimuli
        $result.status = 'available'
    }
    catch {
        $result.status = 'unavailable'
    }
    return $result
}

function Get-VallyInputDigest {
    <#
    .SYNOPSIS
    Hashes tracked and nonignored evaluation inputs without publishing content.
    .PARAMETER RepoRoot
    Checkout whose artifacts, fixtures, scripts and lockfile supply the run.
    .OUTPUTS
    SHA256 digest of the ordered path and content-hash inventory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$RepoRoot)

    $paths = @(& git -C $RepoRoot -c core.quotepath=false ls-files --cached --others --exclude-standard -- .github evals scripts package-lock.json)
    if ($LASTEXITCODE -ne 0) { return $null }
    $inputs = @(
        foreach ($path in @($paths | Sort-Object -Unique -CaseSensitive)) {
            $absolutePath = Join-Path $RepoRoot $path
            [ordered]@{ path = $path; digest = Get-AgentEvalFileDigest -Path $absolutePath }
        }
    )
    return Get-AgentEvalValueDigest -Value $inputs
}

function Test-VallyDiagnosticEvidence {
    <#
    .SYNOPSIS
    Reconciles safe trial evidence against its configured population.
    .PARAMETER Diagnostics
    Versioned diagnostic projection emitted by Invoke-VallySpec.
    .PARAMETER RunKey
    Expected owning run key, when supplied by a consumer.
    .OUTPUTS
    Separate contract and selected-evidence integrity verdicts and safe categories.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][AllowNull()]$Diagnostics,
        [string]$RunKey
    )

    $issues = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $contractValid = $true
    $selectedValid = $false
    $allChecksPassed = $false
    try {
        $data = $Diagnostics | ConvertTo-Json -Depth 50 -Compress | ConvertFrom-Json -AsHashtable -Depth 50
        $required = @('schemaVersion', 'runKey', 'configurationStatus', 'specDigest', 'inputDigest', 'inputDigestScope',
            'selectionDigest', 'checkout', 'executorModel', 'judgeModels', 'versions', 'threshold', 'expectedStimuli', 'selectedAttempt', 'attempts')
        if ($data -isnot [System.Collections.IDictionary] -or
            @($required | Where-Object { -not $data.Contains($_) }).Count -gt 0 -or
            @($data.Keys | Where-Object { $_ -cnotin $required }).Count -gt 0 -or
            $data.schemaVersion -cne '1.0.0' -or ($RunKey -and $data.runKey -cne $RunKey)) {
            throw 'Invalid diagnostic contract.'
        }
        if ($data.configurationStatus -cne 'available') { [void]$issues.Add('configuration-unavailable') }
        foreach ($hashField in @('specDigest', 'inputDigest', 'selectionDigest')) {
            if ($data[$hashField] -isnot [string] -or $data[$hashField] -cnotmatch '^sha256:[a-f0-9]{64}$') { throw 'Invalid provenance digest.' }
        }
        if ($null -ne $data.checkout -and ($data.checkout -isnot [string] -or $data.checkout -cnotmatch '^[a-f0-9]{40,64}$')) { throw 'Invalid checkout identity.' }
        if ($data.inputDigestScope -cnotin @('checkout-evaluation-inputs', 'spec-only')) { throw 'Invalid input scope.' }
        if ($data.versions -isnot [System.Collections.IDictionary] -or
            @($data.versions.Keys | Where-Object { $_ -cnotin @('vally', 'vally-cli') }).Count -gt 0) { throw 'Invalid version fields.' }
        foreach ($version in $data.versions.Values) {
            if ($null -ne $version -and ($version -isnot [string] -or $version -cnotmatch '^\d+\.\d+\.\d+(?:[-+][a-zA-Z0-9.-]+)?$')) { throw 'Invalid tool version.' }
        }
        if ($data.threshold -is [string] -or $data.threshold -is [bool] -or
            ($null -ne $data.threshold -and (-not [double]::IsFinite([double]$data.threshold) -or $data.threshold -lt 0 -or $data.threshold -gt 1))) { throw 'Invalid threshold.' }
        if ($data.expectedStimuli -isnot [System.Collections.IDictionary] -or
            $data.selectionDigest -cne (Get-AgentEvalValueDigest -Value $data.expectedStimuli)) {
            throw 'Invalid selection digest.'
        }
        $expectedTrials = 0
        foreach ($expected in $data.expectedStimuli.Values) {
            if (@($expected.Keys | Where-Object { $_ -cnotin @('runs', 'graders') }).Count -gt 0) { throw 'Invalid inventory fields.' }
            if ($expected.runs -isnot [long] -and $expected.runs -isnot [int]) { throw 'Invalid trial count.' }
            if ($expected.runs -lt 1) { throw 'Invalid trial count.' }
            foreach ($grader in $expected.graders) {
                if (@($grader.Keys | Where-Object { $_ -cnotin @('name', 'type', 'configuredName', 'index') }).Count -gt 0 -or
                    $grader.name -isnot [string] -or $grader.type -isnot [string]) { throw 'Invalid configured grader.' }
            }
            $expectedTrials += $expected.runs
        }
        if (@($data.attempts).Count -eq 0) { throw 'Missing attempts.' }
        $selectedCount = 0
        $bestOrdinal = 0
        $bestErrors = [int]::MaxValue
        $ordinal = 0
        foreach ($attempt in $data.attempts) {
            $ordinal++
            $attemptFields = @('runKey', 'ordinal', 'selected', 'selectionReason', 'exitCategory', 'assertionsPassed',
                'assertionsFailed', 'erroredTrials', 'observedTrials', 'recordIssues', 'perStimulus', 'trials')
            if (@($attemptFields | Where-Object { -not $attempt.Contains($_) }).Count -gt 0 -or
                @($attempt.Keys | Where-Object { $_ -cnotin $attemptFields }).Count -gt 0 -or
                $attempt.ordinal -ne $ordinal -or $attempt.runKey -cne $data.runKey -or $attempt.selected -isnot [bool]) {
                throw 'Invalid attempt contract.'
            }
            if ($attempt.selectionReason -cnotin @('fewest-errors-first-on-tie', 'more-errors', 'later-tie') -or
                $attempt.exitCategory -cnotin @('success', 'unknown', 'authentication', 'model-unavailable', 'rate-limited', 'timeout', 'connection')) { throw 'Invalid attempt category.' }
            if ($attempt.erroredTrials -lt $bestErrors) { $bestErrors = $attempt.erroredTrials; $bestOrdinal = $ordinal }
            $attemptIssues = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($category in $attempt.recordIssues) {
                if ($category -cnotin @('malformed-record', 'invalid-record', 'unknown-record-type', 'invalid-trial-score', 'unexpected-stimulus', 'grader-population-mismatch')) {
                    throw 'Invalid record category.'
                }
                [void]$attemptIssues.Add($category)
            }
            $identities = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $nativeIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            $passedCount = 0
            $failedCount = 0
            $erroredCount = 0
            $attemptAllChecks = $true
            $scores = @{}
            foreach ($trial in $attempt.trials) {
                $trialFields = @('stimulusName', 'trialIndex', 'itemIdDigest', 'identitySource', 'executionStatus', 'score',
                    'thresholdPassed', 'allGradersPassed', 'gradeStatus', 'graders')
                if (@($trialFields | Where-Object { -not $trial.Contains($_) }).Count -gt 0 -or
                    @($trial.Keys | Where-Object { $_ -cnotin $trialFields }).Count -gt 0) { throw 'Invalid trial contract.' }
                if ($trial.executionStatus -cnotin @('success', 'error', 'skipped', 'cancelled', 'unknown', 'invalid') -or
                    $trial.gradeStatus -cnotin @('success', 'error', 'missing', 'invalid') -or
                    $trial.identitySource -cnotin @('native-item-id', 'stimulus-trial-index', 'missing')) { throw 'Invalid trial category.' }
                if ($null -eq $trial.thresholdPassed) { $erroredCount++ }
                elseif ($trial.thresholdPassed -isnot [bool]) { throw 'Invalid threshold verdict.' }
                elseif ($trial.thresholdPassed) { $passedCount++ }
                else { $failedCount++ }
                if ($null -eq $trial.stimulusName -or -not $data.expectedStimuli.Contains($trial.stimulusName)) {
                    [void]$attemptIssues.Add('unexpected-stimulus')
                    continue
                }
                $expected = $data.expectedStimuli[$trial.stimulusName]
                if (($trial.trialIndex -isnot [long] -and $trial.trialIndex -isnot [int]) -or
                    $trial.trialIndex -lt 0 -or $trial.trialIndex -ge $expected.runs) { [void]$attemptIssues.Add('invalid-trial-identity') }
                elseif (-not $identities.Add("$($trial.stimulusName)`0$($trial.trialIndex)")) { [void]$attemptIssues.Add('duplicate-trial') }
                if ($trial.itemIdDigest) {
                    if ($trial.itemIdDigest -cnotmatch '^sha256:[a-f0-9]{64}$' -or -not $nativeIds.Add($trial.itemIdDigest)) {
                        [void]$attemptIssues.Add('invalid-native-identity')
                    }
                }
                if ($trial.executionStatus -cne 'success') { [void]$attemptIssues.Add('execution-error') }
                if ($trial.gradeStatus -cne 'success') { [void]$attemptIssues.Add('grading-error') }
                if ($null -eq $trial.score -or $trial.score -is [string] -or $trial.score -is [bool] -or
                    -not [double]::IsFinite([double]$trial.score) -or $trial.score -lt 0 -or $trial.score -gt 1) {
                    [void]$attemptIssues.Add('invalid-trial-score')
                }
                else {
                    if (-not $scores.ContainsKey($trial.stimulusName)) { $scores[$trial.stimulusName] = [System.Collections.Generic.List[double]]::new() }
                    $scores[$trial.stimulusName].Add([double]$trial.score)
                    if ($null -ne $data.threshold -and $trial.thresholdPassed -ne ($trial.score -ge $data.threshold)) {
                        throw 'Threshold verdict mismatch.'
                    }
                }
                if (@($trial.graders).Count -ne @($expected.graders).Count) { [void]$attemptIssues.Add('grader-population-mismatch') }
                $checksPass = $trial.gradeStatus -ceq 'success'
                if (@($trial.graders).Count -ne @($expected.graders).Count) { $checksPass = $false }
                $graderIndex = 0
                foreach ($grader in $trial.graders) {
                    $graderFields = @('name', 'graderType', 'score', 'passed', 'status')
                    if (@($graderFields | Where-Object { -not $grader.Contains($_) }).Count -gt 0 -or
                        @($grader.Keys | Where-Object { $_ -cnotin $graderFields }).Count -gt 0) { throw 'Invalid grader contract.' }
                    if ($grader.status -cnotin @('success', 'error', 'missing', 'duplicate', 'invalid')) { throw 'Invalid grader category.' }
                    if ($graderIndex -ge @($expected.graders).Count -or
                        $grader.name -cne $expected.graders[$graderIndex].name -or $grader.graderType -cne $expected.graders[$graderIndex].type) {
                        [void]$attemptIssues.Add('grader-population-mismatch')
                    }
                    if ($grader.status -cne 'success' -or $grader.passed -isnot [bool] -or $null -eq $grader.score -or
                        $grader.score -is [string] -or $grader.score -is [bool] -or
                        -not [double]::IsFinite([double]$grader.score) -or $grader.score -lt 0 -or $grader.score -gt 1) {
                        [void]$attemptIssues.Add('invalid-grader-result')
                        $checksPass = $false
                    }
                    if ($grader.passed -ne $true) { $checksPass = $false }
                    $graderIndex++
                }
                if ($trial.allGradersPassed -isnot [bool] -or $trial.allGradersPassed -ne $checksPass) {
                    throw 'All-check verdict mismatch.'
                }
                if (-not $checksPass) { $attemptAllChecks = $false }
            }
            if ($identities.Count -ne $expectedTrials -or @($attempt.trials).Count -ne $expectedTrials) { [void]$attemptIssues.Add('trial-population-mismatch') }
            if ($attempt.observedTrials -ne @($attempt.trials).Count -or $attempt.assertionsPassed -ne $passedCount -or
                $attempt.assertionsFailed -ne $failedCount -or $attempt.erroredTrials -ne $erroredCount) { throw 'Trial count mismatch.' }
            if (@($attempt.perStimulus).Count -ne $data.expectedStimuli.Count) { throw 'Missing stimulus aggregates.' }
            $aggregateNames = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
            foreach ($bucket in $attempt.perStimulus) {
                if (@($bucket.Keys | Where-Object { $_ -cnotin @('stimulusName', 'expectedTrials', 'observedTrials', 'aggregateScore', 'aggregatePassed') }).Count -gt 0) {
                    throw 'Invalid aggregate fields.'
                }
                if (-not $data.expectedStimuli.Contains($bucket.stimulusName) -or -not $aggregateNames.Add($bucket.stimulusName)) { throw 'Invalid stimulus aggregate.' }
                $observed = @($attempt.trials | Where-Object { $_.stimulusName -ceq $bucket.stimulusName })
                if ($bucket.expectedTrials -ne $data.expectedStimuli[$bucket.stimulusName].runs -or $bucket.observedTrials -ne $observed.Count) { throw 'Stimulus count mismatch.' }
                $mean = if ($scores.ContainsKey($bucket.stimulusName)) { ($scores[$bucket.stimulusName] | Measure-Object -Average).Average } else { $null }
                if (($null -eq $mean) -ne ($null -eq $bucket.aggregateScore) -or
                    ($null -ne $mean -and [math]::Abs($mean - [double]$bucket.aggregateScore) -gt 0.000000001)) { throw 'Stimulus mean mismatch.' }
                $verdict = if ($null -eq $mean) { $null }
                elseif ($null -ne $data.threshold) { $mean -ge $data.threshold }
                else { @($observed | Where-Object { $_.thresholdPassed -eq $false }).Count -eq 0 }
                if ($bucket.aggregatePassed -ne $verdict) { throw 'Stimulus verdict mismatch.' }
            }
            if ($attempt.selected) {
                $selectedCount++
                if ($data.selectedAttempt -ne $ordinal -or $attempt.selectionReason -cne 'fewest-errors-first-on-tie') { throw 'Invalid selected attempt.' }
                foreach ($issue in $attemptIssues) { [void]$issues.Add($issue) }
                $selectedValid = $attemptIssues.Count -eq 0
                $allChecksPassed = $selectedValid -and $attemptAllChecks
            }
        }
        if ($selectedCount -ne 1 -or $data.selectedAttempt -ne $bestOrdinal) { throw 'Attempt selection mismatch.' }
    }
    catch {
        $contractValid = $false
        $selectedValid = $false
        $allChecksPassed = $false
        [void]$issues.Add('invalid-diagnostic-contract')
    }
    return @{
        contractValid = $contractValid
        integrityPassed = $contractValid -and $selectedValid -and $issues.Count -eq 0
        allChecksPassed = $allChecksPassed -and $issues.Count -eq 0
        issues = @($issues | Sort-Object)
    }
}

function Read-VallyResultsJsonl {
    <#
    .SYNOPSIS
    Aggregates trial outcomes from a vally `results.jsonl` file.

    .DESCRIPTION
    Reads the `results.jsonl` written by `vally eval` (located under the run
    directory returned by `Resolve-VallyRunDir`) and tallies passing/failing
    trials plus aggregate wall time. Malformed lines are skipped rather than
    thrown so a partial run still yields counts.

    .PARAMETER RunDir
    Directory returned by `Resolve-VallyRunDir`.

    .PARAMETER ExpectedStimuli
    Selected stimulus names mapped to configured runs and grader definitions.
    Diagnostic identities come only from this configuration.

    .OUTPUTS
    [hashtable] `@{ assertionsPassed; assertionsFailed; durationMs; trials; resultsPath; perStimulus; failedOrErroredTrials }`.
    `perStimulus` is an ordered map keyed by stimulus name with `@{ assertionsPassed; assertionsFailed; durationMs; trials }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RunDir,
        [Nullable[double]]$Threshold,
        [System.Collections.IDictionary]$ExpectedStimuli = @{}
    )

    $empty = @{
        assertionsPassed = 0
        assertionsFailed = 0
        errored          = 0
        durationMs       = 0
        trials           = 0
        stimuliPassed    = 0
        stimuliFailed    = 0
        resultsPath      = $null
        perStimulus      = [ordered]@{}
        failedOrErroredTrials = @()
        trialDiagnostics = @()
        recordIssues     = @()
    }

    if ([string]::IsNullOrWhiteSpace($RunDir) -or -not (Test-Path -LiteralPath $RunDir -PathType Container)) {
        return $empty
    }

    $jsonl = Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $jsonl) { return $empty }

    $passed = 0
    $failed = 0
    $errored = 0
    $durationMs = 0
    $trials = 0
    $perStimulus = [ordered]@{}
    $failedOrErroredTrials = [System.Collections.Generic.List[object]]::new()
    $trialDiagnostics = [System.Collections.Generic.List[object]]::new()
    $recordIssues = [System.Collections.Generic.List[string]]::new()

    foreach ($line in Get-Content -LiteralPath $jsonl.FullName -Encoding utf8) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json -Depth 100
        }
        catch {
            $recordIssues.Add('malformed-record')
            continue
        }

        if ($null -eq $obj -or $obj -isnot [pscustomobject]) {
            $recordIssues.Add('invalid-record')
            continue
        }

        # Vally writes a typed "trial-result" record per trial and a typed
        # "run-summary" record after them. Older untyped trial records lack a
        # `type` field, so accept those while ignoring every explicitly typed
        # non-trial record.
        if ($obj.PSObject.Properties['type'] -and
            -not [string]::IsNullOrWhiteSpace([string]$obj.type) -and
            [string]$obj.type -ne 'trial-result') {
            if ([string]$obj.type -cne 'run-summary') { $recordIssues.Add('unknown-record-type') }
            continue
        }

        $trials++

        $trialPassed = $false
        $gradeResult = $null
        if ($obj.PSObject.Properties['gradeResult']) {
            $gradeResult = $obj.gradeResult
        }
        $hasScore = $false
        $scoreValue = $null
        if ($gradeResult -and $gradeResult.PSObject.Properties['score'] -and $null -ne $gradeResult.score) {
            if ($gradeResult.score -is [ValueType] -and $gradeResult.score -isnot [bool]) {
                $scoreValue = [double]$gradeResult.score
                $hasScore = [double]::IsFinite($scoreValue) -and $scoreValue -ge 0 -and $scoreValue -le 1
            }
            if (-not $hasScore) { $recordIssues.Add('invalid-trial-score') }
        }
        $hasPassed = ($gradeResult -and $gradeResult.PSObject.Properties['passed'] -and $gradeResult.passed -is [bool])

        # A trial with no gradeable verdict (neither score nor passed) means the
        # trajectory errored before grading ran (transient executor/model failure).
        # Classify it as errored rather than failed so infrastructure flakiness does
        # not gate the build as a conformance failure.
        $trialErrored = -not ($hasScore -or $hasPassed)

        if (-not $trialErrored) {
            if ($hasScore -and $PSBoundParameters.ContainsKey('Threshold') -and $null -ne $Threshold) {
                $trialPassed = $scoreValue -ge [double]$Threshold
            }
            elseif ($hasPassed) {
                $trialPassed = [bool]$gradeResult.passed
            }
        }

        if ($trialErrored) { $errored++ }
        elseif ($trialPassed) { $passed++ }
        else { $failed++ }

        $trialWallMs = 0
        if ($obj.PSObject.Properties['trajectory'] -and $obj.trajectory -and
            $obj.trajectory.PSObject.Properties['metrics'] -and $obj.trajectory.metrics -and
            $obj.trajectory.metrics.PSObject.Properties['wallTimeMs'] -and
            $null -ne $obj.trajectory.metrics.wallTimeMs) {
            $trialWallMs = [int]$obj.trajectory.metrics.wallTimeMs
            $durationMs += $trialWallMs
        }

        $stimulusName = $null
        if ($obj.PSObject.Properties['trajectory'] -and $obj.trajectory -and
            $obj.trajectory.PSObject.Properties['stimulus'] -and $obj.trajectory.stimulus -and
            $obj.trajectory.stimulus.PSObject.Properties['name'] -and
            -not [string]::IsNullOrWhiteSpace([string]$obj.trajectory.stimulus.name)) {
            $stimulusName = [string]$obj.trajectory.stimulus.name
        }

        if ($obj.PSObject.Properties['stimulus'] -and $obj.stimulus -is [string]) {
            $stimulusName = [string]$obj.stimulus
        }

        if ($stimulusName) {
            if (-not $perStimulus.Contains($stimulusName)) {
                $perStimulus[$stimulusName] = @{
                    assertionsPassed = 0
                    assertionsFailed = 0
                    errored          = 0
                    durationMs       = 0
                    trials           = 0
                    scoreSum         = 0.0
                    scoredTrials     = 0
                }
            }
            $bucket = $perStimulus[$stimulusName]
            $bucket.trials++
            if ($trialErrored) { $bucket.errored++ }
            else {
                if ($trialPassed) { $bucket.assertionsPassed++ }
                else { $bucket.assertionsFailed++ }
                $effectiveScore = if ($hasScore) { $scoreValue } elseif ([bool]$gradeResult.passed) { 1.0 } else { 0.0 }
                $bucket.scoreSum += [double]$effectiveScore
                $bucket.scoredTrials++
            }
            $bucket.durationMs += $trialWallMs
        }

        $knownStimulus = $stimulusName -and $ExpectedStimuli.Contains($stimulusName)
        if ($ExpectedStimuli.Count -gt 0 -and -not $knownStimulus) { $recordIssues.Add('unexpected-stimulus') }
        if ($knownStimulus -and $gradeResult -and $gradeResult.PSObject.Properties['details'] -and
            @($gradeResult.details).Count -ne @($ExpectedStimuli[$stimulusName].graders).Count) { $recordIssues.Add('grader-population-mismatch') }
        $graderDiagnostics = @(
            if ($knownStimulus) {
                foreach ($configured in $ExpectedStimuli[$stimulusName].graders) {
                    $configuredName = if ($configured.Contains('configuredName')) { $configured.configuredName } else { $configured.name }
                    $matchingDetails = @(
                        if ($gradeResult -and $gradeResult.PSObject.Properties['details']) {
                            $detailIndex = 0
                            foreach ($detail in $gradeResult.details) {
                                if ($configuredName) {
                                    if ($detail -and $detail.PSObject.Properties['configuredName'] -and
                                        [string]$detail.configuredName -ceq [string]$configuredName) { $detail }
                                }
                                elseif ($detail -and $detailIndex -eq $configured.index -and
                                    $detail.PSObject.Properties['graderType'] -and [string]$detail.graderType -ceq [string]$configured.type) { $detail }
                                $detailIndex++
                            }
                        }
                    )
                    $detail = if ($matchingDetails.Count -eq 1) { $matchingDetails[0] } else { $null }
                    $detailStatus = if ($matchingDetails.Count -eq 0) { 'missing' }
                    elseif ($matchingDetails.Count -gt 1) { 'duplicate' }
                    elseif (-not $detail.PSObject.Properties['graderType'] -or [string]$detail.graderType -cne [string]$configured.type) { 'invalid' }
                    elseif (-not $detail.PSObject.Properties['status']) { 'success' }
                    elseif ([string]$detail.status -cin @('success', 'error')) { [string]$detail.status }
                    else { 'invalid' }
                    $detailScore = $null
                    if ($detail -and $detail.PSObject.Properties['score'] -and
                        $detail.score -is [ValueType] -and $detail.score -isnot [bool]) {
                        $numericScore = [double]$detail.score
                        if ([double]::IsFinite($numericScore) -and $numericScore -ge 0 -and $numericScore -le 1) {
                            $detailScore = $numericScore
                        }
                    }
                    [ordered]@{
                        name = [string]$configured.name
                        graderType = [string]$configured.type
                        score = $detailScore
                        passed = if ($detail -and $detail.PSObject.Properties['passed'] -and $detail.passed -is [bool]) { $detail.passed } else { $null }
                        status = $detailStatus
                    }
                }
            }
        )
        $gradeStatus = if ($trialErrored) { 'missing' }
        elseif ($gradeResult.PSObject.Properties['status'] -and [string]$gradeResult.status -cnotin @('success', 'error')) { 'invalid' }
        elseif (($gradeResult.PSObject.Properties['status'] -and $gradeResult.status -ceq 'error') -or
            @($graderDiagnostics | Where-Object { $_.status -eq 'error' }).Count -gt 0) { 'error' }
        else { 'success' }
        $allGradersPassed = $knownStimulus -and $gradeStatus -eq 'success' -and
            @($graderDiagnostics | Where-Object { $_.status -ne 'success' -or $_.passed -ne $true -or $null -eq $_.score }).Count -eq 0
        $trialIndex = $null
        if ($obj.PSObject.Properties['trialIndex'] -and $obj.trialIndex -is [ValueType] -and
            $obj.trialIndex -isnot [bool] -and [double]$obj.trialIndex -ge 0 -and
            [double]$obj.trialIndex -le [int]::MaxValue -and [double]$obj.trialIndex -eq [math]::Truncate([double]$obj.trialIndex)) {
            $trialIndex = [int]$obj.trialIndex
        }
        elseif (-not $obj.PSObject.Properties['trialIndex'] -and $knownStimulus -and
            [int]$ExpectedStimuli[$stimulusName].runs -eq 1) { $trialIndex = 0 }
        $itemIdDigest = if ($obj.PSObject.Properties['itemId'] -and $obj.itemId -is [string] -and
            -not [string]::IsNullOrWhiteSpace($obj.itemId)) { Get-AgentEvalValueDigest -Value $obj.itemId } else { $null }
        $executionStatus = if (-not $obj.PSObject.Properties['status']) { 'unknown' }
        elseif ([string]$obj.status -cin @('success', 'error', 'skipped', 'cancelled')) { [string]$obj.status }
        else { 'invalid' }
        $trialDiagnostics.Add([ordered]@{
            stimulusName = if ($knownStimulus) { [string]$stimulusName } else { $null }
            trialIndex = $trialIndex
            itemIdDigest = $itemIdDigest
            identitySource = if ($itemIdDigest) { 'native-item-id' } elseif ($null -ne $trialIndex) { 'stimulus-trial-index' } else { 'missing' }
            executionStatus = $executionStatus
            score = if ($hasScore -and [double]::IsFinite($scoreValue) -and $scoreValue -ge 0 -and $scoreValue -le 1) { $scoreValue } else { $null }
            thresholdPassed = if ($trialErrored) { $null } else { $trialPassed }
            allGradersPassed = [bool]$allGradersPassed
            gradeStatus = $gradeStatus
            graders = $graderDiagnostics
        })

        if ($trialErrored -or -not $trialPassed) {
            # Omit raw evidence text because it has not passed the separate content-moderation job.
            $failedGraders = $null
            if ($gradeResult -and $gradeResult.PSObject.Properties['details'] -and $gradeResult.details) {
                $failedGraders = @(
                    foreach ($detail in @($gradeResult.details)) {
                        if ($null -eq $detail) { continue }
                        if ($detail.PSObject.Properties['passed'] -and [bool]$detail.passed) { continue }
                        $graderName = if ($detail.PSObject.Properties['configuredName'] -and
                            -not [string]::IsNullOrWhiteSpace([string]$detail.configuredName)) {
                            [string]$detail.configuredName
                        }
                        elseif ($detail.PSObject.Properties['name']) { [string]$detail.name }
                        else { 'unnamed' }
                        [ordered]@{
                            name       = $graderName
                            graderType = if ($detail.PSObject.Properties['graderType']) { [string]$detail.graderType }
                                         elseif ($detail.PSObject.Properties['kind']) { [string]$detail.kind }
                                         else { $null }
                            score      = if ($detail.PSObject.Properties['score']) { $detail.score } else { $null }
                        }
                    }
                )
            }

            $failedOrErroredTrials.Add([ordered]@{
                ordinal       = $trials
                outcome       = if ($trialErrored) { 'errored' } else { 'failed' }
                stimulusName  = $stimulusName
                score         = if ($hasScore) { $scoreValue } else { $null }
                passed        = if ($hasPassed) { [bool]$gradeResult.passed } else { $null }
                errorState    = if ($trialErrored) { 'no-gradeable-verdict' } else { $null }
                failedGraders = $failedGraders
            }) | Out-Null
        }
    }

    $stimuliPassed = 0
    $stimuliFailed = 0
    foreach ($stimulusName in @($perStimulus.Keys)) {
        $bucket = $perStimulus[$stimulusName]
        $aggregateScore = if ($bucket.scoredTrials -gt 0) {
            [double]$bucket.scoreSum / [int]$bucket.scoredTrials
        }
        else { $null }
        $aggregatePassed = if ($null -eq $aggregateScore) { $null }
        elseif ($PSBoundParameters.ContainsKey('Threshold') -and $null -ne $Threshold) {
            $aggregateScore -ge [double]$Threshold
        }
        else { $bucket.assertionsFailed -eq 0 }

        $bucket.aggregateScore = $aggregateScore
        $bucket.aggregatePassed = $aggregatePassed
        $bucket.Remove('scoreSum')
        $bucket.Remove('scoredTrials')
        if ($null -ne $aggregatePassed) {
            if ($aggregatePassed) { $stimuliPassed++ }
            else { $stimuliFailed++ }
        }
    }

    return @{
        assertionsPassed = $passed
        assertionsFailed = $failed
        errored          = $errored
        durationMs       = $durationMs
        trials           = $trials
        stimuliPassed    = $stimuliPassed
        stimuliFailed    = $stimuliFailed
        resultsPath      = $jsonl.FullName
        perStimulus      = $perStimulus
        failedOrErroredTrials = @($failedOrErroredTrials)
        trialDiagnostics = @($trialDiagnostics)
        recordIssues = @($recordIssues)
    }
}

function Get-VallyExitCategory {
    <#
    .SYNOPSIS
    Classifies a process result without returning untrusted output.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][int]$ExitCode,
        [AllowEmptyString()][string]$OutputText = ''
    )

    if ($ExitCode -eq 0) { return 'success' }
    $category = switch -Regex ($OutputText) {
        '(?i)\b(401|403|unauthorized|forbidden|authentication)\b' { 'authentication'; break }
        '(?i)\bmodel\b[^\r\n]*(not supported|unsupported|not found|unavailable|not available|not enabled)' { 'model-unavailable'; break }
        '(?i)\b(429|rate[ -]?limit|quota)\b' { 'rate-limited'; break }
        '(?i)\b(timeout|timed out|ETIMEDOUT)\b' { 'timeout'; break }
        '(?i)\b(ECONNRESET|ECONNREFUSED|ENOTFOUND|fetch failed)\b' { 'connection'; break }
        default { 'unknown' }
    }
    return $category
}

function Invoke-VallyProcess {
    <#
    .SYNOPSIS
    Runs a Vally command while withholding child output and emitting trusted progress.

    .DESCRIPTION
    Drains stdout and stderr asynchronously, writes their complete contents only to
    an optional runner-local log, emits allowlisted start, heartbeat, and completion
    records, preserves the exact exit code, and terminates the child tree when asked.

    .OUTPUTS
    [hashtable] ExitCode, ExitCategory, ElapsedMilliseconds, and sanitized Worker.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string[]]$Arguments,
        [string]$Command = 'vally',
        [string]$LogPath,
        [switch]$AppendLog,
        [Parameter(Mandatory = $true)]
        [ValidateSet('plan', 'ordinary-eval', 'output-moderation', 'materialize', 'baseline-eval', 'customized-eval', 'compare', 'merge')]
        [string]$Phase,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Worker,
        [ValidateRange(1, 100)][int]$Attempt = 1,
        [ValidateRange(1, 3600)][int]$HeartbeatIntervalSeconds = 60,
        [scriptblock]$ShouldCancel
    )

    $safeWorker = ($Worker -replace '[^A-Za-z0-9._:-]', '_')
    if ($safeWorker.Length -gt 80) { $safeWorker = $safeWorker.Substring(0, 80) }
    $wrapper = @'
$commandName = $args[0]
$commandArguments = if ($args.Count -gt 1) { @($args[1..($args.Count - 1)]) } else { @() }
$exitCode = 0
try {
    & $commandName @commandArguments 2>&1
    if ($null -ne $LASTEXITCODE) { $exitCode = $LASTEXITCODE }
}
catch {
    [Console]::Error.WriteLine($_.Exception.Message)
    $exitCode = 1
}
exit $exitCode
'@

    $commandInfo = Get-Command -Name $Command -ErrorAction Stop
    $resolvedCommand = if ($commandInfo.CommandType -eq [System.Management.Automation.CommandTypes]::Alias) {
        [string]$commandInfo.Definition
    }
    elseif ($commandInfo.CommandType -in @(
            [System.Management.Automation.CommandTypes]::Application,
            [System.Management.Automation.CommandTypes]::ExternalScript)) {
        [string]$commandInfo.Source
    }
    else {
        $Command
    }

    $startInfo = [System.Diagnostics.ProcessStartInfo]::new()
    $startInfo.FileName = (Get-Command pwsh -ErrorAction Stop).Source
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.StandardOutputEncoding = [System.Text.Encoding]::UTF8
    $startInfo.StandardErrorEncoding = [System.Text.Encoding]::UTF8
    $startInfo.ArgumentList.Add('-NoProfile')
    $startInfo.ArgumentList.Add('-CommandWithArgs')
    $startInfo.ArgumentList.Add($wrapper)
    $startInfo.ArgumentList.Add($resolvedCommand)
    foreach ($argument in $Arguments) { $startInfo.ArgumentList.Add($argument) }

    $process = [System.Diagnostics.Process]::new()
    $process.StartInfo = $startInfo
    $started = $false
    $stopwatch = $null
    try {
        if (-not $process.Start()) { throw "Could not start command '$Command'." }
        $started = $true
        $standardOutput = $process.StandardOutput.ReadToEndAsync()
        $standardError = $process.StandardError.ReadToEndAsync()
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        $nextHeartbeat = $HeartbeatIntervalSeconds
        Write-Host "Vally progress: event=phase-start phase=$Phase worker=$safeWorker attempt=$Attempt elapsedSeconds=0 exitCategory=unknown" -ForegroundColor DarkGray

        while (-not $process.WaitForExit(250)) {
            if ($ShouldCancel -and (& $ShouldCancel)) {
                throw [System.OperationCanceledException]::new('Vally process execution was interrupted.')
            }
            if ($stopwatch.Elapsed.TotalSeconds -ge $nextHeartbeat) {
                $elapsedSeconds = [math]::Floor($stopwatch.Elapsed.TotalSeconds)
                Write-Host "Vally progress: event=heartbeat phase=$Phase worker=$safeWorker attempt=$Attempt elapsedSeconds=$elapsedSeconds exitCategory=unknown" -ForegroundColor DarkGray
                $nextHeartbeat += $HeartbeatIntervalSeconds
            }
        }

        $process.WaitForExit()
        $stopwatch.Stop()
        $stdoutText = $standardOutput.GetAwaiter().GetResult()
        $stderrText = $standardError.GetAwaiter().GetResult()
        $exitCode = $process.ExitCode
        $combinedText = "$stdoutText`n$stderrText"
        $exitCategory = Get-VallyExitCategory -ExitCode $exitCode -OutputText $combinedText
        $elapsedSeconds = [math]::Floor($stopwatch.Elapsed.TotalSeconds)
        Write-Host "Vally progress: event=phase-complete phase=$Phase worker=$safeWorker attempt=$Attempt elapsedSeconds=$elapsedSeconds exitCategory=$exitCategory" -ForegroundColor DarkGray

        if ($LogPath) {
            $directory = Split-Path -Parent $LogPath
            if ($directory -and -not (Test-Path -LiteralPath $directory)) {
                New-Item -ItemType Directory -Path $directory -Force | Out-Null
            }
            $lines = @(
                foreach ($text in @($stdoutText, $stderrText)) {
                    if ([string]::IsNullOrEmpty($text)) { continue }
                    @($text -split '\r?\n') | Where-Object { $_.Length -gt 0 }
                }
            )
            if ($AppendLog) { Add-Content -LiteralPath $LogPath -Value $lines -Encoding utf8NoBOM }
            else { Set-Content -LiteralPath $LogPath -Value $lines -Encoding utf8NoBOM }
        }

        return @{
            ExitCode           = $exitCode
            ExitCategory       = $exitCategory
            ElapsedMilliseconds = [int64]$stopwatch.ElapsedMilliseconds
            Worker             = $safeWorker
        }
    }
    finally {
        if ($started -and -not $process.HasExited) {
            $process.Kill($true)
            $process.WaitForExit()
        }
        if ($stopwatch -and $stopwatch.IsRunning) { $stopwatch.Stop() }
        $process.Dispose()
    }
}

function Invoke-VallySpec {
    <#
    .SYNOPSIS
    Runs `vally eval` for a single spec and returns aggregated outcomes.

    .DESCRIPTION
    Invokes the configured vally executable with `eval --eval-spec --model
    --output-dir`, captures stdout/stderr (optionally tee'd to a log file),
    resolves the timestamped run directory under `OutputDir`, and aggregates
    the `results.jsonl` via `Read-VallyResultsJsonl`.

    .PARAMETER SpecPath
    Path to the eval spec YAML file.

    .PARAMETER OutputDir
    Directory passed to `vally eval --output-dir`. Created if it does not exist.

    .PARAMETER Model
    Model passed to `vally eval --model`.

    .PARAMETER VallyCommand
    Path or name of the vally executable. Defaults to `vally`. Tests override
    this with the stub fixture path.

    .PARAMETER LogPath
    Optional path to tee stdout/stderr to a log file.

    .PARAMETER Tag
    Optional `kind=slug` filter passed to `vally eval --tag`. Scopes execution
    to the stimuli whose `tags.<kind>` matches the slug. Used when a single
    shared spec is backlinked by multiple artifacts so each artifact runs only
    its own stimuli.

    .PARAMETER Workers
    Concurrent stimulus sessions passed to `vally eval --workers`. Vally's own
    default is 5. Useful concurrency is capped by the batch size, which is the
    tag-filtered stimulus count multiplied by `defaults.runs`, so raising this
    past that product yields nothing.

    .OUTPUTS
    [hashtable] `@{ specPath; exitCode; runDir; assertionsPassed; assertionsFailed; durationMs; trials; resultsPath; perStimulus; failedOrErroredTrials; tag }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$Model,
        [string]$VallyCommand = 'vally',
        [string]$LogPath,
        [string]$Tag,
        [ValidateRange(1, 64)][int]$Workers = 8,
        [int]$MaxErroredRetries = 2,
        [string]$RunKey,
        [string]$InputDigest,
        [string]$Worker,
        [ValidateRange(1, 3600)][int]$HeartbeatIntervalSeconds = 60
    )

    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $vallyArgs = @(
        'eval'
        '--eval-spec', $SpecPath
        '--model', $Model
        '--output-dir', $OutputDir
        '--workers', $Workers
    )
    if (-not [string]::IsNullOrWhiteSpace($Tag)) {
        $vallyArgs += @('--tag', $Tag)
    }

    $threshold = Get-VallySpecThreshold -SpecPath $SpecPath
    $configuration = Get-VallyDiagnosticConfiguration -SpecPath $SpecPath -Tag $Tag
    $specLabel = Split-Path -Leaf $SpecPath
    if ([string]::IsNullOrWhiteSpace($RunKey)) {
        $RunKey = if ($Tag) { "$specLabel|$Tag" } else { $specLabel }
    }
    if ([string]::IsNullOrWhiteSpace($Worker)) {
        $Worker = if ([string]::IsNullOrWhiteSpace($Tag)) { $specLabel } else { $Tag }
    }
    $maxAttempts = [Math]::Max(1, $MaxErroredRetries + 1)
    $phaseTimings = [System.Collections.Generic.List[object]]::new()
    $attempts = [System.Collections.Generic.List[object]]::new()
    $best = $null
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        $attempt++
        $attemptOutput = Join-Path $OutputDir ('attempt-{0:D2}-{1}' -f $attempt, [Guid]::NewGuid().ToString('N'))
        $vallyArgs[[array]::IndexOf($vallyArgs, '--output-dir') + 1] = $attemptOutput
        $processResult = Invoke-VallyProcess `
            -Command $VallyCommand `
            -Arguments $vallyArgs `
            -LogPath $LogPath `
            -AppendLog:($attempt -gt 1) `
            -Phase 'ordinary-eval' `
            -Worker $Worker `
            -Attempt $attempt `
            -HeartbeatIntervalSeconds $HeartbeatIntervalSeconds
        $phaseTimings.Add([ordered]@{
                phase          = 'ordinary-eval'
                worker         = $processResult.Worker
                attempt        = $attempt
                elapsedSeconds = [math]::Round($processResult.ElapsedMilliseconds / 1000, 3)
                exitCategory   = $processResult.ExitCategory
            })

        $runDir = Resolve-VallyRunDir -OutputDir $attemptOutput
        $aggregate = Read-VallyResultsJsonl -RunDir $runDir -Threshold $threshold -ExpectedStimuli $configuration.stimuli

        $candidate = @{
            attempt   = $attempt
            exitCode  = $processResult.ExitCode
            runDir    = $runDir
            aggregate = $aggregate
            elapsedMs = [int]$processResult.ElapsedMilliseconds
        }
        $attempts.Add([ordered]@{
            runKey = $RunKey
            ordinal = $attempt
            selected = $false
            selectionReason = $null
            exitCategory = $processResult.ExitCategory
            assertionsPassed = [int]$aggregate.assertionsPassed
            assertionsFailed = [int]$aggregate.assertionsFailed
            erroredTrials = [int]$aggregate.errored
            observedTrials = [int]$aggregate.trials
            recordIssues = @($aggregate.recordIssues)
            perStimulus = @(
                foreach ($name in $configuration.stimuli.Keys) {
                    $bucket = $aggregate.perStimulus[$name]
                    [ordered]@{
                        stimulusName = $name
                        expectedTrials = [int]$configuration.stimuli[$name].runs
                        observedTrials = if ($bucket) { [int]$bucket.trials } else { 0 }
                        aggregateScore = if ($bucket) { $bucket.aggregateScore } else { $null }
                        aggregatePassed = if ($bucket) { $bucket.aggregatePassed } else { $null }
                    }
                }
            )
            trials = @($aggregate.trialDiagnostics)
        })
        # Keep the cleanest attempt (fewest errored trials) across retries.
        if ($null -eq $best -or [int]$aggregate.errored -lt [int]$best.aggregate.errored) {
            $best = $candidate
        }

        if ([int]$aggregate.errored -le 0) { break }
        if ($attempt -lt $maxAttempts) {
            Write-Host "vally: $([int]$aggregate.errored) trial(s) errored for spec '$specLabel'; retrying to obtain a clean count (attempt $attempt of $($maxAttempts - 1) retries)..."
        }
    }

    $exitCode = $best.exitCode
    $runDir = $best.runDir
    $aggregate = $best.aggregate
    foreach ($entry in $attempts) {
        $entry.selected = $entry.ordinal -eq $best.attempt
        $entry.selectionReason = if ($entry.selected) { 'fewest-errors-first-on-tie' }
        elseif ($entry.erroredTrials -gt $best.aggregate.errored) { 'more-errors' }
        else { 'later-tie' }
    }
    $repoRoot = [IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../../..'))
    $checkout = (& git -C $repoRoot rev-parse HEAD 2>$null | Select-Object -First 1)
    if ($checkout -cnotmatch '^[a-f0-9]{40,64}$') { $checkout = $null }
    $versions = [ordered]@{}
    foreach ($packageName in @('vally', 'vally-cli')) {
        $packagePath = Join-Path $repoRoot "node_modules/@microsoft/$packageName/package.json"
        $versions[$packageName] = if (Test-Path -LiteralPath $packagePath) {
            [string](Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json).version
        } else { $null }
    }

    $durationMs = if ($aggregate.durationMs -gt 0) {
        [int]$aggregate.durationMs
    }
    else {
        [int]$best.elapsedMs
    }

    return @{
        specPath         = $SpecPath
        exitCode         = $exitCode
        runDir           = $runDir
        assertionsPassed = $aggregate.assertionsPassed
        assertionsFailed = $aggregate.assertionsFailed
        erroredTrials    = $aggregate.errored
        durationMs       = $durationMs
        trials           = $aggregate.trials
        stimuliPassed    = $aggregate.stimuliPassed
        stimuliFailed    = $aggregate.stimuliFailed
        resultsPath      = $aggregate.resultsPath
        perStimulus      = $aggregate.perStimulus
        failedOrErroredTrials = $aggregate.failedOrErroredTrials
        diagnostics = [ordered]@{
            schemaVersion = '1.0.0'
            runKey = $RunKey
            configurationStatus = $configuration.status
            specDigest = $configuration.specDigest
            inputDigest = if ($InputDigest) { $InputDigest } else { $configuration.specDigest }
            inputDigestScope = if ($InputDigest) { 'checkout-evaluation-inputs' } else { 'spec-only' }
            selectionDigest = $configuration.selectionDigest
            checkout = $checkout
            executorModel = $Model
            judgeModels = $configuration.judgeModels
            versions = $versions
            threshold = $threshold
            expectedStimuli = $configuration.stimuli
            selectedAttempt = $best.attempt
            attempts = @($attempts)
        }
        tag              = $Tag
        phaseTimings     = @($phaseTimings)
    }
}

function Test-SpecInputModeration {
    <#
    .SYNOPSIS
    Moderates all stimulus prompts in an eval spec before execution.

    .DESCRIPTION
    Parses the eval spec YAML, extracts all stimulus.prompt fields, sends them
    through Invoke-ContentModeration.ps1, and returns a moderation result that
    indicates whether the spec should be skipped due to flagged input.

    .PARAMETER SpecPath
    Path to the eval spec YAML file.

    .PARAMETER ArtifactId
    Artifact identifier for scope tagging (e.g., "agent-name").

    .PARAMETER ModerationScript
    Path to Invoke-ContentModeration.ps1. Defaults to scripts/evals/Invoke-ContentModeration.ps1.

    .PARAMETER Threshold
    Toxicity threshold (0.0-1.0). Defaults to 0.5.

    .PARAMETER RepoRoot
    Repository root. Defaults to git root.

    .OUTPUTS
    [hashtable] @{ flagged = $bool; flaggedCount = $int; outputPath = $string; error = $bool }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [Parameter(Mandatory = $true)][string]$ArtifactId,
        [string]$ModerationScript,
        [double]$Threshold = 0.5,
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '../../..' }
    }
    if (-not $ModerationScript) {
        $ModerationScript = Join-Path $RepoRoot 'scripts/evals/Invoke-ContentModeration.ps1'
    }

    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
        Write-Warning "Spec file not found: $SpecPath"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $null }
    }

    $specContent = Get-Content -LiteralPath $SpecPath -Raw -Encoding utf8
    try {
        $spec = $specContent | ConvertFrom-Yaml
    }
    catch {
        Write-Warning "Failed to parse spec YAML: $SpecPath"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $null }
    }

    $records = @()
    $index = 0
    if ($spec -and $spec.stimuli) {
        foreach ($stimulus in $spec.stimuli) {
            if ($stimulus -and $stimulus.prompt) {
                $records += @{
                    id   = "input-$ArtifactId-$index"
                    text = [string]$stimulus.prompt
                }
                $index++
            }
        }
    }

    if ($records.Count -eq 0) {
        Write-Verbose "No stimulus prompts to moderate in $SpecPath"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $null }
    }

    $scope = "input-$ArtifactId"
    $outFile = Join-Path $RepoRoot "logs/moderation-$scope.json"

    Write-Verbose "Moderating $($records.Count) stimulus prompts for artifact: $ArtifactId"
    try {
        & $ModerationScript -Records $records -Scope $scope -Threshold $Threshold -OutFile $outFile -ErrorAction Stop
        $moderationExitCode = $LASTEXITCODE
    }
    catch {
        Write-Warning "Content moderation script failed: $_"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $outFile; error = $true }
    }

    # Exit 1 = genuine content flag; exit >=2 = moderation infrastructure/usage error.
    $flagged = $moderationExitCode -eq 1
    $moderationError = $moderationExitCode -ge 2
    $flaggedCount = 0
    if (Test-Path -LiteralPath $outFile) {
        $output = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $flaggedCount = [int]$output.summary.flaggedCount
    }

    return @{
        flagged       = $flagged
        flaggedCount  = $flaggedCount
        outputPath    = $outFile
        error         = $moderationError
    }
}

function Test-SpecOutputModerationBatch {
    <#
    .SYNOPSIS
    Moderates model outputs from multiple Vally runs in one backend invocation.

    .DESCRIPTION
    Extracts trial outputs from each run, attaches the run's effective threshold
    to every moderation record, and invokes Invoke-ContentModeration.ps1 once.
    Results are attributed back to their originating run key. Typed Vally
    metadata records are ignored while legacy untyped trial records remain
    supported.

    .PARAMETER Run
    Run descriptors with runKey, runDir, and threshold entries.

    .PARAMETER BatchId
    Safe shard identifier used for the moderation output file.

    .PARAMETER ModerationScript
    Path to Invoke-ContentModeration.ps1.

    .PARAMETER Threshold
    Default toxicity threshold for records without an explicit run threshold.

    .PARAMETER RepoRoot
    Repository root.

    .OUTPUTS
    [hashtable] Aggregate moderation result with a byRun map.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Run,
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$BatchId,
        [string]$ModerationScript,
        [double]$Threshold = 0.5,
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '../../..' }
    }
    if (-not $ModerationScript) {
        $ModerationScript = Join-Path $RepoRoot 'scripts/evals/Invoke-ContentModeration.ps1'
    }

    $byRun = @{}
    foreach ($entry in $Run) {
        $runKey = [string]$entry.runKey
        if ([string]::IsNullOrWhiteSpace($runKey)) { continue }
        $byRun[$runKey] = @{
            flagged       = $false
            flaggedCount  = 0
            flaggedLabels = @()
            outputPath    = $null
            error         = $false
        }
    }

    $empty = @{
        flagged      = $false
        flaggedCount = 0
        outputPath   = $null
        error        = $false
        byRun        = $byRun
    }
    if ($Run.Count -eq 0) { return $empty }

    $records = [System.Collections.Generic.List[hashtable]]::new()
    $recordOwners = @{}
    $index = 0

    foreach ($entry in $Run) {
        $runKey = [string]$entry.runKey
        $runDir = [string]$entry.runDir
        if ([string]::IsNullOrWhiteSpace($runKey) -or -not $byRun.ContainsKey($runKey)) { continue }
        if ([string]::IsNullOrWhiteSpace($runDir) -or -not (Test-Path -LiteralPath $runDir -PathType Container)) {
            Write-Warning "Run directory not found: $runDir"
            continue
        }

        $jsonl = Get-ChildItem -LiteralPath $runDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue |
            Select-Object -First 1
        if (-not $jsonl) {
            Write-Warning "results.jsonl not found in $runDir"
            continue
        }

        $effectiveThreshold = if ($entry.ContainsKey('threshold') -and $null -ne $entry.threshold) {
            [double]$entry.threshold
        }
        else {
            $Threshold
        }

        foreach ($line in Get-Content -LiteralPath $jsonl.FullName -Encoding utf8) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            try {
                $obj = $line | ConvertFrom-Json -Depth 100
            }
            catch {
                continue
            }

            if ($obj.PSObject.Properties['type'] -and
                -not [string]::IsNullOrWhiteSpace([string]$obj.type) -and
                [string]$obj.type -ne 'trial-result') {
                continue
            }

            $outputText = $null
            if ($obj.PSObject.Properties['trajectory'] -and $obj.trajectory -and
                $obj.trajectory.PSObject.Properties['output'] -and $obj.trajectory.output) {
                $outputText = [string]$obj.trajectory.output
            }
            if (-not $outputText) { continue }

            $recordId = "output-$index"
            $records.Add(@{
                id        = $recordId
                text      = $outputText
                threshold = $effectiveThreshold
            })
            $recordOwners[$recordId] = $runKey
            $index++
        }
    }

    if ($records.Count -eq 0) {
        Write-Verbose 'No model outputs to moderate in the shard batch.'
        return $empty
    }

    $scope = "output-$BatchId"
    $outFile = Join-Path $RepoRoot "logs/moderation-$scope.json"
    Write-Verbose "Moderating $($records.Count) model outputs in shard batch: $BatchId"
    try {
        & $ModerationScript -Records $records.ToArray() -Scope $scope -Threshold $Threshold -OutFile $outFile -ErrorAction Stop
        $moderationExitCode = $LASTEXITCODE
    }
    catch {
        Write-Warning "Content moderation script failed: $_"
        foreach ($runKey in $byRun.Keys) {
            $byRun[$runKey].error = $true
            $byRun[$runKey].outputPath = $outFile
        }
        return @{ flagged = $false; flaggedCount = 0; outputPath = $outFile; error = $true; byRun = $byRun }
    }

    $moderationError = $moderationExitCode -ge 2
    $flaggedCount = 0
    $mappedFlaggedCount = 0
    if (Test-Path -LiteralPath $outFile) {
        try {
            $output = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
            $flaggedCount = [int]$output.summary.flaggedCount
            foreach ($record in @($output.records)) {
                if (-not $record.PSObject.Properties['id']) { continue }
                $recordId = [string]$record.id
                if (-not $recordOwners.ContainsKey($recordId)) { continue }
                if (-not ($record.PSObject.Properties['flagged'] -and [bool]$record.flagged)) { continue }

                $runKey = $recordOwners[$recordId]
                $bucket = $byRun[$runKey]
                $bucket.flagged = $true
                $bucket.flaggedCount++
                $mappedFlaggedCount++
                if ($record.PSObject.Properties['flaggedLabels']) {
                    $bucket.flaggedLabels = @($bucket.flaggedLabels) + @($record.flaggedLabels | ForEach-Object { [string]$_ })
                }
            }
        }
        catch {
            Write-Warning "Failed to parse moderation output '$outFile': $_"
            $moderationError = $true
        }
    }
    else {
        $moderationError = $true
    }

    if ($moderationExitCode -eq 1 -and $flaggedCount -eq 0) { $flaggedCount = 1 }
    $unattributedFlags = $flaggedCount - $mappedFlaggedCount
    if ($unattributedFlags -gt 0) {
        if ($byRun.Count -eq 1) {
            $onlyKey = @($byRun.Keys)[0]
            $byRun[$onlyKey].flagged = $true
            $byRun[$onlyKey].flaggedCount += $unattributedFlags
        }
        else {
            Write-Warning "$unattributedFlags moderation flag(s) could not be attributed to a Vally run."
            $moderationError = $true
        }
    }

    foreach ($runKey in $byRun.Keys) {
        $byRun[$runKey].outputPath = $outFile
        if ($moderationError) { $byRun[$runKey].error = $true }
    }

    return @{
        flagged      = ($flaggedCount -gt 0)
        flaggedCount = $flaggedCount
        outputPath   = $outFile
        error        = $moderationError
        byRun        = $byRun
    }
}

function Test-SpecOutputModeration {
    <#
    .SYNOPSIS
    Moderates model outputs from a vally eval results.jsonl file.

    .DESCRIPTION
    Reads the results.jsonl from a vally run directory, extracts all trajectory
    model outputs, sends them through Invoke-ContentModeration.ps1, and returns
    a moderation result indicating whether the spec outputs should be flagged.

    .PARAMETER RunDir
    Vally run directory (timestamped subdirectory under --output-dir).

    .PARAMETER ArtifactId
    Artifact identifier for scope tagging.

    .PARAMETER ModerationScript
    Path to Invoke-ContentModeration.ps1.

    .PARAMETER Threshold
    Toxicity threshold (0.0-1.0). Defaults to 0.5.

    .PARAMETER RepoRoot
    Repository root.

    .OUTPUTS
    [hashtable] @{ flagged = $bool; flaggedCount = $int; outputPath = $string; error = $bool }
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$RunDir,
        [Parameter(Mandatory = $true)][string]$ArtifactId,
        [string]$ModerationScript,
        [double]$Threshold = 0.5,
        [string]$RepoRoot
    )

    if (-not $RepoRoot) {
        $RepoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $RepoRoot) { $RepoRoot = Join-Path $PSScriptRoot '../../..' }
    }
    if (-not $ModerationScript) {
        $ModerationScript = Join-Path $RepoRoot 'scripts/evals/Invoke-ContentModeration.ps1'
    }

    if ([string]::IsNullOrWhiteSpace($RunDir) -or -not (Test-Path -LiteralPath $RunDir -PathType Container)) {
        Write-Warning "Run directory not found: $RunDir"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $null }
    }

    $jsonl = Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $jsonl) {
        Write-Warning "results.jsonl not found in $RunDir"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $null }
    }

    $records = @()
    $index = 0
    foreach ($line in Get-Content -LiteralPath $jsonl.FullName -Encoding utf8) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json -Depth 100
        }
        catch {
            continue
        }

        if ($obj.PSObject.Properties['type'] -and
            -not [string]::IsNullOrWhiteSpace([string]$obj.type) -and
            [string]$obj.type -ne 'trial-result') {
            continue
        }

        $outputText = $null
        if ($obj.PSObject.Properties['trajectory'] -and $obj.trajectory -and
            $obj.trajectory.PSObject.Properties['output'] -and $obj.trajectory.output) {
            $outputText = [string]$obj.trajectory.output
        }

        if ($outputText) {
            $records += @{
                id   = "output-$ArtifactId-$index"
                text = $outputText
            }
            $index++
        }
    }

    if ($records.Count -eq 0) {
        Write-Verbose "No model outputs to moderate from $($jsonl.FullName)"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $null }
    }

    $scope = "output-$ArtifactId"
    $outFile = Join-Path $RepoRoot "logs/moderation-$scope.json"

    Write-Verbose "Moderating $($records.Count) model outputs for artifact: $ArtifactId"
    try {
        & $ModerationScript -Records $records -Scope $scope -Threshold $Threshold -OutFile $outFile -ErrorAction Stop
        $moderationExitCode = $LASTEXITCODE
    }
    catch {
        Write-Warning "Content moderation script failed: $_"
        return @{ flagged = $false; flaggedCount = 0; outputPath = $outFile; error = $true }
    }

    # Exit 1 = genuine content flag; exit >=2 = moderation infrastructure/usage error.
    $flagged = $moderationExitCode -eq 1
    $moderationError = $moderationExitCode -ge 2
    $flaggedCount = 0
    if (Test-Path -LiteralPath $outFile) {
        $output = Get-Content -LiteralPath $outFile -Raw | ConvertFrom-Json
        $flaggedCount = [int]$output.summary.flaggedCount
    }

    return @{
        flagged       = $flagged
        flaggedCount  = $flaggedCount
        outputPath    = $outFile
        error         = $moderationError
    }
}

function Get-VallySpecBacklinkCount {
    <#
    .SYNOPSIS
    Counts how many distinct artifacts the stimulus index backlinks to each spec.

    .DESCRIPTION
    Walks the index `coverage` map (coverage key -> array of spec-relative paths)
    and tallies, per spec, the number of coverage keys that reference it. A spec
    backlinked by more than one artifact runs once PER artifact with a
    `--tag kind=slug` filter so each artifact is scored only on its own stimuli
    instead of inheriting another artifact's results.

    .PARAMETER Index
    The stimulus index hashtable produced by New-StimulusIndex. The optional
    `coverage` key maps each coverage key to an array of spec-relative paths.

    .OUTPUTS
    [hashtable] mapping a spec-relative path to its backlink count.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Index
    )

    $specBacklinkCount = @{}
    if ($Index.ContainsKey('coverage') -and $null -ne $Index['coverage']) {
        foreach ($covKey in $Index['coverage'].Keys) {
            foreach ($covSpec in $Index['coverage'][$covKey]) {
                if (-not $specBacklinkCount.ContainsKey($covSpec)) { $specBacklinkCount[$covSpec] = 0 }
                $specBacklinkCount[$covSpec]++
            }
        }
    }

    return $specBacklinkCount
}

function Get-VallySpecRunPlan {
    <#
    .SYNOPSIS
    Builds the per-artifact spec-run plan, keying each run by a composite
    spec+tag runKey so a shared spec runs once per backlinking artifact.

    .DESCRIPTION
    When a spec is backlinked by more than one artifact (SpecBacklinkCount > 1),
    each artifact runs only its own stimuli via a `kind=artifactId` tag,
    producing a distinct runKey of the form `specRel|tag`. Specs backlinked by a
    single artifact run untagged with a runKey equal to specRel. Artifacts with
    no covering spec are collected into missingSpecs.

    .PARAMETER Artifact
    Array of artifact descriptors. Each is a hashtable with keys: kind,
    artifactId, path, status, and specs (an array of spec-relative paths;
    empty when no spec covers the artifact).

    .PARAMETER SpecBacklinkCount
    Hashtable mapping a spec-relative path to the number of artifacts that
    backlink it.

    .PARAMETER IndexRoot
    Root path used to resolve each specRel to an absolute spec path.

    .OUTPUTS
    [hashtable] with keys: uniqueSpecRuns (runKey -> @{ specRel; specAbs; tag }),
    artifactPlan (array of @{ kind; artifactId; path; status; specRuns }), and
    missingSpecs (array of @{ kind; artifactId; path }).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Artifact,

        [Parameter(Mandatory = $true)]
        [hashtable]$SpecBacklinkCount,

        [Parameter(Mandatory = $true)]
        [string]$IndexRoot
    )

    $uniqueSpecRuns = @{}
    $artifactPlan   = [System.Collections.Generic.List[hashtable]]::new()
    $missingSpecs   = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($a in $Artifact) {
        $artifactKind = [string]$a.kind
        $artifactId   = [string]$a.artifactId
        $specs        = @($a.specs)

        if ($specs.Count -eq 0) {
            $missingSpecs.Add(@{ kind = $artifactKind; artifactId = $artifactId; path = [string]$a.path })
            continue
        }

        $artifactSpecRuns = [System.Collections.Generic.List[string]]::new()
        foreach ($specRel in $specs) {
            $shared = ($SpecBacklinkCount.ContainsKey($specRel) -and $SpecBacklinkCount[$specRel] -gt 1)
            if ($shared) {
                $tag    = "$artifactKind=$artifactId"
                $runKey = "$specRel|$tag"
            }
            else {
                $tag    = ''
                $runKey = $specRel
            }
            if (-not $uniqueSpecRuns.ContainsKey($runKey)) {
                $uniqueSpecRuns[$runKey] = @{
                    specRel = $specRel
                    specAbs = Join-Path -Path $IndexRoot -ChildPath $specRel
                    tag     = $tag
                }
            }
            $artifactSpecRuns.Add($runKey) | Out-Null
        }

        $artifactPlan.Add(@{
            kind        = $artifactKind
            artifactId  = $artifactId
            path        = [string]$a.path
            status      = [string]$a.status
            specRuns    = @($artifactSpecRuns)
        })
    }

    return @{
        uniqueSpecRuns = $uniqueSpecRuns
        artifactPlan   = $artifactPlan
        missingSpecs   = $missingSpecs
    }
}

function Get-AgentEvalOwnershipComponent {
    <#
    .SYNOPSIS
    Groups artifacts connected by an identical deduplicated run key.

    .OUTPUTS
    [object[]] Objects containing sorted ArtifactKeys and RunKeys arrays.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [object[]]$ArtifactPlan
    )

    $artifactRuns = @{}
    $runArtifacts = @{}
    foreach ($artifact in $ArtifactPlan) {
        $artifactKey = "$([string]$artifact.kind):$([string]$artifact.artifactId)"
        if (-not $artifactRuns.ContainsKey($artifactKey)) {
            $artifactRuns[$artifactKey] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        }
        foreach ($runKey in @($artifact.specRuns)) {
            [void]$artifactRuns[$artifactKey].Add([string]$runKey)
            if (-not $runArtifacts.ContainsKey([string]$runKey)) {
                $runArtifacts[[string]$runKey] = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
            }
            [void]$runArtifacts[[string]$runKey].Add($artifactKey)
        }
    }

    $unvisited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($artifactKey in $artifactRuns.Keys) { [void]$unvisited.Add($artifactKey) }
    $components = [System.Collections.Generic.List[object]]::new()

    while ($unvisited.Count -gt 0) {
        $start = @($unvisited | Sort-Object)[0]
        $queue = [System.Collections.Generic.Queue[string]]::new()
        $queue.Enqueue($start)
        [void]$unvisited.Remove($start)
        $componentArtifacts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $componentRuns = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

        while ($queue.Count -gt 0) {
            $artifactKey = $queue.Dequeue()
            [void]$componentArtifacts.Add($artifactKey)
            foreach ($runKey in $artifactRuns[$artifactKey]) {
                [void]$componentRuns.Add($runKey)
                foreach ($neighbor in $runArtifacts[$runKey]) {
                    if ($unvisited.Remove($neighbor)) { $queue.Enqueue($neighbor) }
                }
            }
        }

        $components.Add([pscustomobject][ordered]@{
                ArtifactKeys = @($componentArtifacts | Sort-Object)
                RunKeys      = @($componentRuns | Sort-Object)
            })
    }

    return @($components | Sort-Object { $_.ArtifactKeys[0] })
}

function Get-AgentEvalFileDigest {
    <#
    .SYNOPSIS
    Returns a prefixed SHA-256 digest for one file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Required manifest not found: $Path"
    }
    return "sha256:$((Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant())"
}

function Get-AgentEvalValueDigest {
    <#
    .SYNOPSIS
    Returns a prefixed SHA-256 digest for a canonical ordered value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)]$Value)

    $json = $Value | ConvertTo-Json -Depth 50 -Compress
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
    $hash = [System.Security.Cryptography.SHA256]::HashData($bytes)
    return "sha256:$([Convert]::ToHexString($hash).ToLowerInvariant())"
}

function Test-AgentEvalPlanDigest {
    <#
    .SYNOPSIS
    Verifies the digest on a canonical agent eval plan object.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory = $true)][psobject]$Plan)

    $payload = [ordered]@{
        schemaVersion = $Plan.schemaVersion
        manifestDigests = [ordered]@{
            changedArtifacts = $Plan.manifestDigests.changedArtifacts
            changedSpecs = $Plan.manifestDigests.changedSpecs
        }
        baseline = [ordered]@{
            required = [bool]$Plan.baseline.required
            reason = [string]$Plan.baseline.reason
            models = @($Plan.baseline.models)
        }
        ordinaryShards = @($Plan.ordinaryShards)
        expectedProducers = @($Plan.expectedProducers)
    }
    return [string]$Plan.planDigest -ceq (Get-AgentEvalValueDigest -Value $payload)
}

function Assert-AgentEvalOwnership {
    <#
    .SYNOPSIS
    Verifies every expected artifact and run key has exactly one shard owner.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ExpectedArtifact,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ExpectedRunKey,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Shard
    )

    foreach ($expected in $ExpectedArtifact) {
        $count = 0
        foreach ($candidateShard in $Shard) {
            foreach ($artifactKey in @($candidateShard.artifacts)) {
                if ([string]$artifactKey -ceq $expected) { $count++ }
            }
        }
        if ($count -ne 1) { throw "Artifact '$expected' has $count shard owners; expected exactly one." }
    }
    foreach ($expected in $ExpectedRunKey) {
        $count = 0
        foreach ($candidateShard in $Shard) {
            foreach ($ownedRunKey in @($candidateShard.runKeys)) {
                if ([string]$ownedRunKey -ceq $expected) { $count++ }
            }
        }
        if ($count -ne 1) { throw "Run key '$expected' has $count shard owners; expected exactly one." }
    }
}

Export-ModuleMember -Function @(
    'Resolve-VallyRunDir',
    'Get-VallyDiagnosticConfiguration',
    'Get-VallyInputDigest',
    'Test-VallyDiagnosticEvidence',
    'Read-VallyResultsJsonl',
    'Get-VallyExitCategory',
    'Invoke-VallyProcess',
    'Invoke-VallySpec',
    'Test-SpecInputModeration',
    'Test-SpecOutputModerationBatch',
    'Test-SpecOutputModeration',
    'Get-VallySpecBacklinkCount',
    'Get-VallySpecRunPlan',
    'Get-AgentEvalOwnershipComponent',
    'Assert-AgentEvalOwnership',
    'Get-AgentEvalFileDigest',
    'Get-AgentEvalValueDigest',
    'Test-AgentEvalPlanDigest'
)
