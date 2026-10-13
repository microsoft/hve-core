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

function Get-EvalSourceIssue {
    <#
    .SYNOPSIS
    Checks a source and its ancestors before an evaluation copies them.
    .PARAMETER Path
    Lexically resolved absolute source path.
    .PARAMETER Kind
    Expected source type: directory for skills, or an ordinary file or directory for files.
    .OUTPUTS
    [string] Missing or unsafe source reason, or $null for a regular local source.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('entry', 'directory')]
        [string]$Kind
    )

    if ($Path -match '^(?:[\\/]{2}|[\\/]\?\?[\\/])') {
        return 'UNC and device paths are not allowed'
    }
    if ($IsWindows -and [System.IO.DriveInfo]::new($Path).DriveType -eq [System.IO.DriveType]::Network) {
        return 'Network drives are not allowed'
    }

    $root = [System.IO.Path]::GetPathRoot($Path)
    if ($Path -eq $root) { return 'filesystem roots are not allowed as sources' }
    $separators = [char[]]@([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $current = $root
    foreach ($segment in $Path.Substring($root.Length).Split($separators, [System.StringSplitOptions]::RemoveEmptyEntries)) {
        $current = Join-Path $current $segment
        try {
            $component = Get-Item -LiteralPath $current -Force -ErrorAction Stop
        }
        catch [System.Management.Automation.ItemNotFoundException] {
            return 'missing'
        }
        if ($component.LinkType -in @('SymbolicLink', 'Junction') -or ($component.Attributes -band [System.IO.FileAttributes]::ReparsePoint)) {
            return "symbolic links and reparse points are not allowed ('$current')"
        }
        if ($current -ne $Path -and $component -isnot [System.IO.DirectoryInfo]) {
            return "source ancestor is not a directory ('$current')"
        }
    }

    if ($Kind -eq 'directory' -and $component -isnot [System.IO.DirectoryInfo]) {
        return "expected an ordinary $Kind ('$Path')"
    }
    if ($IsLinux -or $IsMacOS) {
        $modeText = if ($IsLinux) { & stat -c '%f' -- $Path } else { & stat -f '%p' $Path }
        if ($LASTEXITCODE -ne 0) { throw "Cannot inspect source type '$Path'." }
        $mode = [Convert]::ToInt64($modeText.Trim(), $(if ($IsLinux) { 16 } else { 8 }))
        $type = $mode -band 0xF000
        if ($type -ne 0x8000 -and $type -ne 0x4000) {
            return "source is not an ordinary file or directory ('$Path')"
        }
    }
    return $null
}

function Test-EvalSpecSources {
    <#
    .SYNOPSIS
    Validates root and stimulus environment sources before staging.
    .PARAMETER Spec
    Parsed evaluation specification.
    .PARAMETER SpecPath
    Spec path relative to the repository, used for diagnostics and source resolution.
    .PARAMETER RepoRoot
    Repository root containing the spec.
    .OUTPUTS
    [System.Collections.Generic.List[hashtable]] Indexed source errors.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Spec,

        [Parameter(Mandatory = $true)]
        [string]$SpecPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $errors = [System.Collections.Generic.List[hashtable]]::new()
    $specDir = Split-Path -Path (Join-Path -Path $RepoRoot -ChildPath $SpecPath) -Parent
    foreach ($errorRecord in (Test-EvalEnvironment -Owner $Spec -FieldPrefix '' -SpecPath $SpecPath -SpecDirectory $specDir)) {
        $errors.Add($errorRecord)
    }
    if ($Spec.Contains('stimuli') -and $Spec['stimuli'] -is [System.Collections.IEnumerable] -and $Spec['stimuli'] -isnot [string]) {
        $index = -1
        foreach ($stimulus in $Spec['stimuli']) {
            $index++
            if ($stimulus -isnot [System.Collections.IDictionary]) { continue }
            $name = if ($stimulus.Contains('name')) { [string]$stimulus['name'] } else { '' }
            $label = if ([string]::IsNullOrWhiteSpace($name)) { "stimuli[$index]" } else { "stimuli[$index] ($name)" }
            foreach ($errorRecord in (Test-EvalEnvironment -Owner $stimulus -FieldPrefix $label -SpecPath $SpecPath -SpecDirectory $specDir)) {
                $errors.Add($errorRecord)
            }
        }
    }
    return $errors
}

function Test-EvalEnvironment {
    <#
    .SYNOPSIS
    Validates an environment declaration on a spec or stimulus.

    .DESCRIPTION
    Checks alias conflicts and inline source paths relative to the spec directory.
    Named references are left to Vally's configuration resolver.

    .PARAMETER Owner
    Spec or stimulus mapping containing the optional environment declaration.

    .PARAMETER FieldPrefix
    Diagnostic prefix for the owning stimulus, or an empty string for the root.

    .PARAMETER SpecPath
    Workspace-relative spec path used for diagnostics.

    .PARAMETER SpecDirectory
    Absolute directory used to resolve environment sources.

    .OUTPUTS
    [System.Collections.Generic.List[hashtable]] Environment validation errors.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Generic.List[hashtable]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Owner,

        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$FieldPrefix,

        [Parameter(Mandatory = $true)]
        [string]$SpecPath,

        [Parameter(Mandatory = $true)]
        [string]$SpecDirectory
    )

    $errors = [System.Collections.Generic.List[hashtable]]::new()
    $hasModern = $Owner.Contains('agent_environment')
    $hasLegacy = $Owner.Contains('environment')
    if (-not $hasModern -and -not $hasLegacy) { return $errors }

    $key = if ($hasModern) { 'agent_environment' } else { 'environment' }
    $field = if ($FieldPrefix) { "$FieldPrefix.$key" } else { $key }
    if ($hasModern -and $hasLegacy) {
        $errors.Add(@{ path = $SpecPath; field = $field; message = "Specify either 'agent_environment' or its deprecated alias 'environment', not both" })
        return $errors
    }

    $environment = $Owner[$key]
    if ($environment -is [string] -and -not [string]::IsNullOrWhiteSpace($environment)) {
        return $errors
    }
    if ($environment -isnot [System.Collections.IDictionary]) {
        $errors.Add(@{ path = $SpecPath; field = $field; message = "$field must be a mapping or a non-empty named reference" })
        return $errors
    }

    foreach ($entryKey in @('skills', 'files')) {
        if (-not $environment.Contains($entryKey)) { continue }
        $entryIndex = -1
        foreach ($rawPath in @($environment[$entryKey])) {
            $entryIndex++
            $entryField = "$field.$entryKey[$entryIndex]"
            # File mappings stage src; dest is a workspace target, not a source.
            $pathString = if ($rawPath -is [System.Collections.IDictionary]) {
                if ($rawPath.Contains('src')) { [string]$rawPath['src'] } else { '' }
            }
            else {
                [string]$rawPath
            }
            if ([string]::IsNullOrWhiteSpace($pathString)) {
                $errors.Add(@{ path = $SpecPath; field = $entryField; message = "Empty $field.$entryKey path" })
                continue
            }
            if ($pathString -match '^(?:[\\/]{2}|[\\/]\?\?[\\/])') {
                $errors.Add(@{ path = $SpecPath; field = $entryField; message = "UNC and device paths are not allowed for $field.$entryKey source '$pathString'" })
                continue
            }
            try {
                $resolved = [System.IO.Path]::GetFullPath($pathString, $SpecDirectory)
                $kind = if ($entryKey -eq 'skills') { 'directory' } else { 'entry' }
                $issue = Get-EvalSourceIssue -Path $resolved -Kind $kind
                if ($issue -eq 'missing') {
                    $errors.Add(@{ path = $SpecPath; field = $entryField; message = "$field.$entryKey path '$pathString' does not resolve to an existing path (resolved to '$resolved'); vally resolves it relative to the spec directory" })
                }
                elseif ($issue) {
                    $errors.Add(@{ path = $SpecPath; field = $entryField; message = "Unsafe $field.$entryKey source '$pathString': $issue" })
                }
            }
            catch [System.ArgumentException] {
                $errors.Add(@{ path = $SpecPath; field = $entryField; message = "Invalid $field.$entryKey path" })
            }
            catch [System.NotSupportedException] {
                $errors.Add(@{ path = $SpecPath; field = $entryField; message = "Invalid $field.$entryKey path" })
            }
            catch [System.IO.PathTooLongException] {
                $errors.Add(@{ path = $SpecPath; field = $entryField; message = "Invalid $field.$entryKey path" })
            }
        }
    }

    return $errors
}

function Test-EvalSpecCompliance {
    <#
    .SYNOPSIS
    Validates a parsed eval spec against the embedded schema.

    .DESCRIPTION
    Checks required top-level keys, executor whitelist, per-stimulus required keys
    (name, prompt or turns, graders), and per-stimulus backlink tags (skill/agent/prompt/instruction)
    when present, plus root and stimulus environment source paths under either
    supported alias. Returns a list of errors with `path` and `message` for each violation.

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

    foreach ($errorRecord in (Test-EvalSpecSources -Spec $Spec -SpecPath $SpecPath -RepoRoot $RepoRoot)) {
        $errors.Add($errorRecord)
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
    $isComparisonSpec = $SpecPath.Replace('\', '/') -eq 'evals/baseline-equivalence/compare.eval.yml'
    $seenGraderNames = @{}
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
            $hasTurns = $false
            if ($stimulus.ContainsKey('turns')) {
                $turnsValue = $stimulus['turns']
                if ($turnsValue -is [System.Collections.IEnumerable] -and -not ($turnsValue -is [string])) {
                    foreach ($turn in $turnsValue) {
                        if (-not [string]::IsNullOrWhiteSpace([string]$turn)) { $hasTurns = $true; break }
                    }
                }
            }
            if (-not $hasTurns) {
                $errors.Add(@{ path = $SpecPath; field = "$stimulusLabel.prompt"; message = 'Stimulus missing required key: prompt or turns' })
            }
        }

        $graders = if ($stimulus.ContainsKey('graders')) { $stimulus['graders'] } else { $null }
        $graderCount = 0
        if ($graders -is [System.Collections.IEnumerable] -and -not ($graders -is [string])) {
            foreach ($g in $graders) { $graderCount++ }
        }
        if ($graderCount -lt 1) {
            $errors.Add(@{ path = $SpecPath; field = "$stimulusLabel.graders"; message = 'Stimulus must declare at least one grader (assertion)' })
        }
        else {
            $graderIndex = -1
            foreach ($grader in $graders) {
                $graderIndex++
                if ($grader -isnot [System.Collections.IDictionary] -or -not $grader.Contains('name')) {
                    continue
                }
                $graderName = [string]$grader['name']
                if ([string]::IsNullOrWhiteSpace($graderName)) {
                    continue
                }
                if ($graderName -cnotmatch '^[a-z0-9][a-z0-9-]{0,59}$') {
                    $errors.Add(@{
                            path    = $SpecPath
                            field   = "$stimulusLabel.graders[$graderIndex].name"
                            message = "Invalid grader name '$graderName'; names must contain only lowercase letters, digits, and hyphens, start with a letter or digit, and contain at most 60 characters"
                        })
                }
                if (-not $isComparisonSpec -and $seenGraderNames.ContainsKey($graderName)) {
                    $errors.Add(@{
                            path    = $SpecPath
                            field   = "$stimulusLabel.graders[$graderIndex].name"
                            message = "Duplicate grader name '$graderName'; first declared in stimulus '$($seenGraderNames[$graderName])'"
                        })
                }
                elseif (-not $seenGraderNames.ContainsKey($graderName)) {
                    $seenGraderNames[$graderName] = $stimulusName
                }
            }
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
    'Test-EvalSpecSources',
    'Resolve-EvalArtifactPath'
)
