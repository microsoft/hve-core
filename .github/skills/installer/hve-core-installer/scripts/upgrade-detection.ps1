# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Detects whether the current installation is eligible for upgrade.
.DESCRIPTION
    Checks for a schema version 2 .hve-tracking.json and compares the installed
    version against the source HVE-Core version from package.json. Reports the
    recorded selection so the caller can re-resolve the same components.
.PARAMETER HveCoreBasePath
    Root path of the local HVE-Core clone containing package.json.
.PARAMETER TargetRoot
    Root of the repository that holds the manifest.
.EXAMPLE
    ./scripts/upgrade-detection.ps1 -HveCoreBasePath ../hve-core
.OUTPUTS
    UPGRADE_MODE, INSTALLED_VERSION, SOURCE_VERSION, VERSION_CHANGED,
    INSTALLED_PACKAGE, INSTALLED_PROFILE, and INSTALLED_COMPONENTS key-value
    pairs. INSTALLED_PACKAGE is empty when the manifest records no package.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$HveCoreBasePath,

    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$TargetRoot = '.'
)

$ErrorActionPreference = 'Stop'

$manifestPath = Join-Path (Resolve-Path -LiteralPath $TargetRoot).Path '.hve-tracking.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    Write-Host 'UPGRADE_MODE=false'
    return
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$schemaVersion = if ($manifest.Contains('schemaVersion')) { $manifest['schemaVersion'] } else { 'missing' }
if ($schemaVersion -ne 2) {
    throw "Unsupported .hve-tracking.json schemaVersion '$schemaVersion' (expected 2). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
}

$sourceVersion = (Get-Content -LiteralPath (Join-Path $HveCoreBasePath 'package.json') -Raw -Encoding utf8 | ConvertFrom-Json).version
$selection = if ($manifest['selection'] -is [System.Collections.IDictionary]) { $manifest['selection'] } else { @{} }
# Empty when a schema version 2 manifest predates package-explicit selection; no package is inferred.
$packageName = if ($selection['package']) { [string]$selection['package'] } else { '' }
$profileName = if ($selection['profile']) { [string]$selection['profile'] } else { 'custom' }
$components = [string[]]@($selection['components'] | Where-Object { $_ })

Write-Host 'UPGRADE_MODE=true'
Write-Host "INSTALLED_VERSION=$($manifest['version'])"
Write-Host "SOURCE_VERSION=$sourceVersion"
# Lower-cased so the emitted value matches UPGRADE_MODE and the Bash detector.
Write-Host "VERSION_CHANGED=$(if ($sourceVersion -ne $manifest['version']) { 'true' } else { 'false' })"
Write-Host "INSTALLED_PACKAGE=$packageName"
Write-Host "INSTALLED_PROFILE=$profileName"
Write-Host "INSTALLED_COMPONENTS=$($components -join ',')"
