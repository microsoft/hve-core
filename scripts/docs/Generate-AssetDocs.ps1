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
    docs/reference/<kind>/README.md) and assigns a stable sidebar_position to
    every page based on its position among sibling pages.

    The generator never calls a model. The "Example usage" and other
    human-authored sections are authored separately (human-in-the-loop).
    Running with -WhatIf reports drift (pages that would be created or updated)
    without writing any files.

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

function Format-YamlScalar {
    <#
    .SYNOPSIS
        Renders a string as a safe YAML scalar for frontmatter.
    .DESCRIPTION
        Returns the value unquoted when it is safe to do so, otherwise wraps it
        in double quotes with backslash and double-quote escaping so colons and
        other YAML-significant characters do not break the frontmatter block.
    .PARAMETER Value
        The scalar value to render.
    .OUTPUTS
        [string] A YAML-safe scalar.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $needsQuote = [string]::IsNullOrEmpty($Value) -or
        $Value -match '[:#\[\]{}",''|>&*!?@`]' -or
        $Value -match '^\s' -or
        $Value -match '\s$'

    if ($needsQuote) {
        $escaped = $Value -replace '\\', '\\' -replace '"', '\"'
        return '"' + $escaped + '"'
    }

    return $Value
}

function ConvertTo-TableCell {
    <#
    .SYNOPSIS
        Normalizes text for inclusion in a Markdown table cell.
    .DESCRIPTION
        Collapses line breaks to spaces and escapes pipe characters so cell
        content cannot break table structure.
    .PARAMETER Value
        The raw cell text.
    .OUTPUTS
        [string] A single-line, pipe-escaped cell value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return (($Value -replace '\r?\n', ' ') -replace '\|', '\|').Trim()
}

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
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][int]$SidebarPosition,
        [Parameter(Mandatory = $true)][string]$MsDate
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

function Format-AssetInvocation {
    <#
    .SYNOPSIS
        Renders an invocation descriptor as human-readable table text.
    .PARAMETER Invocation
        Hashtable from Get-AssetInvocation with Mechanism and Token keys.
    .OUTPUTS
        [string] Table-safe invocation description.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Invocation
    )

    $tick = '`'
    $token = [string]$Invocation.Token
    switch ($Invocation.Mechanism) {
        'agent-picker' { return "Selected from the chat agent picker as $tick$token$tick" }
        'slash-command' { return "Slash command $tick$token$tick" }
        'auto-applied' {
            if ([string]::IsNullOrWhiteSpace($token)) { return 'Applied automatically' }
            return "Applied automatically to $tick$token$tick"
        }
        'skill-load' { return 'Loaded on demand by referencing agents' }
        default { return (ConvertTo-TableCell -Value $token) }
    }
}

function New-AssetMetadataBlock {
    <#
    .SYNOPSIS
        Builds the metadata region body for an asset page.
    .PARAMETER Kind
        Asset kind.
    .PARAMETER SourcePath
        Repo-relative source path of the asset.
    .PARAMETER Invocation
        Invocation descriptor from Get-AssetInvocation.
    .PARAMETER Interactive
        Whether the asset has an interactive usage flow.
    .OUTPUTS
        [string] The metadata table body (without markers).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Kind,
        [Parameter(Mandatory = $true)][string]$SourcePath,
        [Parameter(Mandatory = $true)][hashtable]$Invocation,
        [Parameter(Mandatory = $true)][bool]$Interactive
    )

    $tick = '`'
    $interactiveText = if ($Interactive) { 'Yes' } else { 'No' }

    return (@(
            '| Field | Value |'
            '| ----- | ----- |'
            "| Kind | $Kind |"
            "| Source | $tick$SourcePath$tick |"
            "| Invocation | $(Format-AssetInvocation -Invocation $Invocation) |"
            "| Interactive | $interactiveText |"
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

    return ($Tail -replace '(?ms)\r?\n## How to use it\b.*?(?=\r?\n## )', '')
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
        [Parameter(Mandatory = $true)][string]$TemplatePath,
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

function New-AssetPageModel {
    <#
    .SYNOPSIS
        Builds the resolved page model for a documentable asset.
    .DESCRIPTION
        Reads the asset frontmatter and description once and derives the title,
        invocation, interactivity, source path, and destination docs path used
        by both the page builder and the index builder.
    .PARAMETER Asset
        Hashtable with path and kind keys from Get-DocumentableAssets.
    .PARAMETER RepoRoot
        Repository root directory.
    .OUTPUTS
        [PSCustomObject] The resolved page model.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Asset,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $kind = [string]$Asset.kind
    $relPath = [string]$Asset.path

    $sourceFile = Join-Path $RepoRoot ($relPath -replace '^\./', '')
    if ($kind -eq 'skill') {
        $sourceFile = Join-Path $sourceFile 'SKILL.md'
    }

    $frontmatter = Get-AssetFrontmatter -FilePath $sourceFile
    $key = Get-CollectionArtifactKey -Kind $kind -Path $relPath
    $description = Get-ArtifactDescription -FilePath $sourceFile

    $title = if ($frontmatter.ContainsKey('name') -and $frontmatter['name']) {
        [string]$frontmatter['name']
    }
    elseif ($frontmatter.ContainsKey('title') -and $frontmatter['title']) {
        [string]$frontmatter['title']
    }
    else {
        (Get-Culture).TextInfo.ToTitleCase(($key -replace '[-_]', ' '))
    }

    $docRel = Get-AssetDocsPath -Path $relPath -Kind $kind
    $folder = (Split-Path -Path $docRel -Parent) -replace '\\', '/'
    $kindDir = ($docRel -replace '^docs/reference/', '').Split('/')[0]

    return [PSCustomObject]@{
        Kind        = $kind
        Key         = $key
        Title       = $title
        Description = $description
        SourceRel   = $relPath
        DocRel      = $docRel
        Folder      = $folder
        KindDir     = $kindDir
        Invocation  = Get-AssetInvocation -Kind $kind -Name $key -Frontmatter $frontmatter
        Interactive = Test-AssetInteractive -Kind $kind -Frontmatter $frontmatter
    }
}

function New-AssetDocContent {
    <#
    .SYNOPSIS
        Builds the full documentation page content for an asset.
    .DESCRIPTION
        Assembles frontmatter, the refreshed metadata and overview regions, and
        the human-authored tail. For an existing page the tail (and its ms.date)
        are preserved; for a new page the tail comes from the template.
    .PARAMETER Model
        Page model from New-AssetPageModel.
    .PARAMETER RepoRoot
        Repository root directory.
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
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$TemplatePath,
        [Parameter(Mandatory = $true)][int]$SidebarPosition
    )

    $docFull = Join-Path $RepoRoot $Model.DocRel
    $today = Get-Date -Format 'yyyy-MM-dd'

    if (Test-Path -LiteralPath $docFull) {
        $existing = Get-Content -LiteralPath $docFull -Raw
        $existingFm = Get-AssetFrontmatter -FilePath $docFull
        $msDate = if ($existingFm.ContainsKey('ms.date') -and $existingFm['ms.date']) {
            [string]$existingFm['ms.date']
        }
        else { $today }

        $split = Split-AssetDocByMarkers -Content $existing -Region 'overview'
        $humanTail = if ($split.HasMarkers) {
            $split.After
        }
        else {
            Write-Warning "Overview markers missing in $($Model.DocRel); restoring human sections from template."
            Get-TemplateHumanTail -TemplatePath $TemplatePath -Interactive $Model.Interactive
        }
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
    $overviewBody = if ([string]::IsNullOrWhiteSpace($Model.Description)) {
        'This asset does not declare a description.'
    }
    else { $descriptionMeta }

    $frontmatter = New-DocFrontmatter -Title $Model.Title -Description $descriptionMeta -SidebarPosition $SidebarPosition -MsDate $msDate
    $metadataRegion = New-AssetGeneratedRegion -Region 'metadata' -Body (New-AssetMetadataBlock -Kind $Model.Kind -SourcePath $Model.SourceRel -Invocation $Model.Invocation -Interactive $Model.Interactive)
    $overviewRegion = New-AssetGeneratedRegion -Region 'overview' -Body $overviewBody

    $head = "$frontmatter`n`n$metadataRegion`n`n## What it does`n`n$overviewRegion"
    return ($head + $humanTail).TrimEnd() + "`n"
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
        [Parameter(Mandatory = $true)][string]$KindDir,
        [Parameter(Mandatory = $true)][object[]]$Pages,
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $title = (Get-Culture).TextInfo.ToTitleCase($KindDir)
    $indexRel = "docs/reference/$KindDir/README.md"
    $indexDir = Split-Path -Path (Join-Path $RepoRoot $indexRel) -Parent

    $rows = [System.Collections.Generic.List[string]]::new()
    $rows.Add('| Asset | Description |')
    $rows.Add('| ----- | ----------- |')
    foreach ($page in ($Pages | Sort-Object DocRel)) {
        $target = Join-Path $RepoRoot $page.DocRel
        $link = ([System.IO.Path]::GetRelativePath($indexDir, $target)) -replace '\\', '/'
        $descCell = if ([string]::IsNullOrWhiteSpace($page.Description)) { '' } else { ConvertTo-TableCell -Value $page.Description }
        $titleCell = ConvertTo-TableCell -Value $page.Title
        $rows.Add("| [$titleCell]($link) | $descCell |")
    }

    $body = "This page lists the generated reference documentation for HVE Core $KindDir.`n`n" + ($rows -join "`n")
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
        [Parameter(Mandatory = $true)][string]$RepoRoot
    )

    $rows = [System.Collections.Generic.List[string]]::new()
    $rows.Add('| Category | Assets |')
    $rows.Add('| -------- | ------ |')
    foreach ($group in ($Pages | Group-Object KindDir | Sort-Object Name)) {
        $categoryTitle = (Get-Culture).TextInfo.ToTitleCase($group.Name)
        $rows.Add("| [$categoryTitle]($($group.Name)/README.md) | $($group.Count) |")
    }

    $body = "This page lists the generated reference documentation, grouped by asset kind.`n`n" + ($rows -join "`n")
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
        Path to an existing index page whose ms.date is preserved.
    .OUTPUTS
        [string] The index page content ending with a single newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $true)][string]$Description,
        [Parameter(Mandatory = $true)][int]$SidebarPosition,
        [Parameter(Mandatory = $true)][string]$RegionBody,
        [Parameter(Mandatory = $true)][string]$ExistingPath
    )

    $msDate = Get-Date -Format 'yyyy-MM-dd'
    if (Test-Path -LiteralPath $ExistingPath) {
        $existingFm = Get-AssetFrontmatter -FilePath $ExistingPath
        if ($existingFm.ContainsKey('ms.date') -and $existingFm['ms.date']) {
            $msDate = [string]$existingFm['ms.date']
        }
    }

    $frontmatter = New-DocFrontmatter -Title $Title -Description $Description -SidebarPosition $SidebarPosition -MsDate $msDate
    $region = New-AssetGeneratedRegion -Region 'index' -Body $RegionBody
    return "$frontmatter`n`n$region`n"
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
        [Parameter(Mandatory = $true)][string]$Path,
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
        [PSCustomObject] Summary with Created, Updated, and Unchanged path lists.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][string]$RepoRoot,
        [Parameter(Mandatory = $true)][string]$TemplatePath
    )

    if (-not (Test-Path -LiteralPath $TemplatePath)) {
        throw "Template not found: $TemplatePath"
    }

    $created = [System.Collections.Generic.List[string]]::new()
    $updated = [System.Collections.Generic.List[string]]::new()
    $unchanged = [System.Collections.Generic.List[string]]::new()

    $record = {
        param($Status, $RelPath)
        switch ($Status) {
            'Created' { $created.Add($RelPath) }
            'Updated' { $updated.Add($RelPath) }
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
        $content = New-AssetDocContent -Model $page -RepoRoot $RepoRoot -TemplatePath $TemplatePath -SidebarPosition $positions[$page.DocRel]
        $status = Write-DocIfChanged -Path (Join-Path $RepoRoot $page.DocRel) -Content $content
        & $record $status $page.DocRel
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
        Created    = $created
        Updated    = $updated
        Unchanged  = $unchanged
        DriftCount = $created.Count + $updated.Count
        WhatIf     = [bool]$WhatIfPreference
    }
}

#endregion Orchestration

if ($MyInvocation.InvocationName -ne '.') {
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
    Write-Host "`n--- Asset Docs Generation ---" -ForegroundColor Cyan
    Write-Host "  $verb`: $($summary.Created.Count)"
    Write-Host "  $((Get-Culture).TextInfo.ToTitleCase($verb2))`: $($summary.Updated.Count)"
    Write-Host "  Unchanged: $($summary.Unchanged.Count)"
    if ($summary.WhatIf -and $summary.DriftCount -gt 0) {
        Write-Host "  Drift detected in $($summary.DriftCount) page(s)." -ForegroundColor Yellow
    }
}
