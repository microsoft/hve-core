# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# PythonLintHelpers.psm1
#
# Purpose: Shared helper functions for Python lint and lint-fix wrappers
# Author: HVE Core Team

#Requires -Version 7.0

Import-Module (Join-Path $PSScriptRoot "../../lib/Modules/CIHelpers.psm1") -Force

function Get-PythonSkill {
    <#
    .SYNOPSIS
    Discovers Python skill directories by locating pyproject.toml files.

    .DESCRIPTION
    Recursively scans the repository for pyproject.toml files, excluding
    node_modules, and returns the parent directory of each match.

    .PARAMETER RepoRoot
    Repository root to scan.

    .OUTPUTS
    Array of full directory paths containing pyproject.toml.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    Push-Location $RepoRoot
    try {
        $skills = Get-ChildItem -Path . -Filter 'pyproject.toml' -Recurse -Force -File |
            Where-Object { $_.FullName -notmatch 'node_modules' } |
            ForEach-Object { $_.Directory.FullName }
        return @($skills)
    } finally {
        Pop-Location
    }
}

function Resolve-RuffCommand {
    <#
    .SYNOPSIS
    Resolves the ruff command to use for a given skill directory.

    .DESCRIPTION
    Prefers the skill's own .venv ruff binary (Linux or Windows path), then
    falls back to a globally installed ruff. Returns $null when neither is
    available.

    .PARAMETER SkillPath
    Skill directory to inspect.

    .PARAMETER GlobalRuffAvailable
    Whether ruff is available on PATH.

    .OUTPUTS
    String path or 'ruff', or $null when ruff is not available.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillPath,

        [Parameter(Mandatory = $true)]
        [bool]$GlobalRuffAvailable
    )

    $venvRuff = Join-Path $SkillPath '.venv/bin/ruff'
    $venvRuffWin = Join-Path $SkillPath '.venv/Scripts/ruff.exe'

    if (Test-Path $venvRuff) { return $venvRuff }
    if (Test-Path $venvRuffWin) { return $venvRuffWin }
    if ($GlobalRuffAvailable) { return 'ruff' }
    return $null
}

function Write-PythonLintResults {
    <#
    .SYNOPSIS
    Writes Python lint results to a JSON file, ensuring the parent directory exists.

    .DESCRIPTION
    Resolves the output path (defaulting to logs/<DefaultFileName> under
    RepoRoot when OutputPath is empty), creates the parent directory if
    missing, then writes results as JSON.

    .PARAMETER Results
    Hashtable of results to serialize.

    .PARAMETER RepoRoot
    Repository root used to compute the default logs directory.

    .PARAMETER OutputPath
    Optional explicit output path.

    .PARAMETER DefaultFileName
    Default file name to use when OutputPath is empty.

    .OUTPUTS
    Resolved output path string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Results,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath,

        [Parameter(Mandatory = $true)]
        [string]$DefaultFileName
    )

    if (-not $OutputPath) {
        $logsDir = Join-Path -Path $RepoRoot -ChildPath 'logs'
        $OutputPath = Join-Path -Path $logsDir -ChildPath $DefaultFileName
    }

    $parentDir = Split-Path -Parent $OutputPath
    if ($parentDir -and -not (Test-Path $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    $Results | ConvertTo-Json -Depth 3 | Out-File $OutputPath -Encoding UTF8
    return $OutputPath
}

Export-ModuleMember -Function Get-PythonSkill, Resolve-RuffCommand, Write-PythonLintResults
