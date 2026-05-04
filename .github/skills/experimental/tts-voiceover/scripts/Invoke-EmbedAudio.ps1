#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
#
# Invoke-EmbedAudio.ps1
#
# Purpose: Wrapper that manages uv venv setup and delegates to embed_audio.py

<#
.SYNOPSIS
    Embeds per-slide WAV voice-over files into a PowerPoint deck.

.DESCRIPTION
    Manages the Python virtual environment and invokes embed_audio.py to add
    WAV files as embedded media objects in the corresponding slides of a PPTX file.

.PARAMETER InputPath
    Source PPTX file path. Required.

.PARAMETER AudioDir
    Directory containing slide-NNN.wav files. Defaults to voice-over.

.PARAMETER OutputPath
    Output PPTX file path. Defaults to input stem + '-narrated.pptx'.

.PARAMETER SkipVenvSetup
    Skip virtual environment creation and dependency installation.

.EXAMPLE
    ./Invoke-EmbedAudio.ps1 -InputPath deck.pptx -AudioDir voice-over

.EXAMPLE
    ./Invoke-EmbedAudio.ps1 -InputPath deck.pptx -AudioDir voice-over -OutputPath deck-narrated.pptx

.NOTES
    Part of the tts-voiceover skill. Manages uv virtual environment setup
    and delegates to embed_audio.py for WAV embedding into PPTX slides.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [ValidateNotNullOrEmpty()]
    [string]$InputPath,

    [Parameter(Mandatory = $false)]
    [string]$AudioDir,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

Import-Module (Join-Path $ScriptDir 'Modules/TtsVoiceoverHelpers.psm1') -Force

#region Main

if ($MyInvocation.InvocationName -ne '.') {

    $null = Test-UvAvailability

    if (-not $SkipVenvSetup) {
        Initialize-PythonEnvironment -SkillRoot $SkillRoot
    }

    $python = Get-VenvPythonPath -VenvDir $VenvDir
    if (-not (Test-Path $python)) {
        throw "Python not found at $python. Run without -SkipVenvSetup to initialize."
    }

    $script = Join-Path $ScriptDir 'embed_audio.py'
    $PythonArgs = @('--input', $InputPath)

    if ($AudioDir) { $PythonArgs += '--audio-dir', $AudioDir }
    if ($OutputPath) { $PythonArgs += '--output', $OutputPath }
    if ($VerbosePreference -ne 'SilentlyContinue') { $PythonArgs += '--verbose' }

    & $python $script @PythonArgs
    if ($LASTEXITCODE -ne 0) {
        throw "embed_audio.py exited with code $LASTEXITCODE"
    }

}

#endregion Main
