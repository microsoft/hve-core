#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Embed WAV audio files into a PowerPoint deck.

.DESCRIPTION
    Wrapper script that manages the Python virtual environment and invokes
    embed_audio.py to embed per-slide WAV files into a PPTX presentation.

.PARAMETER InputPath
    Input PPTX file path.

.PARAMETER AudioDir
    Directory containing slide-NNN.wav files.

.PARAMETER OutputPath
    Output PPTX file path.

.PARAMETER Slides
    Comma-separated slide numbers to embed audio on (optional).

.PARAMETER SkipVenvSetup
    Skip virtual environment setup.

.PARAMETER Verbose
    Enable verbose output.

.EXAMPLE
    ./Invoke-EmbedAudio.ps1 -InputPath deck.pptx -AudioDir voice-over/ -OutputPath out.pptx
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][string]$InputPath,
    [Parameter(Mandatory = $true)][string]$AudioDir,
    [Parameter(Mandatory = $true)][string]$OutputPath,
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

$script = Join-Path $ScriptDir 'embed_audio.py'
$args_ = @($script, '--input', $InputPath, '--audio-dir', $AudioDir, '--output', $OutputPath)
if ($Slides) { $args_ += '--slides'; $args_ += $Slides }
if ($VerbosePreference -eq 'Continue') { $args_ += '-v' }

& $python @args_
exit $LASTEXITCODE
