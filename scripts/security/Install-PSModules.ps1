#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

<#
.SYNOPSIS
    Installs PowerShell modules declared in ps-module-versions.json with retry.
.DESCRIPTION
    Reads the pinned module manifest and installs each module at the declared
    version. Modules already present at the correct version are skipped unless
    -Force is specified. Transient PSGallery failures are retried with
    exponential backoff.

    Colocation rationale: this script lives in scripts/security/ because it
    consumes ps-module-versions.json (the pinned-version manifest that the
    security scanners enforce) and its correct operation is a supply-chain
    security concern.
.PARAMETER ConfigPath
    Path to the JSON version manifest. Defaults to
    scripts/security/ps-module-versions.json resolved relative to the
    repository root. Overridable via PS_MODULE_CONFIG_PATH env var.
.PARAMETER Scope
    Install-Module scope (CurrentUser or AllUsers). Defaults to CurrentUser.
    Overridable via PS_MODULE_SCOPE env var.
.PARAMETER Repository
    PowerShell repository name. Defaults to PSGallery.
.PARAMETER Import
    Import each module into the current session after installation.
.PARAMETER Force
    Re-install modules even when the correct version is already present.
.PARAMETER MaxAttempts
    Maximum retry attempts per module. Defaults to 3.
.PARAMETER BaseDelaySeconds
    Initial backoff delay in seconds; doubles each retry. Defaults to 10.
.EXAMPLE
    ./scripts/security/Install-PSModules.ps1
    Installs all pinned modules for the current user.
.EXAMPLE
    ./scripts/security/Install-PSModules.ps1 -Import
    Installs and imports all pinned modules.
.EXAMPLE
    ./scripts/security/Install-PSModules.ps1 -Scope AllUsers -Import
    Installs system-wide and imports (requires elevation on Linux/macOS).
.NOTES
    Called by: .github/actions/setup-ps-modules/action.yml
    Called by: .devcontainer/scripts/on-create.sh (planned)
    Called by: .github/workflows/copilot-setup-steps.yml (planned)
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ConfigPath,

    [Parameter(Mandatory = $false)]
    [ValidateSet('CurrentUser', 'AllUsers')]
    [string]$Scope,

    [Parameter(Mandatory = $false)]
    [string]$Repository = 'PSGallery',

    [Parameter(Mandatory = $false)]
    [switch]$Import,

    [Parameter(Mandatory = $false)]
    [switch]$Force,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 10)]
    [int]$MaxAttempts = 3,

    [Parameter(Mandatory = $false)]
    [ValidateRange(1, 120)]
    [int]$BaseDelaySeconds = 10
)

$ErrorActionPreference = 'Stop'

#region Functions

function Resolve-ConfigPath {
    <#
    .SYNOPSIS
        Resolves the module manifest path from parameter, env var, or default.
    .OUTPUTS
        [string] Absolute path to the config file.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Explicit
    )

    if ($Explicit) { return $Explicit }
    if ($env:PS_MODULE_CONFIG_PATH) { return $env:PS_MODULE_CONFIG_PATH }

    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) { $repoRoot = Split-Path $PSScriptRoot }
    return Join-Path $repoRoot 'scripts/security/ps-module-versions.json'
}

function Resolve-Scope {
    <#
    .SYNOPSIS
        Resolves the install scope from parameter, env var, or default.
    .OUTPUTS
        [string] CurrentUser or AllUsers.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Explicit
    )

    if ($Explicit) { return $Explicit }
    if ($env:PS_MODULE_SCOPE) { return $env:PS_MODULE_SCOPE }
    return 'CurrentUser'
}

function Test-ModulePresent {
    <#
    .SYNOPSIS
        Checks whether a module at the required version is already available.
    .OUTPUTS
        [bool] True if the module is present at the specified version.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version
    )

    $installed = Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue |
        Where-Object { $_.Version -eq [version]$Version }
    return [bool]$installed
}

function Install-SingleModule {
    <#
    .SYNOPSIS
        Installs a single module with exponential-backoff retry.
    .OUTPUTS
        [void]
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Version,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Scope,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Repository,

        [Parameter(Mandatory = $true)]
        [int]$MaxAttempts,

        [Parameter(Mandatory = $true)]
        [int]$BaseDelaySeconds
    )

    $isCI = $env:GITHUB_ACTIONS -eq 'true'

    for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
        try {
            Install-Module -Name $Name -RequiredVersion $Version -Force -Scope $Scope -Repository $Repository -ErrorAction Stop
            Write-Host "✅ Installed $Name $Version (attempt $attempt)" -ForegroundColor Green
            return
        }
        catch {
            if ($attempt -eq $MaxAttempts) {
                $msg = "Failed to install $Name $Version after $MaxAttempts attempts: $($_.Exception.Message)"
                if ($isCI) {
                    Write-Host "::error::$msg"
                }
                throw $msg
            }
            $delay = $BaseDelaySeconds * [math]::Pow(2, $attempt - 1)
            $warnMsg = "Attempt $attempt/$MaxAttempts failed for ${Name}: $($_.Exception.Message). Retrying in ${delay}s..."
            if ($isCI) {
                Write-Host "::warning::$warnMsg"
            }
            Write-Host "⚠️  $warnMsg" -ForegroundColor Yellow
            Start-Sleep -Seconds $delay
        }
    }
}

function Invoke-PSModuleInstall {
    <#
    .SYNOPSIS
        Orchestrates module installation from a JSON config file.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ConfigPath,

        [Parameter()]
        [string]$Scope = 'CurrentUser',

        [Parameter()]
        [string]$Repository = 'PSGallery',

        [Parameter()]
        [switch]$Import,

        [Parameter()]
        [switch]$Force,

        [Parameter()]
        [int]$MaxAttempts = 3,

        [Parameter()]
        [int]$BaseDelaySeconds = 10
    )

    $resolvedConfig = Resolve-ConfigPath -Explicit $ConfigPath
    $resolvedScope = Resolve-Scope -Explicit $Scope

    if (-not (Test-Path $resolvedConfig)) {
        throw "Config file not found: $resolvedConfig"
    }

    $config = Get-Content -Raw $resolvedConfig | ConvertFrom-Json
    $modules = $config.modules.PSObject.Properties
    $totalCount = ($modules | Measure-Object).Count
    $installedCount = 0
    $skippedCount = 0

    Write-Host "Installing $totalCount module(s) from $resolvedConfig (scope: $resolvedScope)" -ForegroundColor Cyan

    foreach ($prop in $modules) {
        $name = $prop.Name
        $version = $prop.Value.version

        if (-not $Force -and (Test-ModulePresent -Name $name -Version $version)) {
            Write-Host "⏭️  $name $version already installed, skipping" -ForegroundColor DarkGray
            $skippedCount++
        }
        else {
            Install-SingleModule -Name $name -Version $version -Scope $resolvedScope `
                -Repository $Repository -MaxAttempts $MaxAttempts -BaseDelaySeconds $BaseDelaySeconds
            $installedCount++
        }

        if ($Import) {
            Import-Module -Name $name -RequiredVersion $version -Force -ErrorAction Stop
            Write-Host "📦 Imported $name $version" -ForegroundColor DarkCyan
        }
    }

    Write-Host "✅ Done: $installedCount installed, $skippedCount skipped" -ForegroundColor Green
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $resolvedConfig = Resolve-ConfigPath -Explicit $ConfigPath
        $resolvedScope = Resolve-Scope -Explicit $Scope
        Invoke-PSModuleInstall -ConfigPath $resolvedConfig -Scope $resolvedScope -Repository $Repository `
            -MaxAttempts $MaxAttempts -BaseDelaySeconds $BaseDelaySeconds `
            -Import:$Import -Force:$Force
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Install-PSModules failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main Execution
