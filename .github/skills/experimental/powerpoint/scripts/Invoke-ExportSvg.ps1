#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
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

        $script = Join-Path $ScriptDir 'export_svg.py'
        $ScriptArgs = @($script, '--input', $InputPath, '--output-dir', $OutputDir)
        if ($Slides) { $ScriptArgs += '--slides'; $ScriptArgs += $Slides }
        if ($VerbosePreference -eq 'Continue') { $ScriptArgs += '-v' }

        & $python @ScriptArgs
        exit $LASTEXITCODE
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-ExportSvg failed: $($_.Exception.Message)"
        exit 1
    }

}

#endregion Main
