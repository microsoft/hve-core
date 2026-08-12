# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Copies selected HVE-Core components into a target repository.
.DESCRIPTION
    Maps marketplace component paths to their canonical .github locations,
    copies files and complete skill directories under TargetRoot without
    flattening paths, and writes the schema version 2 .hve-tracking.json
    manifest. Membership, path-safety, and manifest-schema checks all run
    before the first write.
.PARAMETER HveCoreBasePath
    Root path of the local HVE-Core clone used as the copy source.
.PARAMETER TargetRoot
    Root of the repository that receives the copied components.
.PARAMETER PackageName
    Marketplace package name whose recipe declares the installable components.
.PARAMETER SelectionName
    Marketplace profile name that produced the selection, or 'custom'.
.PARAMETER Component
    Marketplace component paths such as agents/hve-core/rpi-agent.md or skills/rpi/rpi-plan.
.PARAMETER ReportOnly
    When set, runs preflight and reports component maturity and collisions without writing.
.PARAMETER KeepExisting
    When set, components listed in Collisions are left untouched.
.PARAMETER Collisions
    Component paths that already exist in the target and may conflict.
.EXAMPLE
    ./scripts/component-copy.ps1 -HveCoreBasePath ../hve-core -TargetRoot . -PackageName hve-core-all -SelectionName starter -Component @('agents/hve-core/rpi-agent.md', 'skills/rpi/rpi-plan')
.OUTPUTS
    Per-component copy status and manifest creation confirmation.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$HveCoreBasePath,

    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$TargetRoot,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$PackageName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$SelectionName,

    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string[]]$Component,

    [Parameter()]
    [switch]$ReportOnly,

    [Parameter()]
    [switch]$KeepExisting,

    [Parameter()]
    [string[]]$Collisions = @()
)

$ErrorActionPreference = 'Stop'

# Ordinal ordering keeps PowerShell output and manifests byte-comparable with the
# Bash implementation, which sorts under LC_ALL=C.
function ConvertTo-OrdinalOrder {
    param([string[]]$Value)
    $sorted = [string[]]@($Value)
    [array]::Sort($sorted, [System.StringComparer]::Ordinal)
    return , $sorted
}

# ConvertFrom-Json coerces ISO 8601 strings to DateTime, so timestamps read back
# from an existing manifest are re-serialized in the shared string format.
function ConvertTo-InstallerTimestamp {
    param($Value)
    if ($Value -is [datetime]) { return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [datetimeoffset]) { return ([datetimeoffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return [string]$Value
}

# Containment is decided by resolved path and real filesystem state, never by the
# shape of a joined string. A prefix test alone is close to a tautology because
# the candidate was built by joining onto the base, and it also admits a sibling
# directory whose name merely starts with the base name.
#
# ReparsePoint is the portable primitive here: on Windows it covers both symbolic
# links and directory junctions, and on other platforms PowerShell reports POSIX
# symlinks with the same attribute. Resolve-Path is deliberately not used, because
# it resolves links rather than reporting them and cannot inspect a path whose
# leaf does not exist yet.
function Assert-WithinTargetRoot {
    param(
        [Parameter(Mandatory)][string]$Base,
        [Parameter(Mandatory)][string]$RelativePath,
        [Parameter(Mandatory)][string]$Component
    )

    $separator = [System.IO.Path]::DirectorySeparatorChar
    $full = [System.IO.Path]::GetFullPath((Join-Path $Base $RelativePath))
    if (-not ($full + $separator).StartsWith(($Base.TrimEnd($separator) + $separator), [System.StringComparison]::Ordinal)) {
        throw "Component '$Component' resolves outside the target root."
    }

    $current = $Base
    foreach ($segment in ($RelativePath -split '[\\/]')) {
        if ([string]::IsNullOrEmpty($segment)) { continue }
        $current = Join-Path $current $segment
        if (-not (Test-Path -LiteralPath $current)) { break }
        $entry = Get-Item -LiteralPath $current -Force
        if ($entry.Attributes -band [System.IO.FileAttributes]::ReparsePoint) {
            throw "Component '$Component' resolves through a link at '$current', which may write outside the target root."
        }
    }

    return $full
}

$schemaVersion = 2
# Local environment, cache, and test directories are never distributed, matching
# the extension skill-materialization exclusions.
$excludedSkillPath = '(^|/)(tests|\.venv|\.hypothesis|node_modules|__pycache__|\.ruff_cache|\.pytest_cache)(/|$)|\.pyc$'
$fieldMap = [ordered]@{
    agents   = @{ Kind = 'agent'; Root = '.github/agents'; CatalogRoot = 'agents'; PackageSuffix = '.md'; SourceSuffix = '.agent.md' }
    commands = @{ Kind = 'prompt'; Root = '.github/prompts'; CatalogRoot = 'prompts'; PackageSuffix = '.md'; SourceSuffix = '.prompt.md' }
    rules    = @{ Kind = 'instruction'; Root = '.github/instructions'; CatalogRoot = 'instructions'; PackageSuffix = '.instructions.md'; SourceSuffix = '.instructions.md' }
    skills   = @{ Kind = 'skill'; Root = '.github/skills'; CatalogRoot = 'skills'; PackageSuffix = ''; SourceSuffix = '' }
}

# The marketplace catalog stores canonical source identities while installer input
# and manifests use package form. A path whose root is outside the four installable
# fields, such as hooks/, carries through unprojected so catalog load never fails.
function ConvertTo-PackageComponentPath {
    param([string]$CatalogPath)

    $segments = $CatalogPath -split '/', 2
    if ($segments.Count -lt 2) { return $CatalogPath }
    $catalogRoot = $segments[0]
    $relative = $segments[1]
    foreach ($field in $fieldMap.Keys) {
        $descriptor = $fieldMap[$field]
        if (-not [string]::Equals($descriptor.CatalogRoot, $catalogRoot, [System.StringComparison]::Ordinal)) { continue }
        if ($descriptor.SourceSuffix) {
            if (-not $relative.EndsWith($descriptor.SourceSuffix, [System.StringComparison]::Ordinal)) { return $CatalogPath }
            $relative = "$($relative.Substring(0, $relative.Length - $descriptor.SourceSuffix.Length))$($descriptor.PackageSuffix)"
        }
        return "$field/$relative"
    }
    return $CatalogPath
}

$sourceRoot = (Resolve-Path -LiteralPath $HveCoreBasePath).Path
$targetBase = (Resolve-Path -LiteralPath $TargetRoot).Path
$manifestPath = Join-Path $targetBase '.hve-tracking.json'

$catalogPath = Join-Path $sourceRoot '.github/plugin/marketplace.json'
if (-not (Test-Path -LiteralPath $catalogPath -PathType Leaf)) {
    throw "Marketplace catalog not found: $catalogPath"
}
$catalog = Get-Content -LiteralPath $catalogPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$packageEntries = @(@($catalog['plugins']) | Where-Object {
        [string]::Equals([string]$_['name'], $PackageName, [System.StringComparison]::Ordinal)
    })
if ($packageEntries.Count -eq 0) {
    throw "Marketplace catalog '$catalogPath' declares no package named '$PackageName'."
}
if ($packageEntries.Count -gt 1) {
    throw "Marketplace catalog '$catalogPath' declares $($packageEntries.Count) packages named '$PackageName'."
}
$entry = $packageEntries[0]
$componentMaturity = @{}
if ($entry['x-hve'] -is [System.Collections.IDictionary] -and $entry['x-hve']['componentMaturity'] -is [System.Collections.IDictionary]) {
    foreach ($key in $entry['x-hve']['componentMaturity'].Keys) {
        $maturityComponent = ConvertTo-PackageComponentPath -CatalogPath ([string]$key)
        $componentMaturity[$maturityComponent] = [string]$entry['x-hve']['componentMaturity'][$key]
    }
}
$membership = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($field in $fieldMap.Keys) {
    foreach ($catalogPathValue in @($entry[$field])) {
        if ([string]::IsNullOrWhiteSpace([string]$catalogPathValue)) { continue }
        [void]$membership.Add((ConvertTo-PackageComponentPath -CatalogPath ([string]$catalogPathValue)))
    }
}
if ($membership.Count -eq 0) {
    throw "Marketplace package '$PackageName' in '$catalogPath' declares no installable components."
}

# An unsupported manifest must fail before the target is touched. Version 1 has
# no upgrade path because it records flattened agent paths and package identity.
$existingFiles = @{}
if (Test-Path -LiteralPath $manifestPath -PathType Leaf) {
    $existing = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    $existingVersion = if ($existing.Contains('schemaVersion')) { $existing['schemaVersion'] } else { 'missing' }
    if ($existingVersion -ne $schemaVersion) {
        throw "Unsupported .hve-tracking.json schemaVersion '$existingVersion' (expected $schemaVersion). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
    }
    if ($existing['files'] -is [System.Collections.IDictionary]) {
        foreach ($key in $existing['files'].Keys) {
            $existingEntry = $existing['files'][$key]
            $preserved = [ordered]@{
                component = [string]$existingEntry['component']
                kind      = [string]$existingEntry['kind']
                maturity  = [string]$existingEntry['maturity']
                version   = [string]$existingEntry['version']
                sha256    = [string]$existingEntry['sha256']
                status    = [string]$existingEntry['status']
            }
            if ($existingEntry.Contains('ejectedAt')) {
                $preserved['ejectedAt'] = ConvertTo-InstallerTimestamp -Value $existingEntry['ejectedAt']
            }
            $existingFiles[[string]$key] = $preserved
        }
    }
}

$keptComponents = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
if ($KeepExisting) {
    foreach ($kept in $Collisions) { [void]$keptComponents.Add([string]$kept) }
}

# Preflight: normalize, bound, and resolve every component before any write.
$plan = [System.Collections.Generic.List[hashtable]]::new()
$seenComponents = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
$seenTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($raw in $Component) {
    $candidate = ([string]$raw).Trim()
    if ([string]::IsNullOrWhiteSpace($candidate)) { throw 'Component path must be a non-empty string.' }
    if ($candidate -match '\p{C}') { throw "Component path '$candidate' must not contain control characters." }
    if ($candidate -match '\\') { throw "Component path '$candidate' must use forward slashes." }
    if ($candidate -match '^/' -or $candidate -match '^[A-Za-z]:') { throw "Component path '$candidate' must be relative to the package root." }
    $normalized = $candidate.TrimEnd('/')
    foreach ($segment in ($normalized -split '/')) {
        if ([string]::IsNullOrEmpty($segment)) { throw "Component path '$candidate' must not contain empty path segments." }
        if ($segment -eq '.' -or $segment -eq '..') { throw "Component path '$candidate' must not contain relative path segments." }
    }

    $field = ($normalized -split '/', 2)[0]
    if (-not $fieldMap.Contains($field)) {
        throw "Component path '$normalized' must start with one of: $($fieldMap.Keys -join ', ')."
    }
    if (-not $membership.Contains($normalized)) {
        throw "Component '$normalized' is not declared membership of the '$PackageName' marketplace recipe."
    }
    if (-not $seenComponents.Add($normalized)) { continue }

    $descriptor = $fieldMap[$field]
    $relative = $normalized.Substring($field.Length + 1)
    if ($descriptor.PackageSuffix) {
        if (-not $relative.EndsWith($descriptor.PackageSuffix, [System.StringComparison]::Ordinal)) {
            throw "Component path '$normalized' must end with '$($descriptor.PackageSuffix)'."
        }
        $relative = "$($relative.Substring(0, $relative.Length - $descriptor.PackageSuffix.Length))$($descriptor.SourceSuffix)"
    }
    $sourceRelative = "$($descriptor.Root)/$relative"
    $sourceFull = Join-Path $sourceRoot $sourceRelative
    # Preflight bounds the component; the resolved path is recomputed at the
    # write site, so only the assertion's failure behaviour is needed here.
    Assert-WithinTargetRoot -Base $targetBase -RelativePath $sourceRelative -Component $normalized | Out-Null
    if (-not $seenTargets.Add($sourceRelative)) {
        throw "Component '$normalized' resolves to duplicate target '$sourceRelative'."
    }

    $componentFiles = [System.Collections.Generic.List[string]]::new()
    if ($descriptor.Kind -eq 'skill') {
        if (-not (Test-Path -LiteralPath $sourceFull -PathType Container)) {
            throw "Skill component '$normalized' has no source directory at '$sourceRelative'."
        }
        $skillFiles = ConvertTo-OrdinalOrder -Value @(Get-ChildItem -LiteralPath $sourceFull -Recurse -File -Force |
            Where-Object { -not ($_.Attributes -band [System.IO.FileAttributes]::ReparsePoint) } |
            ForEach-Object {
                $withinSkill = ($_.FullName.Substring($sourceFull.Length) -replace '\\', '/').TrimStart('/')
                "$sourceRelative/$withinSkill"
            } | Where-Object { $_ -notmatch $excludedSkillPath })
        if ($skillFiles.Count -eq 0) {
            throw "Skill component '$normalized' has no files at '$sourceRelative'."
        }
        foreach ($file in $skillFiles) { $componentFiles.Add($file) }
    }
    else {
        if (-not (Test-Path -LiteralPath $sourceFull -PathType Leaf)) {
            throw "Component '$normalized' has no source file at '$sourceRelative'."
        }
        $componentFiles.Add($sourceRelative)
    }

    $maturity = if ($componentMaturity.ContainsKey($normalized)) { $componentMaturity[$normalized] } else { 'stable' }
    $plan.Add(@{
            Component = $normalized
            Kind      = $descriptor.Kind
            Maturity  = $maturity
            Target    = $sourceRelative
            Files     = [string[]]$componentFiles.ToArray()
        })
}

$version = (Get-Content -LiteralPath (Join-Path $sourceRoot 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json).version
$componentOrder = ConvertTo-OrdinalOrder -Value @($plan | ForEach-Object { $_.Component })
$planByComponent = @{}
foreach ($item in $plan) { $planByComponent[$item.Component] = $item }

if ($ReportOnly) {
    $collisionComponents = [System.Collections.Generic.List[string]]::new()
    $collisionTargets = [System.Collections.Generic.List[string]]::new()
    foreach ($componentPath in $componentOrder) {
        $item = $planByComponent[$componentPath]
        $exists = Test-Path -LiteralPath (Join-Path $targetBase $item.Target)
        if ($exists) {
            $collisionComponents.Add($item.Component)
            $collisionTargets.Add($item.Target)
        }
        Write-Host "COMPONENT=$($item.Component)|KIND=$($item.Kind)|MATURITY=$($item.Maturity)|TARGET=$($item.Target)|EXISTS=$($exists.ToString().ToLower())"
    }
    if ($collisionComponents.Count -gt 0) {
        Write-Host 'COLLISIONS_DETECTED=true'
        Write-Host "COLLISION_COMPONENTS=$($collisionComponents -join ',')"
        Write-Host "COLLISION_TARGETS=$($collisionTargets -join ',')"
    }
    else {
        Write-Host 'COLLISIONS_DETECTED=false'
    }
    return
}

$files = [ordered]@{}
foreach ($existingPath in (ConvertTo-OrdinalOrder -Value @($existingFiles.Keys))) {
    $files[$existingPath] = $existingFiles[$existingPath]
}
foreach ($componentPath in $componentOrder) {
    $item = $planByComponent[$componentPath]
    if ($keptComponents.Contains($item.Component)) {
        foreach ($file in $item.Files) {
            if ($existingFiles.ContainsKey($file)) { $files[$file] = $existingFiles[$file] }
        }
        Write-Host "⏭️ Kept existing: $($item.Component)"
        continue
    }

    foreach ($file in $item.Files) {
        if ($existingFiles.ContainsKey($file) -and $existingFiles[$file]['status'] -eq 'ejected') {
            $files[$file] = $existingFiles[$file]
            Write-Host "🔒 Skipped ejected: $file"
            continue
        }
        $sourceFile = Join-Path $sourceRoot $file
        # Re-verified immediately before the write. Preflight ran earlier, so a
        # link planted in between would otherwise be honoured by Copy-Item. This
        # narrows that window; it does not make the check and the write atomic.
        $targetFile = Assert-WithinTargetRoot -Base $targetBase -RelativePath $file -Component $item.Component
        $targetParent = Split-Path -Parent $targetFile
        if (-not (Test-Path -LiteralPath $targetParent -PathType Container)) {
            New-Item -ItemType Directory -Path $targetParent -Force | Out-Null
        }
        Copy-Item -LiteralPath $sourceFile -Destination $targetFile -Force
        $files[$file] = [ordered]@{
            component = $item.Component
            kind      = $item.Kind
            maturity  = $item.Maturity
            version   = $version
            sha256    = (Get-FileHash -LiteralPath $targetFile -Algorithm SHA256).Hash.ToLower()
            status    = 'managed'
        }
    }
    Write-Host "✅ Copied $($item.Component) → $($item.Target)"
}

$installedComponents = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
foreach ($fileEntry in $files.Values) {
    $ownedComponent = [string]$fileEntry['component']
    if ($membership.Contains($ownedComponent)) {
        [void]$installedComponents.Add($ownedComponent)
    }
}
$installedComponentOrder = ConvertTo-OrdinalOrder -Value @($installedComponents)

$manifest = [ordered]@{
    schemaVersion = $schemaVersion
    source        = 'microsoft/hve-core'
    version       = $version
    installed     = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    selection     = [ordered]@{
        package    = $PackageName
        profile    = $SelectionName
        components = $installedComponentOrder
    }
    files         = $files
}
$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "✅ Created .hve-tracking.json"
