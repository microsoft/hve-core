# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# PluginHelpers.psm1
#
# Purpose: Shared functions for the Copilot CLI plugin generation pipeline.
# Author: HVE Core Team

#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/ArtifactHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../../lib/Modules/MarketplaceHelpers.psm1') -Force

# Marker pair delimiting the optional package notice inside a durable package
# document. The notice renders in the generated README immediately after the
# package description rather than inside the Overview section.
$script:PluginNoticeBeginMarker = '<!-- BEGIN PACKAGE NOTICE -->'
$script:PluginNoticeEndMarker = '<!-- END PACKAGE NOTICE -->'

# ---------------------------------------------------------------------------
# Pure Functions (no file system side effects)
# ---------------------------------------------------------------------------

function New-PluginManifestContent {
    <#
    .SYNOPSIS
    Generates root plugin.json content as an ordered hashtable.

    .DESCRIPTION
    Creates the runtime manifest mirroring the standard catalog recipe: name,
    description, version, provenance, and component path declarations for
    agents, commands, rules, skills, and hooks. The x-hve metadata overlay is
    catalog-only and never reaches a generated manifest.

    .PARAMETER PackageName
    The package identifier used as the plugin name.

    .PARAMETER Description
    A short description of the plugin.

    .PARAMETER Version
    Semantic version string from the repository package.json.

    .PARAMETER Author
    Optional provenance author.

    .PARAMETER Homepage
    Optional provenance homepage URL.

    .PARAMETER Repository
    Optional provenance repository URL.

    .PARAMETER License
    Optional provenance license identifier.

    .PARAMETER Keywords
    Optional provenance keywords.

    .PARAMETER AgentPaths
    Optional. Array of package-relative directory paths containing agent files.

    .PARAMETER CommandPaths
    Optional. Array of package-relative directory paths containing prompt files.

    .PARAMETER RulePaths
    Optional. Array of package-relative directory paths containing instruction files.

    .PARAMETER SkillPaths
    Optional. Array of package-relative directory paths containing skill subdirs.

    .PARAMETER HookPaths
    Optional. Array of package-relative file paths to hook JSON files.

    .OUTPUTS
    [hashtable] Plugin manifest with name, description, version, provenance,
    and component path keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackageName,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [System.Collections.IDictionary]$Author,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Homepage,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$Repository,

        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$License,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Keywords,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$AgentPaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$CommandPaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$RulePaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$SkillPaths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$HookPaths
    )

    $manifest = [ordered]@{
        name        = $PackageName
        description = $Description
        version     = $Version
    }

    if ($Author -and $Author.Contains('name') -and -not [string]::IsNullOrWhiteSpace([string]$Author['name'])) {
        $manifest['author'] = $Author
    }

    foreach ($provenance in @(
            @{ Key = 'homepage'; Value = $Homepage },
            @{ Key = 'repository'; Value = $Repository },
            @{ Key = 'license'; Value = $License }
        )) {
        if (-not [string]::IsNullOrWhiteSpace($provenance.Value)) {
            $manifest[$provenance.Key] = $provenance.Value
        }
    }

    if ($Keywords -and $Keywords.Count -gt 0) {
        $manifest['keywords'] = @($Keywords)
    }

    # Emit explicit path arrays when provided; the CLI does not recurse
    # into subdirectories, so each leaf directory must be declared.
    if ($AgentPaths -and $AgentPaths.Count -gt 0) {
        $manifest['agents'] = @($AgentPaths | Sort-Object)
    }

    if ($CommandPaths -and $CommandPaths.Count -gt 0) {
        $manifest['commands'] = @($CommandPaths | Sort-Object)
    }

    if ($RulePaths -and $RulePaths.Count -gt 0) {
        $manifest['rules'] = @($RulePaths | Sort-Object)
    }

    if ($SkillPaths -and $SkillPaths.Count -gt 0) {
        $manifest['skills'] = @($SkillPaths | Sort-Object)
    }

    if ($HookPaths -and $HookPaths.Count -gt 0) {
        # The CLI `hooks` field is a single hooks-config file path (or inline
        # object), not an array. Emit the lone path as a string; warn when more
        # than one hook manifest is registered since only one can be referenced.
        $sortedHooks = @($HookPaths | Sort-Object)
        if ($sortedHooks.Count -gt 1) {
            Write-Warning "Plugin '$PackageName' declares $($sortedHooks.Count) hook manifests; the CLI references only one. Using '$($sortedHooks[0])'."
        }
        $manifest['hooks'] = $sortedHooks[0]
    }

    return $manifest
}

function Split-PluginDocumentationSource {
    <#
    .SYNOPSIS
    Separates a package document into title, notice, and overview content.

    .DESCRIPTION
    The durable package document owns the hand-authored prose that the
    generated README embeds. Its frontmatter title supplies the README heading,
    an optional marker-delimited notice block is emitted immediately after the
    description, and the remaining body becomes the Overview section.

    .PARAMETER Content
    Raw document content.

    .OUTPUTS
    [hashtable] Title, Notice, and Body.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Content
    )

    $result = @{ Title = ''; Notice = ''; Body = '' }
    if ([string]::IsNullOrWhiteSpace($Content)) {
        return $result
    }

    $body = $Content -replace "`r`n", "`n"

    if ($body -match '(?s)\A---\s*\n(.*?)\n---\s*\n') {
        $frontmatterText = $Matches[1]
        $body = $body.Substring($Matches[0].Length)
        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $frontmatterText
            if ($frontmatter -is [System.Collections.IDictionary] -and $frontmatter.Contains('title')) {
                $result.Title = [string]$frontmatter['title']
            }
        }
        catch {
            Write-Verbose "Failed to parse package document frontmatter: $_"
        }
    }

    # Legacy companion prose leads with an H1; the frontmatter title replaces it.
    if ($body -match '(?m)\A#\s+([^\r\n]+)\r?\n') {
        if ([string]::IsNullOrWhiteSpace($result.Title)) {
            $result.Title = $Matches[1].Trim()
        }
        $body = $body -replace '(?m)\A#\s+[^\r\n]+\r?\n(\r?\n)?', ''
    }

    if ($body -match "(?s)$([regex]::Escape($script:PluginNoticeBeginMarker))\s*\n(.*?)\n\s*$([regex]::Escape($script:PluginNoticeEndMarker))\s*\n?") {
        $result.Notice = $Matches[1].Trim()
        $body = $body.Replace($Matches[0], '')
    }

    $result.Body = $body.Trim()
    return $result
}

function Get-PluginItemMaturityLabel {
    <#
    .SYNOPSIS
    Returns the canonical maturity label rendered for one README row.

    .DESCRIPTION
    The catalog labels only non-default components, so an item without a
    declared maturity discloses the canonical 'stable' default rather than a
    blank cell.

    .PARAMETER Item
    README item carrying an optional Maturity value.

    .OUTPUTS
    [string] Canonical maturity label.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Item
    )

    $value = [string]$Item.Maturity
    if ([string]::IsNullOrWhiteSpace($value)) { return 'stable' }
    return $value
}

function New-PluginReadmeContent {
    <#
    .SYNOPSIS
    Generates README.md markdown for a plugin.

    .DESCRIPTION
    Builds a complete README.md string with a markdownlint-disable header,
    title, description, install command, and tables for each artifact kind
    that has items. Only sections with items are included.

    .PARAMETER PackageMetadata
    Hashtable with id, name, and description keys for the package.
    An optional 'notice' key injects a custom blockquote after the description.

    .PARAMETER Items
    Array of processed item objects. Each object must have Name, Description,
    and Kind properties, and may carry a canonical Maturity label.

    .PARAMETER Maturity
        Optional package maturity string. When 'experimental', an
        experimental notice is injected after the description. When 'preview',
        a preview notice is injected.

    .PARAMETER PackageDocumentation
        Optional markdown content from the durable package document. Injected as
        an Overview section between the description and the Install section.

    .OUTPUTS
    [string] Complete README markdown content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$PackageMetadata,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Items,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$PackageDocumentation
    )

    $parsedDocument = Split-PluginDocumentationSource -Content $PackageDocumentation
    $title = if (-not [string]::IsNullOrWhiteSpace($parsedDocument.Title)) {
        $parsedDocument.Title
    }
    else {
        [string]$PackageMetadata.name
    }

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine('<!-- markdownlint-disable-file -->')
    [void]$sb.AppendLine("# $title")
    [void]$sb.AppendLine()
    [void]$sb.AppendLine($PackageMetadata.description)

    # Inject maturity notice when the package is not stable
    $effectiveMaturity = if ([string]::IsNullOrWhiteSpace($Maturity)) { 'stable' } else { $Maturity }
    if ($effectiveMaturity -eq 'experimental') {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("> **`u{26A0}`u{FE0F} Experimental** `u{2014} This package is experimental. Contents and behavior may change or be removed without notice.")
    }
    elseif ($effectiveMaturity -eq 'preview') {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine("> **`u{1F50D} Preview** `u{2014} This package is in preview. Core features are complete and functional but refinements may follow.")
    }

    # Inject the package notice declared by the durable package document
    $notice = if ($PackageMetadata.ContainsKey('notice') -and -not [string]::IsNullOrWhiteSpace($PackageMetadata.notice)) {
        [string]$PackageMetadata.notice
    }
    else {
        $parsedDocument.Notice
    }
    if (-not [string]::IsNullOrWhiteSpace($notice)) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine($notice.TrimEnd())
    }

    # Inject the package document body as an Overview section. Frontmatter, a
    # legacy leading H1, and the notice block are already removed because the
    # title and notice are emitted above.
    $overviewText = $parsedDocument.Body

    if (-not [string]::IsNullOrWhiteSpace($overviewText)) {
        [void]$sb.AppendLine()
        [void]$sb.AppendLine('## Overview')
        [void]$sb.AppendLine()
        [void]$sb.AppendLine($overviewText)
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('## Install')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('```bash')
    [void]$sb.AppendLine("copilot plugin install $($PackageMetadata.id)@hve-core")
    [void]$sb.AppendLine('```')

    $sectionMap = [ordered]@{
        agent       = @{ Title = 'Agents'; Header = 'Agent' }
        prompt      = @{ Title = 'Commands'; Header = 'Command' }
        instruction = @{ Title = 'Instructions'; Header = 'Instruction' }
        skill       = @{ Title = 'Skills'; Header = 'Skill' }
        hook        = @{ Title = 'Hooks'; Header = 'Hook' }
    }

    $hasPackageArtifactContent = -not [string]::IsNullOrWhiteSpace($PackageDocumentation) -and (
        $PackageDocumentation -match '(?m)^##\s+Included Artifacts\s*$' -or
        (
            $PackageDocumentation -match '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->' -and
            $PackageDocumentation -match '<!-- END AUTO-GENERATED ARTIFACTS -->'
        )
    )

    if (-not $hasPackageArtifactContent) {
        foreach ($entry in $sectionMap.GetEnumerator()) {
            $kind = $entry.Key
            $meta = $entry.Value
            $kindItems = @($Items | Where-Object { $_.Kind -eq $kind })
            if ($kindItems.Count -eq 0) {
                continue
            }

            [void]$sb.AppendLine()
            [void]$sb.AppendLine("## $($meta.Title)")
            [void]$sb.AppendLine()

            # Calculate column widths for aligned table output
            $col1Width = $meta.Header.Length
            $col2Width = 'Maturity'.Length
            $col3Width = 'Description'.Length
            foreach ($item in $kindItems) {
                $label = Get-PluginItemMaturityLabel -Item $item
                if ($item.Name.Length -gt $col1Width) { $col1Width = $item.Name.Length }
                if ($label.Length -gt $col2Width) { $col2Width = $label.Length }
                if ($item.Description.Length -gt $col3Width) { $col3Width = $item.Description.Length }
            }

            [void]$sb.AppendLine("| $($meta.Header.PadRight($col1Width)) | $('Maturity'.PadRight($col2Width)) | $('Description'.PadRight($col3Width)) |")
            [void]$sb.AppendLine('|' + ('-' * ($col1Width + 2)) + '|' + ('-' * ($col2Width + 2)) + '|' + ('-' * ($col3Width + 2)) + '|')
            foreach ($item in $kindItems) {
                $label = (Get-PluginItemMaturityLabel -Item $item).PadRight($col2Width)
                [void]$sb.AppendLine("| $($item.Name.PadRight($col1Width)) | $label | $($item.Description.PadRight($col3Width)) |")
            }
        }
    }

    [void]$sb.AppendLine()
    [void]$sb.AppendLine('---')
    [void]$sb.AppendLine()
    [void]$sb.AppendLine('> Source: [microsoft/hve-core](https://github.com/microsoft/hve-core)')
    [void]$sb.AppendLine()

    return $sb.ToString()
}

function New-PluginReleaseLocator {
    <#
    .SYNOPSIS
    Builds a validated immutable release locator for marketplace object sources.

    .DESCRIPTION
    Produces the repository, immutable ref, and package path prefix used to emit
    object-form marketplace sources. Accepts an explicit 'plugins-v<version>' tag
    or derives one from a package version.

    Commit-SHA catalog locators are not part of the production contract.

    .PARAMETER Tag
    Explicit immutable release tag in 'plugins-v<version>' form.

    .PARAMETER Version
    Semantic version from which the 'plugins-v<version>' tag is derived.

    .PARAMETER Repo
    Source repository in 'owner/name' form.

    .PARAMETER PathPrefix
    Repository-relative directory holding generated packages.

    .OUTPUTS
    [hashtable] Locator with Repo, Ref, and PathPrefix keys.

    .EXAMPLE
    New-PluginReleaseLocator -Version '1.2.3'
    #>
    [CmdletBinding(DefaultParameterSetName = 'Tag')]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Tag')]
        [AllowEmptyString()]
        [string]$Tag,

        [Parameter(Mandatory = $true, ParameterSetName = 'Version')]
        [AllowEmptyString()]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [string]$Repo = 'microsoft/hve-core',

        [Parameter(Mandatory = $false)]
        [string]$PathPrefix = 'plugins'
    )

    $semVerPattern = '^\d+\.\d+\.\d+(?:-[0-9A-Za-z.-]+)?$'

    if ($PSCmdlet.ParameterSetName -eq 'Version') {
        if ($Version -notmatch $semVerPattern) {
            throw "Release version '$Version' is not a semantic version."
        }
        $Tag = "plugins-v$Version"
    }

    if ($Tag -match '^[0-9a-fA-F]{40}$') {
        throw "Release locator '$Tag' is a commit sha. Sha-pinned catalog sources are not supported; use the immutable 'plugins-v<version>' tag."
    }

    if ($Tag -notmatch "^plugins-v$($semVerPattern.TrimStart('^'))") {
        throw "Release locator '$Tag' must use the immutable 'plugins-v<version>' tag form."
    }

    if ($Repo -notmatch '^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$') {
        throw "Release repository '$Repo' must use 'owner/name' form."
    }

    $normalizedPrefix = $PathPrefix.Trim('/')
    if ([string]::IsNullOrWhiteSpace($normalizedPrefix) -or $normalizedPrefix -match '\\' -or $normalizedPrefix -match '(^|/)\.\.?(/|$)') {
        throw "Release path prefix '$PathPrefix' must be a relative forward-slash path inside the repository."
    }

    return @{
        Repo       = $Repo
        Ref        = $Tag
        PathPrefix = $normalizedPrefix
    }
}

function New-MarketplaceManifestContent {
    <#
    .SYNOPSIS
    Projects a marketplace catalog, optionally rewriting entry sources.

    .DESCRIPTION
    Produces a marketplace manifest from the catalog metadata and entries.
    Standard entry fields and the x-hve overlay are preserved verbatim, because
    the catalog is the package-definition authority. Supplying a release locator
    replaces each object source with a package locator at the selected immutable
    ref in the source repository.

    .PARAMETER RepoName
    Repository name used as the marketplace name.

    .PARAMETER Description
    Short description of the repository.

    .PARAMETER Version
    Semantic version string from package.json.

    .PARAMETER OwnerName
    Organization or individual owning the repository.

    .PARAMETER Plugins
    Catalog entries to project.

    .PARAMETER ReleaseLocator
    Optional. Locator from New-PluginReleaseLocator. When supplied, entry object
    sources are rewritten to the selected immutable package reference.

    .OUTPUTS
    [hashtable] Marketplace manifest with name, metadata, owner, and plugins keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoName,

        [Parameter(Mandatory = $true)]
        [string]$Description,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [string]$OwnerName,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [array]$Plugins,

        [Parameter(Mandatory = $false)]
        [hashtable]$ReleaseLocator
    )

    $useLocator = $null -ne $ReleaseLocator -and $ReleaseLocator.Count -gt 0

    $pluginEntries = @()
    foreach ($plugin in ($Plugins | Sort-Object { $_['name'] })) {
        $projected = [ordered]@{}
        foreach ($key in $plugin.Keys) {
            $projected[$key] = $plugin[$key]
        }

        $projected['version'] = $Version

        if ($useLocator) {
            $projected['source'] = [ordered]@{
                source = 'github'
                repo   = $ReleaseLocator.Repo
                path   = "$($ReleaseLocator.PathPrefix)/$($plugin['name'])"
                ref    = $ReleaseLocator.Ref
            }
        }
        elseif ($plugin['source'] -isnot [System.Collections.IDictionary]) {
            throw "Plugin '$($plugin['name'])' source must be an immutable object locator. Bare package sources are not supported."
        }

        $pluginEntries += $projected
    }

    return [ordered]@{
        name     = $RepoName
        metadata = [ordered]@{
            description = $Description
            version     = $Version
            pluginRoot  = './plugins'
        }
        owner    = [ordered]@{
            name = $OwnerName
        }
        plugins  = $pluginEntries
    }
}

function Write-MarketplaceManifest {
    <#
    .SYNOPSIS
    Writes a projected marketplace snapshot to an explicit destination.

    .DESCRIPTION
    The production catalog at .github/plugin/marketplace.json is the
    package-definition input, so generation never rewrites it. This projects
    that catalog to a separate destination, optionally pinning every entry
    source to an immutable release locator for snapshot publication.

    .PARAMETER RepoRoot
    Absolute path to the repository root directory.

    .PARAMETER Catalog
    Parsed marketplace catalog to project.

    .PARAMETER ReleaseLocator
    Optional. Locator from New-PluginReleaseLocator. Emits object sources and
    requires an explicit OutputPath so the production catalog is never rewritten
    by generation; catalog cutover is a separate reviewed change.

    .PARAMETER OutputPath
    Destination path, absolute or relative to RepoRoot. The production catalog
    is rejected as a destination.

    .PARAMETER Version
    Optional semantic version for the projection. Defaults to package.json.

    .PARAMETER DryRun
    When specified, logs the action without writing to disk.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Catalog,

        [Parameter(Mandatory = $false)]
        [hashtable]$ReleaseLocator,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath,

        [Parameter(Mandatory = $false)]
        [ValidatePattern('^\d+\.\d+\.\d+$')]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $useLocator = $null -ne $ReleaseLocator -and $ReleaseLocator.Count -gt 0

    $productionPath = Join-Path -Path $RepoRoot -ChildPath '.github' -AdditionalChildPath 'plugin', 'marketplace.json'
    $resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $OutputPath
    }

    if ([System.IO.Path]::GetFullPath($resolvedOutputPath) -eq [System.IO.Path]::GetFullPath($productionPath)) {
        throw "Marketplace projection must not write the production catalog at $productionPath. The catalog is the package-definition input."
    }

    $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
    $packageJson = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json
    $manifestVersion = if ([string]::IsNullOrWhiteSpace($Version)) { [string]$packageJson.version } else { $Version }

    $manifestArgs = @{
        RepoName    = $packageJson.name
        Description = $packageJson.description
        Version     = $manifestVersion
        OwnerName   = $packageJson.author
        Plugins     = @($Catalog['plugins'])
    }
    if ($useLocator) {
        $manifestArgs['ReleaseLocator'] = $ReleaseLocator
    }

    $manifest = New-MarketplaceManifestContent @manifestArgs

    $outputDir = Split-Path -Path $resolvedOutputPath -Parent

    if ($DryRun) {
        Write-Host "  [DRY RUN] Would write marketplace snapshot at $resolvedOutputPath" -ForegroundColor Yellow
        return
    }

    if (-not [string]::IsNullOrWhiteSpace($outputDir) -and -not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $manifestJson = ($manifest | ConvertTo-Json -Depth 12) + "`n"
    Set-ContentIfChanged -Path $resolvedOutputPath -Value $manifestJson | Out-Null
    Write-Host "  Marketplace snapshot: $resolvedOutputPath" -ForegroundColor Green
}

function Test-PluginGitRefName {
    <#
    .SYNOPSIS
    Tests whether a string is a usable git reference name.

    .PARAMETER Name
    Candidate branch or tag name.

    .OUTPUTS
    [bool] True when the name is a valid git reference.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name
    )

    if ([string]::IsNullOrWhiteSpace($Name)) {
        return $false
    }

    if ($Name -match '[\s~^:?*\[\\]' -or $Name -match '\.\.' -or $Name -match '@\{') {
        return $false
    }

    if ($Name.StartsWith('-') -or $Name.StartsWith('/') -or $Name.EndsWith('/') -or $Name.EndsWith('.')) {
        return $false
    }

    foreach ($segment in ($Name -split '/')) {
        if ([string]::IsNullOrEmpty($segment) -or $segment.StartsWith('.') -or $segment.EndsWith('.lock')) {
            return $false
        }
    }

    return $true
}

function Assert-PluginSnapshotTarget {
    <#
    .SYNOPSIS
    Validates the branch and tag a snapshot publish may write.

    .DESCRIPTION
    Disposable mode requires a namespaced branch and tag pair. Production mode
    permits exactly one immutable plugins-v<version> tag and no branch. Both
    modes refuse an existing tag rather than overwriting it.

    .PARAMETER Mode
    Disposable or Production publication mode.

    .PARAMETER Branch
    Target branch for the snapshot commit.

    .PARAMETER Tag
    Target tag for the snapshot commit.

    .PARAMETER ExistingRefs
    Reference names that already exist on the remote, short or fully qualified.

    .PARAMETER DisposablePrefix
    Required prefix identifying a disposable reference.

    .OUTPUTS
    [hashtable] Validated target with Branch, Tag, and RefSpecs keys.

    .EXAMPLE
    Assert-PluginSnapshotTarget -Branch 'plugins-snapshot/run-42' -Tag 'plugins-snapshot/run-42-tag'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet('Disposable', 'Production')]
        [string]$Mode = 'Disposable',

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Branch,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Tag,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ExistingRefs = @(),

        [Parameter(Mandatory = $false)]
        [string]$DisposablePrefix = 'plugins-snapshot/'
    )

    $normalizedExisting = @($ExistingRefs | ForEach-Object { ($_ -replace '^refs/(heads|tags)/', '').Trim() })

    if ($Mode -eq 'Production') {
        if (-not [string]::IsNullOrEmpty($Branch)) {
            throw "Production snapshot mode does not publish a branch; received '$Branch'."
        }
        if (-not (Test-PluginGitRefName -Name $Tag)) {
            throw "Snapshot tag '$Tag' is not a valid git reference name."
        }
        if ($Tag -cnotmatch '^plugins-v\d+\.\d+\.\d+$') {
            throw "Production snapshot tag '$Tag' must use 'plugins-v<version>' form."
        }
        if ($normalizedExisting -contains $Tag) {
            throw "Snapshot tag '$Tag' already exists. Tags are immutable and are never overwritten."
        }

        return @{
            Branch   = ''
            Tag      = $Tag
            RefSpecs = @("refs/tags/$Tag")
        }
    }

    $protectedBranches = @('main', 'release/plugins')
    $productionTagPattern = '^plugins-v\d+\.\d+\.\d+'

    foreach ($target in @(@{ Kind = 'branch'; Value = $Branch }, @{ Kind = 'tag'; Value = $Tag })) {
        if (-not (Test-PluginGitRefName -Name $target.Value)) {
            throw "Snapshot $($target.Kind) '$($target.Value)' is not a valid git reference name."
        }

        if ($protectedBranches -contains $target.Value -or $target.Value -match $productionTagPattern) {
            throw "Snapshot $($target.Kind) '$($target.Value)' targets a protected production reference and is refused."
        }

        if (-not $target.Value.StartsWith($DisposablePrefix)) {
            throw "Snapshot $($target.Kind) '$($target.Value)' must start with the disposable prefix '$DisposablePrefix'."
        }
    }

    if ($Branch -eq $Tag) {
        throw "Snapshot branch and tag must differ; both are '$Branch'."
    }

    if ($normalizedExisting -contains $Tag) {
        throw "Snapshot tag '$Tag' already exists. Tags are immutable and are never overwritten."
    }

    return @{
        Branch   = $Branch
        Tag      = $Tag
        RefSpecs = @("HEAD:refs/heads/$Branch", "refs/tags/$Tag")
    }
}

function New-GenerateResult {
    <#
    .SYNOPSIS
    Creates a standardized result object.

    .DESCRIPTION
    Returns a hashtable representing the outcome of a plugin generation run
    with success status, plugin count, and optional error message.

    .PARAMETER Success
    Whether the operation succeeded.

    .PARAMETER PluginCount
    Number of plugins generated.

    .PARAMETER ErrorMessage
    Optional error message when Success is $false.

    .OUTPUTS
    [hashtable] Result with Success, PluginCount, and ErrorMessage keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [bool]$Success,

        [Parameter(Mandatory = $true)]
        [int]$PluginCount,

        [Parameter(Mandatory = $false)]
        [string]$ErrorMessage = ''
    )

    return @{
        Success      = $Success
        PluginCount  = $PluginCount
        ErrorMessage = $ErrorMessage
    }
}

# ---------------------------------------------------------------------------
# I/O Functions (file system operations)
# ---------------------------------------------------------------------------

function Get-PluginTrackedPathIndex {
    <#
    .SYNOPSIS
    Builds the git-tracked path allowlist for a repository working tree.

    .DESCRIPTION
    Reads the repository-relative paths recorded in the git index. Plugin
    materialization copies only these paths, so untracked working-tree content
    such as virtual environments, dependency directories, and bytecode caches
    can never be ingested into a generated plugin. Throws when the directory is
    not a git working tree, because materializing without the allowlist would
    silently copy that residue.

    .PARAMETER RepoRoot
    Absolute path to the repository working tree.

    .OUTPUTS
    [hashtable] Index with RepoRoot, Paths (ordered list), and Lookup (set) keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot)

    # core.quotePath=false keeps non-ASCII paths raw instead of octal-escaped.
    $gitArgs = @('-C', $resolvedRoot, '-c', 'core.quotePath=false', 'ls-files', '--cached', '--full-name')
    $output = & git @gitArgs 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to enumerate git-tracked paths in '$resolvedRoot' (git ls-files exit code $LASTEXITCODE)."
    }

    $paths = [System.Collections.Generic.List[string]]::new()
    $lookup = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($line in @($output)) {
        if ([string]::IsNullOrWhiteSpace($line)) {
            continue
        }
        $normalized = ([string]$line) -replace '\\', '/'
        if ($lookup.Add($normalized)) {
            $paths.Add($normalized)
        }
    }

    return @{
        RepoRoot = $resolvedRoot
        Paths    = $paths
        Lookup   = $lookup
    }
}

function Copy-PluginFileIfChanged {
    <#
    .SYNOPSIS
    Copies a file only when the destination content differs.

    .DESCRIPTION
    Compares length then SHA256 before writing, preserving the git stat cache
    for unchanged files so repeat generations stay idempotent.

    .PARAMETER SourcePath
    Absolute path to the source file.

    .PARAMETER DestinationPath
    Absolute path to the destination file.

    .OUTPUTS
    [bool] True when the file was written, false when skipped.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath
    )

    if (Test-Path -LiteralPath $DestinationPath -PathType Leaf) {
        $sourceLength = (Get-Item -LiteralPath $SourcePath -Force).Length
        $destinationLength = (Get-Item -LiteralPath $DestinationPath -Force).Length
        if ($sourceLength -eq $destinationLength) {
            $sourceHash = (Get-FileHash -LiteralPath $SourcePath -Algorithm SHA256).Hash
            $destinationHash = (Get-FileHash -LiteralPath $DestinationPath -Algorithm SHA256).Hash
            if ($sourceHash -eq $destinationHash) {
                return $false
            }
        }
    }

    Copy-Item -LiteralPath $SourcePath -Destination $DestinationPath -Force
    return $true
}

function Copy-PluginSource {
    <#
    .SYNOPSIS
    Materializes git-tracked source content into a plugin destination.

    .DESCRIPTION
    Copies current working-tree bytes for every git-tracked path at or beneath
    SourcePath, so locally modified tracked files are included and untracked
    files are excluded. A file source produces exactly one destination file; a
    directory source reconstructs its tracked subtree beneath DestinationPath.
    Returns every destination written so callers can record complete generated
    path bookkeeping for orphan cleanup.

    .PARAMETER SourcePath
    Absolute path to the repository file or directory being materialized.

    .PARAMETER DestinationPath
    Absolute destination path: the file itself for a file source, or the
    subtree root for a directory source.

    .PARAMETER RepoRoot
    Absolute path to the repository working tree.

    .PARAMETER TrackedIndex
    Optional index from Get-PluginTrackedPathIndex. Resolved on demand when
    omitted; callers in per-item loops should supply a shared index.

    .OUTPUTS
    [string[]] Absolute destination paths written.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [string]$DestinationPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$TrackedIndex
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot)
    $resolvedSource = [System.IO.Path]::GetFullPath($SourcePath)
    $relativeSource = [System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedSource) -replace '\\', '/'

    if ($relativeSource -eq '..' -or $relativeSource.StartsWith('../') -or [System.IO.Path]::IsPathRooted($relativeSource)) {
        throw "Source path '$SourcePath' resolves outside the repository root '$resolvedRoot'."
    }

    if (-not $TrackedIndex) {
        $TrackedIndex = Get-PluginTrackedPathIndex -RepoRoot $resolvedRoot
    }

    $isFileSource = $TrackedIndex.Lookup.Contains($relativeSource)
    $matched = [System.Collections.Generic.List[string]]::new()

    if ($isFileSource) {
        $matched.Add($relativeSource)
    }
    else {
        $prefix = "$relativeSource/"
        foreach ($tracked in $TrackedIndex.Paths) {
            if ($tracked.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
                $matched.Add($tracked)
            }
        }
    }

    if ($matched.Count -eq 0) {
        Write-Warning "No git-tracked content found for source: $relativeSource"
        return @()
    }

    $written = [System.Collections.Generic.List[string]]::new()

    foreach ($tracked in $matched) {
        $trackedSource = Join-Path -Path $resolvedRoot -ChildPath $tracked

        if ($isFileSource) {
            $destination = $DestinationPath
        }
        else {
            $suffix = $tracked.Substring($relativeSource.Length + 1)
            $destination = [System.IO.Path]::GetFullPath(
                [System.IO.Path]::Combine($DestinationPath, $suffix)
            )
        }

        # A path can be staged while absent from the working tree; skip it
        # rather than failing the whole generation run.
        if (-not (Test-Path -LiteralPath $trackedSource -PathType Leaf)) {
            Write-Warning "Tracked source missing from the working tree: $tracked"
            continue
        }

        $destinationDir = Split-Path -Parent $destination
        if ($destinationDir -and -not (Test-Path -LiteralPath $destinationDir -PathType Container)) {
            New-Item -ItemType Directory -Path $destinationDir -Force | Out-Null
        }

        Copy-PluginFileIfChanged -SourcePath $trackedSource -DestinationPath $destination | Out-Null
        $written.Add($destination)
    }

    return $written.ToArray()
}

function Write-PluginHookArtifact {
    <#
    .SYNOPSIS
    Materializes a hook manifest and its sibling script directory into a plugin.

    .DESCRIPTION
    Hook command paths in the source manifest are repository-root relative
    (for example .github/hooks/shared/telemetry/telemetry-collector.sh) so they resolve
    when the hook is auto-loaded from a checked-out repository. Inside an
    installed plugin the same scripts live under the plugin root, so this
    function writes a transformed copy of the manifest with those paths
    rewritten to the ${CLAUDE_PLUGIN_ROOT} placeholder, then materializes the
    sibling script directory (the manifest path without its .json extension).

    .PARAMETER SourceManifest
    Absolute path to the source hook .json manifest in the repository.

    .PARAMETER DestinationManifest
    Absolute path where the transformed manifest is written in the plugin.

    .PARAMETER GeneratedFiles
    Set tracking generated paths for orphan cleanup; every materialized script
    file is added to it.

    .PARAMETER RepoRoot
    Absolute path to the repository working tree.

    .PARAMETER TrackedIndex
    Optional git-tracked path index shared across a generation run.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceManifest,

        [Parameter(Mandatory = $true)]
        [string]$DestinationManifest,

        [Parameter(Mandatory = $true)]
        [System.Collections.Generic.HashSet[string]]$GeneratedFiles,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [hashtable]$TrackedIndex
    )

    # Degrade gracefully when the manifest is missing, matching how other kinds
    # warn rather than throw and fail the entire generation run.
    if (-not (Test-Path -LiteralPath $SourceManifest)) {
        Write-Warning "Hook manifest not found: $SourceManifest"
        return
    }

    # Rewrite repo-root-relative hook script paths to plugin-relative paths so
    # commands resolve from the installed plugin directory. CLAUDE_PLUGIN_ROOT
    # is the placeholder every Copilot host substitutes; an unsubstituted bare
    # ${PLUGIN_ROOT} reaches the shell and expands to an empty string. Literal
    # string replacement avoids regex interpretation of the path and the $
    # placeholder.
    $manifestText = Get-Content -LiteralPath $SourceManifest -Raw -Encoding utf8
    $manifestText = $manifestText.Replace('.github/hooks/', '${CLAUDE_PLUGIN_ROOT}/hooks/')
    Set-ContentIfChanged -Path $DestinationManifest -Value $manifestText | Out-Null

    # Materialize the sibling script directory (manifest path without .json).
    $scriptSrc = $SourceManifest -replace '\.json$', ''
    if (Test-Path -LiteralPath $scriptSrc) {
        $scriptDest = $DestinationManifest -replace '\.json$', ''
        $materialized = @(Copy-PluginSource -SourcePath $scriptSrc -DestinationPath $scriptDest `
                -RepoRoot $RepoRoot -TrackedIndex $TrackedIndex)
        foreach ($file in $materialized) {
            [void]$GeneratedFiles.Add($file)
        }
    }
}

function Write-PluginDirectory {
    <#
    .SYNOPSIS
    Creates a complete plugin directory structure from a catalog entry.

    .DESCRIPTION
    Builds the full plugin layout under the specified plugins directory using
    the resolved catalog recipe. Every declared component is materialized from
    its canonical git-tracked repository source into the package-relative path
    the catalog declares, so the manifest, the catalog, and the package tree
    describe the same membership. Generates the root plugin.json and README.md.

    .PARAMETER Entry
    Marketplace catalog entry describing package identity and provenance.

    .PARAMETER Items
    Resolved recipe items with Kind, Field, PackagePath, SourcePath, and
    Maturity keys.

    .PARAMETER PluginsDir
    Absolute path to the root plugins output directory.

    .PARAMETER RepoRoot
    Absolute path to the repository root.

    .PARAMETER Version
    Semantic version string from the repository package.json.

    .PARAMETER Maturity
        Optional package maturity string. Forwarded to
        New-PluginReadmeContent for maturity notice injection.

    .PARAMETER DocumentPath
        Optional absolute path to the durable package document supplying the
        README title, notice, and Overview content.

    .PARAMETER DryRun
    When specified, logs actions without creating files or directories.

    .OUTPUTS
    [hashtable] Result with Success, AgentCount, CommandCount, InstructionCount,
    SkillCount, HookCount, and GeneratedFiles keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Items,

        [Parameter(Mandatory = $true)]
        [string]$PluginsDir,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string]$Version,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity,

        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$DocumentPath,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $packageName = [string]$Entry['name']
    $pluginRoot = Join-Path -Path $PluginsDir -ChildPath $packageName

    # One index per plugin bounds git invocations while staying current for
    # callers that stage content between generations.
    $trackedIndex = if ($DryRun) { $null } else { Get-PluginTrackedPathIndex -RepoRoot $RepoRoot }

    $counts = @{
        AgentCount       = 0
        CommandCount     = 0
        InstructionCount = 0
        SkillCount       = 0
        HookCount        = 0
    }

    # Track unique directories per kind for plugin.json path arrays
    $agentDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $commandDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $ruleDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $skillDirs = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )
    $hookFiles = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    $readmeItems = @()
    $generatedFiles = [System.Collections.Generic.HashSet[string]]::new(
        [System.StringComparer]::OrdinalIgnoreCase
    )

    foreach ($item in $Items) {
        $kind = [string]$item.Kind
        $sourcePath = Join-Path -Path $RepoRoot -ChildPath $item.SourcePath
        $destPath = Join-Path -Path $pluginRoot -ChildPath ($item.PackagePath -replace '/', [System.IO.Path]::DirectorySeparatorChar)
        $itemName = Split-Path -Leaf $item.PackagePath

        if ($kind -eq 'skill') {
            # Read frontmatter from SKILL.md for description; fall back to directory name
            $skillMdPath = Join-Path -Path $sourcePath -ChildPath 'SKILL.md'
            if (Test-Path -Path $skillMdPath) {
                $frontmatter = Get-ArtifactFrontmatter -FilePath $skillMdPath -FallbackDescription $itemName
                $description = $frontmatter.description
            }
            else {
                $description = $itemName
            }
        }
        else {
            # Read description from the source file. Hook manifests are JSON
            # with no frontmatter, so read their top-level description field.
            $fallback = $itemName -replace '\.(md|json)$', ''
            if (-not (Test-Path -Path $sourcePath)) {
                $description = $fallback
                Write-Warning "Source file not found: $sourcePath"
            }
            elseif ($kind -eq 'hook') {
                $hookDesc = Get-ArtifactDescription -FilePath $sourcePath
                $description = if ($hookDesc) { $hookDesc } else { $fallback }
            }
            else {
                $frontmatter = Get-ArtifactFrontmatter -FilePath $sourcePath -FallbackDescription $fallback
                $description = $frontmatter.description
            }
        }

        $readmeItems += @{
            Name        = ($itemName -replace '\.md$', '') -replace '\.json$', ''
            Description = $description
            Kind        = $kind
            Maturity    = [string]$item.Maturity
        }

        $relativeParent = (Split-Path -Parent $item.PackagePath) -replace '\\', '/'

        # Update counts and collect parent directories for manifest paths
        switch ($kind) {
            'agent' {
                $counts.AgentCount++
                [void]$agentDirs.Add("$relativeParent/")
            }
            'prompt' {
                $counts.CommandCount++
                [void]$commandDirs.Add("$relativeParent/")
            }
            'instruction' {
                $counts.InstructionCount++
                [void]$ruleDirs.Add("$relativeParent/")
            }
            'skill' {
                $counts.SkillCount++
                [void]$skillDirs.Add("$($item.PackagePath)/")
            }
            'hook' {
                $counts.HookCount++
                [void]$hookFiles.Add($item.PackagePath)
            }
        }

        [void]$generatedFiles.Add($destPath)

        if ($DryRun) {
            Write-Verbose "DryRun: Would materialize $destPath from $sourcePath"
            continue
        }

        # Hooks bundle a sibling script directory and need plugin-relative
        # command paths; other kinds materialize their source directly.
        if ($kind -eq 'hook') {
            Write-PluginHookArtifact -SourceManifest $sourcePath -DestinationManifest $destPath `
                -GeneratedFiles $generatedFiles -RepoRoot $RepoRoot -TrackedIndex $trackedIndex
        }
        else {
            $materialized = @(Copy-PluginSource -SourcePath $sourcePath -DestinationPath $destPath `
                    -RepoRoot $RepoRoot -TrackedIndex $trackedIndex)
            foreach ($file in $materialized) {
                [void]$generatedFiles.Add($file)
            }
        }
    }

    # Materialize shared resource directories (unconditional, all plugins)
    $sharedDirs = @(
        @{ Source = 'docs/templates';    Destination = 'docs/templates' }
        @{ Source = 'scripts/lib';       Destination = 'scripts/lib' }
    )

    foreach ($dir in $sharedDirs) {
        $sourcePath = Join-Path -Path $RepoRoot -ChildPath $dir.Source
        $destPath = Join-Path -Path $pluginRoot -ChildPath $dir.Destination

        if (-not (Test-Path -Path $sourcePath)) {
            Write-Warning "Shared directory not found: $sourcePath"
            continue
        }

        [void]$generatedFiles.Add($destPath)

        if ($DryRun) {
            Write-Verbose "DryRun: Would materialize shared directory $destPath from $sourcePath"
            continue
        }

        $materialized = @(Copy-PluginSource -SourcePath $sourcePath -DestinationPath $destPath `
                -RepoRoot $RepoRoot -TrackedIndex $trackedIndex)
        foreach ($file in $materialized) {
            [void]$generatedFiles.Add($file)
        }
    }

    # Generate the single root plugin.json with explicit path arrays for
    # client discovery. Provenance mirrors the catalog entry; x-hve does not.
    $manifestPath = Join-Path -Path $pluginRoot -ChildPath 'plugin.json'
    $manifestArgs = @{
        PackageName  = $packageName
        Description  = [string]$Entry['description']
        Version      = $Version
        AgentPaths   = @($agentDirs)
        CommandPaths = @($commandDirs)
        RulePaths    = @($ruleDirs)
        SkillPaths   = @($skillDirs)
        HookPaths    = @($hookFiles)
    }
    if ($Entry.Contains('author') -and $Entry['author'] -is [System.Collections.IDictionary]) {
        $manifestArgs['Author'] = $Entry['author']
    }
    foreach ($provenance in @('homepage', 'repository', 'license')) {
        if ($Entry.Contains($provenance) -and -not [string]::IsNullOrWhiteSpace([string]$Entry[$provenance])) {
            $manifestArgs[[cultureinfo]::InvariantCulture.TextInfo.ToTitleCase($provenance)] = [string]$Entry[$provenance]
        }
    }
    if ($Entry.Contains('keywords') -and $Entry['keywords']) {
        $manifestArgs['Keywords'] = @($Entry['keywords'] | ForEach-Object { [string]$_ })
    }
    $manifest = New-PluginManifestContent @manifestArgs
    [void]$generatedFiles.Add($manifestPath)

    if ($DryRun) {
        Write-Verbose "DryRun: Would write plugin.json at $manifestPath"
    }
    else {
        if (-not (Test-Path -Path $pluginRoot)) {
            New-Item -ItemType Directory -Path $pluginRoot -Force | Out-Null
        }
        $jsonContent = $manifest | ConvertTo-Json -Depth 10
        Set-ContentIfChanged -Path $manifestPath -Value $jsonContent | Out-Null
    }

    # Generate README.md
    $readmePath = Join-Path -Path $pluginRoot -ChildPath 'README.md'
    $documentContent = if (-not [string]::IsNullOrWhiteSpace($DocumentPath) -and (Test-Path -LiteralPath $DocumentPath -PathType Leaf)) {
        Get-Content -LiteralPath $DocumentPath -Raw -Encoding utf8
    } else { $null }
    $readmePackage = @{
        id          = $packageName
        name        = $packageName
        description = [string]$Entry['description']
    }
    $readmeContent = New-PluginReadmeContent -PackageMetadata $readmePackage -Items $readmeItems -Maturity $Maturity -PackageDocumentation $documentContent
    [void]$generatedFiles.Add($readmePath)

    if ($DryRun) {
        Write-Verbose "DryRun: Would write README.md at $readmePath"
    }
    else {
        Set-ContentIfChanged -Path $readmePath -Value $readmeContent | Out-Null
    }

    return @{
        Success          = $true
        AgentCount       = $counts.AgentCount
        CommandCount     = $counts.CommandCount
        InstructionCount = $counts.InstructionCount
        SkillCount       = $counts.SkillCount
        HookCount        = $counts.HookCount
        GeneratedFiles   = $generatedFiles
    }
}

Export-ModuleMember -Function @(
    'Assert-PluginSnapshotTarget',
    'Copy-PluginSource',
    'Get-PluginItemMaturityLabel',
    'Get-PluginTrackedPathIndex',
    'New-GenerateResult',
    'New-MarketplaceManifestContent',
    'New-PluginManifestContent',
    'New-PluginReadmeContent',
    'New-PluginReleaseLocator',
    'Split-PluginDocumentationSource',
    'Write-MarketplaceManifest',
    'Write-PluginDirectory'
)
