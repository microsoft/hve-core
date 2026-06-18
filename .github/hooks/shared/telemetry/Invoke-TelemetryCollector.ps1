#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Copilot hook handler that delegates telemetry collection to the shared Python engine.
.DESCRIPTION
    Reads JSON from stdin for each hook lifecycle event, checks the opt-in gate,
    and delegates all processing to _telemetry_core.py. This thin wrapper keeps
    the collection logic in a single implementation (Python) shared with the bash
    hook entry point.
.NOTES
    Runs via: Copilot agent hook (stdin JSON, stdout JSON)
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

#region Resolve repo root
$RepoRoot = $env:HVE_REPO_ROOT
if (-not $RepoRoot -and (Get-Command git -ErrorAction SilentlyContinue)) {
    try { $RepoRoot = & git rev-parse --show-toplevel 2>$null } catch { $RepoRoot = $null }
}
if (-not $RepoRoot) {
    $RepoRoot = '.'
}
#endregion Resolve repo root

#region Opt-in gate
$Enabled = $env:HVE_TELEMETRY -eq '1'
if (-not $Enabled) {
    $MarkerPath = Join-Path $RepoRoot '.hve-telemetry'
    $Enabled = Test-Path $MarkerPath
}
if (-not $Enabled) {
    '{"continue":true}'
    return
}
#endregion Opt-in gate

# Require Python3 for JSON processing
$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $Python) {
    Write-Warning 'HVE telemetry enabled but python3 not found — events will not be recorded'
    '{"continue":true}'
    return
}

# Resolve the shared telemetry engine from the skill directory
$CorePy = Join-Path $PSScriptRoot '_telemetry_core.py'

if (-not (Test-Path $CorePy)) {
    Write-Warning "Telemetry engine not found at $CorePy — events will not be recorded"
    '{"continue":true}'
    return
}

$TelemetryDir = if ($env:HVE_TELEMETRY_DIR) { $env:HVE_TELEMETRY_DIR } else { Join-Path $RepoRoot '.copilot-tracking/telemetry' }
if (-not (Test-Path $TelemetryDir)) {
    New-Item -ItemType Directory -Path $TelemetryDir -Force | Out-Null
}

# Delegate all JSON processing to the shared Python telemetry engine
$RawInput = $input | Out-String
try {
    $env:HVE_REPO_ROOT = $RepoRoot
    $env:HVE_TELEMETRY_DIR = $TelemetryDir
    $RawInput | & $Python.Source $CorePy collect 2>$null
}
catch {
    Write-Verbose "Telemetry collection error: $_"
}

'{"continue":true}'
