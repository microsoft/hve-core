# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# ChangedSpecStimulus.psm1
#
# Purpose: Resolve eval stimuli that were added or modified in a pull request's
#          changed eval specs into synthetic artifact descriptors, so the
#          PR-time eval executor runs a changed test even when the underlying
#          AI artifact is unchanged (issue #2297).
#
#          A stimulus declares its artifact backlink via `tags.<kind>: <slug>`
#          (kind in skill/agent/prompt/instruction). The executor already maps
#          an artifact to its covering spec and scopes the run with
#          `--tag kind=slug`, so emitting a synthetic `{ kind, artifactId }` for
#          each changed stimulus reuses that machinery and keeps execution
#          diff-scoped to the changed stimuli.
# Author: HVE Core Team

#Requires -Version 7.0

Set-StrictMode -Version Latest

Import-Module (Join-Path $PSScriptRoot 'StimulusIndex.psm1') -Force

if (-not (Get-Module -ListAvailable -Name 'powershell-yaml')) {
    throw "ChangedSpecStimulus requires the 'powershell-yaml' module."
}
Import-Module powershell-yaml -ErrorAction Stop

function ConvertTo-CanonicalString {
    <#
    .SYNOPSIS
    Serializes a parsed YAML value into an order-independent string for comparison.

    .DESCRIPTION
    Recursively sorts dictionary keys and serializes the result as compact JSON so
    two semantically equal stimuli produce the same string regardless of key order.

    .PARAMETER Value
    A value produced by `ConvertFrom-Yaml` (dictionary, list, or scalar).

    .OUTPUTS
    [string] Canonical JSON representation.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param([AllowNull()]$Value)

    $normalized = ConvertTo-CanonicalObject -Value $Value
    return ($normalized | ConvertTo-Json -Depth 32 -Compress)
}

function ConvertTo-CanonicalObject {
    [CmdletBinding()]
    param([AllowNull()]$Value)

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in ($Value.Keys | Sort-Object { [string]$_ })) {
            $ordered[[string]$key] = ConvertTo-CanonicalObject -Value $Value[$key]
        }
        return $ordered
    }

    if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Value) {
            $list.Add((ConvertTo-CanonicalObject -Value $item))
        }
        return $list.ToArray()
    }

    return $Value
}

function Get-SpecStimulusSignatureMap {
    <#
    .SYNOPSIS
    Maps each named stimulus in an eval spec to a canonical signature string.

    .DESCRIPTION
    Parses the supplied spec YAML and returns a hashtable of `name -> canonical
    string` for every stimulus that declares a non-empty `name`. Empty input,
    parse failures, and specs without a `stimuli` array yield an empty map so the
    caller can treat them as "no stimuli".

    .PARAMETER Yaml
    The full eval-spec YAML text.

    .OUTPUTS
    [hashtable] `@{ <stimulus-name> = <canonical-string> }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param([AllowNull()][AllowEmptyString()][string]$Yaml)

    $map = @{}
    if ([string]::IsNullOrWhiteSpace($Yaml)) { return $map }

    try {
        $parsed = ConvertFrom-Yaml -Yaml $Yaml
    }
    catch {
        Write-Verbose "Get-SpecStimulusSignatureMap: parse failed: $($_.Exception.Message)"
        return $map
    }

    if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) { return $map }
    if (-not $parsed.Contains('stimuli')) { return $map }
    $stimuli = $parsed['stimuli']
    if ($null -eq $stimuli -or -not ($stimuli -is [System.Collections.IEnumerable]) -or $stimuli -is [string]) { return $map }

    foreach ($stimulus in $stimuli) {
        if (-not ($stimulus -is [System.Collections.IDictionary])) { continue }
        if (-not $stimulus.Contains('name')) { continue }
        $name = [string]$stimulus['name']
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $map[$name] = ConvertTo-CanonicalString -Value $stimulus
    }

    return $map
}

function Get-ChangedStimulusName {
    <#
    .SYNOPSIS
    Returns the names of stimuli added or modified between a base and head spec.

    .DESCRIPTION
    Compares two signature maps (from `Get-SpecStimulusSignatureMap`) and returns
    every name present in head that is absent from base (added) or whose canonical
    signature differs (modified). Deletions are intentionally ignored: a removed
    stimulus has nothing to execute.

    .PARAMETER BaseMap
    Signature map of the base (pre-change) spec.

    .PARAMETER HeadMap
    Signature map of the head (post-change) spec.

    .OUTPUTS
    [string[]] Names of added or modified stimuli.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory)][hashtable]$BaseMap,
        [Parameter(Mandatory)][hashtable]$HeadMap
    )

    $changed = [System.Collections.Generic.List[string]]::new()
    foreach ($name in $HeadMap.Keys) {
        if (-not $BaseMap.ContainsKey($name)) {
            $changed.Add($name)
            continue
        }
        if ([string]$HeadMap[$name] -ne [string]$BaseMap[$name]) {
            $changed.Add($name)
        }
    }

    return , [string[]]$changed.ToArray()
}

function Get-StimulusBacklinkForName {
    <#
    .SYNOPSIS
    Extracts the artifact backlinks for a named subset of stimuli in a spec.

    .DESCRIPTION
    Parses the head spec YAML and, for each requested stimulus name, returns its
    `tags.<kind>` backlinks via the shared `Get-StimulusBacklink` helper. Stimuli
    without a backlink are skipped: there is no `kind=slug` tag to scope a run, so
    they cannot be diff-scoped and are out of scope for this resolver.

    .PARAMETER Yaml
    The head eval-spec YAML text.

    .PARAMETER Name
    The stimulus names to resolve.

    .OUTPUTS
    [hashtable[]] Each entry is `@{ kind; slug; name }`.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [AllowNull()][AllowEmptyString()][string]$Yaml,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Name
    )

    $results = [System.Collections.Generic.List[hashtable]]::new()
    if ([string]::IsNullOrWhiteSpace($Yaml) -or $Name.Count -eq 0) { return , $results.ToArray() }

    try {
        $parsed = ConvertFrom-Yaml -Yaml $Yaml
    }
    catch {
        Write-Verbose "Get-StimulusBacklinkForName: parse failed: $($_.Exception.Message)"
        return , $results.ToArray()
    }

    if ($null -eq $parsed -or -not ($parsed -is [System.Collections.IDictionary])) { return , $results.ToArray() }
    if (-not $parsed.Contains('stimuli')) { return , $results.ToArray() }
    $stimuli = $parsed['stimuli']
    if ($null -eq $stimuli -or -not ($stimuli -is [System.Collections.IEnumerable]) -or $stimuli -is [string]) { return , $results.ToArray() }

    $wanted = @{}
    foreach ($n in $Name) { $wanted[$n] = $true }

    foreach ($stimulus in $stimuli) {
        if (-not ($stimulus -is [System.Collections.IDictionary])) { continue }
        if (-not $stimulus.Contains('name')) { continue }
        $stimName = [string]$stimulus['name']
        if (-not $wanted.ContainsKey($stimName)) { continue }

        foreach ($link in (Get-StimulusBacklink -Stimulus $stimulus)) {
            if ($null -eq $link) { continue }
            $results.Add(@{ kind = [string]$link['kind']; slug = [string]$link['slug']; name = $stimName })
        }
    }

    return , $results.ToArray()
}

function Get-ChangedSpecStimulusArtifact {
    <#
    .SYNOPSIS
    Resolves changed eval-spec stimuli into synthetic artifact descriptors.

    .DESCRIPTION
    Diffs `EvalRoot` between two git refs, and for each changed spec compares the
    base and head stimulus signatures to find added or modified stimuli. Each
    changed stimulus's `tags.<kind>: <slug>` backlink becomes a synthetic artifact
    `@{ kind; artifactId; path; status; stimulusName; source }` that the executor
    runs scoped to that stimulus. Results are deduplicated by `kind:artifactId`.

    .PARAMETER BaseRef
    Base git ref for the diff. Defaults to `origin/main`.

    .PARAMETER HeadRef
    Head git ref for the diff. Defaults to `HEAD`. Change detection uses the
    three-dot `BaseRef...HeadRef` diff (matching `Get-ChangedAIArtifact.ps1`), so
    the head change must be committed (as it always is for a PR head).

    .PARAMETER RepoRoot
    Repository root. Defaults to `git rev-parse --show-toplevel`.

    .PARAMETER EvalRoot
    Eval spec root relative to the repository root. Defaults to `evals`.

    .PARAMETER GitCommand
    Path or name of the git executable. Defaults to `git`. Overridable for tests.

    .OUTPUTS
    [hashtable[]] Synthetic artifact descriptors.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [string]$BaseRef = 'origin/main',
        [string]$HeadRef = 'HEAD',
        [string]$RepoRoot,
        [string]$EvalRoot = 'evals',
        [string]$GitCommand = 'git'
    )

    if ([string]::IsNullOrWhiteSpace($RepoRoot)) {
        $top = & $GitCommand rev-parse --show-toplevel 2>$null
        $RepoRoot = if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($top)) {
            (Resolve-Path -LiteralPath $top.Trim()).ProviderPath
        }
        else {
            (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '../../..')).ProviderPath
        }
    }

    $evalPrefix = ($EvalRoot.TrimEnd('/', '\') -replace '\\', '/') + '/'

    Push-Location -LiteralPath $RepoRoot
    try {
        $diff = & $GitCommand diff --name-only "$BaseRef...$HeadRef" -- $EvalRoot 2>&1
        $exit = $LASTEXITCODE
        if ($exit -ne 0) {
            throw "git diff failed (exit $exit): $($diff -join [Environment]::NewLine)"
        }

        $specFiles = @($diff |
                Where-Object { $_ -is [string] -and -not [string]::IsNullOrWhiteSpace($_) } |
                ForEach-Object { ($_ -replace '\\', '/').Trim() } |
                Where-Object { $_ -match '\.ya?ml$' -and $_.StartsWith($evalPrefix) })

        $artifacts = [System.Collections.Generic.List[hashtable]]::new()
        $seen = @{}

        foreach ($spec in $specFiles) {
            $headPath = Join-Path -Path $RepoRoot -ChildPath $spec
            if (-not (Test-Path -LiteralPath $headPath -PathType Leaf)) { continue }
            $headYaml = Get-Content -LiteralPath $headPath -Raw -Encoding utf8

            $baseYaml = & $GitCommand show "$BaseRef`:$spec" 2>$null
            if ($LASTEXITCODE -ne 0) { $baseYaml = '' }
            else { $baseYaml = ($baseYaml -join [Environment]::NewLine) }

            $baseMap = Get-SpecStimulusSignatureMap -Yaml $baseYaml
            $headMap = Get-SpecStimulusSignatureMap -Yaml $headYaml
            $changedNames = Get-ChangedStimulusName -BaseMap $baseMap -HeadMap $headMap
            if ($changedNames.Count -eq 0) { continue }

            foreach ($link in (Get-StimulusBacklinkForName -Yaml $headYaml -Name $changedNames)) {
                $kind = [string]$link['kind']
                $slug = [string]$link['slug']
                if ([string]::IsNullOrWhiteSpace($kind) -or [string]::IsNullOrWhiteSpace($slug)) { continue }
                $key = "$kind`:$slug"
                if ($seen.ContainsKey($key)) { continue }
                $seen[$key] = $true
                $artifacts.Add(@{
                        kind         = $kind
                        artifactId   = $slug
                        path         = $spec
                        status       = 'M'
                        stimulusName = [string]$link['name']
                        source       = 'changed-spec'
                    })
            }
        }

        return , $artifacts.ToArray()
    }
    finally {
        Pop-Location
    }
}

Export-ModuleMember -Function @(
    'Get-SpecStimulusSignatureMap',
    'Get-ChangedStimulusName',
    'Get-StimulusBacklinkForName',
    'Get-ChangedSpecStimulusArtifact'
)
