#Requires -Modules Pester
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

<#
.SYNOPSIS
    Regression tests asserting that items tombstoned with `maturity: removed`
    in any `collections/*.collection.yml` do not appear anywhere under
    `plugins/` (file paths or text content).

.DESCRIPTION
    A `maturity: removed` marker is a tombstone: the item must be excluded
    from every plugin output (directory listings, plugin.json manifests,
    READMEs, and any aggregated collection such as hve-core-all). This guard
    catches regressions where a removed item leaks back into generated
    plugin artifacts via aggregation, on-disk discovery, or stale state.
#>

BeforeAll {
    Import-Module powershell-yaml -ErrorAction Stop
    Import-Module (Join-Path $PSScriptRoot '../../collections/Modules/CollectionHelpers.psm1') -Force

    $script:RepoRoot = Resolve-Path (Join-Path $PSScriptRoot '../../..') | Select-Object -ExpandProperty Path
    $script:PluginsRoot = Join-Path $script:RepoRoot 'plugins'
    $script:CollectionsRoot = Join-Path $script:RepoRoot 'collections'

    $script:RemovedItems = @()
    $collectionFiles = Get-ChildItem -Path $script:CollectionsRoot -Filter '*.collection.yml' -File -ErrorAction SilentlyContinue
    foreach ($file in $collectionFiles) {
        $manifest = Get-Content -Path $file.FullName -Raw | ConvertFrom-Yaml
        if ($null -eq $manifest -or $null -eq $manifest.items) { continue }
        foreach ($item in $manifest.items) {
            $effective = Resolve-CollectionItemMaturity -Maturity $item.maturity
            if ($effective -eq 'removed') {
                $script:RemovedItems += [pscustomobject]@{
                    Collection = $file.Name
                    Path       = $item.path
                    Leaf       = Split-Path -Path $item.path -Leaf
                    Kind       = $item.kind
                }
            }
        }
    }

    $script:PluginFiles = @()
    if (Test-Path -Path $script:PluginsRoot) {
        $script:PluginFiles = Get-ChildItem -Path $script:PluginsRoot -Recurse -File -Include '*.md', '*.json', '*.yml', '*.yaml' -ErrorAction SilentlyContinue
    }
}

Describe 'Removed maturity exclusion from plugins' {
    It 'Discovers at least one tombstoned item in collections (sanity check)' {
        if (-not (Test-Path -Path $script:PluginsRoot)) {
            Set-ItResult -Skipped -Because 'plugins/ directory not present'
            return
        }
        $script:RemovedItems.Count | Should -BeGreaterThan 0 -Because 'this test is only meaningful when at least one collection item is tombstoned with maturity: removed'
    }

    It 'Excludes tombstoned items from every generated plugin file' {
        if (-not (Test-Path -Path $script:PluginsRoot)) {
            Set-ItResult -Skipped -Because 'plugins/ directory not present'
            return
        }
        if ($script:RemovedItems.Count -eq 0) {
            Set-ItResult -Skipped -Because 'no removed items declared in any collection manifest'
            return
        }
        if ($script:PluginFiles.Count -eq 0) {
            Set-ItResult -Skipped -Because 'no plugin files discovered under plugins/'
            return
        }

        $leaks = @()
        foreach ($removed in $script:RemovedItems) {
            $patterns = @($removed.Path, $removed.Leaf) | Sort-Object -Unique
            foreach ($pattern in $patterns) {
                $matches = $script:PluginFiles | Select-String -SimpleMatch -Pattern $pattern -ErrorAction SilentlyContinue
                foreach ($match in $matches) {
                    $relative = $match.Path.Substring($script:RepoRoot.Length).TrimStart('\', '/')
                    $leaks += "[$($removed.Collection)] removed '$($removed.Path)' leaks into ${relative}:$($match.LineNumber) (matched '$pattern')"
                }
            }
        }

        if ($leaks.Count -gt 0) {
            $message = "Found $($leaks.Count) leak(s) of removed items in plugin outputs:`n  - " + ($leaks -join "`n  - ")
            throw $message
        }
    }

    It 'Excludes tombstoned items from every plugin directory name' {
        if (-not (Test-Path -Path $script:PluginsRoot)) {
            Set-ItResult -Skipped -Because 'plugins/ directory not present'
            return
        }
        if ($script:RemovedItems.Count -eq 0) {
            Set-ItResult -Skipped -Because 'no removed items declared in any collection manifest'
            return
        }

        $allEntries = Get-ChildItem -Path $script:PluginsRoot -Recurse -ErrorAction SilentlyContinue
        $leaks = @()
        foreach ($removed in $script:RemovedItems) {
            $matches = $allEntries | Where-Object { $_.Name -eq $removed.Leaf }
            foreach ($match in $matches) {
                $relative = $match.FullName.Substring($script:RepoRoot.Length).TrimStart('\', '/')
                $leaks += "[$($removed.Collection)] removed '$($removed.Path)' leaks as path: $relative"
            }
        }

        if ($leaks.Count -gt 0) {
            $message = "Found $($leaks.Count) tombstoned item(s) materialized under plugins/:`n  - " + ($leaks -join "`n  - ")
            throw $message
        }
    }
}
