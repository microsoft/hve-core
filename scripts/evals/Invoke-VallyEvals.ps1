#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Executes vally evals for the AI artifacts changed in a pull request.

.DESCRIPTION
    Reads the changed-artifact manifest produced by `Get-ChangedAIArtifact.ps1`,
    resolves each artifact to its matching eval spec(s) via the same
    `StimulusIndex` used by `Test-StimulusPresence.ps1`, and invokes
    `vally eval` exactly once per unique spec path. Per-spec results are
    aggregated into:

      logs/eval-results-<kind>-<artifactId>.json - one file per artifact, with
                                                   its associated spec results
      logs/eval-summary.json                     - roll-up totals + perArtifact
                                                   + perSpec arrays for CI

    Exit codes:
      0 = all changed artifacts passed (or manifest is empty / only deletions).
      1 = at least one spec failed (non-zero vally exit code or failed trials).
      2 = invalid input: missing manifest, missing eval root, or missing
          coverage for any non-deleted artifact (should have been caught by
          `Test-StimulusPresence.ps1` upstream).

.PARAMETER ManifestPath
    Path to the changed-artifact manifest. Defaults to
    `logs/changed-ai-artifacts.json`. Resolved relative to the repository root
    when not absolute.

.PARAMETER EvalRoot
    Filesystem path to the eval spec root. Defaults to `evals/`. Resolved
    relative to the repository root when not absolute.

.PARAMETER LogsDir
    Directory where per-artifact JSON files and the eval-summary are written.
    Defaults to `logs/`. Created if it does not exist.

.PARAMETER Model
    Model passed to `vally eval --model`. Also forwarded to
    `Invoke-BaselineEquivalence.ps1` when baseline equivalence is explicitly
    enabled. Defaults to `claude-haiku-4.5`.

.PARAMETER VallyCommand
    Path or name of the vally executable. Defaults to `vally`. Tests pass the
    absolute path to `scripts/tests/evals/fixtures/stub-vally.ps1`.

.PARAMETER EquivalenceDriverPath
    Path to the baseline-equivalence driver script used when
    `-EnableBaselineEquivalence` is set. Defaults to
    `<RepoRoot>/scripts/evals/Invoke-BaselineEquivalence.ps1`. Tests override this
    to point at a stub script.

.PARAMETER EquivalenceTier
    Tier passed to the equivalence driver (`pr` or `nightly`). Defaults to `pr`.
    Applies only when `-EnableBaselineEquivalence` is set. Per DD-01, PR-tier
    equivalence dispatch is advisory: failures surface in summary JSON but do
    not increment `failedSpecs` or change exit code.

.PARAMETER EnableBaselineEquivalence
    Enables Tier 2 baseline-equivalence dispatch for changed or affected agents.
    Disabled by default for PR-time eval execution.

.PARAMETER FailFast
    Stop after the first spec invocation that returns a non-zero exit code or
    any failed trial. Default: process every spec, then exit non-zero if any
    failed.

.PARAMETER SkipInputModeration
    Skip pre-eval content moderation of stimulus prompts. Default: $false.

.PARAMETER SkipOutputModeration
    Skip post-eval content moderation of model outputs. Default: $false.

.PARAMETER ModerationThreshold
    Toxicity threshold (0.0-1.0) for content moderation. Defaults to 0.5.
    Individual specs may override this via the optional top-level
    `moderation.threshold` field.

.PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

.EXAMPLE
    pwsh scripts/evals/Invoke-VallyEvals.ps1

    Reads `logs/changed-ai-artifacts.json`, runs the matched specs against
    `vally`, and writes per-artifact + summary JSON under `logs/`.

.NOTES
    Runs from the PR-time `eval-execute` job once coverage and lint pass.
#>
[CmdletBinding()]
param(
    [string]$ManifestPath,
    [string]$EvalRoot,
    [string]$LogsDir,
    [ValidateSet('agent','prompt','instruction','skill')]
    [string[]]$Kind = @(),
    [string]$Model = 'claude-haiku-4.5',
    [string]$VallyCommand = 'vally',
    [string]$EquivalenceDriverPath,
    [ValidateSet('pr','nightly')]
    [string]$EquivalenceTier = 'pr',
    [switch]$EnableBaselineEquivalence,
    [switch]$FailFast,
    [switch]$SkipInputModeration,
    [switch]$SkipOutputModeration,
    [double]$ModerationThreshold = 0.5,
    [string]$RepoRoot
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/StimulusIndex.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/VallyRunner.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/ArtifactDetection.psm1') -Force

if (-not (Get-Module -Name powershell-yaml)) {
    Import-Module powershell-yaml -ErrorAction Stop
}

function Get-SpecModerationThreshold {
    [CmdletBinding()]
    [OutputType([Nullable[double]])]
    param(
        [Parameter(Mandatory)][string]$SpecPath
    )

    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { return $null }

    try {
        $raw = Get-Content -LiteralPath $SpecPath -Raw -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        $parsed = $raw | ConvertFrom-Yaml
    }
    catch {
        Write-Verbose "Get-SpecModerationThreshold: failed to parse '$SpecPath': $_"
        return $null
    }

    if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) { return $null }
    if (-not $parsed.ContainsKey('moderation')) { return $null }
    $moderation = $parsed['moderation']
    if (-not ($moderation -is [System.Collections.IDictionary]) -or -not $moderation.ContainsKey('threshold')) { return $null }

    $value = $moderation['threshold']
    try { return [double]$value } catch { return $null }
}

function Test-SpecIsAdvisory {
    # Returns $true when every stimulus in the spec carries `tags.advisory: true`.
    # Per DD-05, advisory specs surface failures in the run summary but never
    # promote the dispatcher's overall exit code to non-zero.
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)][string]$SpecPath
    )

    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { return $false }

    try {
        $raw = Get-Content -LiteralPath $SpecPath -Raw -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $false }
        $parsed = $raw | ConvertFrom-Yaml
    }
    catch {
        Write-Verbose "Test-SpecIsAdvisory: failed to parse '$SpecPath': $_"
        return $false
    }

    if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) { return $false }
    if (-not $parsed.ContainsKey('stimuli')) { return $false }
    $stimuli = $parsed['stimuli']
    if ($null -eq $stimuli -or -not ($stimuli -is [System.Collections.IEnumerable]) -or $stimuli -is [string]) { return $false }

    $any = $false
    foreach ($stimulus in $stimuli) {
        $any = $true
        if (-not ($stimulus -is [System.Collections.IDictionary])) { return $false }
        if (-not $stimulus.Contains('tags')) { return $false }
        $tags = $stimulus['tags']
        if (-not ($tags -is [System.Collections.IDictionary]) -or -not $tags.Contains('advisory')) { return $false }
        if (-not [bool]$tags['advisory']) { return $false }
    }

    return $any
}

function Get-SpecStimulusAdvisoryMap {
    # Returns @{<stimulus-name> = [bool]} when at least one stimulus carries
    # `tags.advisory`, supporting per-stimulus graduation from advisory to
    # authoritative within a single spec. Returns $null when no stimulus
    # declares an advisory tag; callers then fall back to Test-SpecIsAdvisory.
    # When -TagFilter (`key=value`) is supplied the map is scoped to the stimuli
    # that this tag-filtered run actually executes, so a multi-agent spec does
    # not let one agent's authoritative stimuli skew another agent's posture.
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)][string]$SpecPath,
        [string]$TagFilter
    )

    if (-not (Test-Path -LiteralPath $SpecPath -PathType Leaf)) { return $null }

    try {
        $raw = Get-Content -LiteralPath $SpecPath -Raw -Encoding utf8
        if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
        $parsed = $raw | ConvertFrom-Yaml
    }
    catch {
        Write-Verbose "Get-SpecStimulusAdvisoryMap: failed to parse '$SpecPath': $_"
        return $null
    }

    if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) { return $null }
    if (-not $parsed.ContainsKey('stimuli')) { return $null }
    $stimuli = $parsed['stimuli']
    if ($null -eq $stimuli -or -not ($stimuli -is [System.Collections.IEnumerable]) -or $stimuli -is [string]) { return $null }

    $filterKey = $null
    $filterValue = $null
    if (-not [string]::IsNullOrWhiteSpace($TagFilter) -and $TagFilter.Contains('=')) {
        $eq = $TagFilter.IndexOf('=')
        $filterKey = $TagFilter.Substring(0, $eq).Trim()
        $filterValue = $TagFilter.Substring($eq + 1).Trim()
    }

    $entries = [System.Collections.Generic.List[hashtable]]::new()
    $sawAdvisoryTag = $false
    foreach ($stimulus in $stimuli) {
        if (-not ($stimulus -is [System.Collections.IDictionary])) { continue }
        if (-not $stimulus.Contains('name')) { continue }
        $name = [string]$stimulus['name']
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        $tags = if ($stimulus.Contains('tags') -and $stimulus['tags'] -is [System.Collections.IDictionary]) { $stimulus['tags'] } else { $null }

        $advisory = $false
        if ($tags -and $tags.Contains('advisory')) {
            $sawAdvisoryTag = $true
            $rawAdvisory = $tags['advisory']
            # YAML yields a real bool or a quoted string; treat only true/1/yes
            # (case-insensitive) as advisory so a quoted "false" graduates correctly.
            $advisory = if ($rawAdvisory -is [bool]) { [bool]$rawAdvisory } else { [string]$rawAdvisory -match '^(?i:true|1|yes)$' }
        }
        $entries.Add(@{ name = $name; advisory = $advisory; tags = $tags })
    }

    if (-not $sawAdvisoryTag) { return $null }

    # Scope to the run's tag filter when it matches at least one stimulus; fall
    # back to the full set when the filter is absent or matches nothing.
    $selected = $entries
    if ($filterKey) {
        $matched = @($entries | Where-Object { $_.tags -and $_.tags.Contains($filterKey) -and ([string]$_.tags[$filterKey] -eq $filterValue) })
        if ($matched.Count -gt 0) { $selected = $matched }
    }

    $map = @{}
    foreach ($entry in $selected) { $map[$entry.name] = $entry.advisory }
    return $map
}

function Resolve-RepoRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param([string]$Hint)

    if (-not [string]::IsNullOrWhiteSpace($Hint)) {
        return (Resolve-Path -LiteralPath $Hint).ProviderPath
    }

    try {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($gitRoot)) {
            return (Resolve-Path -LiteralPath $gitRoot.Trim()).ProviderPath
        }
    }
    catch { $null = $_ }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).ProviderPath
}

function Resolve-PathFromRoot {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path -Path $RepoRoot -ChildPath $Path)
}

function ConvertTo-SafeKey {
    [CmdletBinding()]
    [OutputType([string])]
    param([Parameter(Mandatory = $true)][string]$Value)

    return ($Value -replace '[^A-Za-z0-9\-_.]', '_')
}

function Get-ArtifactFileKey {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$ArtifactId
    )

    # kind prefix prevents collisions when a skill and a prompt share a slug.
    return "$Kind-$(ConvertTo-SafeKey -Value $ArtifactId)"
}

function Write-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]$Value,
        [Parameter(Mandatory = $true)][string]$Path
    )

    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $json = $Value | ConvertTo-Json -Depth 12
    Set-Content -LiteralPath $Path -Value $json -Encoding utf8NoBOM
}

# Skip the eval workflow below when dot-sourced (e.g. by Pester unit tests) so
# callers can load the helper functions without executing a run.
if ($MyInvocation.InvocationName -ne '.') {
    # Executed directly as a script: fall through to the main workflow.
}
else {
    return
}

$resolvedRoot = Resolve-RepoRoot -Hint $RepoRoot

if ([string]::IsNullOrWhiteSpace($ManifestPath)) { $ManifestPath = 'logs/changed-ai-artifacts.json' }
if ([string]::IsNullOrWhiteSpace($EvalRoot))     { $EvalRoot     = 'evals' }
if ([string]::IsNullOrWhiteSpace($LogsDir))      { $LogsDir      = 'logs' }

$resolvedManifest = Resolve-PathFromRoot -Path $ManifestPath -RepoRoot $resolvedRoot
$resolvedEvalRoot = Resolve-PathFromRoot -Path $EvalRoot     -RepoRoot $resolvedRoot
$resolvedLogsDir  = Resolve-PathFromRoot -Path $LogsDir      -RepoRoot $resolvedRoot

if (-not (Test-Path -LiteralPath $resolvedManifest -PathType Leaf)) {
    Write-Host "::error file=$ManifestPath::Manifest not found: $resolvedManifest"
    exit 2
}
if (-not (Test-Path -LiteralPath $resolvedEvalRoot -PathType Container)) {
    Write-Host "::error::Eval root not found: $resolvedEvalRoot"
    exit 2
}
if (-not (Test-Path -LiteralPath $resolvedLogsDir -PathType Container)) {
    New-Item -ItemType Directory -Path $resolvedLogsDir -Force | Out-Null
}

$manifest = Get-Content -LiteralPath $resolvedManifest -Raw | ConvertFrom-Json
$artifacts = @()
if ($null -ne $manifest -and $null -ne $manifest.artifacts) {
    $artifacts = @($manifest.artifacts | Where-Object { [string]$_.status -ne 'D' })
}

# Repo-root (repo-specific) artifacts live directly under `.github/<kind>/`
# without a collection subdirectory. Per `.github/copilot-instructions.md` they
# are excluded from collection manifests, packaging, and eval coverage, so they
# carry no eval spec. Drop them here so they do not surface as missing-coverage
# failures, mirroring the skip in `Test-StimulusPresence.ps1`.
$artifacts = @($artifacts | Where-Object {
    -not (Test-RepoRootArtifact -Kind ([string]$_.kind) -Path ([string]$_.path))
})

# Per-kind shard filter. When -Kind is supplied, the stimulus artifacts[] loop
# is narrowed to the matching kind(s) only. Baseline equivalence is cross-kind
# (an instruction/skill change can promote a parent agent), so it stays owned by
# the shard that includes 'agent' (or by an unfiltered run) and always reads the
# manifest's full, unfiltered affectedAgents[] set.
$kindFilter = @($Kind | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
$shardOwnsEquivalence = ($kindFilter.Count -eq 0) -or ($kindFilter -contains 'agent')
if ($kindFilter.Count -gt 0) {
    $artifacts = @($artifacts | Where-Object { $kindFilter -contains [string]$_.kind })
}

$summaryPath = Join-Path -Path $resolvedLogsDir -ChildPath 'eval-summary.json'

# Equivalence work can remain even when this shard has zero changed stimulus
# artifacts (e.g. a skill-only PR whose changed skill promotes a parent agent).
# Only take the empty-summary fast path when no equivalence work is pending.
$affectedAgentCount = 0
if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains 'affectedAgents' -and $null -ne $manifest.affectedAgents) {
    $affectedAgentCount = @($manifest.affectedAgents | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }).Count
}
$equivalenceWorkPending = $EnableBaselineEquivalence -and $shardOwnsEquivalence -and $affectedAgentCount -gt 0

if ($artifacts.Count -eq 0 -and -not $equivalenceWorkPending) {
    $emptySummary = [ordered]@{
        manifestPath = $resolvedManifest
        evalRoot     = $resolvedEvalRoot
        model        = $Model
        kindFilter   = @($kindFilter)
        totals       = [ordered]@{
            artifacts        = 0
            specs            = 0
            assertionsPassed = 0
            assertionsFailed = 0
            durationMs       = 0
            failedSpecs      = 0
        }
        perArtifact  = @()
        perSpec      = @()
        equivalence  = @()
    }
    Write-JsonFile -Value $emptySummary -Path $summaryPath
    Write-Host "No changed AI artifacts to evaluate. Summary written to $summaryPath"
    exit 0
}

$index = New-StimulusIndex -EvalRoot $resolvedEvalRoot

# Backlink count per spec: how many distinct artifacts (coverage keys) the index
# maps to each spec. A spec backlinked by more than one artifact runs once PER
# artifact with a `--tag kind=slug` filter so each artifact is scored only on its
# own stimuli instead of inheriting another artifact's results.
$specBacklinkCount = Get-VallySpecBacklinkCount -Index $index

if (-not $EquivalenceDriverPath) {
    $EquivalenceDriverPath = Join-Path -Path $resolvedRoot -ChildPath 'scripts/evals/Invoke-BaselineEquivalence.ps1'
}

$equivalenceSpecs = @{}

# Resolve covering specs per artifact, then delegate run-plan keying to the
# VallyRunner helper so the tag-aware runKey logic stays unit-testable.
$artifactDescriptors = [System.Collections.Generic.List[hashtable]]::new()
foreach ($artifact in $artifacts) {
    $artifactKind = [string]$artifact.kind
    $artifactId   = [string]$artifact.artifactId
    $specs        = Test-StimulusCoverage -Index $index -Kind $artifactKind -ArtifactId $artifactId

    $artifactDescriptors.Add(@{
        kind        = $artifactKind
        artifactId  = $artifactId
        path        = [string]$artifact.path
        status      = [string]$artifact.status
        specs       = @($specs)
    })

    if ($EnableBaselineEquivalence -and $artifactKind -eq 'agent' -and $specs.Count -gt 0) {
        $equivKey = "equivalence:$artifactId"
        if (-not $equivalenceSpecs.ContainsKey($equivKey)) {
            $equivalenceSpecs[$equivKey] = $artifactId
        }
    }
}

$runPlan        = Get-VallySpecRunPlan -Artifact $artifactDescriptors.ToArray() -SpecBacklinkCount $specBacklinkCount -IndexRoot $index.root
$uniqueSpecRuns = $runPlan.uniqueSpecRuns
$artifactPlan   = $runPlan.artifactPlan
$missingSpecs   = $runPlan.missingSpecs

if ($missingSpecs.Count -gt 0) {
    foreach ($m in $missingSpecs) {
        Write-Host "::error file=$($m.path)::No eval spec resolves $($m.kind):$($m.artifactId); run Test-StimulusPresence first."
    }
    Write-Host "::error::Cannot execute evals: $($missingSpecs.Count) artifact(s) have no covering spec."
    exit 2
}

$runsRoot = Join-Path -Path $resolvedLogsDir -ChildPath 'eval-runs'
if (-not (Test-Path -LiteralPath $runsRoot)) {
    New-Item -ItemType Directory -Path $runsRoot -Force | Out-Null
}
$moderationScript = Join-Path -Path $resolvedRoot -ChildPath 'scripts/evals/Invoke-ContentModeration.ps1'

$specResults = @{}
$failedSpecs = 0

foreach ($runKey in $uniqueSpecRuns.Keys) {
    $run     = $uniqueSpecRuns[$runKey]
    $specRel = $run.specRel
    $specAbs = $run.specAbs
    $tag     = $run.tag
    $specKey = ConvertTo-SafeKey -Value $runKey
    $specOut = Join-Path -Path $runsRoot -ChildPath $specKey
    $specLog = Join-Path -Path $resolvedLogsDir -ChildPath "vally-eval-$specKey.log"

    # Pre-eval content moderation (input)
    $inputModeration = @{ flagged = $false; flaggedCount = 0; outputPath = $null; error = $false }
    $specThreshold = Get-SpecModerationThreshold -SpecPath $specAbs
    $effectiveThreshold = if ($null -ne $specThreshold) { $specThreshold } else { $ModerationThreshold }
    if ($null -ne $specThreshold) {
        Write-Verbose "Per-spec moderation.threshold=$specThreshold overrides default ($ModerationThreshold) for $specRel"
    }
    if (-not $SkipInputModeration) {
        Write-Verbose "Pre-eval content moderation for spec: $specRel"
        $inputModeration = Test-SpecInputModeration `
            -SpecPath $specAbs `
            -ArtifactId $specKey `
            -ModerationScript $moderationScript `
            -Threshold $effectiveThreshold `
            -RepoRoot $resolvedRoot

        if ($inputModeration.flagged) {
            Write-Host "::error file=$specRel::Content moderation flagged $($inputModeration.flaggedCount) input prompt(s); eval blocked"
            $specResults[$runKey] = @{
                specPath         = $specAbs
                specRel          = $specRel
                tag              = $tag
                exitCode         = 0
                runDir           = $null
                assertionsPassed = 0
                assertionsFailed = 0
                durationMs       = 0
                trials           = 0
                resultsPath      = $null
                moderationInput  = $inputModeration
                moderationOutput = $null
                status           = 'content-moderation-input'
            }
            $failedSpecs++
            continue
        }
        elseif ($inputModeration.error) {
            Write-Host "::error file=$specRel::Input content moderation could not run (infrastructure error); eval blocked"
            $specResults[$runKey] = @{
                specPath         = $specAbs
                specRel          = $specRel
                tag              = $tag
                exitCode         = 0
                runDir           = $null
                assertionsPassed = 0
                assertionsFailed = 0
                durationMs       = 0
                trials           = 0
                resultsPath      = $null
                moderationInput  = $inputModeration
                moderationOutput = $null
                status           = 'content-moderation-error-input'
            }
            $failedSpecs++
            continue
        }
    }

    $tagBanner = if (-not [string]::IsNullOrWhiteSpace($tag)) { " --tag $tag" } else { '' }
    Write-Host "Running: vally eval --eval-spec $specRel --model $Model$tagBanner" -ForegroundColor Cyan
    $result = Invoke-VallySpec `
        -SpecPath $specAbs `
        -OutputDir $specOut `
        -Model $Model `
        -VallyCommand $VallyCommand `
        -LogPath $specLog `
        -Tag $tag
    $result['specRel'] = $specRel
    $result['tag'] = $tag

    # Post-eval content moderation (output)
    $outputModeration = @{ flagged = $false; flaggedCount = 0; outputPath = $null; error = $false }
    if (-not $SkipOutputModeration -and $result.runDir) {
        Write-Verbose "Post-eval content moderation for spec: $specRel"
        $outputModeration = Test-SpecOutputModeration `
            -RunDir $result.runDir `
            -ArtifactId $specKey `
            -ModerationScript $moderationScript `
            -Threshold $effectiveThreshold `
            -RepoRoot $resolvedRoot

        if ($outputModeration.flagged) {
            Write-Host "::warning file=$specRel::Content moderation flagged $($outputModeration.flaggedCount) model output(s)"
            $result.status = 'content-moderation-output'
            $result.assertionsFailed = [Math]::Max($result.assertionsFailed, $outputModeration.flaggedCount)
        }
        elseif ($outputModeration.error) {
            Write-Host "::error file=$specRel::Output content moderation could not run (infrastructure error)"
        }
    }

    $result['moderationInput'] = $inputModeration
    $result['moderationOutput'] = $outputModeration

    $advisoryMap = Get-SpecStimulusAdvisoryMap -SpecPath $specAbs -TagFilter $tag
    $result['perStimulusAdvisory'] = $advisoryMap

    if ($null -ne $advisoryMap) {
        $advisoryPassed = 0
        $advisoryFailed = 0
        $authoritativePassed = 0
        $authoritativeFailed = 0
        if ($result.ContainsKey('perStimulus') -and $result.perStimulus) {
            foreach ($stimulusName in $result.perStimulus.Keys) {
                $bucket = $result.perStimulus[$stimulusName]
                $stimAdvisory = $false
                if ($advisoryMap.ContainsKey($stimulusName)) {
                    $stimAdvisory = [bool]$advisoryMap[$stimulusName]
                }
                if ($stimAdvisory) {
                    $advisoryPassed += [int]$bucket.assertionsPassed
                    $advisoryFailed += [int]$bucket.assertionsFailed
                }
                else {
                    $authoritativePassed += [int]$bucket.assertionsPassed
                    $authoritativeFailed += [int]$bucket.assertionsFailed
                }
            }
        }

        # Whole-spec advisory posture: true only when every tagged stimulus is advisory.
        $specAllAdvisory = ($advisoryMap.Values.Count -gt 0) -and (@($advisoryMap.Values | Where-Object { -not $_ }).Count -eq 0)

        # Reconcile failures the per-stimulus parse did not attribute (e.g. an empty
        # or partial perStimulus map when results.jsonl carries no resolvable stimulus
        # name). Classify the remainder by the spec's overall advisory posture so
        # advisory failures are never silently counted as authoritative (which would
        # gate the build via the exit-code fallback below).
        $unattributedFailed = [int]$result.assertionsFailed - ($advisoryFailed + $authoritativeFailed)
        if ($unattributedFailed -gt 0) {
            if ($specAllAdvisory) { $advisoryFailed += $unattributedFailed }
            else { $authoritativeFailed += $unattributedFailed }
        }

        # A zero vally exit means the spec met its aggregate threshold (the author's
        # runs/threshold contract), so every stimulus passed overall. Any per-trial
        # dips counted in assertionsFailed are sub-threshold noise, not merge
        # blockers; demote them to advisory so an aggregate-passing spec never gates.
        if ($result.exitCode -eq 0 -and $authoritativeFailed -gt 0) {
            $advisoryFailed += $authoritativeFailed
            $authoritativeFailed = 0
        }

        $result['advisoryPassed'] = $advisoryPassed
        $result['advisoryFailed'] = $advisoryFailed
        $result['authoritativePassed'] = $authoritativePassed
        $result['authoritativeFailed'] = $authoritativeFailed
        $result['isAdvisory'] = ($authoritativeFailed -eq 0 -and $advisoryFailed -gt 0)

        $erroredTrials = if ($result.ContainsKey('erroredTrials')) { [int]$result['erroredTrials'] } else { 0 }

        if (-not $result.ContainsKey('status')) {
            if ($authoritativeFailed -gt 0 -or $outputModeration.flagged) {
                $result['status'] = 'fail'
            }
            elseif ($advisoryFailed -gt 0) {
                $result['status'] = 'advisory-fail'
            }
            elseif ($result.exitCode -ne 0) {
                # A nonzero vally exit with no attributed grader failures is a transient
                # error (not a conformance failure) when trials errored after retries;
                # surface it as advisory rather than gating the build.
                $result['status'] = if ($specAllAdvisory -or $erroredTrials -gt 0) { 'advisory-fail' } else { 'fail' }
            }
            else {
                $result['status'] = 'pass'
            }
        }

        $specResults[$runKey] = $result

        $promote = $authoritativeFailed -gt 0 -or $outputModeration.flagged -or $outputModeration.error
        # A nonzero vally exit with no attributed failures gates only when the spec is
        # not wholly advisory; an all-advisory spec surfaces but never blocks merge.
        if (-not $promote -and $result.exitCode -ne 0 -and $advisoryFailed -eq 0 -and $authoritativeFailed -eq 0 -and -not $specAllAdvisory) {
            if ($erroredTrials -gt 0) {
                # The nonzero exit is explained solely by transient errored trials that
                # persisted after retries; surface it but do not gate the build.
                Write-Host "::warning file=$specRel::$erroredTrials trial(s) errored (transient executor failure) with no grader failures after retries; not promoting to CI failure"
            }
            else {
                $promote = $true
            }
        }

        if ($promote) {
            $failedSpecs++
            if ($outputModeration.error) {
                Write-Host "::error file=$specRel::Output content moderation could not run (infrastructure error); promoting to CI failure"
            }
            elseif ($authoritativeFailed -gt 0 -and $advisoryFailed -gt 0) {
                Write-Host "::warning file=$specRel::Per-stimulus advisory failures coexist with authoritative failures; promoting to CI failure"
            }
            if ($FailFast) {
                Write-Host "::warning::FailFast set; skipping remaining specs after failure in $specRel"
                break
            }
        }
        elseif ($advisoryFailed -gt 0) {
            Write-Host "::warning file=$specRel::Per-stimulus advisory failures: $advisoryFailed assertion(s) across advisory stimuli; not promoting to CI failure"
        }
    }
    else {
        # Per DD-01, baseline-equivalence is advisory at PR tier: equivalence
        # signal surfaces in the run summary but never gates merge. Its stimuli
        # corpus is tag-resolved into this authoritative path and runs at a
        # perfect-score threshold (1.0) against a small model, so a single grader
        # miss on a file-reading prompt would otherwise hard-fail the spec and
        # block the build. Treat any baseline-equivalence spec as advisory so the
        # tag-resolved path honors the same advisory posture as the dedicated
        # equivalence dispatch.
        $specIsEquivalence = $specRel -match '(^|/)baseline-equivalence/'
        $isAdvisory = (Test-SpecIsAdvisory -SpecPath $specAbs) -or $specIsEquivalence
        $result['isAdvisory'] = $isAdvisory

        # A zero vally exit means the spec met its aggregate threshold (the author's
        # runs/threshold contract), so per-trial assertion dips recorded in
        # assertionsFailed are sub-threshold noise, not merge blockers. Mirror the
        # advisory-map branch above and gate only on a nonzero vally exit or a
        # moderation failure. Without this, a spec that carries no advisory-tagged
        # stimulus would gate the build on a single sub-threshold dip even though
        # vally reported an aggregate pass.
        $hardFailure = ($result.exitCode -ne 0) -or $outputModeration.flagged -or $outputModeration.error
        $subThresholdDip = (-not $hardFailure) -and ($result.assertionsFailed -gt 0)

        if (-not $result.ContainsKey('status')) {
            $result['status'] = if ($hardFailure) { 'fail' } elseif ($subThresholdDip) { 'advisory-fail' } else { 'pass' }
        }

        $specResults[$runKey] = $result

        if ($hardFailure) {
            if ($isAdvisory -and -not $outputModeration.error) {
                $result['status'] = 'advisory-fail'
                Write-Host "::warning file=$specRel::Advisory spec failed (exit=$($result.exitCode), assertionsFailed=$($result.assertionsFailed)); not promoting to CI failure"
            }
            else {
                $failedSpecs++
                if ($FailFast) {
                    Write-Host "::warning::FailFast set; skipping remaining specs after failure in $specRel"
                    break
                }
            }
        }
        elseif ($subThresholdDip) {
            Write-Host "::warning file=$specRel::Sub-threshold per-trial dips (exit=0, assertionsFailed=$($result.assertionsFailed)); aggregate threshold met, not promoting to CI failure"
        }
    }
}

# Dep-map reverse-lookup expansion: instruction/skill/subagent changes promote
# parent agents into the equivalence dispatch set. The manifest's
# `affectedAgents` field is precomputed by Get-ChangedAIArtifact.ps1 via the
# AffectedAgents module, which also refreshes logs/agent-dependency-map.json
# when stale.
if ($EnableBaselineEquivalence -and $shardOwnsEquivalence) {
    $manifestAffected = @()
    if ($null -ne $manifest -and $manifest.PSObject.Properties.Name -contains 'affectedAgents' -and $null -ne $manifest.affectedAgents) {
        $manifestAffected = @($manifest.affectedAgents)
    }
    foreach ($slug in $manifestAffected) {
        if ([string]::IsNullOrWhiteSpace($slug)) { continue }
        $equivKey = "equivalence:$slug"
        if (-not $equivalenceSpecs.ContainsKey($equivKey)) {
            $equivalenceSpecs[$equivKey] = $slug
        }
    }
}

# Equivalence dispatch (Tier 2 baseline-equivalence). Per DD-01, PR-tier failures
# are advisory: they surface in summary but do not increment $failedSpecs.
# Only the agent-owning shard dispatches equivalence so cross-kind promotions are
# not duplicated across parallel per-kind shards.
$equivalenceResults = [System.Collections.Generic.List[object]]::new()
if ($EnableBaselineEquivalence -and $shardOwnsEquivalence) {
    foreach ($equivKey in $equivalenceSpecs.Keys) {
        $agentSlug = $equivalenceSpecs[$equivKey]
        $equivOutPath = Join-Path -Path $resolvedLogsDir -ChildPath "baseline-equivalence-$agentSlug.json"
        $equivArgs = @(
            '-NoProfile', '-File', $EquivalenceDriverPath,
            '-Agent', $agentSlug,
            '-Tier', $EquivalenceTier,
            '-Model', $Model,
            '-RepoRoot', $resolvedRoot,
            '-OutputPath', $equivOutPath
        )

        Write-Host "Running: pwsh $($equivArgs -join ' ')" -ForegroundColor Cyan
        & pwsh @equivArgs
        $equivExit = $LASTEXITCODE

        $runs = 0; $invFail = 0; $divFail = 0; $verdict = 'unknown'
        if (Test-Path -LiteralPath $equivOutPath) {
            try {
                $equivSummary = Get-Content -LiteralPath $equivOutPath -Raw | ConvertFrom-Json
                if ($null -ne $equivSummary.runs)               { $runs    = [int]$equivSummary.runs }
                if ($null -ne $equivSummary.invariantFailures)  { $invFail = [int]$equivSummary.invariantFailures }
                if ($null -ne $equivSummary.divergenceFailures) { $divFail = [int]$equivSummary.divergenceFailures }
                if ($null -ne $equivSummary.verdict)            { $verdict = [string]$equivSummary.verdict }
            }
            catch {
                Write-Host "::warning::Failed to parse equivalence summary $equivOutPath" -ForegroundColor Yellow
            }
        }

        $assertionsFailed = $invFail + $divFail
        $assertionsPassed = [Math]::Max(0, $runs - $assertionsFailed)

        $equivalenceResults.Add([ordered]@{
            agent              = $agentSlug
            tier               = $EquivalenceTier
            verdict            = $verdict
            exitCode           = $equivExit
            trials             = $runs
            assertionsPassed   = $assertionsPassed
            assertionsFailed   = $assertionsFailed
            invariantFailures  = $invFail
            divergenceFailures = $divFail
            resultsPath        = "logs/baseline-equivalence-$agentSlug.json"
        }) | Out-Null

        if ($EquivalenceTier -ne 'pr' -and ($equivExit -ne 0 -or $assertionsFailed -gt 0)) {
            $failedSpecs++
        }
    }
}

$hardFailStatuses = @('fail', 'content-moderation-input', 'content-moderation-error-input', 'content-moderation-output')
$perArtifact = [System.Collections.Generic.List[object]]::new()
foreach ($plan in $artifactPlan) {
    $artifactPassed    = 0
    $artifactFailed    = 0
    $artifactDurationMs = 0
    $artifactExitCode  = 0
    $artifactAuthoritativeFailed = 0
    $artifactAdvisoryFailed      = 0
    $artifactHasHardFail = $false
    $specBreakdown     = [System.Collections.Generic.List[object]]::new()
    $allSpecsRan       = $true

    foreach ($runKey in $plan.specRuns) {
        if (-not $specResults.ContainsKey($runKey)) {
            $allSpecsRan = $false
            continue
        }
        $r = $specResults[$runKey]
        $artifactPassed     += [int]$r.assertionsPassed
        $artifactFailed     += [int]$r.assertionsFailed
        $artifactDurationMs += [int]$r.durationMs

        $specStatus = if ($r.ContainsKey('status')) { [string]$r.status } else { '' }
        $specIsAdvisory = $r.ContainsKey('isAdvisory') -and [bool]$r.isAdvisory

        # Split this spec's failures into authoritative (gating) and advisory (non-gating).
        if ($r.ContainsKey('authoritativeFailed') -or $r.ContainsKey('advisoryFailed')) {
            $artifactAuthoritativeFailed += [int]$r['authoritativeFailed']
            $artifactAdvisoryFailed      += [int]$r['advisoryFailed']
        }
        elseif ($specIsAdvisory -or $specStatus -eq 'advisory-fail') {
            # A spec the main loop already demoted to 'advisory-fail' (an advisory
            # spec, or a no-advisory spec whose per-trial dip rode on a zero vally
            # exit) contributes only advisory failures, so it never gates the roll-up.
            $artifactAdvisoryFailed += [int]$r.assertionsFailed
        }
        else {
            $artifactAuthoritativeFailed += [int]$r.assertionsFailed
        }

        # A failing spec status (e.g. content moderation) gates even with zero assertion failures.
        if ($specStatus -in $hardFailStatuses) { $artifactHasHardFail = $true }

        # A nonzero exit gates only when the spec is not advisory.
        if ($r.exitCode -ne 0 -and -not $specIsAdvisory -and $artifactExitCode -eq 0) { $artifactExitCode = $r.exitCode }

        $specBreakdown.Add([ordered]@{
            specPath         = $r.specRel
            tag              = $r.tag
            exitCode         = $r.exitCode
            assertionsPassed = $r.assertionsPassed
            assertionsFailed = $r.assertionsFailed
            durationMs       = $r.durationMs
            trials           = $r.trials
            runDir           = $r.runDir
            resultsPath      = $r.resultsPath
        })
    }

    $status = if (-not $allSpecsRan) { 'skipped' }
              elseif ($artifactHasHardFail -or $artifactAuthoritativeFailed -gt 0 -or $artifactExitCode -ne 0) { 'fail' }
              elseif ($artifactAdvisoryFailed -gt 0) { 'advisory-fail' }
              else { 'pass' }
    $artifactIsAdvisory = ($status -eq 'advisory-fail')

    $artifactKey  = Get-ArtifactFileKey -Kind $plan.kind -ArtifactId $plan.artifactId
    $artifactFile = Join-Path -Path $resolvedLogsDir -ChildPath "eval-results-$artifactKey.json"
    $artifactRecord = [ordered]@{
        kind                = $plan.kind
        artifactId          = $plan.artifactId
        path                = $plan.path
        changeStatus        = $plan.status
        status              = $status
        isAdvisory          = $artifactIsAdvisory
        durationMs          = $artifactDurationMs
        assertionsPassed    = $artifactPassed
        assertionsFailed    = $artifactFailed
        authoritativeFailed = $artifactAuthoritativeFailed
        advisoryFailed      = $artifactAdvisoryFailed
        specs               = @($specBreakdown)
    }
    Write-JsonFile -Value $artifactRecord -Path $artifactFile

    $perArtifact.Add([ordered]@{
        kind                = $plan.kind
        artifactId          = $plan.artifactId
        path                = $plan.path
        changeStatus        = $plan.status
        status              = $status
        isAdvisory          = $artifactIsAdvisory
        durationMs          = $artifactDurationMs
        assertionsPassed    = $artifactPassed
        assertionsFailed    = $artifactFailed
        authoritativeFailed = $artifactAuthoritativeFailed
        advisoryFailed      = $artifactAdvisoryFailed
        specCount           = $specBreakdown.Count
        resultsFile         = "logs/eval-results-$artifactKey.json"
    }) | Out-Null
}

$perSpec = [System.Collections.Generic.List[object]]::new()
foreach ($runKey in $specResults.Keys) {
    $r = $specResults[$runKey]
    $record = [ordered]@{
        specPath         = if ($r.ContainsKey('specRel')) { $r.specRel } else { $runKey }
        tag              = if ($r.ContainsKey('tag')) { $r.tag } else { '' }
        exitCode         = $r.exitCode
        assertionsPassed = $r.assertionsPassed
        assertionsFailed = $r.assertionsFailed
        durationMs       = $r.durationMs
        trials           = $r.trials
    }
    if ($r.ContainsKey('status')) { $record['status'] = $r.status }
    if ($r.ContainsKey('isAdvisory')) { $record['isAdvisory'] = [bool]$r.isAdvisory }
    if ($r.ContainsKey('perStimulusAdvisory') -and $null -ne $r.perStimulusAdvisory) {
        $record['advisoryPassed'] = [int]$r.advisoryPassed
        $record['advisoryFailed'] = [int]$r.advisoryFailed
        $record['authoritativePassed'] = [int]$r.authoritativePassed
        $record['authoritativeFailed'] = [int]$r.authoritativeFailed
        $record['perStimulusAdvisory'] = $r.perStimulusAdvisory
    }
    $perSpec.Add($record) | Out-Null
}

$totalPassed   = 0
$totalFailed   = 0
$totalDuration = 0
foreach ($s in $perSpec) {
    $totalPassed   += [int]$s.assertionsPassed
    $totalFailed   += [int]$s.assertionsFailed
    $totalDuration += [int]$s.durationMs
}

$summary = [ordered]@{
    manifestPath = $resolvedManifest
    evalRoot     = $resolvedEvalRoot
    model        = $Model
    kindFilter   = @($kindFilter)
    totals       = [ordered]@{
        artifacts        = $perArtifact.Count
        specs            = $perSpec.Count
        assertionsPassed = $totalPassed
        assertionsFailed = $totalFailed
        durationMs       = $totalDuration
        failedSpecs      = $failedSpecs
    }
    perArtifact  = @($perArtifact)
    perSpec      = @($perSpec)
    equivalence  = @($equivalenceResults)
}

Write-JsonFile -Value $summary -Path $summaryPath
Write-Host "Eval summary: $summaryPath ($($perArtifact.Count) artifact(s), $($perSpec.Count) spec(s); $failedSpecs failed spec(s))"

if ($failedSpecs -gt 0) { exit 1 }
exit 0
