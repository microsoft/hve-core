#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Synchronizes root plugin.json with the distributable tracked component set.

.DESCRIPTION
    Derives the root All plugin manifest from git-tracked files under the
    .github artifact discovery root. Inclusion is a closed path-and-license
    classification:

    - agents/<package>/**/*.agent.md
    - prompts/<package>/**/*.prompt.md
    - instructions/<package>/**/*.instructions.md
    - skills/<package>/<skill>/SKILL.md, unless the parsed top-level license
      carries a noncommercial qualifier
    - extensions/<package>/<extension>/extension.mjs, declared through the
      package container folder (.github/extensions/<package>) that holds the
      extension folders

    Repository-root artifacts, which have no package segment, are excluded.
    Paths are unique and ordinal-sorted, manifest metadata is preserved, and the
    version follows the root package.json. The extensions field is emitted only
    when at least one extension container exists. The manifest declares no hooks:
    hooks support was removed with the telemetry hook, so a committed hooks field
    is reported as drift rather than preserved.

    Check mode writes nothing. It checks each catalog locator against the
    manifest at its source. Additional manifests select tracked components
    from the All inventory, relative to their own roots; sync never rewrites them.

.PARAMETER RepoRoot
    Root directory of the repository. Defaults to the git working tree root.

.PARAMETER Check
    Report drift and catalog violations without writing the manifest.

.EXAMPLE
    ./Sync-PluginManifest.ps1

.EXAMPLE
    ./Sync-PluginManifest.ps1 -Check

.NOTES
    Runs via: npm run plugin:sync and npm run lint:plugin-manifest
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = ((git rev-parse --show-toplevel 2>$null) ?? (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path),

    [Parameter(Mandatory = $false)]
    [switch]$Check
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'PluginCatalog.psm1') -Force

$script:ArtifactRoot = '.github'
$script:PluginManifestFile = 'plugin.json'
$script:RequiredPluginMetadata = @('plugin.json', 'README.md', 'LICENSE')
$script:ManifestMetadataKey = @('author', 'homepage', 'repository', 'license', 'keywords')
$script:LocatorMetadataKey = @('name', 'description', 'version', 'author', 'homepage', 'repository', 'license', 'keywords')
# Fields the marketplace locator must never declare. 'hooks' stays listed after
# the manifest stopped supporting it, because a retired field is exactly what
# this deny-list exists to reject.
$script:RecipeField = @('agents', 'commands', 'rules', 'skills', 'extensions', 'hooks', 'x-hve')
# Every field the derived manifest can produce. A committed field outside this
# set is drift, which is what keeps a removed field from returning silently.
$script:SupportedManifestField = @('name', 'description', 'version') + $script:ManifestMetadataKey + @('agents', 'commands', 'rules', 'skills', 'extensions')

#region Discovery

function Get-TrackedPluginIndex {
    <#
    .SYNOPSIS
        Reads tracked plugin paths and rejects symbolic-link index entries.

    .DESCRIPTION
        One staged index read serves both component discovery and root metadata
        validation. Mode maps every returned repository-relative path, including
        the required root files, to its exact git index mode.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Paths, violation
        messages, and index modes derived from the git index.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $output = & git -C $RepoRoot ls-files -s -z --full-name -- $script:ArtifactRoot $script:RequiredPluginMetadata ':(glob)**/plugin.json'
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed with exit code $LASTEXITCODE in $RepoRoot"
    }

    $prefix = "$script:ArtifactRoot/"
    $paths = @()
    $violations = @()
    $mode = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)
    foreach ($entry in (($output -join '') -split "`0" | Where-Object { $_ })) {
        if ($entry -notmatch '^(?<Mode>\d{6}) [0-9a-f]+ \d+\t(?<Path>.+)$') {
            throw "Unexpected git ls-files entry: $entry"
        }

        $path = $Matches['Path']
        $mode[$path] = $Matches['Mode']
        if (-not $path.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
            continue
        }

        $relativePath = $path.Substring($prefix.Length)
        if ($Matches['Mode'] -eq '120000') {
            $violations += "Tracked plugin path is a symbolic link: $relativePath"
            continue
        }
        $paths += $relativePath
    }

    return [ordered]@{
        Paths      = @($paths)
        Violations = @($violations)
        Mode       = $mode
    }
}

function Get-TrackedPluginFile {
    <#
    .SYNOPSIS
        Lists git-tracked files under the artifact discovery root.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .OUTPUTS
        [string[]] Artifact-root-relative forward-slash paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $index = Get-TrackedPluginIndex -RepoRoot $RepoRoot
    if ($index.Violations.Count -gt 0) {
        throw ($index.Violations -join [Environment]::NewLine)
    }
    return @($index.Paths)
}

function Get-SkillLicense {
    <#
    .SYNOPSIS
        Reads the top-level license value from a skill entrypoint.

    .DESCRIPTION
        Only a zero-indent license key inside the leading frontmatter block is
        considered, so nested metadata licenses never drive classification.

    .PARAMETER Path
        Absolute path to a SKILL.md file.

    .OUTPUTS
        [string] License value, or an empty string when none is declared.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        return ''
    }

    $lines = @(Get-Content -LiteralPath $Path -TotalCount 200)
    if ($lines.Count -eq 0 -or $lines[0].Trim() -ne '---') {
        return ''
    }

    for ($index = 1; $index -lt $lines.Count; $index++) {
        if ($lines[$index].Trim() -eq '---') {
            break
        }
        if ($lines[$index] -match '^license:\s*(.*)$') {
            return $Matches[1].Trim().Trim('"').Trim("'")
        }
    }

    return ''
}

function Test-NoncommercialLicense {
    <#
    .SYNOPSIS
        Indicates whether a license identifier carries a noncommercial qualifier.

    .PARAMETER License
        Parsed license value.

    .OUTPUTS
        [bool] True when the license forbids commercial distribution.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyString()]
        [string]$License
    )

    if ([string]::IsNullOrWhiteSpace($License)) {
        return $false
    }

    return [bool]($License -match '(?i)(^|[^a-z0-9])(nc|non-?commercial)([^a-z0-9]|$)')
}

function Get-PluginComponentSet {
    <#
    .SYNOPSIS
        Classifies tracked plugin-root files into distributable component sets.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER TrackedPath
        Prevalidated artifact-root-relative tracked paths.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] agents, commands,
        rules, skills, and extensions path arrays.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$TrackedPath
    )

    if (-not $PSBoundParameters.ContainsKey('TrackedPath')) {
        $TrackedPath = Get-TrackedPluginFile -RepoRoot $RepoRoot
    }

    $agents = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    $commands = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    $rules = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    $skills = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    $extensions = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)

    foreach ($path in $TrackedPath) {
        switch -Regex ($path) {
            '^agents/[^/]+/.+\.agent\.md$' { [void]$agents.Add($path); continue }
            '^prompts/[^/]+/.+\.prompt\.md$' { [void]$commands.Add($path); continue }
            '^instructions/[^/]+/.+\.instructions\.md$' { [void]$rules.Add($path); continue }
            '^skills/[^/]+/[^/]+/SKILL\.md$' {
                $license = Get-SkillLicense -Path (Join-Path $RepoRoot $script:ArtifactRoot $path)
                if (-not (Test-NoncommercialLicense -License $license)) {
                    [void]$skills.Add("$script:ArtifactRoot/$($path -replace '/SKILL\.md$', '')")
                }
                continue
            }
            '^(?<Container>extensions/[^/]+)/[^/]+/extension\.mjs$' {
                [void]$extensions.Add("$script:ArtifactRoot/$($Matches['Container'])")
                continue
            }
        }
    }

    return [ordered]@{
        agents     = @($agents | ForEach-Object { "$script:ArtifactRoot/$_" })
        commands   = @($commands | ForEach-Object { "$script:ArtifactRoot/$_" })
        rules      = @($rules | ForEach-Object { "$script:ArtifactRoot/$_" })
        skills     = @($skills)
        extensions = @($extensions)
    }
}

#endregion Discovery

#region Manifest

function Get-RepositoryVersion {
    <#
    .SYNOPSIS
        Reads the repository version from the root package manifest.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .OUTPUTS
        [string] Semantic version string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $packagePath = Join-Path $RepoRoot 'package.json'
    if (-not (Test-Path -LiteralPath $packagePath -PathType Leaf)) {
        throw "Root package manifest not found: $packagePath"
    }

    $version = (Get-Content -LiteralPath $packagePath -Raw | ConvertFrom-Json).version
    if ([string]::IsNullOrWhiteSpace($version)) {
        throw "Root package manifest declares no version: $packagePath"
    }

    return $version
}

function New-PluginManifest {
    <#
    .SYNOPSIS
        Builds the expected plugin manifest content.

    .DESCRIPTION
        Metadata is preserved from the committed manifest, the version follows
        the root package manifest, and component arrays are derived. The
        extensions array is emitted only when it has entries. No hooks
        declaration is emitted.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER Component
        Component sets from Get-PluginComponentSet.

    .PARAMETER Version
        Repository version to declare.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Manifest content.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Component,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version
    )

    $manifestPath = Join-Path $RepoRoot $script:PluginManifestFile
    if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
        throw "Plugin manifest not found: $manifestPath"
    }

    $current = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
    if ([string]::IsNullOrWhiteSpace($current['name'])) {
        throw "Plugin manifest declares no name: $manifestPath"
    }

    $manifest = [ordered]@{ name = $current['name'] }
    if ($current.ContainsKey('description')) {
        $manifest['description'] = $current['description']
    }
    $manifest['version'] = $Version
    foreach ($key in $script:ManifestMetadataKey) {
        if ($current.ContainsKey($key)) {
            $manifest[$key] = $current[$key]
        }
    }

    foreach ($kind in @('agents', 'commands', 'rules', 'skills')) {
        $manifest[$kind] = @($Component[$kind])
    }
    if ($Component.Contains('extensions') -and @($Component['extensions']).Count -gt 0) {
        $manifest['extensions'] = @($Component['extensions'])
    }

    return $manifest
}

function ConvertTo-PluginManifestJson {
    <#
    .SYNOPSIS
        Serializes a manifest to deterministic newline-normalized JSON text.

    .PARAMETER Manifest
        Manifest content.

    .OUTPUTS
        [string] JSON text with LF endings and one trailing newline.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest
    )

    $json = ($Manifest | ConvertTo-Json -Depth 10) -replace "`r`n", "`n"
    return $json.TrimEnd("`n") + "`n"
}

function Compare-PluginManifest {
    <#
    .SYNOPSIS
        Describes supported differences between committed and derived manifests.

    .PARAMETER Committed
        Manifest content read from disk.

    .PARAMETER Expected
        Derived manifest content.

    .OUTPUTS
        [string[]] Human-readable drift descriptions.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [System.Collections.IDictionary]$Committed,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Expected
    )

    $differences = @()
    foreach ($field in @('version')) {
        $committedValue = if ($null -ne $Committed -and $Committed.Contains($field)) { [string]$Committed[$field] } else { '<missing>' }
        $expectedValue = if ($Expected.Contains($field)) { [string]$Expected[$field] } else { '<missing>' }
        if ($committedValue -cne $expectedValue) {
            $differences += "$field differs: committed '$committedValue'; expected '$expectedValue'"
        }
    }

    if ($null -ne $Committed) {
        foreach ($field in @($Committed.Keys)) {
            if ($script:SupportedManifestField -cnotcontains $field) {
                $differences += "$field is declared but the manifest no longer supports it; remove it"
            }
        }
    }

    foreach ($kind in @('agents', 'commands', 'rules', 'skills', 'extensions')) {
        # A missing key must yield no paths: @($null) would contain one $null element.
        $committedPaths = @()
        if ($null -ne $Committed -and $Committed.Contains($kind)) {
            $committedPaths = @($Committed[$kind])
        }
        $expectedPaths = @()
        if ($Expected.Contains($kind)) {
            $expectedPaths = @($Expected[$kind])
        }

        $missing = @($expectedPaths | Where-Object { $_ -cnotin $committedPaths })
        $extra = @($committedPaths | Where-Object { $_ -cnotin $expectedPaths })

        if ($missing.Count -gt 0) {
            $differences += "$kind missing $($missing.Count): $($missing -join ', ')"
        }
        if ($extra.Count -gt 0) {
            $differences += "$kind unexpected $($extra.Count): $($extra -join ', ')"
        }
    }

    return $differences
}

#endregion Manifest

#region Package metadata

function Get-PluginMetadataViolations {
    <#
    .SYNOPSIS
        Validates required files at the plugin root.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER TrackedMode
        Repository-relative path to git index mode map. Defaults to a fresh
        index read so direct callers need no snapshot.

    .OUTPUTS
        [string[]] Violation messages.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.IDictionary[string, string]]$TrackedMode
    )

    if (-not $TrackedMode) {
        $TrackedMode = (Get-TrackedPluginIndex -RepoRoot $RepoRoot).Mode
    }

    $violations = @()
    foreach ($relativePath in $script:RequiredPluginMetadata) {
        $path = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $violations += "Required plugin root file is missing or not a regular file: $relativePath"
            continue
        }

        $mode = $null
        if (-not $TrackedMode.TryGetValue($relativePath, [ref]$mode)) {
            $violations += "Required plugin root file is not tracked: $relativePath"
            continue
        }
        if ($mode -notin @('100644', '100755')) {
            $violations += "Required plugin root file is not a tracked regular file: $relativePath (mode $mode)"
            continue
        }
        $item = Get-Item -LiteralPath $path -Force
        if ($item.LinkType) {
            $violations += "Required plugin root file is a symbolic link: $relativePath"
        }
        elseif ($item.Length -eq 0) {
            $violations += "Required plugin root file is empty: $relativePath"
        }
    }
    return $violations
}

#endregion Package metadata

#region Catalog

function Resolve-PluginPath {
    <#
    .SYNOPSIS
        Resolves a path through symbolic links in every existing segment.

    .PARAMETER Path
        Existing file or directory path to resolve.

    .OUTPUTS
        [string] Canonical absolute path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    $fullPath = [System.IO.Path]::GetFullPath($Path)
    $pathRoot = [System.IO.Path]::GetPathRoot($fullPath)
    $current = $pathRoot
    $relative = $fullPath.Substring($pathRoot.Length)
    foreach ($segment in $relative.Split([System.IO.Path]::DirectorySeparatorChar, [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $segment
        $item = Get-Item -LiteralPath $current -Force
        if ($item.LinkType) {
            $current = $item.ResolveLinkTarget($true).FullName
        }
    }
    return [System.IO.Path]::GetFullPath($current)
}

function Get-PluginComponentCoverageViolations {
    <#
    .SYNOPSIS
        Verifies every declared component path resolves inside the plugin root.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER SourcePath
        Repository-relative plugin root declared by the catalog entry.

    .PARAMETER Manifest
        Manifest content.

    .PARAMETER Inventory
        Derived All manifest. When checking another source, paths must also
        belong to this tracked, license-filtered inventory under the same kind.

    .OUTPUTS
        [string[]] Violation messages.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary]$Inventory
    )

    $violations = @()
    $root = Resolve-PluginPath -Path (Join-Path $RepoRoot $SourcePath)
    $rootPrefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    # Components share few immediate parents, so resolving each distinct parent
    # once avoids repeating the whole segment walk per component. Ordinal keys on
    # every platform preserve the script's case-sensitive path identity.
    $parentCache = [System.Collections.Generic.Dictionary[string, string]]::new([System.StringComparer]::Ordinal)

    foreach ($kind in @('agents', 'commands', 'rules', 'skills', 'extensions')) {
        if (-not $Manifest.Contains($kind)) { continue }
        $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
        $type = if ($kind -in @('skills', 'extensions')) { 'Container' } else { 'Leaf' }
        foreach ($path in @($Manifest[$kind])) {
            if ($path -isnot [string] -or [string]::IsNullOrWhiteSpace($path)) {
                $violations += "$kind path must be a non-empty string under $SourcePath"
                continue
            }
            if ([System.IO.Path]::IsPathRooted($path) -or $path -match '^[A-Za-z]:|\\|(^|/)\.\.(/|$)') {
                $violations += "$kind path escapes the plugin root: $path"
                continue
            }
            $candidate = Join-Path $root $path
            if (-not (Test-Path -LiteralPath $candidate -PathType $type)) {
                $violations += "$kind path does not exist under $SourcePath : $path"
                continue
            }

            $fullCandidate = [System.IO.Path]::GetFullPath($candidate)
            $parent = [System.IO.Path]::GetDirectoryName($fullCandidate)
            $resolvedParent = $null
            if (-not $parentCache.TryGetValue($parent, [ref]$resolvedParent)) {
                $resolvedParent = Resolve-PluginPath -Path $parent
                $parentCache[$parent] = $resolvedParent
            }

            $resolved = Join-Path $resolvedParent ([System.IO.Path]::GetFileName($fullCandidate))
            $item = Get-Item -LiteralPath $resolved -Force
            if ($item.LinkType) {
                $resolved = $item.ResolveLinkTarget($true).FullName
            }
            $resolved = [System.IO.Path]::GetFullPath($resolved)

            if ($resolved -cne $root -and -not $resolved.StartsWith($rootPrefix, [System.StringComparison]::Ordinal)) {
                $violations += "$kind path resolves outside the plugin root: $path"
                continue
            }

            $repoPath = [System.IO.Path]::GetRelativePath($RepoRoot, (Join-Path $RepoRoot $SourcePath $path)).Replace('\', '/').TrimEnd('/')
            if (-not $seen.Add($repoPath)) {
                $violations += "$kind path is duplicated under $SourcePath : $path"
            }
            if ($Inventory -and $repoPath -cnotin $Inventory[$kind]) {
                $violations += "$kind path is not a tracked distributable $kind component of the All plugin: $repoPath"
            }

            if ($kind -eq 'extensions') {
                $entryFiles = @(Get-ChildItem -LiteralPath $resolved -Directory -Force |
                        Where-Object { Test-Path -LiteralPath (Join-Path $_.FullName 'extension.mjs') -PathType Leaf })
                if ($entryFiles.Count -eq 0) {
                    $violations += "extensions path holds no extension folder with extension.mjs: $path"
                }
            }
        }
    }

    return $violations
}

function Get-PluginCatalogMetadataViolations {
    <#
    .SYNOPSIS
        Validates catalog shape, manifest parity, and the source locator.

    .DESCRIPTION
        Pairs each locator with its own tracked manifest. For the root only,
        compare the expected manifest so write mode can repair root drift.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER Manifest
        Expected root All manifest.

    .PARAMETER TrackedMode
        Snapshot of tracked repository paths and their index modes.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Violation messages
        and source/manifest pairs to check for component coverage.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.IDictionary[string, string]]$TrackedMode = (Get-TrackedPluginIndex -RepoRoot $RepoRoot).Mode
    )

    $catalog = Get-PluginCatalog -RepoRoot $RepoRoot
    $violations = @($catalog.Violations)
    $coverage = @()
    if ($catalog.Version -isnot [string] -or $catalog.Version -cne $Manifest['version']) {
        $violations += "Catalog metadata version '$($catalog.Version)' does not match manifest version '$($Manifest['version'])'"
    }

    foreach ($plugin in $catalog.Entries) {
        $entry = $plugin.Locator
        $file = $plugin.ManifestPath
        if ($TrackedMode[$file] -notin @('100644', '100755')) {
            $violations += "Catalog manifest is not a tracked regular file: $file"
            continue
        }
        $local = $Manifest
        if ($plugin.Source -cne '.') {
            $local = Get-Content -LiteralPath (Join-Path $RepoRoot $file) -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate
            if ($local -isnot [System.Collections.IDictionary]) {
                $violations += "Plugin manifest must be an object: $file"
                continue
            }
            foreach ($field in $local.Keys) {
                if ($field -cnotin $script:SupportedManifestField) {
                    $violations += "Unsupported manifest field '$field' in $file"
                }
            }
        }

        foreach ($field in $script:LocatorMetadataKey) {
            if ($entry.Contains($field) -ne $local.Contains($field)) {
                $violations += "Catalog entry field '$field' presence does not match the manifest: $file"
            }
            elseif ($entry.Contains($field)) {
                $entryValue = ConvertTo-Json -InputObject $entry[$field] -Depth 10 -Compress
                $manifestValue = ConvertTo-Json -InputObject $local[$field] -Depth 10 -Compress
                if ($entryValue -cne $manifestValue) {
                    $violations += "Catalog entry field '$field' does not match the manifest: $file"
                }
            }
        }
        if ($plugin.Source -cne '.' -and ($local.version -isnot [string] -or $local.version -cne $catalog.Version)) {
            $violations += "Catalog metadata version '$($catalog.Version)' does not match $file version '$($local.version)'"
        }
        foreach ($field in $script:RecipeField) {
            if ($entry.Contains($field)) {
                $violations += "Catalog entry declares retired package recipe field '$field': $file"
            }
        }
        $coverage += [ordered]@{ Source = $plugin.Source; Manifest = $local }
    }

    return [ordered]@{ Violations = $violations; Coverage = $coverage }
}

function Get-PluginCatalogViolations {
    <#
    .SYNOPSIS
        Validates marketplace locators and their source-relative components.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER Manifest
        Expected root All manifest.

    .PARAMETER TrackedMode
        Snapshot of tracked repository paths and their index modes.

    .OUTPUTS
        [string[]] Violation messages.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Manifest,

        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.IDictionary[string, string]]$TrackedMode = (Get-TrackedPluginIndex -RepoRoot $RepoRoot).Mode
    )

    $metadata = Get-PluginCatalogMetadataViolations -RepoRoot $RepoRoot -Manifest $Manifest -TrackedMode $TrackedMode
    $violations = @($metadata.Violations)
    foreach ($plugin in $metadata.Coverage) {
        $inventory = if ($plugin.Source -cne '.') { $Manifest }
        $violations += @(Get-PluginComponentCoverageViolations -RepoRoot $RepoRoot -SourcePath $plugin.Source -Manifest $plugin.Manifest -Inventory $inventory)
    }
    return $violations
}

#endregion Catalog

#region Synchronization

function Invoke-PluginManifestSync {
    <#
    .SYNOPSIS
        Synchronizes or verifies the plugin manifest and marketplace catalog.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER Check
        Report drift without writing.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Changed flag,
        violations, and the expected manifest.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [switch]$Check
    )

    $trackedIndex = Get-TrackedPluginIndex -RepoRoot $RepoRoot

    $metadataViolations = @(Get-PluginMetadataViolations -RepoRoot $RepoRoot -TrackedMode $trackedIndex.Mode)
    if ($metadataViolations.Count -gt 0) {
        return [ordered]@{
            Changed    = $false
            Violations = $metadataViolations
            Manifest   = $null
        }
    }

    $components = Get-PluginComponentSet -RepoRoot $RepoRoot -TrackedPath $trackedIndex.Paths
    $version = Get-RepositoryVersion -RepoRoot $RepoRoot
    $manifest = New-PluginManifest -RepoRoot $RepoRoot -Component $components -Version $version

    $manifestPath = Join-Path $RepoRoot $script:PluginManifestFile
    $expectedJson = ConvertTo-PluginManifestJson -Manifest $manifest
    $committedRaw = Get-Content -LiteralPath $manifestPath -Raw
    $committedJson = ($committedRaw -replace "`r`n", "`n").TrimEnd("`n") + "`n"

    $violations = @($trackedIndex.Violations)
    $changed = $expectedJson -cne $committedJson

    $violations += @(Get-PluginCatalogViolations -RepoRoot $RepoRoot -Manifest $manifest -TrackedMode $trackedIndex.Mode)

    if ($changed) {
        if ($Check) {
            $violations += "$script:PluginManifestFile is out of sync with the derived manifest"
            $drift = @(Compare-PluginManifest -Committed (ConvertFrom-Json $committedRaw -AsHashtable) -Expected $manifest)
            $violations += if ($drift.Count -gt 0) { $drift } else { "$script:PluginManifestFile differs from the derived manifest, but no supported drift detail is available" }
        }
        elseif ($violations.Count -eq 0) {
            Set-Content -LiteralPath $manifestPath -Value $expectedJson -Encoding UTF8 -NoNewline
        }
    }

    return [ordered]@{
        Changed    = $changed
        Violations = @($violations)
        Manifest   = $manifest
    }
}

#endregion Synchronization

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $result = Invoke-PluginManifestSync -RepoRoot $RepoRoot -Check:$Check

        if ($result.Violations.Count -gt 0) {
            Write-Host "Plugin manifest validation failed: $($result.Violations.Count) violations" -ForegroundColor Red
            foreach ($violation in $result.Violations) {
                Write-Host "   $violation" -ForegroundColor Red
            }
            if ($Check) {
                Write-Host '   Run: npm run plugin:sync' -ForegroundColor Yellow
            }
            exit 1
        }

        $manifest = $result.Manifest
        $summary = "$($manifest.agents.Count) agents, $($manifest.commands.Count) commands, $($manifest.rules.Count) rules, $($manifest.skills.Count) skills"
        if ($manifest.Contains('extensions')) {
            $summary += ", $(@($manifest.extensions).Count) extension containers"
        }
        if ($Check) {
            Write-Host "Plugin manifest and catalog are in sync ($summary)." -ForegroundColor Green
        }
        elseif ($result.Changed) {
            Write-Host "Updated $script:PluginManifestFile ($summary)." -ForegroundColor Green
        }
        else {
            Write-Host "$script:PluginManifestFile is already current ($summary)." -ForegroundColor Green
        }
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Sync-PluginManifest failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
