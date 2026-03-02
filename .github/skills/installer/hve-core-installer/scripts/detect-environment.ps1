<#
.SYNOPSIS
    Detects the current development environment for HVE-Core installation.
.DESCRIPTION
    Identifies whether the user is in a local VS Code, devcontainer, or Codespaces
    environment and reports relevant configuration details.
.OUTPUTS
    Key-value pairs: ENV_TYPE, IS_CODESPACES, IS_DEVCONTAINER,
    HAS_DEVCONTAINER_JSON, HAS_WORKSPACE_FILE, IS_HVE_CORE_REPO.
#>
$ErrorActionPreference = 'Stop'

# Detect environment type
$env_type = "local"
$is_codespaces = $false
$is_devcontainer = $false

if ($env:CODESPACES -eq "true") {
    $env_type = "codespaces"
    $is_codespaces = $true
    $is_devcontainer = $true
} elseif ((Test-Path "/.dockerenv") -or ($env:REMOTE_CONTAINERS -eq "true")) {
    $env_type = "devcontainer"
    $is_devcontainer = $true
}

$has_devcontainer_json = Test-Path ".devcontainer/devcontainer.json"
$has_workspace_file = (Get-ChildItem -Filter "*.code-workspace" -ErrorAction SilentlyContinue | Measure-Object).Count -gt 0
try {
    $is_hve_core_repo = (Split-Path (git rev-parse --show-toplevel 2>$null) -Leaf) -eq "hve-core"
} catch {
    $is_hve_core_repo = $false
}

Write-Host "ENV_TYPE=$env_type"
Write-Host "IS_CODESPACES=$is_codespaces"
Write-Host "IS_DEVCONTAINER=$is_devcontainer"
Write-Host "HAS_DEVCONTAINER_JSON=$has_devcontainer_json"
Write-Host "HAS_WORKSPACE_FILE=$has_workspace_file"
Write-Host "IS_HVE_CORE_REPO=$is_hve_core_repo"
