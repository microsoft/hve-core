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

.PARAMETER Verbose
    Enable verbose output.

.EXAMPLE
    ./Invoke-ExportSvg.ps1 -InputPath deck.pptx -OutputDir svg/
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$OutputDir,
    [string]$Slides,
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillRoot = Split-Path -Parent $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

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
$args_ = @($script, '--input', $InputPath, '--output-dir', $OutputDir)
if ($Slides) { $args_ += '--slides'; $args_ += $Slides }
if ($VerbosePreference -eq 'Continue') { $args_ += '-v' }

& $python @args_
exit $LASTEXITCODE
