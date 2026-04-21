#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates per-slide TTS voice-over from YAML speaker notes via Azure Speech SDK.

.DESCRIPTION
    Manages the Python virtual environment and invokes generate_voiceover.py to
    produce per-slide WAV files from YAML speaker notes with SSML acronym aliases.

.PARAMETER DryRun
    Print SSML templates without generating audio.

.PARAMETER Voice
    Azure TTS voice name. Defaults to en-US-Andrew:DragonHDLatestNeural.

.PARAMETER Rate
    Speech prosody rate. Defaults to +10%.

.PARAMETER ContentDir
    Path to slide content directory. Defaults to content.

.PARAMETER OutputDir
    Path to WAV output directory. Defaults to voice-over.

.PARAMETER Lexicon
    Path to custom acronyms.yaml lexicon file.

.PARAMETER SkipVenvSetup
    Skip virtual environment creation and dependency installation.

.EXAMPLE
    ./Invoke-GenerateVoiceover.ps1 -DryRun -ContentDir content

.EXAMPLE
    ./Invoke-GenerateVoiceover.ps1 -ContentDir content -OutputDir voice-over

.EXAMPLE
    ./Invoke-GenerateVoiceover.ps1 -ContentDir content -Voice "en-US-Jenny:DragonHDLatestNeural" -Rate "+5%"
#>

[CmdletBinding()]
param(
    [Parameter()]
    [switch]$DryRun,

    [Parameter()]
    [string]$Voice,

    [Parameter()]
    [string]$Rate,

    [Parameter()]
    [string]$ContentDir,

    [Parameter()]
    [string]$OutputDir,

    [Parameter()]
    [string]$Lexicon,

    [Parameter()]
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

Import-Module (Join-Path $ScriptDir 'Modules/TtsVoiceoverHelpers.psm1') -Force

#region Main

$null = Test-UvAvailability

if (-not $SkipVenvSetup) {
    Initialize-PythonEnvironment -SkillRoot $SkillRoot
}

$python = Get-VenvPythonPath -VenvDir $VenvDir
if (-not (Test-Path $python)) {
    throw "Python not found at $python. Run without -SkipVenvSetup to initialize."
}

$script = Join-Path $ScriptDir 'generate_voiceover.py'
$args_ = @()

if ($DryRun) { $args_ += '--dry-run' }
if ($Voice) { $args_ += '--voice', $Voice }
if ($Rate) { $args_ += '--rate', $Rate }
if ($ContentDir) { $args_ += '--content-dir', $ContentDir }
if ($OutputDir) { $args_ += '--output-dir', $OutputDir }
if ($Lexicon) { $args_ += '--lexicon', $Lexicon }

& $python $script @args_
if ($LASTEXITCODE -ne 0) {
    throw "generate_voiceover.py exited with code $LASTEXITCODE"
}

#endregion
