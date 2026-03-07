# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
<#
.SYNOPSIS
    Validates that the HVE Core VS Code extension is installed.
.DESCRIPTION
    Checks the installed extensions list for ise-hve-essentials.hve-core
    and reports version information.
.PARAMETER CodeCli
    Path or name of the VS Code CLI executable. Defaults to 'code'.
.EXAMPLE
    ./scripts/validate-extension.ps1
.EXAMPLE
    ./scripts/validate-extension.ps1 -CodeCli 'code-insiders'
.OUTPUTS
    EXTENSION_INSTALLED=True/False and version details.
#>
[CmdletBinding()]
param(
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [string]$CodeCli = 'code'
)

$ErrorActionPreference = 'Stop'

# Check if extension is installed
$extensions = & $codeCli --list-extensions 2>$null
if ($extensions -match "ise-hve-essentials.hve-core") {
    Write-Host "✅ HVE Core extension installed successfully"
    $installed = $true
} else {
    Write-Host "❌ Extension not found in installed extensions"
    $installed = $false
}

# Verify version (optional)
$versionOutput = & $codeCli --list-extensions --show-versions 2>$null | Select-String "ise-hve-essentials.hve-core"
if ($versionOutput) {
    Write-Host "📌 Version: $($versionOutput -replace '.*@', '')"
}

Write-Host "EXTENSION_INSTALLED=$installed"
