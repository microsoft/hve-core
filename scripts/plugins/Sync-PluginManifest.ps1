#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Synchronizes root plugin.json with the distributable tracked component set.

.DESCRIPTION
    Derives the sole root plugin manifest from git-tracked files under the
    .github artifact discovery root. Inclusion is a closed path-and-license
    classification:

    - agents/<package>/**/*.agent.md
    - prompts/<package>/**/*.prompt.md
    - instructions/<package>/**/*.instructions.md
    - skills/<package>/<skill>/SKILL.md, unless the parsed top-level license
      carries a noncommercial qualifier

    Repository-root artifacts, which have no package segment, are excluded.
    Paths are unique and ordinal-sorted, manifest metadata is preserved, the
    version follows the root package.json, and the fixed hook declaration
    remains present.

    Check mode writes nothing. It reports manifest drift and validates the
    one-entry marketplace catalog: exactly one entry, name and version parity,
    a relative contained source, manifest existence under that source, declared
    component coverage, and the absence of package recipe fields.

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

$script:ArtifactRoot = '.github'
$script:PluginManifestFile = 'plugin.json'
$script:MarketplaceCatalogFile = '.github/plugin/marketplace.json'
$script:FixedHookPath = '.github/hooks/shared/telemetry.json'
$script:RequiredPluginMetadata = @('plugin.json', 'README.md', 'LICENSE')
$script:ManifestMetadataKey = @('author', 'homepage', 'repository', 'license', 'keywords')
$script:LocatorMetadataKey = @('name', 'description', 'version', 'author', 'homepage', 'repository', 'license', 'keywords')
$script:RecipeField = @('agents', 'commands', 'rules', 'skills', 'hooks', 'x-hve')

#region Discovery

function Get-TrackedPluginIndex {
    <#
    .SYNOPSIS
        Reads tracked plugin paths and rejects symbolic-link index entries.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .OUTPUTS
        [System.Collections.Specialized.OrderedDictionary] Paths and violation
        messages derived from the git index.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $output = & git -C $RepoRoot ls-files -s -z --full-name -- $script:ArtifactRoot
    if ($LASTEXITCODE -ne 0) {
        throw "git ls-files failed with exit code $LASTEXITCODE in $RepoRoot"
    }

    $prefix = "$script:ArtifactRoot/"
    $paths = @()
    $violations = @()
    foreach ($entry in (($output -join '') -split "`0" | Where-Object { $_ })) {
        if ($entry -notmatch '^(?<Mode>\d{6}) [0-9a-f]+ \d+\t(?<Path>.+)$') {
            throw "Unexpected git ls-files entry: $entry"
        }

        $path = $Matches['Path']
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
        rules, and skills path arrays.
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
        }
    }

    return [ordered]@{
        agents   = @($agents | ForEach-Object { "$script:ArtifactRoot/$_" })
        commands = @($commands | ForEach-Object { "$script:ArtifactRoot/$_" })
        rules    = @($rules | ForEach-Object { "$script:ArtifactRoot/$_" })
        skills   = @($skills)
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
        the root package manifest, component arrays are derived, and the fixed
        hook declaration is always emitted.

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
    $manifest['hooks'] = $script:FixedHookPath

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
    foreach ($field in @('version', 'hooks')) {
        $committedValue = if ($null -ne $Committed -and $Committed.Contains($field)) { [string]$Committed[$field] } else { '<missing>' }
        if ($committedValue -cne [string]$Expected[$field]) {
            $differences += "$field differs: committed '$committedValue'; expected '$($Expected[$field])'"
        }
    }

    foreach ($kind in @('agents', 'commands', 'rules', 'skills')) {
        $committedPaths = @()
        if ($null -ne $Committed -and $Committed.Contains($kind)) {
            $committedPaths = @($Committed[$kind])
        }
        $expectedPaths = @($Expected[$kind])

        $missing = @($expectedPaths | Where-Object { $_ -notin $committedPaths })
        $extra = @($committedPaths | Where-Object { $_ -notin $expectedPaths })

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

    .OUTPUTS
        [string[]] Violation messages.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $violations = @()
    foreach ($relativePath in $script:RequiredPluginMetadata) {
        $path = Join-Path $RepoRoot $relativePath
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            $violations += "Required plugin root file is missing or not a regular file: $relativePath"
            continue
        }

        $indexOutput = & git -C $RepoRoot ls-files -s --full-name -- $relativePath
        if ($LASTEXITCODE -ne 0) {
            throw "git ls-files failed with exit code $LASTEXITCODE in $RepoRoot"
        }
        $entry = @($indexOutput | Where-Object { $_ })
        if ($entry.Count -ne 1 -or $entry[0] -notmatch '^(?<Mode>\d{6}) [0-9a-f]+ \d+\t(?<Path>.+)$' -or $Matches['Path'] -cne $relativePath) {
            $violations += "Required plugin root file is not tracked: $relativePath"
            continue
        }
        if ($Matches['Mode'] -notin @('100644', '100755')) {
            $violations += "Required plugin root file is not a tracked regular file: $relativePath (mode $($Matches['Mode']))"
            continue
        }
        if ((Get-Item -LiteralPath $path).Length -eq 0) {
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
        [System.Collections.IDictionary]$Manifest
    )

    $violations = @()
    $root = Resolve-PluginPath -Path (Join-Path $RepoRoot $SourcePath)
    $rootPrefix = $root.TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar

    foreach ($kind in @('agents', 'commands', 'rules', 'skills')) {
        $type = if ($kind -eq 'skills') { 'Container' } else { 'Leaf' }
        foreach ($path in @($Manifest[$kind])) {
            if ([System.IO.Path]::IsPathRooted($path) -or $path -match '\\' -or $path -match '(^|/)\.\.(/|$)') {
                $violations += "$kind path escapes the plugin root: $path"
                continue
            }
            $candidate = Join-Path $root $path
            if (-not (Test-Path -LiteralPath $candidate -PathType $type)) {
                $violations += "$kind path does not exist under $SourcePath : $path"
                continue
            }
            $resolved = Resolve-PluginPath -Path $candidate
            if ($resolved -cne $root -and -not $resolved.StartsWith($rootPrefix, [System.StringComparison]::Ordinal)) {
                $violations += "$kind path resolves outside the plugin root: $path"
            }
        }
    }

    $hookPath = Join-Path $root $Manifest['hooks']
    if (-not (Test-Path -LiteralPath $hookPath -PathType Leaf)) {
        $violations += "hooks path does not exist under $SourcePath : $($Manifest['hooks'])"
    }
    else {
        $resolvedHook = Resolve-PluginPath -Path $hookPath
        if (-not $resolvedHook.StartsWith($rootPrefix, [System.StringComparison]::Ordinal)) {
            $violations += "hooks path resolves outside the plugin root: $($Manifest['hooks'])"
        }
    }

    return $violations
}

function Get-PluginCatalogViolations {
    <#
    .SYNOPSIS
        Validates the one-entry marketplace catalog against the plugin manifest.

    .PARAMETER RepoRoot
        Root directory of the repository.

    .PARAMETER Manifest
        Expected manifest content.

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
        [System.Collections.IDictionary]$Manifest
    )

    $catalogPath = Join-Path $RepoRoot $script:MarketplaceCatalogFile
    if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
        return @("Marketplace catalog not found: $script:MarketplaceCatalogFile")
    }

    $catalog = Get-Content -LiteralPath $catalogPath -Raw | ConvertFrom-Json -AsHashtable
    $violations = @()

    $entries = @($catalog['plugins'])
    if ($entries.Count -ne 1) {
        return @("Marketplace catalog declares $($entries.Count) entries; exactly one is required")
    }

    $entry = $entries[0]
    foreach ($field in $script:LocatorMetadataKey) {
        $entryHasField = $entry.Contains($field)
        $manifestHasField = $Manifest.Contains($field)
        if ($entryHasField -ne $manifestHasField) {
            $violations += "Catalog entry field '$field' presence does not match the manifest"
            continue
        }
        if ($entryHasField) {
            $entryValue = $entry[$field] | ConvertTo-Json -Depth 10 -Compress
            $manifestValue = $Manifest[$field] | ConvertTo-Json -Depth 10 -Compress
            if ($entryValue -cne $manifestValue) {
                $violations += "Catalog entry field '$field' does not match the manifest"
            }
        }
    }
    if ($catalog['metadata']['version'] -ne $Manifest['version']) {
        $violations += "Catalog metadata version '$($catalog['metadata']['version'])' does not match manifest version '$($Manifest['version'])'"
    }

    foreach ($field in $script:RecipeField) {
        if ($entry.Contains($field)) {
            $violations += "Catalog entry declares retired package recipe field '$field'"
        }
    }

    $source = $entry['source']
    if ($source -isnot [string]) {
        $violations += 'Catalog entry source must be a relative path string'
        return $violations
    }
    if ([System.IO.Path]::IsPathRooted($source) -or $source -match '\\' -or $source -match '(^|/)\.\.(/|$)') {
        $violations += "Catalog entry source escapes the repository: $source"
        return $violations
    }

    if (-not (Test-Path -LiteralPath (Join-Path $RepoRoot $source 'plugin.json') -PathType Leaf)) {
        $violations += "Catalog entry source has no plugin manifest: $source/plugin.json"
        return $violations
    }

    return @($violations) + @(Get-PluginComponentCoverageViolations -RepoRoot $RepoRoot -SourcePath $source -Manifest $Manifest)
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

    $metadataViolations = @(Get-PluginMetadataViolations -RepoRoot $RepoRoot)
    if ($metadataViolations.Count -gt 0) {
        return [ordered]@{
            Changed    = $false
            Violations = $metadataViolations
            Manifest   = $null
        }
    }

    $trackedIndex = Get-TrackedPluginIndex -RepoRoot $RepoRoot
    $components = Get-PluginComponentSet -RepoRoot $RepoRoot -TrackedPath $trackedIndex.Paths
    $version = Get-RepositoryVersion -RepoRoot $RepoRoot
    $manifest = New-PluginManifest -RepoRoot $RepoRoot -Component $components -Version $version

    $manifestPath = Join-Path $RepoRoot $script:PluginManifestFile
    $expectedJson = ConvertTo-PluginManifestJson -Manifest $manifest
    $committedRaw = Get-Content -LiteralPath $manifestPath -Raw
    $committedJson = ($committedRaw -replace "`r`n", "`n").TrimEnd("`n") + "`n"

    $violations = @($trackedIndex.Violations)
    $changed = $expectedJson -ne $committedJson

    $violations += @(Get-PluginCatalogViolations -RepoRoot $RepoRoot -Manifest $manifest)

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
