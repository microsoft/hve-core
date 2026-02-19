# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Detects whether an existing HVE-Core agent installation requires an upgrade
# by comparing manifest version against the source version.
# Usage: detect-upgrade.ps1 -HveCoreBasePath <path>
#   HveCoreBasePath: Path to the HVE-Core clone root

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$HveCoreBasePath
)

$ErrorActionPreference = 'Stop'
$manifestPath = ".hve-tracking.json"

if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json -AsHashtable
    $sourceVersion = (Get-Content "$HveCoreBasePath/package.json" | ConvertFrom-Json).version

    Write-Host "UPGRADE_MODE=true"
    Write-Host "INSTALLED_VERSION=$($manifest.version)"
    Write-Host "SOURCE_VERSION=$sourceVersion"
    Write-Host "VERSION_CHANGED=$($sourceVersion -ne $manifest.version)"
    $installedCollection = if ($manifest.collection) { $manifest.collection } else { 'rpi-core' }
    Write-Host "INSTALLED_COLLECTION=$installedCollection"
} else {
    Write-Host "UPGRADE_MODE=false"
}
