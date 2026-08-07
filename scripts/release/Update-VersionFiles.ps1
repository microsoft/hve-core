#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Updates version strings across all version-tracked files in the repository.

.DESCRIPTION
    Central version bump script for the version-tracked files that must agree
    for a release or moving catalog. Updates:

    - package.json
    - package-lock.json (version and packages[""].version)
    - extension/templates/package.template.json
    - .github/plugin/marketplace.json (metadata.version and plugins[*].version)
    - The selected release-please manifest, unless SkipManifest is set

    After updating the files, runs 'npm run plugin:generate' against the
    caller-supplied staging root unless generation is skipped.

.PARAMETER Version
    The version string to write (e.g. '3.3.0').

.PARAMETER CatalogRefMode
    Required catalog source-ref policy. Exact adds or updates every entry to
    hve-core-v<version>; Remove deletes source.ref from every entry.

.PARAMETER RepoRoot
    Optional. Repository root directory. Defaults to the git working tree root.

.PARAMETER ManifestPath
    Optional. Repository-relative manifest path to update. Defaults to
    .release-please-manifest.json.

.PARAMETER SkipManifest
    Optional. Update shared version metadata without changing a release-please
    manifest. Cannot be combined with ManifestPath.

.PARAMETER SkipPluginGenerate
    Optional. Skip running 'npm run plugin:generate' after updating files.

.EXAMPLE
    ./Update-VersionFiles.ps1 -Version '3.3.0'

.EXAMPLE
    ./Update-VersionFiles.ps1 -Version '3.3.0' -RepoRoot '/path/to/repo'

.NOTES
    Requires Node.js and npm dependencies installed when SkipPluginGenerate is
    not set. The caller must also supply package staging outside the repository.
    Catalog ref updates are explicit because release-please's extra-files
    updaters cannot express property insertion or removal.
#>

[CmdletBinding(DefaultParameterSetName = 'Manifest')]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+\z')]
    [string]$Version,

    [Parameter(Mandatory = $true)]
    [ValidateSet('Remove', 'Exact')]
    [string]$CatalogRefMode,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = "",

    [Parameter(Mandatory = $false, ParameterSetName = 'Manifest')]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
            -not [System.IO.Path]::IsPathRooted($_) -and
            $_ -notmatch '(^|[\\/])\.\.([\\/]|$)'
        })]
    [string]$ManifestPath = '.release-please-manifest.json',

    [Parameter(Mandatory = $true, ParameterSetName = 'SkipManifest')]
    [switch]$SkipManifest,

    [Parameter(Mandatory = $false)]
    [switch]$SkipPluginGenerate
)

$ErrorActionPreference = 'Stop'

#region Helpers

function Resolve-RepoRoot {
    <#
    .SYNOPSIS
        Resolves the repository root directory.
    #>
    param([string]$Supplied)

    if ($Supplied) {
        return (Resolve-Path $Supplied).Path
    }

    # Walk up from script location to find the repo root
    $candidate = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
    if (Test-Path (Join-Path $candidate ".git")) {
        return $candidate
    }

    throw "Unable to determine repository root. Pass -RepoRoot explicitly."
}

function Update-JsonVersion {
    <#
    .SYNOPSIS
        Updates a version field in a JSON file using a script block.
    #>
    param(
        [string]$FilePath,
        [string]$Description,
        [scriptblock]$Transform,
        [switch]$AsHashtable
    )

    if (-not (Test-Path $FilePath)) {
        Write-Host "  ⏭️  Skipping $Description — file not found: $FilePath" -ForegroundColor Yellow
        return
    }

    $convertParams = @{ Depth = 20 }
    if ($AsHashtable) { $convertParams['AsHashtable'] = $true }
    $raw = Get-Content -Raw $FilePath
    if ([string]::IsNullOrWhiteSpace($raw)) {
        throw "File is empty or whitespace-only: $FilePath"
    }
    $hadFinalNewline = $raw.EndsWith("`n", [System.StringComparison]::Ordinal)
    $json = $raw | ConvertFrom-Json @convertParams
    $json = & $Transform $json
    $content = $json | ConvertTo-Json -Depth 20
    if ($hadFinalNewline) {
        $content += "`n"
    }
    $content | Set-Content -Path $FilePath -Encoding UTF8 -NoNewline
    Write-Host "  ✅ Updated $Description" -ForegroundColor Green
}

function Update-MarketplaceCatalogVersion {
    <#
    .SYNOPSIS
        Advances marketplace versions and applies an explicit source-ref mode.

    .PARAMETER Catalog
        Parsed marketplace catalog.

    .PARAMETER Version
        Exact version written to catalog metadata and every package.

    .PARAMETER RefMode
        Exact adds hve-core-v<version>; Remove deletes source.ref.

    .OUTPUTS
        [object] Updated marketplace catalog.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [object]$Catalog,

        [Parameter(Mandatory = $true)]
        [ValidatePattern('^\d+\.\d+\.\d+\z')]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Remove', 'Exact')]
        [string]$RefMode
    )

    $Catalog.metadata.version = $Version
    foreach ($plugin in $Catalog.plugins) {
        $plugin.version = $Version
        if ($RefMode -eq 'Exact') {
            $plugin.source | Add-Member -NotePropertyName ref -NotePropertyValue "hve-core-v$Version" -Force
        }
        else {
            $plugin.source.PSObject.Properties.Remove('ref')
        }
    }
    return $Catalog
}

#endregion Helpers

#region Main

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $root = Resolve-RepoRoot -Supplied $RepoRoot
        Write-Host "🔄 Updating version files to $Version" -ForegroundColor Cyan
        Write-Host "  📂 Repo root: $root" -ForegroundColor Gray

        # 1. package.json
        Update-JsonVersion `
            -FilePath (Join-Path $root "package.json") `
            -Description "package.json" `
            -Transform { param($j) $j.version = $Version; $j }

        # 2. package-lock.json (version + packages[""].version)
        Update-JsonVersion `
            -FilePath (Join-Path $root "package-lock.json") `
            -Description "package-lock.json" `
            -AsHashtable `
            -Transform {
                param($j)
                $j['version'] = $Version
                if ($j.ContainsKey('packages') -and $j['packages'].ContainsKey('')) {
                    $j['packages']['']['version'] = $Version
                }
                $j
            }

        # 3. extension/templates/package.template.json
        Update-JsonVersion `
            -FilePath (Join-Path $root "extension/templates/package.template.json") `
            -Description "extension/templates/package.template.json" `
            -Transform { param($j) $j.version = $Version; $j }

        # 4. .github/plugin/marketplace.json
        Update-JsonVersion `
            -FilePath (Join-Path $root ".github/plugin/marketplace.json") `
            -Description ".github/plugin/marketplace.json" `
            -Transform {
                param($j)
                Update-MarketplaceCatalogVersion -Catalog $j -Version $Version -RefMode $CatalogRefMode
            }

        # 5. Selected release-please manifest
        if (-not $SkipManifest) {
            $resolvedManifestPath = Join-Path $root $ManifestPath
            if (
                $PSBoundParameters.ContainsKey('ManifestPath') -and
                -not (Test-Path -LiteralPath $resolvedManifestPath -PathType Leaf)
            ) {
                throw "Manifest file not found: $ManifestPath"
            }

            Update-JsonVersion `
                -FilePath $resolvedManifestPath `
                -Description $ManifestPath `
                -Transform { param($j) $j.'.' = $Version; $j }
        }
        else {
            Write-Host "  ⏭️  Skipping release-please manifest update" -ForegroundColor Yellow
        }

        # 6. Regenerate plugin outputs
        if (-not $SkipPluginGenerate) {
            Write-Host "  🔧 Running npm run plugin:generate ..." -ForegroundColor Cyan
            Push-Location $root
            try {
                npm run plugin:generate
                if ($LASTEXITCODE -ne 0) {
                    throw "npm run plugin:generate failed with exit code $LASTEXITCODE"
                }
                Write-Host "  ✅ Plugin generation complete" -ForegroundColor Green
            }
            finally {
                Pop-Location
            }
        }
        else {
            Write-Host "  ⏭️  Skipping plugin:generate (SkipPluginGenerate set)" -ForegroundColor Yellow
        }

        Write-Host "✅ All version files updated to $Version" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Version update failed: $_" -ForegroundColor Red
        throw
    }
}

#endregion Main
