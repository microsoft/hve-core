# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Validates an HVE-Core clone-based installation by checking required directories
# and method-specific configuration.
# Usage: validate-installation.ps1 -Method <1-6> -BasePath <path>
#   Method:   Installation method number (1-6)
#   BasePath: Path to hve-core root directory

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateRange(1, 6)]
    [int]$Method,

    [Parameter(Mandatory)]
    [string]$BasePath
)

$ErrorActionPreference = 'Stop'

$valid = $true
$requiredDirs = @("$BasePath/.github/agents", "$BasePath/.github/prompts", "$BasePath/.github/instructions")
foreach ($dir in $requiredDirs) {
    if (-not (Test-Path $dir)) { $valid = $false; Write-Host "❌ Missing: $dir" }
    else { Write-Host "✅ Found: $dir" }
}

# Method 5 additional check: workspace file
if ($Method -eq 5 -and (Test-Path "hve-core.code-workspace")) {
    $workspace = Get-Content "hve-core.code-workspace" | ConvertFrom-Json
    if ($workspace.folders.Count -lt 2) { $valid = $false; Write-Host "❌ Multi-root not configured" }
    else { Write-Host "✅ Multi-root configured" }
}

# Method 6 additional check: submodule
if ($Method -eq 6) {
    if (-not (Test-Path ".gitmodules") -or -not (Select-String -Path ".gitmodules" -Pattern "lib/hve-core" -Quiet)) {
        $valid = $false; Write-Host "❌ Submodule not in .gitmodules"
    }
}

if ($valid) { Write-Host "✅ Installation validated successfully" }
