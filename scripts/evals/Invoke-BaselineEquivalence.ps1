#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

#Requires -Version 7.4

<#
.SYNOPSIS
    Runs the Vally baseline-vs-customized equivalence suite for a target hve-core agent.

.DESCRIPTION
    Drives the `evals/baseline-equivalence/` Vally suite end-to-end. Resolves the target
    agent's frontmatter `model:` hint, selects a model tier (PR or nightly), invokes
    `vally eval` once per environment (`baseline` and `task-researcher-context`), invokes
    `vally compare` to produce a pairwise verdict, and writes a machine-readable summary
    to `logs/baseline-equivalence-summary.json`.

    Exit policy by tier:
    - PR tier always exits 0. Equivalence failures surface as `verdict: warn` in the
      summary JSON. Advisory only.
    - Nightly tier exits non-zero (1) when `verdict == fail`. Source of truth.

    `-WhatIf` (dry-run) mode prints the planned `vally` command lines, emits a summary
    JSON populated with zeros and `verdict: dry-run`, and exits 0 without invoking any
    SDK or external command.

.PARAMETER Agent
    The target agent slug, matching the basename of an `.agent.md` file under
    `.github/agents/`. Defaults to `task-researcher`.

.PARAMETER Tier
    The model tier to exercise. `pr` runs a single primary model; `nightly` runs a model
    array for broader coverage. Defaults to `pr`.

.PARAMETER StimulusFilter
    Optional regular expression filtering stimulus names. Defaults to `.*` (all stimuli).

.PARAMETER Model
    Optional explicit model id for the PR tier. When supplied it overrides the agent's
    frontmatter `model:` hint and the built-in default, letting callers pin a cheaper
    model for advisory PR-tier runs. Ignored for the `nightly` tier, which always runs
    its fixed model array.

.PARAMETER RepoRoot
    Repository root. Defaults to the result of `git rev-parse --show-toplevel`, falling
    back to the parent of `$PSScriptRoot`.

.PARAMETER OutputPath
    Path to the summary JSON. Defaults to `<RepoRoot>/logs/baseline-equivalence-summary.json`.

.EXAMPLE
    ./Invoke-BaselineEquivalence.ps1 -Agent task-researcher -Tier pr -WhatIf

    Prints the planned commands and writes a dry-run summary.

.EXAMPLE
    npm run eval:equivalence -- -Agent task-researcher -Tier pr

    Runs the PR-tier flow via the npm wrapper.

.NOTES
    Runs via: npm run eval:equivalence
#>

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$Agent = 'task-researcher',

    [Parameter(Mandatory = $false)]
    [ValidateSet('pr', 'nightly')]
    [string]$Tier = 'pr',

    [Parameter(Mandatory = $false)]
    [string]$StimulusFilter = '.*',

    [Parameter(Mandatory = $false)]
    [string]$Model,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

Import-Module -Name (Join-Path $PSScriptRoot 'lib/EquivalenceParsing.psm1') -Force

#region Helper Functions

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

function Resolve-AgentSurfaceSignaturePath {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string]$Agent
    )

    $path = Join-Path $RepoRoot "evals/baseline-equivalence/surface-signatures/$Agent.yml"
    if (-not (Test-Path -LiteralPath $path)) {
        throw "Surface signature not found for agent '$Agent' at $path. Run scripts/evals/New-AgentSurfaceSignatures.ps1 -Agent $Agent to generate."
    }
    return $path
}

function New-RenderedCompareSpec {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)]
        [string]$RepoRoot,
        [Parameter(Mandatory)]
        [string]$Agent,
        [Parameter(Mandatory)]
        [string]$OutputPath
    )

    $sourceSpec = Join-Path $RepoRoot 'evals/baseline-equivalence/compare.eval.yml'
    if (-not (Test-Path -LiteralPath $sourceSpec)) {
        throw "Compare spec not found at $sourceSpec."
    }
    $signaturePath = Resolve-AgentSurfaceSignaturePath -RepoRoot $RepoRoot -Agent $Agent

    $specText = [System.IO.File]::ReadAllText($sourceSpec)
    $signatureText = [System.IO.File]::ReadAllText($signaturePath)

    $indentedLines = $signatureText -split "`r?`n" | ForEach-Object {
        if ([string]::IsNullOrEmpty($_)) { '' } else { '    ' + $_ }
    }
    $indented = $indentedLines -join "`n"

    $replacement = "surface_signatures:`n  ${Agent}:`n$indented"

    if ($specText -notmatch '(?m)^surface_signatures:\s*\{\}\s*$') {
        throw "compare.eval.yml does not contain the 'surface_signatures: {}' marker. Update the spec per Phase 2 Step 2.5 before running the equivalence driver."
    }

    $renderedText = [regex]::Replace($specText, '(?m)^surface_signatures:\s*\{\}\s*$', { param($m) $replacement }, 1)

    if ($renderedText -eq $specText) {
        throw "Render produced an unchanged compare spec for agent '$Agent'. Ensure the 'surface_signatures: {}' marker is present in compare.eval.yml."
    }

    $outDir = Split-Path -Parent $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force -WhatIf:$false -Confirm:$false | Out-Null
    }
    [System.IO.File]::WriteAllText($OutputPath, $renderedText)
    return $OutputPath
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

    if ($Tier -eq 'nightly') {
        return @('gpt-5.5', 'claude-opus-4.6', 'claude-sonnet-latest')
    }

    if ($ModelOverride) { return @($ModelOverride) }
    if ($Hint) { return @($Hint) }
    return @('claude-haiku-4.5')
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
        [string]$StimulusFilter,
        [Parameter(Mandatory)]
        [string[]]$PlannedCommands,
        [hashtable]$Variants
    )

    return [ordered]@{
        agent              = $Agent
        tier               = $Tier
        model              = $Model
        stimulusFilter     = $StimulusFilter
        runs               = 0
        ties               = 0
        aWins              = 0
        bWins              = 0
        invariantFailures  = 0
        divergenceFailures = 0
        verdict            = 'dry-run'
        variants           = $Variants
        plannedCommands    = $PlannedCommands
    }
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
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)]
        [string[]]$Models,
        [Parameter(Mandatory)]
        [string]$StimulusFilter,
        [Parameter(Mandatory)]
        [string]$OutputRoot,
        [Parameter(Mandatory)]
        [string]$RunId,
        [Parameter(Mandatory)]
        [string]$CompareSpecPath,
        [string]$BaselineWorkspacePath,
        [string]$BaselineSkillDirPath,
        [string]$CustomizedWorkspacePath,
        [string]$CustomizedSkillDirPath
    )

    $filterTag = if ($StimulusFilter -eq '.*') { '' } else { "  # filter: $StimulusFilter" }
    $plan = [System.Collections.Generic.List[string]]::new()
    foreach ($model in $Models) {
        $aDir = Join-Path $OutputRoot "$model/$RunId/baseline"
        $bDir = Join-Path $OutputRoot "$model/$RunId/customized"
        $baselineWorkspaceArg = if ([string]::IsNullOrEmpty($BaselineWorkspacePath)) { '""' } else { '"' + $BaselineWorkspacePath + '"' }
        $baselineSkillArg = if ([string]::IsNullOrEmpty($BaselineSkillDirPath)) { '""' } else { '"' + $BaselineSkillDirPath + '"' }
        $customizedWorkspaceArg = if ([string]::IsNullOrEmpty($CustomizedWorkspacePath)) { '""' } else { '"' + $CustomizedWorkspacePath + '"' }
        $customizedSkillArg = if ([string]::IsNullOrEmpty($CustomizedSkillDirPath)) { '""' } else { '"' + $CustomizedSkillDirPath + '"' }
        $plan.Add("vally eval --eval-spec evals/baseline-equivalence/baseline/eval.yaml --model $model --output-dir $aDir --workspace $baselineWorkspaceArg --skill-dir $baselineSkillArg$filterTag")
        $plan.Add("vally eval --eval-spec evals/baseline-equivalence/customized/eval.yaml --model $model --output-dir $bDir --workspace $customizedWorkspaceArg --skill-dir $customizedSkillArg$filterTag")
        $plan.Add("vally compare --eval-spec $CompareSpecPath --run-a <resolved baseline run> --run-b <resolved customized run>")
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
        $resolvedRoot = Resolve-RepoRoot -Hint $RepoRoot
        if (-not $OutputPath) {
            $OutputPath = Join-Path $resolvedRoot 'logs/baseline-equivalence-summary.json'
        }

        $modelHint = Get-AgentModelHint -RepoRoot $resolvedRoot -Agent $Agent
        $models = @(Resolve-ModelList -Tier $Tier -Hint $modelHint -ModelOverride $Model)
        $primaryModel = $models[0]

        $outputRoot = Join-Path $resolvedRoot 'evals/results/baseline-equivalence'
        $runId = (Get-Date -AsUTC).ToString('yyyyMMddTHHmmssfffZ')

        $defaultVariantA = @{ kind = 'baseline'; name = 'baseline';   label = 'Baseline (A)';   description = ''; applied = @() }
        $defaultVariantB = @{ kind = 'agent';    name = $Agent;       label = $Agent;            description = ''; applied = @() }
        $variantA = Get-VariantMetadata -VariantYamlPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/baseline/variant.yaml') -Default $defaultVariantA
        $variantB = Get-VariantMetadata -VariantYamlPath (Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/variant.yaml') -Default $defaultVariantB
        $workspaceRoot = Join-Path $resolvedRoot 'evals/baseline-equivalence/customized/workspace'
        $variantB.applied = @(Get-AppliedArtifacts -WorkspaceRoot $workspaceRoot)
        $variants = @{ a = $variantA; b = $variantB; subject = [string]$variantB.name }

        Write-Host "Baseline equivalence: agent=$Agent tier=$Tier model(s)=$($models -join ',')" -ForegroundColor Cyan
        Write-Host "   Stimulus filter: $StimulusFilter" -ForegroundColor DarkGray
        Write-Host "   Summary output:  $OutputPath" -ForegroundColor DarkGray
        Write-Host "   Results root:    $outputRoot" -ForegroundColor DarkGray
        Write-Host "   Run id:          $runId" -ForegroundColor DarkGray

        $renderedCompareSpec = Join-Path $resolvedRoot "logs/baseline-equivalence-compare-$Agent.eval.yml"
        New-RenderedCompareSpec -RepoRoot $resolvedRoot -Agent $Agent -OutputPath $renderedCompareSpec | Out-Null
        $renderedSpecRelative = [System.IO.Path]::GetRelativePath($resolvedRoot, $renderedCompareSpec).Replace('\', '/')
        Write-Host "   Compare spec:    $renderedSpecRelative" -ForegroundColor DarkGray

        $customizedWorkspacePath = $workspaceRoot
        $customizedSkillDirPath = Join-Path $resolvedRoot '.github/skills'
        $plannedCommands = Get-PlannedCommands -Models $models -StimulusFilter $StimulusFilter -OutputRoot $outputRoot -RunId $runId -CompareSpecPath $renderedSpecRelative -BaselineWorkspacePath '' -BaselineSkillDirPath '' -CustomizedWorkspacePath $customizedWorkspacePath -CustomizedSkillDirPath $customizedSkillDirPath

        if ($WhatIfPreference) {
            Write-Host "Dry-run mode: skipping live SDK calls." -ForegroundColor Yellow
            foreach ($cmd in $plannedCommands) {
                Write-Host "   $cmd" -ForegroundColor DarkGray
            }

            $dry = New-DryRunSummary `
                -Agent $Agent `
                -Tier $Tier `
                -Model $primaryModel `
                -StimulusFilter $StimulusFilter `
                -PlannedCommands $plannedCommands `
                -Variants $variants
            Write-SummaryJson -Summary $dry -Path $OutputPath
            Write-Host "Dry-run summary written: $OutputPath" -ForegroundColor Green
            exit 0
        }

        $totalRuns = 0
        $totalTies = 0
        $totalA = 0
        $totalB = 0
        $invariantFailures = 0
        $divergenceFailures = 0
        $compareLogs = [System.Collections.Generic.List[string]]::new()

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
                '--skill-dir', $customizedSkillDirPath
            )

            $codeA = Invoke-VallyCommand -Arguments $evalBaseline
            $baselineRunDir = Resolve-LatestRunDir -OutputDir $aDir
            $baselineFailures = Get-InvariantFailureCount -RunDir $baselineRunDir
            if ($null -ne $baselineFailures) {
                $invariantFailures += $baselineFailures
            }
            elseif ($codeA -ne 0) {
                $invariantFailures++
            }

            $codeB = Invoke-VallyCommand -Arguments $evalCustomized
            if ($codeB -ne 0) { $divergenceFailures++ }

            $aRunDir = Resolve-LatestRunDir -OutputDir $aDir
            $bRunDir = Resolve-LatestRunDir -OutputDir $bDir
            if (-not $aRunDir -or -not $bRunDir) {
                Write-Host "   Compare skipped: missing run dir (a=$aRunDir b=$bRunDir)" -ForegroundColor Yellow
                $divergenceFailures++
            }
            else {
                $compareArgs = @(
                    'compare',
                    '--eval-spec', $renderedSpecRelative,
                    '--run-a', $aRunDir,
                    '--run-b', $bRunDir
                )
                $compareLog = Join-Path $resolvedRoot "logs/vally-compare-$model-$runId.log"
                $resultC = Invoke-VallyCommandWithCapture -Arguments $compareArgs -LogPath $compareLog
                if ($resultC.ExitCode -ne 0) { $divergenceFailures++ }
                $compareLogs.Add($compareLog)

                $tally = Measure-CompareTrials -Lines $resultC.Lines
                if ($tally.Total -le 0) {
                    Write-Host "   Compare emitted no parseable trial lines: $compareLog" -ForegroundColor Yellow
                    $divergenceFailures++
                }
                $totalRuns += $tally.Total
                $totalTies += $tally.Ties
                $totalA   += $tally.AWins
                $totalB   += $tally.BWins
            }
        }

        $verdict = Get-VerdictFromAggregate `
            -Runs $totalRuns `
            -Ties $totalTies `
            -AWins $totalA `
            -BWins $totalB `
            -InvariantFailures $invariantFailures `
            -DivergenceFailures $divergenceFailures `
            -Tier $Tier

        $summary = [ordered]@{
            agent              = $Agent
            tier               = $Tier
            model              = $primaryModel
            stimulusFilter     = $StimulusFilter
            runs               = $totalRuns
            ties               = $totalTies
            aWins              = $totalA
            bWins              = $totalB
            invariantFailures  = $invariantFailures
            divergenceFailures = $divergenceFailures
            verdict            = $verdict
            variants           = $variants
            compareLogs        = @($compareLogs)
        }

        Write-SummaryJson -Summary $summary -Path $OutputPath
        Write-Host "Summary written: $OutputPath ($verdict)" -ForegroundColor Cyan

        if ($Tier -eq 'pr') {
            exit 0
        }

        if ($verdict -eq 'fail') {
            Write-Host "Nightly verdict: fail" -ForegroundColor Red
            exit 1
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-BaselineEquivalence failed: $($_.Exception.Message)"
        exit 3
    }
}
#endregion Main Execution
