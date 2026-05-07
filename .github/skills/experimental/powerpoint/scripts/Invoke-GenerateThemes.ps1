#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
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

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

#endregion Environment Setup

#region Main

if ($MyInvocation.InvocationName -ne '.') {

    try {
        if (-not $SkipVenvSetup) {
            if (-not (Get-Command uv -ErrorAction SilentlyContinue)) {
                throw 'uv is required but was not found on PATH.'
            }
            uv sync --directory $SkillRoot
        }

        $python = if (Test-Path (Join-Path $VenvDir 'Scripts/python.exe')) {
            Join-Path $VenvDir 'Scripts/python.exe'
        } elseif (Test-Path (Join-Path $VenvDir 'bin/python')) {
            Join-Path $VenvDir 'bin/python'
        } else {
            throw "Python interpreter not found in venv. Run: uv sync --directory `"$SkillRoot`""
        }

        $script = Join-Path $ScriptDir 'generate_themes.py'
        $ScriptArgs = @($script, '--content-dir', $ContentDir, '--themes', $ThemesPath, '--output-dir', $OutputDir)
        if ($VerbosePreference -eq 'Continue') { $ScriptArgs += '-v' }

        & $python @ScriptArgs
        exit $LASTEXITCODE
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-GenerateThemes failed: $($_.Exception.Message)"
        exit 1
    }

}

#endregion Main
