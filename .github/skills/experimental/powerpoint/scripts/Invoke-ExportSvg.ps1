#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Export PowerPoint slides to SVG images.

.DESCRIPTION
    Wrapper script that manages the Python virtual environment and invokes
    export_svg.py to convert PPTX slides to SVG via LibreOffice and PyMuPDF.

.PARAMETER InputPath
    Input PPTX file path.

.PARAMETER OutputDir
    Output directory for SVG files.

.PARAMETER Slides
    Comma-separated slide numbers to export (optional).

.PARAMETER SkipVenvSetup
    Skip virtual environment setup.

.EXAMPLE
    ./Invoke-ExportSvg.ps1 -InputPath deck.pptx -OutputDir svg/

.NOTES
    Part of the powerpoint skill. Manages uv virtual environment setup
    and delegates to export_svg.py for PPTX-to-SVG conversion.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InputPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$OutputDir,
    [Parameter(Mandatory = $false)][string]$Slides,
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

function Invoke-ExportSvg {
    <#
    .SYNOPSIS
        Runs export_svg.py with the provided parameters.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $script = Join-Path $ScriptDir 'export_svg.py'

    $arguments = @(
        $script,
        '--input', $InputPath,
        '--output-dir', $OutputDir
    )
    if ($Slides) {
        $arguments += '--slides'
        $arguments += $Slides
    }
    if ($VerbosePreference -eq 'Continue') {
        $arguments += '-v'
    }

    & $python @arguments
    if ($LASTEXITCODE -ne 0) {
        throw "export_svg.py failed with exit code $LASTEXITCODE."
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
        Invoke-ExportSvg
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-ExportSvg failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main
