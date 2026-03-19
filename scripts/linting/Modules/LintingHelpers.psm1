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

    # Determine whether $Path resides inside the current git repository
    $sep = [System.IO.Path]::DirectorySeparatorChar
    $repoRoot = git rev-parse --show-toplevel 2>$null
    if ($repoRoot) { $repoRoot = $repoRoot.Replace('/', $sep) }
    $resolved = Resolve-Path -Path $Path -ErrorAction SilentlyContinue
    $resolvedPath = if ($resolved) { $resolved.Path.Replace('/', $sep) } else { $null }
    $useGit = $repoRoot -and $resolvedPath -and (
        $resolvedPath -eq $repoRoot -or
        $resolvedPath.StartsWith("$repoRoot$sep")
    )

    if ($useGit) {
        # git ls-files natively respects .gitignore via --exclude-standard
        $relPath = if ($resolvedPath -eq $repoRoot) { '' }
                   else { $resolvedPath.Substring($repoRoot.Length + 1) }

        $gitArgs = @('ls-files', '--cached', '--others', '--exclude-standard')
        if ($relPath) {
            $gitArgs += '--'
            $gitArgs += "$relPath/"
        }
        else {
            foreach ($pattern in $Include) {
                $gitArgs += $pattern
            }
        }

        $rawFiles = @(git @gitArgs | Where-Object { $_ })

        # When scoped to a subdirectory, filter by Include patterns
        if ($relPath) {
            $rawFiles = @($rawFiles | Where-Object {
                $name = [System.IO.Path]::GetFileName($_)
                foreach ($p in $Include) {
                    if ($name -like $p) { return $true }
                }
                return $false
            })
        }

        $files = @($rawFiles | ForEach-Object {
            $fullPath = Join-Path $repoRoot $_
            if (Test-Path $fullPath -PathType Leaf) {
                Get-Item -LiteralPath $fullPath
            }
        })
    }
    else {
        # Fallback for non-git contexts or paths outside the repository
        $files = Get-ChildItem -Path $Path -Recurse -Include $Include -File -ErrorAction SilentlyContinue |
            Where-Object { -not $_.LinkTarget }

        if ($GitIgnorePath) {
            $patterns = Get-GitIgnorePatterns -GitIgnorePath $GitIgnorePath
            if ($patterns) {
                $files = @($files | Where-Object {
                    $fullName = $_.FullName
                    foreach ($p in $patterns) {
                        if ($fullName -like $p) { return $false }
                    }
                    return $true
                })
            }
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
