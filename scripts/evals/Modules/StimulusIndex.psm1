# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# StimulusIndex.psm1
#
# Purpose: Build an in-memory index of eval-spec stimulus backlinks keyed by (kind, slug)
#          so AI-artifact coverage checks can resolve which evals exercise a given artifact.
# Author: HVE Core Team

#Requires -Version 7.4

Set-StrictMode -Version Latest

$script:BacklinkKinds = @('skill', 'agent', 'prompt', 'instruction')

function Get-StimulusBacklink {
    <#
    .SYNOPSIS
    Extracts artifact backlinks declared on a single stimulus entry.

    .DESCRIPTION
    Looks for `tags.<kind>` keys on the stimulus mapping (where kind ∈ skill/agent/prompt/instruction)
    and returns one record per non-empty backlink.

    .PARAMETER Stimulus
    Parsed stimulus mapping from a spec's `stimuli[]` array.

    .OUTPUTS
    [hashtable[]] Each entry is `@{ kind; slug }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Stimulus
    )

    if ($null -eq $Stimulus -or -not ($Stimulus -is [System.Collections.IDictionary])) {
        return ,@()
    }

    if (-not $Stimulus.Contains('tags')) {
        return ,@()
    }

    $tags = $Stimulus['tags']
    if ($null -eq $tags -or -not ($tags -is [System.Collections.IDictionary])) {
        return ,@()
    }

    $results = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($kind in $script:BacklinkKinds) {
        if (-not $tags.Contains($kind)) { continue }
        $slug = [string]$tags[$kind]
        if ([string]::IsNullOrWhiteSpace($slug)) { continue }
        $results.Add(@{ kind = $kind; slug = $slug.Trim() })
    }

    return ,$results.ToArray()
}

function New-StimulusIndex {
    <#
    .SYNOPSIS
    Scans an eval root for spec files and builds a (kind:slug) → spec-paths index.

    .DESCRIPTION
    Walks `EvalRoot` for `*.yaml` and `*.yml` files, parses files that declare a top-level
    `stimuli` key via `ConvertFrom-Yaml`, and records every stimulus backlink. Specs that fail
    to parse are reported under `errors` rather than thrown so callers can decide how strict to be.

    Requires the `powershell-yaml` module to be importable.

    .PARAMETER EvalRoot
    Filesystem path to the `evals/` root (absolute or relative to the current location).

    .OUTPUTS
    [hashtable] `@{ root; specsScanned; coverage = @{ 'kind:slug' = @(specPath, ...) }; errors = @(@{ path; message }) }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$EvalRoot
    )

    if (-not (Test-Path -LiteralPath $EvalRoot -PathType Container)) {
        return @{
            root         = $EvalRoot
            specsScanned = 0
            coverage     = @{}
            errors       = @()
        }
    }

    $resolvedRoot = (Resolve-Path -LiteralPath $EvalRoot).ProviderPath
    $coverage = @{}
    $errors = [System.Collections.Generic.List[hashtable]]::new()
    $specsScanned = 0

    $specFiles = Get-ChildItem -LiteralPath $resolvedRoot -Recurse -File -Include '*.yaml', '*.yml' -ErrorAction SilentlyContinue
    foreach ($file in $specFiles) {
        $relPath = [System.IO.Path]::GetRelativePath($resolvedRoot, $file.FullName) -replace '\\', '/'

        $parsed = $null
        try {
            $raw = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction Stop
            if ([string]::IsNullOrWhiteSpace($raw)) {
                continue
            }
            if ($raw -notmatch '(?m)^\s*stimuli\s*:') {
                continue
            }

            $specsScanned++
            $parsed = ConvertFrom-Yaml -Yaml $raw
        }
        catch {
            $errors.Add(@{ path = $relPath; message = "YAML parse error: $($_.Exception.Message)" })
            continue
        }

        if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) {
            $errors.Add(@{ path = $relPath; message = 'Spec root is not a mapping' })
            continue
        }

        if (-not $parsed.Contains('stimuli')) { continue }
        $stimuli = $parsed['stimuli']
        if ($null -eq $stimuli -or -not ($stimuli -is [System.Collections.IEnumerable]) -or $stimuli -is [string]) { continue }

        foreach ($stimulus in $stimuli) {
            $links = Get-StimulusBacklink -Stimulus $stimulus
            if ($null -eq $links) { continue }
            foreach ($link in $links) {
                if ($null -eq $link -or -not ($link -is [System.Collections.IDictionary])) { continue }
                $key = "$($link['kind']):$($link['slug'])"
                if (-not $coverage.ContainsKey($key)) {
                    $coverage[$key] = [System.Collections.Generic.List[string]]::new()
                }
                if (-not $coverage[$key].Contains($relPath)) {
                    $coverage[$key].Add($relPath)
                }
            }
        }
    }

    $flat = @{}
    foreach ($key in $coverage.Keys) {
        $flat[$key] = $coverage[$key].ToArray()
    }

    return @{
        root         = $resolvedRoot
        specsScanned = $specsScanned
        coverage     = $flat
        errors       = $errors.ToArray()
    }
}

function Test-StimulusCoverage {
    <#
    .SYNOPSIS
    Returns the list of spec paths that backlink a given artifact, or an empty array.

    .PARAMETER Index
    An index produced by `New-StimulusIndex`.

    .PARAMETER Kind
    Artifact kind: skill / agent / prompt / instruction.

    .PARAMETER ArtifactId
    Artifact slug.

    .OUTPUTS
    [string[]] Spec paths that cover the artifact (empty when no coverage).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Index,

        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactId
    )

    $key = "$Kind`:$ArtifactId"
    if (-not $Index.ContainsKey('coverage')) { return ,@() }
    $coverage = $Index['coverage']
    if ($null -eq $coverage -or -not $coverage.ContainsKey($key)) { return ,@() }
    return ,@($coverage[$key])
}

Export-ModuleMember -Function @(
    'Get-StimulusBacklink',
    'New-StimulusIndex',
    'Test-StimulusCoverage'
)
