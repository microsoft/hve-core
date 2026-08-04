# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Ejects a tracked component from HVE-Core upgrade management.
.DESCRIPTION
    Marks every file belonging to the component as 'ejected' in the schema
    version 2 .hve-tracking.json so future upgrades skip it. The files remain
    on disk and become owned by the user.
.PARAMETER Component
    Marketplace component path such as agents/hve-core/rpi-agent.md or skills/rpi/rpi-plan.
.PARAMETER TargetRoot
    Root of the repository that holds the manifest.
.EXAMPLE
    ./scripts/eject.ps1 -Component 'agents/hve-core/rpi-agent.md'
.OUTPUTS
    Ejection confirmation or a not-tracked notice.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$Component,

    [Parameter()]
    [ValidateScript({ Test-Path -LiteralPath $_ -PathType Container })]
    [string]$TargetRoot = '.'
)

$ErrorActionPreference = 'Stop'

# ConvertFrom-Json coerces ISO 8601 strings to DateTime, so timestamps are
# re-serialized in the shared string format before the manifest is rewritten.
function ConvertTo-InstallerTimestamp {
    param($Value)
    if ($Value -is [datetime]) { return ([datetime]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    if ($Value -is [datetimeoffset]) { return ([datetimeoffset]$Value).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ') }
    return [string]$Value
}

$manifestPath = Join-Path (Resolve-Path -LiteralPath $TargetRoot).Path '.hve-tracking.json'
if (-not (Test-Path -LiteralPath $manifestPath -PathType Leaf)) {
    throw 'No .hve-tracking.json found.'
}

$manifest = Get-Content -LiteralPath $manifestPath -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
$schemaVersion = if ($manifest.Contains('schemaVersion')) { $manifest['schemaVersion'] } else { 'missing' }
if ($schemaVersion -ne 2) {
    throw "Unsupported .hve-tracking.json schemaVersion '$schemaVersion' (expected 2). Delete .hve-tracking.json and re-run the installer for a clean reinstall."
}

$matched = [string[]]@($manifest['files'].Keys | Where-Object { [string]$manifest['files'][$_]['component'] -eq $Component })
if ($matched.Count -eq 0) {
    Write-Host "❌ Component not found in tracking manifest: $Component"
    return
}

$ejectedAt = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
$manifest['installed'] = ConvertTo-InstallerTimestamp -Value $manifest['installed']
foreach ($file in $manifest['files'].Keys) {
    if ($manifest['files'][$file].Contains('ejectedAt')) {
        $manifest['files'][$file]['ejectedAt'] = ConvertTo-InstallerTimestamp -Value $manifest['files'][$file]['ejectedAt']
    }
}
foreach ($file in $matched) {
    $manifest['files'][$file]['status'] = 'ejected'
    $manifest['files'][$file]['ejectedAt'] = $ejectedAt
}

$manifest | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $manifestPath -Encoding utf8
Write-Host "✅ Ejected: $Component"
Write-Host '   HVE-Core will never update this component.'
