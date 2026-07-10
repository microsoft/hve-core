#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Generates a self-contained telemetry report from Copilot hook JSONL files.
.DESCRIPTION
    Native PowerShell counterpart to generate-telemetry-report.sh. Discovers the
    session files for a target date, embeds their contents into a copy of
    report.html, and writes a self-contained report.generated.html that renders
    automatically without drag & drop.

    Orchestration (file discovery, JSON embedding, template injection) is native
    PowerShell so Windows hosts need no bash. Token/model enrichment is delegated
    to the shared Python engine (_telemetry_core.py) via its aggregate-debug,
    aggregate-session, and list-dirs modes - the same modes the bash entry point
    uses - so the enrichment logic stays single-sourced across platforms. Python
    is optional: when absent, the report is produced without enrichment.
.PARAMETER Date
    Target date (yyyy-MM-dd). Default: today (UTC). Use 'all' to include every
    sessions-*.jsonl file.
.PARAMETER AllDirs
    Scan every per-project telemetry directory recorded in the user-level
    registry (~/.copilot/telemetry-dirs.txt) for a combined cross-project report.
.PARAMETER Path
    Telemetry directory. Default: <repo>/.copilot-tracking/telemetry
.PARAMETER DebugLog
    Optional debug log JSONL (e.g. main.jsonl) for token data. When omitted, VS
    Code debug logs are auto-discovered and the precise model version plus token
    data are joined in by session id.
.PARAMETER Output
    Output path. Default: <telemetry dir>/report.generated.html
.PARAMETER Open
    Open the generated report in the default browser.
.NOTES
    Runs via: pwsh Invoke-TelemetryReport.ps1
#>
[CmdletBinding()]
param(
    [Alias('d')]
    [string]$Date,
    [Alias('a')]
    [switch]$AllDirs,
    [Alias('p')]
    [string]$Path,
    [Alias('l')]
    [string]$DebugLog,
    [Alias('o')]
    [string]$Output,
    [switch]$Open
)

$ErrorActionPreference = 'Stop'

$TemplatePath = Join-Path $PSScriptRoot 'report.html'
$CorePy = Join-Path $PSScriptRoot '_telemetry_core.py'

#region Resolve repo root
$RepoRoot = $env:HVE_REPO_ROOT
if (-not $RepoRoot -and (Get-Command git -ErrorAction SilentlyContinue)) {
    try { $RepoRoot = & git -C $PSScriptRoot rev-parse --show-toplevel 2>$null } catch { $RepoRoot = $null }
}
if (-not $RepoRoot) {
    $RepoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
}
#endregion Resolve repo root

# Python enables best-effort enrichment only; the report works without it.
$Python = Get-Command python3 -ErrorAction SilentlyContinue
if (-not $Python) {
    $Python = Get-Command python -ErrorAction SilentlyContinue
}

# Emit the user-level registry of per-project telemetry directories (one path
# per line). Used by -AllDirs for cross-project reports. Empty without Python.
function Get-RegistryDir {
    if (-not $Python) { return @() }
    try {
        $lines = & $Python.Source $CorePy list-dirs 2>$null
        if ($LASTEXITCODE -eq 0 -and $lines) {
            return @($lines | Where-Object { $_ -and $_.Trim() })
        }
    } catch {
        Write-Verbose "Registry lookup failed; continuing without cross-project dirs: $_"
    }
    return @()
}

# Best-effort enrichment: extract llm_request events (precise model, token, and
# duration data) from VS Code debug logs, scoped to the supplied hook files.
# Returns $true when matching events were written to $OutFile.
function Invoke-AggregateDebug {
    param([string]$OutFile, [string[]]$HookFile)
    if (-not $Python) { return $false }
    & $Python.Source $CorePy aggregate-debug $OutFile @HookFile 2>$null
    return ($LASTEXITCODE -eq 0)
}

# Enrichment from CLI session state: produces llm_request-compatible events so
# CLI sessions without VS Code debug logs still show model/token/duration data.
function Invoke-AggregateSession {
    param([string]$OutFile, [string[]]$HookFile)
    if (-not $Python) { return $false }
    & $Python.Source $CorePy aggregate-session $OutFile @HookFile 2>$null
    return ($LASTEXITCODE -eq 0)
}

if (-not (Test-Path -LiteralPath $TemplatePath)) {
    Write-Error "Template not found: $TemplatePath"
    exit 1
}

$TargetDate = if ($Date) { $Date } else { (Get-Date).ToUniversalTime().ToString('yyyy-MM-dd') }
$TelemetryPath = if ($Path) { $Path } else { Join-Path $RepoRoot '.copilot-tracking/telemetry' }
$OutputPath = if ($Output) { $Output } else { Join-Path $TelemetryPath 'report.generated.html' }

# Determine which telemetry directories to scan. With -AllDirs, prepend every
# directory recorded in the user-level registry (cross-project view).
$SearchDirs = [System.Collections.Generic.List[string]]::new()
if ($AllDirs) {
    foreach ($d in (Get-RegistryDir)) { $SearchDirs.Add($d) }
}
$SearchDirs.Add($TelemetryPath)

# Collect session files for the target date across the chosen directories,
# de-duplicating directories that appear more than once.
$Pattern = if ($TargetDate -eq 'all') { 'sessions-*.jsonl' } else { "sessions-$TargetDate.jsonl" }
$Files = [System.Collections.Generic.List[string]]::new()
$SeenDirs = [System.Collections.Generic.HashSet[string]]::new()
foreach ($dir in $SearchDirs) {
    if (-not $dir -or -not $SeenDirs.Add($dir)) { continue }
    if (-not (Test-Path -LiteralPath $dir -PathType Container)) { continue }
    Get-ChildItem -LiteralPath $dir -Filter $Pattern -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { $Files.Add($_.FullName) }
}

# Temp files for enrichment payloads; cleaned up on exit.
$TmpDir = $null
try {
    if ($DebugLog) {
        if (-not (Test-Path -LiteralPath $DebugLog)) {
            Write-Error "Debug log not found: $DebugLog"
            exit 1
        }
        $Files.Add((Resolve-Path -LiteralPath $DebugLog).Path)
    } elseif ($Files.Count -gt 0) {
        # Auto-enrich with precise model + token data from VS Code debug logs and
        # CLI session state, scoped to the sessions already collected.
        $TmpDir = Join-Path ([System.IO.Path]::GetTempPath()) ([System.Guid]::NewGuid().ToString())
        New-Item -ItemType Directory -Path $TmpDir -Force | Out-Null

        $DebugAgg = Join-Path $TmpDir 'debug-llm-requests.jsonl'
        if (Invoke-AggregateDebug -OutFile $DebugAgg -HookFile $Files.ToArray()) {
            $Files.Add($DebugAgg)
        }

        $CliAgg = Join-Path $TmpDir 'cli-session-state.jsonl'
        if (Invoke-AggregateSession -OutFile $CliAgg -HookFile $Files.ToArray()) {
            $Files.Add($CliAgg)
        }
    }

    if ($Files.Count -eq 0) {
        Write-Warning "No telemetry files found in '$TelemetryPath' for date '$TargetDate'."
        exit 0
    }

    # Build a JSON array of {name, content} objects. ConvertTo-Json escapes '<'
    # to \u003c, so no literal </script> survives in the embedded text; the
    # explicit </ neutralization is a defense-in-depth backstop. The HTML loader
    # decodes both forms via JSON.parse.
    $Objects = foreach ($f in $Files) {
        $content = Get-Content -LiteralPath $f -Raw
        if ($null -eq $content) { $content = '' }
        [PSCustomObject]@{ name = (Split-Path -Leaf $f); content = $content }
    }
    $Json = @($Objects) | ConvertTo-Json -Depth 10 -Compress -AsArray
    $Data = $Json -replace '</', '<\/'

    # Inject the data into the single-line embeddedData script element. The whole
    # matching line is replaced, mirroring the bash awk substitution.
    $TagOpen = '<script id="embeddedData" type="application/json">'
    $TagClose = '</script>'
    $Lines = (Get-Content -LiteralPath $TemplatePath -Raw) -split "`n"
    $Builder = [System.Text.StringBuilder]::new()
    $Injected = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if (-not $Injected -and $Lines[$i].Contains('id="embeddedData"')) {
            [void]$Builder.Append($TagOpen).Append($Data).Append($TagClose)
            $Injected = $true
        } else {
            [void]$Builder.Append($Lines[$i])
        }
        if ($i -lt $Lines.Count - 1) { [void]$Builder.Append("`n") }
    }

    $OutDir = Split-Path -Parent $OutputPath
    if ($OutDir -and -not (Test-Path -LiteralPath $OutDir)) {
        New-Item -ItemType Directory -Path $OutDir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($OutputPath, $Builder.ToString())

    Write-Host "Wrote self-contained report: $OutputPath"
    $Names = ($Files | ForEach-Object { Split-Path -Leaf $_ }) -join ', '
    Write-Host ("Embedded {0} file(s): {1}" -f $Files.Count, $Names)

    if ($Open) {
        if ($IsWindows) {
            Start-Process $OutputPath
        } elseif ($IsMacOS -and (Get-Command open -ErrorAction SilentlyContinue)) {
            & open $OutputPath
        } elseif (Get-Command xdg-open -ErrorAction SilentlyContinue) {
            & xdg-open $OutputPath
        }
    }
} finally {
    if ($TmpDir -and (Test-Path -LiteralPath $TmpDir)) {
        Remove-Item -LiteralPath $TmpDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
