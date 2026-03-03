#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates collection manifests for Copilot CLI plugin generation.

.DESCRIPTION
    Reads all .collection.yml files from collections/ and validates structure,
    required fields, artifact path existence, and kind-suffix consistency.

.EXAMPLE
    ./Validate-Collections.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/CollectionHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Validation Helpers

function Test-KindSuffix {
    <#
    .SYNOPSIS
        Validates that an item path matches its declared kind suffix.

    .DESCRIPTION
        Checks kind-suffix consistency: agent files end with .agent.md,
        prompt files with .prompt.md, instruction files with .instructions.md,
        and skill items are directories containing a SKILL.md file.

    .PARAMETER Kind
        The declared artifact kind (agent, prompt, instruction, skill).

    .PARAMETER ItemPath
        The relative path from the collection manifest.

    .PARAMETER RepoRoot
        Absolute path to the repository root for skill directory checks.

    .OUTPUTS
        [string] Error message if validation fails, empty string if valid.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$ItemPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    switch ($Kind) {
        'agent' {
            if ($ItemPath -notmatch '\.agent\.md$') {
                return "kind 'agent' expects *.agent.md but got '$ItemPath'"
            }
        }
        'prompt' {
            if ($ItemPath -notmatch '\.prompt\.md$') {
                return "kind 'prompt' expects *.prompt.md but got '$ItemPath'"
            }
        }
        'instruction' {
            if ($ItemPath -notmatch '\.instructions\.md$') {
                return "kind 'instruction' expects *.instructions.md but got '$ItemPath'"
            }
        }
        'skill' {
            $skillDir = Join-Path -Path $RepoRoot -ChildPath $ItemPath
            $skillFile = Join-Path -Path $skillDir -ChildPath 'SKILL.md'
            if (-not (Test-Path -Path $skillFile)) {
                return "kind 'skill' expects SKILL.md inside '$ItemPath'"
            }
        }
    }

    return ''
}

function Get-CollectionItemKey {
    <#
    .SYNOPSIS
        Builds a stable uniqueness key for collection items.

    .DESCRIPTION
        Uses kind and path to identify the same artifact across collections.

    .PARAMETER Kind
        Artifact kind.

    .PARAMETER ItemPath
        Artifact path.

    .OUTPUTS
        [string] Composite key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$ItemPath
    )

    return "$Kind|$ItemPath"
}

#endregion Validation Helpers

#region Orchestration

function Invoke-CollectionValidation {
    <#
    .SYNOPSIS
        Validates all collection manifests for correctness.

    .DESCRIPTION
        Scans the collections/ directory for .collection.yml files and validates
        each manifest for required fields (id, name, description, items), id
        format, artifact path existence, kind-suffix consistency, and duplicate
        ids across collections.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .OUTPUTS
        Hashtable with Success bool, ErrorCount int, and CollectionCount int.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $collectionsDir = Join-Path -Path $RepoRoot -ChildPath 'collections'
    $collectionFiles = Get-ChildItem -Path $collectionsDir -Filter '*.collection.yml' -File

    if ($collectionFiles.Count -eq 0) {
        Write-Warning 'No collection manifests found in collections/'
        return @{ Success = $true; ErrorCount = 0; CollectionCount = 0 }
    }

    Write-Host 'Validating collections...'

    $errorCount = 0
    $seenIds = @{}
    $validatedCount = 0
    $allowedMaturities = @('stable', 'preview', 'experimental', 'deprecated')
    $canonicalCollectionId = 'hve-core-all'
    $itemOccurrences = @{}

    foreach ($file in $collectionFiles) {
        $manifest = Get-CollectionManifest -CollectionPath $file.FullName
        $fileErrors = @()

        # Required fields
        $requiredFields = @('id', 'name', 'description', 'items')
        foreach ($field in $requiredFields) {
            if (-not $manifest.ContainsKey($field) -or $null -eq $manifest[$field]) {
                $fileErrors += "missing required field '$field'"
            }
        }

        # Skip further checks if required fields are absent
        if ($fileErrors.Count -gt 0) {
            foreach ($err in $fileErrors) {
                Write-Host "    x $($file.Name): $err" -ForegroundColor Red
            }
            $errorCount += $fileErrors.Count
            continue
        }

        $id = $manifest.id

        # Id format
        if ($id -notmatch '^[a-z0-9-]+$') {
            $fileErrors += "id '$id' must match ^[a-z0-9-]+$"
        }

        # Duplicate id check
        if ($seenIds.ContainsKey($id)) {
            $fileErrors += "duplicate id '$id' (also in $($seenIds[$id]))"
        }
        else {
            $seenIds[$id] = $file.Name
        }

        # Validate collection-level maturity if present
        if ($manifest.ContainsKey('maturity') -and -not [string]::IsNullOrWhiteSpace([string]$manifest.maturity)) {
            $collMaturity = [string]$manifest.maturity
            if ($allowedMaturities -notcontains $collMaturity) {
                $fileErrors += "invalid collection maturity '$collMaturity' (allowed: $($allowedMaturities -join ', '))"
            }
        }

        # Validate each item
        $itemCount = $manifest.items.Count
        foreach ($item in $manifest.items) {
            $itemPath = $item.path
            $kind = $item.kind
            $absolutePath = Join-Path -Path $RepoRoot -ChildPath $itemPath
            $itemMaturity = $null
            if ($item.ContainsKey('maturity')) {
                $itemMaturity = [string]$item.maturity
            }
            $effectiveMaturity = Resolve-CollectionItemMaturity -Maturity $itemMaturity

            # Repo-specific path exclusion
            if (Test-HveCoreRepoRelativePath -Path $itemPath) {
                $fileErrors += "repo-specific path not allowed in collections: $itemPath (root-level artifacts under .github/{type}/ are excluded from distribution)"
            }

            # Path existence
            if (-not (Test-Path -Path $absolutePath)) {
                $fileErrors += "path not found: $itemPath"
            }

            # Kind-suffix consistency
            if ($kind) {
                $suffixError = Test-KindSuffix -Kind $kind -ItemPath $itemPath -RepoRoot $RepoRoot
                if ($suffixError) {
                    $fileErrors += $suffixError
                }
            }
            else {
                $fileErrors += "item missing 'kind': $itemPath"
            }

            if (-not [string]::IsNullOrWhiteSpace($itemMaturity) -and ($allowedMaturities -notcontains $itemMaturity)) {
                $fileErrors += "invalid maturity '$itemMaturity' for item '$itemPath' (allowed: $($allowedMaturities -join ', '))"
            }

            if (-not [string]::IsNullOrWhiteSpace($itemPath) -and -not [string]::IsNullOrWhiteSpace($kind)) {
                $itemKey = Get-CollectionItemKey -Kind $kind -ItemPath $itemPath
                if (-not $itemOccurrences.ContainsKey($itemKey)) {
                    $itemOccurrences[$itemKey] = @()
                }

                $itemOccurrences[$itemKey] += @{
                    CollectionId = $id
                    CollectionFile = $file.Name
                    Kind = $kind
                    Path = $itemPath
                    Maturity = $effectiveMaturity
                }
            }

            # Informational log for instruction items
            if ($kind -eq 'instruction') {
                Write-Verbose "  instruction: $itemPath"
            }
        }

        if ($fileErrors.Count -gt 0) {
            Write-Host "  FAIL $id ($itemCount items) - $($fileErrors.Count) error(s)" -ForegroundColor Red
            foreach ($err in $fileErrors) {
                Write-Host "      $err" -ForegroundColor Red
            }
            $errorCount += $fileErrors.Count
        }
        else {
            Write-Host "  OK $id ($itemCount items)"
        }

        $validatedCount++
    }

    # Duplicate artifact key detection across all collections
    $artifactKeyMap = @{}
    foreach ($itemKey in $itemOccurrences.Keys) {
        $occurrences = $itemOccurrences[$itemKey]
        $first = $occurrences[0]
        $artifactKey = Get-CollectionArtifactKey -Kind $first.Kind -Path $first.Path
        $compositeKey = "$($first.Kind)|$artifactKey"

        if (-not $artifactKeyMap.ContainsKey($compositeKey)) {
            $artifactKeyMap[$compositeKey] = @()
        }
        if ($artifactKeyMap[$compositeKey] -notcontains $first.Path) {
            $artifactKeyMap[$compositeKey] += $first.Path
        }
    }

    foreach ($compositeKey in $artifactKeyMap.Keys) {
        $paths = $artifactKeyMap[$compositeKey]
        if ($paths.Count -gt 1) {
            $kindLabel = ($compositeKey -split '\|')[0]
            $nameLabel = ($compositeKey -split '\|')[1]
            $pathList = ($paths | Sort-Object) -join ', '
            Write-Host "  FAIL duplicate $kindLabel artifact key '$nameLabel' found at distinct paths: $pathList" -ForegroundColor Red
            $errorCount++
        }
    }

    foreach ($itemKey in $itemOccurrences.Keys) {
        $occurrences = $itemOccurrences[$itemKey]
        if ($occurrences.Count -le 1) {
            continue
        }

        $canonicalMatches = @($occurrences | Where-Object { $_.CollectionId -eq $canonicalCollectionId })
        if ($canonicalMatches.Count -eq 0) {
            $sharedCollections = ($occurrences | ForEach-Object { $_.CollectionId } | Sort-Object -Unique) -join ', '
            Write-Host "  FAIL shared item '$itemKey' exists in collections [$sharedCollections] but has no canonical entry in '$canonicalCollectionId'" -ForegroundColor Red
            $errorCount++
            continue
        }

        $canonical = $canonicalMatches[0]
        foreach ($occurrence in $occurrences) {
            if ($occurrence.CollectionId -eq $canonicalCollectionId) {
                continue
            }

            if ($occurrence.Maturity -ne $canonical.Maturity) {
                Write-Host "  FAIL maturity conflict for '$itemKey': canonical '$canonicalCollectionId'='$($canonical.Maturity)', '$($occurrence.CollectionId)'='$($occurrence.Maturity)'" -ForegroundColor Red
                $errorCount++
            }
        }
    }

    Write-Host ''
    Write-Host "$validatedCount collections validated, $errorCount errors"

    return @{
        Success         = ($errorCount -eq 0)
        ErrorCount      = $errorCount
        CollectionCount = $validatedCount
    }
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        # Verify PowerShell-Yaml module
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Resolve paths
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName

        $result = Invoke-CollectionValidation -RepoRoot $RepoRoot

        if (-not $result.Success) {
            throw "Validation failed with $($result.ErrorCount) error(s)."
        }

        exit 0
    }
    catch {
        Write-Error "Collection validation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
