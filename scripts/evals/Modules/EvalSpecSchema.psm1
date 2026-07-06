# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# EvalSpecSchema.psm1
#
# Purpose: Schema validation helpers for vally eval spec files under evals/.
# Author: HVE Core Team

#Requires -Version 7.4

Set-StrictMode -Version Latest

$script:AllowedExecutors = @('copilot-sdk')
$script:BacklinkTagKinds = @{
    skill       = @{ Glob = '.github/skills/**/{0}/SKILL.md' }
    agent       = @{ Glob = '.github/agents/**/{0}.agent.md' }
    prompt      = @{ Glob = '.github/prompts/**/{0}.prompt.md' }
    instruction = @{ Glob = '.github/instructions/**/{0}.instructions.md' }
}

function Resolve-EvalArtifactPath {
    <#
    .SYNOPSIS
    Resolves a stimulus backlink tag value to a concrete artifact path under .github/.

    .DESCRIPTION
    Locates the artifact file for a given backlink kind (skill/agent/prompt/instruction)
    and slug by globbing the appropriate directory tree under the repository's .github/.

    .PARAMETER RepoRoot
    Absolute path to the repository root.

    .PARAMETER Kind
    Backlink kind. One of: skill, agent, prompt, instruction.

    .PARAMETER Slug
    Artifact slug as referenced by the stimulus tag value.

    .OUTPUTS
    [string] Workspace-relative artifact path when found, otherwise $null.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateSet('skill', 'agent', 'prompt', 'instruction')]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Slug
    )

    if (-not $script:BacklinkTagKinds.ContainsKey($Kind)) {
        return $null
    }

    # Glob via Get-ChildItem since Join-Path does not expand wildcard segments.
    $githubRoot = Join-Path -Path $RepoRoot -ChildPath '.github'
    if (-not (Test-Path -LiteralPath $githubRoot -PathType Container)) {
        return $null
    }

    $leafPattern = switch ($Kind) {
        'skill'       { 'SKILL.md' }
        'agent'       { "$Slug.agent.md" }
        'prompt'      { "$Slug.prompt.md" }
        'instruction' { "$Slug.instructions.md" }
    }

    $candidates = Get-ChildItem -LiteralPath $githubRoot -Recurse -File -Filter $leafPattern -ErrorAction SilentlyContinue
    foreach ($candidate in $candidates) {
        if ($Kind -eq 'skill') {
            $parentName = Split-Path -Path (Split-Path -Path $candidate.FullName -Parent) -Leaf
            if ($parentName -ne $Slug) { continue }
        }
        $relPath = ($candidate.FullName.Substring($RepoRoot.Length)).TrimStart('\', '/').Replace('\', '/')
        return $relPath
    }

    return $null
}

function Test-EvalSpecCompliance {
    <#
    .SYNOPSIS
    Validates a parsed eval spec against the embedded schema.

    .DESCRIPTION
    Checks required top-level keys, executor whitelist, per-stimulus required keys
    (name, prompt, graders), and per-stimulus backlink tags (skill/agent/prompt/instruction)
    when present. Returns a list of errors with `path` and `message` for each violation.

    .PARAMETER Spec
    Parsed eval spec object (from ConvertFrom-Yaml).

    .PARAMETER SpecPath
    Workspace-relative path to the spec file, used for error annotations.

    .PARAMETER RepoRoot
    Absolute path to the repository root, used to resolve backlink artifacts.

    .OUTPUTS
    [System.Collections.Generic.List[hashtable]] List of error records with `path` and `message`.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        $Spec,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SpecPath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $errors = [System.Collections.Generic.List[hashtable]]::new()

    if ($null -eq $Spec) {
        $errors.Add(@{ path = $SpecPath; field = '<root>'; message = 'Spec is empty or could not be parsed' })
        return $errors
    }

    if (-not ($Spec -is [hashtable] -or $Spec -is [System.Collections.IDictionary])) {
        $errors.Add(@{ path = $SpecPath; field = '<root>'; message = 'Top-level YAML must be a mapping' })
        return $errors
    }

    if (-not $Spec.ContainsKey('name') -or [string]::IsNullOrWhiteSpace([string]$Spec['name'])) {
        $errors.Add(@{ path = $SpecPath; field = 'name'; message = 'Missing required key: name' })
    }

    $executor = $null
    if ($Spec.ContainsKey('defaults') -and $Spec['defaults'] -is [System.Collections.IDictionary]) {
        if ($Spec['defaults'].ContainsKey('executor')) {
            $executor = [string]$Spec['defaults']['executor']
        }
    }
    if ([string]::IsNullOrWhiteSpace($executor)) {
        $errors.Add(@{ path = $SpecPath; field = 'defaults.executor'; message = 'Missing required key: defaults.executor' })
    }
    elseif ($script:AllowedExecutors -notcontains $executor) {
        $allowed = $script:AllowedExecutors -join ', '
        $errors.Add(@{ path = $SpecPath; field = 'defaults.executor'; message = "Executor '$executor' is not in the whitelist ($allowed)" })
    }

    if ($Spec.ContainsKey('moderation')) {
        $moderation = $Spec['moderation']
        if (-not ($moderation -is [System.Collections.IDictionary])) {
            $errors.Add(@{ path = $SpecPath; field = 'moderation'; message = 'moderation must be a mapping' })
        }
        elseif ($moderation.ContainsKey('threshold')) {
            $thresholdRaw = $moderation['threshold']
            $thresholdValue = $null
            $isNumeric = $false
            if ($thresholdRaw -is [double] -or $thresholdRaw -is [single] -or $thresholdRaw -is [decimal] -or
                $thresholdRaw -is [int] -or $thresholdRaw -is [long] -or $thresholdRaw -is [byte]) {
                $thresholdValue = [double]$thresholdRaw
                $isNumeric = $true
            }
            if (-not $isNumeric) {
                $errors.Add(@{ path = $SpecPath; field = 'moderation.threshold'; message = 'moderation.threshold must be a number between 0.0 and 1.0 inclusive' })
            }
            elseif ($thresholdValue -lt 0.0 -or $thresholdValue -gt 1.0) {
                $errors.Add(@{ path = $SpecPath; field = 'moderation.threshold'; message = "moderation.threshold ($thresholdValue) must be between 0.0 and 1.0 inclusive" })
            }
        }
    }

    if ($Spec.ContainsKey('environment')) {
        $environment = $Spec['environment']
        if ($environment -is [System.Collections.IDictionary]) {
            $specDir = Split-Path -Path (Join-Path -Path $RepoRoot -ChildPath $SpecPath) -Parent
            foreach ($entryKey in @('skills', 'files')) {
                if (-not $environment.ContainsKey($entryKey)) { continue }
                $entryPaths = @($environment[$entryKey])
                $entryIndex = -1
                foreach ($rawPath in $entryPaths) {
                    $entryIndex++
                    $pathString = [string]$rawPath
                    if ([string]::IsNullOrWhiteSpace($pathString)) {
                        $errors.Add(@{ path = $SpecPath; field = "environment.$entryKey[$entryIndex]"; message = "Empty environment.$entryKey path" })
                        continue
                    }
                    $resolved = [System.IO.Path]::GetFullPath((Join-Path -Path $specDir -ChildPath $pathString))
                    if (-not (Test-Path -LiteralPath $resolved)) {
                        $errors.Add(@{ path = $SpecPath; field = "environment.$entryKey[$entryIndex]"; message = "environment.$entryKey path '$pathString' does not resolve to an existing path (resolved to '$resolved'); vally resolves it relative to the spec directory" })
                    }
                }
            }
        }
    }

    if (-not $Spec.ContainsKey('stimuli')) {
        $errors.Add(@{ path = $SpecPath; field = 'stimuli'; message = 'Missing required key: stimuli' })
        return $errors
    }

    $stimuli = $Spec['stimuli']
    if ($null -eq $stimuli -or -not ($stimuli -is [System.Collections.IEnumerable]) -or $stimuli -is [string]) {
        $errors.Add(@{ path = $SpecPath; field = 'stimuli'; message = 'stimuli must be a non-empty array' })
        return $errors
    }

    $stimulusCount = 0
    $index = -1
    foreach ($stimulus in $stimuli) {
        $index++
        $stimulusCount++
        $fieldPrefix = "stimuli[$index]"

        if (-not ($stimulus -is [System.Collections.IDictionary])) {
            $errors.Add(@{ path = $SpecPath; field = $fieldPrefix; message = 'Stimulus must be a mapping' })
            continue
        }

        $stimulusName = if ($stimulus.ContainsKey('name')) { [string]$stimulus['name'] } else { '' }
        $stimulusLabel = if ([string]::IsNullOrWhiteSpace($stimulusName)) { $fieldPrefix } else { "$fieldPrefix ($stimulusName)" }

        if (-not $stimulus.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($stimulusName)) {
            $errors.Add(@{ path = $SpecPath; field = "$fieldPrefix.name"; message = 'Stimulus missing required key: name' })
        }

        if (-not $stimulus.ContainsKey('prompt') -or [string]::IsNullOrWhiteSpace([string]$stimulus['prompt'])) {
            $errors.Add(@{ path = $SpecPath; field = "$stimulusLabel.prompt"; message = 'Stimulus missing required key: prompt' })
        }

        $graders = if ($stimulus.ContainsKey('graders')) { $stimulus['graders'] } else { $null }
        $graderCount = 0
        if ($graders -is [System.Collections.IEnumerable] -and -not ($graders -is [string])) {
            foreach ($g in $graders) { $graderCount++ }
        }
        if ($graderCount -lt 1) {
            $errors.Add(@{ path = $SpecPath; field = "$stimulusLabel.graders"; message = 'Stimulus must declare at least one grader (assertion)' })
        }

        if ($stimulus.ContainsKey('tags') -and $stimulus['tags'] -is [System.Collections.IDictionary]) {
            foreach ($kind in $script:BacklinkTagKinds.Keys) {
                if (-not $stimulus['tags'].ContainsKey($kind)) { continue }
                $tagValue = $stimulus['tags'][$kind]
                $slugs = if ($tagValue -is [System.Collections.IEnumerable] -and -not ($tagValue -is [string])) {
                    @($tagValue | ForEach-Object { [string]$_ })
                } else {
                    @([string]$tagValue)
                }
                foreach ($slug in $slugs) {
                    if ([string]::IsNullOrWhiteSpace($slug)) {
                        $errors.Add(@{ path = $SpecPath; field = "$stimulusLabel.tags.$kind"; message = "Empty backlink tag '$kind'" })
                        continue
                    }
                    $resolved = Resolve-EvalArtifactPath -RepoRoot $RepoRoot -Kind $kind -Slug $slug
                    if ($null -eq $resolved) {
                        $errors.Add(@{ path = $SpecPath; field = "$stimulusLabel.tags.$kind"; message = "Backlink '$kind=$slug' does not resolve to an artifact under .github/" })
                    }
                }
            }
        }
    }

    if ($stimulusCount -eq 0) {
        $errors.Add(@{ path = $SpecPath; field = 'stimuli'; message = 'stimuli array must contain at least one stimulus' })
    }

    return $errors
}

Export-ModuleMember -Function @(
    'Test-EvalSpecCompliance',
    'Resolve-EvalArtifactPath'
)
