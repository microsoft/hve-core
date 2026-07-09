#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0
#
# Invoke-AssembleVideo.ps1
# Wrapper for assemble_video.py that resolves the skill's Python environment
# and delegates FFmpeg video assembly.

<#
.SYNOPSIS
    Assembles a narrated MP4 from image/clip segments and narration WAV files.

.DESCRIPTION
    Resolves the demo-video skill's Python environment with uv and forwards
    the supplied manifest and output arguments to assemble_video.py.

.PARAMETER ManifestPath
    Path to the YAML manifest describing the visual segments.

.PARAMETER OutputPath
    Destination MP4 path for the assembled video.

.PARAMETER Fps
    Frame rate used when rendering each segment.

.PARAMETER Resolution
    Output resolution in WIDTHxHEIGHT format.

.EXAMPLE
    ./Invoke-AssembleVideo.ps1 -ManifestPath examples/segments.yml -OutputPath ./output/demo.mp4
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$ManifestPath,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath,

    [Parameter(Mandatory = $false)]
    [int]$Fps,

    [Parameter(Mandatory = $false)]
    [string]$Resolution
)

$ErrorActionPreference = 'Stop'

$ScriptDir = $PSScriptRoot
$SkillRoot = Split-Path $ScriptDir
$VenvDir = Join-Path $SkillRoot '.venv'

function Test-UvAvailability {
    if (-not (Get-Command -Name 'uv' -ErrorAction SilentlyContinue)) {
        throw "uv is required but was not found on PATH. Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    }
}

function Initialize-PythonEnvironment {
    Write-Verbose 'Syncing Python environment via uv...'
    & uv sync --directory $SkillRoot
    if ($LASTEXITCODE -ne 0) {
        throw 'uv sync failed'
    }
}

function Get-VenvPythonPath {
    if ($IsWindows) {
        return Join-Path $VenvDir 'Scripts/python.exe'
    }
    return Join-Path $VenvDir 'bin/python'
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        Test-UvAvailability
        Initialize-PythonEnvironment

        $python = Get-VenvPythonPath
        if (-not (Test-Path $python)) {
            throw "Python not found at $python"
        }

        $script = Join-Path $ScriptDir 'assemble_video.py'
        $PythonArgs = @()
        if ($ManifestPath) { $PythonArgs += '--manifest', $ManifestPath }
        if ($OutputPath) { $PythonArgs += '--output', $OutputPath }
        if ($PSBoundParameters.ContainsKey('Fps')) { $PythonArgs += '--fps', $Fps }
        if ($Resolution) { $PythonArgs += '--resolution', $Resolution }

        & $python $script @PythonArgs
        if ($LASTEXITCODE -ne 0) {
            throw "assemble_video.py exited with code $LASTEXITCODE"
        }
    }
    catch {
        Write-Error -ErrorAction Continue "Invoke-AssembleVideo.ps1 failed: $($_.Exception.Message)"
        exit 1
    }
}
