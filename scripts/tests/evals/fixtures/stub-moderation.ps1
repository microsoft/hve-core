# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#
# Test stub standing in for Invoke-ContentModeration.ps1. It mirrors the real
# script's parameter surface and exit-code contract so VallyRunner moderation
# classification can be exercised without invoking the moderation backend.
#
# Behavior is driven by environment variables:
#   STUB_MODERATION_EXIT  - exit code to return (default 0).
#   STUB_MODERATION_COUNT - summary.flaggedCount to write (default 0).

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][object[]]$Records,
    [Parameter(Mandatory = $true)][string]$Scope,
    [double]$Threshold = 0.5,
    [Parameter(Mandatory = $true)][string]$OutFile
)

$exitCode = 0
if ($env:STUB_MODERATION_EXIT) { $exitCode = [int]$env:STUB_MODERATION_EXIT }

$flaggedCount = 0
if ($env:STUB_MODERATION_COUNT) { $flaggedCount = [int]$env:STUB_MODERATION_COUNT }

$payload = [ordered]@{
    scope   = $Scope
    records = @()
    summary = [ordered]@{
        total        = $Records.Count
        flaggedCount = $flaggedCount
    }
}

$dir = Split-Path -Parent $OutFile
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
$payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutFile -Encoding utf8

exit $exitCode
