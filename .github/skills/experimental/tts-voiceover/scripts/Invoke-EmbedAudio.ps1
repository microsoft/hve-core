#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

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
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$InputPath,

    [Parameter()]
    [string]$AudioDir,

    [Parameter()]
    [string]$OutputPath,

    [Parameter()]
    [switch]$SkipVenvSetup
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

#region Environment Setup

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

    Write-Host 'Syncing Python environment via uv...'
    & uv sync --directory $SkillRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'Failed to sync Python environment via uv.'
    }
    Write-Host 'Environment synchronized.'
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

#endregion

#region Main

$null = Test-UvAvailability

if (-not $SkipVenvSetup) {
    Initialize-PythonEnvironment
}

$python = Get-VenvPythonPath
if (-not (Test-Path $python)) {
    throw "Python not found at $python. Run without -SkipVenvSetup to initialize."
}

$script = Join-Path $ScriptDir 'embed_audio.py'
$args_ = @('--input', $InputPath)

if ($AudioDir) { $args_ += '--audio-dir', $AudioDir }
if ($OutputPath) { $args_ += '--output', $OutputPath }

& $python $script @args_
if ($LASTEXITCODE -ne 0) {
    throw "embed_audio.py exited with code $LASTEXITCODE"
}

#endregion
