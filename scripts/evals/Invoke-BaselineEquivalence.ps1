#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Runs the Vally baseline-vs-customized equivalence suite for a target hve-core agent.

.DESCRIPTION
    Drives the `evals/baseline-equivalence/` Vally suite end-to-end. Resolves the target
    agent's frontmatter `model:` hint, selects a model tier, invokes `vally eval` once
    per environment (`baseline` and the materialized agent context), invokes
    `vally compare` to produce comparison JSONL, and writes a machine-readable summary
    to `logs/baseline-equivalence-summary.json`.

    Exit policy by tier:
    - `devloop` always exits 0. Failing gates surface as `verdict: warn` in the
      summary JSON. Advisory only.
    - `ci` exits non-zero (1) when `verdict == fail`. Source of truth.

    `-WhatIf` (dry-run) mode prints the planned `vally` command lines, emits a summary
    JSON populated with zeros and `verdict: dry-run`, and exits 0 without invoking any
    SDK or external command.

.PARAMETER Agent
    The target agent slug, matching the basename of an `.agent.md` file under
    `.github/agents/`. Defaults to `rpi-agent`.

.PARAMETER Tier
    The harness mode. `devloop` runs a single primary model and stays advisory; `ci`
    runs a model array for broader coverage and is authoritative. Defaults to `devloop`.
    The former `pr` and `nightly` names are rejected with a migration message rather
    than aliased, so a stale caller fails loudly instead of silently selecting a
    different exit policy.

.PARAMETER Model
    Optional explicit model id for the `devloop` tier. When supplied it overrides the
    agent's frontmatter `model:` hint and the built-in default, letting callers pin a
    cheaper model for advisory runs. Ignored for the `ci` tier, which always runs its
    fixed model array of `gpt-5.6-luna` and `claude-sonnet-4.6`.

.PARAMETER ComparisonJudgeModel
    Model used as the `vally compare` judge. Defaults to `claude-haiku-4.5`.

.PARAMETER ComparisonSpecPath
    Repository-relative path to the comparison-judging contract passed to
    `vally compare --eval-spec`. Defaults to
    `evals/baseline-equivalence/compare.eval.yml`.

.PARAMETER RepoRoot
    Repository root. Defaults to the result of `git rev-parse --show-toplevel`, falling
    back to the parent of `$PSScriptRoot`.

.PARAMETER OutputPath
    Path to the summary JSON. Defaults to `<RepoRoot>/logs/baseline-equivalence-summary.json`.

.PARAMETER NoBaselineCache
    Bypasses both baseline cache lookup and cache persistence, forcing a fresh baseline
    run for every model. Because the baseline is otherwise reused across agents, this
    switch materially increases model-backed execution time and cost; use it when a
    cached baseline is suspect rather than as a default.

.EXAMPLE
    ./Invoke-BaselineEquivalence.ps1 -Agent rpi-agent -Tier devloop -WhatIf

    Prints the planned commands and writes a dry-run summary.

.EXAMPLE
    npm run ci:eval:equivalence -- -Agent rpi-agent -Tier devloop

    Runs the advisory flow via the npm wrapper.

.NOTES
    Runs via: npm run ci:eval:equivalence
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    # Constrained to the only subject this corpus can score. Every customized stimulus
    # and the invocation-evidence default target the RPI Agent, so another subject would
    # stage, spend model budget, and then fail for reasons unrelated to equivalence.
    [Parameter(Mandatory = $false)]
    [ValidateSet('rpi-agent')]
    [string]$Agent = 'rpi-agent',

    [Parameter(Mandatory = $false)]
    [string]$Tier = 'devloop',

    [Parameter(Mandatory = $false)]
    [string]$Model,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    # The comparison judge is pinned here where it is visible to any operator reading
    # the invocation rather than buried in a spec the driver rendered at run time.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ComparisonJudgeModel = 'claude-haiku-4.5',

    # Comparison judging reads the stimulus rubric. Without this spec, vally falls back
    # to the rubric embedded in the baseline trajectory and then to a general-purpose
    # preference rubric that asks which response is better. Preference judging cannot
    # measure equivalence, because two runs of one configuration still produce
    # different text and the judge still picks a winner.
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$ComparisonSpecPath = 'evals/baseline-equivalence/compare.eval.yml',

    [Parameter(Mandatory = $false)]
    [switch]$NoBaselineCache
)

$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'lib/EquivalenceParsing.psm1') -Force
Import-Module -Name (Join-Path $PSScriptRoot 'lib/EquivalenceEnvironment.psm1') -Force

#region Helper Functions

function Assert-SupportedTier {
    <#
    .SYNOPSIS
        Validates the harness mode and rejects the retired tier names by name.
    .DESCRIPTION
        A ValidateSet would reject `pr` and `nightly` with a generic enumeration error
        that says nothing about why they stopped working or what replaced them. The two
        names also carried different exit policies, so a caller left on the old
        vocabulary would otherwise discover the change through a surprising exit code.

        No alias is provided deliberately. `pr` mapping silently to `devloop` would let
        a stale CI caller keep running while reporting a mode that no longer exists.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Tier
    )

    $supported = @('devloop', 'calibration', 'ci')
    if ($supported -contains $Tier) { return }

    $migrated = @{ 'pr' = 'devloop'; 'nightly' = 'ci' }
    if ($migrated.ContainsKey($Tier)) {
        throw "Tier '$Tier' was renamed. Use '-Tier $($migrated[$Tier])' instead. The advisory mode is now 'devloop' and the authoritative mode is now 'ci'; no alias is provided so a stale caller cannot silently select a different exit policy."
    }

    throw "Unsupported tier '$Tier'. Supported values are: $($supported -join ', ')."
}

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [string]$Hint
    )

    if ($Hint) { return (Resolve-Path -LiteralPath $Hint).Path }

    $gitRoot = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
        return $gitRoot.Trim()
    }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).Path
}

function Get-AgentModelHint {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string]$Agent
    )

    $agentsRoot = Join-Path $RepoRoot '.github/agents'
    if (-not (Test-Path -LiteralPath $agentsRoot)) { return $null }

    $candidate = Get-ChildItem -Path $agentsRoot -Recurse -Filter "$Agent.agent.md" -File -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $candidate) { return $null }

    $match = Select-String -Path $candidate.FullName -Pattern '^\s*model\s*:\s*(.+)\s*$' -List
    if (-not $match) { return $null }

    return $match.Matches[0].Groups[1].Value.Trim().Trim('"').Trim("'")
}

function Resolve-ModelList {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string]$Tier,
        [string]$Hint,
        [string]$ModelOverride
    )

    if ($Tier -in @('calibration', 'ci')) {
        # Two standard-tier models rather than a premium sweep. `gpt-5.5` carried a
        # 7.5x cost multiplier for no measured gain in cross-vendor signal, and
        # `claude-sonnet-latest` produced no trajectories at all, so a floating alias
        # is pinned to an explicit version that the suite has actually executed.
        return @('gpt-5.6-luna', 'claude-sonnet-4.6')
    }

    if ($ModelOverride) { return @($ModelOverride) }
    if ($Hint) { return @($Hint) }
    return @('gpt-5.6-luna')
}

function Get-DiagnosticSample {
    <#
    .SYNOPSIS
        Reduces a diagnostic list to distinct messages with occurrence counts.
    .DESCRIPTION
        The summary caps how many diagnostics it records so a large run cannot produce
        an unbounded artifact. Applying that cap to the raw list truncates by position,
        so one high-volume category can consume every slot and hide the categories that
        follow it. A run where invariant failures filled the cap reported no judge-error
        diagnostic at all even though every judge call had failed.

        Collapsing repeats first keeps one entry per distinct message and carries the
        repeat count, so the cap bounds the number of distinct categories rather than
        the number of occurrences.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyCollection()]
        [string[]]$Diagnostics,
        [Parameter(Mandatory = $false)]
        [int]$Max = 50
    )

    $grouped = @($Diagnostics | Group-Object | Sort-Object -Property Count -Descending)
    $sample = foreach ($group in ($grouped | Select-Object -First $Max)) {
        if ($group.Count -gt 1) { "$($group.Name) (x$($group.Count))" } else { $group.Name }
    }
    $sample = @($sample)
    if ($grouped.Count -gt $Max) {
        $sample += "... $($grouped.Count - $Max) further distinct diagnostic(s) omitted."
    }
    return $sample
}

function New-DryRunSummary {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$Agent,
        [Parameter(Mandatory)]
        [string]$Tier,
        [Parameter(Mandatory)]
        [string]$Model,
        [Parameter(Mandatory)]
        [string[]]$PlannedCommands,
        [hashtable]$Variants
    )

    return [ordered]@{
        schemaVersion            = '2.1.0'
        agent                    = $Agent
        tier                     = $Tier
        model                    = $Model
        runs                     = 0
        ties                     = 0
        baselineWins             = 0
        treatmentWins            = 0
        meanScore                = 0.0
        ciLow                    = 0.0
        ciHigh                   = 0.0
        winRate                  = 0.0
        invariantFailures        = 0
        runHealthFailures        = 0
        invocationEvidence       = @()
        invocationFailures       = 0
        comparisonCalibration    = @()
        comparisonStatus         = 'dry-run'
        divergenceGuardFailures  = 0
        equivalenceGate          = 'dry-run'
        documentedDivergenceGate = 'dry-run'
        verdict                  = 'dry-run'
        variants                 = $Variants
        plannedCommands          = $PlannedCommands
    }
}

function Test-CustomizationCollapse {
    <#
    .SYNOPSIS
        Reports whether every evaluated divergence guard failed.
    .DESCRIPTION
        Divergence guards assert behavior only the customization layer can produce.
        Some failing is an ordinary behavioral result. All of them failing means the
        customized variant never received its customization and ran as the baseline,
        which otherwise presents as equivalence rather than as an error.

        Distinguished from a partial failure deliberately: a check that fired on any
        failure would flag normal runs and would be silenced, and one that fired on
        zero evaluated guards would flag runs that simply declared none.
    .OUTPUTS
        [bool] True when the run collapsed to baseline behavior.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [int]$Evaluated,

        [Parameter(Mandatory)]
        [int]$Failed
    )

    return ($Evaluated -gt 0 -and $Failed -eq $Evaluated)
}

function Invoke-VallyCommand {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments
    )

    & vally @Arguments
    return $LASTEXITCODE
}

function Invoke-VallyCommandWithCapture {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Arguments,
        [string]$LogPath
    )

    $prev = [Console]::OutputEncoding
    try {
        [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
        $raw = & vally @Arguments 2>&1
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
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
        Set-Content -LiteralPath $LogPath -Value $lines -Encoding utf8NoBOM
    }

    return @{ ExitCode = $code; Lines = $lines }
}

function Get-CanonicalStimulusPolicy {
    <#
    .SYNOPSIS
        Reads comparison policy and declared invariants from the canonical library.
    .DESCRIPTION
        The comparison JSONL identifies stimuli by name only, so policy and invariant
        membership have to come from `stimuli.yml`. Without them the parser would count
        intentional divergence against equivalence, and the invariant tally would fall
        back to every deterministic grader rather than the ones actually declared.

        Flat name lists answer "did a declared grader fail" but not "was every declared
        grader evaluated". The per-stimulus manifests carry that second question, so a
        declared grader that never produced a result is distinguishable from one that
        ran and passed.
    .OUTPUTS
        [hashtable] With keys Policy (name to policy), Invariants (unique names),
        Guards (unique customized_required and customized_disallow grader names),
        InvariantManifest (stimulus to declared invariant names), and GuardManifest
        (stimulus to declared guard names).
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot
    )

    $result = @{ Policy = @{}; Invariants = @(); Guards = @(); InvariantManifest = @{}; GuardManifest = @{} }
    $path = Join-Path $RepoRoot 'evals/baseline-equivalence/stimuli.yml'
    # An empty result is not a neutral degradation: every stimulus falls through to an
    # empty policy, all trials book to divergence, and both gates fail with diagnostics
    # that blame the customization instead of naming this file. Fail loudly instead.
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Canonical stimulus library not found at '$path'."
    }

    try {
        $parsed = ConvertFrom-Yaml (Get-Content -LiteralPath $path -Raw)
    }
    catch {
        throw "Canonical stimulus library at '$path' could not be parsed: $($_.Exception.Message)"
    }

    $invariants = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $guards = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($stimulus in @($parsed.stimuli)) {
        if (-not $stimulus) { continue }
        $name = [string]$stimulus.name
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $policy = ''
        if ($stimulus.ContainsKey('tags') -and $stimulus.tags -and $stimulus.tags.Contains('policy')) {
            $policy = [string]$stimulus.tags['policy']
        }
        $result.Policy[$name] = $policy

        if ($stimulus.ContainsKey('invariants') -and $stimulus.invariants) {
            $perStimulus = [System.Collections.Generic.List[string]]::new()
            foreach ($invariant in @($stimulus.invariants)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$invariant)) {
                    [void]$invariants.Add([string]$invariant)
                    $perStimulus.Add([string]$invariant)
                }
            }
            if ($perStimulus.Count -gt 0) { $result.InvariantManifest[$name] = @($perStimulus) }
        }

        # The divergence gate asserts that declared customization guards actually held.
        # Both kinds belong: customized_required asserts a behavior the customization
        # mandates, and customized_disallow asserts one it must not produce. Either
        # failing means the customization did not behave as documented.
        $perStimulusGuards = [System.Collections.Generic.List[string]]::new()
        foreach ($key in @('customized_required', 'customized_disallow')) {
            if ($stimulus.ContainsKey($key) -and $stimulus[$key]) {
                foreach ($guard in @($stimulus[$key])) {
                    if (-not [string]::IsNullOrWhiteSpace([string]$guard)) {
                        [void]$guards.Add([string]$guard)
                        $perStimulusGuards.Add([string]$guard)
                    }
                }
            }
        }
        if ($perStimulusGuards.Count -gt 0) { $result.GuardManifest[$name] = @($perStimulusGuards) }
    }

    $result.Invariants = @($invariants)
    $result.Guards = @($guards)
    return $result
}

function Get-EffectiveTrialCount {
    <#
    .SYNOPSIS
        Reads the effective per-stimulus trial count from an executable eval spec.
    .DESCRIPTION
        Expected result cardinality is the declared grader multiplied by the number of
        trials the spec actually runs. Hard-coding that multiplier would make the
        coverage check silently wrong the moment the run count is tuned, which the
        equivalence policy expects to happen during calibration.
    .OUTPUTS
        [int] The configured run count.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory)]
        [string]$SpecPath
    )

    # A silent fallback to 1 against a spec declaring runs: N makes the coverage check
    # report N-1 surplus instances for every declared grader, filling dataQualityViolations
    # with reports that describe a healthy run.
    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) {
        throw "Executable eval spec not found at '$SpecPath'."
    }

    try {
        $spec = ConvertFrom-Yaml (Get-Content -LiteralPath $SpecPath -Raw)
    }
    catch {
        throw "Executable eval spec at '$SpecPath' could not be parsed: $($_.Exception.Message)"
    }

    if ($spec -and $spec.ContainsKey('defaults') -and $spec.defaults -and $spec.defaults.ContainsKey('runs')) {
        $runs = [int]$spec.defaults.runs
        if ($runs -gt 0) { return $runs }
    }

    return 1
}

function Get-InvariantFailureCount {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$RunDir
    )

    if (-not $RunDir -or -not (Test-Path -LiteralPath $RunDir)) { return $null }
    $resultsMd = Join-Path $RunDir 'eval-results.md'
    if (-not (Test-Path -LiteralPath $resultsMd)) { return $null }
    try {
        $lines = Get-Content -LiteralPath $resultsMd -ErrorAction Stop
    }
    catch {
        return $null
    }
    $tally = Measure-InvariantFailures -Lines $lines
    if ($tally.Total -le 0) { return $null }
    return [int]$tally.Failed
}

function Get-PlannedCommands {
    <#
    .SYNOPSIS
        Renders the vally commands a run would issue, one set per model.
    .DESCRIPTION
        The customized skill directory is derived per model rather than accepted as a
        single path. Each model materializes its own surface, so rendering one shared
        path would make dry-run output disagree with the live invocation for every
        model after the first, which is exactly the mismatch that let the `ci` sweep
        evaluate later models against the first model's surface.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Models,
        [Parameter(Mandatory)]
        [string]$OutputRoot,
        [Parameter(Mandatory)]
        [string]$RunId,
        [Parameter(Mandatory)]
        [string]$JudgeModel,
        [Parameter(Mandatory)]
        [string]$ComparisonSpec,
        [string]$BaselineWorkspacePath,
        [string]$BaselineSkillDirPath,
        [string]$CustomizedWorkspacePath
    )

    $plan = [System.Collections.Generic.List[string]]::new()
    foreach ($model in $Models) {
        $aDir = Join-Path $OutputRoot "$model/$RunId/baseline"
        $bDir = Join-Path $OutputRoot "$model/$RunId/customized"
        $customizedSkillDirPath = Join-Path $OutputRoot "$model/$RunId/customized-skill-dir"
        $baselineWorkspaceArg = if ([string]::IsNullOrEmpty($BaselineWorkspacePath)) { '""' } else { '"' + $BaselineWorkspacePath + '"' }
        $baselineSkillArg = if ([string]::IsNullOrEmpty($BaselineSkillDirPath)) { '""' } else { '"' + $BaselineSkillDirPath + '"' }
        $customizedWorkspaceArg = if ([string]::IsNullOrEmpty($CustomizedWorkspacePath)) { '""' } else { '"' + $CustomizedWorkspacePath + '"' }
        $customizedSkillArg = '"' + $customizedSkillDirPath + '"'
        $plan.Add("vally eval --eval-spec evals/baseline-equivalence/baseline/eval.yaml --model $model --output-dir $aDir --workspace $baselineWorkspaceArg --skill-dir $baselineSkillArg")
        $plan.Add("vally eval --eval-spec evals/baseline-equivalence/customized/eval.yaml --model $model --output-dir $bDir --workspace $customizedWorkspaceArg --skill-dir $customizedSkillArg")
        $plan.Add("vally compare --eval-spec $ComparisonSpec --judge-model $JudgeModel --baseline <resolved baseline run> --treatment <resolved customized run> --output <compare jsonl path>")
    }
    return $plan.ToArray()
}

function Resolve-LatestRunDir {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$OutputDir
    )

    if (-not (Test-Path -LiteralPath $OutputDir)) { return $null }
    $latest = Get-ChildItem -LiteralPath $OutputDir -Directory -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending |
        Select-Object -First 1
    if (-not $latest) { return $null }
    return $latest.FullName
}

function Test-CustomizedInvocationRetryEligibility {
    <#
    .SYNOPSIS
        Determines whether one complete customized GPT calibration retry is allowed.
    .DESCRIPTION
        The retry is limited to the first customized GPT calibration attempt when the
        validated baseline is structurally complete and the only customized invocation
        defect is one failed exact read represented by one failed and one missing count.
        Every other invocation defect remains immediately authoritative.
    .OUTPUTS
        [bool] True only for the single approved retry condition.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Tier,

        [Parameter(Mandatory = $true)]
        [string]$Model,

        [Parameter(Mandatory = $true)]
        [int]$Attempt,

        [Parameter(Mandatory = $true)]
        [bool]$BaselineHasSignal,

        [Parameter(Mandatory = $true)]
        [int]$BaselineStructural,

        [Parameter(Mandatory = $true)]
        [hashtable]$InvocationTally
    )

    if ($Tier -ne 'calibration' -or $Model -ne 'gpt-5.6-luna' -or $Attempt -ne 1) { return $false }
    if (-not $BaselineHasSignal -or $BaselineStructural -ne 0) { return $false }
    if ($InvocationTally.Expected -le 0 -or $InvocationTally.Observed -ne ($InvocationTally.Expected - 1)) { return $false }
    if ([string]::IsNullOrWhiteSpace([string]$InvocationTally.FailedKey) -or
        $InvocationTally.ReasonCode -notin @(
            'failed-tool-result',
            'missing-correlated-result',
            'successful-result-without-agent-marker'
        )) { return $false }

    return [int]$InvocationTally.Failed -eq 1 -and
        [int]$InvocationTally.Missing -eq 1 -and
        [int]$InvocationTally.Duplicate -eq 0 -and
        [int]$InvocationTally.WrongPath -eq 0 -and
        [int]$InvocationTally.Malformed -eq 0
}

function Write-SummaryJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Summary,
        [Parameter(Mandatory)]
        [string]$Path
    )

    $dir = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force -WhatIf:$false -Confirm:$false | Out-Null
    }

    $json = $Summary | ConvertTo-Json -Depth 6
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8NoBOM -WhatIf:$false -Confirm:$false
}

#endregion Helper Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        Assert-SupportedTier -Tier $Tier

        $resolvedRoot = Resolve-RepoRoot -Hint $RepoRoot
        if (-not $OutputPath) {
            $OutputPath = Join-Path $resolvedRoot 'logs/baseline-equivalence-summary.json'
        }

        # Compare output, compare logs, and the summary all land under logs/. Create it
        # up front rather than relying on some earlier step to have made it as a side
        # effect, which is how a missing directory previously surfaced as a late and
        # confusing WriteAllText failure partway through a run.
        $logsRoot = Join-Path $resolvedRoot 'logs'
        if (-not (Test-Path -LiteralPath $logsRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $logsRoot -Force -WhatIf:$false -Confirm:$false | Out-Null
        }

        $modelHint = Get-AgentModelHint -RepoRoot $resolvedRoot -Agent $Agent
        $models = @(Resolve-ModelList -Tier $Tier -Hint $modelHint -ModelOverride $Model)
        $primaryModel = $models[0]

        # The comparison contract is resolved before any model-backed work so a missing
        # or moved spec fails immediately rather than after a full executor sweep has
        # already been paid for.
        $comparisonSpecFullPath = Join-Path $resolvedRoot $ComparisonSpecPath
        if (-not (Test-Path -LiteralPath $comparisonSpecFullPath -PathType Leaf)) {
            throw "Comparison spec not found at '$ComparisonSpecPath'. `vally compare` would fall back to a preference rubric that cannot measure equivalence."
        }

        $outputRoot = Join-Path $resolvedRoot 'evals/results/baseline-equivalence'
        $runId = (Get-Date -AsUTC).ToString('yyyyMMddTHHmmssfffZ')

        $defaultVariantA = @{ kind = 'baseline'; name = 'baseline';   label = 'Baseline (A)';   description = ''; applied = @() }
        $defaultVariantB = @{ kind = 'agent';    name = $Agent;       label = $Agent;            description = ''; applied = @() }
        $variantA = Get-VariantMetadata -VariantYamlPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/baseline/variant.yaml') -Default $defaultVariantA
        $variantB = Get-VariantMetadata -VariantYamlPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/variant.yaml') -Default $defaultVariantB
        $workspaceRoot = Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/workspace'
        # vally owns this tree and recreates it per trial, but it must exist before the
        # invocation: it carries no tracked placeholder, so a clean checkout has no such
        # directory and the customized run would receive a nonexistent --workspace.
        if (-not (Test-Path -LiteralPath $workspaceRoot -PathType Container)) {
            New-Item -ItemType Directory -Path $workspaceRoot -Force -WhatIf:$false -Confirm:$false | Out-Null
        }
        # The surface is staged outside the workspace because vally owns the workspace
        # tree and recreates it per trial. The customized spec copies this directory
        # into each trial through environment.files.
        $surfaceRoot = Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/surface'
        $surfacePlaceholderText = 'Placeholder so this directory exists in a clean checkout; the driver rewrites the surface on every run.'
        $variantB.applied = @(Get-AppliedArtifacts -WorkspaceRoot $surfaceRoot)
        $variants = @{ a = $variantA; b = $variantB; subject = [string]$variantB.name }

        # The surface is one mutable repository path shared by every invocation, and it
        # is deleted and repopulated per agent. A second concurrent run would repopulate
        # it for a different agent while this run's trials are still reading it, so the
        # comparison would silently score a surface it did not build. An exclusive lock
        # held for the whole run makes that a fast, explicit failure instead.
        $surfaceLockPath = Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/.surface.lock'
        $surfaceLockStream = $null
        try {
            $surfaceLockStream = [System.IO.File]::Open(
                $surfaceLockPath,
                [System.IO.FileMode]::OpenOrCreate,
                [System.IO.FileAccess]::ReadWrite,
                [System.IO.FileShare]::None)
        }
        catch {
            throw "Another baseline-equivalence run holds the customization surface lock at '$surfaceLockPath'. Concurrent runs would race on the shared surface under evals/baseline-equivalence/customized/. Wait for the other run to finish, or remove the lock file if no run is active."
        }

        Write-Host "Baseline equivalence: agent=$Agent tier=$Tier model(s)=$($models -join ',')" -ForegroundColor Cyan
        Write-Host "   Summary output:  $OutputPath" -ForegroundColor DarkGray
        Write-Host "   Results root:    $outputRoot" -ForegroundColor DarkGray
        Write-Host "   Comparison spec: $ComparisonSpecPath (judge $ComparisonJudgeModel)" -ForegroundColor DarkGray
        Write-Host "   Run id:          $runId" -ForegroundColor DarkGray

        # Baseline reuse is keyed on the inputs that would change baseline behavior. A
        # cached run captured under a different Vally version must not be reused, or a
        # tooling change would be attributed to the customization under test. The version
        # is read from the lockfile rather than by invoking the CLI, because the pinned
        # dependency is what actually determines the runtime and the read cannot fail
        # partway or cost a subprocess.
        $vallyVersion = 'unknown'
        $lockPath = Join-Path $resolvedRoot 'package-lock.json'
        if (Test-Path -LiteralPath $lockPath -PathType Leaf) {
            try {
                # -AsHashtable is required: the lockfile's packages map uses an empty
                # string as the key for the root project, which ConvertFrom-Json rejects
                # when producing PSCustomObject.
                $lock = Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json -AsHashtable
                $node = $lock.packages['node_modules/@microsoft/vally-cli']
                if ($node -and $node.version) { $vallyVersion = [string]$node.version }
            }
            catch {
                # Non-fatal: an unknown version only weakens baseline cache keying, but it
                # must be visible rather than silently recorded as 'unknown'.
                Write-Error -Message "Could not read the pinned Vally version from '$lockPath': $($_.Exception.Message)" -ErrorAction Continue
            }
        }
        $baselineCacheRoot = Join-Path $resolvedRoot 'evals/results/baseline-equivalence/_baseline-cache'
        Write-Host "   Vally version:   $vallyVersion" -ForegroundColor DarkGray

        $customizedWorkspacePath = $workspaceRoot
        $plannedCommands = Get-PlannedCommands -Models $models -OutputRoot $outputRoot -RunId $runId -JudgeModel $ComparisonJudgeModel -ComparisonSpec $ComparisonSpecPath -BaselineWorkspacePath '' -BaselineSkillDirPath '' -CustomizedWorkspacePath $customizedWorkspacePath

        if ($WhatIfPreference) {
            Write-Host "Dry-run mode: skipping live SDK calls." -ForegroundColor Yellow
            foreach ($cmd in $plannedCommands) {
                Write-Host "   $cmd" -ForegroundColor DarkGray
            }

            $dry = New-DryRunSummary `
                -Agent $Agent `
                -Tier $Tier `
                -Model $primaryModel `
                -PlannedCommands $plannedCommands `
                -Variants $variants
            Write-SummaryJson -Summary $dry -Path $OutputPath
            Write-Host "Dry-run summary written: $OutputPath" -ForegroundColor Green
            exit 0
        }

        $totalRuns = 0
        $totalTies = 0
        $totalBaselineWins = 0
        $totalTreatmentWins = 0
        $invariantFailures = 0
        # Renamed from divergenceFailures. This counter only ever measured operational
        # health: nonzero exit codes, missing run directories, and unparseable output.
        # The documented-divergence gate now reads per-guard conformance instead, so the
        # counter keeps its real meaning under an honest name.
        $runHealthFailures = 0
        $divergenceGuardFailures = 0
        $divergenceGuardsEvaluated = 0
        $divergenceHasSignal = $false
        $failedDivergenceGuards = [System.Collections.Generic.List[string]]::new()
        $dataQualityViolations = 0
        $totalJudgeErrors = 0
        $totalEquivalent = 0
        $totalEquivalentTies = 0
        $totalDivergence = 0
        $dataQualityDiagnostics = [System.Collections.Generic.List[string]]::new()
        $invocationEvidence = [System.Collections.Generic.List[object]]::new()
        $invocationFailures = 0
        $comparisonCalibration = [System.Collections.Generic.List[object]]::new()

        # Policy and invariant membership come from the canonical library, because the
        # comparison JSONL identifies stimuli by name only.
        $canonical = Get-CanonicalStimulusPolicy -RepoRoot $resolvedRoot
        $canonicalPolicy = $canonical.Policy
        $canonicalInvariants = @($canonical.Invariants)
        $canonicalGuards = @($canonical.Guards)
        $invariantManifest = $canonical.InvariantManifest
        $guardManifest = $canonical.GuardManifest

        # Expected result cardinality is the declared grader multiplied by the trials the
        # spec actually runs, read from the spec so a calibration change to the run count
        # cannot silently invalidate the coverage check.
        $baselineTrials = Get-EffectiveTrialCount -SpecPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/baseline/eval.yaml')
        $customizedTrials = Get-EffectiveTrialCount -SpecPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/eval.yaml')
        Write-Host "   Canonical policy: $($canonicalPolicy.Count) stimulus/stimuli, $($canonicalInvariants.Count) declared invariant(s), $($canonicalGuards.Count) divergence guard(s)" -ForegroundColor DarkGray
        Write-Host "   Expected coverage: $($invariantManifest.Count) invariant stimulus/stimuli x $baselineTrials trial(s), $($guardManifest.Count) guard stimulus/stimuli x $customizedTrials trial(s)" -ForegroundColor DarkGray
        $compareLogs = [System.Collections.Generic.List[string]]::new()
        $meanScores = [System.Collections.Generic.List[double]]::new()
        $winRates = [System.Collections.Generic.List[double]]::new()
        $ciLows = [System.Collections.Generic.List[double]]::new()
        $ciHighs = [System.Collections.Generic.List[double]]::new()

        foreach ($model in $models) {
            $aDir = Join-Path $outputRoot "$model/$runId/baseline"
            $bDir = Join-Path $outputRoot "$model/$runId/customized"
            $baselineWorkspacePath = Join-Path $outputRoot "$model/$runId/baseline-workspace"
            $baselineSkillDirPath = Join-Path $outputRoot "$model/$runId/baseline-skill-dir"
            foreach ($dir in @($aDir, $bDir, $baselineWorkspacePath, $baselineSkillDirPath)) {
                if (-not (Test-Path -LiteralPath $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
            }
            foreach ($dir in @($baselineWorkspacePath, $baselineSkillDirPath)) {
                if (Test-Path -LiteralPath $dir) {
                    Get-ChildItem -LiteralPath $dir -Force | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
            foreach ($dir in @($aDir, $bDir)) {
                if (-not (Test-Path -LiteralPath $dir)) {
                    New-Item -ItemType Directory -Path $dir -Force | Out-Null
                }
            }

            # The customized side must be specific to the agent under test. Passing the
            # whole skills tree would load every skill for every agent, so two different
            # agents would produce identical customized runs and the comparison could not
            # tell them apart.
            $customizedSkillDirForModel = Join-Path $outputRoot "$model/$runId/customized-skill-dir"
            # Rebuilt from scratch each run so an artifact removed from the agent's
            # dependency set does not linger and keep influencing later comparisons.
            if (Test-Path -LiteralPath $surfaceRoot) {
                Remove-Item -LiteralPath $surfaceRoot -Recurse -Force -ErrorAction SilentlyContinue
            }
            $surfaceGitHub = Join-Path $surfaceRoot '.github'
            New-Item -ItemType Directory -Path $surfaceRoot -Force | Out-Null
            try {
                $customized = New-CustomizedEnvironment `
                    -RepoRoot $resolvedRoot `
                    -Agent $Agent `
                    -WorkspacePath $surfaceRoot `
                    -SkillDirPath $customizedSkillDirForModel
                $variantB.applied = @($customized.Applied)
                $variants.b = $variantB
                Write-Host "   Customized surface: $($customized.Applied.Count) artifact(s)" -ForegroundColor DarkGray
            }
            catch {
                # A customized environment that cannot be built is a divergence failure,
                # not a crash. Recording it keeps the summary readable and lets the
                # verdict reflect the problem instead of losing the run entirely.
                Write-Host "   Customized environment not materialized: $($_.Exception.Message)" -ForegroundColor Yellow
                $runHealthFailures++
                if (-not (Test-Path -LiteralPath $customizedSkillDirForModel)) {
                    New-Item -ItemType Directory -Path $customizedSkillDirForModel -Force | Out-Null
                }
            }
            finally {
                # Materialization clears this tree, so the tracked placeholder is restored
                # after it rather than before. vally's spec linter resolves the path, so a
                # completed or aborted run must both leave the directory present and the
                # working tree clean.
                New-Item -ItemType Directory -Path $surfaceGitHub -Force -WhatIf:$false -Confirm:$false | Out-Null
                Set-Content -LiteralPath (Join-Path $surfaceGitHub '.gitkeep') -Value $surfacePlaceholderText -Encoding utf8NoBOM
            }

            # Both specs seed their trials from this fixture through environment.files.
            # The hash keys the baseline cache, so a baseline captured before a seed
            # change is not reused against a customized run that saw the new content.
            $seedPath = Join-Path $resolvedRoot 'evals/baseline-equivalence/seed-workspace'
            $stimulusHash = Get-StimulusContentHash -SpecPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/baseline/eval.yaml') -SeedPath $seedPath
            $cacheKey = Get-BaselineCacheKey -Model $model -VallyVersion $vallyVersion -StimulusHash $stimulusHash
            $baselineRunDir = $null
            $baselineReused = $false
            if (-not $NoBaselineCache) {
                $baselineRunDir = Get-BaselineCacheEntry -CacheRoot $baselineCacheRoot -CacheKey $cacheKey
                if ($baselineRunDir) {
                    $baselineReused = $true
                    Write-Host "   Baseline: reusing cached run for $model (vally $vallyVersion)" -ForegroundColor DarkGray
                }
            }

            # The scope-language guard asserts the customized run names its own tracking
            # directory. Both eval specs are shared across every agent, so the guard is
            # always present and the per-agent value arrives through --param. An agent
            # that writes no tracking artifacts is exempt and reports as such, because a
            # vacuous guard that passed silently would repeat the defect this replaced.
            # The customization-boundary guards assert that the customized run does not
            # claim it performed a prohibited write. They are declared inline per
            # stimulus and need no per-agent parameter. Resolve-AgentScopePattern is
            # retained for the stage 2 subject-aware guard work rather than invoked here,
            # because a parameter no spec consumes would report a guard that never ran.
            $evalBaseline = @(
                'eval',
                '--eval-spec', 'evals/baseline-equivalence/baseline/eval.yaml',
                '--model', $model,
                '--output-dir', $aDir,
                '--workspace', $baselineWorkspacePath,
                '--skill-dir', $baselineSkillDirPath
            )
            $evalCustomized = @(
                'eval',
                '--eval-spec', 'evals/baseline-equivalence/customized/eval.yaml',
                '--model', $model,
                '--output-dir', $bDir,
                '--workspace', $workspaceRoot,
                '--skill-dir', $customizedSkillDirForModel
            )

            if ($baselineReused) {
                # A reused baseline was already graded when it was captured. Its invariant
                # tally is re-read from the cached run so the verdict still accounts for it.
                $baselineTally = Measure-DeclaredInvariantFailures -RunDir $baselineRunDir -InvariantNames $canonicalInvariants -ExpectedManifest $invariantManifest -ExpectedTrials $baselineTrials
                if ($baselineTally.HasSignal) {
                    $invariantFailures += $baselineTally.Failed
                }
                else {
                    # A cached baseline that yields no invariant signal is unusable, not
                    # clean. Treating it as zero failures would let a corrupted cache
                    # entry silently pass every later agent.
                    $dataQualityViolations++
                    $dataQualityDiagnostics.Add('Cached baseline produced no invariant signal.')
                }
            }
            else {
                $codeA = Invoke-VallyCommand -Arguments $evalBaseline
                $baselineRunDir = Resolve-LatestRunDir -OutputDir $aDir
                $baselineTally = Measure-DeclaredInvariantFailures -RunDir $baselineRunDir -InvariantNames $canonicalInvariants -ExpectedManifest $invariantManifest -ExpectedTrials $baselineTrials
                if ($baselineTally.HasSignal) {
                    $invariantFailures += $baselineTally.Failed
                }
                else {
                    # Previously a missing or unparsable report read as zero failures,
                    # so a baseline that never produced a usable result looked clean.
                    $dataQualityViolations++
                    $dataQualityDiagnostics.Add('Baseline run produced no invariant signal.')
                    if ($codeA -ne 0) { $invariantFailures++ }
                }

                # A run whose declared invariant population was incomplete or malformed
                # must not become the cached baseline every later agent compares against.
                $cacheSafe = ([int]$baselineTally.MalformedRecords + [int]$baselineTally.Missing + [int]$baselineTally.Duplicate + [int]$baselineTally.Unexpected) -eq 0
                if (-not $NoBaselineCache -and $baselineRunDir -and $codeA -eq 0 -and $baselineTally.HasSignal -and $cacheSafe) {
                    $baselineRunDir = Save-BaselineCacheEntry `
                        -CacheRoot $baselineCacheRoot `
                        -CacheKey $cacheKey `
                        -RunDir $baselineRunDir `
                        -Model $model `
                        -VallyVersion $vallyVersion `
                        -StimulusHash $stimulusHash
                    Write-Host "   Baseline: cached for reuse by later agents" -ForegroundColor DarkGray
                }
            }
            # Malformed, missing, duplicate, and unexpected invariant results are
            # structural: they mean the run did not cover the declared population, so a
            # conformance claim over it would assert something never measured. Counting
            # them here also keeps an unsafe run out of the baseline cache.
            $baselineStructural = [int]$baselineTally.MalformedRecords + [int]$baselineTally.Missing + [int]$baselineTally.Duplicate + [int]$baselineTally.Unexpected
            if ($baselineStructural -gt 0) {
                $dataQualityViolations += $baselineStructural
                Write-Host "   Baseline invariant coverage: $($baselineTally.MalformedRecords) malformed, $($baselineTally.Missing) missing, $($baselineTally.Duplicate) duplicate, $($baselineTally.Unexpected) unexpected" -ForegroundColor Yellow
            }
            foreach ($diagnostic in @($baselineTally.Diagnostics)) { $dataQualityDiagnostics.Add($diagnostic) }

            $aRunDir = $baselineRunDir
            $customizedAttempt = 1
            $codeB = Invoke-VallyCommand -Arguments $evalCustomized
            $bRunDir = Resolve-LatestRunDir -OutputDir $bDir
            $invocationTally = Measure-AgentInvocationEvidence `
                -RunDir $bRunDir `
                -StimulusNames @($canonicalPolicy.Keys) `
                -ExpectedTrials $customizedTrials
            $invocationEvidence.Add([ordered]@{
                    model               = $model
                    attempt             = $customizedAttempt
                    expected            = $invocationTally.Expected
                    observed            = $invocationTally.Observed
                    failed              = $invocationTally.Failed
                    missing             = $invocationTally.Missing
                    duplicate           = $invocationTally.Duplicate
                    wrongPath           = $invocationTally.WrongPath
                    malformed           = $invocationTally.Malformed
                    failedKey           = $invocationTally.FailedKey
                    reasonCode          = $invocationTally.ReasonCode
                    hasCompleteEvidence  = $invocationTally.HasCompleteEvidence
                })

            if (Test-CustomizedInvocationRetryEligibility `
                    -Tier $Tier `
                    -Model $model `
                    -Attempt $customizedAttempt `
                    -BaselineHasSignal $baselineTally.HasSignal `
                    -BaselineStructural $baselineStructural `
                    -InvocationTally $invocationTally) {
                Write-Host '   Agent invocation: retrying one complete customized GPT calibration run after one isolated exact-read failure' -ForegroundColor Yellow
                $customizedAttempt++
                $firstCustomizedRunDir = $bRunDir
                $codeB = Invoke-VallyCommand -Arguments $evalCustomized
                $retryRunDir = Resolve-LatestRunDir -OutputDir $bDir
                $bRunDir = if ($retryRunDir -and $retryRunDir -ne $firstCustomizedRunDir) {
                    $retryRunDir
                }
                else {
                    $null
                }
                $invocationTally = Measure-AgentInvocationEvidence `
                    -RunDir $bRunDir `
                    -StimulusNames @($canonicalPolicy.Keys) `
                    -ExpectedTrials $customizedTrials
                $invocationEvidence.Add([ordered]@{
                        model               = $model
                        attempt             = $customizedAttempt
                        expected            = $invocationTally.Expected
                        observed            = $invocationTally.Observed
                        failed              = $invocationTally.Failed
                        missing             = $invocationTally.Missing
                        duplicate           = $invocationTally.Duplicate
                        wrongPath           = $invocationTally.WrongPath
                        malformed           = $invocationTally.Malformed
                        failedKey           = $invocationTally.FailedKey
                        reasonCode          = $invocationTally.ReasonCode
                        hasCompleteEvidence  = $invocationTally.HasCompleteEvidence
                    })
            }

            $modelInvocationFailures = [int]$invocationTally.Failed + [int]$invocationTally.Missing +
                [int]$invocationTally.Duplicate + [int]$invocationTally.WrongPath + [int]$invocationTally.Malformed
            $invocationFailures += $modelInvocationFailures
            if ($modelInvocationFailures -gt 0) {
                $dataQualityViolations += $modelInvocationFailures
                Write-Host "   Agent invocation: $($invocationTally.Observed) of $($invocationTally.Expected) trials have complete evidence; $modelInvocationFailures failure(s)" -ForegroundColor Yellow
            }
            else {
                Write-Host "   Agent invocation: $($invocationTally.Observed) of $($invocationTally.Expected) trials have complete evidence" -ForegroundColor DarkGray
            }
            foreach ($diagnostic in @($invocationTally.Diagnostics)) { $dataQualityDiagnostics.Add($diagnostic) }

            # The documented-divergence gate reads per-guard conformance from the
            # customized run. This is the only place those results exist: comparison
            # JSONL carries winners, not grader detail, and the run's own 0.7 scoring
            # threshold is too coarse for a single guard failure to move.
            $guardTally = Measure-DivergenceGuardResults -RunDir $bRunDir -GuardNames $canonicalGuards -ExpectedManifest $guardManifest -ExpectedTrials $customizedTrials
            if ($guardTally.HasSignal) {
                $divergenceHasSignal = $true
                $divergenceGuardFailures += $guardTally.Failed
                $divergenceGuardsEvaluated += $guardTally.Evaluated
                foreach ($failedGuard in @($guardTally.FailedGuards)) { $failedDivergenceGuards.Add($failedGuard) }
                if ($guardTally.Failed -gt 0) {
                    Write-Host "   Divergence guards: $($guardTally.Failed) of $($guardTally.Evaluated) failed" -ForegroundColor Yellow
                }
                else {
                    Write-Host "   Divergence guards: $($guardTally.Evaluated) evaluated, all passed" -ForegroundColor DarkGray
                }

                # Divergence guards assert behavior that only the customization can
                # produce, so every one of them failing is not a weak customization.
                # It means the customized variant was effectively the baseline. That
                # happens whenever the surface fails to reach the agent, which is
                # otherwise silent and reads as equivalence. Treat a total collapse as
                # a run-health failure so it is attributed to delivery rather than
                # averaged into the divergence rate as a behavioral result.
                if (Test-CustomizationCollapse -Evaluated $guardTally.Evaluated -Failed $guardTally.Failed) {
                    Write-Host "   Customization not delivered: all $($guardTally.Evaluated) divergence guard(s) failed" -ForegroundColor Red
                    $runHealthFailures++
                    $dataQualityDiagnostics.Add("All $($guardTally.Evaluated) divergence guards failed for $model; the customized variant behaved as the baseline.")
                }
            }
            else {
                Write-Host "   Divergence guards: no signal from the customized run" -ForegroundColor Yellow
                # A nonzero exit is only run-health evidence when no guard signal
                # survived. `vally eval` exits nonzero whenever any grader on any trial
                # fails, and those failures are already counted precisely as invariant
                # and guard failures. Counting the exit code as well would make
                # runHealthFailures nonzero on every run that has a single expected
                # grader failure, so the equivalence gate could never report pass. The
                # baseline path already treats its exit code this way; this keeps the
                # customized path symmetric.
                if ($codeB -ne 0) { $runHealthFailures++ }
            }
            # Guard coverage is reconciled the same way as invariants. One passing guard
            # elsewhere must not stand in for a stimulus whose guard never produced a
            # result, so an incomplete population is a data-quality violation.
            $guardStructural = [int]$guardTally.MalformedRecords + [int]$guardTally.Missing + [int]$guardTally.Duplicate + [int]$guardTally.Unexpected
            if ($guardStructural -gt 0) {
                $dataQualityViolations += $guardStructural
                Write-Host "   Divergence guard coverage: $($guardTally.MalformedRecords) malformed, $($guardTally.Missing) missing, $($guardTally.Duplicate) duplicate, $($guardTally.Unexpected) unexpected" -ForegroundColor Yellow
            }
            foreach ($diagnostic in @($guardTally.Diagnostics)) { $dataQualityDiagnostics.Add($diagnostic) }

            if (-not $aRunDir -or -not $bRunDir) {
                Write-Host "   Compare skipped: missing run dir (a=$aRunDir b=$bRunDir)" -ForegroundColor Yellow
                $runHealthFailures++
            }
            else {
                $compareJsonlPath = Join-Path $resolvedRoot "logs/vally-compare-$model-$runId.jsonl"
                # The judge and its rubric are both pinned explicitly. Omitting
                # --eval-spec would fall back to the rubric embedded in the baseline
                # trajectory, and then to a general preference rubric, which measures
                # which response is better rather than whether behavior was unchanged.
                $compareArgs = @(
                    'compare',
                    '--eval-spec', $comparisonSpecFullPath,
                    '--judge-model', $ComparisonJudgeModel,
                    '--baseline', $aRunDir,
                    '--treatment', $bRunDir,
                    '--output', $compareJsonlPath
                )
                $compareLog = Join-Path $resolvedRoot "logs/vally-compare-$model-$runId.log"
                $resultC = Invoke-VallyCommandWithCapture -Arguments $compareArgs -LogPath $compareLog
                $compareFailed = $resultC.ExitCode -ne 0
                if ($compareFailed) { $runHealthFailures++ }
                $compareLogs.Add($compareLog)

                $jsonlLines = if (Test-Path -LiteralPath $compareJsonlPath) { @(Get-Content -LiteralPath $compareJsonlPath -Encoding utf8) } else { @() }
                # A comparison pair needs both sides, so the comparable population is
                # bounded by the smaller trial count.
                $comparableTrials = [Math]::Min($baselineTrials, $customizedTrials)
                $tally = Measure-CompareTrials -Lines $jsonlLines -StimulusPolicy $canonicalPolicy `
                    -ExpectedStimulusName @($canonicalPolicy.Keys) -ExpectedTrialCount $comparableTrials
                if ($tally.Total -le 0) {
                    Write-Host "   Compare emitted no parseable comparison records: $compareJsonlPath" -ForegroundColor Yellow
                    if (-not $compareFailed) { $runHealthFailures++ }
                }
                elseif ($tally.SummaryCount -le 0) {
                    Write-Host "   Compare records carried no summary statistics; cannot assess equivalence: $compareJsonlPath" -ForegroundColor Yellow
                    if (-not $compareFailed) { $runHealthFailures++ }
                }

                # Records that could not be scored are counted rather than dropped. An
                # unmatched trajectory or malformed record means the comparison is
                # incomplete, and reporting a tie ratio computed only from the survivors
                # would overstate equivalence. Missing and unexpected trials extend this
                # to records that never arrived, which no structural counter can see.
                $structural = $tally.MalformedRecords + $tally.UnmatchedBaseline + $tally.UnmatchedTreatment + $tally.DuplicateTrials +
                    $tally.MissingTrials + $tally.UnexpectedTrials
                if ($structural -gt 0) {
                    $dataQualityViolations += $structural
                    Write-Host "   Data quality: $($tally.MalformedRecords) malformed, $($tally.UnmatchedBaseline) unmatched baseline, $($tally.UnmatchedTreatment) unmatched treatment, $($tally.DuplicateTrials) duplicate, $($tally.MissingTrials) missing, $($tally.UnexpectedTrials) unexpected" -ForegroundColor Yellow
                }
                if (-not $tally.PopulationReconciled) {
                    Write-Host "   Comparison population was not reconciled; missing stimuli cannot be detected for this model." -ForegroundColor Yellow
                }
                if ($tally.JudgeErrors -gt 0) {
                    Write-Host "   Judge errors: $($tally.JudgeErrors) of $($tally.Total + $tally.JudgeErrors) attempted trial(s)" -ForegroundColor Yellow
                }
                foreach ($diagnostic in @($tally.Diagnostics)) { $dataQualityDiagnostics.Add($diagnostic) }

                $comparisonCalibration.Add([ordered]@{
                        model                 = $model
                        policy                = 'equivalent-only'
                        status                = 'report-only'
                        scoreCount            = $tally.EquivalentScoreCount
                        meanScore             = $tally.EquivalentMeanScore
                        stdDev                = $tally.EquivalentStdDev
                        ciLow                 = $tally.EquivalentCiLow
                        ciHigh                = $tally.EquivalentCiHigh
                        perStimulus           = $tally.EquivalentPerStimulus
                    })

                $totalRuns += $tally.Total
                $totalTies += $tally.Ties
                $totalBaselineWins  += $tally.BaselineWins
                $totalTreatmentWins += $tally.TreatmentWins
                $totalJudgeErrors += $tally.JudgeErrors
                $totalEquivalent += $tally.EquivalentTotal
                $totalEquivalentTies += $tally.EquivalentTies
                $totalDivergence += $tally.DivergenceTotal
                if ($tally.SummaryCount -gt 0) {
                    $meanScores.Add([double]$tally.MeanScore)
                    $winRates.Add([double]$tally.WinRate)
                    $ciLows.Add([double]$tally.CiLow)
                    $ciHighs.Add([double]$tally.CiHigh)
                }
            }
        }

        $aggregateMeanScore = if ($meanScores.Count -gt 0) { ($meanScores | Measure-Object -Average).Average } else { 0.0 }
        $aggregateWinRate = if ($winRates.Count -gt 0) { ($winRates | Measure-Object -Average).Average } else { 0.0 }
        $aggregateCiLow = if ($ciLows.Count -gt 0) { ($ciLows | Measure-Object -Maximum).Maximum } else { 0.0 }
        $aggregateCiHigh = if ($ciHighs.Count -gt 0) { ($ciHighs | Measure-Object -Minimum).Minimum } else { 0.0 }

        # The gate reads the equivalent-only tie ratio. Aggregating the ties and trials
        # rather than averaging per-model ratios keeps every trial weighted equally, so
        # a model that contributed fewer trials cannot move the result disproportionately.
        $aggregateTieRatio = if ($totalEquivalent -gt 0) { $totalEquivalentTies / $totalEquivalent } else { 0.0 }

        $gates = Get-EquivalenceGateResults `
            -Runs $totalRuns `
            -TieRatio $aggregateTieRatio `
            -EquivalentTotal $totalEquivalent `
            -InvariantFailures $invariantFailures `
            -DataQualityViolations $dataQualityViolations `
            -DivergenceGuardFailures $divergenceGuardFailures `
            -DivergenceHasSignal $divergenceHasSignal `
            -RunHealthFailures $runHealthFailures `
            -Tier $Tier
        $verdict = $gates.Verdict

        $summary = [ordered]@{
            # A breaking contract change. Consumers reject an unsupported major version
            # rather than reading absent fields as zeros, which is how a dropped field
            # previously degraded into a plausible-looking healthy run.
            schemaVersion            = '2.1.0'
            agent                    = $Agent
            tier                     = $Tier
            model                    = $primaryModel
            runs                     = $totalRuns
            ties                     = $totalTies
            baselineWins             = $totalBaselineWins
            treatmentWins            = $totalTreatmentWins
            meanScore                = [math]::Round($aggregateMeanScore, 4)
            ciLow                    = [math]::Round($aggregateCiLow, 4)
            ciHigh                   = [math]::Round($aggregateCiHigh, 4)
            winRate                  = [math]::Round($aggregateWinRate, 4)
            invariantFailures        = $invariantFailures
            runHealthFailures        = $runHealthFailures
            invocationEvidence       = @($invocationEvidence)
            invocationFailures       = $invocationFailures
            divergenceGuardFailures  = $divergenceGuardFailures
            divergenceGuardsEvaluated = $divergenceGuardsEvaluated
            failedDivergenceGuards   = @(Get-DiagnosticSample -Diagnostics $failedDivergenceGuards -Max 50)
            dataQualityViolations    = $dataQualityViolations
            judgeErrors              = $totalJudgeErrors
            judgeErrorRate           = if (($totalRuns + $totalJudgeErrors) -gt 0) { [math]::Round($totalJudgeErrors / ($totalRuns + $totalJudgeErrors), 6) } else { 0.0 }
            equivalentTrials         = $totalEquivalent
            equivalentTies           = $totalEquivalentTies
            divergenceTrials         = $totalDivergence
            tieRatio                 = if ($totalEquivalent -gt 0) { [math]::Round($totalEquivalentTies / $totalEquivalent, 4) } else { 0.0 }
            comparisonCalibration    = @($comparisonCalibration)
            comparisonStatus         = 'report-only'
            dataQualityDiagnostics   = @(Get-DiagnosticSample -Diagnostics $dataQualityDiagnostics -Max 50)
            equivalenceGate          = $gates.EquivalenceGate
            documentedDivergenceGate = $gates.DocumentedDivergenceGate
            verdict                  = $verdict
            variants                 = $variants
            compareLogs              = @($compareLogs)
        }

        Write-SummaryJson -Summary $summary -Path $OutputPath
        Write-Host "Summary written: $OutputPath (equivalence=$($gates.EquivalenceGate) divergence=$($gates.DocumentedDivergenceGate) verdict=$verdict)" -ForegroundColor Cyan

        if ($Tier -eq 'devloop') {
            exit 0
        }

        if ($verdict -eq 'fail') {
            Write-Host "CI verdict: fail" -ForegroundColor Red
            exit 1
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-BaselineEquivalence failed: $($_.Exception.Message)"
        exit 3
    }
    finally {
        # Released before removal so a waiting run fails fast rather than inheriting a
        # half-built surface. Removal keeps the working tree clean for the same reason
        # the surface placeholder is restored.
        if ($surfaceLockStream) {
            $surfaceLockStream.Dispose()
            Remove-Item -LiteralPath $surfaceLockPath -Force -ErrorAction SilentlyContinue
        }
    }
}
#endregion Main Execution
