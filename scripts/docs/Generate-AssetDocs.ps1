#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Generates per-asset reference documentation pages for every documentable
    GenAI asset (agent, prompt, instruction, skill).

.DESCRIPTION
    Deterministic, idempotent generator modeled on the collection README
    refresh in scripts/extension/Prepare-Extension.ps1. For each documentable
    asset it scaffolds a docs/reference/<kind>/... page from the shared
    template and refreshes only the AUTO-GENERATED regions (metadata and
    "What it does"), preserving human-authored sections verbatim. It also
    generates the reference index pages (docs/reference/README.md and
    docs/reference/<kind>/README.md), assigns a stable sidebar_position to
    every page based on its position among sibling pages, and removes an
    orphaned per-asset page only when its generated markers are intact and its
    human-section tail still matches a canonical scaffold exactly.

    The generator never calls a model. The "Example usage" and other
    human-authored sections are authored separately (human-in-the-loop).
    Running with -WhatIf reports drift (pages that would be created, updated,
    or safely removed) without changing documentation pages. The JSON run
    summary is still written to OutputPath. Orphaned pages with authored or
    ambiguous content are preserved and reported as needing attention.

.PARAMETER RepoRoot
    Repository root directory. Assets are discovered under <RepoRoot>/.github
    and pages are written under <RepoRoot>/docs/reference.

.PARAMETER TemplatePath
    Path to the asset documentation template. Defaults to the template shipped
    alongside this script under templates/asset-doc.template.md.

.PARAMETER OutputPath
    Path for the JSON run summary. Defaults to
    logs/asset-docs-generation-results.json.

.EXAMPLE
    ./Generate-AssetDocs.ps1
    Scaffolds or refreshes every asset documentation page.

.EXAMPLE
    ./Generate-AssetDocs.ps1 -WhatIf
    Reports which pages would be created or updated without writing them.

.NOTES
    Runs via: npm run docs:generate
    Dependencies: PowerShell-Yaml module (via DocsHelpers/CollectionHelpers).
#>

[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ((git rev-parse --show-toplevel 2>$null) ?? (Split-Path $PSScriptRoot -Parent | Split-Path -Parent)),

    [Parameter(Mandatory = $false)]
    [string]$TemplatePath = (Join-Path $PSScriptRoot 'templates/asset-doc.template.md'),

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/asset-docs-generation-results.json'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/DocsHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../collections/Modules/CollectionHelpers.psm1') -Force

#region Pure Helpers

function New-DocFrontmatter {
    <#
    .SYNOPSIS
        Builds a Docusaurus frontmatter block.
    .PARAMETER Title
        Page title.
    .PARAMETER Description
        Page description.
    .PARAMETER SidebarPosition
        Stable sidebar position.
    .PARAMETER MsDate
        ISO 8601 last-modified date.
    .OUTPUTS
        [string] The frontmatter block including the delimiting fences.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Title,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Description,
        [Parameter(Mandatory = $true)][int]$SidebarPosition,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$MsDate
    )

    return (@(
            '---'
            "title: $(Format-YamlScalar -Value $Title)"
            "description: $(Format-YamlScalar -Value $Description)"
            "sidebar_position: $SidebarPosition"
            "ms.date: $MsDate"
            '---'
        ) -join "`n")
}

function Remove-HowToUseSection {
    <#
    .SYNOPSIS
        Removes the "How to use it" section from a human-section tail.
    .DESCRIPTION
        Non-interactive assets have no interactive usage flow, so the template's
        "How to use it" section is dropped when scaffolding a new page for them.
        Existing pages are never modified by this function.

        The terminating lookahead matches either the next H2 heading or the end
        of the string (\z), so the section is removed even when "How to use it"
        is the last H2 on the page rather than being followed by another heading.
    .PARAMETER Tail
        The human-section tail beginning at the first section heading.
    .OUTPUTS
        [string] The tail with the "How to use it" section removed.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Tail
    )

    return ($Tail -replace '(?ms)\r?\n## How to use it\b.*?(?=\r?\n## |\z)', '')
}

function Get-AssetDocPageRelPath {
    <#
    .SYNOPSIS
        Enumerates repo-relative per-asset reference page paths.
    .PARAMETER RepoRoot
        Repository root directory.
    .OUTPUTS
        [string[]] Markdown page paths excluding generated README indexes.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $docsRoot = Join-Path $RepoRoot 'docs/reference'
    if (-not (Test-Path -LiteralPath $docsRoot)) {
        return @()
    }

    $paths = foreach ($page in (Get-ChildItem -LiteralPath $docsRoot -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
        if ($page.Name -eq 'README.md') {
            continue
        }
        ([System.IO.Path]::GetRelativePath($RepoRoot, $page.FullName)) -replace '\\', '/'
    }
    return @($paths)
}

function Test-AssetDocScaffoldOrphan {
    <#
    .SYNOPSIS
        Determines whether an orphan page is an untouched generated scaffold.
    .DESCRIPTION
        Requires exactly one begin and end marker for both generated regions,
        valid marker ordering, and a post-overview tail that is byte-identical
        to either canonical interactive or non-interactive scaffold tail.
    .PARAMETER Content
        Full orphan page content.
    .PARAMETER InteractiveTail
        Canonical interactive template tail.
    .PARAMETER NonInteractiveTail
        Canonical non-interactive template tail.
    .OUTPUTS
        [bool] True only when automatic removal cannot discard authored prose.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$InteractiveTail,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$NonInteractiveTail
    )

    foreach ($region in @('metadata', 'overview')) {
        foreach ($boundary in @('Begin', 'End')) {
            $marker = Get-AssetDocMarker -Region $region -Boundary $boundary
            if ([regex]::Matches($Content, [regex]::Escape($marker)).Count -ne 1) {
                return $false
            }
        }
    }

    $metadata = Split-AssetDocByMarkers -Content $Content -Region 'metadata'
    $overview = Split-AssetDocByMarkers -Content $Content -Region 'overview'
    if (-not $metadata.HasMarkers -or -not $overview.HasMarkers) {
        return $false
    }

    $metadataBegin = $Content.IndexOf((Get-AssetDocMarker -Region 'metadata' -Boundary Begin), [System.StringComparison]::Ordinal)
    $metadataEnd = $Content.IndexOf((Get-AssetDocMarker -Region 'metadata' -Boundary End), [System.StringComparison]::Ordinal)
    $overviewBegin = $Content.IndexOf((Get-AssetDocMarker -Region 'overview' -Boundary Begin), [System.StringComparison]::Ordinal)
    $overviewEnd = $Content.IndexOf((Get-AssetDocMarker -Region 'overview' -Boundary End), [System.StringComparison]::Ordinal)
    if (-not ($metadataBegin -lt $metadataEnd -and $metadataEnd -lt $overviewBegin -and $overviewBegin -lt $overviewEnd)) {
        return $false
    }

    return [string]::Equals($overview.After, $InteractiveTail, [System.StringComparison]::Ordinal) -or
        [string]::Equals($overview.After, $NonInteractiveTail, [System.StringComparison]::Ordinal)
}

#endregion Pure Helpers

#region Content Builders

function Get-TemplateHumanTail {
    <#
    .SYNOPSIS
        Extracts the human-authored section tail from the page template.
    .PARAMETER TemplatePath
        Path to the asset documentation template.
    .PARAMETER Interactive
        Whether the target asset is interactive. When false, the "How to use it"
        section is stripped from the returned tail.
    .OUTPUTS
        [string] The template's human-authored tail (from the first section
        heading onward).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TemplatePath,
        [Parameter(Mandatory = $true)][bool]$Interactive
    )

    $template = Get-Content -LiteralPath $TemplatePath -Raw
    $split = Split-AssetDocByMarkers -Content $template -Region 'overview'
    $tail = $split.After

    if (-not $Interactive) {
        $tail = Remove-HowToUseSection -Tail $tail
    }

    return $tail
}

function New-AssetDocContent {
    <#
    .SYNOPSIS
        Builds the full documentation page content for an asset.
    .DESCRIPTION
        Assembles frontmatter, the refreshed metadata and overview regions, and
        the human-authored tail. For an existing page the human-authored tail is
        preserved; for a new page the tail comes from the template. Throws
        when an existing page is missing its overview markers, so human-authored
        sections are never discarded (the orchestrator pre-checks and skips such
        pages before calling this function).

        The ms.date field reflects the last time the generated content changed:
        it is preserved from the existing page when regeneration produces
        identical output, and advanced to today whenever the regenerated
        frontmatter or auto-generated regions differ. New pages are stamped with
        today's date. Human-only edits do not advance ms.date because the tail is
        preserved verbatim, so the regenerated output matches the existing page.
    .PARAMETER Model
        Page model from New-AssetPageModel.
    .PARAMETER RepoRoot
        Repository root directory.
    .PARAMETER ExistingContent
        Existing page content preloaded by the caller. When omitted, the
        function reads an existing page from disk for direct-call compatibility.
    .PARAMETER TemplatePath
        Path to the asset documentation template.
    .PARAMETER SidebarPosition
        Stable sidebar position for the page.
    .OUTPUTS
        [string] The complete page content ending with a single newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
        [Parameter(Mandatory = $false)][AllowNull()][string]$ExistingContent = $null,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TemplatePath,
        [Parameter(Mandatory = $true)][int]$SidebarPosition
    )

    $docFull = Join-Path $RepoRoot $Model.DocRel
    $today = Get-Date -Format 'yyyy-MM-dd'

    if (Test-Path -LiteralPath $docFull) {
        $existing = if ($PSBoundParameters.ContainsKey('ExistingContent')) {
            $ExistingContent
        }
        else {
            Get-Content -LiteralPath $docFull -Raw
        }
        $existingFm = Get-AssetFrontmatter -FilePath $docFull
        $msDate = if ($existingFm.ContainsKey('ms.date') -and $existingFm['ms.date']) {
            [string]$existingFm['ms.date']
        }
        else { $today }

        $split = Split-AssetDocByMarkers -Content $existing -Region 'overview'
        if (-not $split.HasMarkers) {
            # Defense in depth: refuse to regenerate an existing page whose overview
            # markers are missing, mirroring Merge-AssetDocRegion. Rebuilding the tail
            # from the template here would discard the human-authored sections. The
            # orchestrator pre-checks this condition and skips such pages, so this
            # guard is normally unreachable.
            throw "Overview markers missing in $($Model.DocRel); refusing to regenerate because doing so would discard human-authored sections. Restore the AUTO-GENERATED markers (or delete the page to re-scaffold) and re-run."
        }
        $humanTail = $split.After
    }
    else {
        $msDate = $today
        $humanTail = Get-TemplateHumanTail -TemplatePath $TemplatePath -Interactive $Model.Interactive
    }

    $descriptionMeta = if ([string]::IsNullOrWhiteSpace($Model.Description)) {
        "Reference documentation for the $($Model.Key) $($Model.Kind)."
    }
    else {
        ($Model.Description -replace '\r?\n', ' ').Trim()
    }
    $overviewBody = New-AssetOverviewBody -Model $Model

    $metadataRegion = New-AssetGeneratedRegion -Region 'metadata' -Body (New-AssetMetadataBlock -Kind $Model.Kind -SourcePath $Model.SourceRel -Invocation $Model.Invocation -Interactive $Model.Interactive)
    $overviewRegion = New-AssetGeneratedRegion -Region 'overview' -Body $overviewBody
    $generatedTail = "`n`n$metadataRegion`n`n## What it does`n`n$overviewRegion" + $humanTail

    # Assemble with the preserved ms.date first, then advance it to today only
    # when the regenerated output differs from the existing page. This makes
    # ms.date track the last time the generated frontmatter or regions changed
    # rather than the first-scaffold date, while staying idempotent: rebuilding
    # with an unchanged date reproduces the file byte-for-byte, and preserved
    # human sections keep the output identical so human-only edits never advance
    # the date.
    $content = ((New-DocFrontmatter -Title $Model.Title -Description $descriptionMeta -SidebarPosition $SidebarPosition -MsDate $msDate) + $generatedTail).TrimEnd() + "`n"

    if ($null -ne $existing -and -not [string]::Equals($content, $existing, [System.StringComparison]::Ordinal)) {
        $content = ((New-DocFrontmatter -Title $Model.Title -Description $descriptionMeta -SidebarPosition $SidebarPosition -MsDate $today) + $generatedTail).TrimEnd() + "`n"
    }

    return $content
}

function New-KindIndexContent {
    <#
    .SYNOPSIS
        Builds the index page content for a single asset kind.
    .PARAMETER KindDir
        The docs directory segment for the kind (for example, agents).
    .PARAMETER Pages
        Page models belonging to the kind.
    .PARAMETER RepoRoot
        Repository root directory.
    .OUTPUTS
        [string] The index page content ending with a single newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$KindDir,
        [Parameter(Mandatory = $true)][object[]]$Pages,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot
    )

    $title = (Get-Culture).TextInfo.ToTitleCase($KindDir)
    $indexRel = "docs/reference/$KindDir/README.md"
    $indexDir = Split-Path -Path (Join-Path $RepoRoot $indexRel) -Parent

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($page in ($Pages | Sort-Object DocRel)) {
        $target = Join-Path $RepoRoot $page.DocRel
        $link = ([System.IO.Path]::GetRelativePath($indexDir, $target)) -replace '\\', '/'
        $descCell = if ([string]::IsNullOrWhiteSpace($page.Description)) { '' } else { ConvertTo-TableCell -Value $page.Description }
        $titleCell = ConvertTo-TableCell -Value $page.Title
        $rows.Add(@("[$titleCell]($link)", $descCell))
    }

    $table = Format-MarkdownTable -Header @('Asset', 'Description') -Rows $rows.ToArray()
    $body = "This page lists the generated reference documentation for HVE Core $KindDir.`n`n" + $table
    $description = "Reference documentation for HVE Core $KindDir."
    return (New-IndexContent -Title $title -Description $description -SidebarPosition 0 -RegionBody $body -ExistingPath (Join-Path $RepoRoot $indexRel))
}

function New-RootIndexContent {
    <#
    .SYNOPSIS
        Builds the top-level reference index page content.
    .PARAMETER Pages
        All page models.
    .PARAMETER RepoRoot
        Repository root directory.
    .OUTPUTS
        [string] The index page content ending with a single newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][object[]]$Pages,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot
    )

    $rows = [System.Collections.Generic.List[object]]::new()
    foreach ($group in ($Pages | Group-Object KindDir | Sort-Object Name)) {
        $categoryTitle = (Get-Culture).TextInfo.ToTitleCase($group.Name)
        $rows.Add(@("[$categoryTitle]($($group.Name)/README.md)", [string]$group.Count))
    }

    $table = Format-MarkdownTable -Header @('Category', 'Assets') -Rows $rows.ToArray()
    $body = "This page lists the generated reference documentation, grouped by asset kind.`n`n" + $table
    return (New-IndexContent -Title 'Reference' -Description 'Generated reference documentation for HVE Core GenAI assets.' -SidebarPosition 0 -RegionBody $body -ExistingPath (Join-Path $RepoRoot 'docs/reference/README.md'))
}

function New-IndexContent {
    <#
    .SYNOPSIS
        Assembles an index page from a generated region body.
    .PARAMETER Title
        Page title.
    .PARAMETER Description
        Page description.
    .PARAMETER SidebarPosition
        Stable sidebar position.
    .PARAMETER RegionBody
        The generated index body placed inside the index region.
    .PARAMETER ExistingPath
        Path to an existing index page. Its ms.date is preserved when the
        regenerated content is identical, and advanced to today when the
        generated index region or frontmatter changes.
    .OUTPUTS
        [string] The index page content ending with a single newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Title,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Description,
        [Parameter(Mandatory = $true)][int]$SidebarPosition,
        [Parameter(Mandatory = $true)][string]$RegionBody,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ExistingPath
    )

    $today = Get-Date -Format 'yyyy-MM-dd'
    $msDate = $today
    $existing = $null
    if (Test-Path -LiteralPath $ExistingPath) {
        $existing = Get-Content -LiteralPath $ExistingPath -Raw
        $existingFm = Get-AssetFrontmatter -FilePath $ExistingPath
        if ($existingFm.ContainsKey('ms.date') -and $existingFm['ms.date']) {
            $msDate = [string]$existingFm['ms.date']
        }
    }

    $region = New-AssetGeneratedRegion -Region 'index' -Body $RegionBody

    # Advance ms.date to today only when the regenerated index differs, so the
    # date reflects the last content change rather than the first-scaffold date.
    $content = "$(New-DocFrontmatter -Title $Title -Description $Description -SidebarPosition $SidebarPosition -MsDate $msDate)`n`n$region`n"
    if ($null -ne $existing -and -not [string]::Equals($content, $existing, [System.StringComparison]::Ordinal)) {
        $content = "$(New-DocFrontmatter -Title $Title -Description $Description -SidebarPosition $SidebarPosition -MsDate $today)`n`n$region`n"
    }

    return $content
}

#endregion Content Builders

#region I/O

function Write-DocIfChanged {
    <#
    .SYNOPSIS
        Writes page content only when it differs, honoring -WhatIf.
    .DESCRIPTION
        Compares the desired content against the current file using ordinal
        comparison. Returns Unchanged when identical. Otherwise returns Created
        or Updated; the write itself is gated by ShouldProcess so -WhatIf reports
        drift without writing.
    .PARAMETER Path
        Absolute destination path.
    .PARAMETER Content
        Desired file content.
    .OUTPUTS
        [string] One of Created, Updated, or Unchanged.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Path,
        [Parameter(Mandatory = $true)][string]$Content
    )

    $exists = Test-Path -LiteralPath $Path
    if ($exists) {
        $current = Get-Content -LiteralPath $Path -Raw
        if ([string]::Equals($current, $Content, [System.StringComparison]::Ordinal)) {
            return 'Unchanged'
        }
    }

    $status = if ($exists) { 'Updated' } else { 'Created' }
    if ($PSCmdlet.ShouldProcess($Path, $status)) {
        $parent = Split-Path -Path $Path -Parent
        if ($parent -and -not (Test-Path -LiteralPath $parent)) {
            New-Item -ItemType Directory -Path $parent -Force | Out-Null
        }
        Set-Content -LiteralPath $Path -Value $Content -Encoding utf8NoBOM -NoNewline
    }

    return $status
}

#endregion I/O

#region Orchestration

function Invoke-AssetDocsGeneration {
    <#
    .SYNOPSIS
        Generates or refreshes all asset documentation and index pages.
    .DESCRIPTION
        Enumerates documentable assets, assigns stable sidebar positions per
        sibling folder, and writes each asset page plus the reference index
        pages via Write-DocIfChanged. Honors -WhatIf for drift reporting.
    .PARAMETER RepoRoot
        Repository root directory.
    .PARAMETER TemplatePath
        Path to the asset documentation template.
    .OUTPUTS
        [PSCustomObject] Summary with Created, Updated, Removed, Unchanged, and
        NeedsAttention path lists.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        throw "Template not found: $TemplatePath"
    }

    $created = [System.Collections.Generic.List[string]]::new()
    $updated = [System.Collections.Generic.List[string]]::new()
    $removed = [System.Collections.Generic.List[string]]::new()
    $unchanged = [System.Collections.Generic.List[string]]::new()
    $needsAttention = [System.Collections.Generic.List[string]]::new()

    $record = {
        param($Status, $RelPath)
        switch ($Status) {
            'Created' { $created.Add($RelPath) }
            'Updated' { $updated.Add($RelPath) }
            'Removed' { $removed.Add($RelPath) }
            'Unchanged' { $unchanged.Add($RelPath) }
        }
    }

    $assets = Get-DocumentableAssets -RepoRoot $RepoRoot
    $pages = @($assets | ForEach-Object { New-AssetPageModel -Asset $_ -RepoRoot $RepoRoot })

    # Assign stable sidebar positions among sibling pages within each folder.
    $positions = @{}
    foreach ($group in ($pages | Group-Object Folder)) {
        $index = 1
        foreach ($page in ($group.Group | Sort-Object DocRel)) {
            $positions[$page.DocRel] = $index
            $index++
        }
    }

    foreach ($page in $pages) {
        $docFull = Join-Path $RepoRoot $page.DocRel
        $existingContent = if (Test-Path -LiteralPath $docFull) {
            Get-Content -LiteralPath $docFull -Raw
        }
        else {
            $null
        }
        # Option B guard: an existing page whose overview markers are missing cannot
        # be regenerated without discarding its human-authored sections. Skip it,
        # leave the file untouched, and report it as drift needing manual attention.
        if ($null -ne $existingContent -and
            -not (Split-AssetDocByMarkers -Content $existingContent -Region 'overview').HasMarkers) {
            Write-Warning "Overview markers missing in $($page.DocRel); skipping regeneration to preserve human-authored sections. Restore the AUTO-GENERATED markers (or delete the page to re-scaffold) and re-run."
            $needsAttention.Add($page.DocRel)
            continue
        }
        $content = New-AssetDocContent -Model $page -RepoRoot $RepoRoot -ExistingContent $existingContent -TemplatePath $TemplatePath -SidebarPosition $positions[$page.DocRel]
        $status = Write-DocIfChanged -Path (Join-Path $RepoRoot $page.DocRel) -Content $content
        & $record $status $page.DocRel
    }

    # Remove only source-orphaned pages that remain exact generator scaffolds.
    # Any authored or structurally ambiguous page is preserved for explicit
    # human disposition rather than being deleted from a path mismatch alone.
    $expectedPages = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $expectedPagesIgnoreCase = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($page in $pages) {
        [void]$expectedPages.Add($page.DocRel)
        [void]$expectedPagesIgnoreCase.Add($page.DocRel)
    }
    $interactiveTail = Get-TemplateHumanTail -TemplatePath $TemplatePath -Interactive $true
    $nonInteractiveTail = Get-TemplateHumanTail -TemplatePath $TemplatePath -Interactive $false
    foreach ($orphanRel in (Get-AssetDocPageRelPath -RepoRoot $RepoRoot)) {
        if ($expectedPages.Contains($orphanRel)) {
            continue
        }

        if ($expectedPagesIgnoreCase.Contains($orphanRel)) {
            Write-Warning "Page $orphanRel differs from a current asset page only by path casing; preserving it for manual disposition."
            $needsAttention.Add($orphanRel)
            continue
        }

        $orphanFull = Join-Path $RepoRoot $orphanRel
        $orphanContent = Get-Content -LiteralPath $orphanFull -Raw
        if (-not (Test-AssetDocScaffoldOrphan -Content $orphanContent -InteractiveTail $interactiveTail -NonInteractiveTail $nonInteractiveTail)) {
            Write-Warning "Orphaned page $orphanRel contains authored or ambiguous content; preserving it for manual disposition."
            $needsAttention.Add($orphanRel)
            continue
        }

        if ($PSCmdlet.ShouldProcess($orphanFull, 'Remove orphaned generated asset documentation scaffold')) {
            Remove-Item -LiteralPath $orphanFull -Force
        }
        & $record 'Removed' $orphanRel
    }

    # Per-kind index pages.
    foreach ($group in ($pages | Group-Object KindDir)) {
        $indexRel = "docs/reference/$($group.Name)/README.md"
        $content = New-KindIndexContent -KindDir $group.Name -Pages $group.Group -RepoRoot $RepoRoot
        $status = Write-DocIfChanged -Path (Join-Path $RepoRoot $indexRel) -Content $content
        & $record $status $indexRel
    }

    # Top-level index page.
    if ($pages.Count -gt 0) {
        $rootRel = 'docs/reference/README.md'
        $content = New-RootIndexContent -Pages $pages -RepoRoot $RepoRoot
        $status = Write-DocIfChanged -Path (Join-Path $RepoRoot $rootRel) -Content $content
        & $record $status $rootRel
    }

    return [PSCustomObject]@{
        Created        = $created
        Updated        = $updated
        Removed        = $removed
        Unchanged      = $unchanged
        NeedsAttention = $needsAttention
        DriftCount     = $created.Count + $updated.Count + $removed.Count + $needsAttention.Count
        WhatIf         = [bool]$WhatIfPreference
    }
}

#endregion Orchestration

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $summary = Invoke-AssetDocsGeneration -RepoRoot $RepoRoot -TemplatePath $TemplatePath

        # The run summary is a report, not a documentation change, so it is always
        # persisted even under -WhatIf (with -WhatIf:$false) so CI can read drift.
        $resultsPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path $RepoRoot $OutputPath }
        $resultsDir = Split-Path -Path $resultsPath -Parent
        if ($resultsDir -and -not (Test-Path -LiteralPath $resultsDir)) {
            New-Item -ItemType Directory -Path $resultsDir -Force -WhatIf:$false | Out-Null
        }
        $summary | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $resultsPath -Encoding utf8NoBOM -WhatIf:$false

        $verb = if ($summary.WhatIf) { 'Would create' } else { 'Created' }
        $verb2 = if ($summary.WhatIf) { 'would update' } else { 'updated' }
        $verb3 = if ($summary.WhatIf) { 'Would remove' } else { 'Removed' }
        Write-Host "`n--- Asset Docs Generation ---" -ForegroundColor Cyan
        Write-Host "  $verb`: $($summary.Created.Count)"
        Write-Host "  $((Get-Culture).TextInfo.ToTitleCase($verb2))`: $($summary.Updated.Count)"
        Write-Host "  $verb3`: $($summary.Removed.Count)"
        Write-Host "  Unchanged: $($summary.Unchanged.Count)"
        if ($summary.NeedsAttention.Count -gt 0) {
            Write-Host "  Needs attention (authored or ambiguous, preserved): $($summary.NeedsAttention.Count)" -ForegroundColor Yellow
        }
        if ($summary.WhatIf -and $summary.DriftCount -gt 0) {
            Write-Host "  Drift detected in $($summary.DriftCount) page(s)." -ForegroundColor Yellow
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Generate-AssetDocs failed: $($_.Exception.Message)"
        exit 1
    }
}
