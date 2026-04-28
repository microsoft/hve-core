#!/usr/bin/env pwsh
# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

#Requires -Version 7.0

<#
.SYNOPSIS
    Validates planner artifact compliance: footers, disclaimers, and skill-loading contracts.

.DESCRIPTION
    Reads footer-with-review.yml and disclaimers.yml config files as the single source
    of truth, then scans instruction files for required footer text based on artifact
    classification rules. When -PlanRoot is supplied, additionally enforces the
    skill-loading contract by parsing 'skills-loaded.log' and rejecting any entry
    outside the declared scope for the active phase (per the skill's index.yml). Outputs
    results as JSON and sets CI environment variables on failure.

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

.PARAMETER Scope
    Planner family scope. One of 'rai', 'sssc', 'security', 'all'. Used to derive the
    default planner tracking root and to scope skill-loading-contract enforcement.

.PARAMETER PlanRoot
    Path to a single planner instance (e.g. '.copilot-tracking/sssc-plans/{slug}').
    When supplied, the skill-loading contract is enforced against the
    'skills-loaded.log' adjacent to 'state.json' under this root.

.PARAMETER LoadingViolationsOutputPath
    Path for the skill-loading-contract violations JSON file.
    Defaults to 'logs/planner-loading-violations.json'.

.EXAMPLE
    ./Validate-PlannerArtifacts.ps1 -FailOnMissing

.EXAMPLE
    ./Validate-PlannerArtifacts.ps1 -Paths '.github/instructions','.github/skills' -OutputPath 'logs/results.json'

.EXAMPLE
    ./Validate-PlannerArtifacts.ps1 -Scope sssc -PlanRoot .copilot-tracking/sssc-plans/my-project
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
    [string]$OutputPath = 'logs/ai-artifact-results.json',

    [Parameter(Mandatory = $false)]
    [ValidateSet('rai', 'sssc', 'security', 'all')]
    [string]$Scope = 'all',

    [Parameter(Mandatory = $false)]
    [string]$PlanRoot,

    [Parameter(Mandatory = $false)]
    [string]$LoadingViolationsOutputPath = 'logs/planner-loading-violations.json',

    [Parameter(Mandatory = $false)]
    [switch]$EvidenceCitationCheck,

    [Parameter(Mandatory = $false)]
    [string[]]$EvidenceCitationRoots = @(
        '.copilot-tracking/rai-plans',
        '.copilot-tracking/security-plans',
        '.copilot-tracking/sssc-plans',
        '.copilot-tracking/accessibility-plans',
        '.copilot-tracking/sustainability-plans',
        '.copilot-tracking/requirements-sessions'
    ),

    [Parameter(Mandatory = $false)]
    [string]$EvidenceCitationOutputPath = 'logs/evidence-citation-results.json'
)

$ErrorActionPreference = 'Stop'

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

    Import-Module PowerShell-Yaml -ErrorAction Stop
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

    Import-Module PowerShell-Yaml -ErrorAction Stop
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

function Test-SkillLoadingContract {
    <#
    .SYNOPSIS
    Validates the skill-loading contract for a planner instance.

    .DESCRIPTION
    Reads 'skills-loaded.log' (NDJSON, one entry per line) under the planner instance
    root, then for each entry resolves the parent skill's 'index.yml' and verifies the
    logged controlPath is in the phaseMap[phase] list. Entries with null controlPath
    (index.yml or SKILL.md reads) are always allowed. Out-of-scope entries are recorded
    as violations and emitted as JSON to OutputPath.

    .PARAMETER PlanRoot
    Path to the planner instance root (containing state.json and skills-loaded.log).

    .PARAMETER Scope
    Planner family scope (informational; recorded in the violations report).

    .PARAMETER OutputPath
    Path for the violations JSON file.

    .OUTPUTS
    [hashtable] Result with HasViolations and TotalViolations keys.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$PlanRoot,

        [Parameter(Mandatory = $false)]
        [string]$Scope = 'all',

        [Parameter(Mandatory = $false)]
        [string]$OutputPath = 'logs/planner-loading-violations.json'
    )

    $result = @{
        Scope           = $Scope
        PlanRoot        = $PlanRoot
        HasViolations   = $false
        TotalViolations = 0
        Violations      = @()
    }

    if (-not (Test-Path -Path $PlanRoot -PathType Container)) {
        Write-Host "  PlanRoot not found, skipping skill-loading contract: $PlanRoot" -ForegroundColor Yellow
        return $result
    }

    $logPath = Join-Path -Path $PlanRoot -ChildPath 'skills-loaded.log'
    if (-not (Test-Path -Path $logPath -PathType Leaf)) {
        Write-Host "  No skills-loaded.log under $PlanRoot — contract enforcement skipped." -ForegroundColor Yellow
        return $result
    }

    Write-Host "Validating skill-loading contract: $logPath" -ForegroundColor Cyan

    $entries = @()
    $lineNumber = 0
    Get-Content -LiteralPath $logPath -Encoding utf8 | ForEach-Object {
        $lineNumber++
        $line = $_.Trim()
        if ([string]::IsNullOrWhiteSpace($line)) { return }
        try {
            $entry = $line | ConvertFrom-Json -ErrorAction Stop
            $entries += [pscustomobject]@{
                LineNumber  = $lineNumber
                Phase       = $entry.phase
                SkillPath   = $entry.skillPath
                ControlPath = $entry.controlPath
                LoadedAt    = $entry.loadedAt
            }
        }
        catch {
            $result.Violations += @{
                lineNumber = $lineNumber
                reason     = 'malformed-ndjson'
                message    = $_.Exception.Message
                rawLine    = $line
            }
        }
    }

    foreach ($entry in $entries) {
        # Null controlPath means the read targeted the skill's index.yml or SKILL.md — always allowed.
        if ([string]::IsNullOrWhiteSpace($entry.ControlPath)) { continue }

        if ([string]::IsNullOrWhiteSpace($entry.SkillPath) -or [string]::IsNullOrWhiteSpace($entry.Phase)) {
            $result.Violations += @{
                lineNumber  = $entry.LineNumber
                reason      = 'missing-required-field'
                phase       = $entry.Phase
                skillPath   = $entry.SkillPath
                controlPath = $entry.ControlPath
            }
            continue
        }

        # Resolve parent skill directory: trim trailing 'controls/...' and 'index.yml' / 'SKILL.md'.
        $skillDir = $entry.SkillPath
        if ($skillDir -match '^(.*?)/controls/') {
            $skillDir = $Matches[1]
        }
        elseif ($skillDir -match '^(.*?)/(index\.yml|SKILL\.md)$') {
            $skillDir = $Matches[1]
        }

        $indexPath = Join-Path -Path $skillDir -ChildPath 'index.yml'
        if (-not (Test-Path -Path $indexPath -PathType Leaf)) {
            $result.Violations += @{
                lineNumber  = $entry.LineNumber
                reason      = 'missing-index-yml'
                phase       = $entry.Phase
                skillPath   = $entry.SkillPath
                controlPath = $entry.ControlPath
                indexPath   = $indexPath
            }
            continue
        }

        try {
            $index = Get-Content -LiteralPath $indexPath -Raw -Encoding utf8 | ConvertFrom-Yaml
        }
        catch {
            $result.Violations += @{
                lineNumber  = $entry.LineNumber
                reason      = 'index-yml-parse-failed'
                phase       = $entry.Phase
                skillPath   = $entry.SkillPath
                controlPath = $entry.ControlPath
                indexPath   = $indexPath
                message     = $_.Exception.Message
            }
            continue
        }

        $phaseMap = $null
        if ($index -is [System.Collections.IDictionary] -and $index.ContainsKey('phaseMap')) {
            $phaseMap = $index['phaseMap']
        }
        elseif ($index.PSObject.Properties.Name -contains 'phaseMap') {
            $phaseMap = $index.phaseMap
        }

        if (-not $phaseMap) {
            $result.Violations += @{
                lineNumber  = $entry.LineNumber
                reason      = 'index-yml-missing-phaseMap'
                phase       = $entry.Phase
                skillPath   = $entry.SkillPath
                controlPath = $entry.ControlPath
                indexPath   = $indexPath
            }
            continue
        }

        $allowedControls = $null
        if ($phaseMap -is [System.Collections.IDictionary] -and $phaseMap.ContainsKey($entry.Phase)) {
            $allowedControls = @($phaseMap[$entry.Phase])
        }
        elseif ($phaseMap.PSObject.Properties.Name -contains $entry.Phase) {
            $allowedControls = @($phaseMap.($entry.Phase))
        }

        if ($null -eq $allowedControls) {
            $result.Violations += @{
                lineNumber       = $entry.LineNumber
                reason           = 'phase-not-in-phaseMap'
                phase            = $entry.Phase
                skillPath        = $entry.SkillPath
                controlPath      = $entry.ControlPath
                indexPath        = $indexPath
                availablePhases  = @($phaseMap.Keys)
            }
            continue
        }

        # Derive control id: strip leading 'controls/' and trailing '.yml' from controlPath.
        $controlId = $entry.ControlPath
        $controlId = $controlId -replace '^controls/', ''
        $controlId = $controlId -replace '\.yml$', ''

        if ($allowedControls -notcontains $controlId) {
            $result.Violations += @{
                lineNumber      = $entry.LineNumber
                reason          = 'control-out-of-scope'
                phase           = $entry.Phase
                skillPath       = $entry.SkillPath
                controlPath     = $entry.ControlPath
                controlId       = $controlId
                allowedControls = @($allowedControls)
            }
        }
    }

    $result.TotalViolations = $result.Violations.Count
    $result.HasViolations = $result.TotalViolations -gt 0

    # Persist findings.
    $outputFullPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
        $OutputPath
    }
    else {
        Join-Path -Path $PWD -ChildPath $OutputPath
    }
    $outputDir = Split-Path -Path $outputFullPath -Parent
    if ($outputDir -and -not (Test-Path -Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    $payload = [ordered]@{
        scope           = $Scope
        planRoot        = $PlanRoot
        logPath         = $logPath
        entriesScanned  = $entries.Count
        totalViolations = $result.TotalViolations
        violations      = $result.Violations
    }
    $payload | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $outputFullPath -Encoding utf8

    if ($result.HasViolations) {
        Write-Host "  ❌ $($result.TotalViolations) skill-loading-contract violation(s) — see $OutputPath" -ForegroundColor Red
    }
    else {
        Write-Host "  ✅ Skill-loading contract clean ($($entries.Count) entries)" -ForegroundColor Green
    }

    return $result
}

function Find-EvidenceCitationViolationsInContent {
    <#
    .SYNOPSIS
    Scans markdown content for verdict-bearing tables and reports rows whose Evidence cell
    lacks a '(Lines N-M)' span and lacks an explicit 'kind:' qualifier.

    .PARAMETER Content
    Raw markdown content to scan.

    .PARAMETER FilePath
    Source file path used for warning metadata.

    .OUTPUTS
    [hashtable[]] Warning entries (file, line, tableHeading, rowIndex, verdict, reason).
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.IList])]
    param(
        [Parameter(Mandatory = $true)]
        [AllowEmptyString()]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath
    )

    $warnings = [System.Collections.Generic.List[hashtable]]::new()
    if ([string]::IsNullOrEmpty($Content)) {
        return , $warnings
    }

    $lines = $Content -split "`r?`n"
    $verdictRegex = '\b(verified|partial)\b'
    $lineSpanRegex = '\(Lines\s+\d+-\d+\)'
    $kindRegex = 'kind:\s*(file-presence|live-endpoint|external-doc)'
    $externalDocKindRegex = 'kind:\s*external-doc'
    # Glob-copy heuristic: path-style globs unlikely to appear in human-authored evidence rows.
    $globCopyRegex = '(\*\*/|/\*\.[a-zA-Z0-9]|\*\*\.[a-zA-Z0-9])'
    # Badge-image heuristic: SVG badge URLs used as inferred verification.
    $badgeImageRegex = '(?i)(/badge/|shields\.io|\.svg(\)|\s|$|\?))'

    $inTable = $false
    $verdictIdx = -1
    $evidenceIdx = -1
    $tableHeading = ''
    $rowIndex = 0
    $currentSection = ''

    for ($i = 0; $i -lt $lines.Length; $i++) {
        $line = $lines[$i]

        if ($line -match '^#{1,6}\s+(.+)$') {
            $currentSection = $matches[1].Trim()
            $inTable = $false
            continue
        }

        if ($line -notmatch '^\s*\|') {
            $inTable = $false
            continue
        }

        $rawCells = @($line -split '\|' | ForEach-Object { $_.Trim() })
        if ($rawCells.Length -ge 1 -and $rawCells[0] -eq '') {
            $rawCells = if ($rawCells.Length -gt 1) { $rawCells[1..($rawCells.Length - 1)] } else { @() }
        }
        if ($rawCells.Length -ge 1 -and $rawCells[-1] -eq '') {
            $rawCells = if ($rawCells.Length -gt 1) { $rawCells[0..($rawCells.Length - 2)] } else { @() }
        }

        if (-not $inTable) {
            $next = if ($i + 1 -lt $lines.Length) { $lines[$i + 1] } else { '' }
            if ($next -notmatch '^\s*\|[\s\-:|]+\|?\s*$') { continue }

            $verdictIdx = -1
            $evidenceIdx = -1
            for ($h = 0; $h -lt $rawCells.Length; $h++) {
                if ($rawCells[$h] -match '^(?i)verdict\b') { $verdictIdx = $h }
                if ($rawCells[$h] -match '^(?i)(evidence|source(\s+reference)?s?)\b') { $evidenceIdx = $h }
            }
            if ($verdictIdx -ge 0 -and $evidenceIdx -ge 0) {
                $inTable = $true
                $tableHeading = $currentSection
                $rowIndex = 0
                $i++
            }
            continue
        }

        $rowIndex++
        if ($verdictIdx -ge $rawCells.Length -or $evidenceIdx -ge $rawCells.Length) { continue }

        $verdictCell = $rawCells[$verdictIdx]
        $evidenceCell = $rawCells[$evidenceIdx]
        $verdictMatch = [regex]::Match($verdictCell, $verdictRegex, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
        if (-not $verdictMatch.Success) { continue }

        $hasLineSpan = $evidenceCell -match $lineSpanRegex
        $hasKindQualifier = $evidenceCell -match $kindRegex
        $isExternalDoc = $evidenceCell -match $externalDocKindRegex
        $hasGlobCopy = $evidenceCell -match $globCopyRegex
        $hasBadgeImage = $evidenceCell -match $badgeImageRegex

        $verdictValue = $verdictMatch.Groups[1].Value.ToLowerInvariant()
        $rowReasons = [System.Collections.Generic.List[string]]::new()

        # Pattern 2: glob-copy detection fires regardless of qualifier — copying evidenceHints[]
        # into the evidence cell defeats the citation requirement.
        if ($hasGlobCopy) {
            $rowReasons.Add("Evidence cell appears to copy evidenceHints glob verbatim (contains path-glob pattern)") | Out-Null
        }

        # Pattern 3: badge-image used as inferred verification on external-doc rows.
        if ($isExternalDoc -and $hasBadgeImage) {
            $rowReasons.Add("Evidence cell uses badge image as inferred verification on a kind: external-doc row") | Out-Null
        }

        # Pattern 1 (original): missing span and missing kind qualifier.
        if (-not $hasLineSpan -and -not $hasKindQualifier) {
            $rowReasons.Add("Evidence cell missing '(Lines N-M)' span and no 'kind:' qualifier") | Out-Null
        }

        if ($rowReasons.Count -eq 0) { continue }

        foreach ($reason in $rowReasons) {
            $warnings.Add(@{
                    file         = $FilePath
                    line         = $i + 1
                    tableHeading = $tableHeading
                    rowIndex     = $rowIndex
                    verdict      = $verdictValue
                    reason       = $reason
                })
        }
    }

    return , $warnings
}

function Find-EvidenceCitationViolations {
    <#
    .SYNOPSIS
    Walks planner-tracking roots for markdown files and aggregates evidence-citation warnings.

    .PARAMETER Roots
    Directory roots to scan recursively for *.md files.

    .PARAMETER OutputPath
    JSON results file path.

    .OUTPUTS
    [hashtable] @{ Warnings; TotalWarnings; OutputPath }.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Roots,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$OutputPath
    )

    $allWarnings = [System.Collections.Generic.List[hashtable]]::new()

    foreach ($root in $Roots) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        $files = Get-ChildItem -Path $root -Recurse -File -Filter '*.md' -ErrorAction SilentlyContinue
        foreach ($file in $files) {
            $content = Get-Content -LiteralPath $file.FullName -Raw -ErrorAction SilentlyContinue
            if ([string]::IsNullOrEmpty($content)) { continue }
            try {
                $relPath = (Resolve-Path -LiteralPath $file.FullName -Relative).Replace('\', '/')
                if ($relPath.StartsWith('./')) { $relPath = $relPath.Substring(2) }
            }
            catch {
                $relPath = $file.FullName
            }
            $fileWarnings = Find-EvidenceCitationViolationsInContent -Content $content -FilePath $relPath
            foreach ($w in $fileWarnings) { $allWarnings.Add($w) }
        }
    }

    $outDir = Split-Path -Parent -Path $OutputPath
    if ($outDir -and -not (Test-Path -LiteralPath $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    $payload = [ordered]@{
        timestamp     = (Get-Date -Format 'o')
        totalWarnings = $allWarnings.Count
        warnings      = @($allWarnings)
    }
    $payload | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $OutputPath -Encoding UTF8

    return @{
        Warnings      = @($allWarnings)
        TotalWarnings = $allWarnings.Count
        OutputPath    = $OutputPath
    }
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

        $loadingResult = $null
        if ($PSBoundParameters.ContainsKey('PlanRoot') -and -not [string]::IsNullOrWhiteSpace($PlanRoot)) {
            $loadingResult = Test-SkillLoadingContract `
                -PlanRoot $PlanRoot `
                -Scope $Scope `
                -OutputPath $LoadingViolationsOutputPath
        }

        $exitCode = 0
        if ($result.HasFailures) {
            Write-Error -ErrorAction Continue "AI artifact validation failed with $($result.TotalIssues) issue(s)."
            $exitCode = 1
        }
        if ($loadingResult -and $loadingResult.HasViolations) {
            Write-Error -ErrorAction Continue "Skill-loading contract validation failed with $($loadingResult.TotalViolations) violation(s)."
            $exitCode = 1
        }

        if ($EvidenceCitationCheck) {
            $evidenceResult = Find-EvidenceCitationViolations `
                -Roots $EvidenceCitationRoots `
                -OutputPath $EvidenceCitationOutputPath
            if ($evidenceResult.TotalWarnings -gt 0) {
                Write-Error -ErrorAction Continue "Evidence-citation check produced $($evidenceResult.TotalWarnings) violation(s); see $($evidenceResult.OutputPath)."
                $exitCode = 1
            }
        }

        exit $exitCode
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-PlannerArtifacts failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        exit 1
    }
}
#endregion Main Execution
