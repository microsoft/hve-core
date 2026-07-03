# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# DocsHelpers.psm1
#
# Purpose: Per-asset documentation helpers - documentable-asset enumeration,
#          docs-path derivation, invocation/interactivity classification,
#          generated-region rendering, and marker split/merge that preserves
#          human-authored sections.
# Author: HVE Core Team

#Requires -Version 7.4
#Requires -Modules @{ ModuleName='PowerShell-Yaml'; RequiredVersion='0.4.7' }

Import-Module (Join-Path $PSScriptRoot '../../collections/Modules/CollectionHelpers.psm1') -Force

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

# Kinds that receive a generated documentation page. Hooks are intentionally
# excluded because they are JSON lifecycle manifests, not GenAI assets.
$script:DocumentableKinds = @('agent', 'prompt', 'instruction', 'skill')

# Maps an artifact kind to the file-name suffix stripped when deriving the
# documentation file name. Skills are directory-based and handled separately.
$script:AssetFileSuffix = @{
    agent       = '.agent.md'
    prompt      = '.prompt.md'
    instruction = '.instructions.md'
}

# Named auto-generated marker format. Each generated region is delimited by a
# BEGIN/END pair carrying the region name so multiple regions can coexist in a
# single page while human-authored sections between them are preserved.
$script:AssetDocMarkerBeginFormat = '<!-- BEGIN AUTO-GENERATED: {0} -->'
$script:AssetDocMarkerEndFormat = '<!-- END AUTO-GENERATED: {0} -->'

# Sentinel embedded in human-authored stub sections. Validators detect its
# presence to flag documentation pages whose human sections are unwritten.
$script:AssetDocStubSentinel = '<!-- asset-docs:stub -->'

# ---------------------------------------------------------------------------
# Text Formatting
# ---------------------------------------------------------------------------

function Format-YamlScalar {
    <#
    .SYNOPSIS
    Renders a string as a safe YAML scalar for frontmatter.

    .DESCRIPTION
    Returns the value unquoted when it is safe to do so, otherwise wraps it in
    double quotes with backslash and double-quote escaping so colons and other
    YAML-significant characters do not break the frontmatter block.

    .PARAMETER Value
    The scalar value to render.

    .OUTPUTS
    [string] A YAML-safe scalar.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    $needsQuote = [string]::IsNullOrEmpty($Value) -or
        $Value -match '[:#\[\]{}",''|>&*!?@`]' -or
        $Value -match '^\s' -or
        $Value -match '\s$'

    if ($needsQuote) {
        $escaped = $Value -replace '\\', '\\' -replace '"', '\"'
        return '"' + $escaped + '"'
    }

    return $Value
}

function ConvertTo-TableCell {
    <#
    .SYNOPSIS
    Normalizes text for inclusion in a Markdown table cell.

    .DESCRIPTION
    Collapses line breaks to spaces and escapes pipe characters so cell content
    cannot break table structure.

    .PARAMETER Value
    The raw cell text.

    .OUTPUTS
    [string] A single-line, pipe-escaped cell value.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Value
    )

    return (($Value -replace '\r?\n', ' ') -replace '\|', '\|').Trim()
}

# ---------------------------------------------------------------------------
# Frontmatter
# ---------------------------------------------------------------------------

function Get-AssetFrontmatter {
    <#
    .SYNOPSIS
    Parses the full YAML frontmatter block of an asset markdown file.

    .DESCRIPTION
    Reads the YAML frontmatter delimited by --- markers at the start of a
    markdown file and returns it as a hashtable. Complements
    Get-ArtifactDescription (description only) by exposing every frontmatter
    field required for invocation and interactivity classification such as
    name, applyTo, argument-hint, and agent. Returns an empty hashtable when
    the file is missing, has no frontmatter, or the frontmatter fails to parse.

    .PARAMETER FilePath
    Absolute path to the asset markdown file.

    .OUTPUTS
    [hashtable] Parsed frontmatter fields, or an empty hashtable.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    if (-not (Test-Path -LiteralPath $FilePath)) {
        return @{}
    }

    $content = Get-Content -LiteralPath $FilePath -Raw
    if ($content -match '(?s)^---[ \t]*\r?\n(.*?)\r?\n---') {
        $yamlBlock = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $yamlBlock
            if ($frontmatter -is [hashtable]) {
                return $frontmatter
            }
        }
        catch {
            Write-Verbose "Failed to parse frontmatter from $FilePath`: $_"
        }
    }

    return @{}
}

# ---------------------------------------------------------------------------
# Asset Enumeration and Path Derivation
# ---------------------------------------------------------------------------

function Get-DocumentableAssets {
    <#
    .SYNOPSIS
    Enumerates GenAI assets eligible for a generated documentation page.

    .DESCRIPTION
    Discovers all artifacts via Get-ArtifactFiles and narrows them to the
    documentable kinds (agent, prompt, instruction, skill). Root-level
    repo-specific artifacts and assets under deprecated directory trees are
    already excluded by Get-ArtifactFiles, so no additional filtering is
    required. Results are sorted by kind then path for deterministic output.

    .PARAMETER RepoRoot
    Absolute path to the repository root directory.

    .OUTPUTS
    [hashtable[]] Array of hashtable entries with path and kind keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $assets = @(Get-ArtifactFiles -RepoRoot $RepoRoot |
        Where-Object { $_.kind -in $script:DocumentableKinds })

    return @($assets | Sort-Object -Property @{ Expression = 'kind' }, @{ Expression = 'path' })
}

function Get-AssetDocsPath {
    <#
    .SYNOPSIS
    Derives the documentation page path for an asset.

    .DESCRIPTION
    Maps a repo-relative .github/<kind>/... asset path to its deterministic
    docs/reference/<kind>/... documentation page path. The intermediate
    directory structure is preserved so nested assets such as agent subagents
    (.github/agents/<collection>/subagents/<name>.agent.md) and nested
    instructions retain their hierarchy under docs/reference/. File-based kinds
    (agent, prompt, instruction) have their suffix replaced with .md; skills are
    directory-based, so .md is appended to the skill directory name.

    .PARAMETER Path
    Repo-relative asset path with forward slashes (as produced by
    Get-DocumentableAssets). For skills this is the skill directory path.

    .PARAMETER Kind
    The artifact kind (agent, prompt, instruction, skill).

    .OUTPUTS
    [string] Repo-relative documentation page path with forward slashes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind
    )

    $normalized = $Path -replace '\\', '/'

    if ($normalized -notmatch '^\.github/(agents|prompts|instructions|skills)/(.+)$') {
        throw "Path is not a documentable .github asset: $Path"
    }

    $kindDir = $Matches[1]
    $remainder = $Matches[2]

    if ($Kind -eq 'skill') {
        # Skill paths are directories; the page mirrors the skill directory name.
        $docFile = "$remainder.md"
    }
    else {
        $suffix = $script:AssetFileSuffix[$Kind]
        $docFile = $remainder -replace ([regex]::Escape($suffix) + '$'), '.md'
    }

    return "docs/reference/$kindDir/$docFile"
}

# ---------------------------------------------------------------------------
# Invocation and Interactivity Classification
# ---------------------------------------------------------------------------

function Get-AssetInvocation {
    <#
    .SYNOPSIS
    Describes how an asset is invoked.

    .DESCRIPTION
    Returns a structured descriptor of the invocation mechanism for an asset so
    documentation generation can render consistent "how to invoke" guidance.
    Agents surface in the chat agent picker under their display name; prompts run
    as slash commands; instructions apply automatically to files matching their
    applyTo glob; skills load on demand when a referencing agent needs them.

    .PARAMETER Kind
    The artifact kind (agent, prompt, instruction, skill).

    .PARAMETER Name
    The asset name (display name for agents, artifact key otherwise).

    .PARAMETER Frontmatter
    Optional parsed frontmatter hashtable. Used to resolve the applyTo glob for
    instructions and to prefer an agent's declared display name.

    .OUTPUTS
    [hashtable] With Mechanism and Token keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(Mandatory = $false)]
        [hashtable]$Frontmatter = @{}
    )

    switch ($Kind) {
        'agent' {
            $displayName = if ($Frontmatter.ContainsKey('name') -and $Frontmatter['name']) {
                [string]$Frontmatter['name']
            }
            else {
                $Name
            }
            return @{ Mechanism = 'agent-picker'; Token = $displayName }
        }
        'prompt' {
            return @{ Mechanism = 'slash-command'; Token = "/$Name" }
        }
        'instruction' {
            $applyTo = if ($Frontmatter.ContainsKey('applyTo') -and $Frontmatter['applyTo']) {
                [string]$Frontmatter['applyTo']
            }
            else {
                ''
            }
            return @{ Mechanism = 'auto-applied'; Token = $applyTo }
        }
        'skill' {
            return @{ Mechanism = 'skill-load'; Token = $Name }
        }
        default {
            throw "Get-AssetInvocation: unrecognized kind '$Kind'."
        }
    }
}

function Test-AssetInteractive {
    <#
    .SYNOPSIS
    Determines whether an asset engages the user interactively.

    .DESCRIPTION
    Classifies whether an asset has an interactive usage flow so documentation
    generation can decide whether to include a "How to use" section. Agents are
    conversational and always interactive. Prompts are interactive when they
    declare inputs (argument-hint) or launch an agent (agent field). Instructions
    and skills are passive: instructions apply automatically and skills load in
    the background, so neither is interactive.

    .PARAMETER Kind
    The artifact kind (agent, prompt, instruction, skill).

    .PARAMETER Frontmatter
    Optional parsed frontmatter hashtable used to detect prompt inputs and
    agent binding.

    .OUTPUTS
    [bool] True when the asset has an interactive usage flow.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill')]
        [string]$Kind,

        [Parameter(Mandatory = $false)]
        [hashtable]$Frontmatter = @{}
    )

    switch ($Kind) {
        'agent' {
            return $true
        }
        'prompt' {
            $hasInputs = $Frontmatter.ContainsKey('argument-hint') -and $Frontmatter['argument-hint']
            $bindsAgent = $Frontmatter.ContainsKey('agent') -and $Frontmatter['agent']
            return [bool]($hasInputs -or $bindsAgent)
        }
        default {
            return $false
        }
    }
}

function Format-AssetInvocation {
    <#
    .SYNOPSIS
    Renders an invocation descriptor as human-readable table text.

    .PARAMETER Invocation
    Hashtable from Get-AssetInvocation with Mechanism and Token keys.

    .OUTPUTS
    [string] Table-safe invocation description.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Invocation
    )

    $tick = '`'
    $token = [string]$Invocation.Token
    switch ($Invocation.Mechanism) {
        'agent-picker' { return "Selected from the chat agent picker as $tick$token$tick" }
        'slash-command' { return "Slash command $tick$token$tick" }
        'auto-applied' {
            if ([string]::IsNullOrWhiteSpace($token)) { return 'Applied automatically' }
            return "Applied automatically to $tick$token$tick"
        }
        'skill-load' { return 'Loaded on demand by referencing agents' }
        default {
            $mechanism = ConvertTo-TableCell -Value ([string]$Invocation.Mechanism)
            Write-Warning "Format-AssetInvocation: unrecognized mechanism '$mechanism'; rendering drift marker."
            return "(unknown invocation: $mechanism)"
        }
    }
}

# ---------------------------------------------------------------------------
# Generated-Region Rendering and Marker Split/Merge
# ---------------------------------------------------------------------------

function Get-AssetDocMarker {
    <#
    .SYNOPSIS
    Builds a named auto-generated marker string.

    .DESCRIPTION
    Returns the BEGIN or END marker comment for a named generated region using
    the shared marker format so producers and consumers cannot drift.

    .PARAMETER Region
    The region name (for example, metadata or overview).

    .PARAMETER Boundary
    Which marker to build: Begin or End.

    .OUTPUTS
    [string] The marker comment.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Region,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Begin', 'End')]
        [string]$Boundary
    )

    $format = if ($Boundary -eq 'Begin') {
        $script:AssetDocMarkerBeginFormat
    }
    else {
        $script:AssetDocMarkerEndFormat
    }

    return ($format -f $Region)
}

function New-AssetGeneratedRegion {
    <#
    .SYNOPSIS
    Renders a named auto-generated region.

    .DESCRIPTION
    Wraps generated body content between the BEGIN and END markers for a named
    region. The body is trimmed of surrounding blank lines and placed on its own
    lines so the rendered block is stable across regenerations.

    .PARAMETER Region
    The region name (for example, metadata or overview).

    .PARAMETER Body
    The generated content to place between the markers.

    .OUTPUTS
    [string] The rendered region including both markers.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Region,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body
    )

    $begin = Get-AssetDocMarker -Region $Region -Boundary Begin
    $end = Get-AssetDocMarker -Region $Region -Boundary End
    $trimmed = $Body.Trim("`r", "`n")

    return "$begin`n$trimmed`n$end"
}

function Split-AssetDocByMarkers {
    <#
    .SYNOPSIS
    Splits documentation content at a named region's markers.

    .DESCRIPTION
    Locates the BEGIN and END markers for a named region within the supplied
    content and returns the text before the region, the region body, and the
    text after the region. The Before and After segments hold the
    human-authored sections that must survive regeneration. Returns
    HasMarkers = $false with the full content as Before when the markers are
    missing or mis-ordered.

    .PARAMETER Content
    The full text content of a documentation page.

    .PARAMETER Region
    The region name to locate (for example, metadata or overview).

    .OUTPUTS
    [hashtable] With HasMarkers ([bool]), Before ([string]), Body ([string]),
    and After ([string]) keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Region
    )

    $begin = Get-AssetDocMarker -Region $Region -Boundary Begin
    $end = Get-AssetDocMarker -Region $Region -Boundary End

    $beginIdx = $Content.IndexOf($begin)
    $endIdx = $Content.IndexOf($end)

    if ($beginIdx -lt 0 -or $endIdx -lt 0 -or $endIdx -le $beginIdx) {
        return @{
            HasMarkers = $false
            Before     = $Content
            Body       = ''
            After      = ''
        }
    }

    $innerBeginIdx = $Content.IndexOf($begin, $beginIdx + $begin.Length)
    if ($innerBeginIdx -ge 0 -and $innerBeginIdx -lt $endIdx) {
        return @{
            HasMarkers = $false
            Before     = $Content
            Body       = ''
            After      = ''
        }
    }

    $bodyStart = $beginIdx + $begin.Length
    $before = $Content.Substring(0, $beginIdx)
    $body = $Content.Substring($bodyStart, $endIdx - $bodyStart)
    $after = $Content.Substring($endIdx + $end.Length)

    return @{
        HasMarkers = $true
        Before     = $before
        Body       = $body.Trim("`r", "`n")
        After      = $after
    }
}

function Merge-AssetDocRegion {
    <#
    .SYNOPSIS
    Replaces a named region's body while preserving human-authored sections.

    .DESCRIPTION
    Rewrites only the content between a named region's BEGIN and END markers,
    leaving every human-authored section outside the region byte-for-byte
    unchanged. Throws when the region markers are absent so callers can detect
    a corrupted or drifted page instead of silently discarding generated
    content.

    .PARAMETER Content
    The full text content of an existing documentation page.

    .PARAMETER Region
    The region name to update (for example, metadata or overview).

    .PARAMETER Body
    The new generated content to place between the markers.

    .OUTPUTS
    [string] The merged page content.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Region,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body
    )

    $split = Split-AssetDocByMarkers -Content $Content -Region $Region
    if (-not $split.HasMarkers) {
        throw "Region markers for '$Region' not found; cannot merge without corrupting human-authored sections."
    }

    $region = New-AssetGeneratedRegion -Region $Region -Body $Body
    return "$($split.Before)$region$($split.After)"
}

function Test-AssetDocStub {
    <#
    .SYNOPSIS
    Detects unwritten human-authored stub sections.

    .DESCRIPTION
    Returns true when the stub sentinel appears anywhere in the supplied
    content, signalling that at least one human-authored section is still a
    placeholder awaiting authoring.

    .PARAMETER Content
    The full text content of a documentation page.

    .OUTPUTS
    [bool] True when a stub sentinel is present.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    return $Content.Contains($script:AssetDocStubSentinel)
}

# ---------------------------------------------------------------------------
# Asset Page Model and Region Bodies
# ---------------------------------------------------------------------------

function New-AssetPageModel {
    <#
    .SYNOPSIS
    Builds the resolved page model for a documentable asset.

    .DESCRIPTION
    Reads the asset frontmatter and description once and derives the title,
    invocation, interactivity, source path, and destination docs path used by
    both the page builder and the index builder.

    .PARAMETER Asset
    Hashtable with path and kind keys from Get-DocumentableAssets.

    .PARAMETER RepoRoot
    Repository root directory.

    .OUTPUTS
    [PSCustomObject] The resolved page model.
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)][hashtable]$Asset,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$RepoRoot
    )

    $kind = [string]$Asset.kind
    $relPath = [string]$Asset.path

    $sourceFile = Join-Path $RepoRoot ($relPath -replace '^\./', '')
    if ($kind -eq 'skill') {
        $sourceFile = Join-Path $sourceFile 'SKILL.md'
    }

    $frontmatter = Get-AssetFrontmatter -FilePath $sourceFile
    $key = Get-CollectionArtifactKey -Kind $kind -Path $relPath
    $description = Get-ArtifactDescription -FilePath $sourceFile

    $title = if ($frontmatter.ContainsKey('name') -and $frontmatter['name']) {
        [string]$frontmatter['name']
    }
    elseif ($frontmatter.ContainsKey('title') -and $frontmatter['title']) {
        [string]$frontmatter['title']
    }
    else {
        (Get-Culture).TextInfo.ToTitleCase(($key -replace '[-_]', ' '))
    }

    $docRel = Get-AssetDocsPath -Path $relPath -Kind $kind
    $folder = (Split-Path -Path $docRel -Parent) -replace '\\', '/'
    $kindDir = ($docRel -replace '^docs/reference/', '').Split('/')[0]

    return [PSCustomObject]@{
        Kind        = $kind
        Key         = $key
        Title       = $title
        Description = $description
        SourceRel   = $relPath
        DocRel      = $docRel
        Folder      = $folder
        KindDir     = $kindDir
        Invocation  = Get-AssetInvocation -Kind $kind -Name $key -Frontmatter $frontmatter
        Interactive = Test-AssetInteractive -Kind $kind -Frontmatter $frontmatter
    }
}

function New-AssetMetadataBlock {
    <#
    .SYNOPSIS
    Builds the metadata region body for an asset page.

    .PARAMETER Kind
    Asset kind.

    .PARAMETER SourcePath
    Repo-relative source path of the asset.

    .PARAMETER Invocation
    Invocation descriptor from Get-AssetInvocation.

    .PARAMETER Interactive
    Whether the asset has an interactive usage flow.

    .OUTPUTS
    [string] The metadata table body (without markers).
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$Kind,
        [Parameter(Mandatory = $true)][ValidateNotNullOrEmpty()][string]$SourcePath,
        [Parameter(Mandatory = $true)][hashtable]$Invocation,
        [Parameter(Mandatory = $true)][bool]$Interactive
    )

    $tick = '`'
    $interactiveText = if ($Interactive) { 'Yes' } else { 'No' }

    return (@(
            '| Field | Value |'
            '| ----- | ----- |'
            "| Kind | $Kind |"
            "| Source | $tick$SourcePath$tick |"
            "| Invocation | $(Format-AssetInvocation -Invocation $Invocation) |"
            "| Interactive | $interactiveText |"
        ) -join "`n")
}

function New-AssetOverviewBody {
    <#
    .SYNOPSIS
    Renders the overview ("What it does") region body for an asset.

    .DESCRIPTION
    Returns the asset description collapsed to a single line, or a stable
    fallback sentence when the asset declares no description. Shared by the
    generator and the validator so the sync check renders identically.

    .PARAMETER Model
    Page model from New-AssetPageModel.

    .OUTPUTS
    [string] The overview region body.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)][PSCustomObject]$Model
    )

    if ([string]::IsNullOrWhiteSpace($Model.Description)) {
        return 'This asset does not declare a description.'
    }
    return ($Model.Description -replace '\r?\n', ' ').Trim()
}

Export-ModuleMember -Function @(
    'ConvertTo-TableCell',
    'Format-AssetInvocation',
    'Format-YamlScalar',
    'Get-AssetDocMarker',
    'Get-AssetDocsPath',
    'Get-AssetFrontmatter',
    'Get-AssetInvocation',
    'Get-DocumentableAssets',
    'Merge-AssetDocRegion',
    'New-AssetGeneratedRegion',
    'New-AssetMetadataBlock',
    'New-AssetOverviewBody',
    'New-AssetPageModel',
    'Split-AssetDocByMarkers',
    'Test-AssetDocStub',
    'Test-AssetInteractive'
)

Export-ModuleMember -Variable @(
    'AssetDocMarkerBeginFormat',
    'AssetDocMarkerEndFormat',
    'AssetDocStubSentinel'
)
