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
    Telemetry directory. Scopes the cleanup to this directory alone, overriding
    -AllDirs. Default: <repo>/.copilot-tracking/telemetry
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
# Match the collector and anchor on the caller's workspace: the script itself
# may live outside the repo it cleans, so its location says nothing.
# Only needed to build the default telemetry path; an explicit -Path makes the
# whole lookup unnecessary, including the git subprocess.
if (-not $Path) {
    $RepoRoot = $env:HVE_REPO_ROOT
    if (-not $RepoRoot -and (Get-Command git -ErrorAction SilentlyContinue)) {
        try { $RepoRoot = & git rev-parse --show-toplevel 2>$null } catch { $RepoRoot = $null }
    }
    if (-not $RepoRoot) {
        # ProviderPath, not .Path: the latter is PowerShell-qualified ('Work:\',
        # 'HKLM:\SOFTWARE'). A non-filesystem provider survives this as a path with
        # no drive qualifier, which the guard below rejects.
        $RepoRoot = $PWD.ProviderPath
    }
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

$TelemetryDir = if ($Path) { $Path } else { Join-Path $RepoRoot '.copilot-tracking' 'telemetry' }

# Hand Python a native absolute path. -Path may be relative or on a PSDrive, and
# PowerShell does not sync [Environment]::CurrentDirectory with Set-Location, so
# the child process would resolve a relative path against a different directory
# than the one shown in the confirmation prompt below. Guarding the resolved path
# covers both branches: a non-filesystem location leaves a drive-less path
# ('HKEY_LOCAL_MACHINE\SOFTWARE\...') that Python would silently take as relative
# to its own working directory and delete from there.
$Provider = $null
$TelemetryDir = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath(
    $TelemetryDir, [ref]$Provider, [ref]$null)
if ($Provider.Name -ne 'FileSystem') {
    Write-Error "Telemetry path resolved to '$TelemetryDir' on the $($Provider.Name) provider from location '$($PWD.Path)'; re-run from a filesystem directory, pass an absolute -Path, or set HVE_REPO_ROOT."
    exit 1
}

# An explicit -Path narrows the scope. The generated launcher always passes
# -AllDirs, so announce the override rather than silently widening or dropping
# a destructive scope flag.
$UseAllDirs = [bool]$AllDirs -and -not $Path
if ($AllDirs -and $Path) {
    Write-Warning "Ignoring -AllDirs because -Path was given; scope is '$TelemetryDir'."
}

# Prompt before destructive deletion. Skipped on -DryRun (non-destructive) and
# bypassed with -Force (required for non-interactive use).
if (-not $DryRun -and -not $Force) {
    $scope = if ($UseAllDirs) {
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
if ($UseAllDirs) { $CliArgs += '--all-dirs' }
if ($DryRun) { $CliArgs += '--dry-run' }

# Scope the variable to this call, as the bash wrapper's prefix assignment does:
# leaking it would silently redirect the collector and report scripts for the
# rest of the session.
$PreviousTelemetryDir = $env:HVE_TELEMETRY_DIR
$env:HVE_TELEMETRY_DIR = $TelemetryDir
try {
    & $Python.Source $CorePy @CliArgs
}
finally {
    $env:HVE_TELEMETRY_DIR = $PreviousTelemetryDir
}
