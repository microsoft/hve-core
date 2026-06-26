# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# ArtifactDetection.psm1
#
# Purpose: Classify repository paths as AI customization artifacts
#          (agent / prompt / instruction / skill) for eval coverage tooling.
# Author: HVE Core Team

#Requires -Version 7.0

Set-StrictMode -Version Latest

$script:ArtifactPatterns = @(
    [pscustomobject]@{
        Kind    = 'agent'
        Pattern = '^\.github/agents/(?:.+/)?(?<slug>[^/]+)\.agent\.md$'
    }
    [pscustomobject]@{
        Kind    = 'prompt'
        Pattern = '^\.github/prompts/(?:.+/)?(?<slug>[^/]+)\.prompt\.md$'
    }
    [pscustomobject]@{
        Kind    = 'instruction'
        Pattern = '^\.github/instructions/(?:.+/)?(?<slug>[^/]+)\.instructions\.md$'
    }
    [pscustomobject]@{
        Kind    = 'skill'
        Pattern = '^\.github/skills/(?:.+/)?(?<slug>[^/]+)/SKILL\.md$'
    }
)

function ConvertTo-NormalizedArtifactPath {
    <#
    .SYNOPSIS
    Normalizes a workspace path by stripping leading separators and collapsing backslashes to forward slashes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ''
    }

    return ($Path -replace '\\', '/').TrimStart('/')
}

function Get-ArtifactDescriptor {
    <#
    .SYNOPSIS
    Classifies a workspace path as an AI customization artifact when it matches one of the known kinds.

    .DESCRIPTION
    Tests `Path` against the agent / prompt / instruction / skill path patterns and returns a
    descriptor describing the detected artifact, or `$null` when the path is not an AI artifact.

    .PARAMETER Path
    Workspace-relative path (forward or backslash separators accepted).

    .OUTPUTS
    [hashtable] When matched, returns `@{ kind; path; artifactId }`. Returns `$null` otherwise.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    $normalized = ConvertTo-NormalizedArtifactPath -Path $Path
    if ([string]::IsNullOrEmpty($normalized)) {
        return $null
    }

    foreach ($entry in $script:ArtifactPatterns) {
        $match = [regex]::Match($normalized, $entry.Pattern)
        if ($match.Success) {
            return @{
                kind       = $entry.Kind
                path       = $normalized
                artifactId = $match.Groups['slug'].Value
            }
        }
    }

    return $null
}

function ConvertFrom-GitDiffNameStatus {
    <#
    .SYNOPSIS
    Parses output of `git diff --name-status` into change records.

    .DESCRIPTION
    Each input line is parsed into `@{ status; path; previousPath }`. Status codes:
      A = added, M = modified, D = deleted, T = type-changed,
      R = renamed (score suffix stripped), C = copied (score suffix stripped).
    Rename and copy entries include the destination as `path` and the source as `previousPath`.

    .PARAMETER Lines
    Lines emitted by `git diff --name-status` (tab-separated).
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [string[]]$Lines
    )

    $records = [System.Collections.Generic.List[hashtable]]::new()
    if ($null -eq $Lines) { return ,@() }

    foreach ($line in $Lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }

        $parts = $line -split "`t"
        if ($parts.Count -lt 2) { continue }

        $rawStatus = $parts[0].Trim()
        if ([string]::IsNullOrWhiteSpace($rawStatus)) { continue }

        $statusLetter = $rawStatus.Substring(0, 1).ToUpperInvariant()
        $record = @{
            status       = $statusLetter
            path         = ''
            previousPath = $null
        }

        if ($statusLetter -in @('R', 'C')) {
            if ($parts.Count -lt 3) { continue }
            $record.previousPath = ConvertTo-NormalizedArtifactPath -Path $parts[1]
            $record.path = ConvertTo-NormalizedArtifactPath -Path $parts[2]
        }
        else {
            $record.path = ConvertTo-NormalizedArtifactPath -Path $parts[1]
        }

        if ([string]::IsNullOrEmpty($record.path)) { continue }
        $records.Add($record)
    }

    return ,$records.ToArray()
}

function Get-ChangedArtifactRecord {
    <#
    .SYNOPSIS
    Converts a parsed git change record into an AI-artifact change record.

    .DESCRIPTION
    Filters non-artifact paths and emits `@{ kind; path; artifactId; status; previousPath }` when the
    primary path is an AI artifact. For renames where only the source path was an artifact, the
    record falls back to the source path so deletions of artifacts via rename are still reported.

    .PARAMETER Change
    A change record produced by `ConvertFrom-GitDiffNameStatus`.

    .OUTPUTS
    [hashtable] Artifact change record, or `$null` when neither path is an artifact.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Change
    )

    $descriptor = Get-ArtifactDescriptor -Path $Change.path
    if ($null -eq $descriptor -and -not [string]::IsNullOrEmpty([string]$Change.previousPath)) {
        $descriptor = Get-ArtifactDescriptor -Path $Change.previousPath
        if ($null -ne $descriptor) {
            return @{
                kind         = $descriptor.kind
                path         = $descriptor.path
                artifactId   = $descriptor.artifactId
                status       = 'D'
                previousPath = $null
            }
        }
    }

    if ($null -eq $descriptor) { return $null }

    return @{
        kind         = $descriptor.kind
        path         = $descriptor.path
        artifactId   = $descriptor.artifactId
        status       = $Change.status
        previousPath = $Change.previousPath
    }
}

Export-ModuleMember -Function @(
    'Get-ArtifactDescriptor',
    'ConvertFrom-GitDiffNameStatus',
    'Get-ChangedArtifactRecord',
    'ConvertTo-NormalizedArtifactPath'
)
