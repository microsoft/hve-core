# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
# CorpusReader.psm1
# Purpose: Read AI corpus markdown files with YAML frontmatter stripping for moderation input.
#Requires -Version 7.4

<#
.SYNOPSIS
    Returns the markdown body of a file with the YAML frontmatter block removed.

.DESCRIPTION
    Reads a UTF-8 markdown file and strips a leading YAML frontmatter block delimited
    by `---` on the first line and a matching `---` line that follows. When no
    frontmatter is present the original content is returned unchanged.

.PARAMETER Path
    Absolute or relative path to the markdown file.

.OUTPUTS
    System.String - File body without frontmatter.
#>
function Get-CorpusArtifactBody {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Corpus file not found: $Path"
    }

    $content = Get-Content -LiteralPath $Path -Raw -Encoding utf8
    if ([string]::IsNullOrEmpty($content)) {
        return ''
    }

    # Match leading frontmatter: --- on line 1, body, closing --- on its own line.
    $pattern = '^---\r?\n(?:.*?\r?\n)*?---\r?\n'
    return [regex]::Replace($content, $pattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
}

<#
.SYNOPSIS
    Filters a changed-artifacts manifest to AI corpus markdown paths.

.DESCRIPTION
    Reads `logs/changed-ai-artifacts.json` (or a compatible structure) and returns the
    file paths under `.github/agents`, `.github/prompts`, `.github/instructions`, and
    `.github/skills` with `.md` extension. Removed entries are excluded.

.PARAMETER ManifestPath
    Path to the changed-artifacts JSON manifest.

.OUTPUTS
    System.String[] - Repository-relative paths of corpus markdown files to moderate.
#>
function Get-CorpusArtifactPaths {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ManifestPath
    )

    if (-not (Test-Path -LiteralPath $ManifestPath)) {
        throw "Manifest not found: $ManifestPath"
    }

    $manifest = Get-Content -LiteralPath $ManifestPath -Raw -Encoding utf8 | ConvertFrom-Json
    $paths = [System.Collections.Generic.List[string]]::new()
    if (-not $manifest.artifacts) {
        return , $paths.ToArray()
    }

    $pattern = '^\.github/(agents|prompts|instructions|skills)/.+\.md$'
    foreach ($artifact in $manifest.artifacts) {
        $path = ($artifact.path -replace '\\', '/')
        if ($artifact.status -ne 'removed' -and $path -match $pattern) {
            $paths.Add($path)
        }
    }

    return , $paths.ToArray()
}

Export-ModuleMember -Function @(
    'Get-CorpusArtifactBody',
    'Get-CorpusArtifactPaths'
)
