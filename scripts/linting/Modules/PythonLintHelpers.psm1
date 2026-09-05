# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# PythonLintHelpers.psm1
#
# Purpose: Shared helper functions for Python lint and lint-fix wrappers
# Author: HVE Core Team

#Requires -Version 7.4

Import-Module (Join-Path $PSScriptRoot "../../lib/Modules/CIHelpers.psm1") -Force

function Get-PythonSkill {
    <#
    .SYNOPSIS
    Discovers Python skill directories by locating pyproject.toml files.

    .DESCRIPTION
    Recursively scans the repository for pyproject.toml files, excluding
    node_modules, the repository-root plugins/ generated-output tree, and the
    heavyweight scripts/evals/moderation project. Returns the parent directory
    of each eligible match.

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
        $scanRoot = (Get-Location).ProviderPath

        $skills = Get-ChildItem -Path . -Filter 'pyproject.toml' -Recurse -Force -File |
            Where-Object { $_.FullName -notmatch 'node_modules' } |
            Where-Object {
                # plugins/ at the repository root is generated output copied from canonical sources.
                $relativePath = [System.IO.Path]::GetRelativePath($scanRoot, $_.FullName)
                $rootDirectory = ($relativePath -split '[\\/]')[0]
                $rootDirectory -ne 'plugins' -and
                    $relativePath -notmatch '^scripts[\\/]evals[\\/]moderation[\\/]'
            } |
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
    available. This selector makes no version guarantee; callers that must
    honor a committed uv.lock use Resolve-ProjectRuff instead.

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

function Get-LockedRuffVersion {
    <#
    .SYNOPSIS
    Reads the ruff version recorded in a uv.lock file.

    .DESCRIPTION
    Parses the [[package]] entries of a uv.lock file and returns the version
    string of the ruff package. Returns $null when the file is missing, cannot
    be read, does not lock ruff, or records ruff without a parsable version.

    .PARAMETER LockPath
    Path to the uv.lock file.

    .OUTPUTS
    Version string, or $null when no locked ruff version is available.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$LockPath
    )

    if (-not (Test-Path $LockPath)) { return $null }

    try {
        $lines = Get-Content -Path $LockPath -ErrorAction Stop
    } catch {
        return $null
    }

    $inRuffPackage = $false
    foreach ($line in $lines) {
        $trimmed = $line.Trim()

        if ($trimmed -eq '[[package]]') {
            $inRuffPackage = $false
            continue
        }

        # Any other table header ends the current [[package]] block.
        if ($trimmed -match '^\[' ) {
            $inRuffPackage = $false
            continue
        }

        if ($trimmed -match '^name\s*=\s*"([^"]+)"$') {
            $inRuffPackage = ($Matches[1] -eq 'ruff')
            continue
        }

        if ($inRuffPackage -and $trimmed -match '^version\s*=\s*"([^"]+)"$') {
            return $Matches[1]
        }
    }

    return $null
}

function Get-RuffVersionString {
    <#
    .SYNOPSIS
    Reports the version of a ruff binary.

    .DESCRIPTION
    Invokes `<ruff> --version` and extracts the semantic version from its
    output. Returns $null when the binary cannot be executed or its output
    contains no recognizable version.

    .PARAMETER RuffCommand
    Path to a ruff binary, or 'ruff' for the binary on PATH.

    .OUTPUTS
    Version string, or $null when the version cannot be determined.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RuffCommand
    )

    try {
        $output = & $RuffCommand --version 2>&1 | Out-String
    } catch {
        return $null
    }

    if ($output -match '(\d+\.\d+\.\d+[^\s]*)') { return $Matches[1] }
    return $null
}

function Resolve-ProjectRuff {
    <#
    .SYNOPSIS
    Resolves the ruff binary a Python project must use, honoring uv.lock.

    .DESCRIPTION
    When the project commits a uv.lock that records ruff, only a binary whose
    reported version exactly matches that locked version is accepted. Candidates
    are evaluated in order: the project's own .venv ruff (Linux then Windows
    layout), then a globally installed ruff. No candidate is executed for
    linting when none matches, and no dependency synchronization is performed;
    the caller reports the required version and the `uv sync --locked` setup
    action instead.

    When the project has no uv.lock, resolution falls back to the historical
    behavior of preferring the project's .venv ruff over a global ruff, and the
    unlocked resolution mode is reported so callers can surface it.

    .PARAMETER SkillPath
    Project directory to inspect.

    .PARAMETER GlobalRuffAvailable
    Whether ruff is available on PATH.

    .OUTPUTS
    Hashtable with command, resolutionMode, lockedVersion, resolvedVersion,
    mismatches, and reason keys. command is $null when resolution fails.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SkillPath,

        [Parameter(Mandatory = $true)]
        [bool]$GlobalRuffAvailable
    )

    $resolution = @{
        command = $null
        resolutionMode = $null
        lockedVersion = $null
        resolvedVersion = $null
        mismatches = @()
        reason = $null
    }

    $lockPath = Join-Path $SkillPath 'uv.lock'

    if (-not (Test-Path $lockPath)) {
        $resolution.resolutionMode = 'unlocked-fallback'
        $resolution.command = Resolve-RuffCommand -SkillPath $SkillPath -GlobalRuffAvailable $GlobalRuffAvailable
        if (-not $resolution.command) {
            $resolution.reason = 'ruff not available (no .venv ruff and no global ruff), and no uv.lock pins a version'
        }
        return $resolution
    }

    $resolution.resolutionMode = 'locked'
    $lockedVersion = Get-LockedRuffVersion -LockPath $lockPath

    if (-not $lockedVersion) {
        $resolution.reason = 'uv.lock does not record a usable ruff version (ruff is not locked or the lock is malformed)'
        return $resolution
    }

    $resolution.lockedVersion = $lockedVersion

    $candidates = @(
        (Join-Path $SkillPath '.venv/bin/ruff')
        (Join-Path $SkillPath '.venv/Scripts/ruff.exe')
    ) | Where-Object { Test-Path $_ }

    if ($GlobalRuffAvailable) { $candidates = @($candidates) + 'ruff' }

    foreach ($candidate in $candidates) {
        $candidateVersion = Get-RuffVersionString -RuffCommand $candidate
        if ($candidateVersion -eq $lockedVersion) {
            $resolution.command = $candidate
            $resolution.resolvedVersion = $candidateVersion
            return $resolution
        }

        $reported = if ($candidateVersion) { $candidateVersion } else { 'unknown version' }
        $resolution.mismatches += "$candidate ($reported)"
    }

    $found = if ($resolution.mismatches) { "found $($resolution.mismatches -join ', ')" } else { 'found no ruff candidate' }
    $resolution.reason = "uv.lock requires ruff $lockedVersion but $found. Run 'uv sync --locked' in this project."
    return $resolution
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

Export-ModuleMember -Function Get-PythonSkill, Resolve-RuffCommand, Get-LockedRuffVersion, Get-RuffVersionString, Resolve-ProjectRuff, Write-PythonLintResults
