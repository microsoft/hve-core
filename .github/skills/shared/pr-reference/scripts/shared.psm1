# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
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

function Resolve-UnquotedGitPath {
<#
.SYNOPSIS
Unquotes and decodes C-style escapes in git paths.
.DESCRIPTION
Strips surrounding double quotes and decodes C-style escape sequences including
octal byte sequences (\ooo) into valid UTF-8 strings.
.PARAMETER Path
Raw path string from git diff headers or output.
.OUTPUTS
System.String
#>
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$Path
    )

    if (-not $Path) {
        return ""
    }

    $trimmed = $Path.Trim().Trim('"')
    if ($trimmed -notmatch '\\') {
        return $trimmed
    }

    $bytes = [System.Collections.Generic.List[byte]]::new()
    $i = 0
    while ($i -lt $trimmed.Length) {
        if ($trimmed[$i] -eq '\' -and ($i + 1) -lt $trimmed.Length) {
            $next = $trimmed[$i + 1]
            if ($next -match '[0-7]' -and ($i + 3) -lt $trimmed.Length -and $trimmed[$i + 2] -match '[0-7]' -and $trimmed[$i + 3] -match '[0-7]') {
                $octStr = $trimmed.Substring($i + 1, 3)
                $byteVal = [Convert]::ToByte($octStr, 8)
                $bytes.Add($byteVal)
                $i += 4
                continue
            }
            elseif ($next -eq 't') { $bytes.Add(9); $i += 2; continue }
            elseif ($next -eq 'n') { $bytes.Add(10); $i += 2; continue }
            elseif ($next -eq '"') { $bytes.Add(34); $i += 2; continue }
            elseif ($next -eq '\') { $bytes.Add(92); $i += 2; continue }
        }
        $charBytes = [System.Text.Encoding]::UTF8.GetBytes([string]$trimmed[$i])
        foreach ($b in $charBytes) {
            $bytes.Add($b)
        }
        $i++
    }

    return [System.Text.Encoding]::UTF8.GetString($bytes.ToArray())
}

function Format-PathOrdinal {
<#
.SYNOPSIS
Sorts objects by Path using case-insensitive ordinal ordering.
.DESCRIPTION
Orders input objects by their Path property using [System.StringComparer]::OrdinalIgnoreCase
to guarantee deterministic sort order matching LC_ALL=C sort -f across all operating systems.
.PARAMETER InputObject
Collection of objects having a Path property (or string values).
.OUTPUTS
System.Object[]
#>
    [OutputType([object[]])]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [object[]]$InputObject
    )

    begin {
        $list = [System.Collections.Generic.List[object]]::new()
    }
    process {
        if ($null -ne $InputObject) {
            foreach ($item in $InputObject) {
                if ($null -ne $item) {
                    $list.Add($item)
                }
            }
        }
    }
    end {
        $list.Sort([System.Comparison[object]]{
            param($a, $b)
            $pathA = if ($null -ne $a -and $a.PSObject.Properties['Path']) { [string]$a.Path } else { [string]$a }
            $pathB = if ($null -ne $b -and $b.PSObject.Properties['Path']) { [string]$b.Path } else { [string]$b }
            [System.StringComparer]::OrdinalIgnoreCase.Compare($pathA, $pathB)
        })
        return $list.ToArray()
    }
}

Export-ModuleMember -Function Get-RepositoryRoot, Resolve-DefaultBranch, Build-PathspecExclusions, Resolve-UnquotedGitPath, Format-PathOrdinal
