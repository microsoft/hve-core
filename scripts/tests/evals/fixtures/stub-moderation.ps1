# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#
# Test stub standing in for Invoke-ContentModeration.ps1. It mirrors the real
# script's parameter surface and exit-code contract so VallyRunner moderation
# classification can be exercised without invoking the moderation backend.
#
# Behavior is driven by environment variables:
#   STUB_MODERATION_EXIT  - exit code to return (default 0).
#   STUB_MODERATION_COUNT - summary.flaggedCount to write (default 0).
#   STUB_MODERATION_FLAG_IDS - comma-separated record ids to mark flagged.
#   STUB_MODERATION_CAPTURE - optional path that receives the input records.

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

$flaggedIds = @()
if ($env:STUB_MODERATION_FLAG_IDS) {
    $flaggedIds = @($env:STUB_MODERATION_FLAG_IDS -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

if ($env:STUB_MODERATION_CAPTURE) {
    $captureDir = Split-Path -Parent $env:STUB_MODERATION_CAPTURE
    if ($captureDir -and -not (Test-Path -LiteralPath $captureDir)) {
        New-Item -ItemType Directory -Path $captureDir -Force | Out-Null
    }
    $Records | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $env:STUB_MODERATION_CAPTURE -Encoding utf8
}

$resultRecords = @($Records | ForEach-Object {
    $recordId = [string]$_.id
    $isFlagged = $flaggedIds -contains $recordId
    [ordered]@{
        id            = $recordId
        flagged       = $isFlagged
        flaggedLabels = $(if ($isFlagged) { @('toxicity') } else { @() })
    }
})
if (-not $env:STUB_MODERATION_COUNT) {
    $flaggedCount = @($resultRecords | Where-Object { $_.flagged }).Count
}

$payload = [ordered]@{
    scope   = $Scope
    records = $resultRecords
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
