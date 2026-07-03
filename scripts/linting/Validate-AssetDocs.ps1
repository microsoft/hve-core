#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Validates asset documentation coverage, orphans, sync, structure, and
    authored completeness for the docs/reference tree.

.DESCRIPTION
    Enforces the "documentation as a required artifact" contract for every
    documentable GenAI asset (agent, prompt, instruction, skill). Modeled on
    Validate-SkillStructure.ps1 and Validate-PlannerArtifacts.ps1, it runs five
    checks and writes a JSON summary, exiting non-zero when any error-level
    finding is present:

    1. Coverage    - every asset has a docs page (error under -FailOnMissing).
    2. Orphans     - every docs/reference page maps to an existing asset.
    3. Sync        - generated regions match a fresh render (under -CheckSync).
    4. Structure   - required H2 sections and generated-region markers present
                     (How to use only required for interactive assets).
    5. Authored    - human sections differ from stubs (warning by default,
                     error under -RequireAuthoredContent).

    Reference index pages (README.md) are excluded from coverage, sync,
    structure, and authored checks and are never treated as orphans.

.PARAMETER RepoRoot
    Repository root directory. Defaults to the git top level or the resolved
    repository root relative to this script.

.PARAMETER FailOnMissing
    Treat missing documentation pages as errors instead of warnings.

.PARAMETER CheckSync
    Compare each page's generated regions against a fresh render and report
    drift as errors.

.PARAMETER RequireAuthoredContent
    Treat pages whose human-authored sections still contain stub placeholders
    as errors instead of warnings.

.PARAMETER OutputPath
    Path for the JSON results file. Defaults to
    logs/asset-docs-validation-results.json.

.EXAMPLE
    ./Validate-AssetDocs.ps1
    Reports coverage as warnings and authored stubs as warnings.

.EXAMPLE
    ./Validate-AssetDocs.ps1 -FailOnMissing -CheckSync
    Hard-fails on missing pages, orphans, sync drift, and structure problems.

.NOTES
    Runs via: npm run lint:asset-docs
    Dependencies: DocsHelpers module and Generate-AssetDocs.ps1 render helpers.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ((git rev-parse --show-toplevel 2>$null) ?? (Split-Path $PSScriptRoot -Parent | Split-Path -Parent)),

    [Parameter(Mandatory = $false)]
    [switch]$FailOnMissing,

    [Parameter(Mandatory = $false)]
    [switch]$CheckSync,

    [Parameter(Mandatory = $false)]
    [switch]$RequireAuthoredContent,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/asset-docs-validation-results.json'
)

$ErrorActionPreference = 'Stop'

# The generator declares its own RepoRoot/OutputPath param defaults. Dot-sourcing
# it below runs that param block in this script's scope, which would overwrite
# these parameters, so preserve them and restore them after the dot-source.
$assetDocsRepoRoot = $RepoRoot
$assetDocsOutputPath = $OutputPath

# Reuse the generator's deterministic render helpers so the sync check compares
# against exactly what the generator would produce. Dot-sourcing does not run
# the generator's main block (invocation guard).
. (Join-Path -Path $PSScriptRoot -ChildPath '../docs/Generate-AssetDocs.ps1')

# Re-import the modules this script calls directly, highest-level first and
# lowest-level last. The generator and its modules cross-import these with
# -Force, and each -Force re-import re-scopes shared modules into the importing
# module's scope; importing in dependency order here guarantees every command
# this script uses (DocsHelpers, CollectionHelpers, CIHelpers) ends up in this
# script's scope.
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../docs/Modules/DocsHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../collections/Modules/CollectionHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

$RepoRoot = $assetDocsRepoRoot
$OutputPath = $assetDocsOutputPath

#region Findings

function New-AssetDocFinding {
    <#
    .SYNOPSIS
        Builds a validation finding.
    .PARAMETER Level
        Severity: Error or Warning.
    .PARAMETER Category
        One of Coverage, Orphan, Sync, Structure, Authored.
    .PARAMETER Path
        Repo-relative path the finding refers to.
    .PARAMETER Message
        Human-readable description.
    .OUTPUTS
        [PSCustomObject] The finding.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][ValidateSet('Error', 'Warning')][string]$Level,
        [Parameter(Mandatory = $true)][ValidateSet('Coverage', 'Orphan', 'Sync', 'Structure', 'Authored')][string]$Category,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Message
    )

    return [PSCustomObject]@{
        Level    = $Level
        Category = $Category
        Path     = $Path
        Message  = $Message
    }
}

#endregion Findings

#region Checks

function Test-AssetDocCoverage {
    <#
    .SYNOPSIS
        Finds documentable assets missing a documentation page.
    .PARAMETER Models
        Page models from New-AssetPageModel.
    .PARAMETER RepoRoot
        Repository root directory.
    .PARAMETER FailOnMissing
        Emit errors instead of warnings for missing pages.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Models,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
        [Parameter(Mandatory = $false)][switch]$FailOnMissing
    )

    $level = if ($FailOnMissing) { 'Error' } else { 'Warning' }
    $findings = @()
    foreach ($model in $Models) {
        if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $model.DocRel))) {
            $findings += New-AssetDocFinding -Level $level -Category 'Coverage' -Path $model.DocRel -Message "Missing documentation page for asset '$($model.SourceRel)'."
        }
    }
    return $findings
}

function Test-AssetDocOrphan {
    <#
    .SYNOPSIS
        Finds docs/reference pages that map to no documentable asset.
    .DESCRIPTION
        Reference index pages (README.md) are excluded because they are
        generated indexes rather than per-asset pages.
    .PARAMETER Models
        Page models from New-AssetPageModel.
    .PARAMETER RepoRoot
        Repository root directory.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Models,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot
    )

    $findings = @()
    $docsRoot = Join-Path $RepoRoot 'docs/reference'
    if (-not (Test-Path -LiteralPath $docsRoot)) {
        return $findings
    }

    $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($model in $Models) {
        [void]$expected.Add($model.DocRel)
    }

    $pages = Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
    foreach ($page in $pages) {
        if ($page.Name -eq 'README.md') {
            continue
        }
        $rel = ([System.IO.Path]::GetRelativePath($RepoRoot, $page.FullName)) -replace '\\', '/'
        if (-not $expected.Contains($rel)) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Orphan' -Path $rel -Message 'Orphaned documentation page has no matching asset.'
        }
    }
    return $findings
}

function Test-AssetDocStructure {
    <#
    .SYNOPSIS
        Verifies required headings and generated-region markers on a page.
    .PARAMETER Model
        Page model from New-AssetPageModel.
    .PARAMETER Content
        Page file content.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $findings = @()

    $required = @('## What it does', '## When to use it', '## Example usage')
    if ($Model.Interactive) {
        $required += '## How to use it'
    }
    foreach ($heading in $required) {
        $pattern = '(?m)^' + [regex]::Escape($heading) + '\s*$'
        if ($Content -notmatch $pattern) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Structure' -Path $Model.DocRel -Message "Missing required section '$heading'."
        }
    }

    foreach ($region in @('metadata', 'overview')) {
        if (-not (Split-AssetDocByMarkers -Content $Content -Region $region).HasMarkers) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Structure' -Path $Model.DocRel -Message "Missing generated-region markers for '$region'."
        }
    }

    return $findings
}

function Test-AssetDocRegionSync {
    <#
    .SYNOPSIS
        Compares a page's generated regions against a fresh render.
    .PARAMETER Model
        Page model from New-AssetPageModel.
    .PARAMETER Content
        Page file content.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $findings = @()

    $freshMetadata = (New-AssetMetadataBlock -Kind $Model.Kind -SourcePath $Model.SourceRel -Invocation $Model.Invocation -Interactive $Model.Interactive).Trim("`r", "`n")
    $freshOverview = (New-AssetOverviewBody -Model $Model).Trim("`r", "`n")

    $regions = @(
        @{ Name = 'metadata'; Fresh = $freshMetadata },
        @{ Name = 'overview'; Fresh = $freshOverview }
    )

    foreach ($region in $regions) {
        $split = Split-AssetDocByMarkers -Content $Content -Region $region.Name
        if (-not $split.HasMarkers) {
            # Missing markers are reported by the structure check.
            continue
        }
        if (-not [string]::Equals($split.Body, $region.Fresh, [System.StringComparison]::Ordinal)) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Sync' -Path $Model.DocRel -Message "Generated '$($region.Name)' region is out of sync; run npm run docs:generate."
        }
    }

    return $findings
}

function Test-AssetDocAuthored {
    <#
    .SYNOPSIS
        Detects pages whose human sections still contain stub placeholders.
    .PARAMETER Model
        Page model from New-AssetPageModel.
    .PARAMETER Content
        Page file content.
    .PARAMETER RequireAuthoredContent
        Emit an error instead of a warning when stubs remain.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model,
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $false)][switch]$RequireAuthoredContent
    )

    if (Test-AssetDocStub -Content $Content) {
        $level = if ($RequireAuthoredContent) { 'Error' } else { 'Warning' }
        return @(New-AssetDocFinding -Level $level -Category 'Authored' -Path $Model.DocRel -Message 'Human-authored sections still contain unwritten stub placeholders.')
    }
    return @()
}

#endregion Checks

#region Output

function Write-AssetDocsValidationResults {
    <#
    .SYNOPSIS
        Writes validation findings to the console and a JSON results file.
    .PARAMETER Findings
        Validation findings.
    .PARAMETER AssetCount
        Number of documentable assets evaluated.
    .PARAMETER RepoRoot
        Repository root directory.
    .PARAMETER OutputPath
        Repo-relative JSON output path.
    .PARAMETER Options
        Hashtable of the enabled check switches for the summary.
    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Findings,
        [Parameter(Mandatory = $true)][int]$AssetCount,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$OutputPath,
        [Parameter(Mandatory = $true)][hashtable]$Options
    )

    $isCI = Test-CIEnvironment
    $errorCount = @($Findings | Where-Object { $_.Level -eq 'Error' }).Count
    $warningCount = @($Findings | Where-Object { $_.Level -eq 'Warning' }).Count

    Write-Host "`nAsset Docs Validation Results" -ForegroundColor Cyan
    Write-Host ('-' * 40) -ForegroundColor Cyan

    foreach ($finding in $Findings) {
        $prefix = "[$($finding.Category)] $($finding.Path): $($finding.Message)"
        if ($finding.Level -eq 'Error') {
            Write-Host "  ERROR: $prefix" -ForegroundColor Red
            if ($isCI) { Write-CIAnnotation -Message $finding.Message -Level Error -File $finding.Path }
        }
        else {
            Write-Host "  WARNING: $prefix" -ForegroundColor Yellow
            if ($isCI) { Write-CIAnnotation -Message $finding.Message -Level Warning -File $finding.Path }
        }
    }

    Write-Host "`nSummary:" -ForegroundColor Cyan
    Write-Host "   Assets evaluated: $AssetCount" -ForegroundColor Gray
    Write-Host "   Errors:           $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "   Warnings:         $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { 'Yellow' } else { 'Green' })

    $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $RepoRoot $OutputPath }
    $outputDir = Split-Path -Parent $resolvedOutputPath
    if ($outputDir -and -not (Test-Path -LiteralPath $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $jsonOutput = [ordered]@{
        Timestamp    = Get-StandardTimestamp
        assetCount   = $AssetCount
        errorCount   = $errorCount
        warningCount = $warningCount
        options      = $Options
        findings     = @($Findings | ForEach-Object {
                [ordered]@{
                    level    = $_.Level
                    category = $_.Category
                    path     = $_.Path
                    message  = $_.Message
                }
            })
    }
    $jsonOutput | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $resolvedOutputPath -Encoding utf8NoBOM
    Write-Host "Results written to: $resolvedOutputPath" -ForegroundColor Cyan
}

#endregion Output

#region Orchestration

function Invoke-AssetDocsValidation {
    <#
    .SYNOPSIS
        Runs all asset-docs checks and returns an exit code.
    .PARAMETER RepoRoot
        Repository root directory.
    .PARAMETER FailOnMissing
        Treat missing pages as errors.
    .PARAMETER CheckSync
        Enable the generated-region sync check.
    .PARAMETER RequireAuthoredContent
        Treat remaining stub sections as errors.
    .PARAMETER OutputPath
        Repo-relative JSON output path.
    .OUTPUTS
        [int] Exit code: 0 for success, 1 when error-level findings exist.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
        [Parameter(Mandatory = $false)][switch]$FailOnMissing,
        [Parameter(Mandatory = $false)][switch]$CheckSync,
        [Parameter(Mandatory = $false)][switch]$RequireAuthoredContent,
        [Parameter(Mandatory = $false)][string]$OutputPath = 'logs/asset-docs-validation-results.json'
    )

    try {
        $assets = Get-DocumentableAssets -RepoRoot $RepoRoot
        $models = @($assets | ForEach-Object { New-AssetPageModel -Asset $_ -RepoRoot $RepoRoot })

        $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($f in @(Test-AssetDocCoverage -Models $models -RepoRoot $RepoRoot -FailOnMissing:$FailOnMissing)) { $findings.Add($f) }
        foreach ($f in @(Test-AssetDocOrphan -Models $models -RepoRoot $RepoRoot)) { $findings.Add($f) }

        foreach ($model in $models) {
            $full = Join-Path $RepoRoot $model.DocRel
            if (-not (Test-Path -LiteralPath $full)) {
                continue
            }
            $content = Get-Content -LiteralPath $full -Raw

            foreach ($f in @(Test-AssetDocStructure -Model $model -Content $content)) { $findings.Add($f) }
            foreach ($f in @(Test-AssetDocAuthored -Model $model -Content $content -RequireAuthoredContent:$RequireAuthoredContent)) { $findings.Add($f) }
            if ($CheckSync) {
                foreach ($f in @(Test-AssetDocRegionSync -Model $model -Content $content)) { $findings.Add($f) }
            }
        }

        $options = [ordered]@{
            failOnMissing          = [bool]$FailOnMissing
            checkSync              = [bool]$CheckSync
            requireAuthoredContent = [bool]$RequireAuthoredContent
        }
        Write-AssetDocsValidationResults -Findings $findings.ToArray() -AssetCount $models.Count -RepoRoot $RepoRoot -OutputPath $OutputPath -Options $options

        $hasErrors = @($findings | Where-Object { $_.Level -eq 'Error' }).Count -gt 0
        if ($hasErrors) {
            return 1
        }

        Write-Host "Asset docs validation complete" -ForegroundColor Green
        return 0
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-AssetDocs failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        return 1
    }
}

#endregion Orchestration

if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-AssetDocsValidation `
        -RepoRoot $RepoRoot `
        -FailOnMissing:$FailOnMissing `
        -CheckSync:$CheckSync `
        -RequireAuthoredContent:$RequireAuthoredContent `
        -OutputPath $OutputPath
    exit $exitCode
}
