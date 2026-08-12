#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Generates Copilot CLI plugin directories from the marketplace catalog.

.DESCRIPTION
    Reads .github/plugin/marketplace.json and generates plugin directories under
    an explicit staging root outside the repository. Each package contains
    materialized copies of the git-tracked source artifacts, a root plugin.json
    manifest, and an auto-generated README file.

    Standard component fields (agents, commands, rules, skills, hooks) are the
    sole package-definition input; the x-hve overlay contributes display name,
    package and per-component maturity, documentation, and installer profile
    metadata only. Every declared package-relative path maps deterministically
    back to one canonical repository source, so nothing undeclared is
    discovered by scanning.

    Supports generating all packages or specific names. Use -Refresh to
    regenerate existing plugins (deletes and recreates).

.PARAMETER PackageNames
    Optional. Array of package names to generate. Generates all when omitted.

.PARAMETER StagingRoot
    Optional CLI value for the required package staging root. When omitted,
    HVE_PLUGIN_STAGING_ROOT must supply an absolute path outside the repository.

.PARAMETER Refresh
    Optional. Deletes and recreates existing plugin directories.

.PARAMETER DryRun
    Optional. Shows what would be done without making changes.

.PARAMETER Channel
    Optional. Release channel controlling eligible item maturities.
    Stable includes only stable items. PreRelease includes stable, preview,
    and experimental. Deprecated and removed are excluded from both channels.

.PARAMETER MaxTotalSizeMB
    Optional. Ceiling in megabytes for the total generated staging tree.
    Generation fails and names the largest plugins when the ceiling is
    exceeded, catching accidental ingestion of large or undeclared trees.

.PARAMETER CatalogPath
    Optional. Marketplace catalog to read, absolute or relative to the
    repository root. Defaults to .github/plugin/marketplace.json.

.EXAMPLE
    ./Generate-Plugins.ps1 -StagingRoot /tmp/hve-core-plugins
    # Generates all packages under an explicit staging root

.EXAMPLE
    ./Generate-Plugins.ps1 -PackageNames rpi,github
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
    [string[]]$PackageNames,

    [Parameter(Mandatory = $false)]
    [string]$StagingRoot,

    [Parameter(Mandatory = $false)]
    [switch]$Refresh,

    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [ValidateSet('Stable', 'PreRelease')]
    [string]$Channel = 'PreRelease',

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10240)]
    [int]$MaxTotalSizeMB = 40,

    [Parameter(Mandatory = $false)]
    [string]$CatalogPath
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/PluginHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/MarketplaceHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/ArtifactHelpers.psm1') -Force

#region Orchestration

function New-PluginDocumentationBlock {
    <#
    .SYNOPSIS
        Builds the auto-generated artifact tables for a package document.

    .DESCRIPTION
        Renders one table per artifact kind from the resolved package recipe.
        Names, canonical maturity, and descriptions come from the declared
        canonical sources, so the document stays a projection of catalog
        membership rather than an independent inventory.

    .PARAMETER Items
        Resolved recipe items with Kind, SourcePath, and Maturity keys.

    .PARAMETER RepoRoot
        Absolute path to the repository root.

    .OUTPUTS
        [string] Markdown block placed between the auto-generation markers.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Items,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $byKind = @{}
    foreach ($item in $Items) {
        $resolvedPath = Join-Path -Path $RepoRoot -ChildPath $item.SourcePath
        if ($item.Kind -eq 'skill') {
            $resolvedPath = Join-Path -Path $resolvedPath -ChildPath 'SKILL.md'
        }

        if (-not $byKind.ContainsKey($item.Kind)) {
            $byKind[$item.Kind] = [System.Collections.Generic.List[hashtable]]::new()
        }
        $byKind[$item.Kind].Add(@{
                Name        = Get-ArtifactKey -Kind $item.Kind -Path $item.SourcePath
                Maturity    = Get-PluginItemMaturityLabel -Item $item
                Description = Get-ArtifactDescription -FilePath $resolvedPath
            })
    }

    $sections = [System.Text.StringBuilder]::new()
    foreach ($section in @(
            @{ Title = 'Chat Agents'; Kind = 'agent' },
            @{ Title = 'Prompts'; Kind = 'prompt' },
            @{ Title = 'Instructions'; Kind = 'instruction' },
            @{ Title = 'Skills'; Kind = 'skill' },
            @{ Title = 'Hooks'; Kind = 'hook' }
        )) {
        if (-not $byKind.ContainsKey($section.Kind)) { continue }

        $null = $sections.AppendLine("### $($section.Title)")
        $null = $sections.AppendLine()
        $null = $sections.AppendLine('| Name | Maturity | Description |')
        $null = $sections.AppendLine('|------|----------|-------------|')
        foreach ($entry in ($byKind[$section.Kind] | Sort-Object { $_.Name })) {
            $null = $sections.AppendLine("| **$($entry.Name)** | $($entry.Maturity) | $($entry.Description) |")
        }
        $null = $sections.AppendLine()
    }

    return $sections.ToString().TrimEnd()
}

function Update-PluginDocumentationSource {
    <#
    .SYNOPSIS
        Refreshes the auto-generated artifact block in a package document.

    .DESCRIPTION
        The durable package prose referenced by x-hve.documentation owns the
        hand-authored overview and carries one auto-generated artifact block
        between markers. Documents without markers are left untouched so
        hand-authored prose is never overwritten.

    .PARAMETER DocumentPath
        Absolute path to the package document.

    .PARAMETER Items
        Resolved recipe items used to render the artifact block.

    .PARAMETER RepoRoot
        Absolute path to the repository root.

    .OUTPUTS
        [bool] True when the document was rewritten.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$DocumentPath,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [hashtable[]]$Items,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    if (-not (Test-Path -LiteralPath $DocumentPath -PathType Leaf)) {
        return $false
    }

    $content = Get-Content -LiteralPath $DocumentPath -Raw -Encoding utf8
    # An empty document carries no markers and no prose to preserve, so it is a
    # no-op rather than a parse failure that aborts the whole generation run.
    if ([string]::IsNullOrEmpty($content)) {
        return $false
    }

    $parsed = Split-PackageDocByMarkers -Content $content
    if (-not $parsed.HasMarkers) {
        return $false
    }

    $intro = $parsed.Intro.TrimEnd()
    if ($intro -notmatch '(?m)^## Included Artifacts\s*$') {
        $intro = "$intro`n`n## Included Artifacts"
    }

    $block = New-PluginDocumentationBlock -Items $Items -RepoRoot $RepoRoot
    $updated = "$intro`n`n$($PackageDocBeginMarker)`n`n$block`n`n$($PackageDocEndMarker)"
    if (-not [string]::IsNullOrWhiteSpace($parsed.Footer)) {
        $updated += "`n`n$($parsed.Footer.TrimEnd())"
    }
    $updated += "`n"

    return (Set-ContentIfChanged -Path $DocumentPath -Value $updated)
}

function Assert-PluginOutputSize {
    <#
    .SYNOPSIS
        Fails generation when the materialized plugins tree exceeds a ceiling.

    .DESCRIPTION
        Measures the total byte size of the generated plugins directory and
        throws when it exceeds MaxTotalSizeMB. The failure names the largest
        plugins so an accidental ingestion of a large or undeclared tree is
        immediately attributable.

    .PARAMETER PluginsDir
        Absolute path to the generated plugins output directory.

    .PARAMETER MaxTotalSizeMB
        Ceiling in megabytes for the combined generated output.

    .OUTPUTS
        [hashtable] Report with TotalMB and Plugins (name/size pairs) keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginsDir,

        [Parameter(Mandatory = $true)]
        [ValidateRange(1, 10240)]
        [int]$MaxTotalSizeMB
    )

    $perPlugin = [System.Collections.Generic.List[hashtable]]::new()
    $totalBytes = [long]0

    if (Test-Path -LiteralPath $PluginsDir -PathType Container) {
        foreach ($pluginDir in Get-ChildItem -LiteralPath $PluginsDir -Directory) {
            $bytes = [long]0
            foreach ($file in Get-ChildItem -LiteralPath $pluginDir.FullName -File -Recurse -Force) {
                $bytes += $file.Length
            }
            $totalBytes += $bytes
            $perPlugin.Add(@{ Name = $pluginDir.Name; Bytes = $bytes })
        }
    }

    $totalMB = $totalBytes / 1MB
    $report = @{
        TotalMB = $totalMB
        Plugins = @($perPlugin | Sort-Object { -$_.Bytes })
    }

    if ($totalMB -gt $MaxTotalSizeMB) {
        $offenders = @($report.Plugins | Select-Object -First 3 | ForEach-Object {
                "{0} ({1:N1} MB)" -f $_.Name, ($_.Bytes / 1MB)
            })
        throw ("Generated plugins output is {0:N1} MB, exceeding the {1} MB ceiling. Largest plugins: {2}." -f `
                $totalMB, $MaxTotalSizeMB, ($offenders -join ', '))
    }

    return $report
}

function Remove-StalePluginRoot {
    <#
    .SYNOPSIS
        Removes generated plugin roots the catalog no longer declares.

    .DESCRIPTION
        Per-package orphan cleanup only descends into roots the current run
        regenerates, so a package deleted from the catalog leaves its whole
        tree behind. This deletes every directory under the plugins output that
        the current generation did not produce, making repeated generation from
        a pre-collapse tree converge on the declared package set.

    .PARAMETER PluginsDir
        Absolute path to the generated plugins output directory.

    .PARAMETER GeneratedNames
        Package directory names produced by the current run.

    .PARAMETER DryRun
        When specified, logs removals without deleting.

    .OUTPUTS
        [string[]] Removed directory names.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PluginsDir,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$GeneratedNames,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun
    )

    if (-not (Test-Path -LiteralPath $PluginsDir -PathType Container)) {
        return [string[]]@()
    }

    $keep = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]$GeneratedNames, [System.StringComparer]::OrdinalIgnoreCase
    )

    $removed = [System.Collections.Generic.List[string]]::new()
    foreach ($dir in Get-ChildItem -LiteralPath $PluginsDir -Directory -Force | Sort-Object Name) {
        if ($keep.Contains($dir.Name)) { continue }
        $removed.Add($dir.Name)
        if ($DryRun) {
            Write-Host "  [DRY RUN] Would remove stale plugin root: $($dir.Name)" -ForegroundColor Yellow
        }
        else {
            Remove-Item -LiteralPath $dir.FullName -Recurse -Force -ErrorAction Stop
            Write-Host "  Removed stale plugin root: $($dir.Name)" -ForegroundColor Yellow
        }
    }

    return [string[]]$removed.ToArray()
}

function Invoke-PluginGeneration {
    <#
    .SYNOPSIS
        Orchestrates plugin directory generation from the marketplace catalog.

    .DESCRIPTION
        Loads the marketplace catalog, optionally filters to specified package
        names, and generates plugin directory structures under an explicit
        outside-repository staging root. Each package receives materialized
        copies of the declared git-tracked source artifacts, a root plugin.json
        manifest, and an auto-generated README.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .PARAMETER PackageNames
        Optional. Array of package names to generate. Generates all when omitted.

    .PARAMETER StagingRoot
        Optional explicit package staging root. HVE_PLUGIN_STAGING_ROOT is used
        when omitted. The resolved path must be outside the repository.

    .PARAMETER Refresh
        When specified, removes existing plugin directories before regenerating.

    .PARAMETER DryRun
        When specified, logs actions without creating files or directories.

    .PARAMETER Channel
        Release channel controlling item maturity eligibility.

    .PARAMETER MaxTotalSizeMB
        Ceiling in megabytes for the total generated plugins/ tree.

    .PARAMETER CatalogPath
        Optional marketplace catalog path, absolute or relative to RepoRoot.

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
        [string]$StagingRoot,

        [Parameter(Mandatory = $false)]
        [string[]]$PackageNames,

        [Parameter(Mandatory = $false)]
        [switch]$Refresh,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'PreRelease',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10240)]
        [int]$MaxTotalSizeMB = 40,

        [Parameter(Mandatory = $false)]
        [string]$CatalogPath
    )

    $requestedStagingRoot = if (-not [string]::IsNullOrWhiteSpace($StagingRoot)) {
        $StagingRoot
    }
    else {
        $env:HVE_PLUGIN_STAGING_ROOT
    }
    $pluginsDir = Assert-PluginStagingRoot -Path $requestedStagingRoot -RepoRoot $RepoRoot

    $resolvedCatalogPath = if ([string]::IsNullOrWhiteSpace($CatalogPath)) {
        Join-Path -Path $RepoRoot -ChildPath '.github' -AdditionalChildPath 'plugin', 'marketplace.json'
    }
    elseif ([System.IO.Path]::IsPathRooted($CatalogPath)) {
        $CatalogPath
    }
    else {
        Join-Path -Path $RepoRoot -ChildPath $CatalogPath
    }

    $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
    $effectiveVersion = (Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json).version

    $catalog = Get-MarketplaceCatalog -Path $resolvedCatalogPath
    $allEntries = @($catalog['plugins'])

    if ($allEntries.Count -eq 0) {
        Write-Warning "No packages declared in $resolvedCatalogPath"
        return New-GenerateResult -Success $true -PluginCount 0
    }

    $agentIndex = Get-MarketplaceAgentIndex -Catalog $catalog -RepoRoot $RepoRoot

    # Filter to requested names when provided
    if ($PackageNames -and $PackageNames.Count -gt 0) {
        $filtered = @($allEntries | Where-Object { $PackageNames -contains $_['name'] })
        $missing = @($PackageNames | Where-Object { $_ -notin ($allEntries | ForEach-Object { $_['name'] }) })
        if ($missing.Count -gt 0) {
            Write-Warning "Packages not found: $($missing -join ', ')"
        }
        $allEntries = $filtered
    }

    Write-Host "`n=== Plugin Generation ===" -ForegroundColor Cyan
    Write-Host "Packages: $($allEntries.Count)"
    Write-Host "Channel: $Channel"
    Write-Host "Version: $effectiveVersion"
    Write-Host "Catalog: $resolvedCatalogPath"
    Write-Host "Plugins dir: $pluginsDir"
    if ($DryRun) {
        Write-Host '[DRY RUN] No changes will be made' -ForegroundColor Yellow
    }

    $generated = 0
    $totalAgents = 0
    $totalCommands = 0
    $totalInstructions = 0
    $totalSkills = 0
    $totalHooks = 0
    $generatedNames = [System.Collections.Generic.List[string]]::new()

    foreach ($entry in ($allEntries | Sort-Object { $_['name'] })) {
        $id = [string]$entry['name']
        $pluginDir = Join-Path -Path $pluginsDir -ChildPath $id

        $packageMaturity = Get-MarketplaceEntryMaturity -Entry $entry

        if ($packageMaturity -eq 'deprecated') {
            Write-Verbose "Skipping deprecated package: $id"
            continue
        }

        if ($packageMaturity -eq 'removed') {
            Write-Verbose "Skipping removed package: $id"
            continue
        }

        $items = @(Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel $Channel -AgentIndex $agentIndex)

        # Refresh the durable package document before generating the README so
        # the embedded Overview block uses current artifact descriptions.
        $documentation = Get-MarketplaceEntryOverlayValue -Entry $entry -Key 'documentation'
        $documentPath = $null
        if ($documentation) {
            $documentPath = Join-Path -Path $RepoRoot -ChildPath ([string]$documentation)
            if (-not $DryRun) {
                Update-PluginDocumentationSource -DocumentPath $documentPath -Items $items -RepoRoot $RepoRoot | Out-Null
            }
        }

        $result = Write-PluginDirectory -Entry $entry `
            -Items $items `
            -PluginsDir $pluginsDir `
            -RepoRoot $RepoRoot `
            -Version $effectiveVersion `
            -Maturity $packageMaturity `
            -DocumentPath $documentPath `
            -DryRun:$DryRun

        # Orphan cleanup in Refresh mode. Generated directories are real trees,
        # so the walker descends into every one and compares each contained file
        # against the complete generated-path set recorded during materialization.
        if ($Refresh -and (Test-Path -LiteralPath $pluginDir)) {
            $generatedFiles = $result.GeneratedFiles
            $existingFiles = [System.Collections.Generic.List[string]]::new()
            $scanQueue = [System.Collections.Generic.Queue[string]]::new()
            $scanQueue.Enqueue($pluginDir)
            while ($scanQueue.Count -gt 0) {
                $currentDir = $scanQueue.Dequeue()
                foreach ($existing in Get-ChildItem -LiteralPath $currentDir -Force) {
                    if ($existing.PSIsContainer) {
                        $scanQueue.Enqueue($existing.FullName)
                    }
                    else {
                        $existingFiles.Add($existing.FullName)
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
                    Sort-Object { $_.FullName.Length } -Descending |
                    Where-Object { @(Get-ChildItem -LiteralPath $_.FullName -Force).Count -eq 0 } |
                    ForEach-Object {
                        Remove-Item -LiteralPath $_.FullName -Force -ErrorAction Stop
                        Write-Verbose "Removed empty directory: $($_.FullName)"
                    }
            }
        }

        $itemCount = $items.Count
        $totalAgents += $result.AgentCount
        $totalCommands += $result.CommandCount
        $totalInstructions += $result.InstructionCount
        $totalSkills += $result.SkillCount
        $totalHooks += $result.HookCount
        $generated++
        $generatedNames.Add($id)

        Write-Host "  $id ($itemCount items)" -ForegroundColor Green
    }

    # Whole-root cleanup complements per-package orphan removal. A package the
    # catalog no longer declares is never visited above, so only a sweep across
    # the output root retires its tree.
    $isFullRun = -not ($PackageNames -and $PackageNames.Count -gt 0)
    if ($Refresh -and $isFullRun) {
        $staleRoots = @(Remove-StalePluginRoot -PluginsDir $pluginsDir -GeneratedNames ([string[]]$generatedNames) -DryRun:$DryRun)
        if ($staleRoots.Count -gt 0) {
            Write-Host "  Stale plugin roots removed: $($staleRoots -join ', ')"
        }
    }

    if (-not $DryRun) {
        $sizeReport = Assert-PluginOutputSize -PluginsDir $pluginsDir -MaxTotalSizeMB $MaxTotalSizeMB
        Write-Host ("  Generated size: {0:N1} MB (ceiling {1} MB)" -f $sizeReport.TotalMB, $MaxTotalSizeMB)
    }

    Write-Host "`n--- Summary ---" -ForegroundColor Cyan
    Write-Host "  Plugins generated: $generated"
    Write-Host "  Agents: $totalAgents"
    Write-Host "  Commands: $totalCommands"
    Write-Host "  Instructions: $totalInstructions"
    Write-Host "  Skills: $totalSkills"
    Write-Host "  Hooks: $totalHooks"

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

    .PARAMETER PackageNames
        Optional package names forwarded to Invoke-PluginGeneration.

    .PARAMETER StagingRoot
        Explicit staging root forwarded to Invoke-PluginGeneration.

    .PARAMETER Refresh
        Forwarded refresh switch.

    .PARAMETER DryRun
        Forwarded dry-run switch.

    .PARAMETER Channel
        Forwarded channel parameter.

    .PARAMETER MaxTotalSizeMB
        Forwarded generated-output size ceiling in megabytes.

    .PARAMETER CatalogPath
        Forwarded marketplace catalog path.

    .OUTPUTS
        [int] Exit code: 0 for success, 1 for failure.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,

        [Parameter(Mandatory = $false)]
        [string[]]$PackageNames,

        [Parameter(Mandatory = $false)]
        [string]$StagingRoot,

        [Parameter(Mandatory = $false)]
        [switch]$Refresh,

        [Parameter(Mandatory = $false)]
        [switch]$DryRun,

        [Parameter(Mandatory = $false)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel = 'PreRelease',

        [Parameter(Mandatory = $false)]
        [ValidateRange(1, 10240)]
        [int]$MaxTotalSizeMB = 40,

        [Parameter(Mandatory = $false)]
        [string]$CatalogPath
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
        if (-not $PackageNames -and -not $Refresh.IsPresent -and -not $DryRun.IsPresent) {
            $effectiveRefresh = [switch]::new($true)
        }

        $result = Invoke-PluginGeneration `
            -RepoRoot $RepoRoot `
            -StagingRoot $StagingRoot `
            -PackageNames $PackageNames `
            -Refresh:$effectiveRefresh `
            -DryRun:$DryRun `
            -Channel $Channel `
            -MaxTotalSizeMB $MaxTotalSizeMB `
            -CatalogPath $CatalogPath

        if (-not $result.Success) {
            throw $result.ErrorMessage
        }

        Write-Host ''
        Write-Host 'Done!' -ForegroundColor Green
        Write-Host "   $($result.PluginCount) plugin(s) generated."

        return 0
    }
    catch {
        $message = $_.Exception.Message
        Write-Error -ErrorAction Continue "Plugin generation failed: $message"

        if (Get-Command -Name Write-CIAnnotation -ErrorAction SilentlyContinue) {
            Write-CIAnnotation -Message $message -Level Error
        }

        return 1
    }
}

if ($MyInvocation.InvocationName -ne '.') {
    exit (Start-PluginGeneration `
        -ScriptPath $MyInvocation.MyCommand.Path `
        -StagingRoot $StagingRoot `
        -PackageNames $PackageNames `
        -Refresh:$Refresh `
        -DryRun:$DryRun `
        -Channel $Channel `
        -MaxTotalSizeMB $MaxTotalSizeMB `
        -CatalogPath $CatalogPath)
}
#endregion
