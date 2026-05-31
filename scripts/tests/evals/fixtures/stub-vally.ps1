#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Stub vally CLI for unit tests covering Invoke-VallyEvals.ps1.
#
# Honors the `eval` subcommand and writes a deterministic results.jsonl under
# a timestamped run directory beneath --output-dir. Behavior is driven by
# environment variables so a single fixture script can model pass/fail/mixed
# scenarios:
#
#   STUB_VALLY_MODE            Default mode for any spec ('pass' when unset).
#   STUB_VALLY_MODES_JSON      Optional JSON object mapping spec basenames to
#                              modes; overrides STUB_VALLY_MODE per-spec.
#
# Supported modes:
#   pass   - two passing trials, exit 0
#   fail   - two failing trials, exit 1
#   mixed  - one pass, one fail, exit 0 (failed trial drives outer status)
#   empty  - no trials emitted, exit 0
#   crash  - prints an error and exits 99 (does not write results.jsonl)
#   per-stim - emits one trial per entry of STUB_VALLY_STIM_RESULTS_JSON
#              (JSON object {stimulusName: passedBool}); exit 1 only when
#              any record failed AND STUB_VALLY_FAIL_ON_ANY=1.

# Note: $args is the automatic parameter variable when no param block exists.

if ($args.Count -eq 0 -or $args[0] -ne 'eval') {
    Write-Error "stub-vally: only the 'eval' subcommand is supported."
    exit 64
}

$specPath  = $null
$outputDir = $null
for ($i = 1; $i -lt $args.Count; $i++) {
    switch ($args[$i]) {
        '--eval-spec'  { $specPath  = $args[++$i] }
        '--output-dir' { $outputDir = $args[++$i] }
        '--model'      { $null = $args[++$i] }
        default        { }
    }
}

if (-not $outputDir) {
    Write-Error "stub-vally: --output-dir is required."
    exit 65
}

$specBase = if ($specPath) { Split-Path -Leaf $specPath } else { '' }

$modes = @{}
if ($env:STUB_VALLY_MODES_JSON) {
    try {
        $modes = $env:STUB_VALLY_MODES_JSON | ConvertFrom-Json -AsHashtable
    }
    catch {
        Write-Error "stub-vally: STUB_VALLY_MODES_JSON could not be parsed as JSON object."
        exit 67
    }
}

$mode = if ($specBase -and $modes.ContainsKey($specBase)) {
    [string]$modes[$specBase]
}
elseif ($env:STUB_VALLY_MODE) {
    [string]$env:STUB_VALLY_MODE
}
else {
    'pass'
}

if ($mode -eq 'crash') {
    Write-Error "stub-vally: simulated crash"
    exit 99
}

$timestamp = (Get-Date).ToUniversalTime().ToString('yyyyMMddTHHmmssfffZ')
$runDir = Join-Path -Path $outputDir -ChildPath $timestamp
New-Item -ItemType Directory -Path $runDir -Force | Out-Null

function New-StubRecord {
    param(
        [string]$Name,
        [bool]$Passed,
        [int]$WallMs = 12
    )
    return [ordered]@{
        trajectory  = [ordered]@{
            stimulus = [ordered]@{ name = $Name }
            output   = "stub output for $Name"
            metrics  = [ordered]@{
                wallTimeMs = $WallMs
                tokenUsage = [ordered]@{ totalTokens = 7 }
            }
        }
        gradeResult = [ordered]@{
            passed  = $Passed
            score   = $(if ($Passed) { 1.0 } else { 0.0 })
            details = @()
        }
    }
}

$records = switch ($mode) {
    'pass'  { @((New-StubRecord -Name 'stim-1' -Passed $true),  (New-StubRecord -Name 'stim-2' -Passed $true)) }
    'fail'  { @((New-StubRecord -Name 'stim-1' -Passed $false), (New-StubRecord -Name 'stim-2' -Passed $false)) }
    'mixed' { @((New-StubRecord -Name 'stim-1' -Passed $true),  (New-StubRecord -Name 'stim-2' -Passed $false)) }
    'empty' { @() }
    'per-stim' {
        if (-not $env:STUB_VALLY_STIM_RESULTS_JSON) {
            Write-Error "stub-vally: per-stim mode requires STUB_VALLY_STIM_RESULTS_JSON."
            exit 68
        }
        try {
            $stimMap = $env:STUB_VALLY_STIM_RESULTS_JSON | ConvertFrom-Json -AsHashtable
        }
        catch {
            Write-Error "stub-vally: STUB_VALLY_STIM_RESULTS_JSON could not be parsed as JSON object."
            exit 69
        }
        $emitted = foreach ($key in $stimMap.Keys) {
            New-StubRecord -Name ([string]$key) -Passed ([bool]$stimMap[$key])
        }
        @($emitted)
    }
    default {
        Write-Error "stub-vally: unknown mode '$mode'"
        exit 66
    }
}

$resultsPath = Join-Path -Path $runDir -ChildPath 'results.jsonl'
$lines = foreach ($r in $records) { $r | ConvertTo-Json -Depth 10 -Compress }
Set-Content -LiteralPath $resultsPath -Value $lines -Encoding utf8NoBOM

Set-Content -LiteralPath (Join-Path $runDir 'eval-results.md') -Value "# stub eval ($mode)" -Encoding utf8NoBOM

if ($mode -eq 'fail') { exit 1 }
if ($mode -eq 'per-stim' -and $env:STUB_VALLY_FAIL_ON_ANY -eq '1') {
    foreach ($r in $records) {
        if (-not $r.gradeResult.passed) { exit 1 }
    }
}
exit 0
