# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Compares installed HVE-Core files against the .hve-tracking.json manifest.
.DESCRIPTION
    Requires a schema version 2 manifest. For each tracked file, computes the
    current SHA256 hash and compares it against the stored hash to determine
    status: managed, modified, ejected, or missing. Component, kind, and
    maturity accompany every line so callers can group per component.
.PARAMETER TargetRoot
    Root of the repository that holds the manifest and installed files.
.EXAMPLE
    ./scripts/file-status-check.ps1
.EXAMPLE
    ./scripts/file-status-check.ps1 -TargetRoot ../my-project
.OUTPUTS
    Per-file lines: FILE=<path>|COMPONENT=<path>|KIND=<kind>|MATURITY=<maturity>|STATUS=<status>|ACTION=<action>.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$TargetRoot = '.'
)

$ErrorActionPreference = 'Stop'

$targetBase = (Resolve-Path -LiteralPath $TargetRoot).Path
$manifestPath = Join-Path $targetBase '.hve-tracking.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'No .hve-tracking.json found.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$schemaVersion = if ($manifest.Contains('schemaVersion')) { $manifest['schemaVersion'] } else { 'missing' }
if ($schemaVersion -ne 2) {
    throw "Unsupported .hve-tracking.json schemaVersion '$schemaVersion' (expected 2). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
}

$tracked = [string[]]@($manifest['files'].Keys)
[array]::Sort($tracked, [System.StringComparer]::Ordinal)

foreach ($file in $tracked) {
    $entry = $manifest['files'][$file]
    $component = [string]$entry['component']
    $kind = [string]$entry['kind']
    $maturity = [string]$entry['maturity']
    $prefix = "FILE=$file|COMPONENT=$component|KIND=$kind|MATURITY=$maturity"

    if ($entry['status'] -eq 'ejected') {
        Write-Host "$prefix|STATUS=ejected|ACTION=Skip (user owns this file)"
        continue
    }

    $absolute = Join-Path $targetBase $file
    if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
        Write-Host "$prefix|STATUS=missing|ACTION=Will restore"
        continue
    }

    $currentHash = (Get-FileHash -LiteralPath $absolute -Algorithm SHA256).Hash.ToLower()
    if ($currentHash -ne [string]$entry['sha256']) {
        Write-Host "$prefix|STATUS=modified|ACTION=Requires decision"
    }
    else {
        Write-Host "$prefix|STATUS=managed|ACTION=Will update"
    }
}
