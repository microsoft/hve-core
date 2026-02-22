#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the marketplace.json manifest for Copilot CLI plugins.

.DESCRIPTION
    Reads .github/plugin/marketplace.json and validates JSON schema compliance,
    plugin source directory existence, name-source consistency, version
    consistency with the root package.json, and absence of path separators
    in source values.

.EXAMPLE
    ./Validate-Marketplace.ps1
#>

[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Validation Helpers

function Test-PluginSourceDirectory {
    <#
    .SYNOPSIS
        Validates that a plugin source directory exists under the plugins root.

    .PARAMETER Source
        Plugin source value from marketplace.json.

    .PARAMETER PluginsRoot
        Absolute path to the plugins directory.

    .OUTPUTS
        [string] Error message if directory not found, empty string if valid.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source,

        [Parameter(Mandatory = $true)]
        [string]$PluginsRoot
    )

    $pluginDir = Join-Path -Path $PluginsRoot -ChildPath $Source
    if (-not (Test-Path -Path $pluginDir -PathType Container)) {
        return "plugin source directory not found: plugins/$Source"
    }

    return ''
}

function Test-PluginSourceFormat {
    <#
    .SYNOPSIS
        Validates that a plugin source contains no path separators.

    .PARAMETER Source
        Plugin source value from marketplace.json.

    .OUTPUTS
        [string] Error message if source contains path separators, empty string if valid.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Source
    )

    if ($Source -match '[/\\]') {
        return "plugin source '$Source' must not contain path separators"
    }

    if ($Source -match '^\./') {
        return "plugin source '$Source' must not contain relative path prefix"
    }

    return ''
}

#endregion Validation Helpers

#region Orchestration

function Invoke-MarketplaceValidation {
    <#
    .SYNOPSIS
        Validates the marketplace.json manifest.

    .DESCRIPTION
        Validates the marketplace manifest against its JSON schema and performs
        cross-validation checks including source directory existence,
        name-source consistency, version consistency, and source format.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .OUTPUTS
        Hashtable with Success bool and ErrorCount int.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $manifestPath = Join-Path -Path $RepoRoot -ChildPath '.github' -AdditionalChildPath 'plugin', 'marketplace.json'

    if (-not (Test-Path -Path $manifestPath)) {
        Write-Host '  FAIL marketplace.json not found' -ForegroundColor Red
        return @{ Success = $false; ErrorCount = 1 }
    }

    Write-Host 'Validating marketplace.json...'

    $errorCount = 0
    $errors = @()

    # Parse JSON
    try {
        $manifestContent = Get-Content -Path $manifestPath -Raw
        $manifest = $manifestContent | ConvertFrom-Json -AsHashtable
    }
    catch {
        $errors += "invalid JSON: $($_.Exception.Message)"
        foreach ($err in $errors) {
            Write-Host "    x $err" -ForegroundColor Red
        }
        return @{ Success = $false; ErrorCount = 1 }
    }

    # Required top-level fields
    $requiredFields = @('name', 'metadata', 'owner', 'plugins')
    foreach ($field in $requiredFields) {
        if (-not $manifest.ContainsKey($field) -or $null -eq $manifest[$field]) {
            $errors += "missing required field '$field'"
        }
    }

    if ($errors.Count -gt 0) {
        foreach ($err in $errors) {
            Write-Host "    x $err" -ForegroundColor Red
        }
        return @{ Success = $false; ErrorCount = $errors.Count }
    }

    # Metadata validation
    $metadataRequired = @('description', 'version', 'pluginRoot')
    foreach ($field in $metadataRequired) {
        if (-not $manifest.metadata.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$manifest.metadata[$field])) {
            $errors += "missing required metadata field '$field'"
        }
    }

    # Owner validation
    if (-not $manifest.owner.ContainsKey('name') -or [string]::IsNullOrWhiteSpace([string]$manifest.owner.name)) {
        $errors += "missing required owner field 'name'"
    }

    # Version consistency with package.json
    $packageJsonPath = Join-Path -Path $RepoRoot -ChildPath 'package.json'
    $expectedVersion = $null
    if (Test-Path -Path $packageJsonPath) {
        $packageJson = Get-Content -Path $packageJsonPath -Raw | ConvertFrom-Json
        $expectedVersion = $packageJson.version
        if ($manifest.metadata.version -ne $expectedVersion) {
            $errors += "metadata.version '$($manifest.metadata.version)' does not match package.json version '$expectedVersion'"
        }
    }

    # Plugins validation
    if ($manifest.plugins -isnot [array] -or $manifest.plugins.Count -eq 0) {
        $errors += 'plugins array is empty or missing'
    }
    else {
        $pluginsRoot = Join-Path -Path $RepoRoot -ChildPath 'plugins'
        $seenNames = @{}

        foreach ($plugin in $manifest.plugins) {
            $pluginName = $plugin.name

            # Required plugin fields
            $pluginRequired = @('name', 'source', 'description', 'version')
            foreach ($field in $pluginRequired) {
                if (-not $plugin.ContainsKey($field) -or [string]::IsNullOrWhiteSpace([string]$plugin[$field])) {
                    $errors += "plugin '$pluginName': missing required field '$field'"
                }
            }

            # Duplicate name check
            if ($seenNames.ContainsKey($pluginName)) {
                $errors += "duplicate plugin name '$pluginName'"
            }
            else {
                $seenNames[$pluginName] = $true
            }

            # Source format (no path separators)
            if (-not [string]::IsNullOrWhiteSpace($plugin.source)) {
                $formatError = Test-PluginSourceFormat -Source $plugin.source
                if ($formatError) {
                    $errors += "plugin '$pluginName': $formatError"
                }
            }

            # Source directory existence
            if (-not [string]::IsNullOrWhiteSpace($plugin.source)) {
                $dirError = Test-PluginSourceDirectory -Source $plugin.source -PluginsRoot $pluginsRoot
                if ($dirError) {
                    $errors += "plugin '$pluginName': $dirError"
                }
            }

            # Name-source consistency
            if ($pluginName -ne $plugin.source) {
                $errors += "plugin '$pluginName': name does not match source '$($plugin.source)'"
            }

            # Plugin version consistency
            if ($expectedVersion -and $plugin.version -ne $expectedVersion) {
                $errors += "plugin '$pluginName': version '$($plugin.version)' does not match package.json version '$expectedVersion'"
            }
        }
    }

    $errorCount = $errors.Count

    if ($errorCount -gt 0) {
        Write-Host "  FAIL marketplace.json - $errorCount error(s)" -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host "      $err" -ForegroundColor Red
        }
    }
    else {
        Write-Host "  OK marketplace.json ($($manifest.plugins.Count) plugins)"
    }

    return @{
        Success    = ($errorCount -eq 0)
        ErrorCount = $errorCount
    }
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName

        $result = Invoke-MarketplaceValidation -RepoRoot $RepoRoot

        if (-not $result.Success) {
            throw "Marketplace validation failed with $($result.ErrorCount) error(s)."
        }

        exit 0
    }
    catch {
        Write-Error "Marketplace validation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
