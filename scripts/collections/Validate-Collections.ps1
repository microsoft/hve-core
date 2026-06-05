#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates collection manifests for Copilot CLI plugin generation.

.DESCRIPTION
    Reads all .collection.yml files from collections/ and validates structure,
    required fields, artifact path existence, and kind-suffix consistency.

.EXAMPLE
    ./Validate-Collections.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$OutputPath = (Join-Path $PSScriptRoot '../../logs/collection-validation-results.json')
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules/CollectionHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot 'Modules/CoreManifestHelpers.psm1') -Force
Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

#region Validation Helpers

function Test-KindSuffix {
    <#
    .SYNOPSIS
        Validates that an item path matches its declared kind suffix.

    .DESCRIPTION
        Checks kind-suffix consistency: agent files end with .agent.md,
        prompt files with .prompt.md, instruction files with .instructions.md,
        and skill items are directories containing a SKILL.md file.

    .PARAMETER Kind
        The declared artifact kind (agent, prompt, instruction, skill).

    .PARAMETER ItemPath
        The relative path from the collection manifest.

    .PARAMETER RepoRoot
        Absolute path to the repository root for skill directory checks.

    .OUTPUTS
        [string] Error message if validation fails, empty string if valid.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$ItemPath,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    switch ($Kind) {
        'agent' {
            if ($ItemPath -notmatch '\.agent\.md$') {
                return "kind 'agent' expects *.agent.md but got '$ItemPath'"
            }
        }
        'prompt' {
            if ($ItemPath -notmatch '\.prompt\.md$') {
                return "kind 'prompt' expects *.prompt.md but got '$ItemPath'"
            }
        }
        'instruction' {
            if ($ItemPath -notmatch '\.instructions\.md$') {
                return "kind 'instruction' expects *.instructions.md but got '$ItemPath'"
            }
        }
        'skill' {
            $skillDir = Join-Path -Path $RepoRoot -ChildPath $ItemPath
            $skillFile = Join-Path -Path $skillDir -ChildPath 'SKILL.md'
            if (-not (Test-Path -Path $skillFile)) {
                return "kind 'skill' expects SKILL.md inside '$ItemPath'"
            }
        }
    }

    return ''
}

function Get-CollectionItemKey {
    <#
    .SYNOPSIS
        Builds a stable uniqueness key for collection items.

    .DESCRIPTION
        Uses kind and path to identify the same artifact across collections.

    .PARAMETER Kind
        Artifact kind.

    .PARAMETER ItemPath
        Artifact path.

    .OUTPUTS
        [string] Composite key.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Kind,

        [Parameter(Mandatory = $true)]
        [string]$ItemPath
    )

    return "$Kind|$ItemPath"
}

function Get-StrippedAgentName {
    <#
    .SYNOPSIS
        Returns an agent name with any maturity picker suffix removed.

    .DESCRIPTION
        Strips a recognized maturity suffix produced by Get-AgentMaturityNameSuffix
        (currently '(exp)' or '(pre)') from the end of an agent name and trims
        trailing whitespace. Returns $null when no recognized suffix is present.

    .PARAMETER AgentName
        The agent name to inspect.

    .OUTPUTS
        [string] The name without its maturity suffix, or $null when no
        suffix applies.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string]$AgentName
    )

    if ([string]::IsNullOrEmpty($AgentName)) {
        return $null
    }

    foreach ($maturity in @('experimental', 'preview')) {
        $suffix = Get-AgentMaturityNameSuffix -Maturity $maturity
        if ([string]::IsNullOrEmpty($suffix)) {
            continue
        }
        if ($AgentName.EndsWith($suffix, [System.StringComparison]::Ordinal)) {
            $stripped = $AgentName.Substring(0, $AgentName.Length - $suffix.Length).TrimEnd()
            if (-not [string]::IsNullOrEmpty($stripped)) {
                return $stripped
            }
        }
    }

    return $null
}

function Find-AgentReferenceLineNumber {
    <#
    .SYNOPSIS
        Locates the line number where an agent reference value appears.

    .DESCRIPTION
        Scans the raw lines of an agent file and returns the 1-based line
        number where the supplied reference value appears in either the
        agents: list ('- value' form) or a handoffs entry ('agent: value' form).
        Returns 0 when no match is found.

    .PARAMETER Lines
        Raw file lines.

    .PARAMETER Value
        The reference string to locate.

    .PARAMETER Section
        Either 'agents' or 'handoffs' to pick the matching syntax.

    .OUTPUTS
        [int] 1-based line number, or 0 when not found.
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
        [AllowEmptyString()]
        [string[]]$Lines,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Value,

        [Parameter(Mandatory = $true)]
        [ValidateSet('agents', 'handoffs')]
        [string]$Section
    )

    $escaped = [regex]::Escape($Value)
    $pattern = if ($Section -eq 'agents') {
        "^\s*-\s*[`"']?$escaped[`"']?\s*$"
    } else {
        "^\s*agent\s*:\s*[`"']?$escaped[`"']?\s*$"
    }

    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if ($Lines[$i] -match $pattern) {
            return $i + 1
        }
    }
    return 0
}

function Test-DictionaryKey {
    <#
    .SYNOPSIS
        Checks whether a dictionary-like object contains a key.

    .DESCRIPTION
        YAML parsing can return OrderedDictionary instances, which implement
        IDictionary but do not expose ContainsKey().
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter()]
        [AllowNull()]
        [object]$InputObject,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Name
    )

    if ($InputObject -is [System.Collections.IDictionary]) {
        return $InputObject.Contains($Name)
    }

    return $false
}

function Test-AgentHandoffNameReferences {
    <#
    .SYNOPSIS
        Validates that agents: and handoffs.agent: references resolve to a
        registered agent name.

    .DESCRIPTION
        Scans .github/agents/**/*.agent.md to build an inventory of every
        agent name: value, then iterates each file's agents: list and
        handoffs.agent: values and emits an AgentHandoffNameMismatch
        diagnostic for any reference that does not match a known name.
        When a candidate exists whose stripped maturity suffix matches the
        reference, the diagnostic includes a "Did you mean" suggestion.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .OUTPUTS
        [hashtable[]] Diagnostics with Collection, Severity, ErrorType, and
        Message keys. Returns an empty array when all references resolve.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $diagnostics = @()
    $agentsDir = Join-Path -Path $RepoRoot -ChildPath '.github/agents'
    if (-not (Test-Path -Path $agentsDir)) {
        return ,$diagnostics
    }

    $agentFiles = Get-ChildItem -Path $agentsDir -Filter '*.agent.md' -File -Recurse
    if ($agentFiles.Count -eq 0) {
        return ,$diagnostics
    }

    $inventory = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    $fileData = [ordered]@{}

    foreach ($file in $agentFiles) {
        $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $file.FullName) -replace '\\', '/'
        if (Test-DeprecatedPath -Path $relativePath) {
            continue
        }

        $content = Get-Content -Path $file.FullName -Raw
        if ([string]::IsNullOrEmpty($content)) {
            continue
        }
        if ($content -notmatch '(?s)^---\s*\r?\n(.*?)\r?\n---') {
            continue
        }

        $yamlContent = $Matches[1] -replace '\r\n', "`n" -replace '\r', "`n"
        $data = $null
        try {
            $data = ConvertFrom-Yaml -Yaml $yamlContent
        } catch {
            continue
        }
        if (-not $data) {
            continue
        }

        if (Test-DictionaryKey -InputObject $data -Name 'name') {
            $rawName = $data.name
            if ($null -ne $rawName -and -not [string]::IsNullOrWhiteSpace([string]$rawName)) {
                [void]$inventory.Add([string]$rawName)
            }
        }

        $agentRefs = @()
        if ((Test-DictionaryKey -InputObject $data -Name 'agents') -and $data.agents) {
            foreach ($v in $data.agents) {
                if ($v -is [string] -and -not [string]::IsNullOrWhiteSpace($v)) {
                    $agentRefs += [string]$v
                }
            }
        }

        $handoffRefs = @()
        if ((Test-DictionaryKey -InputObject $data -Name 'handoffs') -and $data.handoffs) {
            foreach ($h in $data.handoffs) {
                if ((Test-DictionaryKey -InputObject $h -Name 'agent')) {
                    $val = [string]$h.agent
                    if (-not [string]::IsNullOrWhiteSpace($val)) {
                        $handoffRefs += $val
                    }
                }
            }
        }

        if ($agentRefs.Count -gt 0 -or $handoffRefs.Count -gt 0) {
            $fileData[$relativePath] = @{
                Lines       = ($content -split "`r?`n")
                AgentRefs   = $agentRefs
                HandoffRefs = $handoffRefs
            }
        }
    }

    foreach ($relativePath in ($fileData.Keys | Sort-Object)) {
        $entry = $fileData[$relativePath]
        $allRefs = @()
        foreach ($r in $entry.AgentRefs) { $allRefs += @{ Value = $r; Section = 'agents' } }
        foreach ($r in $entry.HandoffRefs) { $allRefs += @{ Value = $r; Section = 'handoffs' } }

        foreach ($ref in $allRefs) {
            $value = $ref.Value
            if ($inventory.Contains($value)) {
                continue
            }

            $suggestion = $null
            foreach ($candidate in $inventory) {
                $stripped = Get-StrippedAgentName -AgentName $candidate
                if ($null -ne $stripped -and $stripped -eq $value) {
                    $suggestion = $candidate
                    break
                }
            }

            $lineNumber = Find-AgentReferenceLineNumber -Lines $entry.Lines -Value $value -Section $ref.Section
            $location = if ($lineNumber -gt 0) { "${relativePath}:${lineNumber}" } else { $relativePath }

            $message = "Reference '$value' in $location does not match any registered agent name."
            if ($suggestion) {
                $message += " Did you mean '$suggestion'?"
            }

            $diagnostics += @{
                Collection = 'agent-references'
                Severity   = 'Error'
                ErrorType  = 'AgentHandoffNameMismatch'
                Message    = $message
            }
        }
    }

    return ,$diagnostics
}

#endregion Validation Helpers

#region Orchestration

function Invoke-CollectionValidation {
    <#
    .SYNOPSIS
        Validates all collection manifests for correctness.

    .DESCRIPTION
        Scans the collections/ directory for .collection.yml files and validates
        each manifest for required fields (id, name, description, items), id
        format, artifact path existence, kind-suffix consistency, and duplicate
        ids across collections.

    .PARAMETER RepoRoot
        Absolute path to the repository root directory.

    .OUTPUTS
        Hashtable with Success bool, ErrorCount int, CollectionCount int, and Results array.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $validationResults = [System.Collections.Generic.List[hashtable]]::new()

    function Add-ValidationResult {
        param(
            [Parameter(Mandatory = $true)]
            [string]$Collection,

            [Parameter(Mandatory = $true)]
            [string]$ErrorType,

            [Parameter(Mandatory = $true)]
            [string]$Message,

            [Parameter()]
            [ValidateSet('Error', 'Warning')]
            [string]$Severity = 'Error'
        )

        $validationResults.Add(@{
            Collection = $Collection
            Severity   = $Severity
            ErrorType  = $ErrorType
            Message    = $Message
        })
    }

    $collectionsDir = Join-Path -Path $RepoRoot -ChildPath 'collections'
    $coreManifestPath = Join-Path -Path $collectionsDir -ChildPath 'core-manifest.yml'
    if (-not (Test-Path -Path $coreManifestPath -PathType Leaf)) {
        throw "core manifest not found at '$coreManifestPath'"
    }
    $coreManifest = Read-CoreManifest -ManifestPath $coreManifestPath

    # Paths of artifacts the manifest tombstones (maturity removed/deprecated). These are
    # intentionally excluded from every projected collection, so they must be exempt from
    # the on-disk orphan check even though they no longer appear in any rendered manifest.
    $tombstonedManifestPaths = @{}
    foreach ($kindSection in @('agents', 'prompts', 'instructions', 'skills')) {
        $section = Get-CoreManifestProperty -InputObject $coreManifest -Name $kindSection
        foreach ($itemPath in (Get-CoreManifestKeys -InputObject $section)) {
            $itemNode = Get-CoreManifestProperty -InputObject $section -Name $itemPath
            $itemMaturity = [string](Get-CoreManifestProperty -InputObject $itemNode -Name 'maturity')
            if ($null -eq (Get-CoreManifestMaturityRank -Maturity $itemMaturity)) {
                $normalizedItemPath = ConvertTo-CoreManifestRelativePath -Path ([string]$itemPath)
                $tombstonedManifestPaths[$normalizedItemPath] = $true
            }
        }
    }

    $collectionFiles = @(ConvertTo-CollectionManifestFromCore -CoreManifest $coreManifest -All -RepoRoot $RepoRoot | Sort-Object { $_.id } | ForEach-Object {
        [pscustomobject]@{
            Name     = "$($_.id).collection.yml"
            FullName = Join-Path -Path $collectionsDir -ChildPath "$($_.id).collection.yml"
            Manifest = $_
        }
    })

    if ($collectionFiles.Count -eq 0) {
        Write-Host ' WARN No collection manifests found in collections/' -ForegroundColor Yellow
        Add-ValidationResult -Collection 'collections' -ErrorType 'NoCollectionManifests' -Message 'No collection manifests found in collections/' -Severity 'Warning'
        return @{ Success = $true; ErrorCount = 0; CollectionCount = 0; Results = @($validationResults) }
    }

    Write-Host 'Validating collections...'

    $errorCount = 0
    $seenIds = @{}
    $validatedCount = 0
    $allowedMaturities = @('stable', 'preview', 'experimental', 'deprecated', 'removed')
    $canonicalCollectionId = 'hve-core-all'
    $itemOccurrences = @{}

    $knownCollectionIds = @{}
    foreach ($cf in $collectionFiles) {
        $cfId = $cf.Name -replace '\.collection\.yml$', ''
        $knownCollectionIds[$cfId] = $true
    }

    # Sub-domain folders that group artifacts shared across multiple themed collections
    # but are intentionally not collections themselves.
    $sharedSubdomainFolders = @{
        'shared'       = $true
        'rai-planning' = $true
        'jira'         = $true
        'gitlab'       = $true
        'installer'    = $true
    }

    foreach ($file in $collectionFiles) {
        $baseName = $file.Name -replace '\.collection\.yml$', ''
        $collectionLabel = $baseName

        $mdContent = New-CollectionReadmeBodyFromCore -CoreManifest $coreManifest -CollectionId $baseName -RepoRoot $RepoRoot
        $hasBegin = $mdContent.Contains($CollectionMdBeginMarker)
        $hasEnd = $mdContent.Contains($CollectionMdEndMarker)

        if ($hasBegin -xor $hasEnd) {
            Write-Host "  WARN $($file.Name): projected README body has mismatched auto-generation markers" -ForegroundColor Yellow
            Add-ValidationResult -Collection $collectionLabel -ErrorType 'MismatchedAutoGenerationMarkers' -Message 'projected README body has mismatched auto-generation markers' -Severity 'Warning'
        }

        if ($hasBegin -and $hasEnd) {
            $beginIdx = $mdContent.IndexOf($CollectionMdBeginMarker)
            $endIdx = $mdContent.IndexOf($CollectionMdEndMarker)
            if ($endIdx -le $beginIdx) {
                Write-Host "  WARN $($file.Name): projected README body has markers in wrong order" -ForegroundColor Yellow
                Add-ValidationResult -Collection $collectionLabel -ErrorType 'CollectionMarkersWrongOrder' -Message 'projected README body has markers in wrong order' -Severity 'Warning'
            }
        }

        $manifest = if ($file.PSObject.Properties.Name -contains 'Manifest') { $file.Manifest } else { Get-CollectionManifest -CollectionPath $file.FullName }
        $fileErrors = @()
        $seenItemKeys = @{}

        # Required fields
        $requiredFields = @('id', 'name', 'descriptions', 'items')
        foreach ($field in $requiredFields) {
            if (-not (Test-DictionaryKey -InputObject $manifest -Name $field) -or $null -eq $manifest[$field]) {
                $fileErrors += @{ ErrorType = 'MissingRequiredField'; Message = "missing required field '$field'" }
            }
        }

        # 'descriptions' must be a non-empty array of { channel, text } entries
        if ((Test-DictionaryKey -InputObject $manifest -Name 'descriptions') -and $null -ne $manifest['descriptions']) {
            $descriptions = $manifest['descriptions']
            if ($descriptions -isnot [System.Collections.IEnumerable] -or $descriptions -is [string]) {
                $fileErrors += @{ ErrorType = 'InvalidDescriptions'; Message = "'descriptions' must be an array of { channel, text } entries" }
            }
            elseif (@($descriptions).Count -eq 0) {
                $fileErrors += @{ ErrorType = 'InvalidDescriptions'; Message = "'descriptions' must contain at least one entry" }
            }
            else {
                foreach ($entry in $descriptions) {
                    if ($entry -isnot [System.Collections.IDictionary] -or
                        [string]::IsNullOrWhiteSpace([string]$entry['channel']) -or
                        [string]::IsNullOrWhiteSpace([string]$entry['text'])) {
                        $fileErrors += @{ ErrorType = 'InvalidDescriptions'; Message = "each 'descriptions' entry must define non-empty 'channel' and 'text'" }
                        break
                    }
                }
            }
        }

        # Skip further checks if required fields are absent
        if ($fileErrors.Count -gt 0) {
            foreach ($err in $fileErrors) {
                Write-Host "    x $($file.Name): $($err.Message)" -ForegroundColor Red
                Add-ValidationResult -Collection $collectionLabel -ErrorType $err.ErrorType -Message $err.Message
            }
            $errorCount += $fileErrors.Count
            continue
        }

        $id = $manifest.id
        $collectionLabel = $id

        # Id format
        if ($id -notmatch '^[a-z0-9-]+$') {
            $fileErrors += @{ ErrorType = 'InvalidIdFormat'; Message = "id '$id' must match ^[a-z0-9-]+$" }
        }

        # Duplicate id check
        if ($seenIds.ContainsKey($id)) {
            $fileErrors += @{ ErrorType = 'DuplicateCollectionId'; Message = "duplicate id '$id' (also in $($seenIds[$id]))" }
        }
        else {
            $seenIds[$id] = $file.Name
        }

        # Prerelease description presence (warning)
        $hasPrereleaseDescription = $false
        if ((Test-DictionaryKey -InputObject $manifest -Name 'descriptions') -and $manifest.descriptions -is [System.Collections.IEnumerable] -and
            $manifest.descriptions -isnot [string]) {
            foreach ($entry in $manifest.descriptions) {
                if ($entry -is [System.Collections.IDictionary] -and [string]$entry['channel'] -eq 'prerelease' -and
                    -not [string]::IsNullOrWhiteSpace([string]$entry['text'])) {
                    $hasPrereleaseDescription = $true
                    break
                }
            }
        }
        if (-not $hasPrereleaseDescription) {
            Write-Host "  WARN $($file.Name): missing populated 'descriptions.prerelease'" -ForegroundColor Yellow
            Add-ValidationResult -Collection $collectionLabel -ErrorType 'MissingPrereleaseDescription' -Message "missing populated 'descriptions.prerelease'" -Severity 'Warning'
        }

        # Validate collection-level maturity if present
        $collMaturity = $null
        if ((Test-DictionaryKey -InputObject $manifest -Name 'maturity') -and -not [string]::IsNullOrWhiteSpace([string]$manifest.maturity)) {
            $collMaturity = [string]$manifest.maturity
            if ($allowedMaturities -notcontains $collMaturity) {
                $fileErrors += @{ ErrorType = 'InvalidCollectionMaturity'; Message = "invalid collection maturity '$collMaturity' (allowed: $($allowedMaturities -join ', '))" }
            }
        }

        # Validate each item
        $itemCount = $manifest.items.Count
        foreach ($item in $manifest.items) {
            $itemPath = $item.path
            $kind = $item.kind
            $absolutePath = Join-Path -Path $RepoRoot -ChildPath $itemPath
            $itemMaturity = $null
            if (Test-DictionaryKey -InputObject $item -Name 'maturity') {
                $itemMaturity = [string]$item.maturity
            }
            if ([string]::IsNullOrWhiteSpace($itemMaturity)) {
                $fileErrors += @{ ErrorType = 'MissingExplicitMaturity'; Message = "item missing required 'maturity' field: $itemPath" }
            }
            $rawEffectiveMaturity = if (-not [string]::IsNullOrWhiteSpace($itemMaturity)) {
                $itemMaturity
            } elseif (-not [string]::IsNullOrWhiteSpace($collMaturity)) {
                $collMaturity
            } else {
                $null
            }
            $effectiveMaturity = Resolve-CollectionItemMaturity -Maturity $rawEffectiveMaturity

            # Repo-specific path exclusion
            if (Test-HveCoreRepoRelativePath -Path $itemPath) {
                $fileErrors += @{ ErrorType = 'RepoSpecificPath'; Message = "repo-specific path not allowed in collections: $itemPath (root-level artifacts under .github/{type}/ are excluded from distribution)" }
            }

            # Path existence
            if (-not (Test-Path -Path $absolutePath)) {
                $fileErrors += @{ ErrorType = 'PathNotFound'; Message = "path not found: $itemPath" }
            }

            # Kind-suffix consistency
            if ($kind) {
                $suffixError = Test-KindSuffix -Kind $kind -ItemPath $itemPath -RepoRoot $RepoRoot
                if ($suffixError) {
                    $fileErrors += @{ ErrorType = 'MissingSuffix'; Message = $suffixError }
                }
            }
            else {
                $fileErrors += @{ ErrorType = 'MissingItemKind'; Message = "item missing 'kind': $itemPath" }
            }

            if (-not [string]::IsNullOrWhiteSpace($itemMaturity) -and ($allowedMaturities -notcontains $itemMaturity)) {
                $fileErrors += @{ ErrorType = 'InvalidMaturity'; Message = "invalid maturity '$itemMaturity' for item '$itemPath' (allowed: $($allowedMaturities -join ', '))" }
            }

            if ($kind -eq 'agent' -and $itemPath -like '*.agent.md' -and (Test-Path -Path $absolutePath)) {
                $expectedSuffix = Get-AgentMaturityNameSuffix -Maturity $effectiveMaturity
                $frontmatter = Get-ArtifactFrontmatter -FilePath $absolutePath
                $agentName = $frontmatter.name
                $mismatchMessage = $null

                if ([string]::IsNullOrEmpty($agentName)) {
                    if (-not [string]::IsNullOrEmpty($expectedSuffix)) {
                        $mismatchMessage = "agent '$itemPath' source name is missing; must end with '$expectedSuffix' for effective maturity '$effectiveMaturity'"
                    }
                }
                else {
                    $hasExpStale = $agentName.EndsWith('(exp)', [System.StringComparison]::Ordinal)
                    $hasPreStale = $agentName.EndsWith('(pre)', [System.StringComparison]::Ordinal)
                    $hasFullExp = $agentName -match '\(Experimental\)\s*$'
                    $hasFullPre = $agentName -match '\(Preview\)\s*$'
                    $hasDoubleSuffix = ($agentName -match '\((exp|pre)\)\((exp|pre)\)\s*$')

                    if ($hasDoubleSuffix) {
                        $mismatchMessage = "agent '$itemPath' source name has stacked maturity suffixes; expected single '$expectedSuffix' for effective maturity '$effectiveMaturity'"
                    }
                    elseif ($hasFullExp -or $hasFullPre) {
                        $obsolete = if ($hasFullExp) { '(Experimental)' } else { '(Preview)' }
                        $expectedDisplay = if ([string]::IsNullOrEmpty($expectedSuffix)) { 'no suffix' } else { "'$expectedSuffix'" }
                        $mismatchMessage = "agent '$itemPath' source name uses obsolete suffix '$obsolete'; expected $expectedDisplay for effective maturity '$effectiveMaturity'"
                    }
                    elseif (-not [string]::IsNullOrEmpty($expectedSuffix)) {
                        if (-not $agentName.EndsWith($expectedSuffix, [System.StringComparison]::Ordinal)) {
                            $mismatchMessage = "agent '$itemPath' source name must end with '$expectedSuffix' for effective maturity '$effectiveMaturity'"
                        }
                    }
                    elseif ($hasExpStale -or $hasPreStale) {
                        $stale = if ($hasExpStale) { '(exp)' } else { '(pre)' }
                        $mismatchMessage = "agent '$itemPath' source name has stale suffix '$stale'; expected no suffix for effective maturity '$effectiveMaturity'"
                    }
                }

                if ($mismatchMessage) {
                    $fileErrors += @{ ErrorType = 'AgentMaturityLabelMismatch'; Message = $mismatchMessage }
                }
            }

            # Check 2: intra-collection duplicate detection
            if (-not [string]::IsNullOrWhiteSpace($itemPath) -and -not [string]::IsNullOrWhiteSpace($kind)) {
                $dupKey = Get-CollectionItemKey -Kind $kind -ItemPath $itemPath
                if ($seenItemKeys.ContainsKey($dupKey)) {
                    $fileErrors += @{ ErrorType = 'IntraCollectionDuplicate'; Message = "duplicate item '$dupKey' appears more than once in collection '$id'" }
                } else {
                    $seenItemKeys[$dupKey] = $true
                }
            }

            # Check 3: collection-id to folder name consistency
            if ($id -ne 'hve-core-all') {
                $pathSegments = $itemPath -split '[/\\]'
                # Expected pattern: .github/{type}/{collection-id}/{file-or-deeper}
                if ($pathSegments.Count -ge 4 -and $pathSegments[0] -eq '.github') {
                    $folderName = $pathSegments[2]
                    if (-not $sharedSubdomainFolders.ContainsKey($folderName) -and -not $knownCollectionIds.ContainsKey($folderName)) {
                        Write-Host " WARN collection '$id': item folder '$folderName' does not match any known collection ID: $itemPath" -ForegroundColor Yellow
                        Add-ValidationResult -Collection $collectionLabel -ErrorType 'UnknownCollectionFolderReference' -Message "item folder '$folderName' does not match any known collection ID: $itemPath" -Severity 'Warning'
                    }
                }
            }

            if (-not [string]::IsNullOrWhiteSpace($itemPath) -and -not [string]::IsNullOrWhiteSpace($kind)) {
                $itemKey = Get-CollectionItemKey -Kind $kind -ItemPath $itemPath
                if (-not $itemOccurrences.ContainsKey($itemKey)) {
                    $itemOccurrences[$itemKey] = @()
                }

                $itemOccurrences[$itemKey] += @{
                    CollectionId = $id
                    CollectionFile = $file.Name
                    Kind = $kind
                    Path = $itemPath
                    Maturity = $effectiveMaturity
                }
            }

            # Informational log for instruction items
            if ($kind -eq 'instruction') {
                Write-Verbose "  instruction: $itemPath"
            }
        }

        if ($fileErrors.Count -gt 0) {
            Write-Host "  FAIL $id ($itemCount items) - $($fileErrors.Count) error(s)" -ForegroundColor Red
            foreach ($err in $fileErrors) {
                Write-Host "      $($err.Message)" -ForegroundColor Red
                Add-ValidationResult -Collection $collectionLabel -ErrorType $err.ErrorType -Message $err.Message
            }
            $errorCount += $fileErrors.Count
        }
        else {
            Write-Host "  OK $id ($itemCount items)"
        }

        $validatedCount++
    }

    $canonicalManifestFound = ($collectionFiles | Where-Object {
        ($_.Name -replace '\.collection\.yml$', '') -eq $canonicalCollectionId
    }).Count -gt 0
    if (-not $canonicalManifestFound) {
        Write-Host " WARN '$canonicalCollectionId.collection.yml' not found; skipping orphan and cross-collection coverage checks" -ForegroundColor Yellow
        Add-ValidationResult -Collection $canonicalCollectionId -ErrorType 'CanonicalCollectionMissing' -Message "'$canonicalCollectionId.collection.yml' not found; skipping orphan and cross-collection coverage checks" -Severity 'Warning'
    }

    # Duplicate artifact key detection across all collections
    $artifactKeyMap = @{}
    foreach ($itemKey in $itemOccurrences.Keys) {
        $occurrences = $itemOccurrences[$itemKey]
        $first = $occurrences[0]
        $artifactKey = Get-CollectionArtifactKey -Kind $first.Kind -Path $first.Path
        $compositeKey = "$($first.Kind)|$artifactKey"

        if (-not $artifactKeyMap.ContainsKey($compositeKey)) {
            $artifactKeyMap[$compositeKey] = @()
        }
        if ($artifactKeyMap[$compositeKey] -notcontains $first.Path) {
            $artifactKeyMap[$compositeKey] += $first.Path
        }
    }

    foreach ($compositeKey in $artifactKeyMap.Keys) {
        $paths = $artifactKeyMap[$compositeKey]
        if ($paths.Count -gt 1) {
            $kindLabel = ($compositeKey -split '\|')[0]
            $nameLabel = ($compositeKey -split '\|')[1]
            $pathList = ($paths | Sort-Object) -join ', '
            Write-Host "  FAIL duplicate $kindLabel artifact key '$nameLabel' found at distinct paths: $pathList" -ForegroundColor Red
            Add-ValidationResult -Collection 'all-collections' -ErrorType 'DuplicateArtifactKey' -Message "duplicate $kindLabel artifact key '$nameLabel' found at distinct paths: $pathList"
            $errorCount++
        }
    }

    foreach ($itemKey in $itemOccurrences.Keys) {
        $occurrences = $itemOccurrences[$itemKey]
        $canonicalMatches = @($occurrences | Where-Object { $_.CollectionId -eq $canonicalCollectionId })
        $themedMatches    = @($occurrences | Where-Object { $_.CollectionId -ne $canonicalCollectionId })

        # Check 4: item in one or more themed collections but absent from hve-core-all
        # Skip when all themed occurrences are marked maturity:'removed' (intentional tombstone
        # excluded from hve-core-all by Update-HveCoreAllCollection).
        $activeThemedMatches = @($themedMatches | Where-Object { $_.Maturity -ne 'removed' })
        if ($canonicalManifestFound -and $activeThemedMatches.Count -gt 0 -and $canonicalMatches.Count -eq 0) {
            $themedCollections = ($activeThemedMatches | ForEach-Object { $_.CollectionId } | Sort-Object -Unique) -join ', '
            Write-Host "  FAIL item '$itemKey' exists in themed collection(s) [$themedCollections] but is absent from '$canonicalCollectionId'" -ForegroundColor Red
            Add-ValidationResult -Collection $canonicalCollectionId -ErrorType 'ThemedItemMissingFromCanonical' -Message "item '$itemKey' exists in themed collection(s) [$themedCollections] but is absent from '$canonicalCollectionId'"
            $errorCount++
            continue
        }

        # Maturity conflict: only when item appears in canonical AND at least one themed
        if ($canonicalMatches.Count -gt 0 -and $themedMatches.Count -gt 0) {
            $canonical = $canonicalMatches[0]
            $maturityRank = @{ 'stable' = 0; 'preview' = 1; 'experimental' = 2; 'deprecated' = 3; 'removed' = 4 }
            foreach ($occurrence in $themedMatches) {
                if ($occurrence.Maturity -ne $canonical.Maturity) {
                    $expected = if ($maturityRank[$canonical.Maturity] -ge $maturityRank[$occurrence.Maturity]) { $canonical.Maturity } else { $occurrence.Maturity }
                    $msg = "maturity conflict for '$itemKey' in '$($occurrence.CollectionFile)': canonical '$canonicalCollectionId'='$($canonical.Maturity)', '$($occurrence.CollectionId)'='$($occurrence.Maturity)', expected='$expected'"
                    Write-Host "  FAIL $msg" -ForegroundColor Red
                    Add-ValidationResult -Collection $occurrence.CollectionId -ErrorType 'MaturityConflict' -Message $msg
                    $errorCount++
                }
            }
        }
    }

    if ($canonicalManifestFound) {
        # Check 1: Orphan artifact detection
        $onDiskArtifacts = Get-ArtifactFiles -RepoRoot $RepoRoot
        foreach ($artifact in $onDiskArtifacts) {
            $diskKey = Get-CollectionItemKey -Kind $artifact.kind -ItemPath $artifact.path
            $occurrences = if ($itemOccurrences.ContainsKey($diskKey)) { $itemOccurrences[$diskKey] } else { @() }

            $inCanonical = @($occurrences | Where-Object { $_.CollectionId -eq $canonicalCollectionId }).Count -gt 0
            $inThemed    = @($occurrences | Where-Object { $_.CollectionId -ne $canonicalCollectionId }).Count -gt 0

            if (-not $inCanonical) {
                # Skip orphan failure when all themed occurrences are tombstoned (maturity:'removed'),
                # or when the manifest itself tombstones the artifact (removed/deprecated), in which
                # case it is intentionally projected into no collection at all.
                $themedActive  = @($occurrences | Where-Object { $_.CollectionId -ne $canonicalCollectionId -and $_.Maturity -ne 'removed' }).Count -gt 0
                $themedRemoved = @($occurrences | Where-Object { $_.CollectionId -ne $canonicalCollectionId -and $_.Maturity -eq 'removed' }).Count -gt 0
                $manifestTombstoned = $tombstonedManifestPaths.ContainsKey($artifact.path)
                if ($manifestTombstoned -or ($themedRemoved -and -not $themedActive)) {
                    Write-Verbose "Skipping orphan check for tombstoned item '$diskKey'"
                } else {
                    Write-Host "  FAIL orphan: '$diskKey' is on disk but absent from '$canonicalCollectionId'" -ForegroundColor Red
                    Add-ValidationResult -Collection $canonicalCollectionId -ErrorType 'OrphanArtifact' -Message "'$diskKey' is on disk but absent from '$canonicalCollectionId'"
                    $errorCount++
                }
            } elseif (-not $inThemed) {
                Write-Host " WARN '$diskKey' exists in '$canonicalCollectionId' but is not in any themed collection" -ForegroundColor Yellow
                Add-ValidationResult -Collection $canonicalCollectionId -ErrorType 'CanonicalOnlyArtifact' -Message "'$diskKey' exists in '$canonicalCollectionId' but is not in any themed collection" -Severity 'Warning'
            }
        }
    }

    $handoffDiagnostics = Test-AgentHandoffNameReferences -RepoRoot $RepoRoot
    foreach ($diag in $handoffDiagnostics) {
        Write-Host "  FAIL $($diag.Message)" -ForegroundColor Red
        Add-ValidationResult -Collection $diag.Collection -ErrorType $diag.ErrorType -Message $diag.Message -Severity $diag.Severity
        $errorCount++
    }

    Write-Host ''
    Write-Host "$validatedCount collections validated, $errorCount errors"

    return @{
        Success         = ($errorCount -eq 0)
        ErrorCount      = $errorCount
        CollectionCount = $validatedCount
        Results         = @($validationResults)
    }
}

function Export-CollectionValidationReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ValidationResult,

        [Parameter(Mandatory = $true)]
        [string]$OutputPath
    )

    $logsDir = Split-Path -Path $OutputPath -Parent
    if (-not [string]::IsNullOrWhiteSpace($logsDir) -and -not (Test-Path -Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $report = @{
        Timestamp        = (Get-Date).ToUniversalTime().ToString('o')
        TotalCollections = $ValidationResult.CollectionCount
        ErrorCount       = $ValidationResult.ErrorCount
        Results          = @($ValidationResult.Results)
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding utf8
}

#endregion Orchestration

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        # Verify PowerShell-Yaml module
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }
        Import-Module PowerShell-Yaml -ErrorAction Stop

        # Resolve paths
        $ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $RepoRoot = (Get-Item "$ScriptDir/../..").FullName

        $result = Invoke-CollectionValidation -RepoRoot $RepoRoot
        Export-CollectionValidationReport -ValidationResult $result -OutputPath $OutputPath

        if (-not $result.Success) {
            throw "Validation failed with $($result.ErrorCount) error(s)."
        }

        exit 0
    }
    catch {
        Write-Error "Collection validation failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion
