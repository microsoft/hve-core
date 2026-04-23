#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates AI artifact footer and disclaimer presence in instruction templates.

.DESCRIPTION
    Reads footer-with-review.yml and disclaimers.yml config files as the single source
    of truth, then scans instruction files for required footer text based on artifact
    classification rules. Outputs results as JSON and sets CI environment variables on
    failure.

.PARAMETER Paths
    Directories to scan for instruction files. Defaults to '.github/instructions'.

.PARAMETER ExcludePaths
    Directories to exclude from scanning.

.PARAMETER FooterConfigPath
    Path to the footer-with-review.yml config file.

.PARAMETER DisclaimerConfigPath
    Path to the disclaimers.yml config file.

.PARAMETER FailOnMissing
    When specified, treats missing footers and disclaimers as validation failures.

.PARAMETER OutputPath
    Path for the JSON results file. Defaults to 'logs/ai-artifact-results.json'.

.EXAMPLE
    ./Validate-PlannerArtifacts.ps1 -FailOnMissing

.EXAMPLE
    ./Validate-PlannerArtifacts.ps1 -Paths '.github/instructions','.github/skills' -OutputPath 'logs/results.json'
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('.github/instructions'),

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths = @(),

    [Parameter(Mandatory = $false)]
    [string]$FooterConfigPath = '.github/config/footer-with-review.yml',

    [Parameter(Mandatory = $false)]
    [string]$DisclaimerConfigPath = '.github/config/disclaimers.yml',

    [Parameter(Mandatory = $false)]
    [switch]$FailOnMissing,

    [Parameter(Mandatory = $false)]
    [string]$OutputPath = 'logs/ai-artifact-results.json'
)

$ErrorActionPreference = 'Stop'

Import-Module PowerShell-Yaml -ErrorAction Stop
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

#region Functions

function Import-FooterConfig {
    <#
    .SYNOPSIS
    Loads and validates footer-with-review.yml.

    .PARAMETER ConfigPath
    Absolute path to the footer config YAML file.

    .OUTPUTS
    [hashtable] Parsed footer config.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Footer config not found: $ConfigPath"
    }

    $content = Get-Content -Path $ConfigPath -Raw -Encoding utf8
    $config = ConvertFrom-Yaml -Yaml $content

    if (-not $config.version) {
        throw "Footer config missing 'version' field: $ConfigPath"
    }
    if (-not $config.footers) {
        throw "Footer config missing 'footers' section: $ConfigPath"
    }
    if (-not $config.'artifact-classification') {
        throw "Footer config missing 'artifact-classification' section: $ConfigPath"
    }

    return $config
}

function Import-DisclaimerConfig {
    <#
    .SYNOPSIS
    Loads and validates disclaimers.yml.

    .PARAMETER ConfigPath
    Absolute path to the disclaimer config YAML file.

    .OUTPUTS
    [hashtable] Parsed disclaimer config.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$ConfigPath
    )

    if (-not (Test-Path $ConfigPath)) {
        throw "Disclaimer config not found: $ConfigPath"
    }

    $content = Get-Content -Path $ConfigPath -Raw -Encoding utf8
    $config = ConvertFrom-Yaml -Yaml $content

    if (-not $config.version) {
        throw "Disclaimer config missing 'version' field: $ConfigPath"
    }
    if (-not $config.disclaimers) {
        throw "Disclaimer config missing 'disclaimers' section: $ConfigPath"
    }

    return $config
}

function Get-FooterSearchText {
    <#
    .SYNOPSIS
    Extracts plain-text search strings from footer config entries.

    .DESCRIPTION
    Strips leading blockquote markers and normalizes whitespace to produce
    a substring suitable for content matching.

    .PARAMETER FooterText
    Raw footer text from the YAML config.

    .OUTPUTS
    [string] Normalized search string.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FooterText
    )

    # Strip leading > and trim
    $normalized = $FooterText -replace '^\s*>\s*', ''
    # Collapse internal whitespace for matching
    $normalized = $normalized -replace '\s+', ' '
    return $normalized.Trim()
}

function Test-FooterInContent {
    <#
    .SYNOPSIS
    Checks whether a footer text pattern appears in file content.

    .PARAMETER Content
    Full file content as a single string.

    .PARAMETER FooterText
    Raw footer text from config (may include blockquote markers).

    .OUTPUTS
    [bool] $true if the footer text is found in content.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$FooterText
    )

    $searchText = Get-FooterSearchText -FooterText $FooterText
    # Normalize file content whitespace for comparison
    $normalizedContent = $Content -replace '\s+', ' '

    return $normalizedContent.Contains($searchText)
}

function Test-DisclaimerInContent {
    <#
    .SYNOPSIS
    Checks whether disclaimer text appears in file content.

    .PARAMETER Content
    Full file content as a single string.

    .PARAMETER DisclaimerText
    Raw disclaimer text from config.

    .OUTPUTS
    [bool] $true if the disclaimer text is found in content.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [string]$DisclaimerText
    )

    $searchText = Get-FooterSearchText -FooterText $DisclaimerText
    $normalizedContent = $Content -replace '\s+', ' '

    return $normalizedContent.Contains($searchText)
}

function Find-ArtifactReferences {
    <#
    .SYNOPSIS
    Identifies which configured artifact names match a file by its basename.

    .DESCRIPTION
    Matches the file basename (with .instructions.md or .md extension stripped)
    against configured artifact names to determine which classification tier
    applies. Scope patterns filter by relative path when configured.

    .PARAMETER ArtifactClassification
    The artifact-classification section from footer config.

    .PARAMETER RelativePath
    Relative path of the file. Used for scope filtering and basename extraction
    to match against artifact names.

    .OUTPUTS
    [hashtable[]] Array of hashtables with keys: ArtifactName, Tier, RequiredFooters, RequiresDisclaimer, DisclaimerRef.
    #>
    [CmdletBinding()]
    [OutputType([hashtable[]])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$ArtifactClassification,

        [Parameter(Mandatory = $false)]
        [string]$RelativePath
    )

    $foundRefs = @()

    # Extract base name by stripping .instructions.md or .md extension
    $fileBaseName = if ($RelativePath) {
        $fileName = [System.IO.Path]::GetFileName($RelativePath)
        $fileName -replace '\.(?:instructions\.)?md$', ''
    } else { '' }

    foreach ($tierName in $ArtifactClassification.Keys) {
        $tier = $ArtifactClassification[$tierName]
        $artifacts = $tier.artifacts
        if (-not $artifacts) { continue }

        # Scope filtering: skip tiers whose scope patterns do not match the file path
        if ($tier.scope -and $RelativePath) {
            $inScope = $false
            foreach ($pattern in $tier.scope) {
                if ($RelativePath -like $pattern) {
                    $inScope = $true
                    break
                }
            }
            if (-not $inScope) { continue }
        }

        foreach ($artifactName in $artifacts) {
            if ($fileBaseName -eq $artifactName) {
                $foundRefs += @{
                    ArtifactName       = $artifactName
                    Tier               = $tierName
                    RequiredFooters    = $tier.'required-footers'
                    RequiresDisclaimer = [bool]$tier.'requires-disclaimer'
                    DisclaimerRef      = $tier.'disclaimer-ref'
                }
            }
        }
    }

    Write-Output -NoEnumerate -InputObject $foundRefs
}

function Test-AIArtifactCompliance {
    <#
    .SYNOPSIS
    Validates footer and disclaimer compliance for a single file.

    .PARAMETER FilePath
    Path to the file to validate.

    .PARAMETER FooterConfig
    Parsed footer-with-review.yml config.

    .PARAMETER DisclaimerConfig
    Parsed disclaimers.yml config.

    .PARAMETER RepoRoot
    Repository root for relative path display.

    .OUTPUTS
    [hashtable] Validation result with keys: File, RelativePath, ArtifactsFound, Issues, Passed.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [hashtable]$FooterConfig,

        [Parameter(Mandatory = $true)]
        [hashtable]$DisclaimerConfig,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $content = Get-Content -Path $FilePath -Raw -Encoding utf8
    $relativePath = $FilePath.Substring($RepoRoot.Length + 1).Replace('\', '/')
    $issues = @()
    $artifactsFound = @()

    $artifactRefs = Find-ArtifactReferences -ArtifactClassification $FooterConfig.'artifact-classification' -RelativePath $relativePath

    if ($artifactRefs.Count -eq 0) {
        return @{
            File           = $FilePath
            RelativePath   = $relativePath
            ArtifactsFound = @()
            Issues         = @()
            Passed         = $true
            Skipped        = $true
        }
    }

    foreach ($ref in $artifactRefs) {
        $artifactsFound += $ref.ArtifactName

        # Check required footers
        foreach ($footerKey in $ref.RequiredFooters) {
            $footerDef = $FooterConfig.footers[$footerKey]
            if (-not $footerDef) {
                $issues += "Artifact '$($ref.ArtifactName)' requires footer '$footerKey' but it is not defined in footer config"
                continue
            }

            if (-not (Test-FooterInContent -Content $content -FooterText $footerDef.text)) {
                $issues += "Missing footer '$($footerDef.label)' for artifact '$($ref.ArtifactName)' (tier: $($ref.Tier))"
            }
        }

        # Check disclaimer requirement
        if ($ref.RequiresDisclaimer -and $ref.DisclaimerRef) {
            $disclaimerFound = $false
            foreach ($plannerKey in $DisclaimerConfig.disclaimers.Keys) {
                $disclaimer = $DisclaimerConfig.disclaimers[$plannerKey]
                if ($disclaimer.id -eq $ref.DisclaimerRef) {
                    if (-not (Test-DisclaimerInContent -Content $content -DisclaimerText $disclaimer.text)) {
                        $issues += "Missing disclaimer '$($disclaimer.label)' for artifact '$($ref.ArtifactName)' (tier: $($ref.Tier))"
                    }
                    $disclaimerFound = $true
                    break
                }
            }
            if (-not $disclaimerFound) {
                $issues += "Artifact '$($ref.ArtifactName)' references disclaimer '$($ref.DisclaimerRef)' but it is not defined in disclaimer config"
            }
        }
    }

    # De-duplicate issues (same footer may be required by multiple artifacts in the same tier)
    $uniqueIssues = $issues | Select-Object -Unique

    return @{
        File           = $FilePath
        RelativePath   = $relativePath
        ArtifactsFound = ($artifactsFound | Select-Object -Unique)
        Issues         = @($uniqueIssues)
        Passed         = ($uniqueIssues.Count -eq 0)
        Skipped        = $false
    }
}

function Test-AIArtifactValidation {
    <#
    .SYNOPSIS
    Orchestrates AI artifact validation across instruction files.

    .PARAMETER Paths
    Root search paths relative to the repository root.

    .PARAMETER ExcludePaths
    Glob patterns to exclude from scanning.

    .PARAMETER FooterConfigPath
    Path to footer-with-review.yml relative to repo root.

    .PARAMETER DisclaimerConfigPath
    Path to disclaimers.yml relative to repo root.

    .PARAMETER FailOnMissing
    When set, missing footers cause a non-zero exit code.

    .PARAMETER OutputPath
    Path for JSON results output relative to repo root.

    .OUTPUTS
    [hashtable] Summary with keys: TotalFiles, FilesScanned, FilesWithArtifacts, FilesWithIssues, Issues, Results.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths,

        [Parameter(Mandatory = $false)]
        [string[]]$ExcludePaths = @(),

        [Parameter(Mandatory = $true)]
        [string]$FooterConfigPath,

        [Parameter(Mandatory = $true)]
        [string]$DisclaimerConfigPath,

        [Parameter(Mandatory = $false)]
        [switch]$FailOnMissing,

        [Parameter(Mandatory = $false)]
        [string]$OutputPath
    )

    $repoRoot = git rev-parse --show-toplevel 2>$null
    if (-not $repoRoot) {
        throw 'Not inside a git repository'
    }
    $repoRoot = (Resolve-Path $repoRoot).Path

    # Load configs
    $footerConfig = Import-FooterConfig -ConfigPath (Join-Path $repoRoot $FooterConfigPath)
    $disclaimerConfig = Import-DisclaimerConfig -ConfigPath (Join-Path $repoRoot $DisclaimerConfigPath)

    # Collect instruction files
    $allFiles = @()
    foreach ($searchPath in $Paths) {
        $fullPath = Join-Path $repoRoot $searchPath
        if (Test-Path $fullPath) {
            $files = Get-FilesRecursive -Path $fullPath -Include @('*.instructions.md')
            $allFiles += $files
        }
    }

    # Apply exclude patterns
    if ($ExcludePaths.Count -gt 0) {
        $allFiles = $allFiles | Where-Object {
            $relPath = $_.FullName.Substring($repoRoot.Length + 1).Replace('\', '/')
            $excluded = $false
            foreach ($pattern in $ExcludePaths) {
                if ($relPath -like $pattern) {
                    $excluded = $true
                    break
                }
            }
            -not $excluded
        }
    }

    # Validate each file
    $results = @()
    $issueCount = 0
    $filesWithArtifacts = 0
    $filesWithIssues = 0

    foreach ($file in $allFiles) {
        $result = Test-AIArtifactCompliance `
            -FilePath $file.FullName `
            -FooterConfig $footerConfig `
            -DisclaimerConfig $disclaimerConfig `
            -RepoRoot $repoRoot

        $results += $result

        if (-not $result.Skipped) {
            $filesWithArtifacts++
        }
        if (-not $result.Passed) {
            $filesWithIssues++
            $issueCount += $result.Issues.Count

            foreach ($issue in $result.Issues) {
                $level = if ($FailOnMissing) { 'Error' } else { 'Warning' }
                Write-CIAnnotation -Message "$($result.RelativePath): $issue" -Level $level -File $result.RelativePath
                Write-Host "  $level :: $($result.RelativePath): $issue" -ForegroundColor $(if ($FailOnMissing) { 'Red' } else { 'Yellow' })
            }
        }
    }

    $summary = @{
        TotalFiles         = $allFiles.Count
        FilesScanned       = $allFiles.Count
        FilesWithArtifacts = $filesWithArtifacts
        FilesWithIssues    = $filesWithIssues
        TotalIssues        = $issueCount
        Results            = $results
        HasFailures        = ($FailOnMissing -and $filesWithIssues -gt 0)
    }

    # Console output
    Write-Host ""
    Write-Host "AI Artifact Validation Summary" -ForegroundColor Cyan
    Write-Host "  Files scanned:        $($summary.TotalFiles)"
    Write-Host "  Files with artifacts: $($summary.FilesWithArtifacts)"
    Write-Host "  Files with issues:    $($summary.FilesWithIssues)"
    Write-Host "  Total issues:         $($summary.TotalIssues)"

    # Export JSON results
    if ($OutputPath) {
        $outputFullPath = Join-Path $repoRoot $OutputPath
        $outputDir = Split-Path -Parent $outputFullPath
        if (-not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        $jsonResults = @{
            timestamp          = Get-StandardTimestamp
            totalFiles         = $summary.TotalFiles
            filesWithArtifacts = $summary.FilesWithArtifacts
            filesWithIssues    = $summary.FilesWithIssues
            totalIssues        = $summary.TotalIssues
            results            = $results | Where-Object { -not $_.Skipped } | ForEach-Object {
                @{
                    file           = $_.RelativePath
                    artifacts      = $_.ArtifactsFound
                    issues         = $_.Issues
                    passed         = $_.Passed
                }
            }
        }

        $jsonResults | ConvertTo-Json -Depth 10 | Set-Content -Path $outputFullPath -Encoding utf8
        Write-Host "  Results written to: $OutputPath" -ForegroundColor Gray
    }

    # CI step summary
    if (Test-CIEnvironment) {
        if ($summary.HasFailures) {
            $summaryContent = @"
## ❌ AI Artifact Validation Failed

**Files scanned:** $($summary.TotalFiles)
**Files with artifacts:** $($summary.FilesWithArtifacts)
**Files with issues:** $($summary.FilesWithIssues)
**Total issues:** $($summary.TotalIssues)

See the uploaded artifact for complete details.
"@
            Write-CIStepSummary -Content $summaryContent
            Set-CIEnv -Name "AI_ARTIFACT_VALIDATION_FAILED" -Value "true"
        }
        else {
            $summaryContent = @"
## ✅ AI Artifact Validation Passed

**Files scanned:** $($summary.TotalFiles)
**Files with artifacts:** $($summary.FilesWithArtifacts)
**Issues:** 0
"@
            Write-CIStepSummary -Content $summaryContent
        }
    }

    if (-not $summary.HasFailures) {
        Write-Host "✅ AI artifact validation completed successfully" -ForegroundColor Green
    }

    return $summary
}

#endregion Functions

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    try {
        # Verify PowerShell-Yaml module
        if (-not (Get-Module -ListAvailable -Name PowerShell-Yaml)) {
            throw "Required module 'PowerShell-Yaml' is not installed."
        }

        $result = Test-AIArtifactValidation `
            -Paths $Paths `
            -ExcludePaths $ExcludePaths `
            -FooterConfigPath $FooterConfigPath `
            -DisclaimerConfigPath $DisclaimerConfigPath `
            -FailOnMissing:$FailOnMissing `
            -OutputPath $OutputPath

        if ($result.HasFailures) {
            Write-Error "AI artifact validation failed with $($result.TotalIssues) issue(s)."
            exit 1
        }

        exit 0
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-PlannerArtifacts failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
