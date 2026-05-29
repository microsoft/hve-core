# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Shared helpers for validating the HVE Core central manifest.

.DESCRIPTION
    Provides reusable object access, path validation, artifact discovery, and
    compatibility helpers for collections/core-manifest.yml validation.
#>

function Get-CoreManifestProperty {
    <#
    .SYNOPSIS
        Gets a named property from a manifest object.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            return $InputObject[$Name]
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        return $property.Value
    }

    return $null
}

function Get-CoreManifestRawProperty {
    <#
    .SYNOPSIS
        Gets a named property from a manifest object without enumerating list values.
    .DESCRIPTION
        PowerShell unwraps single-item collections when returned from a function.
        Use this helper at call sites that must distinguish a list from a scalar
        (for example, schema checks that reject a string where a list is required).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if ($null -eq $InputObject) {
        return $null
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        if ($InputObject.Contains($Name)) {
            $value = $InputObject[$Name]
            if ($null -eq $value) {
                return $null
            }
            return , $value
        }

        return $null
    }

    $property = $InputObject.PSObject.Properties[$Name]
    if ($null -ne $property) {
        if ($null -eq $property.Value) {
            return $null
        }
        return , $property.Value
    }

    return $null
}

function Get-CoreManifestKeys {
    <#
    .SYNOPSIS
        Gets property or dictionary keys from a manifest object.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject
    )

    if ($null -eq $InputObject) {
        return @()
    }

    if ($InputObject -is [System.Collections.IDictionary]) {
        return @($InputObject.Keys | ForEach-Object { [string]$_ })
    }

    return @($InputObject.PSObject.Properties.Name)
}

function ConvertTo-CoreManifestRelativePath {
    <#
    .SYNOPSIS
        Normalizes a manifest path to repository-relative slash form.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Path
    )

    return ($Path.Trim() -replace '\\', '/')
}

function Test-CoreManifestRelativePath {
    <#
    .SYNOPSIS
        Tests whether a manifest path is safely repository-relative.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ArtifactPath
    )

    $normalizedPath = ConvertTo-CoreManifestRelativePath -Path $ArtifactPath
    return -not ([System.IO.Path]::IsPathFullyQualified($ArtifactPath) -or
        $normalizedPath -match '^[A-Za-z]:' -or
        $normalizedPath -match '(^|/)\.\.(/|$)' -or
        $normalizedPath -match '^/' -or
        $ArtifactPath -match '^\\')
}

function Read-CoreManifest {
    <#
    .SYNOPSIS
        Reads and parses the central manifest YAML file.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath
    )

    if (-not (Test-Path -Path $ManifestPath -PathType Leaf)) {
        throw "Manifest file '$ManifestPath' does not exist."
    }

    try {
        return Get-Content -Path $ManifestPath -Raw | ConvertFrom-Yaml
    }
    catch {
        throw "Manifest file '$ManifestPath' could not be parsed: $($_.Exception.Message)"
    }
}

function Test-CoreManifestKindPath {
    <#
    .SYNOPSIS
        Validates artifact path conventions for a manifest section.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agents', 'prompts', 'instructions', 'skills')]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [bool]$AllowMissing
    )

    $normalizedPath = ConvertTo-CoreManifestRelativePath -Path $ArtifactPath
    switch ($Section) {
        'agents' {
            if ($normalizedPath -notmatch '^\.github/agents/.+\.agent\.md$') {
                return "agents entry '$ArtifactPath' must be a .github/agents/**/*.agent.md path."
            }
        }
        'prompts' {
            if ($normalizedPath -notmatch '^\.github/prompts/.+\.prompt\.md$') {
                return "prompts entry '$ArtifactPath' must be a .github/prompts/**/*.prompt.md path."
            }
        }
        'instructions' {
            if ($normalizedPath -notmatch '^\.github/instructions/.+\.instructions\.md$') {
                return "instructions entry '$ArtifactPath' must be a .github/instructions/**/*.instructions.md path."
            }
        }
        'skills' {
            if ($normalizedPath -notmatch '^\.github/skills/.+') {
                return "skills entry '$ArtifactPath' must be a .github/skills/** directory path."
            }

            if ($normalizedPath -match '/SKILL\.md$') {
                return "skills entry '$ArtifactPath' must reference the skill directory, not SKILL.md."
            }

            if (-not $AllowMissing) {
                $skillFile = Join-Path -Path (Join-Path -Path $RepoRoot -ChildPath $ArtifactPath) -ChildPath 'SKILL.md'
                if (-not (Test-Path -Path $skillFile -PathType Leaf)) {
                    return "skills entry '$ArtifactPath' must contain SKILL.md."
                }
            }
        }
    }

    return ''
}

function Get-CoreManifestArtifactFiles {
    <#
    .SYNOPSIS
        Discovers current artifact paths that can appear in the manifest.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $paths = [System.Collections.Generic.List[string]]::new()
    $artifactSearches = @(
        @{ Root = '.github/agents'; Filter = '*.agent.md' },
        @{ Root = '.github/prompts'; Filter = '*.prompt.md' },
        @{ Root = '.github/instructions'; Filter = '*.instructions.md' }
    )

    foreach ($search in $artifactSearches) {
        $artifactRoot = Join-Path -Path $RepoRoot -ChildPath $search.Root
        if (-not (Test-Path -Path $artifactRoot -PathType Container)) {
            continue
        }

        Get-ChildItem -Path $artifactRoot -Filter $search.Filter -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName)
            $paths.Add((ConvertTo-CoreManifestRelativePath -Path $relativePath))
        }
    }

    $skillsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/skills'
    if (Test-Path -Path $skillsRoot -PathType Container) {
        Get-ChildItem -Path $skillsRoot -Filter 'SKILL.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $_.DirectoryName)
            $paths.Add((ConvertTo-CoreManifestRelativePath -Path $relativePath))
        }
    }

    return @($paths)
}

function ConvertTo-CoreManifestReferenceName {
    <#
    .SYNOPSIS
        Normalizes human-facing manifest reference names for comparison.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name
    )

    $normalizedName = ($Name.Trim() -replace '\s+', ' ')
    return ($normalizedName -replace '\s+\((exp|pre|preview|experimental|stable)\)$', '').Trim()
}

function Get-CoreManifestAgentDisplayNames {
    <#
    .SYNOPSIS
        Discovers agent display names from leading YAML frontmatter.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $agentNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $agentsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/agents'
    if (-not (Test-Path -Path $agentsRoot -PathType Container)) {
        return @()
    }

    Get-ChildItem -Path $agentsRoot -Filter '*.agent.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            return
        }

        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $Matches[1]
            $name = Get-CoreManifestProperty -InputObject $frontmatter -Name 'name'
            if (-not [string]::IsNullOrWhiteSpace([string]$name)) {
                [void]$agentNames.Add((ConvertTo-CoreManifestReferenceName -Name ([string]$name)))
            }
        }
        catch {
            Write-Warning "Failed to parse agent frontmatter from $($_.FullName): $($_.Exception.Message)"
        }
    }

    return @($agentNames)
}

function Test-CoreManifestReferenceMetadata {
    <#
    .SYNOPSIS
        Validates optional dependency and handoff metadata for an artifact entry.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Section,

        [Parameter(Mandatory = $true)]
        [string]$ArtifactKey,

        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Entry,

        [Parameter()]
        [string[]]$KnownAgentNames = @()
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $knownAgentSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($agentName in $KnownAgentNames) {
        if (-not [string]::IsNullOrWhiteSpace($agentName)) {
            [void]$knownAgentSet.Add((ConvertTo-CoreManifestReferenceName -Name $agentName))
        }
    }

    $requires = Get-CoreManifestProperty -InputObject $Entry -Name 'requires'
    if ($null -ne $requires) {
        $requiredAgents = Get-CoreManifestRawProperty -InputObject $requires -Name 'agents'
        if ($null -ne $requiredAgents) {
            if ($requiredAgents -is [string]) {
                $errors.Add("$Section entry '$ArtifactKey' requires.agents must be a list.")
            }
            else {
                foreach ($agentReference in @($requiredAgents)) {
                    if ([string]::IsNullOrWhiteSpace([string]$agentReference)) {
                        $errors.Add("$Section entry '$ArtifactKey' requires.agents contains an empty agent reference.")
                        continue
                    }

                    $normalizedReference = ConvertTo-CoreManifestReferenceName -Name ([string]$agentReference)
                    if ($knownAgentSet.Count -gt 0 -and -not $knownAgentSet.Contains($normalizedReference)) {
                        $warnings.Add("$Section entry '$ArtifactKey' requires.agents references agent '$agentReference' that was not found in agent frontmatter names.")
                    }
                }
            }
        }
    }

    $handoffs = Get-CoreManifestRawProperty -InputObject $Entry -Name 'handoffs'
    if ($null -ne $handoffs) {
        if ($handoffs -is [string] -or $handoffs -is [System.Collections.IDictionary]) {
            $errors.Add("$Section entry '$ArtifactKey' handoffs must be a list.")
        }
        else {
            foreach ($handoff in @($handoffs)) {
                $prompt = Get-CoreManifestProperty -InputObject $handoff -Name 'prompt'
                $agent = Get-CoreManifestProperty -InputObject $handoff -Name 'agent'
                $label = Get-CoreManifestProperty -InputObject $handoff -Name 'label'
                $send = Get-CoreManifestProperty -InputObject $handoff -Name 'send'

                if ([string]::IsNullOrWhiteSpace([string]$prompt)) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs contains an entry with an empty prompt.")
                }

                if ([string]::IsNullOrWhiteSpace([string]$agent)) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs contains an entry with an empty agent.")
                }
                else {
                    $normalizedAgent = ConvertTo-CoreManifestReferenceName -Name ([string]$agent)
                    if ($knownAgentSet.Count -gt 0 -and -not $knownAgentSet.Contains($normalizedAgent)) {
                        $warnings.Add("$Section entry '$ArtifactKey' handoffs references agent '$agent' that was not found in agent frontmatter names.")
                    }
                }

                if ([string]::IsNullOrWhiteSpace([string]$label)) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs contains an entry with an empty label.")
                }

                if ($null -ne $send -and $send -isnot [bool]) {
                    $errors.Add("$Section entry '$ArtifactKey' handoffs send value must be boolean when present.")
                }
            }
        }
    }

    return @{
        Errors   = @($errors)
        Warnings = @($warnings)
    }
}

function Get-CoreManifestMaturityRank {
    <#
    .SYNOPSIS
        Returns the comparison rank for a manifest maturity value.
    .DESCRIPTION
        Ranks shippable maturities so dependency edges can be compared:
        stable = 3, preview = 2, experimental = 1. Lifecycle-end states
        (deprecated, removed) and unrecognized values return $null, signalling
        that the value must be skipped rather than ranked.
    .PARAMETER Maturity
        The maturity string to rank.
    .OUTPUTS
        [int] The rank (3/2/1) for a shippable maturity, or $null for
        deprecated, removed, empty, or unknown values.
    .EXAMPLE
        Get-CoreManifestMaturityRank -Maturity 'stable'
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Maturity
    )

    if ([string]::IsNullOrWhiteSpace($Maturity)) {
        return $null
    }

    $ranks = @{
        stable       = 3
        preview      = 2
        experimental = 1
    }

    $normalizedMaturity = $Maturity.Trim().ToLowerInvariant()
    if ($ranks.ContainsKey($normalizedMaturity)) {
        return $ranks[$normalizedMaturity]
    }

    return $null
}

function Get-CoreManifestArtifactSectionNames {
    <#
    .SYNOPSIS
        Returns the canonical ordered list of manifest artifact section names.
    .DESCRIPTION
        Provides the single source of truth for the artifact-bearing manifest
        sections (agents, prompts, instructions, skills) so enumeration logic in
        Validate-CoreManifest.ps1 and Get-CoreManifestMaturityMap stays in sync.
    .OUTPUTS
        [string[]] The artifact section names in canonical order.
    .EXAMPLE
        Get-CoreManifestArtifactSectionNames
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return @('agents', 'prompts', 'instructions', 'skills')
}

function Get-CoreManifestMaturityMap {
    <#
    .SYNOPSIS
        Builds a path-to-maturity lookup for every asset in the manifest.
    .DESCRIPTION
        Iterates the agents, prompts, instructions, and skills sections of a
        parsed manifest and returns a hashtable keyed by normalized
        repo-relative asset path with the asset's maturity string as the value.
        Mirrors the per-section enumeration performed by Validate-CoreManifest.ps1
        when it populates $artifactEntries.
    .PARAMETER Manifest
        The parsed manifest object (from Read-CoreManifest).
    .OUTPUTS
        [hashtable] Normalized asset path -> maturity string.
    .EXAMPLE
        $map = Get-CoreManifestMaturityMap -Manifest (Read-CoreManifest -ManifestPath $path)
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [object]$Manifest
    )

    $maturityMap = @{}
    if ($null -eq $Manifest) {
        return $maturityMap
    }

    foreach ($sectionName in (Get-CoreManifestArtifactSectionNames)) {
        $section = Get-CoreManifestProperty -InputObject $Manifest -Name $sectionName
        if ($null -eq $section) {
            continue
        }

        foreach ($artifactKey in (Get-CoreManifestKeys -InputObject $section)) {
            $entry = Get-CoreManifestProperty -InputObject $section -Name $artifactKey
            $entryPath = Get-CoreManifestProperty -InputObject $entry -Name 'path'
            if ([string]::IsNullOrWhiteSpace([string]$entryPath)) {
                continue
            }

            $normalizedPath = ConvertTo-CoreManifestRelativePath -Path ([string]$entryPath)
            $maturityMap[$normalizedPath] = [string](Get-CoreManifestProperty -InputObject $entry -Name 'maturity')
        }
    }

    return $maturityMap
}

function Get-CoreManifestAgentNameIndex {
    <#
    .SYNOPSIS
        Builds an agent display-name-to-path index from agent frontmatter.
    .DESCRIPTION
        Scans every .github/agents/**/*.agent.md file for its leading YAML
        frontmatter 'name' value and returns a hashtable keyed by the normalized
        display name with the repo-relative agent path as the value. The keys are
        normalized with ConvertTo-CoreManifestReferenceName so callers can resolve
        manifest references (requires.agents, handoffs[].agent) to a concrete path.
    .PARAMETER RepoRoot
        Root directory of the repository.
    .OUTPUTS
        [hashtable] Normalized agent display name -> repo-relative agent path.
    .EXAMPLE
        $index = Get-CoreManifestAgentNameIndex -RepoRoot $repoRoot
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $nameIndex = @{}
    $agentsRoot = Join-Path -Path $RepoRoot -ChildPath '.github/agents'
    if (-not (Test-Path -Path $agentsRoot -PathType Container)) {
        return $nameIndex
    }

    Get-ChildItem -Path $agentsRoot -Filter '*.agent.md' -File -Recurse -ErrorAction SilentlyContinue | ForEach-Object {
        $content = Get-Content -Path $_.FullName -Raw
        if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            return
        }

        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $Matches[1]
            $name = Get-CoreManifestProperty -InputObject $frontmatter -Name 'name'
            if ([string]::IsNullOrWhiteSpace([string]$name)) {
                return
            }

            $normalizedName = ConvertTo-CoreManifestReferenceName -Name ([string]$name)
            $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $_.FullName)
            $nameIndex[$normalizedName] = ConvertTo-CoreManifestRelativePath -Path $relativePath
        }
        catch {
            Write-Warning "Failed to parse agent frontmatter from $($_.FullName): $($_.Exception.Message)"
        }
    }

    return $nameIndex
}

function Resolve-CoreManifestReferenceTarget {
    <#
    .SYNOPSIS
        Resolves a manifest dependency reference to its target asset path.
    .DESCRIPTION
        Maps a dependency reference to the manifest asset path it points at so
        the target's maturity can be looked up. Agent references (requires.agents,
        handoffs[].agent) are display names resolved via the supplied name index.
        Prompt references (handoffs[].prompt) that begin with '/' are slash
        commands resolved to the prompt asset whose file basename matches the
        command; prompt references that do not begin with '/' are free text and
        return $null. Unresolvable references return $null.
    .PARAMETER Reference
        The raw reference value from the manifest.
    .PARAMETER ReferenceKind
        Whether the reference is an 'agent' display name or a 'prompt' value.
    .PARAMETER AgentNameIndex
        Hashtable mapping normalized agent display names to agent paths
        (from Get-CoreManifestAgentNameIndex). Required for agent references.
    .PARAMETER MaturityMap
        Hashtable of normalized asset paths (from Get-CoreManifestMaturityMap),
        used to locate the prompt asset for a slash-command reference.
    .OUTPUTS
        [string] The resolved target asset path, or $null when unresolvable.
    .EXAMPLE
        Resolve-CoreManifestReferenceTarget -Reference '/ado-triage-work-items' -ReferenceKind 'prompt' -MaturityMap $map
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$Reference,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt')]
        [string]$ReferenceKind,

        [Parameter(Mandatory = $false)]
        [hashtable]$AgentNameIndex = @{},

        [Parameter(Mandatory = $false)]
        [hashtable]$MaturityMap = @{}
    )

    if ([string]::IsNullOrWhiteSpace($Reference)) {
        return $null
    }

    switch ($ReferenceKind) {
        'agent' {
            $normalizedReference = ConvertTo-CoreManifestReferenceName -Name $Reference
            if ($AgentNameIndex.ContainsKey($normalizedReference)) {
                return [string]$AgentNameIndex[$normalizedReference]
            }

            return $null
        }
        'prompt' {
            $trimmedReference = $Reference.Trim()
            if (-not $trimmedReference.StartsWith('/')) {
                return $null
            }

            $command = ($trimmedReference.TrimStart('/') -split '\s+', 2)[0]
            if ([string]::IsNullOrWhiteSpace($command)) {
                return $null
            }

            $expectedBaseName = "$command.prompt.md"
            foreach ($candidatePath in $MaturityMap.Keys) {
                $candidate = [string]$candidatePath
                if ($candidate -notmatch '^\.github/prompts/') {
                    continue
                }

                $candidateBaseName = ($candidate -split '/')[-1]
                if ($candidateBaseName -eq $expectedBaseName) {
                    return $candidate
                }
            }

            return $null
        }
    }

    return $null
}

function Resolve-CoreManifestEmbeddedToken {
    <#
    .SYNOPSIS
        Resolves a single embedded reference token to concrete manifest asset paths.
    .DESCRIPTION
        Normalizes one extracted reference token and resolves it against the
        maturity map. Handles three forms: a direct asset path, a '/SKILL.md'
        suffix that maps to its containing skill directory, and a glob whose
        final segment is a concrete file name matched against the map keys.
        Bare directory globs (no concrete file name) resolve to nothing.
    .PARAMETER Token
        The raw reference token extracted from source content.
    .PARAMETER MaturityMap
        Hashtable of normalized asset paths used to resolve the token.
    .OUTPUTS
        [string[]] Zero or more resolved manifest asset paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Token,

        [Parameter(Mandatory = $true)]
        [hashtable]$MaturityMap
    )

    $normalizedToken = (ConvertTo-CoreManifestRelativePath -Path $Token) -replace '^\./', ''
    if ([string]::IsNullOrWhiteSpace($normalizedToken)) {
        return @()
    }

    if ($MaturityMap.ContainsKey($normalizedToken)) {
        return @($normalizedToken)
    }

    if ($normalizedToken.EndsWith('/SKILL.md')) {
        $skillDirectory = $normalizedToken -replace '/SKILL\.md$', ''
        if ($MaturityMap.ContainsKey($skillDirectory)) {
            return @($skillDirectory)
        }
        return @()
    }

    if (-not $normalizedToken.Contains('*')) {
        return @()
    }

    $tokenBaseName = ($normalizedToken -split '/')[-1]
    if ([string]::IsNullOrWhiteSpace($tokenBaseName) -or $tokenBaseName.Contains('*')) {
        Write-Verbose "Skipping embedded glob '$normalizedToken' without a concrete file name."
        return @()
    }

    $matchedPaths = [System.Collections.Generic.List[string]]::new()
    foreach ($candidatePath in $MaturityMap.Keys) {
        $candidate = [string]$candidatePath
        $candidateBaseName = ($candidate -split '/')[-1]
        if ($candidateBaseName -eq $tokenBaseName) {
            $matchedPaths.Add($candidate)
        }
    }

    return @($matchedPaths)
}

function Get-CoreManifestEmbeddedReferences {
    <#
    .SYNOPSIS
        Extracts embedded manifest-asset dependency edges from an asset's source.
    .DESCRIPTION
        Scans a source file for embedded references that reach another shipped
        asset and resolves each to a concrete manifest asset path via the supplied
        maturity map. Only two reference forms are treated as dependency edges:
        '#file:' directives that target a path under .github/, and concrete
        artifact path or glob references whose final segment is a real artifact
        file name (for example .github/agents/**/researcher-subagent.agent.md).
        Bare directory globs such as .github/agents/** carry no concrete file name
        and are ignored, which prevents false positives from documentation tables
        and prose that merely name a directory. A glob resolves by matching its
        file basename against the maturity-map keys; a glob matching multiple
        paths yields one edge per matched path.
    .PARAMETER SourcePath
        Absolute or repo-relative path to the source file to scan.
    .PARAMETER MaturityMap
        Hashtable of normalized asset paths (from Get-CoreManifestMaturityMap)
        used to resolve references to concrete manifest assets.
    .OUTPUTS
        [string[]] The distinct, sorted set of resolved target asset paths.
    .EXAMPLE
        Get-CoreManifestEmbeddedReferences -SourcePath $agentPath -MaturityMap $map
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$MaturityMap
    )

    if (-not (Test-Path -Path $SourcePath -PathType Leaf)) {
        return @()
    }

    $content = Get-Content -Path $SourcePath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) {
        return @()
    }

    $resolvedTargets = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $referenceTokens = [System.Collections.Generic.List[string]]::new()

    foreach ($fileMatch in [regex]::Matches($content, '(?i)#file:\s*([^\s)`''"]+)')) {
        $referenceTokens.Add($fileMatch.Groups[1].Value)
    }

    $pathPattern = '\.github/(?:agents|prompts|instructions|skills)/[A-Za-z0-9_./*-]*?[\w.-]+\.(?:agent|prompt|instructions)\.md'
    foreach ($pathMatch in [regex]::Matches($content, $pathPattern)) {
        $referenceTokens.Add($pathMatch.Value)
    }

    foreach ($token in $referenceTokens) {
        foreach ($resolved in (Resolve-CoreManifestEmbeddedToken -Token $token -MaturityMap $MaturityMap)) {
            [void]$resolvedTargets.Add($resolved)
        }
    }

    return @($resolvedTargets | Sort-Object)
}

Export-ModuleMember -Function @(
    'ConvertTo-CoreManifestReferenceName',
    'ConvertTo-CoreManifestRelativePath',
    'Get-CoreManifestAgentDisplayNames',
    'Get-CoreManifestAgentNameIndex',
    'Get-CoreManifestArtifactFiles',
    'Get-CoreManifestArtifactSectionNames',
    'Get-CoreManifestEmbeddedReferences',
    'Get-CoreManifestKeys',
    'Get-CoreManifestMaturityMap',
    'Get-CoreManifestMaturityRank',
    'Get-CoreManifestProperty',
    'Get-CoreManifestRawProperty',
    'Read-CoreManifest',
    'Resolve-CoreManifestEmbeddedToken',
    'Resolve-CoreManifestReferenceTarget',
    'Test-CoreManifestKindPath',
    'Test-CoreManifestReferenceMetadata',
    'Test-CoreManifestRelativePath'
)
