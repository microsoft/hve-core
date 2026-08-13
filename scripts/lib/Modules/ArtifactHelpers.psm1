# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# ArtifactHelpers.psm1
# Purpose: Shared artifact, maturity, frontmatter, marker, path, and content utilities.

#Requires -Version 7.4
#Requires -Modules @{ ModuleName='PowerShell-Yaml'; RequiredVersion='0.4.7' }

Import-Module (Join-Path $PSScriptRoot 'CIHelpers.psm1') -Force

$script:PackageDocBeginMarker = '<!-- BEGIN AUTO-GENERATED ARTIFACTS -->'
$script:PackageDocEndMarker = '<!-- END AUTO-GENERATED ARTIFACTS -->'

function Set-ContentIfChanged {
    <#
    .SYNOPSIS
    Writes content only when its value changed.

    .PARAMETER Path
    File path to write.

    .PARAMETER Value
    Content to write.

    .OUTPUTS
    [bool] True when content was written.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory)]
        [string]$Path,

        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Value
    )

    if (Test-Path -LiteralPath $Path) {
        $existing = Get-Content -LiteralPath $Path -Raw -Encoding utf8
        if ([string]::Equals($existing, $Value, [System.StringComparison]::Ordinal)) {
            return $false
        }
    }

    $parentDir = Split-Path -Path $Path -Parent
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) {
        New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
    }

    Set-Content -LiteralPath $Path -Value $Value -Encoding utf8NoBOM -NoNewline
    return $true
}

function Test-DeprecatedPath {
    <#
    .SYNOPSIS
    Checks whether a path contains a deprecated directory segment.

    .PARAMETER Path
    File path to check.

    .OUTPUTS
    [bool] True when the path contains a deprecated segment.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    return ($Path -match '[/\\]deprecated[/\\]')
}

function Test-BuildArtifactPath {
    <#
    .SYNOPSIS
    Checks whether a file path sits inside a dependency or build artifact directory.

    .DESCRIPTION
    Returns true when the path contains a node_modules or .venv segment. A skill
    may vendor its own runtime dependencies, and those packages can ship their
    own agent, prompt, and skill files. Those belong to the dependency, not to
    this repository, so they must never be treated as distributable artifacts.

    .PARAMETER Path
    File path to check (absolute or relative, any slash style).

    .OUTPUTS
    [bool] True when the path is inside a dependency or build artifact directory.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    return ($Path -match '[/\\](node_modules|\.venv)[/\\]')
}

function Test-HveCoreRepoSpecificPath {
    <#
    .SYNOPSIS
    Checks whether a type-relative path is a root-level repository artifact.

    .PARAMETER RelativePath
    Path relative to an artifact type directory.

    .OUTPUTS
    [bool] True when the path is repository-specific.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    return ($RelativePath -notlike '*/*')
}

function Test-HveCoreRepoRelativePath {
    <#
    .SYNOPSIS
    Checks whether a repository-relative path is a root-level artifact.

    .PARAMETER Path
    Repository-relative path.

    .OUTPUTS
    [bool] True when the path is repository-specific.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    return ($Path -match '^\.github/(agents|instructions|prompts|hooks|skills)/[^/]+$')
}

function Get-ArtifactKey {
    <#
    .SYNOPSIS
    Extracts a unique artifact key from a repository-relative path.

    .PARAMETER Kind
    Artifact kind.

    .PARAMETER Path
    Repository-relative artifact path.

    .OUTPUTS
    [string] Artifact key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$Path
    )

    switch ($Kind) {
        'agent' {
            return ([System.IO.Path]::GetFileName($Path) -replace '\.agent\.md$', '')
        }
        'prompt' {
            return ([System.IO.Path]::GetFileName($Path) -replace '\.prompt\.md$', '')
        }
        'instruction' {
            return ($Path -replace '^\.github/instructions/', '' -replace '\.instructions\.md$', '')
        }
        'skill' {
            return [System.IO.Path]::GetFileName($Path.TrimEnd('/'))
        }
        'hook' {
            return [System.IO.Path]::GetFileNameWithoutExtension($Path.TrimEnd('/'))
        }
        default {
            if ($Path -match "\.$([regex]::Escape($Kind))\.md$") {
                return ([System.IO.Path]::GetFileName($Path) -replace "\.$([regex]::Escape($Kind))\.md$", '')
            }

            if ($Path -like '*.md') {
                return [System.IO.Path]::GetFileNameWithoutExtension($Path)
            }

            return [System.IO.Path]::GetFileName($Path)
        }
    }
}

function Get-ArtifactFrontmatter {
    <#
    .SYNOPSIS
    Extracts YAML frontmatter from a Markdown file.

    .PARAMETER FilePath
    Markdown file to parse.

    .PARAMETER FallbackDescription
    Default description when none is present.

    .OUTPUTS
    [hashtable] Parsed description metadata.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$FallbackDescription = ''
    )

    $content = Get-Content -Path $FilePath -Raw
    $description = ''

    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        try {
            $data = ConvertFrom-Yaml -Yaml $yamlContent
            if ($data.ContainsKey('description')) {
                $description = $data.description
            }
        }
        catch {
            Write-Warning "Failed to parse YAML frontmatter in $(Split-Path -Leaf $FilePath): $_"
        }
    }

    return @{
        description = if ($description) { $description } else { $FallbackDescription }
    }
}

function Get-ArtifactFiles {
    <#
    .SYNOPSIS
    Discovers distributable artifact files from .github directories.

    .PARAMETER RepoRoot
    Absolute repository root.

    .OUTPUTS
    [hashtable[]] Repository-relative artifact descriptors.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $items = @()
    $gitHubDir = Join-Path -Path $RepoRoot -ChildPath '.github'
    if (Test-Path -Path $gitHubDir) {
        $suffixToKind = @{ instructions = 'instruction' }
        $artifactFiles = Get-ChildItem -Path $gitHubDir -Filter '*.*.md' -File -Recurse
        foreach ($file in $artifactFiles) {
            if ($file.Name -notmatch '\.(?<suffix>[^.]+)\.md$') {
                continue
            }

            $suffix = $Matches['suffix'].ToLowerInvariant()
            $kind = if ($suffixToKind.ContainsKey($suffix)) { $suffixToKind[$suffix] } else { $suffix }
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
            if (Test-BuildArtifactPath -Path $relativePath) {
                continue
            }
            if (Test-HveCoreRepoRelativePath -Path $relativePath) {
                continue
            }
            if (Test-DeprecatedPath -Path $relativePath) {
                continue
            }
            $items += @{ path = $relativePath; kind = $kind }
        }
    }

    $skillsDir = Join-Path -Path $RepoRoot -ChildPath '.github/skills'
    if (Test-Path -Path $skillsDir) {
        foreach ($skillFile in Get-ChildItem -Path $skillsDir -Filter 'SKILL.md' -File -Recurse) {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $skillFile.Directory.FullName) -replace '\\', '/'
            if (Test-BuildArtifactPath -Path $relativePath) {
                continue
            }
            if (Test-DeprecatedPath -Path $relativePath) {
                continue
            }
            if (Test-HveCoreRepoRelativePath -Path $relativePath) {
                continue
            }
            $items += @{ path = $relativePath; kind = 'skill' }
        }
    }

    $hooksDir = Join-Path -Path $RepoRoot -ChildPath '.github/hooks'
    if (Test-Path -Path $hooksDir) {
        foreach ($packageDir in Get-ChildItem -Path $hooksDir -Directory) {
            foreach ($hookFile in Get-ChildItem -Path $packageDir.FullName -Filter '*.json' -File) {
                $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $hookFile.FullName) -replace '\\', '/'
                if (Test-HveCoreRepoRelativePath -Path $relativePath) {
                    continue
                }
                if (Test-DeprecatedPath -Path $relativePath) {
                    continue
                }
                $items += @{ path = $relativePath; kind = 'hook' }
            }
        }
    }

    return $items
}

function Split-PackageDocByMarkers {
    <#
    .SYNOPSIS
    Splits Markdown content at the artifact-generation markers.

    .PARAMETER Content
    Markdown content to split.

    .OUTPUTS
    [hashtable] Marker status, intro, and footer content.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]$Content
    )

    $beginIdx = $Content.IndexOf($script:PackageDocBeginMarker)
    $endIdx = $Content.IndexOf($script:PackageDocEndMarker)
    if ($beginIdx -lt 0 -or $endIdx -lt 0 -or $endIdx -le $beginIdx) {
        return @{ HasMarkers = $false; Intro = $Content; Footer = '' }
    }

    $intro = $Content.Substring(0, $beginIdx).TrimEnd()
    $endMarkerEnd = $endIdx + $script:PackageDocEndMarker.Length
    $footer = if ($endMarkerEnd -lt $Content.Length) {
        $Content.Substring($endMarkerEnd).TrimStart("`r", "`n")
    }
    else {
        ''
    }

    return @{ HasMarkers = $true; Intro = $intro; Footer = $footer }
}

function Get-ArtifactDescription {
    <#
    .SYNOPSIS
    Reads an artifact description from YAML frontmatter or JSON.

    .PARAMETER FilePath
    Artifact file to inspect.

    .OUTPUTS
    [string] Description text or an empty string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    if (-not (Test-Path $FilePath)) {
        return ''
    }

    if ([System.IO.Path]::GetExtension($FilePath) -eq '.json') {
        try {
            $json = Get-Content -Path $FilePath -Raw | ConvertFrom-Json
            $desc = $json.description
            if ($desc) {
                return ([string]$desc).Trim()
            }
        }
        catch {
            Write-Verbose "Failed to parse JSON description from $FilePath`: $_"
        }
        return ''
    }

    $content = Get-Content -Path $FilePath -Raw
    if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $Matches[1]
            if ($frontmatter -is [hashtable] -and $frontmatter.ContainsKey('description')) {
                return ([string]$frontmatter.description).Trim()
            }
        }
        catch {
            Write-Verbose "Failed to parse frontmatter from $FilePath`: $_"
        }
    }

    return ''
}

function Get-MaturityVocabulary {
    <#
    .SYNOPSIS
    Returns the ordered artifact maturity vocabulary.

    .OUTPUTS
    [string[]] Ordered maturity values, least to most restrictive.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return , @('stable', 'preview', 'experimental', 'deprecated', 'removed')
}

function Get-MaturityRank {
    <#
    .SYNOPSIS
    Returns the maturity precedence map used for artifact aggregation.

    .OUTPUTS
    [hashtable] Maturity value to integer rank.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    $rank = @{}
    $vocabulary = Get-MaturityVocabulary
    for ($i = 0; $i -lt $vocabulary.Count; $i++) {
        $rank[$vocabulary[$i]] = $i
    }

    return $rank
}

function Resolve-ArtifactMaturity {
    <#
    .SYNOPSIS
    Resolves effective artifact maturity from optional metadata.

    .PARAMETER Maturity
    Optional artifact maturity value.

    .OUTPUTS
    [string] Effective maturity value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity
    )

    if ([string]::IsNullOrWhiteSpace($Maturity)) {
        return 'stable'
    }

    return $Maturity
}

function Resolve-StrictSafeMaturity {
    <#
    .SYNOPSIS
    Resolves a maturity to a rankable value, erring toward experimental.

    .PARAMETER Maturity
    Candidate maturity value.

    .PARAMETER Source
    Origin descriptor included in the warning.

    .OUTPUTS
    [string] A rankable maturity value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Maturity,

        [Parameter(Mandatory = $false)]
        [string]$Source = 'an unspecified source'
    )

    $rank = Get-MaturityRank
    if ($rank.ContainsKey($Maturity)) {
        return $Maturity
    }

    $vocabulary = Get-MaturityVocabulary
    $fallback = 'experimental'
    $warning = @(
        "Unrankable maturity '$Maturity' from $Source.",
        "Strict-safe resolution defaults it to '$fallback' so the item surfaces as not-yet-stable instead of being silently treated as 'stable' (the `$null -gt rank comparison pitfall).",
        "Remediation: set maturity to one of [$($vocabulary -join ', ')] in the source metadata, then re-run artifact aggregation."
    ) -join ' '
    Write-CIAnnotation -Message $warning -Level Warning

    return $fallback
}

Export-ModuleMember -Function @(
    'Get-ArtifactDescription',
    'Get-ArtifactFiles',
    'Get-ArtifactFrontmatter',
    'Get-ArtifactKey',
    'Get-MaturityRank',
    'Get-MaturityVocabulary',
    'Resolve-ArtifactMaturity',
    'Resolve-StrictSafeMaturity',
    'Set-ContentIfChanged',
    'Split-PackageDocByMarkers',
    'Test-DeprecatedPath',
    'Test-HveCoreRepoRelativePath',
    'Test-HveCoreRepoSpecificPath'
)

Export-ModuleMember -Variable @(
    'PackageDocBeginMarker',
    'PackageDocEndMarker'
)
