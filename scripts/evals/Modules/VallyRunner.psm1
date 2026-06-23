# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# VallyRunner.psm1
#
# Purpose: Spawn `vally eval` for a single spec, locate the timestamped run
#          directory vally writes under --output-dir, and aggregate the
#          resulting results.jsonl into pass/fail counts suitable for the
#          PR-time eval-summary report.
# Author: HVE Core Team

#Requires -Version 7.0

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

        if ($hasScore -and $PSBoundParameters.ContainsKey('Threshold') -and $null -ne $Threshold) {
            $trialPassed = $scoreValue -ge [double]$Threshold
        }
        elseif ($gradeResult -and $gradeResult.PSObject.Properties['passed'] -and $null -ne $gradeResult.passed) {
            $trialPassed = [bool]$gradeResult.passed
        }
        if ($trialPassed) { $passed++ } else { $failed++ }

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
                    durationMs       = 0
                    trials           = 0
                }
            }
            $bucket = $perStimulus[$stimulusName]
            $bucket.trials++
            if ($trialPassed) { $bucket.assertionsPassed++ } else { $bucket.assertionsFailed++ }
            $bucket.durationMs += $trialWallMs
        }
    }

    return @{
        assertionsPassed = $passed
        assertionsFailed = $failed
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

    .OUTPUTS
    [hashtable] `@{ specPath; exitCode; runDir; assertionsPassed; assertionsFailed; durationMs; trials; resultsPath; perStimulus }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)][string]$SpecPath,
        [Parameter(Mandatory = $true)][string]$OutputDir,
        [Parameter(Mandatory = $true)][string]$Model,
        [string]$VallyCommand = 'vally',
        [string]$LogPath
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
    foreach ($line in $lines) { Write-Host $line }

    if ($LogPath) {
        $dir = Split-Path -Parent $LogPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $LogPath -Value $lines -Encoding utf8NoBOM
    }

    $runDir = Resolve-VallyRunDir -OutputDir $OutputDir
    $threshold = Get-VallySpecThreshold -SpecPath $SpecPath
    $aggregate = Read-VallyResultsJsonl -RunDir $runDir -Threshold $threshold

    $durationMs = if ($aggregate.durationMs -gt 0) {
        [int]$aggregate.durationMs
    }
    else {
        [int]$sw.ElapsedMilliseconds
    }

    return @{
        specPath         = $SpecPath
        exitCode         = $exitCode
        runDir           = $runDir
        assertionsPassed = $aggregate.assertionsPassed
        assertionsFailed = $aggregate.assertionsFailed
        durationMs       = $durationMs
        trials           = $aggregate.trials
        resultsPath      = $aggregate.resultsPath
        perStimulus      = $aggregate.perStimulus
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

Export-ModuleMember -Function @(
    'Resolve-VallyRunDir',
    'Read-VallyResultsJsonl',
    'Invoke-VallySpec',
    'Test-SpecInputModeration',
    'Test-SpecOutputModeration'
)
