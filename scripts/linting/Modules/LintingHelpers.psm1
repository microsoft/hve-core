# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# LintingHelpers.psm1
#
# Purpose: Shared helper functions for linting scripts and workflows
# Author: HVE Core Team

Import-Module (Join-Path $PSScriptRoot "../../lib/Modules/CIHelpers.psm1") -Force

function Get-ChangedFilesFromGit {
    <#
    .SYNOPSIS
    Gets changed files from git with intelligent fallback strategies.

    .DESCRIPTION
    Attempts to detect changed files using merge-base, with fallbacks for different scenarios.

    .PARAMETER BaseBranch
    The base branch to compare against (default: origin/main).

    .PARAMETER FileExtensions
    Array of file extensions to filter (e.g., @('*.ps1', '*.md')).

    .OUTPUTS
    Array of changed file paths.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [string[]]$FileExtensions = @('*')
    )

    $changedFiles = @()

    try {
        # Try merge-base first (best for PRs)
        $mergeBase = git merge-base HEAD $BaseBranch 2>$null
        
        if ($LASTEXITCODE -eq 0 -and $mergeBase) {
            Write-Verbose "Using merge-base: $mergeBase"
            $changedFiles = git diff --name-only --diff-filter=ACMR $mergeBase HEAD 2>$null
        }
        elseif ((git rev-parse HEAD~1 2>$null)) {
            Write-Verbose "Merge base failed, using HEAD~1"
            $changedFiles = git diff --name-only --diff-filter=ACMR HEAD~1 HEAD 2>$null
        }
        else {
            Write-Verbose "HEAD~1 failed, using staged/unstaged files"
            $changedFiles = git diff --name-only HEAD 2>$null
        }

        if ($LASTEXITCODE -ne 0) {
            Write-Warning "Unable to determine changed files from git"
            return @()
        }

        # Filter by extensions and verify files exist
        $filteredFiles = $changedFiles | Where-Object {
            if ([string]::IsNullOrEmpty($_)) { return $false }
            
            # Check if file matches any of the allowed extensions
            $currentFile = $_
            $matchesExtension = $false
            foreach ($pattern in $FileExtensions) {
                if ($currentFile -like $pattern) {
                    $matchesExtension = $true
                    break
                }
            }
            
            $matchesExtension -and (Test-Path $currentFile -PathType Leaf)
        }

        Write-Verbose "Found $($filteredFiles.Count) changed files matching extensions: $($FileExtensions -join ', ')"
        return $filteredFiles
    }
    catch {
        Write-Warning "Error getting changed files: $($_.Exception.Message)"
        return @()
    }
}

function Get-FilesRecursive {
    <#
    .SYNOPSIS
    Gets files recursively with gitignore filtering.

    .DESCRIPTION
    Recursively finds files by extension, respecting .gitignore patterns.

    .PARAMETER Path
    Root path to search from.

    .PARAMETER Include
    File patterns to include (e.g., @('*.ps1', '*.psm1')).

    .PARAMETER GitIgnorePath
    Path to .gitignore file for exclusion patterns.

    .OUTPUTS
    Array of FileInfo objects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [string[]]$Include,

        [Parameter(Mandatory = $false)]
        [string]$GitIgnorePath
    )

    $files = Get-ChildItem -Path $Path -Recurse -Include $Include -File -Force -ErrorAction SilentlyContinue

    # Apply gitignore filtering if provided
    if ($GitIgnorePath -and (Test-Path $GitIgnorePath)) {
        $gitignorePatterns = Get-GitIgnorePatterns -GitIgnorePath $GitIgnorePath
        
        $files = $files | Where-Object {
            $file = $_
            $excluded = $false
            
            foreach ($pattern in $gitignorePatterns) {
                if ($file.FullName -like $pattern) {
                    $excluded = $true
                    break
                }
            }
            
            -not $excluded
        }
    }

    return $files
}

function Get-GitIgnorePatterns {
    <#
    .SYNOPSIS
    Parses .gitignore into PowerShell wildcard patterns.

    .PARAMETER GitIgnorePath
    Path to .gitignore file.

    .OUTPUTS
    Array of wildcard patterns using platform-appropriate separators.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$GitIgnorePath
    )

    if (-not (Test-Path $GitIgnorePath)) {
        return @()
    }

    $sep = [System.IO.Path]::DirectorySeparatorChar

    $patterns = Get-Content $GitIgnorePath | Where-Object {
        $_ -and -not $_.StartsWith('#') -and $_.Trim() -ne ''
    } | ForEach-Object {
        $pattern = $_.Trim()
        
        # Normalize to platform separator
        $normalizedPattern = $pattern.Replace('/', $sep).Replace('\', $sep)
        
        if ($pattern.EndsWith('/')) {
            "*$sep$($normalizedPattern.TrimEnd($sep))$sep*"
        }
        elseif ($pattern.Contains('/') -or $pattern.Contains('\')) {
            "*$sep$normalizedPattern*"
        }
        else {
            "*$sep$normalizedPattern$sep*"
        }
    }

    return $patterns
}

# Export local functions only - CIHelpers functions are used via direct import
Export-ModuleMember -Function @(
    'Get-ChangedFilesFromGit',
    'Get-FilesRecursive',
    'Get-GitIgnorePatterns'
)
