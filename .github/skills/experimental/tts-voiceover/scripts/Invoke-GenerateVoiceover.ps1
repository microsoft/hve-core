#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4
#
# Invoke-GenerateVoiceover.ps1
#
# Purpose: Wrapper that manages uv venv setup and delegates to generate_voiceover.py

<#
.SYNOPSIS
    Generates per-slide TTS voice-over from YAML speaker notes via Azure Speech SDK.

.DESCRIPTION
    Manages the Python virtual environment and invokes generate_voiceover.py to
    produce per-slide WAV files from YAML speaker notes with SSML acronym aliases.

.PARAMETER DryRun
    Print SSML templates without generating audio.

.PARAMETER Engine
    Synthesis engine: azure (default) or piper. Piper must be installed separately.

.PARAMETER Voice
    Voice name. Defaults to en-US-Andrew:DragonHDLatestNeural for azure and
    en_US-joe-medium for piper.

.PARAMETER Rate
    Speech prosody rate. Defaults to +10%.

.PARAMETER ContentDir
    Path to slide content directory. Defaults to content.

.PARAMETER OutputDir
    Path to WAV output directory. Defaults to voice-over.

.PARAMETER Lexicon
    Path to custom acronyms.yaml lexicon file.

.PARAMETER CollapseNewlines
    Collapse newlines and runs of whitespace in speaker notes into single spaces before synthesis.

.PARAMETER SkipVenvSetup
    Skip virtual environment creation and dependency installation.

.EXAMPLE
    ./Invoke-GenerateVoiceover.ps1 -DryRun -ContentDir content

.EXAMPLE
    ./Invoke-GenerateVoiceover.ps1 -ContentDir content -OutputDir voice-over

.EXAMPLE
    ./Invoke-GenerateVoiceover.ps1 -ContentDir content -Voice "en-US-Jenny:DragonHDLatestNeural" -Rate "+5%"

.NOTES
    Part of the tts-voiceover skill. Manages uv virtual environment setup
    and delegates to generate_voiceover.py for TTS audio generation.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$DryRun,

    [Parameter(Mandatory = $false)]
    [ValidateSet('azure', 'piper')]
    [string]$Engine,

    [Parameter(Mandatory = $false)]
    [string]$Voice,

    [Parameter(Mandatory = $false)]
    [string]$Rate,

    [Parameter(Mandatory = $false)]
    [string]$ContentDir,

    [Parameter(Mandatory = $false)]
    [string]$OutputDir,

    [Parameter(Mandatory = $false)]
    [string]$Lexicon,

    [Parameter(Mandatory = $false)]
    [switch]$CollapseNewlines,

    [Parameter(Mandatory = $false)]
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

Import-Module (Join-Path $ScriptDir 'Modules/TtsVoiceoverHelpers.psm1') -Force

function Get-VoiceoverArgument {
    <#
    .SYNOPSIS
        Builds the generate_voiceover.py argument list from wrapper parameters.
    .OUTPUTS
        [string[]] Discrete arguments; an omitted parameter adds nothing.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [switch]$DryRun,
        [string]$Engine,
        [string]$Voice,
        [string]$Rate,
        [string]$ContentDir,
        [string]$OutputDir,
        [string]$Lexicon,
        [switch]$CollapseNewlines,
        [switch]$VerboseOutput
    )

    $arguments = [System.Collections.Generic.List[string]]::new()
    if ($DryRun) { $arguments.Add('--dry-run') }
    if ($Engine) { $arguments.AddRange([string[]]@('--engine', $Engine)) }
    if ($Voice) { $arguments.AddRange([string[]]@('--voice', $Voice)) }
    if ($Rate) { $arguments.AddRange([string[]]@('--rate', $Rate)) }
    if ($ContentDir) { $arguments.AddRange([string[]]@('--content-dir', $ContentDir)) }
    if ($OutputDir) { $arguments.AddRange([string[]]@('--output-dir', $OutputDir)) }
    if ($Lexicon) { $arguments.AddRange([string[]]@('--lexicon', $Lexicon)) }
    if ($CollapseNewlines) { $arguments.Add('--collapse-newlines') }
    if ($VerboseOutput) { $arguments.Add('--verbose') }
    return , $arguments.ToArray()
}

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

    $script = Join-Path $ScriptDir 'generate_voiceover.py'
    $PythonArgs = Get-VoiceoverArgument -DryRun:$DryRun -Engine $Engine -Voice $Voice `
        -Rate $Rate -ContentDir $ContentDir -OutputDir $OutputDir -Lexicon $Lexicon `
        -CollapseNewlines:$CollapseNewlines `
        -VerboseOutput:($VerbosePreference -ne 'SilentlyContinue')

    & $python $script @PythonArgs
    if ($LASTEXITCODE -ne 0) {
        throw "generate_voiceover.py exited with code $LASTEXITCODE"
    }

}

#endregion Main
