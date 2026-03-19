# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

function Get-RepositoryRoot {
<#
.SYNOPSIS
Gets the repository root path.
.DESCRIPTION
Runs git rev-parse --show-toplevel to locate the repository root.
In default mode, falls back to the current directory when git fails.
With -Strict, throws a terminating error instead.
.PARAMETER Strict
When set, throws instead of falling back to the current directory.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param(
        [switch]$Strict
    )

    if ($Strict) {
        $repoRoot = (& git rev-parse --show-toplevel).Trim()
        if (-not $repoRoot) {
            throw "Unable to determine repository root."
        }
        return $repoRoot
    }

    $root = & git rev-parse --show-toplevel 2>$null
    if ($LASTEXITCODE -eq 0 -and $root) {
        return $root.Trim()
    }
    return $PWD.Path
}

function Resolve-DefaultBranch {
<#
.SYNOPSIS
Resolves the default branch from the remote HEAD ref.
.DESCRIPTION
Runs git symbolic-ref refs/remotes/origin/HEAD to detect the default branch.
Falls back to origin/main when the symbolic ref is unavailable.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param()

    $symRef = & git symbolic-ref refs/remotes/origin/HEAD 2>$null
    if ($LASTEXITCODE -eq 0 -and $symRef) {
        # Strip refs/remotes/ prefix to get origin/<branch>
        return ($symRef.Trim() -replace '^refs/remotes/', '')
    }

    return 'origin/main'
}

function Build-PathspecExclusions {
<#
.SYNOPSIS
Builds git pathspec negation patterns from extensions and path prefixes.
.DESCRIPTION
Accepts optional arrays of file extensions (without dots) and path prefixes,
returning git pathspec arguments that exclude matching files.
.PARAMETER Extensions
File extensions to exclude (e.g., 'yml', 'json'). Leading dots are stripped.
.PARAMETER Paths
Path prefixes to exclude (e.g., '.github/skills/', 'docs/').
.OUTPUTS
System.String[]
#>
    [OutputType([string[]])]
    param(
        [Parameter()]
        [string[]]$Extensions = @(),

        [Parameter()]
        [string[]]$Paths = @()
    )

    $specs = @()
    foreach ($ext in $Extensions) {
        $clean = $ext.TrimStart('.')
        if ($clean) {
            $specs += ":!*.$clean"
        }
    }
    foreach ($p in $Paths) {
        $clean = $p.TrimEnd('/')
        if ($clean) {
            $specs += ":!$clean/**"
        }
    }
    return $specs
}

Export-ModuleMember -Function Get-RepositoryRoot, Resolve-DefaultBranch, Build-PathspecExclusions
