<#
.SYNOPSIS
    Validates an HVE-Core clone-based installation.
.DESCRIPTION
    Checks that required directories exist and method-specific configuration
    is correct (workspace file for multi-root, .gitmodules for submodule).
.NOTES
    Set $method (1-6) and $basePath before running.
.OUTPUTS
    Per-directory pass/fail status and overall validation result.
#>
$ErrorActionPreference = 'Stop'

if (-not $basePath) { throw "Variable `$basePath must be set per method table above" }
if (-not $method) { throw "Variable `$method must be set (1-6)" }

$valid = $true
foreach ($dir in @("$basePath/.github/agents", "$basePath/.github/prompts", "$basePath/.github/instructions")) {
    if (-not (Test-Path $dir)) { $valid = $false; Write-Host "❌ Missing: $dir" }
    else { Write-Host "✅ Found: $dir" }
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
