# Copyright (c) 2026 Microsoft Corporation. All rights reserved.
# SPDX-License-Identifier: MIT

# MarketplaceHelpers.psm1
# Purpose: Shared marketplace catalog contract, projection, indexing, and closure utilities.

#Requires -Version 7.4
#Requires -Modules @{ ModuleName='PowerShell-Yaml'; RequiredVersion='0.4.7' }

Import-Module (Join-Path $PSScriptRoot 'ArtifactHelpers.psm1') -Force

function Get-PluginItemName {
    <#
    .SYNOPSIS
    Returns an artifact filename in package form.
    .PARAMETER FileName
    Source filename.
    .PARAMETER Kind
    Artifact kind.
    .OUTPUTS
    [string] Package filename.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FileName,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    switch ($Kind) {
        'agent' { return $FileName -replace '\.agent\.md$', '.md' }
        'prompt' { return $FileName -replace '\.prompt\.md$', '.md' }
        default { return $FileName }
    }
}

function Get-PluginItemSubpath {
    <#
    .SYNOPSIS
    Returns the path between an artifact root and leaf.
    .PARAMETER Path
    Repository-relative source path.
    .PARAMETER Kind
    Artifact kind.
    .OUTPUTS
    [string] Intermediate path or an empty string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    $prefixMap = @{
        agent       = '.github/agents/'
        prompt      = '.github/prompts/'
        instruction = '.github/instructions/'
        skill       = '.github/skills/'
        hook        = '.github/hooks/'
    }
    $normalized = $Path -replace '\\', '/'
    $prefix = $prefixMap[$Kind]
    if (-not $normalized.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
        return ''
    }

    $parts = $normalized.Substring($prefix.Length) -split '/'
    if ($parts.Count -gt 1) {
        return $parts[0..($parts.Count - 2)] -join '/'
    }

    return ''
}

function Get-PluginSubdirectory {
    <#
    .SYNOPSIS
    Returns the package directory for an artifact kind.
    .PARAMETER Kind
    Artifact kind.
    .OUTPUTS
    [string] Standard component directory.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    return @{
        agent       = 'agents'
        prompt      = 'commands'
        instruction = 'rules'
        skill       = 'skills'
        hook        = 'hooks'
    }[$Kind]
}

function Get-MarketplaceComponentFieldMap {
    <#
    .SYNOPSIS
    Returns standard marketplace fields and artifact kinds.
    .OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] Field-to-kind map.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        agents   = 'agent'
        commands = 'prompt'
        rules    = 'instruction'
        skills   = 'skill'
        hooks    = 'hook'
    }
}

function Get-MarketplaceMetadataKey {
    <#
    .SYNOPSIS
    Returns the closed x-hve metadata key set.
    .OUTPUTS
    [string[]] Permitted metadata keys.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return , @('displayName', 'maturity', 'componentMaturity', 'documentation', 'profiles')
}

function Get-MarketplaceComponentSourceRoot {
    <#
    .SYNOPSIS
    Returns canonical source roots and suffixes by marketplace field.
    .OUTPUTS
    [System.Collections.Specialized.OrderedDictionary] Field descriptors.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param()

    return [ordered]@{
        agents   = @{ Kind = 'agent'; SourceRoot = '.github/agents'; SourceSuffix = '.agent.md'; PackageSuffix = '.md' }
        commands = @{ Kind = 'prompt'; SourceRoot = '.github/prompts'; SourceSuffix = '.prompt.md'; PackageSuffix = '.md' }
        rules    = @{ Kind = 'instruction'; SourceRoot = '.github/instructions'; SourceSuffix = '.instructions.md'; PackageSuffix = '.instructions.md' }
        skills   = @{ Kind = 'skill'; SourceRoot = '.github/skills'; SourceSuffix = ''; PackageSuffix = '' }
        hooks    = @{ Kind = 'hook'; SourceRoot = '.github/hooks'; SourceSuffix = '.json'; PackageSuffix = '.json' }
    }
}

function Get-MarketplaceComponentField {
    <#
    .SYNOPSIS
    Returns the marketplace field for an artifact kind.
    .PARAMETER Kind
    Artifact kind.
    .OUTPUTS
    [string] Marketplace field.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    return Get-PluginSubdirectory -Kind $Kind
}

function Resolve-MarketplaceComponentPath {
    <#
    .SYNOPSIS
    Normalizes and validates a package-relative component path.
    .PARAMETER Path
    Candidate component path.
    .OUTPUTS
    [hashtable] Normalized Path and Error.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [AllowNull()]
        [string]$Path
    )

    $candidate = if ($null -eq $Path) { '' } else { $Path.Trim() }
    if ([string]::IsNullOrWhiteSpace($candidate)) {
        return @{ Path = ''; Error = 'component path must be a non-empty string' }
    }
    if ($candidate -match '\p{C}') {
        return @{ Path = ''; Error = "component path '$candidate' must not contain control characters" }
    }
    if ($candidate -match '\\') {
        return @{ Path = ''; Error = "component path '$candidate' must use forward slashes" }
    }
    if ($candidate -match '^/' -or $candidate -match '^[A-Za-z]:') {
        return @{ Path = ''; Error = "component path '$candidate' must be relative to the package root" }
    }

    $normalized = $candidate.TrimEnd('/')
    foreach ($segment in ($normalized -split '/')) {
        if ([string]::IsNullOrEmpty($segment)) {
            return @{ Path = ''; Error = "component path '$candidate' must not contain empty path segments" }
        }
        if ($segment -eq '..') {
            return @{ Path = ''; Error = "component path '$candidate' must not escape the package root" }
        }
        if ($segment -eq '.') {
            return @{ Path = ''; Error = "component path '$candidate' must not contain relative path segments" }
        }
    }

    return @{ Path = $normalized; Error = '' }
}

function Get-MarketplacePackagePath {
    <#
    .SYNOPSIS
    Projects a canonical source path to a package component path.
    .PARAMETER SourcePath
    Repository-relative source path.
    .PARAMETER Kind
    Artifact kind.
    .OUTPUTS
    [string] Package-relative path.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agent', 'prompt', 'instruction', 'skill', 'hook')]
        [string]$Kind
    )

    $normalized = ($SourcePath -replace '\\', '/').TrimEnd('/')
    $field = Get-PluginSubdirectory -Kind $Kind
    $descriptor = (Get-MarketplaceComponentSourceRoot)[$field]
    $expectedRoot = "$($descriptor.SourceRoot)/"
    if (-not $normalized.StartsWith($expectedRoot, [System.StringComparison]::Ordinal)) {
        throw "Source path '$SourcePath' is not under the canonical '$($descriptor.SourceRoot)' root for kind '$Kind'."
    }

    $leaf = Get-PluginItemName -FileName (Split-Path -Leaf $normalized) -Kind $Kind
    $subpath = Get-PluginItemSubpath -Path $normalized -Kind $Kind
    if ($subpath) {
        return "$field/$subpath/$leaf"
    }
    return "$field/$leaf"
}

function Resolve-MarketplaceComponentSource {
    <#
    .SYNOPSIS
    Resolves a package component path to its canonical source.
    .PARAMETER PackagePath
    Package-relative component path.
    .PARAMETER Field
    Standard component field.
    .OUTPUTS
    [hashtable] Kind, PackagePath, and SourcePath.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PackagePath,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agents', 'commands', 'rules', 'skills', 'hooks')]
        [string]$Field
    )

    $resolved = Resolve-MarketplaceComponentPath -Path $PackagePath
    if ($resolved.Error) {
        throw "Component field '$Field': $($resolved.Error)"
    }

    $prefix = "$Field/"
    if (-not $resolved.Path.StartsWith($prefix, [System.StringComparison]::Ordinal)) {
        throw "Component path '$PackagePath' must start with the '$Field/' package directory."
    }

    $descriptor = (Get-MarketplaceComponentSourceRoot)[$Field]
    $relative = $resolved.Path.Substring($prefix.Length)
    if ($descriptor.PackageSuffix) {
        if (-not $relative.EndsWith($descriptor.PackageSuffix, [System.StringComparison]::Ordinal)) {
            throw "Component path '$PackagePath' must end with '$($descriptor.PackageSuffix)'."
        }
        $relative = "$($relative.Substring(0, $relative.Length - $descriptor.PackageSuffix.Length))$($descriptor.SourceSuffix)"
    }

    return @{ Kind = $descriptor.Kind; PackagePath = $resolved.Path; SourcePath = "$($descriptor.SourceRoot)/$relative" }
}

function Get-MarketplaceCatalog {
    <#
    .SYNOPSIS
    Loads the marketplace catalog.
    .PARAMETER Path
    Catalog path.
    .OUTPUTS
    [hashtable] Parsed catalog.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Marketplace catalog not found: $Path"
    }

    $catalog = Get-Content -LiteralPath $Path -Raw -Encoding utf8 | ConvertFrom-Json -AsHashtable
    if ($null -eq $catalog -or -not $catalog.Contains('plugins')) {
        throw "Marketplace catalog '$Path' does not declare a plugins array."
    }
    return $catalog
}

function Get-MarketplaceEntryMaturity {
    <#
    .SYNOPSIS
    Returns package maturity.
    .PARAMETER Entry
    Marketplace entry.
    .OUTPUTS
    [string] Effective package maturity.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry
    )

    $value = Get-MarketplaceEntryOverlayValue -Entry $Entry -Key 'maturity'
    if ([string]::IsNullOrWhiteSpace([string]$value)) {
        return 'stable'
    }
    return [string]$value
}

function Get-MarketplaceEntryOverlayValue {
    <#
    .SYNOPSIS
    Reads an x-hve overlay value.
    .PARAMETER Entry
    Marketplace entry.
    .PARAMETER Key
    Overlay key.
    .OUTPUTS
    [object] Overlay value or null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Key
    )

    if (-not $Entry.Contains('x-hve') -or $Entry['x-hve'] -isnot [System.Collections.IDictionary]) {
        return $null
    }
    if ($Entry['x-hve'].Contains($Key)) {
        return $Entry['x-hve'][$Key]
    }
    return $null
}

function Get-MarketplaceActiveMaturity {
    <#
    .SYNOPSIS
    Returns the maturity values that both release channels distribute.
    .OUTPUTS
    [string[]] Active maturity values.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return , @('stable', 'preview', 'experimental')
}

function Get-MarketplaceComponentMaturityMap {
    <#
    .SYNOPSIS
    Returns declared per-component maturity keyed by package component path.
    .PARAMETER Entry
    Marketplace entry.
    .OUTPUTS
    [hashtable] Component path to declared maturity string.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry
    )

    $map = @{}
    $overlayValue = Get-MarketplaceEntryOverlayValue -Entry $Entry -Key 'componentMaturity'
    if ($overlayValue -is [System.Collections.IDictionary]) {
        foreach ($key in $overlayValue.Keys) {
            $map[[string]$key] = [string]$overlayValue[$key]
        }
    }
    return $map
}

function Test-MarketplaceEntryEligible {
    <#
    .SYNOPSIS
    Checks package eligibility for a release channel.
    .DESCRIPTION
    Stable and PreRelease distribute the same active content, so only
    deprecated and removed packages are excluded.
    .PARAMETER Entry
    Marketplace entry.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .OUTPUTS
    [bool] True when the package is eligible.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    return ((Get-MarketplaceEntryMaturity -Entry $Entry) -in (Get-MarketplaceActiveMaturity))
}

function Get-MarketplacePackageRecipe {
    <#
    .SYNOPSIS
    Projects a marketplace entry into a channel-filtered recipe.
    .PARAMETER Entry
    Marketplace entry.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .OUTPUTS
    [hashtable[]] Component recipe.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    $allowed = Get-MarketplaceActiveMaturity
    $componentMaturity = Get-MarketplaceComponentMaturityMap -Entry $Entry

    $items = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($field in (Get-MarketplaceComponentFieldMap).Keys) {
        if (-not $Entry.Contains($field) -or $null -eq $Entry[$field]) {
            continue
        }
        foreach ($packagePath in @($Entry[$field]) | Sort-Object -Unique) {
            $component = Resolve-MarketplaceComponentSource -PackagePath ([string]$packagePath) -Field $field
            $maturity = if ($componentMaturity.ContainsKey($component.PackagePath)) {
                Resolve-StrictSafeMaturity -Maturity $componentMaturity[$component.PackagePath] -Source "marketplace entry '$($Entry['name'])' component '$($component.PackagePath)'"
            }
            else {
                'stable'
            }
            if ($allowed -contains $maturity) {
                $items.Add(@{ Kind = $component.Kind; Field = $field; PackagePath = $component.PackagePath; SourcePath = $component.SourcePath; Maturity = $maturity })
            }
        }
    }
    return [hashtable[]]$items.ToArray()
}

function Test-MarketplaceEntryContract {
    <#
    .SYNOPSIS
    Validates marketplace membership and x-hve metadata.
    .PARAMETER Entry
    Marketplace entry.
    .OUTPUTS
    [string[]] Contract errors.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry
    )

    $errors = @()
    $declared = @{}
    foreach ($field in (Get-MarketplaceComponentFieldMap).Keys) {
        if (-not $Entry.Contains($field)) {
            continue
        }
        $value = $Entry[$field]
        if ($null -eq $value) {
            $errors += "component field '$field' must be a path string or an array of path strings"
            continue
        }
        if ($field -eq 'hooks' -and $value -isnot [string]) {
            $errors += "component field 'hooks' must be a single path string"
            continue
        }
        if ($value -isnot [string] -and $value -isnot [System.Collections.IEnumerable]) {
            $errors += "component field '$field' must be a path string or an array of path strings"
            continue
        }
        $values = @($value)
        if ($values.Count -eq 0) {
            $errors += "component field '$field' must declare at least one path"
            continue
        }
        $seen = @{}
        foreach ($item in $values) {
            if ($item -isnot [string]) {
                $errors += "component field '$field' must contain only path strings"
                continue
            }
            $resolved = Resolve-MarketplaceComponentPath -Path $item
            if ($resolved.Error) {
                $errors += "component field '$field': $($resolved.Error)"
                continue
            }
            if ($seen.ContainsKey($resolved.Path)) {
                $errors += "component field '$field' declares duplicate path '$($resolved.Path)'"
                continue
            }
            $seen[$resolved.Path] = $true
            $fieldPrefix = "$field/"
            if ($resolved.Path.StartsWith($fieldPrefix, [System.StringComparison]::Ordinal) -and
                (Test-HveCoreRepoSpecificPath -RelativePath $resolved.Path.Substring($fieldPrefix.Length))) {
                $errors += "component path '$($resolved.Path)' is a root-level repository artifact and must not be declared"
            }
            if ($declared.ContainsKey($resolved.Path)) {
                $errors += "component path '$($resolved.Path)' is declared in both '$($declared[$resolved.Path])' and '$field'"
            }
            else {
                $declared[$resolved.Path] = $field
            }
        }
    }

    # Experimental namespaces never inherit the stable default, so disclosure
    # stays truthful for any component added under an experimental root.
    $componentMaturity = Get-MarketplaceComponentMaturityMap -Entry $Entry
    foreach ($path in @($declared.Keys | Sort-Object)) {
        $segments = $path -split '/'
        if ($segments.Count -lt 2 -or $segments[1] -ne 'experimental') {
            continue
        }
        if (-not $componentMaturity.ContainsKey($path) -or $componentMaturity[$path] -eq 'stable') {
            $errors += "component path '$path' is under an experimental namespace and must declare a non-stable x-hve.componentMaturity"
        }
    }

    if ($Entry.Contains('author')) {
        $author = $Entry['author']
        if ($author -isnot [System.Collections.IDictionary] -or -not $author.Contains('name') -or [string]::IsNullOrWhiteSpace([string]$author['name'])) {
            $errors += 'author must be an object containing a non-empty name'
        }
        elseif ($author.Contains('url') -and ([string]$author['url'] -notmatch '^https://\S+$')) {
            $errors += 'author.url must be an absolute https URL when provided'
        }
    }

    if (-not $Entry.Contains('x-hve')) {
        return [string[]]$errors
    }
    $overlay = $Entry['x-hve']
    if ($overlay -isnot [System.Collections.IDictionary]) {
        return [string[]]($errors + 'x-hve must be an object')
    }
    foreach ($key in $overlay.Keys) {
        if ((Get-MarketplaceMetadataKey) -notcontains $key) {
            $errors += "x-hve contains unsupported key '$key'"
        }
    }
    if ($overlay.Contains('displayName') -and [string]::IsNullOrWhiteSpace([string]$overlay['displayName'])) {
        $errors += 'x-hve.displayName must be a non-empty string'
    }

    $vocabulary = Get-MaturityVocabulary
    if ($overlay.Contains('maturity') -and ($overlay['maturity'] -isnot [string] -or $vocabulary -notcontains $overlay['maturity'])) {
        $errors += "x-hve.maturity '$($overlay['maturity'])' must be one of: $($vocabulary -join ', ')"
    }
    if ($overlay.Contains('componentMaturity')) {
        if ($overlay['componentMaturity'] -isnot [System.Collections.IDictionary]) {
            $errors += 'x-hve.componentMaturity must be an object keyed by component path'
        }
        else {
            foreach ($key in $overlay['componentMaturity'].Keys) {
                $resolved = Resolve-MarketplaceComponentPath -Path ([string]$key)
                if ($resolved.Error) {
                    $errors += "x-hve.componentMaturity: $($resolved.Error)"
                }
                elseif ($resolved.Path -ne [string]$key) {
                    $errors += "x-hve.componentMaturity key '$key' must be a normalized component path"
                }
                $maturity = $overlay['componentMaturity'][$key]
                if ($maturity -isnot [string] -or $vocabulary -notcontains $maturity) {
                    $errors += "x-hve.componentMaturity['$key'] value '$maturity' must be one of: $($vocabulary -join ', ')"
                }
            }
        }
    }
    if ($overlay.Contains('documentation')) {
        $documentation = $overlay['documentation']
        if ($documentation -isnot [string]) {
            $errors += 'x-hve.documentation must be a repository-relative path string'
        }
        else {
            $resolved = Resolve-MarketplaceComponentPath -Path $documentation
            if ($resolved.Error) {
                $errors += "x-hve.documentation: $($resolved.Error)"
            }
            elseif ($resolved.Path -ne $documentation) {
                $errors += "x-hve.documentation '$documentation' must be a normalized repository-relative path"
            }
        }
    }
    if ($overlay.Contains('profiles')) {
        $profiles = $overlay['profiles']
        $installableFields = Get-MarketplaceInstallableField
        if ($profiles -isnot [System.Collections.IDictionary]) {
            $errors += 'x-hve.profiles must be an object keyed by profile name'
        }
        else {
            foreach ($profileName in $profiles.Keys) {
                if ([string]$profileName -notmatch '^[a-z0-9-]+$') {
                    $errors += "x-hve.profiles name '$profileName' must contain only lowercase letters, digits, and hyphens"
                }
                $members = $profiles[$profileName]
                if ($members -is [string] -or $members -isnot [System.Collections.IEnumerable]) {
                    $errors += "x-hve.profiles['$profileName'] must be an array of component paths"
                    continue
                }
                $memberValues = @($members)
                if ($memberValues.Count -eq 0) {
                    $errors += "x-hve.profiles['$profileName'] must declare at least one component path"
                    continue
                }
                $seenMembers = @{}
                foreach ($member in $memberValues) {
                    if ($member -isnot [string]) {
                        $errors += "x-hve.profiles['$profileName'] must contain only path strings"
                        continue
                    }
                    $resolvedMember = Resolve-MarketplaceComponentPath -Path $member
                    if ($resolvedMember.Error) {
                        $errors += "x-hve.profiles['$profileName']: $($resolvedMember.Error)"
                        continue
                    }
                    if ($seenMembers.ContainsKey($resolvedMember.Path)) {
                        $errors += "x-hve.profiles['$profileName'] declares duplicate path '$($resolvedMember.Path)'"
                        continue
                    }
                    $seenMembers[$resolvedMember.Path] = $true
                    if (-not $declared.ContainsKey($resolvedMember.Path)) {
                        $errors += "x-hve.profiles['$profileName'] references '$($resolvedMember.Path)', which is not declared component membership"
                    }
                    elseif ($installableFields -notcontains [string]$declared[$resolvedMember.Path]) {
                        $errors += "x-hve.profiles['$profileName'] references '$($resolvedMember.Path)' from non-installable field '$($declared[$resolvedMember.Path])'; profiles support only: $($installableFields -join ', ')"
                    }
                }
            }
        }
    }
    return [string[]]$errors
}

function ConvertTo-MarketplaceAgentKey {
    <#
    .SYNOPSIS
    Normalizes an agent handoff target.
    .PARAMETER Name
    Display name or file stem.
    .OUTPUTS
    [string] Comparable agent key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Name
    )

    return (($Name -replace '[^A-Za-z0-9]+', '-').Trim('-')).ToLowerInvariant()
}

function Get-MarketplaceAgentIndex {
    <#
    .SYNOPSIS
    Builds a handoff index from catalog-declared agents.
    .PARAMETER Catalog
    Parsed marketplace catalog.
    .PARAMETER RepoRoot
    Repository root.
    .OUTPUTS
    [hashtable] Lookup and ambiguous keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Catalog,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $lookup = @{}
    $ambiguous = @{}
    $seenSources = @{}
    $addKey = {
        param([string]$Key, [hashtable]$Descriptor)
        if ([string]::IsNullOrWhiteSpace($Key)) { return }
        if (-not $lookup.ContainsKey($Key)) {
            $lookup[$Key] = $Descriptor
        }
        elseif ($lookup[$Key].SourcePath -ne $Descriptor.SourcePath) {
            if (-not $ambiguous.ContainsKey($Key)) {
                $ambiguous[$Key] = @($lookup[$Key].SourcePath)
            }
            $ambiguous[$Key] = @($ambiguous[$Key] + $Descriptor.SourcePath | Sort-Object -Unique)
        }
    }

    foreach ($entry in @($Catalog['plugins'])) {
        foreach ($packagePath in @($entry['agents'])) {
            if ([string]::IsNullOrWhiteSpace([string]$packagePath)) { continue }
            $component = Resolve-MarketplaceComponentSource -PackagePath ([string]$packagePath) -Field 'agents'
            if ($seenSources.ContainsKey($component.SourcePath)) { continue }
            $absolute = Join-Path -Path $RepoRoot -ChildPath $component.SourcePath
            $handoffs = @()
            $displayName = ''
            if (Test-Path -LiteralPath $absolute -PathType Leaf) {
                $content = Get-Content -LiteralPath $absolute -Raw -Encoding utf8
                if ($content -match '(?s)^---\s*\r?\n(.*?)\r?\n---') {
                    try {
                        $frontmatter = ConvertFrom-Yaml -Yaml ($Matches[1] -replace '\r\n', "`n" -replace '\r', "`n")
                        if ($frontmatter -is [System.Collections.IDictionary]) {
                            if ($frontmatter.Contains('name')) { $displayName = [string]$frontmatter['name'] }
                            foreach ($handoff in @($frontmatter['handoffs'])) {
                                if ($handoff -is [string]) { $handoffs += $handoff }
                                elseif ($handoff -is [System.Collections.IDictionary] -and $handoff.Contains('agent')) { $handoffs += [string]$handoff['agent'] }
                            }
                        }
                    }
                    catch {
                        Write-Warning "Failed to parse frontmatter from $($component.SourcePath): $_"
                    }
                }
            }
            else {
                Write-Warning "Declared agent source not found: $($component.SourcePath)"
            }

            $stem = (Split-Path -Leaf $component.SourcePath) -replace '\.agent\.md$', ''
            $descriptor = @{ PackagePath = $component.PackagePath; SourcePath = $component.SourcePath; Handoffs = @($handoffs) }
            $seenSources[$component.SourcePath] = $descriptor
            & $addKey (ConvertTo-MarketplaceAgentKey -Name $stem) $descriptor
            if ($displayName) { & $addKey (ConvertTo-MarketplaceAgentKey -Name $displayName) $descriptor }
        }
    }
    return @{ Lookup = $lookup; Ambiguous = $ambiguous }
}

function Expand-MarketplaceAgentDependency {
    <#
    .SYNOPSIS
    Closes transitive agent handoff dependencies.
    .PARAMETER Index
    Agent index.
    .PARAMETER SeedPackagePaths
    Declared package agent paths.
    .PARAMETER PackageName
    Package name for errors.
    .OUTPUTS
    [string[]] Closed sorted agent paths.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Index,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [string[]]$SeedPackagePaths,

        [Parameter(Mandatory = $false)]
        [string]$PackageName = 'unknown'
    )

    $resolved = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $queue = [System.Collections.Generic.Queue[hashtable]]::new()
    foreach ($seed in $SeedPackagePaths) {
        $component = Resolve-MarketplaceComponentSource -PackagePath $seed -Field 'agents'
        $key = ConvertTo-MarketplaceAgentKey -Name ((Split-Path -Leaf $component.SourcePath) -replace '\.agent\.md$', '')
        $descriptor = $Index.Lookup[$key]
        if (-not $descriptor) { throw "Package '$PackageName' declares agent '$seed', which is absent from the catalog agent index." }
        if ($resolved.Add($descriptor.PackagePath)) { $queue.Enqueue($descriptor) }
    }
    while ($queue.Count -gt 0) {
        $current = $queue.Dequeue()
        foreach ($target in $current.Handoffs) {
            $key = ConvertTo-MarketplaceAgentKey -Name $target
            if ($Index.Ambiguous.ContainsKey($key)) {
                throw "Package '$PackageName': handoff target '$target' in '$($current.SourcePath)' is ambiguous across $($Index.Ambiguous[$key] -join ', ')."
            }
            $descriptor = $Index.Lookup[$key]
            if (-not $descriptor) {
                throw "Package '$PackageName': handoff target '$target' in '$($current.SourcePath)' does not resolve to a catalog-declared agent."
            }
            if ($resolved.Add($descriptor.PackagePath)) { $queue.Enqueue($descriptor) }
        }
    }
    return [string[]]@($resolved | Sort-Object)
}

function Get-MarketplaceResolvedPackageRecipe {
    <#
    .SYNOPSIS
    Returns the channel-filtered, handoff-closed package recipe.
    .PARAMETER Entry
    Marketplace entry.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .PARAMETER AgentIndex
    Catalog agent index.
    .OUTPUTS
    [hashtable[]] Resolved package recipe.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel,

        [Parameter(Mandatory = $true)]
        [hashtable]$AgentIndex
    )

    $items = @(Get-MarketplacePackageRecipe -Entry $Entry -Channel $Channel)
    $allowed = Get-MarketplaceActiveMaturity
    $componentMaturity = Get-MarketplaceComponentMaturityMap -Entry $Entry
    $seedAgents = @($items | Where-Object { $_.Kind -eq 'agent' } | ForEach-Object { $_.PackagePath })
    foreach ($agentPath in Expand-MarketplaceAgentDependency -Index $AgentIndex -SeedPackagePaths $seedAgents -PackageName ([string]$Entry['name'])) {
        if ($seedAgents -contains $agentPath) { continue }
        $component = Resolve-MarketplaceComponentSource -PackagePath $agentPath -Field 'agents'
        # Closure additions keep their canonical label instead of being stamped stable.
        $maturity = if ($componentMaturity.ContainsKey($component.PackagePath)) {
            Resolve-StrictSafeMaturity -Maturity $componentMaturity[$component.PackagePath] -Source "marketplace entry '$($Entry['name'])' component '$($component.PackagePath)'"
        }
        else {
            'stable'
        }
        if ($allowed -notcontains $maturity) { continue }
        $items += @{ Kind = $component.Kind; Field = 'agents'; PackagePath = $component.PackagePath; SourcePath = $component.SourcePath; Maturity = $maturity }
    }
    return [hashtable[]]@($items | Sort-Object { $_.Field }, { $_.PackagePath })
}

function Get-MarketplaceComponentIndex {
    <#
    .SYNOPSIS
    Indexes clone-installable entry components by package path.
    .DESCRIPTION
    Covers agents, commands, rules, and skills. Hooks are excluded because the
    clone installer never copies them.
    .PARAMETER Entry
    Marketplace entry.
    .OUTPUTS
    [hashtable] Package path to PackagePath, Kind, Field, SourcePath, and Maturity.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry
    )

    $componentMaturity = Get-MarketplaceComponentMaturityMap -Entry $Entry
    $installableFields = Get-MarketplaceInstallableField
    $index = @{}
    foreach ($field in $installableFields) {
        foreach ($packagePath in @($Entry[$field])) {
            if ([string]::IsNullOrWhiteSpace([string]$packagePath)) { continue }
            $component = Resolve-MarketplaceComponentSource -PackagePath ([string]$packagePath) -Field $field
            $maturity = if ($componentMaturity.ContainsKey($component.PackagePath)) {
                Resolve-StrictSafeMaturity -Maturity $componentMaturity[$component.PackagePath] -Source "marketplace entry '$($Entry['name'])' component '$($component.PackagePath)'"
            }
            else {
                'stable'
            }
            $index[$component.PackagePath] = @{
                PackagePath = $component.PackagePath
                Kind        = $component.Kind
                Field       = $field
                SourcePath  = $component.SourcePath
                Maturity    = $maturity
            }
        }
    }
    return $index
}

function Get-MarketplaceInstallableField {
    <#
    .SYNOPSIS
    Returns the marketplace fields the clone installer can copy.
    .OUTPUTS
    [string[]] Installable component fields.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param()

    return , @('agents', 'commands', 'rules', 'skills')
}

function Get-MarketplaceLiteralReference {
    <#
    .SYNOPSIS
    Extracts #file: directive targets from artifact text.
    .DESCRIPTION
    A payload ends at whitespace, a backtick, a quote, or a closing bracket, so
    prose that mentions the bare `#file:` token yields no reference.
    .PARAMETER Body
    Artifact text to scan.
    .OUTPUTS
    [string[]] Distinct reference paths in first-seen order.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Body
    )

    $references = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($match in [regex]::Matches($Body, '#file:([^\s`''")\]>,]+)')) {
        $reference = $match.Groups[1].Value.TrimEnd('.', ';', ':')
        if ($reference -and $seen.Add($reference)) {
            [void]$references.Add($reference)
        }
    }
    return [string[]]$references.ToArray()
}

function Resolve-MarketplaceReferenceComponent {
    <#
    .SYNOPSIS
    Maps one #file: reference to the component that owns its target.
    .DESCRIPTION
    Only component-shaped references are closed: a payload that ends with a
    canonical artifact suffix or names a skills path. Every other payload, such
    as a documentation placeholder, is not a component and is ignored. A
    component-shaped reference resolves against the citing file's directory
    first, then the repository root, and its target must belong to recipe
    membership.
    .PARAMETER Reference
    Reference payload without the #file: prefix.
    .PARAMETER SourcePath
    Repository-relative path of the citing component source.
    .PARAMETER RepoRoot
    Resolved absolute repository root.
    .PARAMETER SourceLookup
    Canonical source path to package path map.
    .PARAMETER Origin
    Citing component package path used in error text.
    .OUTPUTS
    [string] Owning package path, or an empty string when the target is not a component.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Reference,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [hashtable]$SourceLookup,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Origin
    )

    $normalized = $Reference -replace '\\', '/'
    if ($normalized -notmatch '(\.agent\.md|\.prompt\.md|\.instructions\.md)$' -and $normalized -notmatch '(^|/)skills/') {
        return ''
    }

    $citingDirectory = Split-Path -Parent (Join-Path -Path $RepoRoot -ChildPath $SourcePath)
    $target = ''
    foreach ($candidate in @((Join-Path -Path $citingDirectory -ChildPath $Reference), (Join-Path -Path $RepoRoot -ChildPath $Reference))) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) {
            $target = (Resolve-Path -LiteralPath $candidate).Path
            break
        }
    }
    if (-not $target) {
        throw "Component '$Origin' references '#file:$Reference', which does not resolve to a file under '$RepoRoot'."
    }

    $relative = ($target.Substring($RepoRoot.Length).TrimStart([char]'/', [char]'\')) -replace '\\', '/'
    if ($SourceLookup.ContainsKey($relative)) {
        return $SourceLookup[$relative]
    }

    # A skill is a directory component, so a file inside it resolves to its root.
    if ($relative.StartsWith('.github/skills/', [System.StringComparison]::Ordinal)) {
        $parent = $relative
        while ($parent.Contains('/')) {
            $parent = $parent.Substring(0, $parent.LastIndexOf('/'))
            if ($SourceLookup.ContainsKey($parent)) {
                return $SourceLookup[$parent]
            }
        }
    }

    $sourceRoots = Get-MarketplaceComponentSourceRoot
    $installableFields = Get-MarketplaceInstallableField
    foreach ($field in $installableFields) {
        $root = "$($sourceRoots[$field].SourceRoot)/"
        if ($relative.StartsWith($root, [System.StringComparison]::Ordinal)) {
            throw "Component '$Origin' references '$relative', which is not declared marketplace membership."
        }
    }
    return ''
}

function Resolve-MarketplaceComponentSelection {
    <#
    .SYNOPSIS
    Resolves a starter profile or custom component selection with its dependency closure.
    .DESCRIPTION
    Validates that every seed is recipe membership, closes visible agent
    handoff and literal #file: dependencies, and returns canonical maturity for
    each selected and dependency-added component so callers can display it
    before any write.
    .PARAMETER Entry
    Marketplace entry.
    .PARAMETER RepoRoot
    Repository root holding the canonical sources.
    .PARAMETER AgentIndex
    Catalog agent index from Get-MarketplaceAgentIndex.
    .PARAMETER ProfileName
    Declared x-hve profile name to select.
    .PARAMETER Component
    Explicit component package paths to select.
    .OUTPUTS
    [hashtable[]] Sorted descriptors with PackagePath, Kind, Field, SourcePath, Maturity, and Origin.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Custom')]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Entry,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [hashtable]$AgentIndex,

        [Parameter(Mandatory = $true, ParameterSetName = 'Profile')]
        [ValidateNotNullOrEmpty()]
        [string]$ProfileName,

        [Parameter(Mandatory = $true, ParameterSetName = 'Custom')]
        [ValidateNotNullOrEmpty()]
        [string[]]$Component
    )

    $entryName = [string]$Entry['name']
    $index = Get-MarketplaceComponentIndex -Entry $Entry
    $sourceLookup = @{}
    foreach ($descriptor in $index.Values) {
        $sourceLookup[$descriptor.SourcePath] = $descriptor.PackagePath
    }

    if ($PSCmdlet.ParameterSetName -eq 'Profile') {
        $profiles = Get-MarketplaceEntryOverlayValue -Entry $Entry -Key 'profiles'
        if ($profiles -isnot [System.Collections.IDictionary] -or -not $profiles.Contains($ProfileName)) {
            throw "Marketplace entry '$entryName' declares no '$ProfileName' selection profile."
        }
        $seeds = @($profiles[$ProfileName])
    }
    else {
        $seeds = @($Component)
    }

    $origin = [ordered]@{}
    foreach ($seed in $seeds) {
        $resolved = Resolve-MarketplaceComponentPath -Path ([string]$seed)
        if ($resolved.Error) {
            throw "Component selection: $($resolved.Error)"
        }
        if (-not $index.ContainsKey($resolved.Path)) {
            throw "Component '$($resolved.Path)' is not declared membership of marketplace entry '$entryName'."
        }
        if (-not $origin.Contains($resolved.Path)) {
            $origin[$resolved.Path] = 'selected'
        }
    }

    $agentSeeds = @($origin.Keys | Where-Object { $index[$_].Kind -eq 'agent' })
    if ($agentSeeds.Count -gt 0) {
        foreach ($agentPath in Expand-MarketplaceAgentDependency -Index $AgentIndex -SeedPackagePaths $agentSeeds -PackageName $entryName) {
            if ($origin.Contains($agentPath)) { continue }
            if (-not $index.ContainsKey($agentPath)) {
                throw "Handoff dependency '$agentPath' is not declared membership of marketplace entry '$entryName'."
            }
            $origin[$agentPath] = 'dependency'
        }
    }

    $repoRootFull = (Resolve-Path -LiteralPath $RepoRoot).Path
    $queue = [System.Collections.Generic.Queue[string]]::new()
    foreach ($packagePath in @($origin.Keys)) { $queue.Enqueue($packagePath) }
    while ($queue.Count -gt 0) {
        $packagePath = $queue.Dequeue()
        $descriptor = $index[$packagePath]
        # Skills are copied as complete directories, so their internal references stay intact.
        if ($descriptor.Kind -eq 'skill') { continue }

        $absolute = Join-Path -Path $repoRootFull -ChildPath $descriptor.SourcePath
        if (-not (Test-Path -LiteralPath $absolute -PathType Leaf)) {
            throw "Component '$packagePath' source '$($descriptor.SourcePath)' is missing from '$RepoRoot'."
        }
        $body = Get-Content -LiteralPath $absolute -Raw -Encoding utf8
        foreach ($reference in Get-MarketplaceLiteralReference -Body $body) {
            $dependency = Resolve-MarketplaceReferenceComponent -Reference $reference -SourcePath $descriptor.SourcePath `
                -RepoRoot $repoRootFull -SourceLookup $sourceLookup -Origin $packagePath
            if (-not $dependency -or $origin.Contains($dependency)) { continue }
            $origin[$dependency] = 'dependency'
            $queue.Enqueue($dependency)
        }
    }

    $selection = [System.Collections.Generic.List[hashtable]]::new()
    foreach ($packagePath in (@($origin.Keys) | Sort-Object)) {
        $descriptor = $index[$packagePath]
        $selection.Add(@{
                PackagePath = $descriptor.PackagePath
                Kind        = $descriptor.Kind
                Field       = $descriptor.Field
                SourcePath  = $descriptor.SourcePath
                Maturity    = $descriptor.Maturity
                Origin      = $origin[$packagePath]
            })
    }
    return [hashtable[]]$selection.ToArray()
}

function Get-MarketplaceSourceIndex {
    <#
    .SYNOPSIS
    Builds a source-to-package index from resolved marketplace recipes.
    .PARAMETER Catalog
    Parsed marketplace catalog.
    .PARAMETER RepoRoot
    Repository root.
    .PARAMETER Channel
    Stable or PreRelease channel.
    .OUTPUTS
    [hashtable] Source paths to package descriptors.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Catalog,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateSet('Stable', 'PreRelease')]
        [string]$Channel
    )

    $index = @{}
    $agentIndex = Get-MarketplaceAgentIndex -Catalog $Catalog -RepoRoot $RepoRoot
    foreach ($entry in @($Catalog['plugins']) | Sort-Object { $_['name'] }) {
        if (-not (Test-MarketplaceEntryEligible -Entry $entry -Channel $Channel)) { continue }
        foreach ($item in Get-MarketplaceResolvedPackageRecipe -Entry $entry -Channel $Channel -AgentIndex $agentIndex) {
            if (-not $index.ContainsKey($item.SourcePath)) {
                $index[$item.SourcePath] = @()
            }
            $index[$item.SourcePath] += @{
                PackageName = [string]$entry['name']
                PackagePath = $item.PackagePath
                Kind        = $item.Kind
                Maturity    = $item.Maturity
            }
        }
    }
    return $index
}

function Get-MarketplaceSourcePolicyIndex {
    <#
    .SYNOPSIS
    Builds a source-to-package policy index including maturity tombstones.
    .PARAMETER Catalog
    Parsed marketplace catalog.
    .OUTPUTS
    [hashtable] Source paths to package, component, and maturity records.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.IDictionary]$Catalog
    )

    $index = @{}
    foreach ($entry in @($Catalog['plugins']) | Sort-Object { $_['name'] }) {
        $componentMaturity = Get-MarketplaceEntryOverlayValue -Entry $entry -Key 'componentMaturity'
        if ($componentMaturity -isnot [System.Collections.IDictionary]) {
            $componentMaturity = @{}
        }

        $packagePaths = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($field in (Get-MarketplaceComponentFieldMap).Keys) {
            foreach ($packagePath in @($entry[$field])) {
                if (-not [string]::IsNullOrWhiteSpace([string]$packagePath)) {
                    [void]$packagePaths.Add([string]$packagePath)
                }
            }
        }
        foreach ($packagePath in $componentMaturity.Keys) {
            [void]$packagePaths.Add([string]$packagePath)
        }

        foreach ($packagePath in $packagePaths) {
            $field = ([string]$packagePath -split '/', 2)[0]
            if ((Get-MarketplaceComponentFieldMap).Keys -notcontains $field) {
                continue
            }
            $component = Resolve-MarketplaceComponentSource -PackagePath $packagePath -Field $field
            $maturity = if ($componentMaturity.Contains($component.PackagePath)) {
                Resolve-StrictSafeMaturity -Maturity ([string]$componentMaturity[$component.PackagePath]) -Source "marketplace entry '$($entry['name'])' component '$($component.PackagePath)'"
            }
            else {
                'stable'
            }
            if (-not $index.ContainsKey($component.SourcePath)) {
                $index[$component.SourcePath] = @()
            }
            $index[$component.SourcePath] += @{
                PackageName = [string]$entry['name']
                PackagePath = $component.PackagePath
                Kind        = $component.Kind
                Maturity    = $maturity
            }
        }
    }
    return $index
}

function Get-MarketplaceSourceMaturity {
    <#
    .SYNOPSIS
    Returns the most restrictive maturity for one canonical source path.
    .PARAMETER Index
    Source policy index from Get-MarketplaceSourcePolicyIndex.
    .PARAMETER SourcePath
    Canonical repository source path.
    .OUTPUTS
    [string] Most restrictive maturity, or null when the source is undeclared.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Index,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$SourcePath
    )

    if (-not $Index.ContainsKey($SourcePath)) {
        return $null
    }
    $rank = Get-MaturityRank
    return @($Index[$SourcePath] | Sort-Object { $rank[$_.Maturity] } -Descending | Select-Object -First 1)[0].Maturity
}

Export-ModuleMember -Function @(
    'ConvertTo-MarketplaceAgentKey',
    'Expand-MarketplaceAgentDependency',
    'Get-MarketplaceActiveMaturity',
    'Get-MarketplaceAgentIndex',
    'Get-MarketplaceCatalog',
    'Get-MarketplaceComponentField',
    'Get-MarketplaceComponentFieldMap',
    'Get-MarketplaceComponentIndex',
    'Get-MarketplaceComponentMaturityMap',
    'Get-MarketplaceComponentSourceRoot',
    'Get-MarketplaceEntryMaturity',
    'Get-MarketplaceEntryOverlayValue',
    'Get-MarketplaceInstallableField',
    'Get-MarketplaceLiteralReference',
    'Get-MarketplaceMetadataKey',
    'Get-MarketplacePackagePath',
    'Get-MarketplacePackageRecipe',
    'Get-MarketplaceResolvedPackageRecipe',
    'Get-MarketplaceSourceIndex',
    'Get-MarketplaceSourceMaturity',
    'Get-MarketplaceSourcePolicyIndex',
    'Get-PluginItemName',
    'Get-PluginItemSubpath',
    'Get-PluginSubdirectory',
    'Resolve-MarketplaceComponentPath',
    'Resolve-MarketplaceComponentSelection',
    'Resolve-MarketplaceComponentSource',
    'Test-MarketplaceEntryContract',
    'Test-MarketplaceEntryEligible'
)
