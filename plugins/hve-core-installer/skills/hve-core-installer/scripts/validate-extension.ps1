# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.
#
# Validates the HVE Core VS Code extension installation.
# Usage: validate-extension.ps1 -CodeCli <code_cli>
#   CodeCli: 'code' or 'code-insiders'

[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('code', 'code-insiders')]
    [string]$CodeCli
)

$ErrorActionPreference = 'Stop'

# Check if extension is installed
$extensions = & $CodeCli --list-extensions 2>$null
if ($extensions -match "ise-hve-essentials.hve-core") {
    Write-Host "✅ HVE Core extension installed successfully"
    $installed = $true
} else {
    Write-Host "❌ Extension not found in installed extensions"
    $installed = $false
}

# Verify version (optional)
$versionOutput = & $CodeCli --list-extensions --show-versions 2>$null | Select-String "ise-hve-essentials.hve-core"
if ($versionOutput) {
    Write-Host "📌 Version: $($versionOutput -replace '.*@', '')"
}

Write-Host "EXTENSION_INSTALLED=$installed"
