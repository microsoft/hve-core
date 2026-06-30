#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Generate themed content directory variants from a base deck.

.DESCRIPTION
    Wrapper script that manages the Python virtual environment and invokes
    generate_themes.py to produce themed content copies with remapped colors.

.PARAMETER ContentDir
    Path to the base theme's content directory.

.PARAMETER ThemesPath
    Path to a YAML file defining theme color mappings.

.PARAMETER OutputDir
    Parent directory where themed content directories are created.

.PARAMETER SkipVenvSetup
    Skip virtual environment setup.

.EXAMPLE
    ./Invoke-GenerateThemes.ps1 -ContentDir content/ -ThemesPath themes.yaml -OutputDir ../

.NOTES
    Part of the powerpoint skill. Manages uv virtual environment setup
    and delegates to generate_themes.py for themed content generation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ContentDir,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$ThemesPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$OutputDir,
    [Parameter(Mandatory = $false)][switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

#region Environment Setup

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path -Parent $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

#endregion Environment Setup

#region Environment Functions

function Test-UvAvailability {
    <#
    .SYNOPSIS
        Verifies uv is available on PATH.
    .OUTPUTS
        [string] The resolved uv command path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $resolved = Get-Command 'uv' -ErrorAction SilentlyContinue
    if ($resolved) {
        return $resolved.Source
    }
    throw 'uv is required but was not found on PATH. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh'
}

function Initialize-PythonEnvironment {
    <#
    .SYNOPSIS
        Syncs the Python virtual environment and dependencies via uv.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    & uv sync --directory $SkillRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to sync Python environment via uv.'
    }
}

function Get-VenvPythonPath {
    <#
    .SYNOPSIS
        Returns the path to the venv Python executable.
    .OUTPUTS
        [string] Absolute path to the venv python binary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if ($IsWindows) {
        return Join-Path $VenvDir 'Scripts/python.exe'
    }
    return Join-Path $VenvDir 'bin/python'
}

#endregion Environment Functions

#region Script Execution

function Invoke-GenerateThemes {
    <#
    .SYNOPSIS
        Runs generate_themes.py with the provided parameters.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $script = Join-Path $ScriptDir 'generate_themes.py'

    $arguments = @(
        $script,
        '--content-dir', $ContentDir,
        '--themes', $ThemesPath,
        '--output-dir', $OutputDir
    )
    if ($VerbosePreference -eq 'Continue') {
        $arguments += '-v'
    }

    & $python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "generate_themes.py failed with exit code $LASTEXITCODE."
    }
}

#endregion Script Execution

#region Main

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not $SkipVenvSetup) {
            Test-UvAvailability | Out-Null
            Initialize-PythonEnvironment
        }
        Invoke-GenerateThemes
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-GenerateThemes failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main
