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
Import-Module (Join-Path $PSScriptRoot '../collections/Modules/CollectionHelpers.psm1') -Force
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

    if ($allCollections.Count -eq 0) {
        Write-Warning 'No collections to process after filtering'
        return New-GenerateResult -Success $true -PluginCount 0
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

        # Generate plugin directory structure (overwrites in place)
        $filteredCollection = Select-CollectionItemsByChannel -Collection $collection -Channel $Channel

        $result = Write-PluginDirectory -Collection $filteredCollection `
            -PluginsDir $pluginsDir `
            -RepoRoot $RepoRoot `
            -Version $repoVersion `
            -Maturity $collectionMaturity `
            -DryRun:$DryRun `
            -SymlinkCapable:$symlinkCapable

        # Orphan cleanup in Refresh mode
        if ($Refresh -and (Test-Path -LiteralPath $pluginDir)) {
            $generatedFiles = $result.GeneratedFiles
            $existingFiles = [System.Collections.Generic.List[string]]::new()
            $scanQueue = [System.Collections.Generic.Queue[string]]::new()
            $scanQueue.Enqueue($pluginDir)
            while ($scanQueue.Count -gt 0) {
                $currentDir = $scanQueue.Dequeue()
                foreach ($entry in Get-ChildItem -LiteralPath $currentDir -Force) {
                    if ($entry.PSIsContainer -and -not $entry.LinkType) {
                        $scanQueue.Enqueue($entry.FullName)
                    }
                    else {
                        $existingFiles.Add($entry.FullName)
                    }
                }
            }
            foreach ($existingFile in $existingFiles) {
                if (-not $generatedFiles.Contains($existingFile)) {
                    if ($DryRun) {
                        Write-Host "  [DRY RUN] Would remove orphan: $existingFile" -ForegroundColor Yellow
                    }
                    else {
                        Remove-Item -LiteralPath $existingFile -Force -ErrorAction Stop
                        Write-Verbose "Removed orphan file: $existingFile"
                    }
                }
            }
            # Remove empty directories bottom-up
            if (-not $DryRun) {
                Get-ChildItem -LiteralPath $pluginDir -Recurse -Directory |
                    Where-Object { -not $_.LinkType } |
                    Sort-Object { $_.FullName.Length } -Descending |
                    Where-Object { @(Get-ChildItem -LiteralPath $_.FullName).Count -eq 0 } |
                    ForEach-Object {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                        Write-Verbose "Removed empty directory: $($_.FullName)"
                    }
            }
        }

        #region Update collection.md artifact tables
        if (-not $DryRun) {
            $collectionMdPath = Join-Path $collectionsDir "$id.collection.md"
            if (Test-Path $collectionMdPath) {
                $bodyContent = Get-Content -Path $collectionMdPath -Raw
                $parsed = Split-CollectionMdByMarkers -Content $bodyContent

                if ($parsed.HasMarkers) {
                    $agents = @()
                    $prompts = @()
                    $instructions = @()
                    $skills = @()

                    foreach ($item in $filteredCollection.items) {
                        if (-not $item.ContainsKey('kind') -or -not $item.ContainsKey('path')) {
                            continue
                        }
                        $kind = [string]$item.kind
                        $path = [string]$item.path
                        $artifactName = Get-CollectionArtifactKey -Kind $kind -Path $path

                        $resolvedPath = Join-Path $RepoRoot ($path -replace '^\./', '')
                        if ($kind -eq 'skill') {
                            $resolvedPath = Join-Path $resolvedPath 'SKILL.md'
                        }
                        $artifactDesc = Get-ArtifactDescription -FilePath $resolvedPath

                        $entry = @{ Name = $artifactName; Description = $artifactDesc }
                        switch ($kind) {
                            'agent' { $agents += $entry }
                            'prompt' { $prompts += $entry }
                            'instruction' { $instructions += $entry }
                            'skill' { $skills += $entry }
                        }
                    }

                    $artifactSections = [System.Text.StringBuilder]::new()

                    foreach ($section in @(
                        @{ Title = 'Chat Agents'; Items = $agents },
                        @{ Title = 'Prompts'; Items = $prompts },
                        @{ Title = 'Instructions'; Items = $instructions },
                        @{ Title = 'Skills'; Items = $skills }
                    )) {
                        if ($section.Items.Count -eq 0) { continue }

                        $null = $artifactSections.AppendLine("### $($section.Title)")
                        $null = $artifactSections.AppendLine()
                        $null = $artifactSections.AppendLine('| Name | Description |')
                        $null = $artifactSections.AppendLine('|------|-------------|')
                        foreach ($entry in ($section.Items | Sort-Object { $_.Name })) {
                            $null = $artifactSections.AppendLine("| **$($entry.Name)** | $($entry.Description) |")
                        }
                        $null = $artifactSections.AppendLine()
                    }

                    $generatedBlock = $artifactSections.ToString().TrimEnd()
                    $updatedCollectionMd = "$($parsed.Intro)`n`n$($CollectionMdBeginMarker)`n`n$generatedBlock`n`n$($CollectionMdEndMarker)"
                    if (-not [string]::IsNullOrWhiteSpace($parsed.Footer)) {
                        $updatedCollectionMd += "`n`n$($parsed.Footer.TrimEnd())"
                    }
                    $updatedCollectionMd += "`n"
                    Set-ContentIfChanged -Path $collectionMdPath -Value $updatedCollectionMd
                }
            }
        }
        #endregion

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

    # Aggregate framework attribution notices from skill index.yml files
    $noticesResult = Update-ThirdPartyNotices `
        -RepoRoot $RepoRoot `
        -Collections $allCollections `
        -DryRun:$DryRun
    Write-Verbose "Notices: $($noticesResult.Attributed) attributed, $($noticesResult.Acknowledgements) acknowledgements (changed=$($noticesResult.Changed))"

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

function Update-ThirdPartyNotices {
    <#
    .SYNOPSIS
        Regenerates the auto-managed framework attribution block in THIRD-PARTY-NOTICES.

    .DESCRIPTION
        Walks every skill referenced by the supplied collections, locates the
        sibling index.yml, and emits one notice row per framework whose
        metadata.attributionRequired is true. Frameworks with
        attributionRequired: false are listed under an Acknowledgements
        sub-section. Output is written between fixed delimiters; content
        outside the delimiters is preserved verbatim. The aggregator is
        idempotent: re-running with no source changes produces no diff.

    .PARAMETER RepoRoot
        Absolute path to the repository root.

    .PARAMETER Collections
        Loaded collection manifests whose skill items determine the attribution scope.

    .PARAMETER DryRun
        When set, reports what would be written but does not modify the file.

    .OUTPUTS
        [hashtable] with Attributed, Acknowledgements, and Changed keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [object[]]$Collections,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    $beginMarker = '<!-- BEGIN AUTO-GENERATED FRAMEWORK SKILL ATTRIBUTIONS -->'
    $endMarker = '<!-- END AUTO-GENERATED FRAMEWORK SKILL ATTRIBUTIONS -->'
    $noticesPath = Join-Path -Path $RepoRoot -ChildPath 'THIRD-PARTY-NOTICES'

    # Collect unique skill directories across every active collection
    $skillDirs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($collection in $Collections) {
        foreach ($item in $collection.items) {
            if ([string]$item.kind -ne 'skill') { continue }
            $itemPath = [string]$item.path
            if ([string]::IsNullOrWhiteSpace($itemPath)) { continue }
            # Skill items reference the skill directory itself; if a SKILL.md path
            # is supplied instead, fall back to its parent directory.
            $skillDir = $itemPath
            if ($itemPath -match '\.md$') {
                $skillDir = Split-Path -Path $itemPath -Parent
            }
            if (-not [string]::IsNullOrWhiteSpace($skillDir)) {
                [void]$skillDirs.Add($skillDir)
            }
        }
    }

    $attributed = @()
    $acknowledgements = @()

    foreach ($skillDir in $skillDirs) {
        $indexPath = Join-Path -Path $RepoRoot -ChildPath (Join-Path -Path $skillDir -ChildPath 'index.yml')
        if (-not (Test-Path -LiteralPath $indexPath)) { continue }
        try {
            $parsed = Get-Content -LiteralPath $indexPath -Raw | ConvertFrom-Yaml
        }
        catch {
            Write-Warning "Failed to parse $indexPath : $($_.Exception.Message)"
            continue
        }
        if (-not $parsed -or -not $parsed.ContainsKey('metadata')) { continue }
        $meta = $parsed['metadata']
        $framework = [string]$parsed['framework']
        if ([string]::IsNullOrWhiteSpace($framework)) { continue }

        $entry = [pscustomobject]@{
            Framework       = $framework
            Authority       = if ($meta.ContainsKey('authority')) { [string]$meta['authority'] } else { '' }
            License         = if ($meta.ContainsKey('license')) { [string]$meta['license'] } else { '' }
            LicenseUrl      = if ($meta.ContainsKey('licenseUrl')) { [string]$meta['licenseUrl'] } else { '' }
            Source          = if ($meta.ContainsKey('source')) { [string]$meta['source'] } else { '' }
            AttributionText = if ($meta.ContainsKey('attributionText')) { [string]$meta['attributionText'] } else { '' }
        }

        $required = $false
        if ($meta.ContainsKey('attributionRequired')) {
            $required = [bool]$meta['attributionRequired']
        }
        if ($required) {
            $attributed += $entry
        }
        else {
            $acknowledgements += $entry
        }
    }

    $attributed = @($attributed | Sort-Object Framework)
    $acknowledgements = @($acknowledgements | Sort-Object Framework)

    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.AppendLine($beginMarker)
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('## Framework Skill Attributions')
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('Auto-generated by `scripts/plugins/Generate-Plugins.ps1` from `metadata` blocks in')
    [void]$sb.AppendLine('`.github/skills/**/index.yml`. Do not edit by hand inside the marker block — changes')
    [void]$sb.AppendLine('are overwritten on the next plugin generation run.')
    [void]$sb.AppendLine('')

    if ($attributed.Count -gt 0) {
        [void]$sb.AppendLine('### Attribution-Required Frameworks')
        [void]$sb.AppendLine('')
        foreach ($e in $attributed) {
            [void]$sb.AppendLine("#### $($e.Framework)")
            [void]$sb.AppendLine('')
            if ($e.Authority) { [void]$sb.AppendLine("- Authority: $($e.Authority)") }
            if ($e.License) { [void]$sb.AppendLine("- License: $($e.License)") }
            if ($e.LicenseUrl) { [void]$sb.AppendLine("- License URI: $($e.LicenseUrl)") }
            if ($e.Source) { [void]$sb.AppendLine("- Source: $($e.Source)") }
            if ($e.AttributionText) {
                [void]$sb.AppendLine('- Attribution:')
                [void]$sb.AppendLine('')
                $lines = $e.AttributionText -split "`r?`n"
                foreach ($ln in $lines) {
                    if ($ln.Trim().Length -eq 0) {
                        [void]$sb.AppendLine('  >')
                    }
                    else {
                        [void]$sb.AppendLine("  > $ln")
                    }
                }
            }
            [void]$sb.AppendLine('')
        }
    }

    if ($acknowledgements.Count -gt 0) {
        [void]$sb.AppendLine('### Acknowledgements')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('Bundled framework skills that do not require redistribution attribution.')
        [void]$sb.AppendLine('')
        foreach ($e in $acknowledgements) {
            $authority = if ($e.Authority) { " — $($e.Authority)" } else { '' }
            $license = if ($e.License) { " ($($e.License))" } else { '' }
            [void]$sb.AppendLine("- $($e.Framework)$authority$license")
        }
        [void]$sb.AppendLine('')
    }

    [void]$sb.Append($endMarker)
    $generatedBlock = $sb.ToString()

    $existing = ''
    if (Test-Path -LiteralPath $noticesPath) {
        $existing = Get-Content -LiteralPath $noticesPath -Raw
    }
    $existingNormalized = $existing -replace "`r`n", "`n"

    $beginIdx = $existingNormalized.IndexOf($beginMarker)
    $endIdx = $existingNormalized.IndexOf($endMarker)

    if ($beginIdx -ge 0 -and $endIdx -gt $beginIdx) {
        $before = $existingNormalized.Substring(0, $beginIdx)
        $after = $existingNormalized.Substring($endIdx + $endMarker.Length)
        $newContent = $before + $generatedBlock + $after
    }
    else {
        $separator = ''
        if ($existingNormalized.Length -gt 0) {
            if (-not $existingNormalized.EndsWith("`n")) { $separator = "`n`n" } else { $separator = "`n" }
        }
        $newContent = $existingNormalized + $separator + $generatedBlock + "`n"
    }

    if (-not $newContent.EndsWith("`n")) { $newContent += "`n" }

    $changed = $newContent -ne $existingNormalized

    if ($DryRun) {
        if ($changed) {
            Write-Host "  [DRY RUN] Would update THIRD-PARTY-NOTICES (attributed: $($attributed.Count), acknowledgements: $($acknowledgements.Count))" -ForegroundColor Yellow
        }
    }
    elseif ($changed) {
        [System.IO.File]::WriteAllText($noticesPath, $newContent, [System.Text.UTF8Encoding]::new($false))
        Write-Host "  THIRD-PARTY-NOTICES updated (attributed: $($attributed.Count), acknowledgements: $($acknowledgements.Count))" -ForegroundColor Green
    }
    else {
        Write-Verbose 'THIRD-PARTY-NOTICES already up to date.'
    }

    return @{
        Attributed       = $attributed.Count
        Acknowledgements = $acknowledgements.Count
        Changed          = $changed
    }
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
