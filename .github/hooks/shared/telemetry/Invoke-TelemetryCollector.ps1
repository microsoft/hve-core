#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

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

# The hook contract is that this script always answers with a continue signal:
# a silent hook stalls the agent turn. The answer is emitted from finally so
# every path below, including an early return, still produces it.
try {
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
    # Test-Path takes -LiteralPath throughout: these paths come from the
    # environment and from the repository, so a bracket in a directory name must
    # not be read as a wildcard and quietly report the path as missing.
    $Enabled = $env:HVE_TELEMETRY -eq '1'
    if (-not $Enabled) {
        $MarkerPath = Join-Path $RepoRoot '.hve-telemetry'
        $Enabled = Test-Path -LiteralPath $MarkerPath
    }
    if (-not $Enabled) {
        return
    }
    #endregion Opt-in gate

    # Require Python3 for JSON processing
    $Python = Get-Command python3 -ErrorAction SilentlyContinue
    if (-not $Python) {
        $Python = Get-Command python -ErrorAction SilentlyContinue
    }
    if (-not $Python) {
        Write-Warning 'HVE telemetry enabled but no python3 or python found; events will not be recorded'
        return
    }

    # Resolve the shared telemetry engine from the skill directory
    $CorePy = Join-Path $PSScriptRoot '_telemetry_core.py'

    if (-not (Test-Path -LiteralPath $CorePy)) {
        Write-Warning "Telemetry engine not found at $CorePy; events will not be recorded"
        return
    }

    # Nested 2-arg Join-Path: the 3-arg form needs PS 6+, and this hook can be
    # launched by a host that picks Windows PowerShell 5.1.
    $TelemetryDir = if ($env:HVE_TELEMETRY_DIR) { $env:HVE_TELEMETRY_DIR } else { Join-Path (Join-Path $RepoRoot '.copilot-tracking') 'telemetry' }
    $StackDir = Join-Path $TelemetryDir '.stacks'
    try {
        if (-not (Test-Path -LiteralPath $TelemetryDir)) {
            New-Item -ItemType Directory -Path $TelemetryDir -Force | Out-Null
        }
        if (-not (Test-Path -LiteralPath $StackDir)) {
            New-Item -ItemType Directory -Path $StackDir -Force | Out-Null
        }
    }
    catch {
        # An unwritable store is a telemetry failure, not a turn failure. The
        # engine below skips its own writes for the same reason.
        Write-Verbose "Telemetry directory unavailable: $_"
    }

    # Delegate all JSON processing to the shared Python telemetry engine.
    # The hook contract is raw process stdin, not a PowerShell object pipeline:
    # [CmdletBinding()] makes this an advanced script, which rejects pipeline input
    # it cannot bind to a parameter, leaving $input empty.
    # Decode explicitly as UTF-8: [Console]::In would use the OEM console codepage
    # under Windows PowerShell 5.1 and corrupt non-ASCII payload bytes.
    $RawInput = ''
    if ([Console]::IsInputRedirected) {
        $Reader = [IO.StreamReader]::new([Console]::OpenStandardInput(), [Text.UTF8Encoding]::new($false))
        try { $RawInput = $Reader.ReadToEnd() }
        finally { $Reader.Dispose() }
    }

    # Dump raw input for diagnostics (first 5 events only). This records hook
    # payloads verbatim, including the full prompt text and tool inputs such as
    # file contents and shell command strings, which can contain secrets. The
    # processed sessions-*.jsonl stream already provides the diagnostic signal,
    # so the verbatim dump is a separate explicit opt-in (off by default)
    # layered on top of the telemetry gate. See docs/customization/local-telemetry.md.
    if ($env:HVE_TELEMETRY_RAW -eq '1') {
        try {
            $RawLog = Join-Path $TelemetryDir 'raw-input.jsonl'
            $RawCount = 0
            if (Test-Path -LiteralPath $RawLog) {
                # Array subexpression: Get-Content returns a bare string for a
                # single-line file, whose .Count is 1 only by PS 3+ unified property.
                $RawCount = @(Get-Content -LiteralPath $RawLog).Count
            }
            if ($RawCount -lt 5) {
                # Not Add-Content -Encoding UTF8: that emits a BOM under Windows
                # PowerShell 5.1, which makes the first JSONL line unparseable.
                # Trim the inbound line ending and write LF so one event is one JSONL
                # record, as on bash; CRLF here would leave a blank line between records.
                [IO.File]::AppendAllText($RawLog, $RawInput.TrimEnd("`r", "`n") + "`n", [Text.UTF8Encoding]::new($false))
            }
        }
        catch {
            Write-Verbose "Raw telemetry capture failed: $_"
        }
    }

    $env:HVE_REPO_ROOT = $RepoRoot
    $env:HVE_TELEMETRY_DIR = $TelemetryDir
    # Windows PowerShell 5.1 defaults $OutputEncoding to ASCII, which flattens
    # every non-ASCII character to '?' when piping into a native process.
    $OutputEncoding = [Text.UTF8Encoding]::new($false)
    # Engine stderr is left unredirected so it reaches the host log, matching the
    # bash wrapper. Whether a non-zero exit throws depends on the host version,
    # and either way the finally below still returns continue.
    $RawInput | & $Python.Source $CorePy collect
}
catch {
    Write-Verbose "Telemetry collection error: $_"
}
finally {
    '{"continue":true}'
}
