# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Ejects a tracked file from HVE-Core upgrade management.
.DESCRIPTION
    Marks a file as 'ejected' in .hve-tracking.json so future upgrades
    skip it. The file remains on disk but is owned by the user.
.PARAMETER FilePath
    The relative path to the file to eject (e.g., .github/agents/task-implementor.agent.md).
.EXAMPLE
    ./scripts/eject.ps1 -FilePath '.github/agents/task-implementor.agent.md'
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateNotNullOrEmpty()]
    [string]$FilePath
)

$ErrorActionPreference = 'Stop'

$manifest = Get-Content ".hve-tracking.json" | ConvertFrom-Json -AsHashtable

if ($manifest.files.ContainsKey($FilePath)) {
    $manifest.files[$FilePath].status = "ejected"
    $manifest.files[$FilePath].ejectedAt = (Get-Date -Format "o")

    $manifest | ConvertTo-Json -Depth 10 | Set-Content ".hve-tracking.json"
    Write-Host "✅ Ejected: $FilePath"
    Write-Host "   This file will never be updated by HVE-Core."
} else {
    Write-Host "❌ File not found in tracking manifest: $FilePath"
}
