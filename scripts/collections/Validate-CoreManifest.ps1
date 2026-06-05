#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Validates the central HVE Core artifact metadata manifest.

.DESCRIPTION
    Reads collections/core-manifest.yml and validates its required sections,
    artifact metadata, release artifact references, and referenced release
    metadata files.

.EXAMPLE
    ./Validate-CoreManifest.ps1
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$RepoRoot = (Get-Item (Join-Path $PSScriptRoot '../..')).FullName,

    [Parameter()]
    [string]$ManifestPath = (Join-Path $RepoRoot 'collections/core-manifest.yml'),

    [Parameter()]
    [string]$OutputPath = (Join-Path $RepoRoot 'logs/core-manifest-validation-results.json')
)

$ErrorActionPreference = 'Stop'

$validMaturityValues = @('stable', 'preview', 'experimental', 'deprecated', 'removed')
$coreManifestHelpersPath = Join-Path -Path $PSScriptRoot -ChildPath 'Modules/CoreManifestHelpers.psm1'
Import-Module -Name $coreManifestHelpersPath -Force

function Invoke-CoreManifestValidation {
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ManifestPath
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $artifactEntries = @{}

    function Add-Error {
        param([Parameter(Mandatory = $true)][string]$Message)
        $errors.Add($Message)
    }

    function Add-Warning {
        param([Parameter(Mandatory = $true)][string]$Message)
        $warnings.Add($Message)
    }

    try {
        $manifest = Read-CoreManifest -ManifestPath $ManifestPath
    }
    catch {
        Add-Error $_.Exception.Message
        return @{
            Success      = $false
            ErrorCount   = $errors.Count
            WarningCount = $warnings.Count
            Errors       = @($errors)
            Warnings     = @($warnings)
        }
    }

    $requiredSections = @('schemaVersion', 'collections', 'agents', 'prompts', 'instructions', 'skills', 'releases')

    foreach ($sectionName in $requiredSections) {
        if ($null -eq (Get-CoreManifestProperty -InputObject $manifest -Name $sectionName)) {
            Add-Error "Required top-level section '$sectionName' is missing."
        }
    }

    if ($errors.Count -gt 0) {
        return @{
            Success      = $false
            ErrorCount   = $errors.Count
            WarningCount = $warnings.Count
            Errors       = @($errors)
            Warnings     = @($warnings)
        }
    }

    $collectionsSection = Get-CoreManifestProperty -InputObject $manifest -Name 'collections'
    $collectionIds = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($collectionId in (Get-CoreManifestKeys -InputObject $collectionsSection)) {
        [void]$collectionIds.Add($collectionId)
    }

    if ($collectionIds.Count -eq 0) {
        Add-Error "Top-level section 'collections' must not be empty."
    }

    $discoveredArtifacts = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($discoveredArtifact in (Get-CoreManifestArtifactFiles -RepoRoot $RepoRoot)) {
        [void]$discoveredArtifacts.Add($discoveredArtifact)
    }

    foreach ($sectionName in (Get-CoreManifestArtifactSectionNames)) {
        $section = Get-CoreManifestProperty -InputObject $manifest -Name $sectionName
        $artifactPaths = Get-CoreManifestKeys -InputObject $section

        if ($artifactPaths.Count -eq 0) {
            Add-Error "Top-level section '$sectionName' must not be empty."
            continue
        }

        foreach ($artifactKey in $artifactPaths) {
            $entry = Get-CoreManifestProperty -InputObject $section -Name $artifactKey
            $entryPath = Get-CoreManifestProperty -InputObject $entry -Name 'path'
            $entryMaturity = Get-CoreManifestProperty -InputObject $entry -Name 'maturity'
            $entryCollections = @(Get-CoreManifestProperty -InputObject $entry -Name 'collections')

            if ([string]::IsNullOrWhiteSpace($entryPath)) {
                Add-Error "$sectionName entry '$artifactKey' must define a non-empty path."
                continue
            }

            $normalizedEntryPath = ConvertTo-CoreManifestRelativePath -Path $entryPath
            if ($entryPath -ne $normalizedEntryPath) {
                Add-Error "$sectionName entry '$artifactKey' path '$entryPath' must use repo-relative slash form '$normalizedEntryPath'."
            }

            if ($artifactKey -ne $entryPath) {
                Add-Error "$sectionName entry key '$artifactKey' must match path '$entryPath'."
            }

            if (-not (Test-CoreManifestRelativePath -ArtifactPath $entryPath)) {
                Add-Error "$sectionName entry '$artifactKey' path '$entryPath' must be repo-relative and must not traverse outside the repo."
            }

            $referenceMetadataResult = Test-CoreManifestReferenceMetadata -Section $sectionName -ArtifactKey $artifactKey -Entry $entry
            foreach ($referenceError in @($referenceMetadataResult.Errors)) {
                Add-Error $referenceError
            }

            foreach ($referenceWarning in @($referenceMetadataResult.Warnings)) {
                Add-Warning $referenceWarning
            }

            if ($entryMaturity -notin $validMaturityValues) {
                Add-Error "$sectionName entry '$artifactKey' has invalid maturity '$entryMaturity'. Valid values: $($validMaturityValues -join ', ')."
            }

            $nonEmptyCollections = @($entryCollections | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
            if ($nonEmptyCollections.Count -eq 0) {
                Add-Error "$sectionName entry '$artifactKey' must reference at least one collection."
            }

            foreach ($collectionId in $nonEmptyCollections) {
                if (-not $collectionIds.Contains([string]$collectionId)) {
                    Add-Error "$sectionName entry '$artifactKey' references unknown collection '$collectionId'."
                }
            }

            $allowMissing = $entryMaturity -eq 'removed'
            $kindError = Test-CoreManifestKindPath -Section $sectionName -ArtifactPath $entryPath -RepoRoot $RepoRoot -AllowMissing $allowMissing
            if (-not [string]::IsNullOrWhiteSpace($kindError)) {
                Add-Error $kindError
            }

            $absoluteArtifactPath = Join-Path -Path $RepoRoot -ChildPath $entryPath
            if (-not $allowMissing -and -not (Test-Path -Path $absoluteArtifactPath)) {
                Add-Error "$sectionName entry '$artifactKey' path '$entryPath' does not exist."
            }

            if (-not $allowMissing -and $discoveredArtifacts.Count -gt 0 -and -not $discoveredArtifacts.Contains($normalizedEntryPath)) {
                Add-Warning "$sectionName entry '$artifactKey' path '$entryPath' was not found by artifact discovery."
            }

            $sourceFile = if ($sectionName -eq 'skills') {
                Join-Path -Path $absoluteArtifactPath -ChildPath 'SKILL.md'
            }
            else {
                $absoluteArtifactPath
            }

            $artifactEntries[$normalizedEntryPath] = @{
                Section     = $sectionName
                Maturity    = $entryMaturity
                Collections = @($nonEmptyCollections)
                SourceFile  = $sourceFile
            }
        }
    }

    $maturityMap = Get-CoreManifestMaturityMap -Manifest $manifest
    $agentNameIndex = Get-CoreManifestAgentNameIndex -RepoRoot $RepoRoot
    $maturityViolations = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($sourcePath in $artifactEntries.Keys) {
        $sourceMetadata = $artifactEntries[$sourcePath]
        $sourceRank = Get-CoreManifestMaturityRank -Maturity $sourceMetadata.Maturity
        if ($null -eq $sourceRank) {
            continue
        }

        $edges = [System.Collections.Generic.List[hashtable]]::new()
        $sourceFrontmatter = Get-CoreManifestAssetFrontmatter -SourcePath $sourceMetadata.SourceFile

        $requiredAgents = Get-CoreManifestProperty -InputObject $sourceFrontmatter -Name 'agents'
        foreach ($agentReference in @($requiredAgents)) {
            if ([string]::IsNullOrWhiteSpace([string]$agentReference)) {
                continue
            }

            $target = Resolve-CoreManifestReferenceTarget -Reference ([string]$agentReference) -ReferenceKind 'agent' -AgentNameIndex $agentNameIndex -MaturityMap $maturityMap
            if (-not [string]::IsNullOrWhiteSpace($target)) {
                $edges.Add(@{ Target = $target; EdgeType = 'requires' })
            }
        }

        $handoffs = Get-CoreManifestProperty -InputObject $sourceFrontmatter -Name 'handoffs'
        foreach ($handoff in @($handoffs)) {
            if ($null -eq $handoff) {
                continue
            }

            $handoffAgent = Get-CoreManifestProperty -InputObject $handoff -Name 'agent'
            if (-not [string]::IsNullOrWhiteSpace([string]$handoffAgent)) {
                $target = Resolve-CoreManifestReferenceTarget -Reference ([string]$handoffAgent) -ReferenceKind 'agent' -AgentNameIndex $agentNameIndex -MaturityMap $maturityMap
                if (-not [string]::IsNullOrWhiteSpace($target)) {
                    $edges.Add(@{ Target = $target; EdgeType = 'handoff-agent' })
                }
            }

            $handoffPrompt = Get-CoreManifestProperty -InputObject $handoff -Name 'prompt'
            if (-not [string]::IsNullOrWhiteSpace([string]$handoffPrompt) -and ([string]$handoffPrompt).Trim().StartsWith('/')) {
                $target = Resolve-CoreManifestReferenceTarget -Reference ([string]$handoffPrompt) -ReferenceKind 'prompt' -AgentNameIndex $agentNameIndex -MaturityMap $maturityMap
                if (-not [string]::IsNullOrWhiteSpace($target)) {
                    $edges.Add(@{ Target = $target; EdgeType = 'handoff-prompt' })
                }
            }
        }

        foreach ($embeddedTarget in @(Get-CoreManifestEmbeddedReferences -SourcePath $sourceMetadata.SourceFile -MaturityMap $maturityMap)) {
            if (-not [string]::IsNullOrWhiteSpace($embeddedTarget)) {
                $edges.Add(@{ Target = $embeddedTarget; EdgeType = 'embedded' })
            }
        }

        foreach ($edge in $edges) {
            $targetPath = [string]$edge.Target
            if ($targetPath -eq $sourcePath) {
                continue
            }

            if (-not $maturityMap.ContainsKey($targetPath)) {
                continue
            }

            $targetMaturity = [string]$maturityMap[$targetPath]
            $targetRank = Get-CoreManifestMaturityRank -Maturity $targetMaturity
            if ($null -eq $targetRank) {
                continue
            }

            if ($sourceRank -gt $targetRank) {
                $maturityViolations.Add(@{
                        SourcePath     = $sourcePath
                        SourceMaturity = $sourceMetadata.Maturity
                        TargetPath     = $targetPath
                        TargetMaturity = $targetMaturity
                        EdgeType       = $edge.EdgeType
                    })
            }
        }
    }

    $sortedViolations = @($maturityViolations | Sort-Object -Property @{ Expression = { $_.SourcePath } }, @{ Expression = { $_.EdgeType } }, @{ Expression = { $_.TargetPath } })
    $seenViolations = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($violation in $sortedViolations) {
        $violationKey = @($violation.SourcePath, $violation.EdgeType, $violation.TargetPath) -join [char]0x1F
        if (-not $seenViolations.Add($violationKey)) {
            continue
        }

        Add-Error "$($violation.SourcePath) ($($violation.SourceMaturity)) depends on $($violation.TargetPath) ($($violation.TargetMaturity)) via $($violation.EdgeType); higher-maturity assets must not depend on lower-maturity assets."
    }

    $releasesSection = Get-CoreManifestProperty -InputObject $manifest -Name 'releases'
    $releaseIds = Get-CoreManifestKeys -InputObject $releasesSection

    if ($releaseIds.Count -eq 0) {
        Add-Error "Top-level section 'releases' must not be empty."
    }

    foreach ($releaseId in $releaseIds) {
        $release = Get-CoreManifestProperty -InputObject $releasesSection -Name $releaseId
        $includeMaturity = @(Get-CoreManifestProperty -InputObject $release -Name 'includeMaturity')
        $releaseArtifacts = @(Get-CoreManifestProperty -InputObject $release -Name 'artifacts')
        $excludePaths = @(Get-CoreManifestProperty -InputObject $release -Name 'excludePaths')
        $allowDeprecated = [bool](Get-CoreManifestProperty -InputObject $release -Name 'allowDeprecated')
        $allowRemoved = [bool](Get-CoreManifestProperty -InputObject $release -Name 'allowRemoved')

        if ($includeMaturity.Count -eq 0) {
            Add-Error "Release '$releaseId' must define includeMaturity."
        }

        foreach ($maturityValue in $includeMaturity) {
            if ($maturityValue -notin $validMaturityValues) {
                Add-Error "Release '$releaseId' has invalid includeMaturity value '$maturityValue'. Valid values: $($validMaturityValues -join ', ')."
            }
        }

        $excludedSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        foreach ($excludePath in $excludePaths) {
            if (-not [string]::IsNullOrWhiteSpace([string]$excludePath)) {
                [void]$excludedSet.Add([string]$excludePath)
            }
        }

        foreach ($artifactPath in $releaseArtifacts) {
            $artifactPath = [string]$artifactPath
            $normalizedArtifactPath = ConvertTo-CoreManifestRelativePath -Path $artifactPath
            if ($artifactPath -ne $normalizedArtifactPath) {
                Add-Error "Release '$releaseId' artifact path '$artifactPath' must use repo-relative slash form '$normalizedArtifactPath'."
            }

            if ($excludedSet.Contains($normalizedArtifactPath)) {
                Add-Error "Release '$releaseId' lists excluded artifact '$artifactPath' in artifacts."
            }

            if (-not $artifactEntries.ContainsKey($normalizedArtifactPath)) {
                Add-Error "Release '$releaseId' references artifact '$artifactPath' that is not present in manifest artifact sections."
                continue
            }

            $artifactMetadata = $artifactEntries[$normalizedArtifactPath]
            $artifactMaturity = $artifactMetadata.Maturity
            if ($artifactMaturity -notin $includeMaturity) {
                Add-Error "Release '$releaseId' references artifact '$artifactPath' with maturity '$artifactMaturity', which is not included by includeMaturity."
            }

            if ($artifactMaturity -eq 'deprecated' -and -not $allowDeprecated) {
                Add-Error "Release '$releaseId' references deprecated artifact '$artifactPath' without allowDeprecated: true."
            }

            if ($artifactMaturity -eq 'removed' -and -not $allowRemoved) {
                Add-Error "Release '$releaseId' references removed artifact '$artifactPath' without allowRemoved: true."
            }
        }

        $whatNew = Get-CoreManifestProperty -InputObject $release -Name 'whatNew'
        if ($null -ne $whatNew) {
            foreach ($metadataProperty in @('source', 'changelogPath')) {
                $metadataPath = Get-CoreManifestProperty -InputObject $whatNew -Name $metadataProperty
                if ([string]::IsNullOrWhiteSpace($metadataPath)) {
                    continue
                }

                if (-not (Test-CoreManifestRelativePath -ArtifactPath $metadataPath)) {
                    Add-Error "Release '$releaseId' whatNew.$metadataProperty path '$metadataPath' must be repo-relative."
                    continue
                }

                $absoluteMetadataPath = Join-Path -Path $RepoRoot -ChildPath $metadataPath
                if (-not (Test-Path -Path $absoluteMetadataPath -PathType Leaf)) {
                    Add-Error "Release '$releaseId' whatNew.$metadataProperty file '$metadataPath' does not exist."
                }
            }
        }
    }

    return @{
        Success      = ($errors.Count -eq 0)
        ErrorCount   = $errors.Count
        WarningCount = $warnings.Count
        Errors       = @($errors)
        Warnings     = @($warnings)
    }
}

function Export-CoreManifestValidationReport {
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
        Timestamp    = (Get-Date).ToUniversalTime().ToString('o')
        Success      = $ValidationResult.Success
        ErrorCount   = $ValidationResult.ErrorCount
        WarningCount = $ValidationResult.WarningCount
        Errors       = @($ValidationResult.Errors)
        Warnings     = @($ValidationResult.Warnings)
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content -Path $OutputPath -Encoding utf8
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }

        Import-Module PowerShell-Yaml -ErrorAction Stop

        $result = Invoke-CoreManifestValidation -RepoRoot $RepoRoot -ManifestPath $ManifestPath
        Export-CoreManifestValidationReport -ValidationResult $result -OutputPath $OutputPath

        if (-not $result.Success) {
            throw "Validation failed with $($result.ErrorCount) error(s)."
        }

        exit 0
    }
    catch {
        Write-Error "Core manifest validation failed: $($_.Exception.Message)"
        exit 1
    }
}