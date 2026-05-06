#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates model references in agent and prompt files against the model catalog.

.DESCRIPTION
    Scans all .agent.md and .prompt.md files for model frontmatter references and
    validates them against scripts/linting/model-catalog.json. Reports unrecognized
    models and models with retiring status.

.PARAMETER OutputPath
    Path for the JSON results file.

.PARAMETER CatalogPath
    Path to the model catalog JSON file.

.EXAMPLE
    ./Test-ModelReferences.ps1

.EXAMPLE
    ./Test-ModelReferences.ps1 -OutputPath logs/model-validation-results.json
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/model-validation-results.json',

    [Parameter(Mandatory = $false)]
    [string]$CatalogPath = 'scripts/linting/model-catalog.json'
)

$ErrorActionPreference = 'Stop'

Import-Module PowerShell-Yaml -ErrorAction Stop

#region Functions

function Get-FrontmatterFromFile {
    <#
    .SYNOPSIS
    Extracts YAML frontmatter from a markdown file.

    .PARAMETER FilePath
    Path to the markdown file.

    .OUTPUTS
    [hashtable] Parsed frontmatter or $null if no frontmatter found.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )

    $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
    if ($content -match '(?s)^---\r?\n(.+?)\r?\n---') {
        $yamlBlock = $Matches[1]
        try {
            return ConvertFrom-Yaml -Yaml $yamlBlock
        }
        catch {
            Write-Warning "Failed to parse YAML in $FilePath : $_"
            return $null
        }
    }
    return $null
}

function Get-ModelReferences {
    <#
    .SYNOPSIS
    Extracts model references from frontmatter.

    .PARAMETER Frontmatter
    Parsed frontmatter hashtable.

    .OUTPUTS
    [string[]] Array of model name strings.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter
    )

    $modelValue = $Frontmatter['model']
    if ($null -eq $modelValue) {
        return @()
    }

    if ($modelValue -is [System.Collections.IEnumerable] -and $modelValue -isnot [string]) {
        return @($modelValue | ForEach-Object { $_.ToString() })
    }

    return @($modelValue.ToString())
}

#endregion Functions

#region Main

# Validate catalog exists
if (-not (Test-Path -Path $CatalogPath)) {
    Write-Error "Model catalog not found at: $CatalogPath"
    exit 1
}

$catalog = Get-Content -Path $CatalogPath -Raw | ConvertFrom-Json
$validModelNames = @($catalog.models | ForEach-Object { $_.name })
$retiringModels = @($catalog.models | Where-Object { $_.status -eq 'retiring' } | ForEach-Object { $_.name })

# Find all agent and prompt files
$agentFiles = Get-ChildItem -Path '.github' -Recurse -Filter '*.agent.md' -ErrorAction SilentlyContinue
$promptFiles = Get-ChildItem -Path '.github' -Recurse -Filter '*.prompt.md' -ErrorAction SilentlyContinue
$allFiles = @($agentFiles) + @($promptFiles) | Where-Object { $null -ne $_ }

$results = @()
$warnings = @()
$errors = @()
$totalReferences = 0
$validReferences = 0
$invalidReferences = 0
$retiringReferences = 0
$filesWithModels = 0

foreach ($file in $allFiles) {
    $relativePath = $file.FullName -replace [regex]::Escape((Get-Location).Path + [System.IO.Path]::DirectorySeparatorChar), ''
    $relativePath = $relativePath.Replace('\', '/')

    $frontmatter = Get-FrontmatterFromFile -FilePath $file.FullName
    if ($null -eq $frontmatter) {
        continue
    }

    $models = Get-ModelReferences -Frontmatter $frontmatter
    if ($models.Count -eq 0) {
        continue
    }

    $filesWithModels++
    $fileStatus = 'valid'
    $fileModels = @()

    foreach ($modelName in $models) {
        $totalReferences++
        $fileModels += $modelName

        if ($modelName -notin $validModelNames) {
            $invalidReferences++
            $fileStatus = 'invalid'
            $errors += @{
                file    = $relativePath
                model   = $modelName
                message = "Unrecognized model: '$modelName' not found in catalog"
            }
        }
        elseif ($modelName -in $retiringModels) {
            $retiringReferences++
            $validReferences++
            if ($fileStatus -ne 'invalid') { $fileStatus = 'warning' }
            $warnings += @{
                file    = $relativePath
                model   = $modelName
                message = "Model '$modelName' is marked as retiring in the catalog"
            }
        }
        else {
            $validReferences++
        }
    }

    $results += @{
        file   = $relativePath
        models = $fileModels
        status = $fileStatus
    }
}

# Build output
$output = @{
    timestamp           = (Get-Date -Format 'o')
    catalogLastUpdated  = $catalog.lastUpdated
    totalFiles          = $allFiles.Count
    filesWithModels     = $filesWithModels
    totalReferences     = $totalReferences
    validReferences     = $validReferences
    invalidReferences   = $invalidReferences
    retiringReferences  = $retiringReferences
    results             = $results
    warnings            = $warnings
    errors              = $errors
}

# Ensure output directory exists
$outputDir = Split-Path -Path $OutputPath -Parent
if ($outputDir -and -not (Test-Path -Path $outputDir)) {
    New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
}

$output | ConvertTo-Json -Depth 5 | Set-Content -Path $OutputPath -Encoding utf8

# Summary output
Write-Host "Model Reference Validation Results:" -ForegroundColor Cyan
Write-Host "  Total files scanned: $($allFiles.Count)"
Write-Host "  Files with model references: $filesWithModels"
Write-Host "  Total model references: $totalReferences"
Write-Host "  Valid references: $validReferences" -ForegroundColor Green
if ($retiringReferences -gt 0) {
    Write-Host "  Retiring references: $retiringReferences" -ForegroundColor Yellow
}
if ($invalidReferences -gt 0) {
    Write-Host "  Invalid references: $invalidReferences" -ForegroundColor Red
    foreach ($err in $errors) {
        Write-Host "    ERROR: $($err.file) - $($err.message)" -ForegroundColor Red
    }
}
foreach ($warn in $warnings) {
    Write-Host "    WARNING: $($warn.file) - $($warn.message)" -ForegroundColor Yellow
}

Write-Host "`nResults written to: $OutputPath"

if ($invalidReferences -gt 0) {
    exit 1
}

exit 0

#endregion Main
