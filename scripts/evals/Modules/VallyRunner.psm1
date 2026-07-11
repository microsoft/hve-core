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

    .OUTPUTS
    [hashtable] `@{ assertionsPassed; assertionsFailed; durationMs; trials; resultsPath; perStimulus }`.
    `perStimulus` is an ordered map keyed by stimulus name with `@{ assertionsPassed; assertionsFailed; durationMs; trials }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RunDir,
        [Nullable[double]]$Threshold
    )

    $empty = @{
        assertionsPassed = 0
        assertionsFailed = 0
        errored          = 0
        durationMs       = 0
        trials           = 0
        resultsPath      = $null
        perStimulus      = [ordered]@{}
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

    foreach ($line in Get-Content -LiteralPath $jsonl.FullName -Encoding utf8) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $obj = $line | ConvertFrom-Json -Depth 100
        }
        catch {
            continue
        }

        # Vally 0.6 writes a typed run-summary record after the trial records.
        # Legacy Vally versions emitted untyped trial records, so accept those
        # while ignoring every explicitly typed non-trial record.
        if ($obj.PSObject.Properties['type'] -and
            -not [string]::IsNullOrWhiteSpace([string]$obj.type) -and
            [string]$obj.type -ne 'trial-result') {
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
            $hasScore = $true
            $scoreValue = [double]$gradeResult.score
        }
        $hasPassed = ($gradeResult -and $gradeResult.PSObject.Properties['passed'] -and $null -ne $gradeResult.passed)

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

        if ($stimulusName) {
            if (-not $perStimulus.Contains($stimulusName)) {
                $perStimulus[$stimulusName] = @{
                    assertionsPassed = 0
                    assertionsFailed = 0
                    errored          = 0
                    durationMs       = 0
                    trials           = 0
                }
            }
            $bucket = $perStimulus[$stimulusName]
            $bucket.trials++
            if ($trialErrored) { $bucket.errored++ }
            elseif ($trialPassed) { $bucket.assertionsPassed++ }
            else { $bucket.assertionsFailed++ }
            $bucket.durationMs += $trialWallMs
        }
    }

    return @{
        assertionsPassed = $passed
        assertionsFailed = $failed
        errored          = $errored
        durationMs       = $durationMs
        trials           = $trials
        resultsPath      = $jsonl.FullName
        perStimulus      = $perStimulus
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

    .OUTPUTS
    [hashtable] `@{ specPath; exitCode; runDir; assertionsPassed; assertionsFailed; durationMs; trials; resultsPath; perStimulus; tag }`.
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
        [int]$MaxErroredRetries = 2
    )

    if (-not (Test-Path -LiteralPath $OutputDir)) {
        New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
    }

    $vallyArgs = @(
        'eval'
        '--eval-spec', $SpecPath
        '--model', $Model
        '--output-dir', $OutputDir
    )
    if (-not [string]::IsNullOrWhiteSpace($Tag)) {
        $vallyArgs += @('--tag', $Tag)
    }

    $threshold = Get-VallySpecThreshold -SpecPath $SpecPath
    $specLabel = Split-Path -Leaf $SpecPath
    $maxAttempts = [Math]::Max(1, $MaxErroredRetries + 1)
    $allLines = [System.Collections.Generic.List[string]]::new()
    $best = $null
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        $attempt++
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $prev = [Console]::OutputEncoding
        $exitCode = 0
        try {
            [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
            $raw = & $VallyCommand @vallyArgs 2>&1
            $exitCode = $LASTEXITCODE
        }
        finally {
            [Console]::OutputEncoding = $prev
            $sw.Stop()
        }

        $lines = @($raw | ForEach-Object { $_.ToString() })
        foreach ($line in $lines) { Write-Host $line; [void]$allLines.Add($line) }

        $runDir = Resolve-VallyRunDir -OutputDir $OutputDir
        $aggregate = Read-VallyResultsJsonl -RunDir $runDir -Threshold $threshold

        $candidate = @{
            exitCode  = $exitCode
            runDir    = $runDir
            aggregate = $aggregate
            elapsedMs = [int]$sw.ElapsedMilliseconds
        }
        # Keep the cleanest attempt (fewest errored trials) across retries.
        if ($null -eq $best -or [int]$aggregate.errored -lt [int]$best.aggregate.errored) {
            $best = $candidate
        }

        if ([int]$aggregate.errored -le 0) { break }
        if ($attempt -lt $maxAttempts) {
            Write-Host "vally: $([int]$aggregate.errored) trial(s) errored for spec '$specLabel'; retrying to obtain a clean count (attempt $attempt of $($maxAttempts - 1) retries)..."
        }
    }

    if ($LogPath) {
        $dir = Split-Path -Parent $LogPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $LogPath -Value $allLines -Encoding utf8NoBOM
    }

    $exitCode = $best.exitCode
    $runDir = $best.runDir
    $aggregate = $best.aggregate

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
        resultsPath      = $aggregate.resultsPath
        perStimulus      = $aggregate.perStimulus
        tag              = $Tag
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

Export-ModuleMember -Function @(
    'Resolve-VallyRunDir',
    'Read-VallyResultsJsonl',
    'Invoke-VallySpec',
    'Test-SpecInputModeration',
    'Test-SpecOutputModerationBatch',
    'Test-SpecOutputModeration',
    'Get-VallySpecBacklinkCount',
    'Get-VallySpecRunPlan'
)
