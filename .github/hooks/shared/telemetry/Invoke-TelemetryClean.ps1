#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Removes telemetry artifacts written by the Copilot telemetry hooks.
.DESCRIPTION
    Delegates to the shared Python engine's clean mode. By default cleans this
    project's telemetry store; -AllDirs extends the cleanup to every registered
    project plus the user-level HVE home directory. This thin wrapper keeps the
    cleanup logic in a single implementation (Python) shared with the bash entry
    point clean-telemetry.sh.
.PARAMETER AllDirs
    Also clean every per-project telemetry directory recorded in the user-level
    registry, plus the generated launchers, report, and registry in the HVE home
    directory.
.PARAMETER Path
    Telemetry directory. Default: <repo>/.copilot-tracking/telemetry
.PARAMETER DryRun
    List what would be removed without deleting anything.
.PARAMETER Force
    Skip the confirmation prompt (required for non-interactive use).
.NOTES
    Runs via: pwsh Invoke-TelemetryClean.ps1
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$AllDirs,
    [string]$Path,
    [switch]$DryRun,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

#region Resolve repo root
$RepoRoot = $env:HVE_REPO_ROOT
if (-not $RepoRoot -and (Get-Command git -ErrorAction SilentlyContinue)) {
    try { $RepoRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null } catch { $RepoRoot = $null }
}
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
}
#endregion Resolve repo root

# Require Python3 for the shared telemetry engine
$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command python -ErrorAction SilentlyContinue
}
if (-not $Python) {
    Write-Error "'python3' is required but not installed"
    exit 1
}

# Resolve the shared telemetry engine from the skill directory
$CorePy = Join-Path $PSScriptRoot '_telemetry_core.py'
if (-not (Test-Path $CorePy)) {
    Write-Error "Telemetry engine not found: $CorePy"
    exit 1
}

$TelemetryDir = if ($Path) { $Path } else { Join-Path $RepoRoot '.copilot-tracking/telemetry' }

# Prompt before destructive deletion. Skipped on -DryRun (non-destructive) and
# bypassed with -Force (required for non-interactive use).
if (-not $DryRun -and -not $Force) {
    $scope = if ($AllDirs) {
        'ALL registered telemetry stores plus the user-level HVE home directory'
    } else {
        $TelemetryDir
    }
    if (-not $PSCmdlet.ShouldProcess($scope, 'Permanently remove telemetry artifacts')) {
        Write-Host 'Aborted.'
        exit 0
    }
}

# Build the clean-mode argument list mirroring the bash wrapper's flags.
$CliArgs = @('clean')
if ($AllDirs) { $CliArgs += '--all-dirs' }
if ($DryRun) { $CliArgs += '--dry-run' }

$env:HVE_TELEMETRY_DIR = $TelemetryDir
& $Python.Source $CorePy @CliArgs
