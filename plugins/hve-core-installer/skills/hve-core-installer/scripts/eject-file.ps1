# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Ejects a file from HVE-Core upgrade tracking. Ejected files are permanently
# excluded from future upgrades, giving the user full ownership.
# Usage: eject-file.ps1 -FilePath <path>
#   FilePath: Relative path to the file to eject (e.g., .github/agents/task-planner.agent.md)

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$FilePath
)

$ErrorActionPreference = 'Stop'

$manifestPath = ".hve-tracking.json"
$manifest = Get-Content $manifestPath | ConvertFrom-Json -AsHashtable

if ($manifest.files.ContainsKey($FilePath)) {
    $manifest.files[$FilePath].status = "ejected"
    $manifest.files[$FilePath].ejectedAt = (Get-Date -Format "o")

    $manifest | ConvertTo-Json -Depth 10 | Set-Content $manifestPath
    Write-Host "✅ Ejected: $FilePath"
    Write-Host "   This file will never be updated by HVE-Core."
} else {
    Write-Host "File not found in manifest: $FilePath" -ForegroundColor Red
    exit 1
}
