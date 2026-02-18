# Copyright (c) Microsoft Corporation.
# SPDX-License-Identifier: MIT

# Validate-SkillStructure.ps1
#
# Purpose: Validates the structural integrity of skill directories under .github/skills/
# Author: HVE Core Team

#Requires -Version 7.0

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [string]$SkillsPath = '.github/skills',

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = 'origin/main'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath '../lib/Modules/CIHelpers.psm1') -Force

# Recognized subdirectories within a skill directory
$script:RecognizedSubdirectories = @('scripts', 'references', 'assets', 'examples')

function Get-SkillFrontmatter {
    <#
    .SYNOPSIS
    Parses YAML frontmatter from a SKILL.md file.

    .DESCRIPTION
    Extracts single-line key-value pairs between --- delimiters using regex.
    Does not support multiline YAML scalars. Does not depend on the
    PowerShell-Yaml module.

    .PARAMETER Path
    Absolute path to the SKILL.md file.

    .OUTPUTS
    [hashtable] Parsed frontmatter key-value pairs, or $null if no frontmatter found.

    .EXAMPLE
    $fm = Get-SkillFrontmatter -Path '/repo/.github/skills/my-skill/SKILL.md'
    $fm['name']  # 'my-skill'
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    $content = Get-Content -Path $Path -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) {
        return $null
    }

    # Match frontmatter block between --- delimiters
    if ($content -notmatch '(?s)^---\r?\n(.+?)\r?\n---') {
        return $null
    }

    $frontmatterBlock = $Matches[1]
    $result = @{}

    # Split into lines and parse key-value pairs
    $lines = $frontmatterBlock -split '\r?\n'
    foreach ($line in $lines) {
        # Match key: value or key: 'value with spaces'
        if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_-]*)\s*:\s*(.*)$') {
            $key = $Matches[1].Trim()
            $value = $Matches[2].Trim()

            # Strip surrounding single or double quotes
            if (($value.StartsWith("'") -and $value.EndsWith("'")) -or
                ($value.StartsWith('"') -and $value.EndsWith('"'))) {
                $value = $value.Substring(1, $value.Length - 2)
            }

            $result[$key] = $value
        }
    }

    if ($result.Count -eq 0) {
        return $null
    }

    return $result
}

function Test-SkillDirectory {
    <#
    .SYNOPSIS
    Validates a single skill directory for structural compliance.

    .DESCRIPTION
    Checks that a skill directory contains a SKILL.md with valid frontmatter,
    required fields, name consistency, and recognized subdirectories.

    .PARAMETER Directory
    DirectoryInfo object for the skill directory to validate.

    .PARAMETER RepoRoot
    Repository root path for computing relative paths.

    .OUTPUTS
    [PSCustomObject] Validation result with SkillName, SkillPath, IsValid, Errors, and Warnings.

    .EXAMPLE
    $dir = Get-Item '.github/skills/video-to-gif'
    $result = Test-SkillDirectory -Directory $dir -RepoRoot '/repo'
    #>
    [CmdletBinding()]
    [OutputType([PSCustomObject])]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.DirectoryInfo]$Directory,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $errors = [System.Collections.Generic.List[string]]::new()
    $warnings = [System.Collections.Generic.List[string]]::new()
    $skillName = $Directory.Name
    $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $Directory.FullName) -replace '\\', '/'

    # Check SKILL.md exists
    $skillMdPath = Join-Path -Path $Directory.FullName -ChildPath 'SKILL.md'
    if (-not (Test-Path $skillMdPath)) {
        $errors.Add("SKILL.md is missing from '$relativePath'")
        return [PSCustomObject]@{
            SkillName = $skillName
            SkillPath = $relativePath
            IsValid   = $false
            Errors    = [string[]]$errors.ToArray()
            Warnings  = [string[]]$warnings.ToArray()
        }
    }

    # Parse frontmatter
    $frontmatter = Get-SkillFrontmatter -Path $skillMdPath
    if ($null -eq $frontmatter) {
        $errors.Add("SKILL.md has missing or malformed frontmatter in '$relativePath'")
        return [PSCustomObject]@{
            SkillName = $skillName
            SkillPath = $relativePath
            IsValid   = $false
            Errors    = [string[]]$errors.ToArray()
            Warnings  = [string[]]$warnings.ToArray()
        }
    }

    # Required frontmatter fields
    if (-not $frontmatter.ContainsKey('name') -or [string]::IsNullOrWhiteSpace($frontmatter['name'])) {
        $errors.Add("SKILL.md frontmatter missing required 'name' field in '$relativePath'")
    }

    if (-not $frontmatter.ContainsKey('description') -or [string]::IsNullOrWhiteSpace($frontmatter['description'])) {
        $errors.Add("SKILL.md frontmatter missing required 'description' field in '$relativePath'")
    }

    # Name must match directory name
    if ($frontmatter.ContainsKey('name') -and -not [string]::IsNullOrWhiteSpace($frontmatter['name'])) {
        if ($frontmatter['name'] -ne $skillName) {
            $errors.Add("Frontmatter 'name' value '$($frontmatter['name'])' does not match directory name '$skillName'")
        }
    }

    # Check scripts/ subdirectory contents (optional dir, but must contain both .ps1 and .sh if present)
    $scriptsDirPath = Join-Path -Path $Directory.FullName -ChildPath 'scripts'
    if (Test-Path $scriptsDirPath -PathType Container) {
        $scriptFiles = Get-ChildItem -Path $scriptsDirPath -File -ErrorAction SilentlyContinue |
            Where-Object { $_.Extension -in @('.ps1', '.sh') }
        $hasPowerShell = @($scriptFiles | Where-Object { $_.Extension -eq '.ps1' }).Count -gt 0
        $hasBash = @($scriptFiles | Where-Object { $_.Extension -eq '.sh' }).Count -gt 0

        if (-not $hasPowerShell -and -not $hasBash) {
            $errors.Add("'scripts/' subdirectory exists but contains no .ps1 or .sh files in '$relativePath'")
        }
        elseif (-not $hasPowerShell) {
            $errors.Add("'scripts/' subdirectory is missing a required .ps1 file in '$relativePath'")
        }
        elseif (-not $hasBash) {
            $errors.Add("'scripts/' subdirectory is missing a required .sh file in '$relativePath'")
        }
    }

    # Check for unrecognized subdirectories
    $subdirs = Get-ChildItem -Path $Directory.FullName -Directory -ErrorAction SilentlyContinue
    foreach ($subdir in $subdirs) {
        if ($subdir.Name -notin $script:RecognizedSubdirectories) {
            $warnings.Add("Unrecognized subdirectory '$($subdir.Name)' in '$relativePath' (recognized: $($script:RecognizedSubdirectories -join ', '))")
        }
    }

    $isValid = $errors.Count -eq 0

    return [PSCustomObject]@{
        SkillName = $skillName
        SkillPath = $relativePath
        IsValid   = $isValid
        Errors    = [string[]]$errors.ToArray()
        Warnings  = [string[]]$warnings.ToArray()
    }
}

function Get-ChangedSkillDirectories {
    <#
    .SYNOPSIS
    Returns skill directory names that contain changed files.

    .DESCRIPTION
    Uses Get-ChangedFilesFromGit (LintingHelpers) to identify changed files
    under the skills path with merge-base, HEAD~1, and staged/unstaged
    fallbacks, then extracts unique skill directory names.

    .PARAMETER BaseBranch
    Git reference for the base branch comparison. Default: 'origin/main'.

    .PARAMETER SkillsPath
    Relative path to the skills directory. Default: '.github/skills'.

    .OUTPUTS
    [string[]] Unique skill directory names with changes.

    .EXAMPLE
    $changed = Get-ChangedSkillDirectories -BaseBranch 'origin/main'
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseBranch = 'origin/main',

        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$SkillsPath = '.github/skills'
    )

    $changedFiles = @(Get-ChangedFilesFromGit -BaseBranch $BaseBranch -FileExtensions @('*'))

    # Normalize skills path for matching
    $normalizedSkillsPath = $SkillsPath -replace '\\', '/'
    if (-not $normalizedSkillsPath.EndsWith('/')) {
        $normalizedSkillsPath += '/'
    }

    $skillNames = @($changedFiles |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        ForEach-Object { $_ -replace '\\', '/' } |
        Where-Object { $_.StartsWith($normalizedSkillsPath) } |
        ForEach-Object {
            $remainder = $_.Substring($normalizedSkillsPath.Length)
            $parts = $remainder -split '/'
            if ($parts.Count -gt 0) { $parts[0] }
        } |
        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
        Sort-Object -Unique)

    return $skillNames
}

function Write-SkillValidationResults {
    <#
    .SYNOPSIS
    Outputs skill validation results to console and writes JSON to logs.

    .DESCRIPTION
    Displays per-skill pass/fail status with colored output, emits CI annotations
    when running in a CI environment, and exports results as JSON.

    .PARAMETER Results
    Array of validation result objects from Test-SkillDirectory.

    .PARAMETER RepoRoot
    Repository root path for resolving the logs directory.

    .EXAMPLE
    Write-SkillValidationResults -Results $results -RepoRoot '/repo'
    #>
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [PSCustomObject[]]$Results,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoRoot
    )

    $isCI = Test-CIEnvironment

    Write-Host "`nSkill Structure Validation Results" -ForegroundColor Cyan
    Write-Host ("-" * 40) -ForegroundColor Cyan

    foreach ($result in $Results) {
        if ($result.IsValid -and $result.Warnings.Count -eq 0) {
            Write-Host "  ✅ $($result.SkillName)" -ForegroundColor Green
        }
        elseif ($result.IsValid) {
            Write-Host "  ⚠️  $($result.SkillName) (warnings)" -ForegroundColor Yellow
        }
        else {
            Write-Host "  ❌ $($result.SkillName)" -ForegroundColor Red
        }

        foreach ($err in $result.Errors) {
            Write-Host "     ERROR: $err" -ForegroundColor Red
            if ($isCI) {
                $skillMdRelative = "$($result.SkillPath)/SKILL.md"
                Write-CIAnnotation -Message $err -Level Error -File $skillMdRelative
            }
        }
        foreach ($warn in $result.Warnings) {
            Write-Host "     WARNING: $warn" -ForegroundColor Yellow
            if ($isCI) {
                $skillMdRelative = "$($result.SkillPath)/SKILL.md"
                Write-CIAnnotation -Message $warn -Level Warning -File $skillMdRelative
            }
        }
    }

    # Summary
    $totalSkills = $Results.Count
    $errorCount = @($Results | Where-Object { -not $_.IsValid }).Count
    $warningCount = @($Results | Where-Object { $_.Warnings.Count -gt 0 }).Count

    Write-Host "`n📋 Summary:" -ForegroundColor Cyan
    Write-Host "   Total skills:    $totalSkills" -ForegroundColor Gray
    Write-Host "   With errors:     $errorCount" -ForegroundColor $(if ($errorCount -gt 0) { 'Red' } else { 'Green' })
    Write-Host "   With warnings:   $warningCount" -ForegroundColor $(if ($warningCount -gt 0) { 'Yellow' } else { 'Green' })

    # Write JSON results
    $logsDir = Join-Path -Path $RepoRoot -ChildPath 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $jsonOutput = @{
        timestamp    = (Get-Date -Format 'o')
        totalSkills  = $totalSkills
        skillErrors  = $errorCount
        skillWarnings = $warningCount
        results      = @($Results | ForEach-Object {
            @{
                skillName = $_.SkillName
                skillPath = $_.SkillPath
                isValid   = $_.IsValid
                errors    = @($_.Errors)
                warnings  = @($_.Warnings)
            }
        })
    }

    $outputPath = Join-Path -Path $logsDir -ChildPath 'skill-validation-results.json'
    $jsonOutput | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding UTF8
    Write-Host "📊 Results written to: $outputPath" -ForegroundColor Cyan
}

function Invoke-SkillStructureValidation {
    <#
    .SYNOPSIS
    Orchestrates skill structure validation and returns an exit code.

    .DESCRIPTION
    Resolves the repository root, discovers skill directories (optionally
    filtered to changed files), validates each one, writes results, and
    returns an integer exit code. Extracted from the main execution block
    for testability.

    .PARAMETER SkillsPath
    Relative path to the skills directory from the repo root.

    .PARAMETER WarningsAsErrors
    Treat warnings as errors for exit code calculation.

    .PARAMETER ChangedFilesOnly
    Validate only skill directories containing changed files.

    .PARAMETER BaseBranch
    Git reference for the base branch comparison when using ChangedFilesOnly.

    .OUTPUTS
    [int] Exit code: 0 for success, 1 for failure.

    .EXAMPLE
    $exitCode = Invoke-SkillStructureValidation -SkillsPath '.github/skills'
    #>
    [CmdletBinding()]
    [OutputType([int])]
    param(
        [Parameter(Mandatory = $false)]
        [string]$SkillsPath = '.github/skills',

        [Parameter(Mandatory = $false)]
        [switch]$WarningsAsErrors,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = 'origin/main'
    )

    try {
        # Resolve repo root
        $repoRoot = git rev-parse --show-toplevel 2>$null
        if (-not $repoRoot -or $LASTEXITCODE -ne 0) {
            $repoRoot = (Get-Location).Path
        }

        $fullSkillsPath = Join-Path -Path $repoRoot -ChildPath $SkillsPath

        if ($ChangedFilesOnly) {
            Write-Host "🔍 Detecting changed skill directories..." -ForegroundColor Cyan
            $changedSkills = Get-ChangedSkillDirectories -BaseBranch $BaseBranch -SkillsPath $SkillsPath

            if (@($changedSkills).Count -eq 0) {
                Write-Host "✅ No changed skill directories found - validation complete" -ForegroundColor Green
                return 0
            }
        }

        if ($ChangedFilesOnly) {
            Write-Host "Found $($changedSkills.Count) changed skill(s) to validate" -ForegroundColor Cyan

            $results = @()
            foreach ($skillName in $changedSkills) {
                $skillDirPath = Join-Path -Path $fullSkillsPath -ChildPath $skillName
                if (Test-Path $skillDirPath -PathType Container) {
                    $dirInfo = Get-Item $skillDirPath
                    $results += Test-SkillDirectory -Directory $dirInfo -RepoRoot $repoRoot
                }
                else {
                    Write-Host "  ⏭️  Skill '$skillName' was deleted - skipping validation" -ForegroundColor DarkGray
                }
            }

            if ($results.Count -eq 0) {
                Write-Host "✅ No skill directories to validate after filtering - success" -ForegroundColor Green
                return 0
            }
        }
        else {
            if (-not (Test-Path $fullSkillsPath -PathType Container)) {
                Write-Host "Skills directory not found at '$SkillsPath' - nothing to validate" -ForegroundColor Yellow
                return 0
            }

            $skillDirs = Get-ChildItem -Path $fullSkillsPath -Directory -ErrorAction SilentlyContinue
            if ($null -eq $skillDirs -or @($skillDirs).Count -eq 0) {
                Write-Host "No skill directories found under '$SkillsPath' - nothing to validate" -ForegroundColor Yellow
                return 0
            }

            Write-Host "🔍 Validating $(@($skillDirs).Count) skill directory(ies)..." -ForegroundColor Cyan

            $results = @()
            foreach ($dir in $skillDirs) {
                $results += Test-SkillDirectory -Directory $dir -RepoRoot $repoRoot
            }
        }

        Write-SkillValidationResults -Results $results -RepoRoot $repoRoot

        # Calculate exit code
        $hasErrors = @($results | Where-Object { -not $_.IsValid }).Count -gt 0
        $hasWarnings = @($results | Where-Object { $_.Warnings.Count -gt 0 }).Count -gt 0

        if ($hasErrors) {
            return 1
        }
        elseif ($WarningsAsErrors -and $hasWarnings) {
            return 1
        }
        else {
            Write-Host "✅ Skill structure validation complete" -ForegroundColor Green
            return 0
        }
    }
    catch {
        Write-Error -ErrorAction Continue "Validate-SkillStructure failed: $($_.Exception.Message)"
        Write-CIAnnotation -Message $_.Exception.Message -Level Error
        return 1
    }
}

#region Main Execution
if ($MyInvocation.InvocationName -ne '.') {
    $exitCode = Invoke-SkillStructureValidation `
        -SkillsPath $SkillsPath `
        -WarningsAsErrors:$WarningsAsErrors `
        -ChangedFilesOnly:$ChangedFilesOnly `
        -BaseBranch $BaseBranch
    exit $exitCode
}
#endregion Main Execution
