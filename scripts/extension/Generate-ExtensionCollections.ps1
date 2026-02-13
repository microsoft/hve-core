#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT
#Requires -Version 7.0

<#
.SYNOPSIS
    Generates persona package templates from root collections.

.DESCRIPTION
    Reads root collection manifests from collections/*.collection.yml and generates:
    - extension/package.{collection-id}.json (plus canonical extension/package.json for hve-core-all)

    Generated output is deterministic for identical input files.

.PARAMETER ValidateDeterminism
    Runs generation twice in temporary directories and fails when outputs differ.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [switch]$ValidateDeterminism
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot '../lib/Modules/CIHelpers.psm1') -Force

function Get-CollectionDisplayName {
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$CollectionManifest,

        [Parameter(Mandatory = $true)]
        [string]$DefaultValue
    )

    if ($CollectionManifest.ContainsKey('displayName') -and -not [string]::IsNullOrWhiteSpace([string]$CollectionManifest.displayName)) {
        return [string]$CollectionManifest.displayName
    }

    if ($CollectionManifest.ContainsKey('name') -and -not [string]::IsNullOrWhiteSpace([string]$CollectionManifest.name)) {
        return "HVE Core - $($CollectionManifest.name)"
    }

    return $DefaultValue
}

function Copy-TemplateWithOverrides {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Template,

        [Parameter(Mandatory = $true)]
        [hashtable]$Overrides
    )

    $output = [ordered]@{}

    foreach ($propertyName in $Template.PSObject.Properties.Name) {
        if ($Overrides.ContainsKey($propertyName)) {
            $output[$propertyName] = $Overrides[$propertyName]
        }
        else {
            $output[$propertyName] = $Template.$propertyName
        }
    }

    foreach ($propertyName in $Overrides.Keys | Sort-Object) {
        if (-not $output.Contains($propertyName)) {
            $output[$propertyName] = $Overrides[$propertyName]
        }
    }

    return [pscustomobject]$output
}

function Set-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,

        [Parameter(Mandatory = $true)]
        [object]$Content
    )

    $parent = Split-Path -Path $Path -Parent
    if (-not (Test-Path -Path $parent)) {
        New-Item -Path $parent -ItemType Directory -Force | Out-Null
    }

    $json = $Content | ConvertTo-Json -Depth 30
    Set-Content -Path $Path -Value $json -Encoding utf8NoBOM
}

function Remove-StaleGeneratedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [string[]]$ExpectedFiles
    )

    $expected = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($file in $ExpectedFiles) {
        $null = $expected.Add([System.IO.Path]::GetFullPath($file))
    }

    $extensionDir = Join-Path $RepoRoot 'extension'
    Get-ChildItem -Path $extensionDir -Filter 'package.*.json' -File | ForEach-Object {
        $fullPath = [System.IO.Path]::GetFullPath($_.FullName)
        if (-not $expected.Contains($fullPath)) {
            Remove-Item -Path $_.FullName -Force
        }
    }
}

function Get-GenerationHashes {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$OutputRoot
    )

    $patterns = @(
        (Join-Path $OutputRoot 'extension/package.json'),
        (Join-Path $OutputRoot 'extension/package.*.json')
    )

    $files = @()
    foreach ($pattern in $patterns) {
        $files += @(Get-ChildItem -Path $pattern -File -ErrorAction SilentlyContinue)
    }

    $normalizedOutputRoot = [System.IO.Path]::GetFullPath($OutputRoot)

    $hashes = @(
        $files |
            Sort-Object FullName |
            ForEach-Object {
                $relativePath = [System.IO.Path]::GetRelativePath($normalizedOutputRoot, $_.FullName) -replace '\\', '/'
                $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash
                "$relativePath::$hash"
            }
    )

    return $hashes
}

function Invoke-ExtensionCollectionsGeneration {
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $collectionsDir = Join-Path $RepoRoot 'collections'
    $templatesDir = Join-Path $RepoRoot 'extension/templates'

    $packageTemplatePath = Join-Path $templatesDir 'package.template.json'

    if (-not (Test-Path $packageTemplatePath)) {
        throw "Package template not found: $packageTemplatePath"
    }

    if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
        throw "Required module 'PowerShell-Yaml' is not installed."
    }

    Import-Module PowerShell-Yaml -ErrorAction Stop

    $packageTemplate = Get-Content -Path $packageTemplatePath -Raw | ConvertFrom-Json

    $collectionFiles = Get-ChildItem -Path $collectionsDir -Filter '*.collection.yml' -File | Sort-Object Name
    if ($collectionFiles.Count -eq 0) {
        throw "No root collection files found in $collectionsDir"
    }

    $expectedFiles = @()

    foreach ($collectionFile in $collectionFiles) {
        $collection = ConvertFrom-Yaml -Yaml (Get-Content -Path $collectionFile.FullName -Raw)
        if ($collection -isnot [hashtable]) {
            throw "Collection manifest must be a hashtable: $($collectionFile.FullName)"
        }

        $collectionId = [string]$collection.id
        if ([string]::IsNullOrWhiteSpace($collectionId)) {
            throw "Collection id is required: $($collectionFile.FullName)"
        }

        $collectionDescription = if ($collection.ContainsKey('description')) { [string]$collection.description } else { [string]$packageTemplate.description }

        $extensionName = if ($collectionId -eq 'hve-core-all') { [string]$packageTemplate.name } else { "hve-$collectionId" }
        $extensionDisplayName = if ($collectionId -eq 'hve-core-all') {
            [string]$packageTemplate.displayName
        }
        else {
            Get-CollectionDisplayName -CollectionManifest $collection -DefaultValue ([string]$packageTemplate.displayName)
        }

        $packageTemplateOutput = Copy-TemplateWithOverrides -Template $packageTemplate -Overrides @{
            name        = $extensionName
            displayName = $extensionDisplayName
            description = $collectionDescription
        }

        $packagePath = if ($collectionId -eq 'hve-core-all') {
            Join-Path $RepoRoot 'extension/package.json'
        }
        else {
            Join-Path $RepoRoot "extension/package.$collectionId.json"
        }

        Set-JsonFile -Path $packagePath -Content $packageTemplateOutput
        $expectedFiles += $packagePath
    }

    Remove-StaleGeneratedFiles -RepoRoot $RepoRoot -ExpectedFiles $expectedFiles

    return $expectedFiles
}

if ($MyInvocation.InvocationName -ne '.') {
    try {
        $scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
        $repoRoot = (Get-Item "$scriptDir/../..").FullName

        $generated = Invoke-ExtensionCollectionsGeneration -RepoRoot $repoRoot

        if ($ValidateDeterminism) {
            $tempA = Join-Path ([System.IO.Path]::GetTempPath()) ("hve-extgen-A-" + [System.Guid]::NewGuid().ToString('N'))
            $tempB = Join-Path ([System.IO.Path]::GetTempPath()) ("hve-extgen-B-" + [System.Guid]::NewGuid().ToString('N'))

            try {
                New-Item -Path $tempA -ItemType Directory -Force | Out-Null
                New-Item -Path $tempB -ItemType Directory -Force | Out-Null
                New-Item -Path (Join-Path $tempA 'extension') -ItemType Directory -Force | Out-Null
                New-Item -Path (Join-Path $tempB 'extension') -ItemType Directory -Force | Out-Null

                Copy-Item -Path (Join-Path $repoRoot 'collections') -Destination $tempA -Recurse
                Copy-Item -Path (Join-Path $repoRoot 'collections') -Destination $tempB -Recurse
                Copy-Item -Path (Join-Path $repoRoot 'extension/templates') -Destination (Join-Path $tempA 'extension/templates') -Recurse
                Copy-Item -Path (Join-Path $repoRoot 'extension/templates') -Destination (Join-Path $tempB 'extension/templates') -Recurse

                Invoke-ExtensionCollectionsGeneration -RepoRoot $tempA | Out-Null
                Invoke-ExtensionCollectionsGeneration -RepoRoot $tempB | Out-Null

                $hashesA = Get-GenerationHashes -OutputRoot $tempA
                $hashesB = Get-GenerationHashes -OutputRoot $tempB

                $contentA = ($hashesA -join "`n")
                $contentB = ($hashesB -join "`n")
                if ($contentA -ne $contentB) {
                    throw 'Determinism validation failed: generated outputs differ for identical inputs.'
                }
            }
            finally {
                if (Test-Path $tempA) { Remove-Item -Path $tempA -Recurse -Force }
                if (Test-Path $tempB) { Remove-Item -Path $tempB -Recurse -Force }
            }
        }

        Write-Host "Generated $($generated.Count) extension artifacts." -ForegroundColor Green
        Set-CIOutput -Name 'generated-files-count' -Value $generated.Count
        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Generate-ExtensionCollections failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
