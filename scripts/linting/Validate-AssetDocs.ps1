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
    5. Authored    - human sections differ from stubs (warning by default;
                     required-section stubs are errors for kinds selected by
                     -RequireAuthoredContent).

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
    One or more asset kinds whose Required human-authored sections must not
    contain stub placeholders. Supported values are agent, prompt, instruction,
    and skill. Separate multiple command-line values with commas. Optional-
    section stubs remain warnings.

.PARAMETER ChangedFilesOnly
    Validate only assets and documentation pages affected by changed files.
    Orphans are reported only when the page or its would-be source asset changed.

.PARAMETER BaseBranch
    Git reference used for changed-file detection. Defaults to origin/main.

.PARAMETER OutputPath
    Path for the JSON results file. Defaults to
    logs/asset-docs-validation-results.json.

.EXAMPLE
    ./Validate-AssetDocs.ps1
    Reports coverage as warnings and authored stubs as warnings.

.EXAMPLE
    ./Validate-AssetDocs.ps1 -FailOnMissing -CheckSync
    Hard-fails on missing pages, orphans, sync drift, and structure problems.

.EXAMPLE
    ./Validate-AssetDocs.ps1 -FailOnMissing -CheckSync -RequireAuthoredContent instruction
    Also hard-fails when an instruction page has a stubbed Required human
    section. Optional instruction examples remain advisory.

.NOTES
    Runs via: npm run lint:asset-docs
    Dependencies: DocsHelpers, and CIHelpers modules.
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
    [ValidateScript({
            $values = @(($_ -split ',') | ForEach-Object { $_.Trim() })
            $invalid = @($values | Where-Object { [string]::IsNullOrWhiteSpace($_) -or $_ -notin @('agent', 'prompt', 'instruction', 'skill') })
            if ($invalid.Count -gt 0) {
                throw "Unsupported asset kind: $($invalid -join ', '). Supported values are agent, prompt, instruction, and skill."
            }
            return $true
        })]
    [string[]]$RequireAuthoredContent = @(),

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [ValidateNotNullOrEmpty()]
    [string]$BaseBranch = 'origin/main',

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/asset-docs-validation-results.json'
)

$ErrorActionPreference = 'Stop'

$normalizedAuthoredKinds = [System.Collections.Generic.List[string]]::new()
foreach ($value in $RequireAuthoredContent) {
    foreach ($kind in ($value -split ',')) {
        $normalizedKind = $kind.Trim().ToLowerInvariant()
        if (-not $normalizedAuthoredKinds.Contains($normalizedKind)) {
            $normalizedAuthoredKinds.Add($normalizedKind)
        }
    }
}
$RequireAuthoredContent = $normalizedAuthoredKinds.ToArray()

# Import the modules this script calls directly, highest-level first and
# lowest-level last, so each -Force re-import re-scopes shared dependencies in
# dependency order and every command used here resolves in this script's scope.
# DocsHelpers exposes the shared
# render helpers (New-AssetPageModel, New-AssetMetadataBlock, New-AssetOverviewBody)
# so the sync check renders exactly what the generator produces.
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../docs/Modules/DocsHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

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

function Get-AssetDocPagePath {
    <#
    .SYNOPSIS
        Enumerates repo-relative paths of per-asset documentation pages.
    .DESCRIPTION
        Returns every docs/reference markdown page except generated README
        index pages, normalized to forward-slash separators so the paths
        compare directly against model DocRel values. Callers must compare
        these paths case-sensitively (Ordinal) so a miscased page is neither
        accepted as coverage nor hidden from orphan detection.
    .PARAMETER RepoRoot
        Repository root directory.
    .OUTPUTS
        [string[]] Repo-relative page paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot
    )

    $docsRoot = Join-Path $RepoRoot 'docs/reference'
    if (-not (Test-Path -LiteralPath $docsRoot)) {
        return @()
    }

    $pages = Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
    $paths = foreach ($page in $pages) {
        if ($page.Name -eq 'README.md') {
            continue
        }
        ([System.IO.Path]::GetRelativePath($RepoRoot, $page.FullName)) -replace '\\', '/'
    }
    return @($paths)
}

function Get-AssetDocSourcePath {
    <#
    .SYNOPSIS
        Maps an asset documentation page to its would-be source asset path.
    .DESCRIPTION
        Reverses the deterministic docs/reference path convention for agent,
        prompt, instruction, and skill pages. Skill results are directory paths;
        other kinds are file paths. Returns null for non-asset pages.
    .PARAMETER DocPath
        Repo-relative asset documentation page path.
    .OUTPUTS
        [string] Repo-relative source asset path, or null when not recognized.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DocPath
    )

    $normalized = $DocPath -replace '\\', '/'
    if ($normalized -notmatch '^docs/reference/(?<kind>agents|prompts|instructions|skills)/(?<remainder>.+)\.md$') {
        return $null
    }

    $kind = $Matches['kind']
    $remainder = $Matches['remainder']
    switch ($kind) {
        'agents' { return ".github/agents/$remainder.agent.md" }
        'prompts' { return ".github/prompts/$remainder.prompt.md" }
        'instructions' { return ".github/instructions/$remainder.instructions.md" }
        'skills' { return ".github/skills/$remainder" }
    }
}

function Test-AssetDocModelChanged {
    <#
    .SYNOPSIS
        Tests whether a page model is affected by changed files.
    .PARAMETER Model
        Page model from New-AssetPageModel.
    .PARAMETER ChangedFiles
        Repo-relative changed file paths.
    .OUTPUTS
        [bool] True when the source asset or documentation page changed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ChangedFiles
    )

    foreach ($file in $ChangedFiles) {
        $normalized = $file -replace '\\', '/'
        if ([string]::Equals($normalized, $Model.DocRel, [System.StringComparison]::Ordinal)) {
            return $true
        }
        if ([string]::Equals($normalized, $Model.SourceRel, [System.StringComparison]::Ordinal)) {
            return $true
        }
        if ($Model.Kind -eq 'skill' -and $normalized.StartsWith("$($Model.SourceRel)/", [System.StringComparison]::Ordinal)) {
            return $true
        }
    }

    return $false
}

function Test-AssetDocOrphanChanged {
    <#
    .SYNOPSIS
        Tests whether an orphan page is in changed-file scope.
    .PARAMETER DocPath
        Repo-relative orphan documentation path.
    .PARAMETER ChangedFiles
        Repo-relative changed file paths.
    .OUTPUTS
        [bool] True when the page or its would-be source asset changed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$DocPath,
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][string[]]$ChangedFiles
    )

    $sourcePath = Get-AssetDocSourcePath -DocPath $DocPath
    foreach ($file in $ChangedFiles) {
        $normalized = $file -replace '\\', '/'
        if ([string]::Equals($normalized, $DocPath, [System.StringComparison]::Ordinal)) {
            return $true
        }
        if ($sourcePath -and [string]::Equals($normalized, $sourcePath, [System.StringComparison]::Ordinal)) {
            return $true
        }
        if ($sourcePath -and $sourcePath.StartsWith('.github/skills/', [System.StringComparison]::Ordinal) -and
            $normalized.StartsWith("$sourcePath/", [System.StringComparison]::Ordinal)) {
            return $true
        }
    }

    return $false
}

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

    # Match pages by exact case (Ordinal) so a miscased page such as
    # docs/reference/Agents/foo.md is not silently accepted as covering the
    # expected lowercase docs/reference/agents/foo.md on case-insensitive
    # filesystems.
    $actual = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($page in (Get-AssetDocPagePath -RepoRoot $RepoRoot)) {
        [void]$actual.Add($page)
    }

    foreach ($model in $Models) {
        if (-not $actual.Contains($model.DocRel)) {
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
    .PARAMETER ChangedFiles
        Optional changed-file scope. When supplied, reports an orphan only when
        the page or its would-be source asset is present in this list.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyCollection()][object[]]$Models,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
        [Parameter(Mandatory = $false)][AllowEmptyCollection()][string[]]$ChangedFiles
    )

    $findings = @()

    # Ordinal (case-sensitive) comparison so a miscased page path such as
    # docs/reference/Agents/foo.md is still flagged as an orphan on
    # case-sensitive filesystems, where it does not match the expected
    # lowercase docs/reference/agents/foo.md.
    $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($model in $Models) {
        [void]$expected.Add($model.DocRel)
    }

    foreach ($rel in (Get-AssetDocPagePath -RepoRoot $RepoRoot)) {
        if (-not $expected.Contains($rel)) {
            if ($PSBoundParameters.ContainsKey('ChangedFiles') -and
                -not (Test-AssetDocOrphanChanged -DocPath $rel -ChangedFiles $ChangedFiles)) {
                continue
            }
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Orphan' -Path $rel -Message 'Orphaned documentation page has no matching asset.'
        }
    }
    return $findings
}

function Test-AssetDocStructure {
    <#
    .SYNOPSIS
        Verifies required headings, canonical section order, and generated-region
        markers on a page.
    .DESCRIPTION
        Reports duplicate contract headings, a missing Required section, an
        applicable section that appears out of the contract's canonical order,
        and a damaged generated-region marker pair. Optional sections are only
        order-checked when the page includes them. NotApplicable sections are
        checked for duplicates but excluded from presence and order checks.
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

    $present = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($section in (Get-AssetDocSectionContract)) {
        $status = Resolve-AssetDocSectionStatus -Section $section -Kind $Model.Kind -Interactive $Model.Interactive
        $heading = $section.Heading
        $headingMatches = [regex]::Matches($Content, '(?m)^' + [regex]::Escape($heading) + '\s*$')
        if ($headingMatches.Count -gt 1) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Structure' -Path $Model.DocRel -Message "Duplicate section '$heading' appears $($headingMatches.Count) times; contract headings must be unique."
        }

        if ($status -eq 'NotApplicable') {
            continue
        }

        if ($headingMatches.Count -eq 0) {
            if ($status -eq 'Required') {
                $findings += New-AssetDocFinding -Level 'Error' -Category 'Structure' -Path $Model.DocRel -Message "Missing required section '$heading'."
            }
            continue
        }

        $present.Add([PSCustomObject]@{ Heading = $heading; Index = $headingMatches[0].Index })
    }

    # The contract declares canonical order, so a page that carries every heading
    # in the wrong sequence must fail rather than pass an existence-only check.
    for ($i = 1; $i -lt $present.Count; $i++) {
        if ($present[$i].Index -lt $present[$i - 1].Index) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Structure' -Path $Model.DocRel -Message "Section '$($present[$i].Heading)' must appear after '$($present[$i - 1].Heading)' in canonical contract order."
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
        # Normalize line endings before comparison. Committed pages check out as
        # CRLF on Windows (git autocrlf) while the renderer emits LF, so an ordinal
        # compare would report false drift. Line endings are a platform concern,
        # not generated-content drift.
        $actualBody = $split.Body -replace '\r\n', "`n" -replace '\r', "`n"
        $expectedBody = $region.Fresh -replace '\r\n', "`n" -replace '\r', "`n"
        if (-not [string]::Equals($actualBody, $expectedBody, [System.StringComparison]::Ordinal)) {
            $findings += New-AssetDocFinding -Level 'Error' -Category 'Sync' -Path $Model.DocRel -Message "Generated '$($region.Name)' region is out of sync; run npm run docs:generate."
        }
    }

    return $findings
}

function Get-AssetDocSectionBody {
    <#
    .SYNOPSIS
        Extracts the body of a named H2 section.
    .DESCRIPTION
        Returns the content after an exact H2 heading through the next H2 or
        end of content. Returns null when the heading is absent. Structure
        validation remains responsible for required-heading presence.
    .PARAMETER Content
        Full page content.
    .PARAMETER Heading
        Exact H2 heading from the shared asset-documentation contract.
    .OUTPUTS
        [string] Section body, or null when the heading is absent.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Heading
    )

    $pattern = '(?ms)^' + [regex]::Escape($Heading) + '[ \t]*\r?\n(?<Body>.*?)(?=^##(?:[ \t]|$)|\z)'
    $match = [regex]::Match($Content, $pattern)
    if (-not $match.Success) {
        return $null
    }

    return $match.Groups['Body'].Value.Trim("`r", "`n")
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
        Asset kinds whose Required section stubs produce an error.
    .OUTPUTS
        [PSCustomObject[]] Findings.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model,
        [Parameter(Mandatory = $true)][string]$Content,
        [Parameter(Mandatory = $false)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string[]]$RequireAuthoredContent = @()
    )

    $stubbedSections = [System.Collections.Generic.List[PSCustomObject]]::new()
    foreach ($section in (Get-AssetDocSectionContract)) {
        if ([string]::IsNullOrWhiteSpace($section.TemplateRegion)) {
            continue
        }

        $status = Resolve-AssetDocSectionStatus -Section $section -Kind $Model.Kind -Interactive $Model.Interactive
        if ($status -eq 'NotApplicable') {
            continue
        }

        $body = Get-AssetDocSectionBody -Content $Content -Heading $section.Heading
        if ($null -ne $body -and (Test-AssetDocStub -Content $body)) {
            $stubbedSections.Add([PSCustomObject]@{
                    Heading = $section.Heading
                    Status  = $status
                })
        }
    }

    if ($stubbedSections.Count -gt 0) {
        $hasRequiredStub = @($stubbedSections | Where-Object Status -EQ 'Required').Count -gt 0
        $kindIsRequired = $RequireAuthoredContent -contains $Model.Kind
        $level = if ($kindIsRequired -and $hasRequiredStub) { 'Error' } else { 'Warning' }
        $headings = @($stubbedSections | ForEach-Object { "'$($_.Heading)'" }) -join ', '
        return @(New-AssetDocFinding -Level $level -Category 'Authored' -Path $Model.DocRel -Message "Human-authored sections still contain unwritten stub placeholders: $headings.")
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
        Asset kinds whose Required section stubs produce errors.
    .PARAMETER ChangedFilesOnly
        Validate only assets and pages affected by changed files.
    .PARAMETER BaseBranch
        Git reference used for changed-file detection.
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
        [Parameter(Mandatory = $false)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string[]]$RequireAuthoredContent = @(),
        [Parameter(Mandatory = $false)][switch]$ChangedFilesOnly,
        [Parameter(Mandatory = $false)][ValidateNotNullOrEmpty()][string]$BaseBranch = 'origin/main',
        [Parameter(Mandatory = $false)][string]$OutputPath = 'logs/asset-docs-validation-results.json'
    )

    try {
        $assets = Get-DocumentableAssets -RepoRoot $RepoRoot
        $models = @($assets | ForEach-Object { New-AssetPageModel -Asset $_ -RepoRoot $RepoRoot })
        $changedFiles = @()
        $modelsToValidate = $models

        if ($ChangedFilesOnly) {
            $changedFiles = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*') -IncludeDeleted |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { $_ -replace '\\', '/' } |
                Sort-Object -Unique)
            $modelsToValidate = @($models | Where-Object { Test-AssetDocModelChanged -Model $_ -ChangedFiles $changedFiles })
            Write-Host "Changed-file mode selected $($modelsToValidate.Count) asset(s) from $($changedFiles.Count) changed path(s)" -ForegroundColor Cyan
        }

        $findings = [System.Collections.Generic.List[PSCustomObject]]::new()
        foreach ($f in @(Test-AssetDocCoverage -Models $modelsToValidate -RepoRoot $RepoRoot -FailOnMissing:$FailOnMissing)) { $findings.Add($f) }

        $orphanParams = @{ Models = $models; RepoRoot = $RepoRoot }
        if ($ChangedFilesOnly) { $orphanParams['ChangedFiles'] = $changedFiles }
        foreach ($f in @(Test-AssetDocOrphan @orphanParams)) { $findings.Add($f) }

        foreach ($model in $modelsToValidate) {
            $full = Join-Path $RepoRoot $model.DocRel
            if (-not (Test-Path -LiteralPath $full)) {
                continue
            }
            $content = Get-Content -LiteralPath $full -Raw

            foreach ($f in @(Test-AssetDocStructure -Model $model -Content $content)) { $findings.Add($f) }
            foreach ($f in @(Test-AssetDocAuthored -Model $model -Content $content -RequireAuthoredContent $RequireAuthoredContent)) { $findings.Add($f) }
            if ($CheckSync) {
                foreach ($f in @(Test-AssetDocRegionSync -Model $model -Content $content)) { $findings.Add($f) }
            }
        }

        $options = [ordered]@{
            failOnMissing          = [bool]$FailOnMissing
            checkSync              = [bool]$CheckSync
            requireAuthoredContent = @($RequireAuthoredContent)
            changedFilesOnly       = [bool]$ChangedFilesOnly
            baseBranch             = $BaseBranch
        }
        Write-AssetDocsValidationResults -Findings $findings.ToArray() -AssetCount $modelsToValidate.Count -RepoRoot $RepoRoot -OutputPath $OutputPath -Options $options

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
        -RequireAuthoredContent $RequireAuthoredContent `
        -ChangedFilesOnly:$ChangedFilesOnly `
        -BaseBranch $BaseBranch `
        -OutputPath $OutputPath
    exit $exitCode
}
