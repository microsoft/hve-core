#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4

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

.EXAMPLE
    ./Invoke-EmbedAudio.ps1 -InputPath deck.pptx -AudioDir voice-over/ -OutputPath out.pptx

.NOTES
    Part of the powerpoint skill. Manages uv virtual environment setup
    and delegates to embed_audio.py for WAV embedding into PPTX slides.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$InputPath,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$AudioDir,
    [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$OutputPath,
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

function Invoke-EmbedAudio {
    <#
    .SYNOPSIS
        Runs embed_audio.py with the provided parameters.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param()

    $python = Get-VenvPythonPath
    $script = Join-Path $ScriptDir 'embed_audio.py'

    $arguments = @(
        $script,
        '--input', $InputPath,
        '--audio-dir', $AudioDir,
        '--output', $OutputPath
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
        throw "embed_audio.py failed with exit code $LASTEXITCODE."
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
        Invoke-EmbedAudio
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-EmbedAudio failed: $($_.Exception.Message)"
        exit 1
    }
}

#endregion Main
