#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Renders a self-contained HTML matrix dashboard for the per-agent
    `agent-behavior` eval suite (one row per parent agent).

.DESCRIPTION
    Consumes `agent-matrix-summary.json` (produced by
    `scripts/evals/Invoke-AgentMatrix.ps1`) along with the per-slug
    `<slug>.json` files in the same dated folder under
    `evals/results/agent-matrix/<YYYY-MM-DD>/`, the agent inventory
    `evals/agent-behavior/AGENTS.yml`, and (when present) the surface
    signature files under `evals/baseline-equivalence/surface-signatures/`,
    then writes a single offline HTML file with a 50-row matrix.

    Columns:
      * Agent slug
      * Functional verdict (pass | fail | dry-run | unknown)
      * Surface signature (present | missing)
      * Equivalence (placeholder; n/a until per-agent equivalence is wired)
      * Last functional pass date (scanned across prior dated folders)

    Cells link to the per-agent `<slug>.json` summary in the same dated
    folder so reviewers can drill into grader detail.

.PARAMETER RepoRoot
    Optional repository root. Defaults to `git rev-parse --show-toplevel`,
    falling back to the inferred repo root from this script's location.

.PARAMETER SummaryPath
    Optional explicit path to `agent-matrix-summary.json`. When omitted, the
    most recent dated folder under `evals/results/agent-matrix/` is used.

.PARAMETER AgentMatrixRoot
    Optional override for the dated-folder root. Defaults to
    `<RepoRoot>/evals/results/agent-matrix`.

.PARAMETER SurfaceSignaturesRoot
    Optional override for the surface signatures root. Defaults to
    `<RepoRoot>/evals/baseline-equivalence/surface-signatures`.

.PARAMETER InventoryPath
    Optional override for the agent inventory. Defaults to
    `<RepoRoot>/evals/agent-behavior/AGENTS.yml`.

.PARAMETER OutPath
    Optional output HTML path. Defaults to
    `<RepoRoot>/logs/agent-matrix-dashboard.html`.

.PARAMETER Open
    When set, attempts to open the generated HTML in the default browser.

.EXAMPLE
    pwsh -NoProfile -File scripts/evals/New-AgentMatrixDashboard.ps1

    Renders the dashboard for the most recent dated agent-matrix run.

.EXAMPLE
    pwsh -NoProfile -File scripts/evals/New-AgentMatrixDashboard.ps1 `
        -SummaryPath evals/results/agent-matrix/2026-05-25/agent-matrix-summary.json `
        -OutPath logs/agent-matrix-dashboard.html

    Renders the dashboard for a specific dated run.
#>

[CmdletBinding()]
param(
    [string]$RepoRoot,
    [string]$SummaryPath,
    [string]$AgentMatrixRoot,
    [string]$SurfaceSignaturesRoot,
    [string]$InventoryPath,
    [string]$OutPath,
    [switch]$Open
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'lib/EquivalenceParsing.psm1') -Force

function Resolve-DashboardRepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Hint)

    if ($Hint) { return (Resolve-Path -LiteralPath $Hint).ProviderPath }
    try {
        $root = (& git rev-parse --show-toplevel 2>$null)
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($root)) {
            return $root.Trim()
        }
    }
    catch {
        Write-Verbose "git rev-parse failed: $($_.Exception.Message)"
    }
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).ProviderPath
}

function Get-LatestSummaryPath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string]$AgentMatrixRoot
    )

    if (-not (Test-Path -LiteralPath $AgentMatrixRoot -PathType Container)) {
        throw "Agent matrix root not found: $AgentMatrixRoot"
    }

    $dated = Get-ChildItem -LiteralPath $AgentMatrixRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object Name -Descending

    foreach ($dir in $dated) {
        $candidate = Join-Path $dir.FullName 'agent-matrix-summary.json'
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }

    throw "No agent-matrix-summary.json found under $AgentMatrixRoot. Run scripts/evals/Invoke-AgentMatrix.ps1 first."
}

function Read-AgentSlugInventory {
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param([Parameter(Mandatory)] [string]$Path)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Agent inventory not found: $Path"
    }
    if (-not (Get-Module -Name 'powershell-yaml')) {
        if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
            throw "Required module 'powershell-yaml' is not installed."
        }
        Import-Module powershell-yaml -ErrorAction Stop | Out-Null
    }

    $parsed = ConvertFrom-Yaml -Yaml ([System.IO.File]::ReadAllText($Path))
    if (-not $parsed -or -not $parsed.ContainsKey('agents')) {
        throw "Agent inventory at $Path is missing the 'agents:' collection."
    }

    $list = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($entry in $parsed['agents']) {
        if (-not $entry -or -not $entry.ContainsKey('slug')) { continue }
        $list.Add(@{
            slug      = [string]$entry['slug']
            class     = if ($entry.ContainsKey('class'))     { [string]$entry['class']     } else { '' }
            cost_tier = if ($entry.ContainsKey('cost_tier')) { [string]$entry['cost_tier'] } else { 'unknown' }
        })
    }
    return $list
}

function Get-LastPassDateBySlug {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)] [string]$AgentMatrixRoot
    )

    $result = @{}
    if (-not (Test-Path -LiteralPath $AgentMatrixRoot -PathType Container)) { return $result }

    $dated = Get-ChildItem -LiteralPath $AgentMatrixRoot -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match '^\d{4}-\d{2}-\d{2}$' } |
        Sort-Object Name -Descending

    foreach ($dir in $dated) {
        $perAgent = Get-ChildItem -LiteralPath $dir.FullName -Filter '*.json' -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Name -ne 'agent-matrix-summary.json' }
        foreach ($file in $perAgent) {
            $slug = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            if ($result.ContainsKey($slug)) { continue }
            try {
                $obj = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json
                if ($obj.PSObject.Properties['overall'] -and $obj.overall -eq 'pass') {
                    $result[$slug] = $dir.Name
                }
            }
            catch {
                Write-Verbose "Failed to read $($file.FullName): $($_.Exception.Message)"
            }
        }
    }
    return $result
}

function ConvertTo-AgentMatrixRows {
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [Parameter(Mandatory)] [System.Collections.Generic.List[hashtable]]$Inventory,
        [Parameter(Mandatory)] $Summary,
        [Parameter(Mandatory)] [string]$SummaryDir,
        [Parameter(Mandatory)] [string]$SurfaceSignaturesRoot,
        [Parameter(Mandatory)] [hashtable]$LastPassBySlug
    )

    $bySlug = @{}
    if ($Summary -and $Summary.PSObject.Properties['results']) {
        foreach ($row in @($Summary.results)) {
            if ($row -and $row.PSObject.Properties['slug']) {
                $bySlug[[string]$row.slug] = $row
            }
        }
    }

    $rows = New-Object System.Collections.Generic.List[object]
    foreach ($entry in $Inventory) {
        $slug = $entry['slug']
        $row = if ($bySlug.ContainsKey($slug)) { $bySlug[$slug] } else { $null }

        $functional = if ($row -and $row.PSObject.Properties['overall']) { [string]$row.overall } else { 'unknown' }
        $exitCode   = if ($row -and $row.PSObject.Properties['exitCode']) { [int]$row.exitCode } else { -1 }
        $logPath    = if ($row -and $row.PSObject.Properties['logPath']) { [string]$row.logPath } else { '' }

        $graders = New-Object System.Collections.Generic.List[hashtable]
        if ($row -and $row.PSObject.Properties['graders'] -and $row.graders) {
            foreach ($g in @($row.graders)) {
                if (-not $g) { continue }
                $gName     = if ($g.PSObject.Properties['name'])     { [string]$g.name }     else { '' }
                $gStatus   = if ($g.PSObject.Properties['status'])   { [string]$g.status }   else { 'unknown' }
                $gMessage  = if ($g.PSObject.Properties['message'])  { [string]$g.message }  else { '' }
                $gPattern  = if ($g.PSObject.Properties['pattern'])  { [string]$g.pattern }  else { '' }
                $gEvidence = if ($g.PSObject.Properties['evidence']) { [string]$g.evidence } else { '' }
                $gKind     = if ($g.PSObject.Properties['kind'])     { [string]$g.kind }     else { '' }
                $gLabel    = if ($g.PSObject.Properties['label'])    { [string]$g.label }    else { '' }
                $graders.Add(@{
                    name     = $gName
                    status   = $gStatus
                    message  = $gMessage
                    pattern  = $gPattern
                    evidence = $gEvidence
                    kind     = $gKind
                    label    = $gLabel
                })
            }
        }

        $stimulusPrompt = if ($row -and $row.PSObject.Properties['stimulusPrompt']) { [string]$row.stimulusPrompt } else { '' }
        $agentOutput    = if ($row -and $row.PSObject.Properties['output'])         { [string]$row.output }         else { '' }
        $vallyOutputDir = if ($row -and $row.PSObject.Properties['vallyOutputDir']) { [string]$row.vallyOutputDir } else { '' }

        $perAgentRel = "$slug.json"
        $perAgentExists = Test-Path -LiteralPath (Join-Path $SummaryDir $perAgentRel) -PathType Leaf

        $surfacePath = Join-Path $SurfaceSignaturesRoot "$slug.yml"
        $surface = if (Test-Path -LiteralPath $surfacePath -PathType Leaf) { 'present' } else { 'missing' }

        $lastPass = if ($LastPassBySlug.ContainsKey($slug)) { $LastPassBySlug[$slug] } else { '' }

        $rows.Add([ordered]@{
            slug           = $slug
            class          = [string]$entry['class']
            cost_tier      = [string]$entry['cost_tier']
            functional     = $functional
            exitCode       = $exitCode
            surface        = $surface
            equivalence    = 'n/a'
            lastPass       = $lastPass
            perAgentHref   = if ($perAgentExists) { $perAgentRel } else { '' }
            logPath        = $logPath
            graders        = $graders.ToArray()
            stimulusPrompt = $stimulusPrompt
            output         = $agentOutput
            vallyOutputDir = $vallyOutputDir
        })
    }
    return , $rows.ToArray()
}

function ConvertTo-AgentMatrixHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [object[]]$Rows,
        [Parameter(Mandatory)] $Summary,
        [Parameter(Mandatory)] [string]$DateLabel
    )

    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $totalAgents = $Rows.Count
    $passCount = @($Rows | Where-Object { $_.functional -eq 'pass' }).Count
    $failCount = @($Rows | Where-Object { $_.functional -eq 'fail' }).Count
    $unknownCount = @($Rows | Where-Object { $_.functional -eq 'unknown' }).Count
    $dryRunCount = @($Rows | Where-Object { $_.functional -eq 'dry-run' }).Count
    $surfacePresent = @($Rows | Where-Object { $_.surface -eq 'present' }).Count

    $tier = if ($Summary -and $Summary.PSObject.Properties['tier']) { [string]$Summary.tier } else { 'unknown' }
    $mode = if ($Summary -and $Summary.PSObject.Properties['mode']) { [string]$Summary.mode } else { 'unknown' }
    $overall = if ($Summary -and $Summary.PSObject.Properties['overall']) { [string]$Summary.overall } else { 'unknown' }

    $uniqueClasses = @($Rows | ForEach-Object { $_.class } | Where-Object { $_ } | Sort-Object -Unique)
    $uniqueTiers   = @($Rows | ForEach-Object { $_.cost_tier } | Where-Object { $_ } | Sort-Object -Unique)
    # Count failing grader occurrences across rows (de-duped within a row) so the dropdown can
    # be ordered by frequency desc and labels can carry an occurrence count.
    $failingGraderCounts = @{}
    foreach ($r in $Rows) {
        $perRowNames = @(
            $r.graders |
                Where-Object { $_ -and $_.status -eq 'fail' -and $_.name } |
                ForEach-Object { ([string]$_.name).ToLowerInvariant() } |
                Sort-Object -Unique
        )
        foreach ($n in $perRowNames) {
            if ($failingGraderCounts.ContainsKey($n)) {
                $failingGraderCounts[$n] = [int]$failingGraderCounts[$n] + 1
            } else {
                $failingGraderCounts[$n] = 1
            }
        }
    }
    $failingGraderEntries = @(
        $failingGraderCounts.GetEnumerator() |
            Sort-Object @{ Expression = 'Value'; Descending = $true }, @{ Expression = 'Key'; Descending = $false } |
            ForEach-Object { [pscustomobject]@{ Name = [string]$_.Key; Count = [int]$_.Value } }
    )

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!doctype html>')
    [void]$sb.AppendLine('<html lang="en">')
    [void]$sb.AppendLine('<head>')
    [void]$sb.AppendLine('<meta charset="utf-8">')
    [void]$sb.AppendLine("<title>Per-Agent Matrix Dashboard &mdash; $(Edit-HtmlEscape $DateLabel)</title>")
    [void]$sb.AppendLine('<style>')
    [void]$sb.AppendLine(@'
:root { color-scheme: light dark; }
body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; margin: 0; padding: 1rem; }
header { border-bottom: 1px solid #888; padding-bottom: 0.5rem; margin-bottom: 1rem; }
header h1 { margin: 0 0 0.25rem 0; font-size: 1.4rem; }
.meta { font-size: 0.85rem; color: #666; }
.totals { display: flex; gap: 1.5rem; margin-top: 0.5rem; flex-wrap: wrap; }
.totals div { font-size: 0.9rem; }
.totals strong { font-size: 1.1rem; }
.banner { padding: 0.75rem 1rem; margin: 1rem 0; border-radius: 4px; font-weight: bold; }
.banner-dry-run { background: #fff3cd; color: #614500; border: 1px solid #ffc107; }
.failures-panel { background: #fdecea; color: #5b1410; border: 1px solid #f5c2c0; padding: 0.75rem 1rem; margin: 1rem 0; border-radius: 4px; }
.failures-panel h2 { margin: 0 0 0.5rem 0; font-size: 1.05rem; }
.failures-panel ul { margin: 0; padding-left: 1.25rem; }
.controls { display: flex; gap: 1rem; margin: 1rem 0 0.5rem 0; flex-wrap: wrap; align-items: center; }
.controls label { font-size: 0.85rem; }
.controls input[type="search"] { padding: 0.25rem 0.5rem; font-size: 0.9rem; min-width: 16rem; }
.controls select { padding: 0.25rem; font-size: 0.9rem; }
.controls fieldset { border: 1px solid #ccc; padding: 0.25rem 0.5rem; }
.controls fieldset legend { font-size: 0.8rem; padding: 0 0.25rem; }
table { border-collapse: collapse; width: 100%; font-size: 0.85rem; margin-top: 0.5rem; }
th, td { border: 1px solid #ccc; padding: 0.35rem 0.5rem; text-align: left; vertical-align: top; }
th { background: #f0f0f0; position: sticky; top: 0; }
th[data-sort-key] { cursor: pointer; user-select: none; }
th[data-sort-key]::after { content: ' \2195'; opacity: 0.4; font-size: 0.75rem; }
th[data-sort-active="asc"]::after { content: ' \25B2'; opacity: 1; }
th[data-sort-active="desc"]::after { content: ' \25BC'; opacity: 1; }
td.slug { font-family: ui-monospace, Menlo, Consolas, monospace; }
.toggle { background: none; border: 1px solid #888; border-radius: 3px; cursor: pointer; padding: 0 0.4rem; margin-right: 0.4rem; font-family: inherit; font-size: 0.85rem; }
.pass { color: #0a7d28; font-weight: bold; }
.fail { color: #b30000; font-weight: bold; }
.unknown { color: #777; }
.dry-run { color: #b8860b; font-weight: bold; }
.present { color: #0a7d28; }
.missing { color: #b30000; }
.na { color: #777; font-style: italic; }
tr.drill { display: none; }
tr.drill.open { display: table-row; }
tr.drill > td { background: #fafafa; padding: 0.5rem 1rem; }
.drill-graders { width: 100%; margin-top: 0.25rem; table-layout: fixed; }
.drill-graders th, .drill-graders td { font-size: 0.8rem; padding: 0.2rem 0.4rem; word-break: break-word; vertical-align: top; }
.drill-graders col.col-grader { width: 12rem; }
.drill-graders col.col-status { width: 5rem; }
.drill-graders col.col-message { width: 16rem; }
.drill-graders col.col-pattern { width: 16rem; }
.drill-graders code { font-family: ui-monospace, Menlo, Consolas, monospace; font-size: 0.78rem; }
.drill-meta { font-size: 0.8rem; color: #444; margin-bottom: 0.25rem; }
.drill-empty { font-style: italic; color: #777; }
.drill-block { margin-top: 0.5rem; }
.drill-block > summary { cursor: pointer; font-size: 0.85rem; font-weight: 600; padding: 0.2rem 0; }
.drill-block > pre { background: #f5f5f5; border: 1px solid #ddd; border-radius: 3px; padding: 0.5rem; font-size: 0.78rem; max-height: 24rem; overflow: auto; white-space: pre-wrap; word-break: break-word; }
@media (prefers-color-scheme: dark) {
  .drill-block > pre { background: #161616; border-color: #333; }
}
@media (prefers-color-scheme: dark) {
  th { background: #2a2a2a; }
  .meta, .drill-meta { color: #aaa; }
  tr.drill > td { background: #1f1f1f; }
  .banner-dry-run { background: #3a3206; color: #ffd966; border-color: #b8860b; }
  .failures-panel { background: #3a1410; color: #ffb3b0; border-color: #b30000; }
}
'@)
    [void]$sb.AppendLine('</style>')
    [void]$sb.AppendLine('</head>')
    [void]$sb.AppendLine('<body>')
    [void]$sb.AppendLine('<header>')
    [void]$sb.AppendLine('<h1>Per-Agent Matrix Dashboard</h1>')
    [void]$sb.AppendLine("<div class=`"meta`">Date: <strong>$(Edit-HtmlEscape $DateLabel)</strong> &middot; Tier: <strong>$(Edit-HtmlEscape $tier)</strong> &middot; Mode: <strong>$(Edit-HtmlEscape $mode)</strong> &middot; Overall: <strong>$(Edit-HtmlEscape $overall)</strong> &middot; Generated: $(Edit-HtmlEscape $generatedAt)</div>")
    [void]$sb.AppendLine('<div class="totals">')
    [void]$sb.AppendLine("<div>Agents: <strong>$totalAgents</strong></div>")
    [void]$sb.AppendLine("<div>Functional pass: <strong class=`"pass`">$passCount</strong></div>")
    [void]$sb.AppendLine("<div>Functional fail: <strong class=`"fail`">$failCount</strong></div>")
    [void]$sb.AppendLine("<div>Dry-run: <strong class=`"dry-run`">$dryRunCount</strong></div>")
    [void]$sb.AppendLine("<div>Unknown: <strong class=`"unknown`">$unknownCount</strong></div>")
    [void]$sb.AppendLine("<div>Surface signatures present: <strong>$surfacePresent / $totalAgents</strong></div>")
    [void]$sb.AppendLine('</div>')
    [void]$sb.AppendLine('</header>')

    if ($overall -eq 'dry-run') {
        [void]$sb.AppendLine('<div class="banner banner-dry-run" data-banner="dry-run">DRY-RUN: no live grader results. Re-run with the live matrix to populate verdicts.</div>')
    }

    if ($failCount -gt 0) {
        [void]$sb.AppendLine('<section class="failures-panel" data-panel="failures">')
        [void]$sb.AppendLine("<h2>Failures ($failCount)</h2>")
        [void]$sb.AppendLine('<ul>')
        foreach ($row in $Rows | Where-Object { $_.functional -eq 'fail' }) {
            $slugEsc = Edit-HtmlEscape $row.slug
            $failingGraders = @($row.graders | Where-Object { $_.status -eq 'fail' } | ForEach-Object { $_.name })
            $detail = if ($failingGraders.Count -gt 0) {
                ' &mdash; failing graders: ' + (Edit-HtmlEscape ($failingGraders -join ', '))
            } else {
                ''
            }
            $link = if ($row.perAgentHref) {
                $hrefEsc = Edit-HtmlEscape $row.perAgentHref
                "<a href=`"$hrefEsc`">$slugEsc</a>"
            } else {
                $slugEsc
            }
            [void]$sb.AppendLine("<li>$link (exit $($row.exitCode))$detail</li>")
        }
        [void]$sb.AppendLine('</ul>')
        [void]$sb.AppendLine('</section>')
    }

    [void]$sb.AppendLine('<div class="controls" data-panel="controls">')
    [void]$sb.AppendLine('<label>Search slug: <input type="search" id="filter-search" placeholder="substring..." autocomplete="off"></label>')
    [void]$sb.AppendLine('<fieldset><legend>Verdict</legend>')
    foreach ($v in @('pass', 'fail', 'dry-run', 'unknown')) {
        [void]$sb.AppendLine("<label><input type=`"checkbox`" data-filter-verdict value=`"$v`" checked> $v</label>")
    }
    [void]$sb.AppendLine('</fieldset>')
    [void]$sb.AppendLine('<label>Class: <select id="filter-class"><option value="">(all)</option>')
    foreach ($c in $uniqueClasses) {
        $cEsc = Edit-HtmlEscape $c
        [void]$sb.AppendLine("<option value=`"$cEsc`">$cEsc</option>")
    }
    [void]$sb.AppendLine('</select></label>')
    [void]$sb.AppendLine('<label>Cost tier: <select id="filter-cost"><option value="">(all)</option>')
    foreach ($t in $uniqueTiers) {
        $tEsc = Edit-HtmlEscape $t
        [void]$sb.AppendLine("<option value=`"$tEsc`">$tEsc</option>")
    }
    [void]$sb.AppendLine('</select></label>')
    [void]$sb.AppendLine('<label>Failing grader: <select id="filter-failing-grader"><option value="">(all)</option>')
    foreach ($entry in $failingGraderEntries) {
        $gEsc = Edit-HtmlEscape $entry.Name
        $labelEsc = "$gEsc ($($entry.Count))"
        [void]$sb.AppendLine("<option value=`"$gEsc`">$labelEsc</option>")
    }
    [void]$sb.AppendLine('</select></label>')
    [void]$sb.AppendLine('<label><input type="checkbox" id="filter-failures-only"> Failures only</label>')
    [void]$sb.AppendLine('</div>')

    [void]$sb.AppendLine('<table id="matrix">')
    [void]$sb.AppendLine('<thead><tr>')
    [void]$sb.AppendLine('<th data-sort-key="slug">Agent</th>')
    [void]$sb.AppendLine('<th data-sort-key="class">Class</th>')
    [void]$sb.AppendLine('<th data-sort-key="cost">Cost tier</th>')
    [void]$sb.AppendLine('<th data-sort-key="functional">Functional</th>')
    [void]$sb.AppendLine('<th data-sort-key="surface">Surface</th>')
    [void]$sb.AppendLine('<th data-sort-key="equivalence">Equivalence</th>')
    [void]$sb.AppendLine('<th data-sort-key="lastPass">Last pass</th>')
    [void]$sb.AppendLine('</tr></thead>')
    [void]$sb.AppendLine('<tbody>')

    $rowIndex = 0
    foreach ($row in $Rows) {
        $slugEsc  = Edit-HtmlEscape $row.slug
        $classEsc = Edit-HtmlEscape $row.class
        $costEsc  = Edit-HtmlEscape $row.cost_tier
        $funcEsc  = Edit-HtmlEscape $row.functional
        $surfEsc  = Edit-HtmlEscape $row.surface
        $eqEsc    = Edit-HtmlEscape $row.equivalence
        $lastEsc  = if ($row.lastPass) { Edit-HtmlEscape $row.lastPass } else { '&mdash;' }
        $lastSortVal = if ($row.lastPass) { Edit-HtmlEscape $row.lastPass } else { '' }

        $slugLink = if ($row.perAgentHref) {
            $hrefEsc = Edit-HtmlEscape $row.perAgentHref
            "<a href=`"$hrefEsc`">$slugEsc</a>"
        } else {
            $slugEsc
        }

        $drillId = "drill-$rowIndex"
        $slugCell = "<button type=`"button`" class=`"toggle`" data-toggle=`"$drillId`" aria-expanded=`"false`" aria-controls=`"$drillId`">+</button>$slugLink"

        $funcClass = switch ($row.functional) {
            'pass'    { 'pass' }
            'fail'    { 'fail' }
            'dry-run' { 'dry-run' }
            default   { 'unknown' }
        }
        $surfClass = if ($row.surface -eq 'present') { 'present' } else { 'missing' }
        $eqClass = 'na'

        $rowFailingNames = @(
            $row.graders |
                Where-Object { $_ -and $_.status -eq 'fail' -and $_.name } |
                ForEach-Object { ([string]$_.name).ToLowerInvariant() } |
                Sort-Object -Unique
        )
        $failingNamesAttr = Edit-HtmlEscape ($rowFailingNames -join ',')

        [void]$sb.AppendLine("<tr class=`"row`" data-slug=`"$slugEsc`" data-class=`"$classEsc`" data-cost=`"$costEsc`" data-functional=`"$funcEsc`" data-surface=`"$surfEsc`" data-equivalence=`"$eqEsc`" data-lastpass=`"$lastSortVal`" data-failing-graders=`"$failingNamesAttr`">")
        [void]$sb.AppendLine("<td class=`"slug`">$slugCell</td>")
        [void]$sb.AppendLine("<td>$classEsc</td>")
        [void]$sb.AppendLine("<td>$costEsc</td>")
        [void]$sb.AppendLine("<td class=`"$funcClass`">$funcEsc</td>")
        [void]$sb.AppendLine("<td class=`"$surfClass`">$surfEsc</td>")
        [void]$sb.AppendLine("<td class=`"$eqClass`">$eqEsc</td>")
        [void]$sb.AppendLine("<td>$lastEsc</td>")
        [void]$sb.AppendLine('</tr>')

        [void]$sb.AppendLine("<tr class=`"drill`" id=`"$drillId`" data-drill-for=`"$slugEsc`"><td colspan=`"7`">")
        $exitText = if ($row.exitCode -ge 0) { [string]$row.exitCode } else { 'n/a' }
        $logCell = if ($row.logPath) {
            $logEsc = Edit-HtmlEscape $row.logPath
            "<a href=`"$logEsc`">$logEsc</a>"
        } else {
            '<span class="drill-empty">(no log path)</span>'
        }
        [void]$sb.AppendLine("<div class=`"drill-meta`">Exit code: <strong>$exitText</strong> &middot; Log: $logCell</div>")
        if ($row.graders -and $row.graders.Count -gt 0) {
            [void]$sb.AppendLine('<table class="drill-graders"><colgroup><col class="col-grader"><col class="col-status"><col class="col-message"><col class="col-pattern"></colgroup><thead><tr><th>Grader</th><th>Status</th><th>Evidence / Message</th><th>Pattern</th></tr></thead><tbody>')
            foreach ($g in $row.graders) {
                $gName    = Edit-HtmlEscape $g.name
                $gStatus  = Edit-HtmlEscape $g.status
                # Prefer the JSONL evidence string when present (contains the full pattern + verdict);
                # fall back to the log message for older runs without trajectory enrichment.
                $rawDetail = if ($g.evidence) { [string]$g.evidence } elseif ($g.message) { [string]$g.message } else { '' }
                $gDetail  = if ($rawDetail) { Edit-HtmlEscape $rawDetail } else { '<span class="drill-empty">(none)</span>' }
                $gPattern = if ($g.pattern) { '<code>' + (Edit-HtmlEscape ([string]$g.pattern)) + '</code>' } else { '<span class="drill-empty">(n/a)</span>' }
                $gClass = switch ($g.status) {
                    'pass'    { 'pass' }
                    'fail'    { 'fail' }
                    'dry-run' { 'dry-run' }
                    default   { 'unknown' }
                }
                [void]$sb.AppendLine("<tr><td>$gName</td><td class=`"$gClass`">$gStatus</td><td>$gDetail</td><td>$gPattern</td></tr>")
            }
            [void]$sb.AppendLine('</tbody></table>')
        } else {
            [void]$sb.AppendLine('<div class="drill-empty">No grader results recorded.</div>')
        }
        if ($row.stimulusPrompt) {
            $stimEsc = Edit-HtmlEscape $row.stimulusPrompt
            [void]$sb.AppendLine("<details class=`"drill-block`"><summary>Stimulus prompt ($($row.stimulusPrompt.Length) chars)</summary><pre>$stimEsc</pre></details>")
        }
        if ($row.output) {
            $outEsc = Edit-HtmlEscape $row.output
            [void]$sb.AppendLine("<details class=`"drill-block`"><summary>Agent output ($($row.output.Length) chars)</summary><pre>$outEsc</pre></details>")
        }
        if ($row.vallyOutputDir) {
            $vDirEsc = Edit-HtmlEscape $row.vallyOutputDir
            [void]$sb.AppendLine("<div class=`"drill-meta`">Vally output dir: <code>$vDirEsc</code></div>")
        }
        [void]$sb.AppendLine('</td></tr>')

        $rowIndex++
    }

    [void]$sb.AppendLine('</tbody>')
    [void]$sb.AppendLine('</table>')
    [void]$sb.AppendLine('<script>')
    [void]$sb.AppendLine(@'
(function () {
  var table = document.getElementById('matrix');
  if (!table) { return; }
  var tbody = table.querySelector('tbody');
  var search = document.getElementById('filter-search');
  var classSel = document.getElementById('filter-class');
  var costSel = document.getElementById('filter-cost');
  var failSel = document.getElementById('filter-failing-grader');
  var failOnly = document.getElementById('filter-failures-only');
  var verdictBoxes = Array.prototype.slice.call(document.querySelectorAll('[data-filter-verdict]'));

  function applyFilters() {
    var term = (search && search.value || '').toLowerCase();
    var cls = classSel ? classSel.value : '';
    var cost = costSel ? costSel.value : '';
    var failName = failSel ? failSel.value : '';
    var onlyFailures = !!(failOnly && failOnly.checked);
    var allowed = {};
    verdictBoxes.forEach(function (b) { allowed[b.value] = b.checked; });
    var rows = tbody.querySelectorAll('tr.row');
    rows.forEach(function (r) {
      var slug = (r.getAttribute('data-slug') || '').toLowerCase();
      var rc = r.getAttribute('data-class') || '';
      var rcost = r.getAttribute('data-cost') || '';
      var rverdict = r.getAttribute('data-functional') || 'unknown';
      var ok = true;
      if (term && slug.indexOf(term) === -1) { ok = false; }
      if (ok && cls && rc !== cls) { ok = false; }
      if (ok && cost && rcost !== cost) { ok = false; }
      if (ok && verdictBoxes.length && !allowed[rverdict]) { ok = false; }
      if (ok && onlyFailures && rverdict !== 'fail') { ok = false; }
      if (ok && failName) {
        var fgAttr = r.getAttribute('data-failing-graders') || '';
        var fgList = fgAttr ? fgAttr.split(',') : [];
        if (fgList.indexOf(failName) === -1) { ok = false; }
      }
      r.style.display = ok ? '' : 'none';
      var btn = r.querySelector('[data-toggle]');
      if (btn) {
        var drill = document.getElementById(btn.getAttribute('data-toggle'));
        if (drill) {
          if (!ok) {
            drill.style.display = 'none';
          } else if (drill.classList.contains('open')) {
            drill.style.display = 'table-row';
          } else {
            drill.style.display = '';
          }
        }
      }
    });
  }

  function toggleDrill(btn) {
    var id = btn.getAttribute('data-toggle');
    var drill = document.getElementById(id);
    if (!drill) { return; }
    var open = drill.classList.toggle('open');
    btn.setAttribute('aria-expanded', open ? 'true' : 'false');
    btn.textContent = open ? '-' : '+';
    drill.style.display = open ? 'table-row' : '';
  }

  var sortKey = null;
  var sortDir = 'asc';
  function sortBy(key) {
    if (sortKey === key) {
      sortDir = sortDir === 'asc' ? 'desc' : 'asc';
    } else {
      sortKey = key;
      sortDir = 'asc';
    }
    table.querySelectorAll('th[data-sort-key]').forEach(function (th) {
      if (th.getAttribute('data-sort-key') === sortKey) {
        th.setAttribute('data-sort-active', sortDir);
      } else {
        th.removeAttribute('data-sort-active');
      }
    });
    var attrMap = {
      slug: 'data-slug',
      class: 'data-class',
      cost: 'data-cost',
      functional: 'data-functional',
      surface: 'data-surface',
      equivalence: 'data-equivalence',
      lastPass: 'data-lastpass'
    };
    var attr = attrMap[key];
    if (!attr) { return; }
    var pairs = [];
    var rows = Array.prototype.slice.call(tbody.querySelectorAll('tr.row'));
    rows.forEach(function (r) {
      var btn = r.querySelector('[data-toggle]');
      var drill = btn ? document.getElementById(btn.getAttribute('data-toggle')) : null;
      pairs.push({ row: r, drill: drill, key: (r.getAttribute(attr) || '').toLowerCase() });
    });
    pairs.sort(function (a, b) {
      if (a.key < b.key) { return sortDir === 'asc' ? -1 : 1; }
      if (a.key > b.key) { return sortDir === 'asc' ? 1 : -1; }
      return 0;
    });
    pairs.forEach(function (p) {
      tbody.appendChild(p.row);
      if (p.drill) { tbody.appendChild(p.drill); }
    });
  }

  table.querySelectorAll('th[data-sort-key]').forEach(function (th) {
    th.addEventListener('click', function () { sortBy(th.getAttribute('data-sort-key')); });
  });
  tbody.addEventListener('click', function (e) {
    var t = e.target;
    if (t && t.matches && t.matches('[data-toggle]')) { toggleDrill(t); }
  });
  if (search) { search.addEventListener('input', applyFilters); }
  if (classSel) { classSel.addEventListener('change', applyFilters); }
  if (costSel) { costSel.addEventListener('change', applyFilters); }
  if (failSel) { failSel.addEventListener('change', applyFilters); }
  if (failOnly) { failOnly.addEventListener('change', applyFilters); }
  verdictBoxes.forEach(function (b) { b.addEventListener('change', applyFilters); });
})();
'@)
    [void]$sb.AppendLine('</script>')
    [void]$sb.AppendLine('</body>')
    [void]$sb.AppendLine('</html>')

    return $sb.ToString()
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolvedRoot = Resolve-DashboardRepoRoot -Hint $RepoRoot

    if (-not $AgentMatrixRoot) {
        $AgentMatrixRoot = Join-Path $resolvedRoot 'evals/results/agent-matrix'
    }
    if (-not $SurfaceSignaturesRoot) {
        $SurfaceSignaturesRoot = Join-Path $resolvedRoot 'evals/baseline-equivalence/surface-signatures'
    }
    if (-not $InventoryPath) {
        $InventoryPath = Join-Path $resolvedRoot 'evals/agent-behavior/AGENTS.yml'
    }
    if (-not $SummaryPath) {
        $SummaryPath = Get-LatestSummaryPath -AgentMatrixRoot $AgentMatrixRoot
    }
    if (-not (Test-Path -LiteralPath $SummaryPath -PathType Leaf)) {
        throw "Summary file not found: $SummaryPath"
    }
    if (-not $OutPath) {
        $OutPath = Join-Path $resolvedRoot 'logs/agent-matrix-dashboard.html'
    }

    $summaryDir = Split-Path -Parent $SummaryPath
    $dateLabel  = Split-Path -Leaf $summaryDir

    $summary    = Get-Content -LiteralPath $SummaryPath -Raw | ConvertFrom-Json
    $inventory  = Read-AgentSlugInventory -Path $InventoryPath
    $lastPass   = Get-LastPassDateBySlug -AgentMatrixRoot $AgentMatrixRoot
    $rows       = ConvertTo-AgentMatrixRows -Inventory $inventory -Summary $summary -SummaryDir $summaryDir -SurfaceSignaturesRoot $SurfaceSignaturesRoot -LastPassBySlug $lastPass
    $html       = ConvertTo-AgentMatrixHtml -Rows $rows -Summary $summary -DateLabel $dateLabel

    $outDir = Split-Path -Parent $OutPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }
    Set-Content -LiteralPath $OutPath -Value $html -Encoding utf8NoBOM

    Write-Host "Wrote $OutPath"

    if ($Open) {
        try {
            Start-Process -FilePath $OutPath -ErrorAction Stop
        }
        catch {
            Write-Warning "Could not open browser automatically: $($_.Exception.Message). Open the file manually: $OutPath"
        }
    }
}
