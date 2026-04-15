#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Updates version strings across all version-tracked files in the repository.

.DESCRIPTION
    Central version bump script called by both release-prerelease-pr.yml and
    release-stable.yml workflows. Updates:

    - package.json
    - package-lock.json (version and packages[""].version)
    - extension/templates/package.template.json
    - .github/plugin/marketplace.json (metadata.version and plugins[*].version)
    - plugins/*/.github/plugin/plugin.json (glob)
    - .release-please-manifest.json

    After updating the files, runs 'npm run plugin:generate' to regenerate
    plugin outputs so plugin-validation passes.

.PARAMETER Version
    The version string to write (e.g. '3.3.0').

.PARAMETER RepoRoot
    Optional. Repository root directory. Defaults to the git working tree root.

.PARAMETER SkipPluginGenerate
    Optional. Skip running 'npm run plugin:generate' after updating files.

.EXAMPLE
    ./Update-VersionFiles.ps1 -Version '3.3.0'

.EXAMPLE
    ./Update-VersionFiles.ps1 -Version '3.3.0' -RepoRoot '/path/to/repo'

.NOTES
    Called by CI workflows. Requires Node.js and npm dependencies installed
    when SkipPluginGenerate is not set.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidatePattern('^\d+\.\d+\.\d+')]
    [string]$Version,

    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = "",

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
    $json = $raw | ConvertFrom-Json @convertParams
    $json = & $Transform $json
    $json | ConvertTo-Json -Depth 20 | Set-Content -Path $FilePath -Encoding UTF8 -NoNewline
    Write-Host "  ✅ Updated $Description" -ForegroundColor Green
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
                $j.metadata.version = $Version
                foreach ($plugin in $j.plugins) {
                    $plugin.version = $Version
                }
                $j
            }

        # 5. plugins/*/.github/plugin/plugin.json (glob)
        $pluginJsonFiles = Get-ChildItem -Path (Join-Path $root "plugins") `
            -Filter "plugin.json" -Recurse -Force `
            | Where-Object { $_.FullName -match 'plugins[/\\][^/\\]+[/\\]\.github[/\\]plugin[/\\]plugin\.json$' }

        foreach ($pluginFile in $pluginJsonFiles) {
            $relativePath = $pluginFile.FullName.Replace($root, '').TrimStart('/\')
            Update-JsonVersion `
                -FilePath $pluginFile.FullName `
                -Description $relativePath `
                -Transform { param($j) $j.version = $Version; $j }
        }

        # 6. .release-please-manifest.json
        Update-JsonVersion `
            -FilePath (Join-Path $root ".release-please-manifest.json") `
            -Description ".release-please-manifest.json" `
            -Transform { param($j) $j.'.' = $Version; $j }

        # 7. Regenerate plugin outputs
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
