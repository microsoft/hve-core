# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates an HVE-Core clone-based installation.
.DESCRIPTION
    Checks that required directories exist and method-specific configuration
    is correct (workspace file for multi-root, .gitmodules for submodule).
.PARAMETER BasePath
    Root path of the installation to validate.
.PARAMETER Method
    Installation method number (1-6) that determines which validations to run.
.EXAMPLE
    ./scripts/validate-installation.ps1 -BasePath ./my-project -Method 1
.EXAMPLE
    ./scripts/validate-installation.ps1 -BasePath ./my-project -Method 5
.OUTPUTS
    Per-directory pass/fail status and overall validation result.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateScript({ Test-Path $_ })]
    [string]$BasePath,

    [Parameter(Mandatory)]
    [ValidateRange(1, 6)]
    [int]$Method
)

$ErrorActionPreference = 'Stop'

$valid = $true
foreach ($dir in @("$basePath/.github/agents", "$basePath/.github/prompts", "$basePath/.github/instructions", "$basePath/.github/skills")) {
    if (-not (Test-Path $dir)) { $valid = $false; Write-Host "❌ Missing: $dir" }
    else { Write-Host "✅ Found: $dir" }
}

# Optional: informational check for experimental subdirectories (absence is not a failure)
foreach ($dir in @("$basePath/.github/skills/experimental", "$basePath/.github/agents/experimental")) {
    if (Test-Path $dir) { Write-Host "ℹ️  Found optional: $dir" }
}

# Method 5 additional check: workspace file
if ($method -eq 5 -and (Test-Path "hve-core.code-workspace")) {
    $workspace = Get-Content "hve-core.code-workspace" | ConvertFrom-Json
    if ($workspace.folders.Count -lt 2) { $valid = $false; Write-Host "❌ Multi-root not configured" }
    else { Write-Host "✅ Multi-root configured" }
}

# Method 6 additional check: submodule
if ($method -eq 6) {
    if (-not (Test-Path ".gitmodules") -or -not (Select-String -Path ".gitmodules" -Pattern "lib/hve-core" -Quiet)) {
        $valid = $false; Write-Host "❌ Submodule not in .gitmodules"
    }
}

if ($valid) { Write-Host "✅ Installation validated successfully" }
