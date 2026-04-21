# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Shared helper functions for tts-voiceover skill PowerShell wrappers.

.DESCRIPTION
    Provides uv availability checking, Python virtual environment setup,
    and venv Python path resolution used by both Invoke-GenerateVoiceover.ps1
    and Invoke-EmbedAudio.ps1.
#>

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
    .PARAMETER SkillRoot
        Root directory of the skill containing pyproject.toml.
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillRoot
    )

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
    .PARAMETER VenvDir
        Path to the .venv directory.
    .OUTPUTS
        [string] Absolute path to the venv python binary.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$VenvDir
    )

    if ($IsWindows) {
        return Join-Path $VenvDir 'Scripts/python.exe'
    }
    return Join-Path $VenvDir 'bin/python'
}

Export-ModuleMember -Function Test-UvAvailability, Initialize-PythonEnvironment, Get-VenvPythonPath
