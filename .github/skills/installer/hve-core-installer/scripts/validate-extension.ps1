<#
.SYNOPSIS
    Validates that the HVE Core VS Code extension is installed.
.DESCRIPTION
    Checks the installed extensions list for ise-hve-essentials.hve-core
    and reports version information.
.NOTES
    Set $codeCli to 'code' or 'code-insiders' before running.
.OUTPUTS
    EXTENSION_INSTALLED=True/False and version details.
#>
$ErrorActionPreference = 'Stop'

# Set based on user's earlier choice: 'code' or 'code-insiders'
if (-not $codeCli) { $codeCli = "code" }

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
