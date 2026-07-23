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

function Get-TagValues {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Tags,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$TagName
    )

    if ($null -eq $Tags -or -not ($Tags -is [System.Collections.IDictionary])) {
        return @()
    }

    if (-not $Tags.Contains($TagName)) {
        return @()
    }

    $rawValue = $Tags[$TagName]
    if ($null -eq $rawValue) {
        return @()
    }

    if ($rawValue -is [System.Collections.IEnumerable] -and -not ($rawValue -is [string])) {
        return @($rawValue | ForEach-Object { [string]$_ })
    }

    return @([string]$rawValue)
}

function Get-AgentInventorySlugs {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$InventoryPath = 'evals/agent-behavior/AGENTS.yml'
    )

    $inventoryFull = if ([System.IO.Path]::IsPathRooted($InventoryPath)) {
        $InventoryPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $InventoryPath
    }

    if (-not (Test-Path -LiteralPath $inventoryFull -PathType Leaf)) {
        return @()
    }

    $parsed = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $inventoryFull -Raw -ErrorAction Stop)
    if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) {
        return @()
    }

    if (-not $parsed.Contains('agents')) {
        return @()
    }

    $slugs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($record in @($parsed['agents'])) {
        if ($null -eq $record -or -not ($record -is [System.Collections.IDictionary])) {
            continue
        }

        if (-not $record.Contains('slug')) {
            continue
        }

        $slug = [string]$record['slug']
        if ([string]::IsNullOrWhiteSpace($slug)) {
            continue
        }

        [void]$slugs.Add($slug.Trim())
    }

    return @($slugs)
}

function Test-OrphanedStimulusTag {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$EvalSpecPath = 'evals/agent-behavior/eval.yaml',

        [Parameter(Mandatory = $false)]
        [string]$InventoryPath = 'evals/agent-behavior/AGENTS.yml'
    )

    $selectableSlugs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($slug in @(Get-AgentInventorySlugs -RepoRoot $RepoRoot -InventoryPath $InventoryPath)) {
        [void]$selectableSlugs.Add($slug)
    }

    $inventoryFull = if ([System.IO.Path]::IsPathRooted($InventoryPath)) {
        $InventoryPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $InventoryPath
    }

    $inventoryError = $null
    if (-not (Test-Path -LiteralPath $inventoryFull -PathType Leaf)) {
        $inventoryError = "Agent inventory not found at '$InventoryPath'; cannot evaluate stimulus tag reachability."
    }
    elseif ($selectableSlugs.Count -eq 0) {
        $inventoryError = "Agent inventory at '$InventoryPath' contains no usable agent slugs; cannot evaluate stimulus tag reachability."
    }

    if ($null -ne $inventoryError) {
        return @{
            evalSpecPath   = $EvalSpecPath
            inventoryPath  = $InventoryPath
            availableSlugs = @($selectableSlugs)
            checkedCount   = 0
            orphanedTags   = @()
            inventoryError = $inventoryError
        }
    }

    $evalSpecFull = if ([System.IO.Path]::IsPathRooted($EvalSpecPath)) {
        $EvalSpecPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $EvalSpecPath
    }

    if (-not (Test-Path -LiteralPath $evalSpecFull -PathType Leaf)) {
        return @{
            evalSpecPath = $EvalSpecPath
            inventoryPath = $InventoryPath
            availableSlugs = @($selectableSlugs.ToArray())
            checkedCount = 0
            orphanedTags = @()
            inventoryError = $null
        }
    }

    $parsed = ConvertFrom-Yaml -Yaml (Get-Content -LiteralPath $evalSpecFull -Raw -ErrorAction Stop)
    $orphaned = [System.Collections.Generic.List[hashtable]]::new()
    $checkedCount = 0

    if ($null -ne $parsed -and $parsed -is [System.Collections.IDictionary] -and $parsed.Contains('stimuli')) {
        foreach ($stimulus in @($parsed['stimuli'])) {
            if ($null -eq $stimulus -or -not ($stimulus -is [System.Collections.IDictionary])) {
                continue
            }

            $tags = $null
            if ($stimulus.ContainsKey('tags') -and $stimulus['tags'] -is [System.Collections.IDictionary]) {
                $tags = $stimulus['tags']
            }

            $agentTags = @(Get-TagValues -Tags $tags -TagName 'agent')
            foreach ($agentTag in $agentTags) {
                $checkedCount++
                if (-not $selectableSlugs.Contains($agentTag)) {
                    $orphaned.Add(@{
                        tag = 'agent'
                        value = $agentTag
                        stimulusName = if ($stimulus.ContainsKey('name')) { [string]$stimulus['name'] } else { '<unknown>' }
                        reason = 'tag value is not an inventoried slug'
                    })
                }
            }

            $scenarioTags = @(Get-TagValues -Tags $tags -TagName 'scenario')
            foreach ($scenarioTag in $scenarioTags) {
                $checkedCount++
                $hasReachableAgentSelector = $false
                foreach ($agentTag in $agentTags) {
                    if ($selectableSlugs.Contains($agentTag)) {
                        $hasReachableAgentSelector = $true
                        break
                    }
                }

                if (-not $hasReachableAgentSelector) {
                    $orphaned.Add(@{
                        tag = 'scenario'
                        value = $scenarioTag
                        stimulusName = if ($stimulus.ContainsKey('name')) { [string]$stimulus['name'] } else { '<unknown>' }
                        reason = 'scenario tag has no reachable agent selector in the same stimulus'
                    })
                }
            }
        }
    }

    return @{
        evalSpecPath = $EvalSpecPath
        inventoryPath = $InventoryPath
        availableSlugs = @($selectableSlugs)
        checkedCount = $checkedCount
        orphanedTags = @($orphaned)
        inventoryError = $null
    }
}

function Write-OrphanedStimulusTagAnnotations {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IEnumerable]$OrphanedTags,

        [Parameter(Mandatory = $true)]
        [string]$EvalSpecPath
    )

    foreach ($entry in $OrphanedTags) {
        $msg = "Orphaned $($entry.tag) tag '$($entry.value)' in stimulus '$($entry.stimulusName)' ($($entry.reason))."
        Write-Host "::error file=$EvalSpecPath::$msg"
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

    $orphanReport = Test-OrphanedStimulusTag -RepoRoot $resolvedRepoRoot -EvalSpecPath 'evals/agent-behavior/eval.yaml' -InventoryPath 'evals/agent-behavior/AGENTS.yml'
    Write-Host "Stimulus tag reachability: $($orphanReport.checkedCount) tag value(s) checked; $($orphanReport.orphanedTags.Count) orphaned."

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
            root         = $report.root
            valid        = $report.valid
            invalid      = $report.invalid
            orphanedTags = $orphanReport.orphanedTags
            inventoryError = $orphanReport.inventoryError
            coverage     = $coverageReport
        }
        $merged | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutput -Encoding UTF8
    }
    else {
        $merged = [ordered]@{
            root         = $report.root
            valid        = $report.valid
            invalid      = $report.invalid
            orphanedTags = $orphanReport.orphanedTags
            inventoryError = $orphanReport.inventoryError
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
    if ($orphanReport.inventoryError) {
        Write-Host "::error file=$($orphanReport.inventoryPath)::$($orphanReport.inventoryError)"
        $exitCode = 1
    }
    elseif ($orphanReport.orphanedTags.Count -gt 0) {
        Write-OrphanedStimulusTagAnnotations -OrphanedTags $orphanReport.orphanedTags -EvalSpecPath $orphanReport.evalSpecPath
        $exitCode = 1
    }

    exit $exitCode
}
