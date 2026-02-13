#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates Copilot CLI plugin directories from collection manifests.

.DESCRIPTION
    Reads collection YAML manifests from the collections/ directory and generates
    plugin directories under plugins/ with symlinks to source artifacts, plugin.json
    manifests, and auto-generated README files.

    Supports generating all plugins or specific collections. Use -Refresh to
    regenerate existing plugins (deletes and recreates).

.PARAMETER CollectionIds
    Optional. Array of collection IDs to generate. Generates all when omitted.

.PARAMETER Refresh
    Optional. Deletes and recreates existing plugin directories.

.PARAMETER DryRun
    Optional. Shows what would be done without making changes.

.EXAMPLE
    ./Generate-Plugins.ps1
    # Generates all plugins (default: all + refresh)

.EXAMPLE
    ./Generate-Plugins.ps1 -CollectionIds rpi,github
    # Generates only the rpi and github plugins

.EXAMPLE
    ./Generate-Plugins.ps1 -DryRun
    # Shows what would be generated without making changes

.NOTES
    Dependencies: PowerShell-Yaml module, scripts/plugins/Modules/PluginHelpers.psm1
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$CollectionIds,

    [Parameter(Mandatory = $false)]
    [switch]$Refresh,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Orchestration

function Invoke-PluginGeneration {
    <#
    .SYNOPSIS
        Orchestrates plugin directory generation from collection manifests.

    .DESCRIPTION
        Loads collection manifests from the collections/ directory, optionally
        filters to specified IDs, and generates plugin directory structures
        under plugins/. Each plugin receives symlinks to source artifacts,
        a plugin.json manifest, and an auto-generated README.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER CollectionIds
        Optional. Array of collection IDs to generate. Generates all when omitted.

    .PARAMETER Refresh
        When specified, removes existing plugin directories before regenerating.

    .PARAMETER DryRun
        When specified, logs actions without creating files or directories.

    .OUTPUTS
        Hashtable with Success, PluginCount, and ErrorMessage keys
        via New-GenerateResult.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string[]]$CollectionIds,

        [Parameter(Mandatory = $false)]
        [switch]$Refresh,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $collectionsDir = Join-Path -Path $RepoRoot -ChildPath 'collections'
    $pluginsDir = Join-Path -Path $RepoRoot -ChildPath 'plugins'

    # Auto-update hve-core-all collection with discovered artifacts
    $updateResult = Update-HveCoreAllCollection -RepoRoot $RepoRoot -DryRun:$DryRun
    Write-Verbose "hve-core-all updated: $($updateResult.ItemCount) items ($($updateResult.AddedCount) added, $($updateResult.RemovedCount) removed)"

    # Load all collection manifests
    $allCollections = Get-AllCollections -CollectionsDir $collectionsDir

    if ($allCollections.Count -eq 0) {
        Write-Warning 'No collection manifests found in collections/'
        return New-GenerateResult -Success $true -PluginCount 0
    }

    # Filter to requested IDs when provided
    if ($CollectionIds -and $CollectionIds.Count -gt 0) {
        $filtered = @($allCollections | Where-Object { $CollectionIds -contains $_.id })
        $missing = @($CollectionIds | Where-Object { $_ -notin ($allCollections | ForEach-Object { $_.id }) })
        if ($missing.Count -gt 0) {
            Write-Warning "Collections not found: $($missing -join ', ')"
        }
        $allCollections = $filtered
    }

    Write-Host "`n=== Plugin Generation ===" -ForegroundColor Cyan
    Write-Host "Collections: $($allCollections.Count)"
    Write-Host "Plugins dir: $pluginsDir"
    if ($DryRun) {
        Write-Host '[DRY RUN] No changes will be made' -ForegroundColor Yellow
    }

    $generated = 0
    $totalAgents = 0
    $totalCommands = 0
    $totalInstructions = 0
    $totalSkills = 0

    foreach ($collection in $allCollections) {
        $id = $collection.id
        $pluginDir = Join-Path -Path $pluginsDir -ChildPath $id

        # Refresh: remove existing plugin directory
        if ($Refresh -and (Test-Path -Path $pluginDir)) {
            if ($DryRun) {
                Write-Host "  [DRY RUN] Would remove $pluginDir" -ForegroundColor Yellow
            }
            else {
                Remove-Item -Path $pluginDir -Recurse -Force
                Write-Verbose "Removed existing plugin directory: $pluginDir"
            }
        }

        # Generate plugin directory structure
        $result = Write-PluginDirectory -Collection $collection `
            -PluginsDir $pluginsDir `
            -RepoRoot $RepoRoot `
            -DryRun:$DryRun

        $itemCount = $collection.items.Count
        $totalAgents += $result.AgentCount
        $totalCommands += $result.CommandCount
        $totalInstructions += $result.InstructionCount
        $totalSkills += $result.SkillCount
        $generated++

        Write-Host "  $id ($itemCount items)" -ForegroundColor Green
    }

    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    Write-Host "  Plugins generated: $generated"
    Write-Host "  Agents: $totalAgents"
    Write-Host "  Commands: $totalCommands"
    Write-Host "  Instructions: $totalInstructions"
    Write-Host "  Skills: $totalSkills"

    return New-GenerateResult -Success $true -PluginCount $generated
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

        Write-Host 'HVE Core Plugin Generator' -ForegroundColor Cyan
        Write-Host '==========================' -ForegroundColor Cyan

        # Default to all + refresh when no args
        $effectiveRefresh = $Refresh
        if (-not $CollectionIds -and -not $Refresh.IsPresent -and -not $DryRun.IsPresent) {
            $effectiveRefresh = [switch]::new($true)
        }

        $result = Invoke-PluginGeneration `
            -RepoRoot $RepoRoot `
            -CollectionIds $CollectionIds `
            -Refresh:$effectiveRefresh `
            -DryRun:$DryRun

        if (-not $result.Success) {
            throw $result.ErrorMessage
        }

        Write-Host ''
        Write-Host 'Done!' -ForegroundColor Green
        Write-Host "   $($result.PluginCount) plugin(s) generated."

        exit 0
    }
    catch {
        Write-Error "Plugin generation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
