# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# PluginCatalog.psm1
# Purpose: Resolve checked-in marketplace locators for validation and versioning.
#Requires -Version 7.4

function Get-PluginCatalog {
    <#
    .SYNOPSIS
        Reads a non-empty catalog of uniquely named local plugin roots.
    .DESCRIPTION
        Normalizes relative source aliases and rejects links in a manifest path
        before callers read or write it. The root All plugin is required but
        has no special position in the catalog.
    .PARAMETER RepoRoot
        Root directory of the repository.
    .OUTPUTS
        [System.Collections.IDictionary] Catalog version, resolved entries in
        catalog order, and any locator violations.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.IDictionary])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $result = [ordered]@{ Version = $null; Entries = @(); Violations = @() }
    $catalogFile = '.github/plugin/marketplace.json'
    $path = Join-Path $RepoRoot $catalogFile
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        $result.Violations += "Marketplace catalog not found: $catalogFile"
        return $result
    }

    $catalog = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json -AsHashtable -NoEnumerate
    if ($catalog -isnot [System.Collections.IDictionary] -or $catalog.plugins -isnot [array] -or $catalog.plugins.Count -eq 0) {
        $result.Violations += 'Marketplace catalog plugins must be a non-empty array'
        return $result
    }

    $result.Version = $catalog.metadata.version
    $names = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $sources = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    $root = [System.IO.Path]::GetFullPath($RepoRoot)
    :entries foreach ($entry in $catalog.plugins) {
        if ($entry -isnot [System.Collections.IDictionary] -or $entry.name -isnot [string] -or [string]::IsNullOrWhiteSpace($entry.name)) {
            $result.Violations += 'Catalog entry must be an object with a non-empty name'
            continue
        }
        if (-not $names.Add($entry.name)) {
            $result.Violations += "Duplicate catalog entry name: $($entry.name)"
        }
        $source = $entry.source
        if ($source -isnot [string] -or [string]::IsNullOrWhiteSpace($source)) {
            $result.Violations += "Catalog entry source must be a relative path string: $($entry.name)"
            continue
        }
        if ([System.IO.Path]::IsPathRooted($source) -or $source -match '^[A-Za-z]:|\\|(^|/)\.\.(/|$)') {
            $result.Violations += "Catalog entry source escapes the repository: $source"
            continue
        }

        $file = [System.IO.Path]::GetFullPath((Join-Path $root $source 'plugin.json'))
        $relative = [System.IO.Path]::GetRelativePath($root, $file).Replace('\', '/')
        $source = [System.IO.Path]::GetRelativePath($root, [System.IO.Path]::GetDirectoryName($file)).Replace('\', '/')
        if (-not $sources.Add($source)) {
            $result.Violations += "Duplicate catalog entry source: $source"
        }

        $current = $root
        foreach ($segment in $relative.Split('/')) {
            $current = Join-Path $current $segment
            $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
            if (-not $item) {
                $result.Violations += "Catalog entry source has no plugin manifest: $relative"
                continue entries
            }
            if ($item.LinkType) {
                $result.Violations += "Catalog entry manifest path contains a symbolic link: $relative"
                continue entries
            }
        }
        if ($item -isnot [System.IO.FileInfo]) {
            $result.Violations += "Catalog entry source has no plugin manifest: $relative"
            continue
        }
        $result.Entries += [ordered]@{ Locator = $entry; Source = $source; ManifestPath = $relative }
    }
    if (-not $sources.Contains('.')) {
        $result.Violations += 'Marketplace catalog is missing the root plugin locator'
    }
    return $result
}

Export-ModuleMember -Function Get-PluginCatalog
