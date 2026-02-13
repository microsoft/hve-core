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

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
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

        # Validate each item
        $itemCount = $manifest.items.Count
        foreach ($item in $manifest.items) {
            $itemPath = $item.path
            $kind = $item.kind
            $absolutePath = Join-Path -Path $RepoRoot -ChildPath $itemPath

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
