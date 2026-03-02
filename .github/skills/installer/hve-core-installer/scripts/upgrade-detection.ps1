<#
.SYNOPSIS
    Detects whether the current installation is eligible for upgrade.
.DESCRIPTION
    Checks for .hve-tracking.json and compares installed version against
    the source HVE-Core version from package.json.
.NOTES
    Set $hveCoreBasePath before running.
.OUTPUTS
    UPGRADE_MODE, INSTALLED_VERSION, SOURCE_VERSION, VERSION_CHANGED,
    INSTALLED_COLLECTION key-value pairs.
#>
$ErrorActionPreference = 'Stop'
$manifestPath = ".hve-tracking.json"

if (Test-Path $manifestPath) {
    $manifest = Get-Content $manifestPath | ConvertFrom-Json -AsHashtable
    $sourceVersion = (Get-Content "$hveCoreBasePath/package.json" | ConvertFrom-Json).version

    Write-Host "UPGRADE_MODE=true"
    Write-Host "INSTALLED_VERSION=$($manifest.version)"
    Write-Host "SOURCE_VERSION=$sourceVersion"
    Write-Host "VERSION_CHANGED=$($sourceVersion -ne $manifest.version)"
    Write-Host "INSTALLED_COLLECTION=$($manifest.collection ?? 'hve-core')"
} else {
    Write-Host "UPGRADE_MODE=false"
}
