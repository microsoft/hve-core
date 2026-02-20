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

.PARAMETER Channel
    Optional. Release channel controlling eligible item maturities.
    Stable includes only stable items. PreRelease includes stable, preview,
    and experimental. Deprecated is excluded from both channels.

.EXAMPLE
    ./Generate-Plugins.ps1
    # Generates all plugins (default: all + refresh)

.EXAMPLE
    ./Generate-Plugins.ps1 -CollectionIds rpi,github
    # Generates only the rpi and github plugins

.EXAMPLE
    ./Generate-Plugins.ps1 -DryRun
    # Shows what would be generated without making changes

.EXAMPLE
    ./Generate-Plugins.ps1 -Channel Stable
    # Generates plugins with stable-only items

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
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'PreRelease'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Orchestration

function Get-AllowedCollectionMaturities {
    <#
    .SYNOPSIS
        Returns allowed collection item maturities for a channel.

    .PARAMETER Channel
        Release channel ('Stable' or 'PreRelease').

    .OUTPUTS
        [string[]] Allowed maturity values for collection items.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    if ($Channel -eq 'Stable') {
        return @('stable')
    }

    return @('stable', 'preview', 'experimental')
}

function Select-CollectionItemsByChannel {
    <#
    .SYNOPSIS
        Filters collection items by channel using item maturity metadata.

    .PARAMETER Collection
        Collection manifest hashtable.

    .PARAMETER Channel
        Release channel ('Stable' or 'PreRelease').

    .OUTPUTS
        [hashtable] Collection clone with filtered items.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Collection,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    $allowedMaturities = Get-AllowedCollectionMaturities -Channel $Channel
    $filteredItems = @()

    foreach ($item in $Collection.items) {
        $effectiveMaturity = Resolve-CollectionItemMaturity -Maturity $item.maturity
        if ($allowedMaturities -contains $effectiveMaturity) {
            $filteredItems += $item
        }
    }

    $filteredCollection = @{}
    foreach ($key in $Collection.Keys) {
        $filteredCollection[$key] = $Collection[$key]
    }
    $filteredCollection['items'] = $filteredItems

    return $filteredCollection
}

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

    .PARAMETER Channel
        Release channel controlling item maturity eligibility.

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
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'PreRelease'
    )

    $collectionsDir = Join-Path -Path $RepoRoot -ChildPath 'collections'
    $pluginsDir = Join-Path -Path $RepoRoot -ChildPath 'plugins'

    # Read repo version from package.json for plugin manifests
    $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
    $repoVersion = (Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json).version

    # Auto-update hve-core-all collection with discovered artifacts
    $updateResult = Update-HveCoreAllCollection -RepoRoot $RepoRoot -DryRun:$DryRun
    Write-Verbose "hve-core-all updated: $($updateResult.ItemCount) items ($($updateResult.AddedCount) added, $($updateResult.RemovedCount) removed)"

    # Probe symlink capability once for the entire generation run
    $symlinkCapable = Test-SymlinkCapability
    Write-Verbose "Symlink capability: $symlinkCapable ($(if ($symlinkCapable) { 'using symlinks' } else { 'using file copies' }))"

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
    Write-Host "Channel: $Channel"
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

        # Skip deprecated collections
        $collectionMaturity = if ($collection.ContainsKey('maturity') -and $collection.maturity) {
            [string]$collection.maturity
        } else { 'stable' }

        if ($collectionMaturity -eq 'deprecated') {
            Write-Verbose "Skipping deprecated collection: $id"
            continue
        }

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
        $filteredCollection = Select-CollectionItemsByChannel -Collection $collection -Channel $Channel

        $result = Write-PluginDirectory -Collection $filteredCollection `
            -PluginsDir $pluginsDir `
            -RepoRoot $RepoRoot `
            -Version $repoVersion `
            -Maturity $collectionMaturity `
            -DryRun:$DryRun `
            -SymlinkCapable:$symlinkCapable

        $itemCount = $filteredCollection.items.Count
        $totalAgents += $result.AgentCount
        $totalCommands += $result.CommandCount
        $totalInstructions += $result.InstructionCount
        $totalSkills += $result.SkillCount
        $generated++

        Write-Host "  $id ($itemCount items)" -ForegroundColor Green
    }

    # Generate marketplace.json from all collections
    Write-MarketplaceManifest `
        -RepoRoot $RepoRoot `
        -Collections $allCollections `
        -DryRun:$DryRun

    # Fix git index modes for text stubs on non-symlink systems so Linux
    # checkouts materialize real symbolic links instead of plain files.
    if (-not $symlinkCapable) {
        $fixedCount = Repair-PluginSymlinkIndex -PluginsDir $pluginsDir -RepoRoot $RepoRoot -DryRun:$DryRun
        if ($fixedCount -gt 0) {
            Write-Host "  Symlink index: $fixedCount entries fixed (100644 -> 120000)" -ForegroundColor Green
        }
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

function Start-PluginGeneration {
    <#
    .SYNOPSIS
        Entry point for CLI invocation. Returns 0 on success, 1 on failure.

    .PARAMETER ScriptPath
        Absolute path to this script file, used to resolve the repo root.

    .PARAMETER CollectionIds
        Optional collection IDs forwarded to Invoke-PluginGeneration.

    .PARAMETER Refresh
        Forwarded refresh switch.

    .PARAMETER DryRun
        Forwarded dry-run switch.

    .PARAMETER Channel
        Forwarded channel parameter.

    .OUTPUTS
        [int] Exit code: 0 for success, 1 for failure.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $false)]
        [string[]]$CollectionIds,

        [Parameter(Mandatory = $false)]
        [switch]$Refresh,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'PreRelease'
    )

    try {
        # Verify PowerShell-Yaml module
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Resolve paths
        $ScriptDir = Split-Path -Parent $ScriptPath
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
            -DryRun:$DryRun `
            -Channel $Channel

        if (-not $result.Success) {
            throw $result.ErrorMessage
        }

        Write-Host ''
        Write-Host 'Done!' -ForegroundColor Green
        Write-Host "   $($result.PluginCount) plugin(s) generated."

        return 0
    }
    catch {
        Write-Error "Plugin generation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Start-PluginGeneration `
        -ScriptPath $MyInvocation.MyCommand.Path `
        -CollectionIds $CollectionIds `
        -Refresh:$Refresh `
        -DryRun:$DryRun `
        -Channel $Channel)
}
#endregion
