#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Validates vally eval spec files against the embedded schema and enforces
    per-agent behavioral eval coverage.

.DESCRIPTION
    Walks evals/**/*.yaml (default) or a caller-supplied root, parses each spec,
    and validates required keys, executor whitelist, and stimulus backlink tags
    using the EvalSpecSchema module. After schema validation, enumerates every
    parent (user-invocable) agent under .github/agents/ and verifies a matching
    stimulus partial exists in evals/agent-behavior/stimuli/<slug>.yml. Writes a
    combined JSON report (schema + coverage) to the requested output path and
    exits 1 when any spec fails schema validation or any parent agent lacks a
    stimulus partial.

.PARAMETER Root
    Repository-relative path to the eval spec root. Defaults to 'evals'.

.PARAMETER RepoRoot
    Absolute path to the repository root. Inferred from git when omitted.

.PARAMETER OutputPath
    Output file path for the validation report. Defaults to 'logs/eval-spec-validation.json'.

.PARAMETER AgentsRoot
    Repository-relative path to the agents root used for coverage enumeration.
    Defaults to '.github/agents'.

.PARAMETER StimuliRoot
    Repository-relative path to the per-agent stimulus partial directory.
    Defaults to 'evals/agent-behavior/stimuli'.

.PARAMETER SkipAgentCoverage
    Disable the agent-behavior coverage check. Useful for fixture-only test runs.

.PARAMETER NewAgentsOnly
    Restrict the coverage check to parent agents added since BaseRef (as reported
    by `git diff --name-only --diff-filter=A`). Existing agents without partials
    are not flagged when this switch is set, enabling incremental enforcement.

.PARAMETER BaseRef
    Git ref used for new-agent detection when -NewAgentsOnly is set. Defaults to
    'origin/main'.

.EXAMPLE
    pwsh -File scripts/evals/Test-EvalSpec.ps1
#>

#Requires -Version 7.4

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$Root = 'evals',

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/eval-spec-validation.json',

    [Parameter(Mandatory = $false)]
    [string]$AgentsRoot = '.github/agents',

    [Parameter(Mandatory = $false)]
    [string]$StimuliRoot = 'evals/agent-behavior/stimuli',

    [Parameter(Mandatory = $false)]
    [switch]$SkipAgentCoverage,

    [Parameter(Mandatory = $false)]
    [switch]$NewAgentsOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseRef = 'origin/main'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/EvalSpecSchema.psm1') -Force

if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    Write-Error "Required module 'powershell-yaml' is not installed. Run 'Install-Module powershell-yaml -Scope CurrentUser' before invoking this script."
    exit 2
}
Import-Module powershell-yaml -ErrorAction Stop

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
    catch {
        $null = $_
    }

    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../..')).ProviderPath
}

function Invoke-EvalSpecValidation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Root,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $rootFull = if ([System.IO.Path]::IsPathRooted($Root)) { $Root } else { Join-Path -Path $RepoRoot -ChildPath $Root }
    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
        throw "Eval root '$rootFull' does not exist."
    }

    $valid = [System.Collections.Generic.List[string]]::new()
    $invalid = [System.Collections.Generic.List[hashtable]]::new()

    $specFiles = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Include '*.yaml', '*.yml' -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -notin @('variant.yaml', 'variant.yml', 'AGENTS.yml') -and
            $_.FullName.Replace('\', '/') -notmatch '/surface-signatures/' -and
            $_.FullName.Replace('\', '/') -notmatch '/agent-behavior/stimuli/' -and
            $_.FullName.Replace('\', '/') -notmatch '/agent-behavior/expectations/' -and
            $_.FullName.Replace('\', '/') -notmatch '/beval/'
        }
    foreach ($file in $specFiles) {
        $relPath = ($file.FullName.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')

        $parsed = $null
        $parseError = $null
        try {
            $rawContent = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($rawContent)) {
                $parseError = 'Spec file is empty'
            }
            else {
                $parsed = ConvertFrom-Yaml -Yaml $rawContent
            }
        }
        catch {
            $parseError = "YAML parse error: $($_.Exception.Message)"
        }

        if ($null -ne $parseError) {
            $invalid.Add(@{ path = $relPath; errors = @(@{ field = '<parse>'; message = $parseError }) })
            continue
        }

        $errors = @(Test-EvalSpecCompliance -Spec $parsed -SpecPath $relPath -RepoRoot $RepoRoot)
        if ($errors.Count -eq 0) {
            $valid.Add($relPath)
        }
        else {
            $invalid.Add(@{ path = $relPath; errors = @($errors) })
        }
    }

    $outputDir = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -LiteralPath $outputDir -PathType Container)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $report = @{
        root    = $Root
        valid   = $valid
        invalid = $invalid
    }
    $report | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

    return $report
}

function Write-EvalSpecAnnotations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Invalid
    )

    foreach ($entry in $Invalid) {
        foreach ($err in $entry.errors) {
            $msg = "[$($err.field)] $($err.message)"
            Write-Host "::error file=$($entry.path)::$msg"
        }
    }
}

function Get-ParentAgentInventoryForCoverage {
    [CmdletBinding()]
    [OutputType([System.Collections.IList])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$AgentsRoot
    )

    $rootFull = if ([System.IO.Path]::IsPathRooted($AgentsRoot)) {
        $AgentsRoot
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $AgentsRoot
    }

    $inventory = [System.Collections.Generic.List[hashtable]]::new()
    if (-not (Test-Path -LiteralPath $rootFull -PathType Container)) {
        return $inventory
    }

    $files = Get-ChildItem -LiteralPath $rootFull -Recurse -File -Filter '*.agent.md' -ErrorAction SilentlyContinue
    foreach ($file in $files) {
        $relPath = ($file.FullName.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')

        try {
            $raw = [System.IO.File]::ReadAllText($file.FullName)
        }
        catch {
            continue
        }

        $isParent = $true
        if ($raw -match '(?ms)^---\s*\r?\n(.*?)\r?\n---\s*(?:\r?\n|$)') {
            $block = $matches[1]
            foreach ($line in ($block -split "\r?\n")) {
                if ($line -match '^\s*user-invocable\s*:\s*(?<val>.+?)\s*$') {
                    $val = $matches['val'].Trim().Trim("'", '"').ToLowerInvariant()
                    if ($val -eq 'false') { $isParent = $false }
                    break
                }
            }
        }

        if (-not $isParent) { continue }

        $name = $file.Name
        $slug = if ($name.EndsWith('.agent.md')) {
            $name.Substring(0, $name.Length - '.agent.md'.Length)
        }
        else {
            [System.IO.Path]::GetFileNameWithoutExtension($name)
        }

        $inventory.Add(@{ slug = $slug; path = $relPath })
    }

    return $inventory
}

function Get-NewParentAgentSlugFromGit {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$BaseRef
    )

    Push-Location -LiteralPath $RepoRoot
    try {
        $output = git diff --name-only --diff-filter=A $BaseRef -- '.github/agents/**/*.agent.md' 2>$null
        $gitExit = $LASTEXITCODE
    }
    finally {
        Pop-Location
    }

    if ($gitExit -ne 0 -or $null -eq $output) { return @() }

    $slugs = [System.Collections.Generic.List[string]]::new()
    foreach ($line in $output) {
        $trimmed = ([string]$line).Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        $name = [System.IO.Path]::GetFileName($trimmed)
        if (-not $name.EndsWith('.agent.md')) { continue }
        $slug = $name.Substring(0, $name.Length - '.agent.md'.Length)
        $slugs.Add($slug)
    }
    return $slugs.ToArray()
}

function Test-AgentBehaviorCoverage {
    <#
    .SYNOPSIS
        Enumerates parent agents and verifies each has a stimulus partial.

    .DESCRIPTION
        Day-one coverage gate for the per-agent behavioral eval suite. A parent
        agent is any `.github/agents/**/*.agent.md` file whose frontmatter does
        not set `user-invocable: false`. For every parent, asserts a matching
        partial exists at `evals/agent-behavior/stimuli/<slug>.yml`. When
        -RestrictToSlugs is provided, only those slugs are checked, which the
        entrypoint uses to honor -NewAgentsOnly without coupling to git inside
        this function.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$AgentsRoot = '.github/agents',

        [Parameter(Mandatory = $false)]
        [string]$StimuliRoot = 'evals/agent-behavior/stimuli',

        [Parameter(Mandatory = $false)]
        [string[]]$RestrictToSlugs
    )

    $inventory = @(Get-ParentAgentInventoryForCoverage -RepoRoot $RepoRoot -AgentsRoot $AgentsRoot)

    $stimuliFull = if ([System.IO.Path]::IsPathRooted($StimuliRoot)) {
        $StimuliRoot
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $StimuliRoot
    }

    $existingStimuli = @{}
    if (Test-Path -LiteralPath $stimuliFull -PathType Container) {
        Get-ChildItem -LiteralPath $stimuliFull -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in '.yml', '.yaml' } |
            ForEach-Object {
                $slug = [System.IO.Path]::GetFileNameWithoutExtension($_.Name)
                $relStim = ($_.FullName.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')
                $existingStimuli[$slug] = $relStim
            }
    }

    $restrict = $null
    if ($null -ne $RestrictToSlugs -and $RestrictToSlugs.Count -gt 0) {
        $restrict = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
        foreach ($s in $RestrictToSlugs) { [void]$restrict.Add($s) }
    }

    $covered = [System.Collections.Generic.List[hashtable]]::new()
    $missing = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($entry in $inventory) {
        if ($null -ne $restrict -and -not $restrict.Contains($entry.slug)) { continue }

        if ($existingStimuli.ContainsKey($entry.slug)) {
            $covered.Add(@{
                slug         = $entry.slug
                agentPath    = $entry.path
                stimulusPath = $existingStimuli[$entry.slug]
            })
        }
        else {
            $missing.Add(@{
                slug      = $entry.slug
                agentPath = $entry.path
            })
        }
    }

    return @{
        agentsRoot   = $AgentsRoot
        stimuliRoot  = $StimuliRoot
        parentCount  = $inventory.Count
        checkedCount = ($covered.Count + $missing.Count)
        covered      = $covered.ToArray()
        missing      = $missing.ToArray()
    }
}

function Write-AgentCoverageAnnotations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$Missing,

        [Parameter(Mandatory = $true)]
        [string]$StimuliRoot
    )

    foreach ($entry in $Missing) {
        $msg = "Parent agent '$($entry.slug)' is missing eval stimulus partial '$StimuliRoot/$($entry.slug).yml'. Author one using the class recipe in evals/agent-behavior/README.md and regenerate evals/agent-behavior/eval.yaml."
        Write-Host "::error file=$($entry.agentPath)::$msg"
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    $resolvedRepoRoot = Resolve-RepoRoot -Hint $RepoRoot

    $resolvedOutput = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $resolvedRepoRoot -ChildPath $OutputPath
    }

    $report = Invoke-EvalSpecValidation -Root $Root -RepoRoot $resolvedRepoRoot -OutputPath $resolvedOutput

    Write-Host "Validated $($report.valid.Count) eval spec(s) successfully; $($report.invalid.Count) failed."
    Write-Host "Report: $resolvedOutput"

    $coverageReport = $null
    if (-not $SkipAgentCoverage) {
        $restrictSlugs = $null
        if ($NewAgentsOnly) {
            $restrictSlugs = Get-NewParentAgentSlugFromGit -RepoRoot $resolvedRepoRoot -BaseRef $BaseRef
            if ($null -eq $restrictSlugs -or $restrictSlugs.Count -eq 0) {
                Write-Host "Agent behavior coverage: -NewAgentsOnly set, but no newly-added parent agents detected vs '$BaseRef'. Skipping coverage check."
            }
        }

        if (-not $NewAgentsOnly -or ($null -ne $restrictSlugs -and $restrictSlugs.Count -gt 0)) {
            $coverageReport = Test-AgentBehaviorCoverage `
                -RepoRoot $resolvedRepoRoot `
                -AgentsRoot $AgentsRoot `
                -StimuliRoot $StimuliRoot `
                -RestrictToSlugs $restrictSlugs

            Write-Host "Agent behavior coverage: $($coverageReport.covered.Count) covered, $($coverageReport.missing.Count) missing (of $($coverageReport.checkedCount) checked, $($coverageReport.parentCount) parent agents on disk)."
        }
    }

    if ($null -ne $coverageReport) {
        $merged = [ordered]@{
            root     = $report.root
            valid    = $report.valid
            invalid  = $report.invalid
            coverage = $coverageReport
        }
        $merged | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
    }

    $exitCode = 0
    if ($report.invalid.Count -gt 0) {
        Write-EvalSpecAnnotations -Invalid $report.invalid
        $exitCode = 1
    }
    if ($null -ne $coverageReport -and $coverageReport.missing.Count -gt 0) {
        Write-AgentCoverageAnnotations -Missing $coverageReport.missing -StimuliRoot $StimuliRoot
        $exitCode = 1
    }

    exit $exitCode
}
