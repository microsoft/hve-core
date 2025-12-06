#!/usr/bin/env pwsh
#Requires -Modules PowerShell-Yaml

<#
.SYNOPSIS
    Generate learning catalog markdown files with auto-generated headers and multi-category support.

.DESCRIPTION
    Scans learning content directories (katas, paths, training-labs), parses YAML frontmatter,
    and generates catalog.md plus 13 README files. Implements multi-category support via tags field.

    Uses prefix-based difficulty system:
    - 01-: Beginner (15-40 minutes) - Heavy scaffolding with explicit guidance
    - 02-: Advanced (30-60 minutes) - Medium-heavy scaffolding with structured frameworks
    - 03-: Expert (45-90 minutes) - Light scaffolding with decision frameworks
    - 04-: Legendary (60-120 minutes) - Minimal scaffolding, capstone challenges

.PARAMETER LearningRoot
    Root directory of learning content. Defaults to './learning'.

.EXAMPLE
    pwsh -File scripts/learning/Generate-LearningCatalog.ps1

.EXAMPLE
    pwsh -File scripts/learning/Generate-LearningCatalog.ps1 -LearningRoot "C:\Projects\hve-learning\learning"

.NOTES
    Author: Auto-generated from PowerShell conversion plan
    Dependencies: PowerShell-Yaml module
#>

[CmdletBinding(SupportsShouldProcess=$true)]
param(
    [Parameter()]
    [string]$LearningRoot = "./learning"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Constants

# Valid difficulty levels for content validation
$Script:VALID_DIFFICULTIES = @('Foundation', 'Skill', 'Advanced', 'Expert', 'Legendary')

# Path whitelist - Only include signature learning paths
$Script:SIGNATURE_PATHS = @(
    'foundation-ai-first-engineering.md',
    'intermediate-devops-excellence.md',
    'intermediate-infrastructure-architect.md',
    'expert-data-analytics-integration.md',
    'expert-enterprise-integration.md'
)

#endregion

#region YAML Parsing Functions

<#
.SYNOPSIS
    Parse YAML frontmatter from a markdown file.

.DESCRIPTION
    Extracts and parses YAML frontmatter block from markdown files.
    Handles both prefixed fields (kata_*, path_*, lab_*) and unprefixed names.
    Normalizes arrays and ensures consistent data structure.
    Extracts difficulty from filename prefix (01-04) if not in frontmatter.

.PARAMETER FilePath
    Path to the markdown file to parse.

.OUTPUTS
    PSCustomObject with normalized frontmatter fields including:
    - kata_id, path_id, lab_id: Identifiers
    - title: Content title
    - difficulty: Numeric difficulty level (1-4)
    - estimated_time_minutes: Duration estimate
    - prerequisite_katas: Array of prerequisite IDs
    - technologies: Array of technology tags
    - tags: Array of category tags
    - description: Content description

    Returns $null on error.

.EXAMPLE
    $metadata = Get-YamlFrontmatter -FilePath "learning/katas/example/01-kata.md"

.NOTES
    Supports course-level difficulty extraction: 100-199=Beginner, 200-299=Advanced, 300-399=Expert, 400-499=Legendary
    Also supports legacy prefix system: 01-=Beginner, 02-=Advanced, 03-=Expert, 04-=Legendary (during migration)
#>
function Get-YamlFrontmatter {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    try {
        $content = Get-Content -Path $FilePath -Raw

        # Extract YAML between --- markers
        if ($content -match '(?s)^---\s*\n(.*?)\n---') {
            $yamlContent = $matches[1]
            $data = ConvertFrom-Yaml -Yaml $yamlContent

            # Extract common fields across katas, paths, labs with null-safe access
            # ConvertFrom-Yaml returns a Hashtable, so use ContainsKey instead of PSObject.Properties
            $titleValue = if ($data.ContainsKey('title')) { $data.title } `
                elseif ($data.ContainsKey('lab_title')) { $data.lab_title } else { '' }

            # Extract difficulty as string directly from frontmatter
            $difficultyValue = if ($data.ContainsKey('difficulty')) {
                # Use difficulty field directly (should be string like "Foundation", "Skill", etc.)
                $data.difficulty
            } elseif ($data.ContainsKey('kata_difficulty')) {
                # Legacy numeric support during migration
                $numDiff = $data.kata_difficulty
                switch ($numDiff) {
                    1 { 'Foundation' }
                    2 { 'Skill' }
                    3 { 'Advanced' }
                    4 { 'Expert' }
                    5 { 'Legendary' }
                    default { '' }
                }
            } else { '' }

            # If still no difficulty, try to extract from filename prefix (100-400 course-level or legacy 01-04)
            if (-not $difficultyValue) {
                $filename = Split-Path -Leaf $FilePath
                if ($filename -match '^(\d{2,3})-') {
                    $prefixStr = $Matches[1]
                    if ($prefixStr.Length -eq 2) {
                        # Legacy 01-04 format
                        $prefix = [int]$prefixStr
                        switch ($prefix) {
                            1 { $difficultyValue = 'Foundation' }
                            2 { $difficultyValue = 'Skill' }
                            3 { $difficultyValue = 'Advanced' }
                            4 { $difficultyValue = 'Expert' }
                        }
                    } else {
                        # New 100-400 course-level format
                        $prefixNum = [int]$prefixStr
                        if ($prefixNum -ge 100 -and $prefixNum -lt 200) { $difficultyValue = 'Foundation' }
                        elseif ($prefixNum -ge 200 -and $prefixNum -lt 300) { $difficultyValue = 'Skill' }
                        elseif ($prefixNum -ge 300 -and $prefixNum -lt 400) { $difficultyValue = 'Advanced' }
                        elseif ($prefixNum -ge 400 -and $prefixNum -lt 500) { $difficultyValue = 'Expert' }
                        elseif ($prefixNum -ge 500 -and $prefixNum -lt 600) { $difficultyValue = 'Legendary' }
                    }
                }
            }

            # Normalize tags to always be an array (single item becomes string in YAML)
            $tagsValue = if ($data.ContainsKey('tags')) {
                if ($data.tags -is [string]) { @($data.tags) } else { $data.tags }
            } else { @() }

            # Normalize technologies to always be an array
            $techValue = if ($data.ContainsKey('technologies')) {
                if ($data.technologies -is [string]) { @($data.technologies) } else { $data.technologies }
            } else { @() }

            # Normalize prerequisite_katas to always be an array
            $prereqsValue = if ($data.ContainsKey('prerequisite_katas')) {
                if ($data.prerequisite_katas -is [string]) { @($data.prerequisite_katas) } else { $data.prerequisite_katas }
            } else { @() }

            # Extract scaffolding_level and normalize to title case
            $scaffoldingValue = if ($data.ContainsKey('scaffolding_level')) {
                $rawScaffolding = $data.scaffolding_level
                # Normalize to title case: heavy -> Heavy, medium-heavy -> Medium-Heavy, etc.
                if ($rawScaffolding -match '-') {
                    # Handle hyphenated values like "medium-heavy"
                    ($rawScaffolding -split '-' | ForEach-Object { (Get-Culture).TextInfo.ToTitleCase($_.ToLower()) }) -join '-'
                } else {
                    (Get-Culture).TextInfo.ToTitleCase($rawScaffolding.ToLower())
                }
            } else { '' }

            return [PSCustomObject]@{
                kata_id = if ($data.ContainsKey('kata_id')) { $data.kata_id } else { '' }
                path_id = if ($data.ContainsKey('path_id')) { $data.path_id } else { '' }
                lab_id = if ($data.ContainsKey('lab_id')) { $data.lab_id } else { '' }
                title = $titleValue
                difficulty = $difficultyValue
                estimated_time_minutes = if ($data.ContainsKey('estimated_time_minutes')) { $data.estimated_time_minutes } else { 0 }
                prerequisite_katas = $prereqsValue
                technologies = $techValue
                tags = $tagsValue
                description = if ($data.ContainsKey('description')) { $data.description } else { '' }
                scaffolding_level = $scaffoldingValue
            }
        } else {
            Write-Error "No YAML frontmatter found in $FilePath"
            return $null
        }
    } catch {
        Write-Error "Error parsing YAML frontmatter in ${FilePath}: $($_.Exception.Message)"
        return $null
    }
}

#endregion

#region Directory Scanning Functions

<#
.SYNOPSIS
    Scan katas directory for kata markdown files.

.DESCRIPTION
    Recursively scans the katas directory structure, extracts frontmatter
    from all kata markdown files (excluding README.md), and returns metadata.
    Processes all subdirectories as category folders.

.PARAMETER BasePath
    Root path of katas directory to scan.

.OUTPUTS
    Array of PSCustomObjects with kata metadata and file paths.
    Each object includes: filePath, category, kata_id, title, difficulty,
    estimated_time_minutes, prerequisite_katas, technologies, tags, description.

.EXAMPLE
    $katas = Get-KataItem -BasePath "./learning/katas"

.NOTES
    Uses Write-Verbose for progress logging.
#>
function Get-KataItem {
    param(
        [Parameter(Mandatory)]
        [string]$BasePath
    )

    Write-Verbose "Scanning $BasePath..."
    $items = @()

    $categories = Get-ChildItem -Path $BasePath -Directory

    foreach ($category in $categories) {
        $mdFiles = Get-ChildItem -Path $category.FullName -Filter "*.md" |
            Where-Object { $_.Name -ne "README.md" }

        foreach ($file in $mdFiles) {
            $frontmatter = Get-YamlFrontmatter -FilePath $file.FullName

            if ($frontmatter) {
                $item = [PSCustomObject]@{
                    filePath = $file.FullName
                    category = $category.Name
                    kata_id = if ($frontmatter.kata_id) { $frontmatter.kata_id } else { '' }
                    path_id = if ($frontmatter.path_id) { $frontmatter.path_id } else { '' }
                    lab_id = if ($frontmatter.lab_id) { $frontmatter.lab_id } else { '' }
                    title = if ($frontmatter.title) { $frontmatter.title } else { '' }
                    difficulty = if ($frontmatter.difficulty) { $frontmatter.difficulty } else { 0 }
                    estimated_time_minutes = if ($frontmatter.estimated_time_minutes) { $frontmatter.estimated_time_minutes } else { 0 }
                    prerequisite_katas = @($frontmatter.prerequisite_katas)
                    technologies = @($frontmatter.technologies)
                    tags = @($frontmatter.tags)
                    description = if ($frontmatter.description) { $frontmatter.description } else { '' }
                    scaffolding_level = if ($frontmatter.scaffolding_level) { $frontmatter.scaffolding_level } else { '' }
                }
                $items += $item
            }
        }
    }

    Write-Verbose "Found $($items.Count) katas"
    return $items
}

<#
.SYNOPSIS
    Scan paths directory for signature learning path markdown files.

.DESCRIPTION
    Scans the paths directory, extracts frontmatter from path markdown files,
    filters based on signature paths configuration, and returns metadata.
    Non-signature paths are excluded from the output.

.PARAMETER BasePath
    Root path of paths directory to scan.

.PARAMETER SignaturePaths
    Array of filenames considered signature paths to include in the output.

.OUTPUTS
    Array of PSCustomObjects with path metadata (filtered to signature paths only).
    Each object includes: filePath, type, path_id, title, difficulty,
    estimated_time_minutes, prerequisite_katas, technologies, tags, description.

.EXAMPLE
    $paths = Get-PathItem -BasePath "./learning/paths" -SignaturePaths $Script:SIGNATURE_PATHS

.NOTES
    Uses Write-Verbose to log included and excluded paths.
#>
function Get-PathItem {
    param(
        [Parameter(Mandatory)]
        [string]$BasePath,
        [Parameter(Mandatory)]
        [string[]]$SignaturePaths
    )

    Write-Verbose "Scanning $BasePath..."
    $items = @()

    $allPaths = @(Get-ChildItem -Path $BasePath -Filter "*.md" |
        Where-Object { $_.Name -ne "README.md" })

    # Filter to include only signature paths (use different variable name to avoid collision with parameter)
    $filteredPaths = @($allPaths | Where-Object { $_.Name -in $SignaturePaths })
    $excluded = @($allPaths | Where-Object { $_.Name -notin $SignaturePaths })

    Write-Verbose "Including $($filteredPaths.Count) signature paths"
    if ($excluded.Count -gt 0) {
        Write-Verbose "Excluding $($excluded.Count) paths: $($excluded.Name -join ', ')"
    }

    foreach ($file in $filteredPaths) {
        $frontmatter = Get-YamlFrontmatter -FilePath $file.FullName

        if ($frontmatter) {
            $item = [PSCustomObject]@{
                filePath = $file.FullName
                type = 'path'
                kata_id = if ($frontmatter.kata_id) { $frontmatter.kata_id } else { '' }
                path_id = if ($frontmatter.path_id) { $frontmatter.path_id } else { '' }
                lab_id = if ($frontmatter.lab_id) { $frontmatter.lab_id } else { '' }
                title = if ($frontmatter.title) { $frontmatter.title } else { '' }
                difficulty = if ($frontmatter.difficulty) { $frontmatter.difficulty } else { 0 }
                estimated_time_minutes = if ($frontmatter.estimated_time_minutes) { $frontmatter.estimated_time_minutes } else { 0 }
                prerequisite_katas = if ($frontmatter.prerequisite_katas) { $frontmatter.prerequisite_katas } else { @() }
                technologies = if ($frontmatter.technologies) { $frontmatter.technologies } else { @() }
                tags = if ($frontmatter.tags) { $frontmatter.tags } else { @() }
                description = if ($frontmatter.description) { $frontmatter.description } else { '' }
            }
            $items += $item
        }
    }

    Write-Verbose "Found $($items.Count) learning paths"
    return $items
}

<#
.SYNOPSIS
    Scan training-labs directory for lab markdown files.

.DESCRIPTION
    Scans the training-labs directory structure, extracts frontmatter
    from lab markdown files (excluding README.md), and returns metadata.

.PARAMETER BasePath
    Root path of training-labs directory to scan.

.OUTPUTS
    Array of PSCustomObjects with lab metadata and file paths.
    Each object includes: filePath, type, lab_id, title, difficulty,
    estimated_time_minutes, prerequisite_katas, technologies, tags, description.

.EXAMPLE
    $labs = Get-LabItem -BasePath "./learning/training-labs"

.NOTES
    Uses Write-Verbose for progress logging.
#>
function Get-LabItem {
    param(
        [Parameter(Mandatory)]
        [string]$BasePath
    )

    Write-Verbose "Scanning $BasePath..."
    $items = @()

    $mdFiles = Get-ChildItem -Path $BasePath -Filter "*.md" |
        Where-Object { $_.Name -ne "README.md" }

    foreach ($file in $mdFiles) {
        $frontmatter = Get-YamlFrontmatter -FilePath $file.FullName

        if ($frontmatter) {
            $item = [PSCustomObject]@{
                filePath = $file.FullName
                type = 'lab'
                kata_id = if ($frontmatter.kata_id) { $frontmatter.kata_id } else { '' }
                path_id = if ($frontmatter.path_id) { $frontmatter.path_id } else { '' }
                lab_id = if ($frontmatter.lab_id) { $frontmatter.lab_id } else { '' }
                title = if ($frontmatter.title) { $frontmatter.title } else { '' }
                difficulty = if ($frontmatter.difficulty) { $frontmatter.difficulty } else { 0 }
                estimated_time_minutes = if ($frontmatter.estimated_time_minutes) { $frontmatter.estimated_time_minutes } else { 0 }
                prerequisite_katas = if ($frontmatter.prerequisite_katas) { $frontmatter.prerequisite_katas } else { @() }
                technologies = if ($frontmatter.technologies) { $frontmatter.technologies } else { @() }
                tags = if ($frontmatter.tags) { $frontmatter.tags } else { @() }
                description = if ($frontmatter.description) { $frontmatter.description } else { '' }
            }
            $items += $item
        }
    }

    Write-Verbose "Found $($items.Count) training labs"
    return $items
}

#endregion

#region Markdown Generation Functions

<#
.SYNOPSIS
    Generate auto-generated file header with timestamp.

.DESCRIPTION
    Creates a standardized markdown comment header indicating the file
    is auto-generated and should not be manually edited. Includes UTC timestamp.

.OUTPUTS
    String containing auto-generated header markdown with ISO 8601 timestamp.

.EXAMPLE
    $header = Get-AutoGenHeader
    # Returns:
    # <!-- AUTO-GENERATED - DO NOT EDIT MANUALLY -->
    # <!-- Generated by: scripts/learning/Generate-LearningCatalog.ps1 -->
    # <!-- Last updated: 2025-10-19T19:43:02Z -->
#>
function Get-AutoGenHeader {
    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
    return @"
<!-- AUTO-GENERATED - DO NOT EDIT MANUALLY -->
<!-- Generated by: scripts/learning/Generate-LearningCatalog.ps1 -->
<!-- Last updated: $timestamp -->

"@
}

<#
.SYNOPSIS
    Generate a single catalog entry in markdown task list format.

.DESCRIPTION
    Formats a kata, path, or lab item as a markdown task list entry with
    difficulty, duration, description, prerequisites, and technologies.

.PARAMETER Item
    PSCustomObject with item metadata (from Get-KataItem, Get-PathItem, or Get-LabItem).

.PARAMETER RelativePath
    Relative path to the item file from learning root.

.OUTPUTS
    String containing catalog entry as markdown task list item.

.EXAMPLE
    $entry = Format-CatalogEntry -Item $kata -RelativePath "learning/katas/category/01-kata.md"

.NOTES
    Uses string difficulty values directly from content frontmatter.
#>
function Format-CatalogEntry {
    param(
        [Parameter(Mandatory)]
        [PSCustomObject]$Item,
        [Parameter(Mandatory)]
        [string]$RelativePath
    )


    # Use difficulty string directly, normalize case
    $difficulty = if ($Item.difficulty) {
        (Get-Culture).TextInfo.ToTitleCase($Item.difficulty.ToLower())
    } else { 'Unknown' }

    $durationText = if ($Item.estimated_time_minutes) { "$($Item.estimated_time_minutes) min" } else { '' }
    $metadata = if ($durationText) { "*$difficulty | $durationText*" } else { "*$difficulty*" }

    $technologies = @($Item.technologies)
    $techList = if ($technologies.Count -gt 0) {
        "**Technologies:** $($technologies -join ', ')"
    } else {
        ''
    }

    $prerequisites = @($Item.prerequisite_katas)
    $prereqList = if ($prerequisites.Count -gt 0) {
        "**Prerequisites:** $($prerequisites -join ', ')"
    } else {
        "**Prerequisites:** None"
    }
    $prereqList = if ($prerequisites.Count -gt 0) {
        "**Prerequisites:** $($prerequisites -join ', ')"
    } else {
        "**Prerequisites:** None"
    }

    $markdown = "- [ ] [**$($Item.title)**]($RelativePath)`n"
    $markdown += "  $metadata • $($Item.description)"

    if ($prereqList -or $techList) {
        $markdown += "`n  "
        if ($prereqList) { $markdown += $prereqList }
        if ($prereqList -and $techList) { $markdown += " • " }
        if ($techList) { $markdown += $techList }
    }

    return $markdown
}

<#
.SYNOPSIS
    Generate main catalog.md with all katas, paths, and labs.

.DESCRIPTION
    Creates the complete catalog markdown file with auto-generated header,
    summary statistics, katas grouped by category (multi-category support),
    training labs section, and paths grouped by difficulty level.

.PARAMETER Katas
    Array of kata items from Get-KataItem.

.PARAMETER Paths
    Array of path items from Get-PathItem.

.PARAMETER Labs
    Array of lab items from Get-LabItem (optional, defaults to empty array).

.OUTPUTS
    String containing complete catalog markdown with task lists.

.EXAMPLE
    $markdown = Format-CatalogMarkdown -Katas $katas -Paths $paths -Labs $labs

.NOTES
    Katas can appear in multiple categories via tags field.
#>
function Format-CatalogMarkdown {
    param(
        [Parameter(Mandatory=$false)]
        [array]$Katas = @(),
        [Parameter(Mandatory=$false)]
        [array]$Paths = @(),
        [Parameter(Mandatory=$false)]
        [array]$Labs = @()
    )


    # Ensure arrays with null-safe handling - force array cast immediately
    [array]$Katas = if ($null -ne $Katas) { ,$Katas } else { @() }
    [array]$Paths = if ($null -ne $Paths) { ,$Paths } else { @() }
    [array]$Labs = if ($null -ne $Labs) { ,$Labs } else { @() }


    $totalItems = $Katas.Count + $Paths.Count + $Labs.Count

    # Add YAML frontmatter
    $markdown = "---`n"
    $markdown += "title: Learning Catalog`n"
    $markdown += "description: Complete catalog of all available learning resources including katas, training labs, and pre-curated learning paths`n"
    $markdown += "author: Learning Platform Team`n"
    $markdown += "ms.date: $(Get-Date -Format 'yyyy-MM-dd')`n"
    $markdown += "ms.topic: hub-page`n"
    $markdown += "keywords:`n"
    $markdown += "  - learning catalog`n"
    $markdown += "  - katas`n"
    $markdown += "  - training labs`n"
    $markdown += "  - learning paths`n"
    $markdown += "---`n`n"

    $markdown += Get-AutoGenHeader
    $markdown += "## All Learning Content`n`n"
    $markdown += "Complete catalog of all available learning resources. Check items to track your progress.`n`n"
    $markdown += "**Total Content:** $totalItems items ($($Katas.Count) katas + $($Labs.Count) training labs + $($Paths.Count) paths)`n`n"
    $markdown += "---`n`n"

    # SECTION 1: Pre-Curated Learning Paths (moved to top)
    $markdown += "## 📚 Pre-Curated Learning Paths`n`n"

    # Sort paths by difficulty order for flat list presentation
    $difficultyOrder = @{
        'Foundation' = 1
        'Skill' = 2
        'Advanced' = 3
        'Expert' = 4
        'Legendary' = 5
        'Unknown' = 99
    }

    $sortedPaths = $Paths | Sort-Object {
        $level = if ($_.difficulty) {
            (Get-Culture).TextInfo.ToTitleCase($_.difficulty.ToLower())
        } else { 'Unknown' }
        $difficultyOrder[$level]
    }

    foreach ($path in $sortedPaths) {
        $relativePath = $path.filePath -replace '^.*?learning[/\\]', '' -replace '\\', '/'
        $markdown += Format-CatalogEntry -Item $path -RelativePath $relativePath
        $markdown += "`n`n"
    }

    $markdown += "---`n`n"

    # SECTION 2: Katas by Difficulty (regrouped from category to difficulty)
    $markdown += "## 🥋 Katas by Difficulty`n`n"

    # Group katas by difficulty level
    $katasByDifficulty = @{
        'Foundation' = @()
        'Skill' = @()
        'Advanced' = @()
        'Expert' = @()
        'Legendary' = @()
        'Unknown' = @()
    }

    foreach ($kata in $Katas) {
        $level = if ($kata.difficulty) {
            (Get-Culture).TextInfo.ToTitleCase($kata.difficulty.ToLower())
        } else { 'Unknown' }
        $katasByDifficulty[$level] += $kata
    }

    foreach ($level in @('Foundation', 'Skill', 'Advanced', 'Expert', 'Legendary', 'Unknown')) {
        $levelKatas = @($katasByDifficulty[$level])
        if ($levelKatas.Count -gt 0) {
            $difficultyStars = switch ($level) {
                'Foundation' { '⭐' }
                'Skill' { '⭐⭐' }
                'Advanced' { '⭐⭐⭐' }
                'Expert' { '⭐⭐⭐⭐' }
                'Legendary' { '⭐⭐⭐⭐⭐' }
                default { '⭐' }
            }
            $markdown += "### $difficultyStars $level Level ($($levelKatas.Count) $(if ($levelKatas.Count -eq 1) {'kata'} else {'katas'}))`n`n"
            foreach ($kata in $levelKatas) {
                $relativePath = $kata.filePath -replace '^.*?learning[/\\]', '' -replace '\\', '/'
                $markdown += Format-CatalogEntry -Item $kata -RelativePath $relativePath
                $markdown += "`n`n"
            }
            $markdown += "---`n`n"
        }
    }

    # SECTION 3: Training Labs (if any)
    if ($Labs.Count -gt 0) {
        $markdown += "## 🧪 Training Labs`n`n"
        foreach ($lab in $Labs) {
            $relativePath = $lab.filePath -replace '^.*?learning[/\\]', '' -replace '\\', '/'
            $markdown += Format-CatalogEntry -Item $lab -RelativePath $relativePath
            $markdown += "`n`n"
        }
        $markdown += "---`n`n"
    }

    # Add signature footer
    $markdown += "`n---`n`n"
    $markdown += "<!-- markdownlint-disable MD036 -->`n"
    $markdown += "*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,`n"
    $markdown += "then carefully refined by our team of discerning human reviewers.*`n"
    $markdown += "<!-- markdownlint-enable MD036 -->`n"

    return $markdown
}

<#
.SYNOPSIS
    Generate paths/README.md with signature learning paths.

.DESCRIPTION
    Creates the paths directory README with auto-generated header
    and formatted list of signature learning paths.

.PARAMETER Paths
    Array of path items from Get-PathItem (signature paths only).

.OUTPUTS
    String containing paths README markdown with task lists.

.EXAMPLE
    $readme = Format-PathsReadme -Paths $signaturePaths
#>
function Format-PathsReadme {
    param(
        [Parameter(Mandatory)]
        [array]$Paths
    )

    # Add YAML frontmatter
    $markdown = "---`n"
    $markdown += "title: Learning Paths`n"
    $markdown += "description: Pre-curated learning paths for platform development`n"
    $markdown += "author: Learning Platform Team`n"
    $markdown += "ms.date: $(Get-Date -Format 'yyyy-MM-dd')`n"
    $markdown += "ms.topic: hub-page`n"
    $markdown += "keywords:`n"
    $markdown += "  - learning paths`n"
    $markdown += "  - guided learning`n"
    $markdown += "---`n`n"

    $markdown += Get-AutoGenHeader
    $markdown += "## Pre-Curated Learning Paths`n`n"
    $markdown += "Signature learning paths for guided skill development.`n`n"
    $markdown += "---`n`n"

    # Sort paths by difficulty order: Foundation -> Skill -> Advanced -> Expert -> Legendary
    $difficultyOrder = @{
        'Foundation' = 1
        'Skill' = 2
        'Advanced' = 3
        'Expert' = 4
        'Legendary' = 5
        'Unknown' = 99
    }

    $sortedPaths = $Paths | Sort-Object {
        $level = if ($_.difficulty) {
            (Get-Culture).TextInfo.ToTitleCase($_.difficulty.ToLower())
        } else { 'Unknown' }
        $difficultyOrder[$level]
    }

    foreach ($path in $sortedPaths) {
        # Use relative path - just the filename since paths README is in learning/paths/ directory
        $fileName = Split-Path -Leaf $path.filePath
        $markdown += Format-CatalogEntry -Item $path -RelativePath $fileName
        $markdown += "`n`n"
    }

    # Add signature footer
    $markdown += "---`n`n"
    $markdown += "<!-- markdownlint-disable MD036 -->`n"
    $markdown += "*🤖 Crafted with precision by ✨Copilot following brilliant human instruction,`n"
    $markdown += "then carefully refined by our team of discerning human reviewers.*`n"
    $markdown += "<!-- markdownlint-enable MD036 -->`n"

    return $markdown
}

<#
.SYNOPSIS
    Generate Streamlined Kata Progression table for category README.

.DESCRIPTION
    Creates a markdown table with kata progression including difficulty,
    duration, technology focus, and scaffolding level.

.PARAMETER Katas
    Array of katas for this category.

.OUTPUTS
    String containing markdown table.

.EXAMPLE
    $table = Format-KataProgressionTable -Katas $categoryKatas
#>
function Format-KataProgressionTable {
    param(
        [Parameter(Mandatory)]
        [array]$Katas
    )

    $table = "| # | Kata Title | Difficulty | Duration | Prerequisites | Technology Focus | Scaffolding |`n"
    $table += "|---|------------|------------|----------|---------------|------------------|-------------|`n"

    foreach ($kata in $Katas) {
        $kataTitle = $kata.title -replace '^Kata:\s*', ''
        $fileName = Split-Path -Leaf $kata.filePath

        # Extract kata number from filename (supports both 2-digit and 3-digit prefixes)
        $kataNumber = if ($fileName -match '^(\d{2,3})-') { $matches[1] } else { '00' }

        $kataLink = "[$kataTitle](./$fileName)"

        # Map difficulty string to label with stars
        $difficultyLabel = switch ($kata.difficulty) {
            'Foundation' { "⭐ Foundation" }
            'Skill' { "⭐⭐ Skill" }
            'Advanced' { "⭐⭐⭐ Advanced" }
            'Expert' { "⭐⭐⭐⭐ Expert" }
            'Legendary' { "⭐⭐⭐⭐⭐ Legendary" }
            default { "⭐ Foundation" }
        }

        $duration = "$($kata.estimated_time_minutes) min"

        # Extract prerequisites from prerequisite_katas array
        $prereqList = @($kata.prerequisite_katas)
        $prereqDisplay = if ($prereqList.Count -gt 0) {
            $prereqNumbers = @($prereqList | ForEach-Object {
                if ($_ -match '-(\d{2,3})-') { $matches[1] } else { $null }
            } | Where-Object { $_ -ne $null })
            if ($prereqNumbers.Count -gt 0) {
                "→ " + ($prereqNumbers -join ', ')
            } else { "—" }
        } else { "—" }

        # Extract technology focus from description or technologies field
        $techFocus = if ($kata.description -match '([\w\s]+vs[\w\s]+)') {
            $matches[1].Trim()
        } else {
            $techList = @($kata.technologies)
            if ($techList.Count -gt 0) {
                ($techList | Select-Object -First 3) -join ', '
            } else {
                "Multiple technologies"
            }
        }

        # Get scaffolding level from kata YAML (already normalized to title case)
        $scaffoldingLevel = if ($kata.scaffolding_level) { $kata.scaffolding_level } else { "—" }

        $table += "| $kataNumber | $kataLink | $difficultyLabel | $duration | $prereqDisplay | $techFocus | $scaffoldingLevel |`n"
    }

    return $table
}

<#
.SYNOPSIS
    Generate Learning Progression section for category README.

.DESCRIPTION
    Creates detailed learning progression descriptions for each kata
    including focus, scenario, skills, and scaffolding notes.

.PARAMETER Katas
    Array of katas for this category.

.OUTPUTS
    String containing learning progression markdown.

.EXAMPLE
    $progression = Format-LearningProgression -Katas $categoryKatas
#>
function Format-LearningProgression {
    param(
        [Parameter(Mandatory)]
        [array]$Katas
    )

    # Group katas by difficulty level and sort by numeric difficulty value
    $groupedKatas = $Katas | Group-Object -Property difficulty | Sort-Object {
        switch ($_.Name) {
            'Foundation' { 1 }
            'Skill' { 2 }
            'Advanced' { 3 }
            'Expert' { 4 }
            'Legendary' { 5 }
            default { 0 }
        }
    }

    $progression = ""

    foreach ($group in $groupedKatas) {
        $difficulty = $group.Name
        $katasInGroup = $group.Group

        # Determine level range and label based on difficulty
        $levelInfo = switch ($difficulty) {
            'Foundation' { @{ Range = "100"; Label = "Foundation Level" } }
            'Skill' { @{ Range = "200"; Label = "Skill Level" } }
            'Advanced' { @{ Range = "300"; Label = "Advanced Level" } }
            'Expert' { @{ Range = "400"; Label = "Expert Level" } }
            'Legendary' { @{ Range = "500"; Label = "Legendary Level" } }
            default { @{ Range = "100"; Label = "Foundation Level" } }
        }

        # Special grouping: combine 200-300 if both exist
        # This is handled by the default single-difficulty grouping for now
        # Future enhancement: detect multiple groups and combine ranges

        $progression += "### $($levelInfo.Range) - $($levelInfo.Label)`n`n"

        # Aggregate Focus: combine descriptions from all katas in group
        $focusItems = @($katasInGroup | ForEach-Object {
            if ($_.description -match '^([^\.]+)') {
                $matches[1].Trim()
            } else {
                $null
            }
        } | Where-Object { $_ })

        $aggregatedFocus = if ($focusItems.Count -gt 0) {
            ($focusItems | Select-Object -First 2) -join " and "
        } else {
            "Learn through hands-on practice"
        }
        $progression += "- **Focus**: $aggregatedFocus`n"

        # Aggregate Skills: combine technologies from all katas in group
        $allTechnologies = @($katasInGroup | ForEach-Object {
            @($_.technologies)
        } | Where-Object { $_ })

        $uniqueTechnologies = @($allTechnologies | Select-Object -Unique | Select-Object -First 5)
        $aggregatedSkills = if ($uniqueTechnologies.Count -gt 0) {
            $uniqueTechnologies -join ', '
        } else {
            "Core technical skills and decision-making"
        }
        $progression += "- **Skills**: $aggregatedSkills`n"

        # Aggregate Time-to-Practice: sum estimated_time_minutes from all katas
        $totalMinutes = ($katasInGroup | Measure-Object -Property estimated_time_minutes -Sum).Sum

        $timeDescription = if ($totalMinutes -gt 0) {
            if ($totalMinutes -lt 30) {
                "Under 30 minutes"
            } elseif ($totalMinutes -lt 60) {
                "Under 1 hour"
            } elseif ($totalMinutes -lt 120) {
                "1-2 hours"
            } else {
                "$([Math]::Ceiling($totalMinutes / 60)) hours"
            }
        } else {
            "Varies by complexity"
        }
        $progression += "- **Time-to-Practice**: $timeDescription`n`n"
    }

    return $progression
}

<#
.SYNOPSIS
    Update category README sections between markers.

.DESCRIPTION
    Reads existing category README and updates auto-generated sections
    between HTML comment markers while preserving manual content.

.PARAMETER CategoryPath
    Full path to category README.md file.

.PARAMETER Katas
    Array of katas for this category.

.OUTPUTS
    Updated README content or $null if no markers found.

.EXAMPLE
    $updated = Update-CategoryReadmeSection -CategoryPath $readmePath -Katas $categoryKatas
#>
function Update-CategoryReadmeSection {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory)]
        [string]$CategoryPath,
        [Parameter(Mandatory)]
        [array]$Katas
    )

    if (-not (Test-Path $CategoryPath)) {
        return $null
    }

    $content = Get-Content -Path $CategoryPath -Raw -Encoding UTF8

    # Check for progression table markers
    $tableMarkerStart = '<!-- AUTO-GENERATED: Kata Progression Table START -->'
    $tableMarkerEnd = '<!-- AUTO-GENERATED: Kata Progression Table END -->'

    # Check for learning progression markers
    $progressionMarkerStart = '<!-- AUTO-GENERATED: Learning Progression START -->'
    $progressionMarkerEnd = '<!-- AUTO-GENERATED: Learning Progression END -->'

    # Check for generic auto-generation markers
    $genericMarkerStart = '<!-- AUTO-GENERATED:START -->'
    $genericMarkerEnd = '<!-- AUTO-GENERATED:END -->'

    $hasTableMarkers = $content -match [regex]::Escape($tableMarkerStart)
    $hasProgressionMarkers = $content -match [regex]::Escape($progressionMarkerStart)
    $hasGenericMarkers = $content -match [regex]::Escape($genericMarkerStart)

    if (-not $hasTableMarkers -and -not $hasProgressionMarkers -and -not $hasGenericMarkers) {
        Write-Verbose "No auto-generation markers found in $CategoryPath"
        return $null
    }

    # Declare WhatIf support
    if ($PSCmdlet.ShouldProcess($CategoryPath, "Update auto-generated sections")) {
        # Update table section if markers exist
        if ($hasTableMarkers) {
            $table = Format-KataProgressionTable -Katas $Katas
            $tablePattern = "(?s)($([regex]::Escape($tableMarkerStart))).*?($([regex]::Escape($tableMarkerEnd)))"
            $tableReplacement = "`$1`n`n$table`n`$2"
            $content = $content -replace $tablePattern, $tableReplacement
            Write-Verbose "Updated Kata Progression Table in $CategoryPath"
        }

        # Update learning progression section if markers exist
        if ($hasProgressionMarkers) {
            $progression = Format-LearningProgression -Katas $Katas
            $progressionPattern = "(?s)($([regex]::Escape($progressionMarkerStart))).*?($([regex]::Escape($progressionMarkerEnd)))"
            $progressionReplacement = "`$1`n`n$progression`$2"
            $content = $content -replace $progressionPattern, $progressionReplacement
            Write-Verbose "Updated Learning Progression in $CategoryPath"
        }

        # Update generic auto-generated section if markers exist
        if ($hasGenericMarkers) {
            $table = Format-KataProgressionTable -Katas $Katas
            $genericPattern = "(?s)($([regex]::Escape($genericMarkerStart))).*?($([regex]::Escape($genericMarkerEnd)))"

            # Extract the section between markers to preserve the header
            if ($content -match "(?s)$([regex]::Escape($genericMarkerStart))(.*?)$([regex]::Escape($genericMarkerEnd))") {
                $sectionContent = $Matches[1]
                # Find the header (## or ###) in the section
                if ($sectionContent -match '(?m)^(#{2,3}\s+[^\n]+)') {
                    $header = $Matches[1]
                    $genericReplacement = "`$1`n<!-- This section is automatically generated. Manual edits will be overwritten. -->`n`n$header`n`n$table`n`$2"
                } else {
                    $genericReplacement = "`$1`n<!-- This section is automatically generated. Manual edits will be overwritten. -->`n`n$table`n`$2"
                }
            } else {
                $genericReplacement = "`$1`n<!-- This section is automatically generated. Manual edits will be overwritten. -->`n`n$table`n`$2"
            }

            $content = $content -replace $genericPattern, $genericReplacement
            Write-Verbose "Updated generic auto-generated section in $CategoryPath"
        }

        return $content
    }

    return $null
}

<#
.SYNOPSIS
    Generate category-specific katas/{category}/README.md.

.DESCRIPTION
    Checks for auto-generation markers in existing category README.
    If markers exist, updates only those sections. If no README or
    no markers exist, skips generation to preserve manual content.

.PARAMETER Category
    Category name (kebab-case).

.PARAMETER Katas
    Array of katas for this category.

.PARAMETER CategoryPath
    Full path to category README.md file.

.OUTPUTS
    String containing updated category README markdown, or $null to skip.

.EXAMPLE
    $readme = Format-CategoryReadme -Category "edge-deployment" -Katas $categoryKatas -CategoryPath $path
#>
function Format-CategoryReadme {
    param(
        [Parameter(Mandatory)]
        [string]$Category,
        [Parameter(Mandatory)]
        [array]$Katas,
        [Parameter(Mandatory)]
        [string]$CategoryPath
    )

    # Try to update existing README with markers
    $updated = Update-CategoryReadmeSection -CategoryPath $CategoryPath -Katas $Katas

    if ($null -ne $updated) {
        Write-Verbose "Updated auto-generated sections in category README: $Category"
        return $updated
    }

    # No markers found - preserve manual content by returning null
    Write-Verbose "No auto-generation markers in $Category README - preserving manual content"
    return $null
}

#endregion

#region Main Script Logic

try {
    Write-Information "Starting catalog generation..." -InformationAction Continue
    Write-Verbose "Learning root: $LearningRoot"

    # Resolve paths
    $katasDir = Join-Path $LearningRoot "katas"
    $pathsDir = Join-Path $LearningRoot "paths"
    $labsDir = Join-Path $LearningRoot "training-labs"

    # Scan directories
    $katas = @(Get-KataItem -BasePath $katasDir)
    $paths = @(Get-PathItem -BasePath $pathsDir -SignaturePaths $Script:SIGNATURE_PATHS)
    $labs = @(Get-LabItem -BasePath $labsDir)
    if ($null -eq $labs) { $labs = @() }

    # Generate main catalog
    Write-Information "Generating main catalog..." -InformationAction Continue
    $catalogPath = Join-Path $LearningRoot "catalog.md"
    $catalogMarkdown = Format-CatalogMarkdown -Katas $katas -Paths $paths -Labs $labs
    if ($PSCmdlet.ShouldProcess($catalogPath, 'Write')) {
        Set-Content -Path $catalogPath -Value $catalogMarkdown -Encoding UTF8BOM
    }
    Write-Information "Generated: $catalogPath" -InformationAction Continue

    # Generate paths README
    Write-Information "Generating paths README..." -InformationAction Continue
    $pathsReadmePath = Join-Path $pathsDir "README.md"
    $pathsReadmeMarkdown = Format-PathsReadme -Paths $paths
    if ($PSCmdlet.ShouldProcess($pathsReadmePath, 'Write')) {
        Set-Content -Path $pathsReadmePath -Value $pathsReadmeMarkdown -Encoding UTF8BOM
    }
    Write-Information "Generated: $pathsReadmePath" -InformationAction Continue

    # Generate category READMEs (katas grouped by category folder)
    Write-Information "Generating category READMEs..." -InformationAction Continue
    $categorizedKatas = @{}
    foreach ($kata in $katas) {
        $category = $kata.category
        if (-not $categorizedKatas.ContainsKey($category)) {
            $categorizedKatas[$category] = @()
        }
        $categorizedKatas[$category] += $kata
    }

    foreach ($category in $categorizedKatas.Keys | Sort-Object) {
        $categoryDir = Join-Path $katasDir $category
        if (Test-Path $categoryDir) {
            $categoryReadmePath = Join-Path $categoryDir "README.md"

            # DEBUG: Show what we're passing
            $categoryKatas = @($categorizedKatas[$category])

            $categoryReadmeMarkdown = Format-CategoryReadme -Category $category -Katas $categoryKatas -CategoryPath $categoryReadmePath

            # Only write if we got content back (markers found and updated)
            if ($null -ne $categoryReadmeMarkdown) {
                if ($PSCmdlet.ShouldProcess($categoryReadmePath, 'Write')) {
                    Set-Content -Path $categoryReadmePath -Value $categoryReadmeMarkdown -Encoding UTF8BOM
                }
                Write-Information "Updated auto-generated sections: $categoryReadmePath" -InformationAction Continue
            } else {
                Write-Information "Preserved manual content (no markers): $categoryReadmePath" -InformationAction Continue
            }
        }
    }

    $totalItems = $katas.Count + $paths.Count + $labs.Count
    Write-Information -MessageData @{ Message = 'Catalog generation complete!'; TotalItems = $totalItems; Katas = $katas.Count; Paths = $paths.Count; Labs = $labs.Count } -InformationAction Continue
    Write-Information "Generated files:" -InformationAction Continue
    Write-Information "  - learning/catalog.md" -InformationAction Continue
    Write-Information "  - learning/paths/README.md" -InformationAction Continue
    Write-Information "  - $($categorizedKatas.Count)x learning/katas/{category}/README.md" -InformationAction Continue

} catch {
    Write-Error "Catalog generation failed: $($_.Exception.Message)"
    Write-Error "  At line: $($_.InvocationInfo.ScriptLineNumber)"
    Write-Error "  In function: $($_.InvocationInfo.InvocationName)"
    Write-Error "  Stack trace: $($_.ScriptStackTrace)"
    exit 1
}

#endregion

