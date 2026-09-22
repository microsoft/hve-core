#!/usr/bin/env pwsh
# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT
#Requires -Version 7.4
#Requires -Modules @{ ModuleName = 'PowerShell-Yaml'; RequiredVersion = '0.4.7' }

<#
.SYNOPSIS
    Validates path portability in distributed runtime artifacts.
.DESCRIPTION
    Uses the canonical artifact inventory, expands runtime skill Markdown, masks
    non-runtime regions, and reports operational .github references that would
    resolve against a consumer workspace after distribution.
.PARAMETER RepoRoot
    Repository root to scan.
.PARAMETER OutputPath
    JSON result path written when the script is invoked directly.
.EXAMPLE
    ./Test-ArtifactPathPortability.ps1 -RepoRoot .
.NOTES
    Runs via: npm run lint:artifact-portability
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$RepoRoot = (Get-Location).Path,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = (Join-Path $RepoRoot 'logs/artifact-path-portability-results.json')
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/ArtifactHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function Test-ArtifactPathPortabilityExcludedFile {
    <#
    .SYNOPSIS
        Determines whether a discovered file is outside the runtime scan boundary.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RelativePath
    )

    $normalizedPath = $RelativePath -replace '\\', '/'
    if ([System.IO.Path]::GetFileName($normalizedPath) -in 'README.md', 'SECURITY.md') {
        return $true
    }

    if ($normalizedPath -match '^\.github/skills/installer/') {
        return $true
    }

    $vallyEvidenceFiles = @(
        '.github/skills/hve-core/vally-tests/references/agents.md',
        '.github/skills/hve-core/vally-tests/references/instructions.md',
        '.github/skills/hve-core/vally-tests/references/prompts.md',
        '.github/skills/hve-core/vally-tests/references/skills.md'
    )
    return $normalizedPath -in $vallyEvidenceFiles
}

function Get-ArtifactPathPortabilityFiles {
    <#
    .SYNOPSIS
        Expands the canonical artifact inventory to runtime Markdown files.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $files = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($artifact in (Get-ArtifactFiles -RepoRoot $RepoRoot)) {
        if ($artifact.kind -eq 'hook') {
            continue
        }

        if ($artifact.kind -eq 'skill') {
            $skillRoot = Join-Path $RepoRoot $artifact.path
            $entryPath = Join-Path $skillRoot 'SKILL.md'
            if (Test-Path -LiteralPath $entryPath -PathType Leaf) {
                [void]$files.Add(([System.IO.Path]::GetRelativePath($RepoRoot, $entryPath) -replace '\\', '/'))
            }

            $referencesRoot = Join-Path $skillRoot 'references'
            if (Test-Path -LiteralPath $referencesRoot -PathType Container) {
                foreach ($referenceFile in Get-ChildItem -LiteralPath $referencesRoot -Filter '*.md' -File -Recurse) {
                    [void]$files.Add(([System.IO.Path]::GetRelativePath($RepoRoot, $referenceFile.FullName) -replace '\\', '/'))
                }
            }
            continue
        }

        $artifactPath = Join-Path $RepoRoot $artifact.path
        if (Test-Path -LiteralPath $artifactPath -PathType Leaf) {
            [void]$files.Add(($artifact.path -replace '\\', '/'))
        }
    }

    return @(
        $files |
            Where-Object { -not (Test-ArtifactPathPortabilityExcludedFile -RelativePath $_) } |
            Sort-Object
    )
}

function Get-ArtifactPathPortabilityMaskedLines {
    <#
    .SYNOPSIS
        Masks YAML frontmatter and fenced code while preserving line positions.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    $lines = @($Content -split '\r?\n')
    $inFrontmatter = $lines.Count -gt 0 -and $lines[0].Trim() -eq '---'
    $frontmatterClosed = -not $inFrontmatter
    $inFence = $false
    $scanFence = $false
    $masked = for ($index = 0; $index -lt $lines.Count; $index++) {
        $line = $lines[$index]
        if (-not $frontmatterClosed) {
            if ($index -gt 0 -and $line.Trim() -eq '---') {
                $frontmatterClosed = $true
            }
            ''
            continue
        }

        if ($line -match '^\s*(?:```|~~~)\s*(?<Info>.*)$') {
            if ($inFence) {
                $inFence = $false
                $scanFence = $false
            }
            else {
                $inFence = $true
                $scanFence = $Matches.Info.Trim() -match '^(?:bash|sh|shell|console|powershell|pwsh)(?:\s|$)'
            }
            ''
            continue
        }

        if ($inFence -and -not $scanFence) {
            ''
            continue
        }

        $line
    }

    return $masked
}

function Get-ArtifactPathReference {
    <#
    .SYNOPSIS
        Extracts the token surrounding one .github reference occurrence.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Line,

        [Parameter(Mandatory = $true)]
        [int]$Index
    )

    $start = $Index
    while ($start -gt 0 -and $Line[$start - 1] -notmatch '[\s`"''|]') {
        $start--
    }

    $end = $Index + '.github/'.Length
    while ($end -lt $Line.Length -and $Line[$end] -notmatch '[\s`"''|]') {
        $end++
    }

    return $Line.Substring($start, $end - $start).TrimEnd('.', ',', ';', ':')
}

function Test-ArtifactPathReferenceAllowed {
    <#
    .SYNOPSIS
        Determines whether one path occurrence is sanctioned portable syntax.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RelativePath,

        [Parameter(Mandatory = $true)]
        [string]$Line,

        [Parameter(Mandatory = $true)]
        [int]$Index,

        [Parameter(Mandatory = $true)]
        [string]$Reference
    )

    $exactAllowedReferences = @{
        '.github/agents/rai-planning/rai-planner.agent.md' = @('.github/skills/rai/rai-standards/SKILL.md')
        '.github/instructions/rai-planning/rai-identity.instructions.md' = @('.github/skills/rai/rai-standards/SKILL.md')
        '.github/instructions/hve-core/hve-builder.instructions.md' = @('.github/', '#file:')
        '.github/instructions/shared/hve-core-location.instructions.md' = @('.github/', '.github/instructions/')
    }
    $trimmedReference = $Reference.Trim('(', ')', '[', ']')
    if ($exactAllowedReferences.ContainsKey($RelativePath) -and $trimmedReference -in $exactAllowedReferences[$RelativePath]) {
        return $true
    }

    foreach ($match in [regex]::Matches($Line, '\[[^\]]*\.github/[^\]]*\]\([^)]*\)')) {
        $closingBracket = $Line.IndexOf('](', $match.Index, $match.Length, [System.StringComparison]::Ordinal)
        if ($Index -ge $match.Index -and $Index -lt $closingBracket) {
            return $true
        }
    }

    foreach ($match in [regex]::Matches($Line, '\]\((?<destination>(?:\.\.?/)+\.github/[^)]*)\)')) {
        $destination = $match.Groups['destination']
        if ($Index -ge $destination.Index -and $Index -lt ($destination.Index + $destination.Length)) {
            return $true
        }
    }

    if ($Reference -match '\*|\{[^}]+\}|<[^>]+>') {
        return $true
    }

    return $false
}

function Test-ArtifactPathPortability {
    <#
    .SYNOPSIS
        Finds non-portable operational .github references in distributed runtime artifacts.
    .OUTPUTS
        [hashtable] Pass state, scanned-file count, and ordered findings.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $resolvedRoot = [System.IO.Path]::GetFullPath($RepoRoot)
    $runtimeFiles = @(Get-ArtifactPathPortabilityFiles -RepoRoot $resolvedRoot)
    $findings = [System.Collections.Generic.List[object]]::new()

    foreach ($relativePath in $runtimeFiles) {
        $content = Get-Content -LiteralPath (Join-Path $resolvedRoot $relativePath) -Raw -Encoding utf8
        $lines = @(Get-ArtifactPathPortabilityMaskedLines -Content $content)
        for ($lineIndex = 0; $lineIndex -lt $lines.Count; $lineIndex++) {
            $line = $lines[$lineIndex]
            foreach ($match in [regex]::Matches($line, '(?<![\w/.-])(?:\./)?(?<Root>\.github/)')) {
                $referenceIndex = $match.Groups['Root'].Index
                $reference = Get-ArtifactPathReference -Line $line -Index $referenceIndex
                if (Test-ArtifactPathReferenceAllowed -RelativePath $relativePath -Line $line -Index $referenceIndex -Reference $reference) {
                    continue
                }

                $findings.Add([pscustomobject]@{
                        File      = $relativePath
                        Line      = $lineIndex + 1
                        Reference = $reference
                        Reason    = 'Operational .github reference assumes the consumer workspace contains the source repository artifact tree.'
                    })
            }
        }
    }

    $orderedFindings = @($findings | Sort-Object File, Line, Reference)
    return @{
        Passed           = ($orderedFindings.Count -eq 0)
        ScannedFileCount = $runtimeFiles.Count
        Findings         = $orderedFindings
    }
}

#endregion Functions

#region Main Execution

if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = 0
    try {
        $result = Test-ArtifactPathPortability -RepoRoot $RepoRoot
        $outputDirectory = Split-Path -Path $OutputPath -Parent
        if ($outputDirectory -and -not (Test-Path -LiteralPath $outputDirectory)) {
            New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
        }
        $result | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $OutputPath -Encoding utf8NoBOM

        if (-not $result.Passed) {
            foreach ($finding in $result.Findings) {
                Write-CIAnnotation -Level Error -Message $finding.Reason -File $finding.File -Line $finding.Line
            }
            Write-Host "Artifact path portability check failed: $($result.Findings.Count) finding(s) in $($result.ScannedFileCount) file(s)." -ForegroundColor Red
            $exitCode = 1
        }
        else {
            Write-Host "Artifact path portability check passed: $($result.ScannedFileCount) file(s) scanned." -ForegroundColor Green
        }
    }
    catch {
        Write-Error -ErrorAction Continue "Test-ArtifactPathPortability failed: $($_.Exception.Message)"
        $exitCode = 1
    }
    [Environment]::Exit($exitCode)
}

#endregion Main Execution
