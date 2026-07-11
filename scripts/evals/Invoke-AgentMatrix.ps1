#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Runs the Vally `agent-behavior` suite per parent-agent slug and aggregates
    a matrix-style summary.

.DESCRIPTION
    Drives `npx vally eval --eval-spec evals/agent-behavior/eval.yaml --tag agent=<slug>` for either
    a curated set of slugs (`-Changed`) or the full inventory (`-All`).
    Emits one per-agent summary plus an aggregate `agent-matrix-summary.json`
    and applies a tier exit policy:

      - `pr`      : exit 0 always (advisory).
      - `nightly` : exit 1 when any agent's `overall` is `fail`; otherwise exit 0.

    `-WhatIf` (dry-run) enumerates the slugs that would be exercised, reports the
    planned `vally` command lines plus the per-slug `cost_tier` from AGENTS.yml,
    writes a dry-run summary to the output directory, and exits 0 without
    invoking any external command.

.PARAMETER All
    Run the full agent-behavior matrix using slugs from
    `evals/agent-behavior/AGENTS.yml`.

.PARAMETER Changed
    Explicit set of changed agent slugs (or paths) to evaluate. Paths are
    resolved to parent-agent slugs via `Get-AffectedAgentSlugs`. Mutually
    exclusive with `-All`.

.PARAMETER Tier
    Exit policy. `pr` (default) always exits 0; `nightly` exits 1 on any
    `overall: fail`.

.PARAMETER OutputDir
    Directory for per-agent summary JSON files and the aggregate
    `agent-matrix-summary.json`. Defaults to
    `<RepoRoot>/evals/results/agent-matrix/<yyyy-MM-dd>/`.

.PARAMETER Concurrency
    Reserved for parallel execution (WI-04). Currently runs sequentially;
    values greater than 1 produce a warning and fall back to 1.

.PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

.PARAMETER Model
    SDK model id passed to `vally eval --model`. Defaults to
    `gpt-5.6-luna`.

.EXAMPLE
    ./Invoke-AgentMatrix.ps1 -All -Tier nightly -WhatIf

    Lists every agent slug, prints planned `vally` commands and per-slug cost
    tiers, writes a dry-run summary, and exits 0.

.EXAMPLE
    npm run eval:agent:changed -- -WhatIf

    PR-tier advisory run filtered by git-changed agents.

.NOTES
    Runs via: npm run eval:agent / npm run eval:agent:matrix / npm run eval:agent:changed
#>

[CmdletBinding(SupportsShouldProcess = $true, DefaultParameterSetName = 'All')]
param(
    [Parameter(ParameterSetName = 'All', Mandatory = $false)]
    [switch]$All,

    [Parameter(ParameterSetName = 'Changed', Mandatory = $true)]
    [AllowEmptyCollection()]
    [string[]]$Changed,

    [Parameter(Mandatory = $false)]
    [ValidateSet('pr', 'nightly')]
    [string]$Tier = 'pr',

    [Parameter(Mandatory = $false)]
    [string]$OutputDir,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 32)]
    [int]$Concurrency = 1,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$Model = 'gpt-5.6-luna'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Import-YamlModule {
    [CmdletBinding()]
    param()

    if (Get-Module -Name 'powershell-yaml') { return }
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
        throw "Required module 'powershell-yaml' is not installed. Run 'Install-Module powershell-yaml -Scope CurrentUser' before invoking this script."
    }
    Import-Module powershell-yaml -ErrorAction Stop | Out-Null
}

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Hint)

    if ($Hint) { return (Resolve-Path -LiteralPath $Hint).Path }
    try {
        $root = (& git rev-parse --show-toplevel 2>$null).Trim()
        if ($LASTEXITCODE -eq 0 -and $root) { return $root }
    } catch {
        Write-Verbose "git rev-parse failed: $($_.Exception.Message)"
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
}

function Read-AgentInventory {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param([Parameter(Mandatory)] [string]$RepoRoot)

    $path = Join-Path $RepoRoot 'evals/agent-behavior/AGENTS.yml'
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Agent inventory not found at $path. Run scripts/evals/Build-AgentInventory.ps1 to generate."
    }

    Import-YamlModule
    $raw = [System.IO.File]::ReadAllText($path)
    $parsed = ConvertFrom-Yaml -Yaml $raw
    if (-not $parsed -or -not $parsed.ContainsKey('agents')) {
        throw "Agent inventory at $path is missing the 'agents:' collection."
    }

    $list = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($entry in $parsed['agents']) {
        if (-not $entry -or -not $entry.ContainsKey('slug')) { continue }
        $list.Add(@{
            slug      = [string]$entry['slug']
            path      = if ($entry.ContainsKey('path'))      { [string]$entry['path']      } else { '' }
            class     = if ($entry.ContainsKey('class'))     { [string]$entry['class']     } else { '' }
            cost_tier = if ($entry.ContainsKey('cost_tier')) { [string]$entry['cost_tier'] } else { 'unknown' }
        })
    }
    return $list
}

function Resolve-SlugSet {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)] [string]$RepoRoot,
        [Parameter(Mandatory)] [System.Collections.Generic.List[hashtable]]$Inventory,
        [Parameter(Mandatory)] [string]$ParameterSet,
        [string[]]$Changed
    )

    $known = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $Inventory) { [void]$known.Add($entry['slug']) }

    if ($ParameterSet -eq 'All') {
        return ,[string[]](@($Inventory | ForEach-Object { $_['slug'] } | Sort-Object -Unique))
    }

    if (-not $Changed -or $Changed.Count -eq 0) {
        return ,[string[]]@()
    }

    $resolved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $pathLike = [System.Collections.Generic.List[string]]::new()

    foreach ($item in $Changed) {
        if ([string]::IsNullOrWhiteSpace($item)) { continue }
        $trimmed = $item.Trim()
        if ($known.Contains($trimmed) -and ($trimmed -notmatch '[\\/]')) {
            [void]$resolved.Add($trimmed)
        } else {
            $pathLike.Add($trimmed)
        }
    }

    if ($pathLike.Count -gt 0) {
        $modulePath = Join-Path $PSScriptRoot 'Modules/AffectedAgents.psm1'
        if (-not (Test-Path -LiteralPath $modulePath)) {
            throw "Required module not found: $modulePath"
        }
        Import-Module $modulePath -Force | Out-Null
        $derived = Get-AffectedAgentSlugs -ChangedFiles $pathLike.ToArray() -RepoRoot $RepoRoot
        foreach ($slug in $derived) {
            if ($known.Contains($slug)) { [void]$resolved.Add($slug) }
        }
    }

    return ,[string[]](@($resolved | Sort-Object))
}

function Get-PlannedCommand {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$Slug,
        [Parameter(Mandatory)] [string]$Model
    )
    return "npx vally eval --eval-spec evals/agent-behavior/eval.yaml --tag agent=$Slug --model $Model"
}

function Resolve-NpxExecutable {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    # On Windows, `Get-Command npx` may resolve to `npx.ps1`, whose argument
    # forwarding is broken when invoked via the `&` call operator (it drops or
    # mangles dashed args and yields 'could not determine executable to run').
    # Prefer `npx.cmd` explicitly on Windows; fall back to plain `npx` elsewhere.
    if ($IsWindows) {
        $cmd = Get-Command 'npx.cmd' -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    $generic = Get-Command 'npx' -ErrorAction SilentlyContinue
    if ($generic) { return $generic.Source }
    throw "Could not locate the 'npx' executable on PATH."
}

function Invoke-VallyAgentRun {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [string]$Slug,
        [Parameter(Mandatory)] [string]$LogPath,
        [Parameter(Mandatory)] [string]$Model
    )

    $npx = Resolve-NpxExecutable
    $vallyArgs = @('vally', 'eval', '--eval-spec', 'evals/agent-behavior/eval.yaml', '--tag', "agent=$Slug", '--model', $Model)
    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = & $npx @vallyArgs 2>&1
        $code = $LASTEXITCODE
    }
    finally {
        [Console]::OutputEncoding = $prev
    }

    $lines = @($raw | ForEach-Object { $_.ToString() })
    foreach ($line in $lines) { Write-Host $line }

    if ($LogPath) {
        $dir = Split-Path -Parent $LogPath
        if ($dir -and -not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false -Confirm:$false | Out-Null
        }
        Set-Content -LiteralPath $LogPath -Value $lines -Encoding utf8NoBOM -WhatIf:$false -Confirm:$false
    }

    return @{ ExitCode = $code; Lines = $lines }
}

function Get-GraderStatusesFromLog {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]]$Lines)

    # Vally emits a per-eval Graders block of the form:
    #   Graders (2/3)
    #   ─────────────────────────────────────────
    #     ✔ field-vocab-present  Output matches pattern /(?i)(title|...)/
    #     ✘ tracking-file-write  Output does not match pattern /(?i)\.copilot-tracking/workitems/
    #     ✔ no-source-edit  Output does not match pattern /(?i)(\.cs|...)/
    #   <blank line>
    #   1 grader(s) failed.
    #
    # The legacy "grader X: pass" textual form is also tolerated for forward compatibility.
    $graders = [System.Collections.Generic.List[hashtable]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)

    $glyphRegex   = [regex]'^\s*(?<glyph>[\u2714\u2718])\s+(?<name>[\w\.\-:]+)\s+(?<message>.+?)\s*$'
    $legacyRegex  = [regex]'(?i)grader\s+["'']?(?<name>[\w\.\-:]+)["'']?\s*[:=\-]\s*(?<status>pass|fail|warn|skip)'
    $patternRegex = [regex]'(?<negation>does not )?match(?:es)? pattern\s+(?<pattern>/.+/)'
    # Vally colorizes its console output with ANSI SGR sequences; strip them so glyph/name parsing works.
    $ansiRegex    = [regex]"\x1B\[[0-9;?]*[ -/]*[@-~]"
    $inBlock = $false

    foreach ($rawLine in $Lines) {
        if ($null -eq $rawLine) { continue }
        $line = $ansiRegex.Replace([string]$rawLine, '')

        if ($line -match '^\s*Graders\s*\(') { $inBlock = $true; continue }
        if ($inBlock -and ($line -match '^\s*\d+\s+grader\(s\)\s+failed' -or [string]::IsNullOrWhiteSpace($line))) {
            $inBlock = $false
            continue
        }

        if ($inBlock) {
            $glyphMatch = $glyphRegex.Match($line)
            if ($glyphMatch.Success) {
                $name = $glyphMatch.Groups['name'].Value
                if (-not $seen.Add($name)) { continue }
                $status = if ($glyphMatch.Groups['glyph'].Value -eq [char]0x2714) { 'pass' } else { 'fail' }
                $message = $glyphMatch.Groups['message'].Value.Trim()
                $pattern = ''
                $patternMatch = $patternRegex.Match($message)
                if ($patternMatch.Success) { $pattern = $patternMatch.Groups['pattern'].Value }
                $graders.Add(@{
                    name    = $name
                    status  = $status
                    message = $message
                    pattern = $pattern
                })
                continue
            }
        }

        $legacyMatch = $legacyRegex.Match($line)
        if ($legacyMatch.Success) {
            $name = $legacyMatch.Groups['name'].Value
            if (-not $seen.Add($name)) { continue }
            $graders.Add(@{
                name    = $name
                status  = $legacyMatch.Groups['status'].Value.ToLowerInvariant()
                message = ''
                pattern = ''
            })
        }
    }
    return $graders
}

function Get-VallyOutputDirFromLog {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)] [AllowEmptyCollection()] [AllowEmptyString()] [string[]]$Lines)

    $regex = [regex]'(?im)^\s*Output\s+directory:\s*(?<dir>.+?)\s*$'
    foreach ($line in $Lines) {
        if ($null -eq $line) { continue }
        $m = $regex.Match($line)
        if ($m.Success) { return $m.Groups['dir'].Value.Trim() }
    }
    return ''
}

function Read-VallyTrajectoryDetails {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([Parameter(Mandatory)] [AllowEmptyString()] [string]$OutputDir)

    $empty = @{ stimulusPrompt = ''; output = ''; richGraders = @() }
    if (-not $OutputDir) { return $empty }
    $jsonlPath = Join-Path $OutputDir 'results.jsonl'
    if (-not (Test-Path -LiteralPath $jsonlPath -PathType Leaf)) { return $empty }

    try {
        $first = Get-Content -LiteralPath $jsonlPath -TotalCount 1 -ErrorAction Stop
        if (-not $first) { return $empty }
        $obj = $first | ConvertFrom-Json -Depth 60 -ErrorAction Stop
    } catch {
        Write-Verbose "Failed to parse vally JSONL at $jsonlPath`: $($_.Exception.Message)"
        return $empty
    }

    $stimPrompt = ''
    if ($obj.PSObject.Properties['trajectory'] -and $obj.trajectory `
        -and $obj.trajectory.PSObject.Properties['stimulus'] -and $obj.trajectory.stimulus `
        -and $obj.trajectory.stimulus.PSObject.Properties['prompt']) {
        $stimPrompt = [string]$obj.trajectory.stimulus.prompt
    }

    $output = ''
    if ($obj.PSObject.Properties['trajectory'] -and $obj.trajectory `
        -and $obj.trajectory.PSObject.Properties['output']) {
        $rawOutput = $obj.trajectory.output
        $output = if ($rawOutput -is [string]) { $rawOutput } else { ($rawOutput | ConvertTo-Json -Depth 12) }
    }

    $rich = [System.Collections.Generic.List[hashtable]]::new()
    $richPatternRegex = [regex]'(?<negation>does not )?match(?:es)? pattern\s+(?<pattern>/.+/)'
    if ($obj.PSObject.Properties['gradeResult'] -and $obj.gradeResult `
        -and $obj.gradeResult.PSObject.Properties['details'] -and $obj.gradeResult.details) {
        foreach ($d in @($obj.gradeResult.details)) {
            if (-not $d) { continue }
            $evidence = if ($d.PSObject.Properties['evidence']) { [string]$d.evidence } else { '' }
            $pattern = ''
            if ($evidence) {
                $pm = $richPatternRegex.Match($evidence)
                if ($pm.Success) { $pattern = $pm.Groups['pattern'].Value }
            }
            $rich.Add(@{
                name     = if ($d.PSObject.Properties['name'])     { [string]$d.name }     else { '' }
                status   = if ($d.PSObject.Properties['passed'])   { if ($d.passed) { 'pass' } else { 'fail' } } else { 'unknown' }
                evidence = $evidence
                pattern  = $pattern
                label    = if ($d.PSObject.Properties['label'])    { [string]$d.label }    else { '' }
                kind     = if ($d.PSObject.Properties['kind'])     { [string]$d.kind }     else { '' }
            })
        }
    }

    return @{
        stimulusPrompt = $stimPrompt
        output         = $output
        richGraders    = $rich.ToArray()
    }
}

function Merge-GraderDetails {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[hashtable]]$LogGraders,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]]$RichGraders
    )

    $merged = [System.Collections.Generic.List[hashtable]]::new()
    $richByName = @{}
    foreach ($r in $RichGraders) {
        if (-not $r) { continue }
        $rn = [string]$r['name']
        if ($rn) { $richByName[$rn] = $r }
    }

    foreach ($g in $LogGraders) {
        $name = [string]$g['name']
        $entry = @{
            name     = $name
            status   = [string]$g['status']
            message  = if ($g.ContainsKey('message')) { [string]$g['message'] } else { '' }
            pattern  = if ($g.ContainsKey('pattern')) { [string]$g['pattern'] } else { '' }
            evidence = ''
            label    = ''
            kind     = ''
        }
        if ($richByName.ContainsKey($name)) {
            $r = $richByName[$name]
            $entry['evidence'] = [string]$r['evidence']
            $entry['label']    = [string]$r['label']
            $entry['kind']     = [string]$r['kind']
            if (-not $entry['status']) { $entry['status'] = [string]$r['status'] }
            if (-not $entry['pattern'] -and $r.ContainsKey('pattern')) {
                $entry['pattern'] = [string]$r['pattern']
            }
        }
        $merged.Add($entry)
    }

    # Include rich-only graders that the log parser missed (defensive fallback).
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($e in $merged) { [void]$seen.Add($e['name']) }
    foreach ($name in $richByName.Keys) {
        if ($seen.Contains($name)) { continue }
        $r = $richByName[$name]
        $evidence = [string]$r['evidence']
        $merged.Add(@{
            name     = $name
            status   = [string]$r['status']
            message  = $evidence
            pattern  = if ($r.ContainsKey('pattern')) { [string]$r['pattern'] } else { '' }
            evidence = $evidence
            label    = [string]$r['label']
            kind     = [string]$r['kind']
        })
    }
    return $merged
}

function New-AgentSummary {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [hashtable]$AgentEntry,
        [Parameter(Mandatory)] [int]$ExitCode,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[hashtable]]$Graders,
        [Parameter(Mandatory)] [string]$LogPath,
        [string]$OutputDir = '',
        [string]$StimulusPrompt = '',
        [string]$Output = ''
    )

    $overall = if ($ExitCode -eq 0) { 'pass' } else { 'fail' }
    if ($overall -eq 'pass' -and $Graders.Count -gt 0) {
        foreach ($g in $Graders) {
            if ($g['status'] -eq 'fail') { $overall = 'fail'; break }
        }
    }

    $graderObjects = @($Graders | ForEach-Object {
        [ordered]@{
            name     = [string]$_['name']
            status   = [string]$_['status']
            message  = if ($_.ContainsKey('message'))  { [string]$_['message'] }  else { '' }
            pattern  = if ($_.ContainsKey('pattern'))  { [string]$_['pattern'] }  else { '' }
            evidence = if ($_.ContainsKey('evidence')) { [string]$_['evidence'] } else { '' }
            label    = if ($_.ContainsKey('label'))    { [string]$_['label'] }    else { '' }
            kind     = if ($_.ContainsKey('kind'))     { [string]$_['kind'] }     else { '' }
        }
    })

    return [ordered]@{
        slug           = [string]$AgentEntry['slug']
        class          = [string]$AgentEntry['class']
        cost_tier      = [string]$AgentEntry['cost_tier']
        graders        = $graderObjects
        overall        = $overall
        exitCode       = $ExitCode
        logPath        = $LogPath
        vallyOutputDir = $OutputDir
        stimulusPrompt = $StimulusPrompt
        output         = $Output
    }
}

function New-MatrixSummary {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [string]$Tier,
        [Parameter(Mandatory)] [string]$Mode,
        [Parameter(Mandatory)] [AllowEmptyCollection()] [System.Collections.Generic.List[hashtable]]$Results,
        [string[]]$PlannedCommands,
        [string]$Verdict
    )

    $failures = @($Results | Where-Object { $_['overall'] -eq 'fail' } | ForEach-Object { [string]$_['slug'] })
    $overall = if ($Verdict) { $Verdict } elseif ($failures.Count -gt 0) { 'fail' } else { 'pass' }

    return [ordered]@{
        generatedAt     = (Get-Date -AsUTC).ToString('yyyy-MM-ddTHH:mm:ssZ')
        tier            = $Tier
        mode            = $Mode
        agentCount      = $Results.Count
        overall         = $overall
        failures        = $failures
        results         = @($Results)
        plannedCommands = @($PlannedCommands)
    }
}

function Write-SummaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [object]$Summary,
        [Parameter(Mandatory)] [string]$Path
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false -Confirm:$false | Out-Null
    }
    $json = $Summary | ConvertTo-Json -Depth 12
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8NoBOM -WhatIf:$false -Confirm:$false
}

#endregion Helper Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $resolvedRoot = Resolve-RepoRoot -Hint $RepoRoot
        if ($Concurrency -gt 1) {
            Write-Warning "Concurrency > 1 reserved for WI-04; running sequentially."
            $Concurrency = 1
        }

        if (-not $OutputDir) {
            $dateStamp = (Get-Date -AsUTC).ToString('yyyy-MM-dd')
            $OutputDir = Join-Path $resolvedRoot "evals/results/agent-matrix/$dateStamp"
        }
        if (-not (Test-Path -LiteralPath $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force -WhatIf:$false -Confirm:$false | Out-Null
        }

        $inventory = Read-AgentInventory -RepoRoot $resolvedRoot
        $inventoryBySlug = @{}
        foreach ($entry in $inventory) { $inventoryBySlug[$entry['slug']] = $entry }

        $slugs = Resolve-SlugSet -RepoRoot $resolvedRoot -Inventory $inventory -ParameterSet $PSCmdlet.ParameterSetName -Changed $Changed

        $mode = $PSCmdlet.ParameterSetName.ToLowerInvariant()
        Write-Host "Agent matrix: mode=$mode tier=$Tier slug_count=$($slugs.Count)" -ForegroundColor Cyan
        Write-Host "   Output dir: $OutputDir" -ForegroundColor DarkGray

        $plannedCommands = @($slugs | ForEach-Object { Get-PlannedCommand -Slug $_ -Model $Model })

        $summaryPath = Join-Path $OutputDir 'agent-matrix-summary.json'

        if ($slugs.Count -eq 0) {
            Write-Host "No agent slugs resolved; nothing to evaluate." -ForegroundColor Yellow
            $emptyResults = [System.Collections.Generic.List[hashtable]]::new()
            $verdict = if ($WhatIfPreference) { 'dry-run' } else { 'pass' }
            $summary = New-MatrixSummary -Tier $Tier -Mode $mode -Results $emptyResults -PlannedCommands $plannedCommands -Verdict $verdict
            Write-SummaryJson -Summary $summary -Path $summaryPath
            Write-Host "Summary written: $summaryPath ($verdict)" -ForegroundColor Green
            exit 0
        }

        if ($WhatIfPreference) {
            Write-Host "Dry-run mode: skipping live vally invocations." -ForegroundColor Yellow
            $dryResults = [System.Collections.Generic.List[hashtable]]::new()
            foreach ($slug in $slugs) {
                $entry = $inventoryBySlug[$slug]
                $cmd = Get-PlannedCommand -Slug $slug -Model $Model
                Write-Host "   [$($entry['cost_tier'])] $cmd" -ForegroundColor DarkGray
                $dryResults.Add([ordered]@{
                    slug      = $slug
                    class     = [string]$entry['class']
                    cost_tier = [string]$entry['cost_tier']
                    graders   = @()
                    overall   = 'dry-run'
                    exitCode  = 0
                    logPath   = ''
                })
            }
            $summary = New-MatrixSummary -Tier $Tier -Mode $mode -Results $dryResults -PlannedCommands $plannedCommands -Verdict 'dry-run'
            Write-SummaryJson -Summary $summary -Path $summaryPath
            Write-Host "Dry-run summary written: $summaryPath" -ForegroundColor Green
            exit 0
        }

        $logsRoot = Join-Path $resolvedRoot 'logs/agent-matrix'
        $runId = (Get-Date -AsUTC).ToString('yyyyMMddTHHmmssfffZ')

        $results = [System.Collections.Generic.List[hashtable]]::new()
        foreach ($slug in $slugs) {
            $entry = $inventoryBySlug[$slug]
            $logPath = Join-Path $logsRoot "$slug-$runId.log"
            Write-Host "[$slug] running agent-behavior eval" -ForegroundColor Cyan
            $run = Invoke-VallyAgentRun -Slug $slug -LogPath $logPath -Model $Model
            $graders = Get-GraderStatusesFromLog -Lines $run['Lines']
            if ($null -eq $graders) { $graders = [System.Collections.Generic.List[hashtable]]::new() }

            $vallyOutDir = Get-VallyOutputDirFromLog -Lines $run['Lines']
            $details = Read-VallyTrajectoryDetails -OutputDir $vallyOutDir
            if ($details['richGraders'] -and $details['richGraders'].Count -gt 0) {
                $graders = Merge-GraderDetails -LogGraders $graders -RichGraders $details['richGraders']
            }

            $summary = New-AgentSummary -AgentEntry $entry -ExitCode $run['ExitCode'] -Graders $graders `
                -LogPath $logPath -OutputDir $vallyOutDir `
                -StimulusPrompt $details['stimulusPrompt'] -Output $details['output']

            $perAgentPath = Join-Path $OutputDir "$slug.json"
            Write-SummaryJson -Summary $summary -Path $perAgentPath
            $results.Add($summary)
        }

        $matrixSummary = New-MatrixSummary -Tier $Tier -Mode $mode -Results $results -PlannedCommands $plannedCommands
        Write-SummaryJson -Summary $matrixSummary -Path $summaryPath
        Write-Host "Summary written: $summaryPath ($($matrixSummary['overall']))" -ForegroundColor Cyan

        if ($Tier -eq 'pr') { exit 0 }
        if ($matrixSummary['overall'] -eq 'fail') {
            Write-Host "Nightly verdict: fail (failures: $($matrixSummary['failures'] -join ', '))" -ForegroundColor Red
            exit 1
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-AgentMatrix failed: $($_.Exception.Message)"
        exit 3
    }
}
#endregion Main Execution
