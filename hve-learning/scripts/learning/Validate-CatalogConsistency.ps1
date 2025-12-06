#!/usr/bin/env pwsh
#Requires -Modules PowerShell-Yaml

<#
.SYNOPSIS
    Validate consistency between generated READMEs and kata frontmatter.

.DESCRIPTION
    Checks that times, difficulty levels, titles, and descriptions in category READMEs
    match the source YAML frontmatter in kata files. Reports discrepancies.

.PARAMETER LearningRoot
    Root directory of learning content. Defaults to './learning'.

.EXAMPLE
    pwsh -File scripts/learning/Validate-CatalogConsistency.ps1

.NOTES
    Depends on PowerShell-Yaml module for YAML parsing.
#>

[CmdletBinding()]
param(
    [Parameter()]
    [string]$LearningRoot = "./learning"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Difficulty mapping
$Script:DIFFICULTY_MAP = @{
    1 = 'Foundation'
    2 = 'Skill'
    3 = 'Advanced'
    4 = 'Expert'
    5 = 'Legendary'
}

function Get-YamlFrontmatter {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return $null
    }

    $content = Get-Content -Path $FilePath -Raw
    if ($content -match '(?s)^---\s*\n(.*?)\n---') {
        try {
            $yamlContent = $matches[1]
            $frontmatter = ConvertFrom-Yaml -Yaml $yamlContent -Ordered

            # Extract difficulty from filename if not in frontmatter
            $filename = Split-Path $FilePath -Leaf
            if ($filename -match '^(\d+)-') {
                $prefix = [int]$matches[1]
                # Support both 'difficulty' and 'kata_difficulty' fields
                # Use ContainsKey for hashtable/dictionary property checks
                $hasDifficulty = $frontmatter.Contains('difficulty')
                $hasKataDifficulty = $frontmatter.Contains('kata_difficulty')

                if (-not $hasDifficulty -and -not $hasKataDifficulty) {
                    $frontmatter['difficulty'] = $prefix
                } elseif ($hasKataDifficulty) {
                    $frontmatter['difficulty'] = $frontmatter['kata_difficulty']
                }
            }

            return $frontmatter
        } catch {
            Write-Warning "Failed to parse YAML in $FilePath : $_"
            return $null
        }
    }
    return $null
}

function Test-CategoryReadme {
    param(
        [string]$CategoryPath,
        [array]$Katas
    )

    $issues = @()
    $readmePath = Join-Path $CategoryPath "README.md"

    if (-not (Test-Path $readmePath)) {
        Write-Warning "README not found: $readmePath"
        return $issues
    }

    $readmeContent = Get-Content -Path $readmePath -Raw

    foreach ($kata in $Katas) {
        $filename = Split-Path $kata.filePath -Leaf
        $kataName = [System.IO.Path]::GetFileNameWithoutExtension($filename)

        # Get frontmatter from actual file
        $frontmatter = Get-YamlFrontmatter -FilePath $kata.filePath

        if (-not $frontmatter) {
            $issues += @{
                File = $kata.filePath
                Issue = "Could not parse frontmatter"
                Severity = "Error"
            }
            continue
        }

        # Check if kata is mentioned in README
        if ($readmeContent -notmatch [regex]::Escape($kataName)) {
            $issues += @{
                File = $kata.filePath
                Issue = "Kata not found in README: $kataName"
                Severity = "Warning"
            }
            continue
        }

        # Try to extract kata from auto-generated table format first
        $kataNumber = if ($kataName -match '^(\d+)-') { $matches[1] } else { $null }
        $tableRowPattern = "\|\s*$kataNumber\s*\|[^\|]+\(\./$([regex]::Escape($kataName))\.md\)[^\|]*\|([^\|]+)\|([^\|]+)\|"

        $foundInTable = $false
        if ($kataNumber -and $readmeContent -match $tableRowPattern) {
            $foundInTable = $true
            $difficultyColumn = $matches[1].Trim()
            $timeColumn = $matches[2].Trim()

            # Check difficulty (convert symbols to text or vice versa)
            $expectedDifficulty = $Script:DIFFICULTY_MAP[[int]$frontmatter.difficulty]
            $expectedSymbols = "⭐" * [int]$frontmatter.difficulty

            if ($difficultyColumn -notmatch [regex]::Escape($expectedDifficulty) -and
                $difficultyColumn -notmatch [regex]::Escape($expectedSymbols)) {
                $issues += @{
                    File = $kata.filePath
                    Issue = "Difficulty mismatch in table. Expected: $expectedDifficulty or $expectedSymbols, Found: $difficultyColumn"
                    Severity = "Error"
                    Section = "Difficulty"
                }
            }

            # Check estimated time
            $expectedTime = $frontmatter.estimated_time_minutes
            if ($timeColumn -notmatch "$expectedTime\s*min") {
                $issues += @{
                    File = $kata.filePath
                    Issue = "Time mismatch in table. Expected: $expectedTime min, Found: $timeColumn"
                    Severity = "Error"
                    Section = "Time"
                }
            }

            # Check title (look for it in the link text)
            $expectedTitle = $frontmatter.title
            $titlePattern = "\|\s*$kataNumber\s*\|\s*\[[^\]]*$([regex]::Escape($expectedTitle))[^\]]*\]"
            if ($readmeContent -notmatch $titlePattern) {
                $issues += @{
                    File = $kata.filePath
                    Issue = "Title not found in table link. Expected: '$expectedTitle'"
                    Severity = "Warning"
                    Section = "Title"
                }
            }
        }

        # Fall back to section-based format (for manually maintained READMEs)
        if (-not $foundInTable) {
            $pattern = "(?s)##\s+\[?\**$([regex]::Escape($kataName))\**\]?.*?(?=\n##|\z)"
            if ($readmeContent -match $pattern) {
                $kataSection = $matches[0]

                # Check difficulty
                $expectedDifficulty = $Script:DIFFICULTY_MAP[[int]$frontmatter.difficulty]
                if ($kataSection -notmatch "\*\*Difficulty\*\*:\s*$([regex]::Escape($expectedDifficulty))") {
                    $issues += @{
                        File = $kata.filePath
                        Issue = "Difficulty mismatch. Expected: $expectedDifficulty (from frontmatter: $($frontmatter.difficulty))"
                        Severity = "Error"
                        Section = "Difficulty"
                    }
                }

                # Check estimated time
                $expectedTime = $frontmatter.estimated_time_minutes
                if ($kataSection -notmatch "\*\*Time\*\*:\s*~?$expectedTime\s*min") {
                    $issues += @{
                        File = $kata.filePath
                        Issue = "Time mismatch. Expected: $expectedTime minutes"
                        Severity = "Error"
                        Section = "Time"
                    }
                }

                # Check title (should be in heading or link text)
                $expectedTitle = $frontmatter.title
                if ($kataSection -notmatch [regex]::Escape($expectedTitle)) {
                    $issues += @{
                        File = $kata.filePath
                        Issue = "Title not found. Expected: '$expectedTitle'"
                        Severity = "Warning"
                        Section = "Title"
                    }
                }

                # Check description (if present in frontmatter)
                if ($frontmatter.description) {
                    $expectedDesc = $frontmatter.description
                    if ($kataSection -notmatch [regex]::Escape($expectedDesc.Substring(0, [Math]::Min(50, $expectedDesc.Length)))) {
                        $issues += @{
                            File = $kata.filePath
                            Issue = "Description mismatch or not found"
                            Severity = "Warning"
                            Section = "Description"
                        }
                    }
                }
            } else {
                $issues += @{
                    File = $kata.filePath
                    Issue = "Could not find kata section in README for: $kataName"
                    Severity = "Warning"
                }
            }
        }
    }

    return $issues
}

# Main validation logic
try {
    Write-Host "`n=== Validating Catalog Consistency ===`n" -ForegroundColor Cyan

    $katasDir = Join-Path $LearningRoot "katas"
    $categories = Get-ChildItem -Path $katasDir -Directory

    $allIssues = @()

    foreach ($category in $categories) {
        Write-Host "Checking category: $($category.Name)" -ForegroundColor Yellow

        $kataFiles = Get-ChildItem -Path $category.FullName -Filter "*.md" |
            Where-Object { $_.Name -ne "README.md" }

        $katas = @()
        foreach ($file in $kataFiles) {
            $katas += @{
                filePath = $file.FullName
                category = $category.Name
            }
        }

        $categoryIssues = @(Test-CategoryReadme -CategoryPath $category.FullName -Katas $katas)

        if ($categoryIssues.Count -gt 0) {
            $allIssues += $categoryIssues
            Write-Host "  Found $($categoryIssues.Count) issue(s)" -ForegroundColor Red
        } else {
            Write-Host "  ✓ No issues found" -ForegroundColor Green
        }
    }

    # Summary report
    Write-Host "`n=== Summary ===" -ForegroundColor Cyan
    Write-Host "Total categories checked: $($categories.Count)"
    Write-Host "Total issues found: $($allIssues.Count)"

    if ($allIssues.Count -gt 0) {
        Write-Host "`n=== Detailed Issues ===" -ForegroundColor Cyan

        $groupedIssues = $allIssues | Group-Object -Property { $_.File }

        foreach ($group in $groupedIssues) {
            Write-Host "`nFile: $($group.Name)" -ForegroundColor Yellow
            foreach ($issue in $group.Group) {
                $color = if ($issue.Severity -eq "Error") { "Red" } else { "Yellow" }
                Write-Host "  [$($issue.Severity)] $($issue.Issue)" -ForegroundColor $color
            }
        }

        # Exit with error code if there are errors
        $errors = @($allIssues | Where-Object { $_.Severity -eq "Error" })
        $errorCount = $errors.Count
        if ($errorCount -gt 0) {
            Write-Host "`n$errorCount ERROR(S) must be fixed!" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "`n✓ All checks passed!" -ForegroundColor Green
    }

} catch {
    Write-Error "Validation failed: $($_.Exception.Message)"
    exit 1
}
