# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Shared parsing, aggregation, and rendering helpers for baseline-equivalence eval runs.

.DESCRIPTION
    Consolidates the `vally compare --output` JSONL and results.jsonl parsers used by
    `Invoke-BaselineEquivalence.ps1` and the dashboard generator
    `New-EquivalenceDashboard.ps1`. All public functions are exported via
    `Export-ModuleMember` at the bottom of the file.
#>

Set-StrictMode -Version Latest

function Measure-CompareTrials {
    <#
    .SYNOPSIS
        Aggregates comparison trials and summary statistics from Vally JSONL records.
    .DESCRIPTION
        Tallies recognized winners and combines complete confidence-interval pairs
        conservatively by taking the maximum lower and minimum upper bounds.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $ties = 0; $baselineWins = 0; $treatmentWins = 0; $total = 0
    $summaryCount = 0
    $perStimulus = @{}
    $meanScores = [System.Collections.Generic.List[double]]::new()
    $winRates = [System.Collections.Generic.List[double]]::new()
    $ciLows = [System.Collections.Generic.List[double]]::new()
    $ciHighs = [System.Collections.Generic.List[double]]::new()

    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        try {
            $record = $line | ConvertFrom-Json -Depth 100 -ErrorAction Stop
        }
        catch {
            continue
        }
        if (-not $record.PSObject.Properties['type'] -or $record.type -ne 'comparison') { continue }

        $stimuli = if ($record.PSObject.Properties['stimuli'] -and $record.stimuli) { @($record.stimuli) } else { @() }
        foreach ($stimulus in $stimuli) {
            if (-not $stimulus) { continue }
            $name = if ($stimulus.PSObject.Properties['stimulusName']) { [string]$stimulus.stimulusName } else { '<unknown>' }
            if (-not $perStimulus.ContainsKey($name)) {
                $perStimulus[$name] = @{ Ties = 0; AWins = 0; BWins = 0 }
            }
            $trials = if ($stimulus.PSObject.Properties['trials'] -and $stimulus.trials) { @($stimulus.trials) } else { @() }
            foreach ($trial in $trials) {
                if (-not $trial) { continue }
                if ($trial.PSObject.Properties['errored'] -and $trial.errored) { continue }
                $winner = if ($trial.PSObject.Properties['winner']) { [string]$trial.winner } else { '' }
                switch ($winner) {
                    'tie' { $ties++; $total++; $perStimulus[$name].Ties += 1 }
                    'baseline' { $baselineWins++; $total++; $perStimulus[$name].AWins += 1 }
                    'treatment' { $treatmentWins++; $total++; $perStimulus[$name].BWins += 1 }
                    default { Write-Verbose "Unrecognized winner '$winner' for stimulus '$name'; excluded from tally." }
                }
            }
        }

        if (-not ($record.PSObject.Properties['summary'] -and $record.summary)) { continue }
        $summary = $record.summary
        $hasCiPair = $summary.PSObject.Properties['ciLow'] -and
            $summary.PSObject.Properties['ciHigh'] -and
            $null -ne $summary.ciLow -and
            $null -ne $summary.ciHigh
        if ($hasCiPair) {
            $summaryCount++
            $ciLows.Add([double]$summary.ciLow)
            $ciHighs.Add([double]$summary.ciHigh)
        }
        if ($summary.PSObject.Properties['meanScore'] -and $null -ne $summary.meanScore) { $meanScores.Add([double]$summary.meanScore) }
        if ($summary.PSObject.Properties['winRate'] -and $null -ne $summary.winRate) { $winRates.Add([double]$summary.winRate) }
    }

    $meanScore = if ($meanScores.Count -gt 0) { ($meanScores | Measure-Object -Average).Average } else { 0.0 }
    $winRate = if ($winRates.Count -gt 0) { ($winRates | Measure-Object -Average).Average } else { 0.0 }
    $ciLow = if ($ciLows.Count -gt 0) { ($ciLows | Measure-Object -Maximum).Maximum } else { 0.0 }
    $ciHigh = if ($ciHighs.Count -gt 0) { ($ciHighs | Measure-Object -Minimum).Minimum } else { 0.0 }

    return @{
        Total        = $total
        Ties         = $ties
        AWins        = $baselineWins
        BWins        = $treatmentWins
        PerStimulus  = $perStimulus
        SummaryCount = $summaryCount
        MeanScore    = [math]::Round($meanScore, 4)
        WinRate      = [math]::Round($winRate, 4)
        CiLow        = [math]::Round($ciLow, 4)
        CiHigh       = [math]::Round($ciHigh, 4)
    }
}

function Measure-InvariantFailures {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines
    )

    $ansi = [regex]'\x1B\[[0-9;]*[A-Za-z]'
    $pass = [char]::ConvertFromUtf32(0x2705)
    $fail = [char]::ConvertFromUtf32(0x274C)
    $warn = [char]::ConvertFromUtf32(0x1F7E1)
    $verdictAlt = "$pass|$fail|$warn"
    $rowPattern = "^\|\s*[^|\s][^|]*\|.*\|\s*(?<verdict>$verdictAlt)(?:\s|$|<)"
    $total = 0; $failed = 0
    foreach ($line in $Lines) {
        $clean = $ansi.Replace($line, '')
        if ($clean -match $rowPattern) {
            $total++
            if ($Matches.verdict -ne $pass) { $failed++ }
        }
    }
    return @{ Total = $total; Failed = $failed }
}

function Get-VerdictFromAggregate {
    # A confidence interval that excludes zero signals a documented-divergence review.
    # PR runs warn; nightly runs fail. Missing runs always fail.
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][int]$Runs,
        [Parameter(Mandatory)][double]$CiLow,
        [Parameter(Mandatory)][double]$CiHigh,
        [Parameter(Mandatory)][int]$InvariantFailures,
        [Parameter(Mandatory)][int]$DivergenceFailures,
        [Parameter(Mandatory)][string]$Tier
    )

    if ($Runs -le 0) { return 'fail' }
    if ($InvariantFailures -gt 0 -or $DivergenceFailures -gt 0) {
        if ($Tier -eq 'pr') { return 'warn' } else { return 'fail' }
    }

    $significantDifference = ($CiLow -gt 0) -or ($CiHigh -lt 0)
    if (-not $significantDifference) { return 'pass' }

    if ($Tier -eq 'pr') { return 'warn' } else { return 'fail' }
}

function Get-OutputHash {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return -join ($hash | ForEach-Object { $_.ToString('x2') })
    }
    finally { $sha.Dispose() }
}

function ConvertFrom-EquivalenceResults {
    [CmdletBinding()]
    [OutputType([System.Collections.IList])]
    param(
        [Parameter(Mandatory)][string]$RunDir
    )

    if (-not (Test-Path -LiteralPath $RunDir)) {
        throw "Run directory not found: $RunDir"
    }

    $jsonlFiles = @(Get-ChildItem -LiteralPath $RunDir -Filter 'results.jsonl' -Recurse -File)
    if ($jsonlFiles.Count -eq 0) {
        throw "No results.jsonl found under $RunDir"
    }

    $records = New-Object 'System.Collections.Generic.List[object]'
    $stimulusCounts = @{}
    $knownKinds = @('code', 'llm', 'human')

    foreach ($file in $jsonlFiles) {
        $lines = Get-Content -LiteralPath $file.FullName -Encoding utf8
        foreach ($line in $lines) {
            if ([string]::IsNullOrWhiteSpace($line)) { continue }
            $obj = $line | ConvertFrom-Json -Depth 100
            if (-not ($obj.PSObject.Properties['trajectory'])) { continue }
            $traj = $obj.trajectory
            $stim = if ($traj -and $traj.stimulus) { [string]$traj.stimulus.name } else { '<unknown>' }
            if (-not $stimulusCounts.ContainsKey($stim)) { $stimulusCounts[$stim] = 0 }
            $trial = $stimulusCounts[$stim]
            $stimulusCounts[$stim] = $trial + 1

            $output = if ($traj -and $null -ne $traj.output) { [string]$traj.output } else { '' }
            $wallMs = 0
            $totalTokens = 0
            if ($traj -and $traj.metrics) {
                if ($null -ne $traj.metrics.wallTimeMs) { $wallMs = [int]$traj.metrics.wallTimeMs }
                if ($traj.metrics.tokenUsage -and $null -ne $traj.metrics.tokenUsage.totalTokens) {
                    $totalTokens = [int]$traj.metrics.tokenUsage.totalTokens
                }
            }

            $passed = $false
            $score = 0.0
            $details = @{ code = @(); llm = @(); human = @(); other = @() }
            if ($obj.PSObject.Properties['gradeResult'] -and $obj.gradeResult) {
                $gr = $obj.gradeResult
                if ($null -ne $gr.passed) { $passed = [bool]$gr.passed }
                if ($null -ne $gr.score) { $score = [double]$gr.score }
                if ($gr.PSObject.Properties['details'] -and $gr.details) {
                    foreach ($d in @($gr.details)) {
                        $kind = if ($d.PSObject.Properties['kind'] -and $d.kind) { [string]$d.kind } else { 'other' }
                        if ($knownKinds -notcontains $kind) {
                            Write-Warning "ConvertFrom-EquivalenceResults: unknown grader kind '$kind' for stimulus '$stim' (trial $trial); bucketing under 'other'."
                            $details.other += $d
                        }
                        else {
                            $details[$kind] += $d
                        }
                    }
                }
            }

            $records.Add([pscustomobject]@{
                    stimulusName = $stim
                    trial        = $trial
                    output       = $output
                    outputHash   = Get-OutputHash -Text $output
                    passed       = $passed
                    score        = $score
                    wallTimeMs   = $wallMs
                    totalTokens  = $totalTokens
                    details      = $details
                }) | Out-Null
        }
    }

    return , $records
}

function Merge-EquivalenceStimuli {
    [CmdletBinding()]
    [OutputType([System.Collections.IList])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Baseline,
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Customized,
        [Parameter(Mandatory)][hashtable]$Compare
    )

    $byStimBase = @{}
    foreach ($r in $Baseline) {
        if (-not $byStimBase.ContainsKey($r.stimulusName)) { $byStimBase[$r.stimulusName] = @() }
        $byStimBase[$r.stimulusName] += $r
    }
    $byStimCust = @{}
    foreach ($r in $Customized) {
        if (-not $byStimCust.ContainsKey($r.stimulusName)) { $byStimCust[$r.stimulusName] = @() }
        $byStimCust[$r.stimulusName] += $r
    }

    $perStim = if ($Compare.ContainsKey('PerStimulus')) { $Compare.PerStimulus } else { @{} }
    $nameSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($k in $byStimBase.Keys) { [void]$nameSet.Add($k) }
    foreach ($k in $byStimCust.Keys) { [void]$nameSet.Add($k) }
    $allNames = @($nameSet) | Sort-Object
    $merged = New-Object 'System.Collections.Generic.List[object]'

    foreach ($name in $allNames) {
        [object[]]$b = @(if ($byStimBase.ContainsKey($name)) { $byStimBase[$name] } else { @() })
        [object[]]$c = @(if ($byStimCust.ContainsKey($name)) { $byStimCust[$name] } else { @() })
        $trialCount = [math]::Max($b.Count, $c.Count)

        $identical = 0
        $wallDiffs = New-Object 'System.Collections.Generic.List[double]'
        $tokenDiffs = New-Object 'System.Collections.Generic.List[double]'
        $pairs = New-Object 'System.Collections.Generic.List[object]'
        for ($i = 0; $i -lt $trialCount; $i++) {
            $bi = if ($i -lt $b.Count) { $b[$i] } else { $null }
            $ci = if ($i -lt $c.Count) { $c[$i] } else { $null }
            if ($bi -and $ci -and $bi.outputHash -eq $ci.outputHash) { $identical++ }
            if ($bi -and $ci) {
                $wallDiffs.Add([double]($ci.wallTimeMs - $bi.wallTimeMs))
                $tokenDiffs.Add([double]($ci.totalTokens - $bi.totalTokens))
            }
            $pairs.Add([pscustomobject]@{
                    trial      = $i
                    baseline   = $bi
                    customized = $ci
                }) | Out-Null
        }

        $basePassed = @($b | Where-Object { $_.passed }).Count
        $custPassed = @($c | Where-Object { $_.passed }).Count

        $tally = if ($perStim.ContainsKey($name)) { $perStim[$name] } else { @{ Ties = 0; AWins = 0; BWins = 0 } }

        $meanWall = if ($wallDiffs.Count -gt 0) { ($wallDiffs | Measure-Object -Average).Average } else { 0.0 }
        $meanTokens = if ($tokenDiffs.Count -gt 0) { ($tokenDiffs | Measure-Object -Average).Average } else { 0.0 }

        $merged.Add([pscustomobject]@{
                stimulusName       = $name
                baselineTrials     = $b.Count
                customizedTrials   = $c.Count
                baselinePassed     = $basePassed
                customizedPassed   = $custPassed
                baselinePassRate   = if ($b.Count -gt 0) { [math]::Round($basePassed / [double]$b.Count, 4) } else { 0.0 }
                customizedPassRate = if ($c.Count -gt 0) { [math]::Round($custPassed / [double]$c.Count, 4) } else { 0.0 }
                identicalCount     = $identical
                identicalTotal     = $trialCount
                ties               = [int]$tally.Ties
                aWins              = [int]$tally.AWins
                bWins              = [int]$tally.BWins
                meanWallTimeDeltaMs = [math]::Round($meanWall, 2)
                meanTokenDelta     = [math]::Round($meanTokens, 2)
                trials             = $pairs
            }) | Out-Null
    }

    return , $merged
}

function Edit-HtmlEscape {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory)][AllowEmptyString()][AllowNull()][string]$Text)
    if ($null -eq $Text) { return '' }
    return ($Text -replace '&', '&amp;' -replace '<', '&lt;' -replace '>', '&gt;' -replace '"', '&quot;' -replace "'", '&#39;')
}

function Get-VariantMetadata {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$VariantYamlPath,
        [Parameter(Mandatory)]
        [hashtable]$Default
    )

    $variant = @{}
    foreach ($key in $Default.Keys) { $variant[$key] = $Default[$key] }

    if (-not (Test-Path -LiteralPath $VariantYamlPath)) { return $variant }
    if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) { return $variant }

    try {
        Import-Module powershell-yaml -ErrorAction Stop
        $raw = Get-Content -LiteralPath $VariantYamlPath -Raw
        $parsed = ConvertFrom-Yaml -Yaml $raw
        if ($parsed) {
            foreach ($key in @('kind', 'name', 'label', 'description', 'applied')) {
                if ($parsed.ContainsKey($key)) { $variant[$key] = $parsed[$key] }
            }
        }
    }
    catch {
        Write-Verbose "Failed to parse variant metadata at ${VariantYamlPath}: $($_.Exception.Message)"
    }

    if (-not $variant.ContainsKey('applied') -or $null -eq $variant.applied) { $variant.applied = @() }
    return $variant
}

function ConvertTo-EquivalenceHtml {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Stimuli,
        [Parameter(Mandatory)][string]$Model,
        [Parameter(Mandatory)][string]$RunId,
        [Parameter(Mandatory)][string]$Agent,
        [hashtable]$Variants
    )

    $generatedAt = (Get-Date).ToUniversalTime().ToString('o')
    $totalStimuli = $Stimuli.Count
    $totalTrials = ($Stimuli | Measure-Object -Property identicalTotal -Sum).Sum
    if (-not $totalTrials) { $totalTrials = 0 }
    $totalIdentical = ($Stimuli | Measure-Object -Property identicalCount -Sum).Sum
    if (-not $totalIdentical) { $totalIdentical = 0 }
    $identicalPct = if ($totalTrials -gt 0) { [math]::Round(100 * $totalIdentical / [double]$totalTrials, 1) } else { 0 }

    $defaultVariantA = @{ kind = 'baseline'; name = 'baseline';   label = 'Baseline (A)';   description = ''; applied = @() }
    $defaultVariantB = @{ kind = 'unknown';  name = 'customized'; label = 'Customized (B)'; description = ''; applied = @() }
    $variantA = if ($Variants -and $Variants.a) { $Variants.a } else { $defaultVariantA }
    $variantB = if ($Variants -and $Variants.b) { $Variants.b } else { $defaultVariantB }
    $subject  = if ($Variants -and $Variants.subject) { [string]$Variants.subject } else { [string]$variantB.name }

    $payload = [ordered]@{
        model        = $Model
        runId        = $RunId
        generatedAt  = $generatedAt
        totalStimuli = $totalStimuli
        totalTrials  = $totalTrials
        identicalPct = $identicalPct
        variants     = @{ a = $variantA; b = $variantB; subject = $subject }
        stimuli      = $Stimuli
    }
    $json = $payload | ConvertTo-Json -Depth 100 -Compress
    # Escape sequences that could break out of a <script> tag context (including '/' for </script> defense in depth).
    $json = $json -replace '<', '\u003c' -replace '>', '\u003e' -replace '&', '\u0026' -replace '/', '\/'

    $modelEsc = Edit-HtmlEscape $Model
    $runIdEsc = Edit-HtmlEscape $RunId
    $agentEsc = Edit-HtmlEscape $Agent
    $aLabelEsc = Edit-HtmlEscape ([string]$variantA.label)
    $bLabelEsc = Edit-HtmlEscape ([string]$variantB.label)
    $aKindEsc = Edit-HtmlEscape ([string]$variantA.kind)
    $bKindEsc = Edit-HtmlEscape ([string]$variantB.kind)
    $aDescEsc = Edit-HtmlEscape ([string]$variantA.description)
    $bDescEsc = Edit-HtmlEscape ([string]$variantB.description)
    $aAppliedList = if ($variantA.applied -and @($variantA.applied).Count -gt 0) { (@($variantA.applied) | ForEach-Object { '<li>' + (Edit-HtmlEscape ([string]$_)) + '</li>' }) -join '' } else { '<li><em>(none)</em></li>' }
    $bAppliedList = if ($variantB.applied -and @($variantB.applied).Count -gt 0) { (@($variantB.applied) | ForEach-Object { '<li>' + (Edit-HtmlEscape ([string]$_)) + '</li>' }) -join '' } else { '<li><em>(none)</em></li>' }
    $genEsc = Edit-HtmlEscape $generatedAt

    $css = @'
:root { color-scheme: light dark; }
body { font-family: -apple-system, Segoe UI, Roboto, sans-serif; margin: 0; padding: 1rem; }
header { border-bottom: 1px solid #888; padding-bottom: 0.5rem; margin-bottom: 1rem; }
header h1 { margin: 0 0 0.25rem 0; font-size: 1.4rem; }
.meta { font-size: 0.85rem; color: #666; }
.totals { display: flex; gap: 1.5rem; margin-top: 0.5rem; }
.totals div { font-size: 0.9rem; }
.totals strong { font-size: 1.1rem; }
.variant-strip { display: flex; gap: 1rem; margin: 1rem 0; flex-wrap: wrap; }
.variant-card { flex: 1; min-width: 280px; padding: 0.75rem 1rem; background: #f3f6fb; border: 1px solid #d0d7e2; border-radius: 6px; font-size: 0.85rem; }
.variant-card strong { color: #1a3a6b; }
.variant-kind { font-size: 0.75rem; color: #555; }
.variant-desc { margin-top: 0.35rem; color: #444; }
.variant-applied { margin-top: 0.5rem; font-size: 0.8rem; }
.variant-applied ul { margin: 0.15rem 0 0 1rem; padding: 0; }
@media (prefers-color-scheme: dark) {
  .variant-card { background: #1a2230; border-color: #344056; }
  .variant-card strong { color: #8ab4ff; }
  .variant-kind { color: #aaa; }
  .variant-desc { color: #ddd; }
}
input[type=search] { padding: 0.35rem 0.5rem; width: 320px; max-width: 100%; margin-bottom: 0.5rem; }
table { border-collapse: collapse; width: 100%; font-size: 0.85rem; }
th, td { border: 1px solid #ccc; padding: 0.35rem 0.5rem; text-align: left; }
th { background: #f0f0f0; cursor: pointer; user-select: none; position: sticky; top: 0; }
tr.summary:hover { background: #f6f6ff; cursor: pointer; }
tr.details { display: none; background: #fafafa; }
tr.details.open { display: table-row; }
tr.details td { padding: 0.75rem; }
.kind-group { margin-bottom: 0.75rem; }
.kind-group h4 { margin: 0.25rem 0; font-size: 0.9rem; }
.grader { font-size: 0.8rem; margin-left: 1rem; }
.diff { display: grid; grid-template-columns: 1fr 1fr; gap: 0.5rem; margin-top: 0.5rem; }
.diff h5 { margin: 0 0 0.25rem 0; font-size: 0.8rem; }
pre { background: #f5f5f5; padding: 0.5rem; border: 1px solid #ddd; overflow: auto; white-space: pre-wrap; max-height: 240px; margin: 0; }
.verdict-pass { color: #0a7d28; font-weight: bold; }
.verdict-warn { color: #b8860b; font-weight: bold; }
.verdict-fail { color: #b30000; font-weight: bold; }
@media (prefers-color-scheme: dark) {
  th { background: #2a2a2a; }
  tr.details { background: #1c1c1c; }
  pre { background: #161616; border-color: #333; }
  .meta { color: #aaa; }
}
'@

    $js = @'
(function () {
  var data = JSON.parse(document.getElementById('data').textContent);
  var tbody = document.getElementById('rows');
  var search = document.getElementById('search');
  var sortKey = 'stimulusName';
  var sortDir = 1;
  var aLabel = (data.variants && data.variants.a && data.variants.a.label) || 'Variant A';
  var bLabel = (data.variants && data.variants.b && data.variants.b.label) || 'Variant B';

  function escapeHtml(s) {
    return String(s == null ? '' : s)
      .replace(/&/g, '&amp;')
      .replace(/</g, '&lt;')
      .replace(/>/g, '&gt;')
      .replace(/"/g, '&quot;')
      .replace(/'/g, '&#39;');
  }

  function verdictGlyph(s) {
    if (s.identicalTotal === 0) return '<span class="verdict-warn">?</span>';
    var pct = s.identicalCount / s.identicalTotal;
    if (pct === 1 && s.baselinePassRate === s.customizedPassRate) return '<span class="verdict-pass">=</span>';
    if (pct >= 0.8) return '<span class="verdict-warn">~</span>';
    return '<span class="verdict-fail">!=</span>';
  }

  function renderRows() {
    var filter = search.value.toLowerCase();
    var rows = data.stimuli.filter(function (s) {
      return !filter || s.stimulusName.toLowerCase().indexOf(filter) !== -1;
    }).slice().sort(function (a, b) {
      var av = a[sortKey], bv = b[sortKey];
      if (typeof av === 'string') return av.localeCompare(bv) * sortDir;
      return ((av || 0) - (bv || 0)) * sortDir;
    });
    tbody.innerHTML = rows.map(function (s, i) {
      var trials = (s.trials || []).map(function (t) {
        var bi = t.baseline || {};
        var ci = t.customized || {};
        var detailsHtml = ['code', 'llm', 'human', 'other'].map(function (kind) {
          var bg = (bi.details && bi.details[kind]) || [];
          var cg = (ci.details && ci.details[kind]) || [];
          if (bg.length === 0 && cg.length === 0) return '';
          var fmt = function (g) {
            return '<div class="grader">' + escapeHtml(g.name || '') +
              ' &mdash; passed=' + escapeHtml(g.passed) +
              ' score=' + escapeHtml(g.score) +
              (g.evidence ? ' <em>' + escapeHtml(g.evidence) + '</em>' : '') +
              '</div>';
          };
          return '<div class="kind-group"><h4>' + escapeHtml(kind) + '</h4>' +
            '<div><strong>' + escapeHtml(aLabel) + ':</strong>' + bg.map(fmt).join('') + '</div>' +
            '<div><strong>' + escapeHtml(bLabel) + ':</strong>' + cg.map(fmt).join('') + '</div></div>';
        }).join('');
        return '<div><strong>Trial ' + t.trial + '</strong>' + detailsHtml +
          '<div class="diff"><div><h5>' + escapeHtml(aLabel) + ' output</h5><pre>' + escapeHtml(bi.output || '') + '</pre></div>' +
          '<div><h5>' + escapeHtml(bLabel) + ' output</h5><pre>' + escapeHtml(ci.output || '') + '</pre></div></div></div>';
      }).join('<hr/>');

      return '<tr class="summary" data-i="' + i + '">' +
        '<td>' + escapeHtml(s.stimulusName) + '</td>' +
        '<td>' + (s.baselinePassRate * 100).toFixed(1) + '%</td>' +
        '<td>' + (s.customizedPassRate * 100).toFixed(1) + '%</td>' +
        '<td>' + s.identicalCount + '/' + s.identicalTotal + '</td>' +
        '<td>' + s.ties + '</td><td>' + s.aWins + '</td><td>' + s.bWins + '</td>' +
        '<td>' + s.meanWallTimeDeltaMs + '</td>' +
        '<td>' + s.meanTokenDelta + '</td>' +
        '<td>' + verdictGlyph(s) + '</td>' +
        '</tr>' +
        '<tr class="details" data-i="' + i + '"><td colspan="10">' + trials + '</td></tr>';
    }).join('');
  }

  tbody.addEventListener('click', function (e) {
    var tr = e.target.closest('tr.summary');
    if (!tr) return;
    var i = tr.getAttribute('data-i');
    var det = tbody.querySelector('tr.details[data-i="' + i + '"]');
    if (det) det.classList.toggle('open');
  });

  document.querySelectorAll('th[data-key]').forEach(function (th) {
    th.addEventListener('click', function () {
      var k = th.getAttribute('data-key');
      if (sortKey === k) { sortDir = -sortDir; } else { sortKey = k; sortDir = 1; }
      renderRows();
    });
  });

  search.addEventListener('input', renderRows);
  renderRows();
})();
'@

    $html = @"
<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<title>Baseline Equivalence Dashboard &mdash; $modelEsc &mdash; $runIdEsc</title>
<style>
$css
</style>
</head>
<body>
<header>
<h1>Baseline Equivalence Dashboard</h1>
<div class="meta">Agent: <strong>$agentEsc</strong> &middot; Model: <strong>$modelEsc</strong> &middot; Run: <strong>$runIdEsc</strong> &middot; Generated: $genEsc</div>
<div class="totals">
<div>Stimuli: <strong>$totalStimuli</strong></div>
<div>Total trials: <strong>$totalTrials</strong></div>
<div>Identical outputs: <strong>${identicalPct}%</strong></div>
</div>
<div class="variant-strip">
<div class="variant-card">
<div><strong>Variant A &mdash; $aLabelEsc</strong> <span class="variant-kind">[$aKindEsc]</span></div>
<div class="variant-desc">$aDescEsc</div>
<div class="variant-applied"><div>Applied:</div><ul>$aAppliedList</ul></div>
</div>
<div class="variant-card">
<div><strong>Variant B &mdash; $bLabelEsc</strong> <span class="variant-kind">[$bKindEsc]</span></div>
<div class="variant-desc">$bDescEsc</div>
<div class="variant-applied"><div>Applied:</div><ul>$bAppliedList</ul></div>
</div>
</div>
</header>
<input id="search" type="search" placeholder="filter stimuli&hellip;">
<table>
<thead><tr>
<th data-key="stimulusName">Stimulus</th>
<th data-key="baselinePassRate">$aLabelEsc pass</th>
<th data-key="customizedPassRate">$bLabelEsc pass</th>
<th data-key="identicalCount">Identical</th>
<th data-key="ties">Ties</th>
<th data-key="aWins">$aLabelEsc wins</th>
<th data-key="bWins">$bLabelEsc wins</th>
<th data-key="meanWallTimeDeltaMs">Wall &Delta; (ms)</th>
<th data-key="meanTokenDelta">Tokens &Delta;</th>
<th>Verdict</th>
</tr></thead>
<tbody id="rows"></tbody>
</table>
<script id="data" type="application/json">$json</script>
<script>
$js
</script>
</body>
</html>
"@

    return $html
}

function Get-AppliedArtifacts {
    <#
    .SYNOPSIS
        Discovers the customization artifacts materialized under a workspace root.
    .PARAMETER WorkspaceRoot
        Absolute path to the materialized customized workspace (typically
        evals/baseline-equivalence/customized/workspace). When missing, empty,
        or not a directory the function returns an empty array without erroring.
    .OUTPUTS
        System.String[] of workspace-relative artifact paths using forward
        slashes, sorted and de-duplicated by exact path.
    .EXAMPLE
        Get-AppliedArtifacts -WorkspaceRoot 'C:/repo/evals/baseline-equivalence/customized/workspace'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$WorkspaceRoot
    )

    if ([string]::IsNullOrWhiteSpace($WorkspaceRoot)) { return @() }
    if (-not (Test-Path -LiteralPath $WorkspaceRoot -PathType Container)) { return @() }

    $kinds = @(
        @{ Anchor = '.github/agents';       Filter = '*.agent.md' },
        @{ Anchor = '.github/skills';       Filter = 'SKILL.md' },
        @{ Anchor = '.github/instructions'; Filter = '*.instructions.md' },
        @{ Anchor = '.github/prompts';      Filter = '*.prompt.md' }
    )

    $relatives = New-Object 'System.Collections.Generic.List[string]'
    foreach ($kind in $kinds) {
        $anchorPath = Join-Path $WorkspaceRoot $kind.Anchor
        if (-not (Test-Path -LiteralPath $anchorPath -PathType Container)) { continue }
        $files = Get-ChildItem -LiteralPath $anchorPath -Recurse -Filter $kind.Filter -File -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $rel = [IO.Path]::GetRelativePath($WorkspaceRoot, $file.FullName) -replace '\\', '/'
            $relatives.Add($rel)
        }
    }

    return @($relatives | Sort-Object -Unique)
}

Export-ModuleMember -Function `
    Measure-CompareTrials, `
    Measure-InvariantFailures, `
    Get-VerdictFromAggregate, `
    Get-OutputHash, `
    ConvertFrom-EquivalenceResults, `
    Merge-EquivalenceStimuli, `
    Edit-HtmlEscape, `
    Get-VariantMetadata, `
    ConvertTo-EquivalenceHtml, `
    Get-AppliedArtifacts
