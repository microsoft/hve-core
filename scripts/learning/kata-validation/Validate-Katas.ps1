#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Comprehensive Kata Standards Compliance Validator

.DESCRIPTION
    This script validates all katas against the standards defined in:
    - learning/shared/templates/kata-template.md
    - .copilot-tracking/plans/20250120-kata-standards-compliance-plan.instructions.md

    Validation includes:
    - Template field compliance
    - Category organization
    - Prerequisite chain validation
    - Required field completeness
    - AI coaching schema compliance

.PARAMETER ValidationTypes
    Specify which validation types to run. Valid values:
    - All (default): Run all validations
    - Template: Only validate template compliance
    - Categories: Only validate categories and organization
    - Prerequisites: Only validate prerequisite chains
    - Fields: Only validate required field completeness

.PARAMETER KataDirectory
    Specify the path to the katas directory. Can be absolute or relative path.
    If not specified, defaults to "learning/katas" relative to the project root.
    This is useful when running from VS Code extension or different working directories.

.PARAMETER IncludeCategoryReadmes
    Include category README.md files in validation.
    By default, only individual kata files (01-*.md, 02-*.md, etc.) are validated.

.PARAMETER Quiet
    Suppress verbose output

.EXAMPLE
    .\Validate-Katas.ps1
    Runs all validations on individual kata files only (01-*.md, 02-*.md, etc.)

.EXAMPLE
    .\Validate-Katas.ps1 -KataDirectory "C:\workspace\hve-learning\learning\katas"
    Validates katas in the specified directory (useful from VS Code extension context)

.EXAMPLE
    .\Validate-Katas.ps1 -KataDirectory "./learning/katas"
    Validates katas using a relative path from current directory

.EXAMPLE
    .\Validate-Katas.ps1 -IncludeCategoryReadmes
    Runs all validations on both individual kata files and category READMEs

.EXAMPLE
    .\Validate-Katas.ps1 -ValidationTypes Fields
    Only validates field compliance for individual kata files

.EXAMPLE
    .\Validate-Katas.ps1 -KataPath "learning/katas/adr-creation/01-basic-messaging-architecture.md"
    Validates only the specified kata file

.EXAMPLE
    .\Validate-Katas.ps1 -KataPath @("learning/katas/adr-creation/01-basic-messaging-architecture.md", "learning/katas/adr-creation/02-advanced-observability-stack.md")
    Validates multiple specified kata files

.EXAMPLE
    pwsh -NoProfile -Command '$files = @("learning/katas/troubleshooting/100-ai-assisted-diagnostics.md", "learning/katas/troubleshooting/200-multi-component-debugging.md"); & "./scripts/learning/kata-validation/Validate-Katas.ps1" -KataPath $files *>&1'
    Validates multiple kata files from bash shell with all output streams captured

.NOTES
    IMPORTANT: Script invocation method matters!

    ✅ CORRECT - Direct execution:
       pwsh ./scripts/kata-validation/Validate-Katas.ps1 '/path/to/kata.md'
       ./Validate-Katas.ps1 '/path/to/kata.md'

    ❌ INCORRECT - Using & operator:
       pwsh -Command "& './scripts/kata-validation/Validate-Katas.ps1' -Path 'kata.md'"

    The script checks $MyInvocation.InvocationName and will NOT run validation logic
    when invoked with the & (call) operator. This causes the script to show only
    initialization messages (module loading, schema loading) then exit without
    actually validating files or showing the validation summary.

    When run correctly, you should see:
    1. Initialization messages (✓ PowerShell-Yaml module loaded, ✓ Loaded schema)
    2. Validation progress (🔍 Validating: [file path])
    3. Validation summary (📊 Validation Summary with error/warning counts)
    4. Overall status (🎯 Overall Status: ✅ PASS or ❌ FAIL)

    If you only see initialization messages, the script is being invoked incorrectly.
#>

param(
    [ValidateSet('All', 'Template', 'Categories', 'Prerequisites', 'Fields', 'Quality', 'Structure')]
    [string[]]$ValidationTypes = @('All'),

    [Alias('File', 'Path', 'KataFile')]
    [object[]]$KataPath,

    [Alias('KataFolder', 'KatasDirectory')]
    [string]$KataDirectory,

    [switch]$IncludeCategoryReadmes,

    [switch]$FixCommonIssues,

    [switch]$Quiet
)

# Configuration
$Script:ProjectRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $PSScriptRoot))

# Use provided KataDirectory parameter or default to project structure
if ($KataDirectory) {
    # If provided, use it directly (can be absolute or relative)
    if ([System.IO.Path]::IsPathRooted($KataDirectory)) {
        $Script:KataDirectory = $KataDirectory
    } else {
        # Relative path - resolve from current directory
        $Script:KataDirectory = Join-Path (Get-Location) $KataDirectory | Resolve-Path -ErrorAction SilentlyContinue
        if (-not $Script:KataDirectory) {
            $Script:KataDirectory = Join-Path (Get-Location) $KataDirectory
        }
    }
} else {
    # Default: assume script is in the hve-learning repository structure
    $Script:KataDirectory = Join-Path $Script:ProjectRoot "learning\katas"
}

$Script:TemplatePath = Join-Path $Script:ProjectRoot "learning\shared\templates\kata-template.md"

# Script-level variables to use parameters throughout
$Script:ValidationTypes = $ValidationTypes
# Normalize ValidationTypes: support comma-separated single string
if ($Script:ValidationTypes -and $Script:ValidationTypes.Count -eq 1 -and $Script:ValidationTypes[0] -is [string] -and $Script:ValidationTypes[0] -match ',') {
    $Script:ValidationTypes = $Script:ValidationTypes -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne '' }
}
$Script:IncludeCategoryReadmes = $IncludeCategoryReadmes.IsPresent
$Script:FixCommonIssues = $FixCommonIssues.IsPresent
$Script:Quiet = $Quiet.IsPresent

# Normalize KataPath input
if ($KataPath) {
    $normalizedPaths = @()
    foreach ($item in $KataPath) {
        if ($null -eq $item) { continue }

        # Normalize FileInfo/DirectoryInfo objects to strings
        if ($item -is [System.IO.FileInfo] -or $item -is [System.IO.DirectoryInfo]) {
            $normalizedPaths += $item.FullName
        }
        else {
            $s = [string]$item
            if (-not [string]::IsNullOrWhiteSpace($s)) {
                $normalizedPaths += $s.Trim()
            }
        }
    }
    $Script:KataPath = $normalizedPaths
}
else {
    $Script:KataPath = @()
}

# Ensure PowerShell-Yaml module is available for robust YAML parsing
function Install-YamlModule {
        try {
            Import-Module powershell-yaml -ErrorAction Stop
        if (-not $Script:Quiet) {
            Write-Information "✓ PowerShell-Yaml module loaded successfully" -InformationAction Continue
        }
    }
    catch {
        if (-not $Script:Quiet) {
            Write-Information "📦 Installing PowerShell-Yaml module for robust YAML parsing..." -InformationAction Continue
        }
        try {
            Install-Module -Name powershell-yaml -Force -AllowClobber -Scope CurrentUser
            Import-Module powershell-yaml -Force
            if (-not $Script:Quiet) {
                Write-Information "✓ PowerShell-Yaml module installed and loaded successfully" -InformationAction Continue
            }
        }
        catch {
            Write-Error "❌ Failed to install PowerShell-Yaml module: $($_.Exception.Message)"
            Write-Error "Please install manually with: Install-Module -Name powershell-yaml"
            exit 1
        }
    }
}

# Initialize YAML module
Install-YamlModule

# Load kata frontmatter schema
$Script:KataSchema = $null
$schemaPath = Join-Path $ProjectRoot "learning\shared\schema\kata-frontmatter-schema.json"

if (Test-Path $schemaPath) {
    try {
        $schemaContent = Get-Content -Path $schemaPath -Raw
        $Script:KataSchema = $schemaContent | ConvertFrom-Json
        if (-not $Script:Quiet) {
            Write-Information "✓ Loaded kata frontmatter schema ($($Script:KataSchema.required.Count) required fields)" -InformationAction Continue
        }
    }
    catch {
        Write-Warning "Failed to load schema: $_"
        Write-Warning "Schema validation will be skipped"
    }
}
else {
    Write-Warning "Schema file not found: $schemaPath"
    Write-Warning "Schema validation will be skipped"
}

# Define required sections for individual katas
$Script:RequiredSections = @(
    '## Quick Context',
    '## Essential Setup',
    '## Practice Tasks',
    '## Completion Check',
    '## Reference Appendix'
)

# Strict section order from kata template (excludes Task N which are validated separately)
$Script:ExpectedSectionOrder = @(
    'Quick Context',
    'Essential Setup',
    'Practice Tasks',
    'Completion Check',
    'Reference Appendix'
)

# Required subsections in Reference Appendix (must appear in this order)
$Script:RequiredReferenceAppendixSubsections = @(
    '### Help Resources',
    '### Professional Tips',
    '### Troubleshooting'
)

# Allowed section names (from template)
$Script:AllowedSections = @(
    'Quick Context',
    'Essential Setup',
    'Practice Tasks',
    'Completion Check',
    'Reference Appendix'
)

# Required fields are now defined in kata-frontmatter-schema.json
# Validated by Test-SchemaCompliance function
$RequiredFields = if ($Script:KataSchema) {
    $Script:KataSchema.required
}
else {
    # Fallback to basic validation if schema not loaded (21 required fields)
    @(
        'title', 'description', 'author', 'ms.date',
        'kata_id', 'kata_category', 'kata_difficulty',
        'learning_objectives', 'success_criteria',
        'estimated_time_minutes', 'required_tools', 'related_katas',
        'tags', 'focus_concept', 'focus_platform',
        'setup_time_minutes', 'practice_time_minutes', 'conceptual_depth',
        'conceptual_breadth', 'ai_coaching_enabled', 'hint_strategy'
    )
}

# Global tracking
$Script:Errors = @()
$Script:Warnings = @()
$Script:KataFiles = @()
$Script:TemplateFields = @()
$Script:CategoryStats = @{}
$Script:KataIdLookup = @{}

function Write-ValidationLog {
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Error', 'Warning', 'Info')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Message,

        [string]$File = $null
    )

    $entry = @{
        Level     = $Level
        Message   = $Message
        File      = $File
        Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }

    if ($Level -eq 'Error') {
        $Script:Errors += $entry
        $prefix = "❌"
    }
    elseif ($Level -eq 'Warning') {
        $Script:Warnings += $entry
        $prefix = "⚠️"
    }
    else {
        $prefix = "ℹ️"
    }

    $fileContext = if ($File) { " [$File]" } else { "" }

    if (-not $Script:Quiet) {
        Write-Information "$prefix $Message$fileContext" -InformationAction Continue
    }
}

function Find-KataFile {
    if (-not (Test-Path $Script:KataDirectory)) {
        Write-ValidationLog -Level Error -Message "Kata directory not found: $Script:KataDirectory"
        return @()
    }

    $kataFiles = @()

    # If specific paths provided, use only those (support globs and directories)
    if ($Script:KataPath -and $Script:KataPath.Count -gt 0) {
        foreach ($path in $Script:KataPath) {
            # Support both absolute and relative paths
            $candidate = if ([System.IO.Path]::IsPathRooted($path)) { $path } else { Join-Path $ProjectRoot $path }

            # If directory, add all kata files under it
            if (Test-Path $candidate -PathType Container) {
                $dirFiles = Get-ChildItem -Path $candidate -Recurse -Filter "*.md" |
                Where-Object { $_.Name -notmatch "README\.md" -and $_.Name -match "^\d{2,3}-.*\.md$" } |
                ForEach-Object { $_.FullName }
                $kataFiles += $dirFiles
                continue
            }

            # If pattern contains wildcard, expand
            if ($candidate -like '*[*?]*') {
                $globMatches = Get-ChildItem -Path (Split-Path $candidate) -Filter (Split-Path $candidate -Leaf) -Recurse -ErrorAction SilentlyContinue |
                Where-Object { $_.Name -notmatch "README\.md" -and $_.Name -match "^\d{2,3}-.*\.md$" } |
                ForEach-Object { $_.FullName }

                if ($globMatches) { $kataFiles += $globMatches } else { Write-ValidationLog -Level Error -Message "No files matched pattern: $path" }
                continue
            }

            if (Test-Path $candidate) {
                $kataFiles += (Get-Item -Path $candidate).FullName
            }
            else {
                Write-ValidationLog -Level Error -Message "Specified kata file not found: $path"
            }
        }

        # Deduplicate while preserving order
        $kataFiles = [System.Collections.ArrayList]@($kataFiles | Select-Object -Unique)
        $Script:KataFiles = $kataFiles

        if (-not $Script:Quiet) {
            Write-Information "📚 Validating $($kataFiles.Count) specified kata file(s)" -InformationAction Continue
        }

        return $kataFiles
    }

    # Otherwise, discover all files (existing behavior)
    # Always include individual numbered kata files (01-*.md, 02-*.md, 100-*.md, 200-*.md, etc.)
    $individualFiles = Get-ChildItem -Path $Script:KataDirectory -Recurse -Filter "*.md" |
    Where-Object { $_.Name -notmatch "README\.md" -and $_.Name -match "^\d{2,3}-.*\.md$" } |
    ForEach-Object { $_.FullName }

    $kataFiles += $individualFiles

    # Include category README.md files only if explicitly requested
    if ($Script:IncludeCategoryReadmes) {
        # Get all README.md files recursively
        # Since we're using -Filter "README.md", we only get files named exactly README.md
        # This includes both:
        # - learning/katas/{category}/README.md (when scanning all katas)
        # - README.md at root (when scanning specific category)
        $readmeFiles = Get-ChildItem -Path $Script:KataDirectory -Recurse -Filter "README.md" |
        ForEach-Object { $_.FullName }

        $kataFiles += $readmeFiles
    }    $Script:KataFiles = $kataFiles

    if (-not $Script:Quiet) {
        $message = "📚 Found $($kataFiles.Count) kata files to validate"
        if ($Script:IncludeCategoryReadmes) {
            $readmeCount = ($kataFiles | Where-Object { $_ -like "*README.md" }).Count
            $individualCount = $kataFiles.Count - $readmeCount
            $message += " ($individualCount individual katas + $readmeCount category READMEs)"
        }
        else {
            $message += " (individual katas only)"
        }
        Write-Information $message -InformationAction Continue
    }

    return $kataFiles
}

function Get-RelativePath {
    param(
        [string]$Path,
        [string]$ProjectRoot
    )

    # PowerShell 5.1 compatible relative path calculation
    try {
        $normalizedPath = [System.IO.Path]::GetFullPath($Path)
        $normalizedRoot = [System.IO.Path]::GetFullPath($ProjectRoot)

        if ($normalizedPath.StartsWith($normalizedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
            $relativePath = $normalizedPath.Substring($normalizedRoot.Length).TrimStart('\', '/')
            return $relativePath.Replace('\', '/')
        }
    }
    catch {
        Write-Debug "Error calculating relative path for '$Path' from '$ProjectRoot': $($_.Exception.Message)"
    }

    # Fallback to original path if calculation fails
    return $Path.Replace('\', '/')
}

function Test-ContentQuality {
    <#
    .SYNOPSIS
    Validates kata content quality standards discovered during Phase 4 remediation.

    .DESCRIPTION
    Performs content-level validations to ensure katas meet quality standards:
    - No duplicate frontmatter blocks
    - No "Master" language (inclusive language compliance)
    - Required Practice Tasks section exists
    - Minimum checkbox count in tasks
    - Frontmatter position validation
    - No duplicate sections after frontmatter

    .PARAMETER FilePath
    Path to the kata file to validate

    .OUTPUTS
    Boolean indicating if content quality checks passed
    #>
    param(
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'
    $hasErrors = $false

    # Rule 1: Check for duplicate frontmatter (no more than 4 delimiters total, and if 4, not in first 200 lines)
    $delimiterLines = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $delimiterLines += $i
        }
    }

    if ($delimiterLines.Count -gt 4) {
        Write-ValidationLog -Level Error -Message "Found $($delimiterLines.Count) '---' delimiters (expected 2 or 4). Possible duplicate frontmatter at lines: $($delimiterLines -join ', ')" -File $relativePath
        $hasErrors = $true
    }
    elseif ($delimiterLines.Count -eq 4) {
        # Valid pattern: frontmatter (2) + section separators after Completion Check and Reference Appendix (2)
        # Check for duplicate frontmatter by validating delimiter spacing
        if ($delimiterLines.Count -ge 2) {
            $frontmatterSize = $delimiterLines[1] - $delimiterLines[0]
            # If first two delimiters are suspiciously far apart (>100 lines), or delimiters 2-3 too close (<20 lines), flag as potential duplicate
            if ($frontmatterSize -gt 100) {
                Write-ValidationLog -Level Error -Message "Possible duplicate frontmatter: first two delimiters are $frontmatterSize lines apart (expected <100). Delimiter lines: $($delimiterLines -join ', ')" -File $relativePath
                $hasErrors = $true
            }
            elseif ($delimiterLines.Count -eq 4 -and ($delimiterLines[2] - $delimiterLines[1]) -lt 20) {
                Write-ValidationLog -Level Error -Message "Possible duplicate frontmatter: delimiters at lines $($delimiterLines[1]) and $($delimiterLines[2]) are too close (expected at least 20 lines between sections). Delimiter lines: $($delimiterLines -join ', ')" -File $relativePath
                $hasErrors = $true
            }
        }
    }

    # Rule 2: Check for "Master" language (inclusive language compliance)
    $masterOccurrences = ($content | Select-String -Pattern '\bMaster\b' -AllMatches).Matches.Count
    if ($masterOccurrences -gt 0) {
        $masterLines = @()
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match '\bMaster\b') {
                $masterLines += ($i + 1)  # Convert to 1-based line numbers
            }
        }
        Write-ValidationLog -Level Error -Message "Found $masterOccurrences occurrence(s) of 'Master' language at lines: $($masterLines -join ', '). Use inclusive alternatives like 'Learn', 'Primary', 'Main', etc." -File $relativePath
        $hasErrors = $true
    }

    # Rule 3: Check for Practice Tasks section (only for individual katas, not category READMEs)
    $isCategoryReadme = Test-IsCategoryReadme -FilePath $FilePath

    if (-not $isCategoryReadme) {
        $hasPracticeTasks = $false
        $hasTasksSection = $false
        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i] -match '^## Practice Tasks\s*$') {
                $hasPracticeTasks = $true
                break
            }
            elseif ($lines[$i] -match '^## Tasks\s*$') {
                $hasTasksSection = $true
                break
            }
        }

        if (-not ($hasPracticeTasks -or $hasTasksSection)) {
            Write-ValidationLog -Level Error -Message "Missing required '## Practice Tasks' or '## Tasks' section" -File $relativePath
            $hasErrors = $true
        }
    }

    # Rule 4: Check for minimum checkbox count (only for individual katas, not category READMEs)
    if (-not $isCategoryReadme) {
        $checkboxPattern = '^\s*- \[ \]'
        $checkboxCount = ($lines | Where-Object { $_ -match $checkboxPattern }).Count
        if ($checkboxCount -lt 5) {
            Write-ValidationLog -Level Warning -Message "Found only $checkboxCount checkboxes (recommended minimum: 5). Ensure adequate practice tasks are provided." -File $relativePath
            # Note: This is a warning, not an error, as some katas may legitimately have fewer tasks
        }
    }

    # Rule 5: Check frontmatter closes before line 100
    if ($delimiterLines.Count -ge 2 -and $delimiterLines[1] -ge 100) {
        Write-ValidationLog -Level Warning -Message "Frontmatter ends at line $($delimiterLines[1] + 1) (recommended: before line 100). Consider reducing frontmatter size." -File $relativePath
        # Warning only - some katas with extensive metadata may legitimately exceed this
    }

    # Rule 6: Check for duplicate sections after frontmatter (lines 85-200)
    if ($delimiterLines.Count -ge 2) {
        $frontmatterEnd = $delimiterLines[1]
        $sectionHeaders = @{}

        for ($i = [Math]::Max($frontmatterEnd + 1, 85); $i -lt [Math]::Min($lines.Length, 200); $i++) {
            if ($lines[$i] -match '^## (.+)$') {
                $header = $Matches[1].Trim()
                if ($sectionHeaders.ContainsKey($header)) {
                    $sectionHeaders[$header] += @($i + 1)
                }
                else {
                    $sectionHeaders[$header] = @($i + 1)
                }
            }
        }

        foreach ($header in $sectionHeaders.Keys) {
            if ($sectionHeaders[$header].Count -gt 1) {
                Write-ValidationLog -Level Error -Message "Duplicate section '## $header' found at lines: $($sectionHeaders[$header] -join ', '). Remove duplicate sections." -File $relativePath
                $hasErrors = $true
            }
        }
    }

    return -not $hasErrors
}

function Test-YamlFrontmatterStructure {
    param(
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $hasErrors = $false

    # Check basic frontmatter structure using simple string operations
    if (-not $content.StartsWith('---')) {
        Write-ValidationLog -Level Error -Message "File must start with YAML frontmatter delimiter '---'" -File $relativePath
        $hasErrors = $true
    }

    # Find all occurrences of --- delimiter
    $lines = $content -split '\r?\n'
    $delimiterCount = 0

    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $delimiterCount++
            if ($delimiterCount -eq 2) {
                break
            }
        }
    }

    # Check for proper frontmatter structure
    if ($delimiterCount -lt 2) {
        Write-ValidationLog -Level Error -Message "Incomplete frontmatter structure: found $delimiterCount '---' delimiters, expected at least 2" -File $relativePath
        $hasErrors = $true
    }

    # Note: Additional '---' delimiters after frontmatter are allowed as they may be markdown horizontal rules

    return -not $hasErrors
}

function Get-YamlFrontmatter {
    param(
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath

    # First validate the basic structure
    $structureValid = Test-YamlFrontmatterStructure -FilePath $FilePath
    if (-not $structureValid) {
        Write-ValidationLog -Level Error -Message "YAML frontmatter structure validation failed" -File $relativePath
        return $null
    }

    try {
        $content = Get-Content -Path $FilePath -Raw

        # Extract frontmatter content between --- delimiters
        $lines = $content -split '\r?\n'
        $frontmatterLines = @()
        $inFrontmatter = $false

        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i].Trim() -eq '---') {
                if (-not $inFrontmatter) {
                    $inFrontmatter = $true
                    continue
                }
                else {
                    # End of frontmatter
                    break
                }
            }

            if ($inFrontmatter) {
                $frontmatterLines += $lines[$i]
            }
        }

        if ($frontmatterLines.Count -eq 0) {
            Write-ValidationLog -Level Error -Message "No frontmatter content found between '---' delimiters" -File $relativePath
            return $null
        }

        # Join frontmatter lines and parse with PowerShell-Yaml
        $frontmatterText = $frontmatterLines -join "`n"

        try {
            $frontmatter = ConvertFrom-Yaml -Yaml $frontmatterText

            if (-not $frontmatter) {
                Write-ValidationLog -Level Error -Message "Empty or invalid YAML frontmatter content" -File $relativePath
                return $null
            }

            return $frontmatter
        }
        catch {
            Write-ValidationLog -Level Error -Message "Invalid YAML syntax in frontmatter: $($_.Exception.Message)" -File $relativePath
            return $null
        }
    }
    catch {
        Write-ValidationLog -Level Error -Message "Failed to read or parse frontmatter: $($_.Exception.Message)" -File $relativePath
        return $null
    }
}function Get-TemplateField {
    if ($Script:TemplateFields.Count -gt 0) {
        return $Script:TemplateFields
    }

    if (-not (Test-Path $TemplatePath)) {
        Write-ValidationLog -Level Error -Message "Template file not found: $TemplatePath"
        return @()
    }

    try {
        # Template files contain placeholder syntax, so we need to parse them differently
        # than regular YAML frontmatter
        $content = Get-Content -Path $TemplatePath -Raw

        # Extract frontmatter content between --- delimiters
        $lines = $content -split '\r?\n'
        $frontmatterLines = @()
        $inFrontmatter = $false

        for ($i = 0; $i -lt $lines.Length; $i++) {
            if ($lines[$i].Trim() -eq '---') {
                if (-not $inFrontmatter) {
                    $inFrontmatter = $true
                    continue
                }
                else {
                    # End of frontmatter
                    break
                }
            }

            if ($inFrontmatter) {
                $frontmatterLines += $lines[$i]
            }
        }

        if ($frontmatterLines.Count -eq 0) {
            Write-ValidationLog -Level Error -Message "Template file has no frontmatter content"
            return @()
        }

        # Parse template fields manually since it contains placeholder syntax
        $templateFields = @()
        foreach ($line in $frontmatterLines) {
            $trimmed = $line.Trim()

            # Skip empty lines and comments
            if (-not $trimmed -or $trimmed.StartsWith('#')) {
                continue
            }

            # Match top-level fields (no leading spaces before the key)
            if ($line -match '^([^:]+):' -and -not $line.StartsWith(' ') -and -not $line.StartsWith('  ')) {
                $field = $Matches[1].Trim()
                if ($field) {
                    $templateFields += $field
                }
            }
        }

        $Script:TemplateFields = $templateFields

        if (-not $Script:Quiet) {
            Write-Information "📋 Template defines $($templateFields.Count) fields: $($templateFields -join ', ')" -InformationAction Continue
        }

        return $templateFields
    }
    catch {
        Write-ValidationLog -Level Error -Message "Failed to load template: $($_.Exception.Message)"
        return @()
    }
}

function Test-RequiredField {
    param(
        [hashtable]$Frontmatter,
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $missing = $RequiredFields | Where-Object { -not $Frontmatter.ContainsKey($_) }

    if ($missing.Count -gt 0) {
        Write-ValidationLog -Level Error -Message "Missing required fields: $($missing -join ', ')" -File $relativePath
    }

    # Validate AI coaching fields specifically
    $aiCoachingEnabled = $Frontmatter['ai_coaching_enabled']
    if ($aiCoachingEnabled -eq 'true' -or $aiCoachingEnabled -eq $true) {
        # Check for hint_strategy field (required if ai_coaching_enabled)
        if (-not $Frontmatter.ContainsKey('hint_strategy')) {
            Write-ValidationLog -Level Error -Message "AI coaching enabled but hint_strategy field is missing" -File $relativePath
        }
        else {
            $strategy = $Frontmatter['hint_strategy']
            if ($strategy -notin @('progressive', 'direct', 'minimal')) {
                Write-ValidationLog -Level Error -Message "hint_strategy must be 'progressive', 'direct', or 'minimal', got: $strategy" -File $relativePath
            }
        }

        # Check for common_pitfalls field (optional but recommended)
        if (-not $Frontmatter.ContainsKey('common_pitfalls')) {
            Write-ValidationLog -Level Warning -Message "AI coaching enabled but common_pitfalls field is missing (recommended for better coaching)" -File $relativePath
        }
    }
}

function Test-IsCategoryReadme {
    param(
        [string]$FilePath
    )

    # Category README files are named README.md and are directly in a kata category folder
    # Pattern: learning/katas/{category}/README.md
    $fileName = Split-Path -Leaf $FilePath
    $parentFolder = Split-Path -Parent $FilePath | Split-Path -Leaf

    return ($fileName -eq "README.md" -and $parentFolder -match '^[a-z-]+$')
}

function Test-TemplateCompliance {
    param(
        [hashtable]$Frontmatter,
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $templateFields = Get-TemplateField

    if ($templateFields.Count -eq 0) {
        return
    }

    $kataFields = $Frontmatter.Keys

    # Check for missing template fields
    $missingFields = $templateFields | Where-Object { $_ -notin $kataFields }
    if ($missingFields.Count -gt 0) {
        Write-ValidationLog -Level Error -Message "Missing template fields: $($missingFields -join ', ')" -File $relativePath
    }

    # Check for extra fields not in template (excluding known nested fields)
    $extraFields = $kataFields | Where-Object {
        $_ -notin $templateFields -and
        $_ -ne 'estimated_time'  # This appears in extension_challenges and is valid
    }
    if ($extraFields.Count -gt 0) {
        Write-ValidationLog -Level Warning -Message "Extra fields not in template: $($extraFields -join ', ')" -File $relativePath
    }

    # Validate content structure
    $content = Get-Content -Path $FilePath -Raw
    $isCategoryReadme = Test-IsCategoryReadme -FilePath $FilePath

    # Category READMEs have different structure requirements
    if ($isCategoryReadme) {
        # Category READMEs should have these sections in frontmatter, not body
        # We'll check for redundancy in Test-RedundantSection instead
        if ($content -notmatch '## Quick Context') {
            Write-ValidationLog -Level Warning -Message 'Missing "Quick Context" section' -File $relativePath
        }

        if ($content -notmatch '## Content Index' -and $content -notmatch '## Streamlined Kata Progression' -and $content -notmatch '## Katas') {
            Write-ValidationLog -Level Warning -Message 'Category README missing content index section (expected: "Content Index", "Streamlined Kata Progression", or "Katas")' -File $relativePath
        }
    }
    # Individual katas have sections in frontmatter only (not body sections)
    # Category READMEs have sections in both frontmatter AND body

    # Validate that Practice Tasks section contains checkboxes for progress tracking
    if ($content -match '## Practice Tasks') {
        # Extract Practice Tasks section content
        $practiceTasksMatch = [regex]::Match($content, '(?s)## Practice Tasks.*?(?=(##|$))')
        if ($practiceTasksMatch.Success) {
            $practiceTasksContent = $practiceTasksMatch.Value

            # Check if there are numbered steps without checkboxes
            # Pattern: Look for numbered list items (1., 2., etc.) that don't have checkbox children
            $hasSteps = $practiceTasksContent -match '\d+\.\s+\*\*'
            $hasCheckboxes = $practiceTasksContent -match '- \[ \]'

            if ($hasSteps -and -not $hasCheckboxes) {
                Write-ValidationLog -Level Error -Message 'Practice Tasks must include checkboxes (- [ ]) for each step to enable progress tracking' -File $relativePath
            }
        }
    }
}

function Test-Category {
    param(
        [hashtable]$Frontmatter,
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath

    # Category READMEs don't have kata_category field - skip this validation
    $isCategoryReadme = Test-IsCategoryReadme -FilePath $FilePath
    if ($isCategoryReadme) {
        return
    }

    $kataCategory = $Frontmatter['kata_category']

    if (-not $kataCategory) {
        Write-ValidationLog -Level Error -Message "kata_category field is required" -File $relativePath
        return
    }

    # Schema requires kata_category to be an array - enforce strict type checking
    if ($kataCategory -isnot [array] -and $kataCategory -isnot [System.Collections.IList]) {
        Write-ValidationLog -Level Error -Message "Field 'kata_category' has wrong type: expected array, got $($kataCategory.GetType().Name)" -File $relativePath
        return
    }

    # Extract first value for path validation (schema guarantees minItems: 1)
    $category = $kataCategory[0]

    # Validate category matches file path
    # Normalize paths for comparison (handle both forward and backward slashes)
    $normalizedFilePath = $FilePath.Replace('\', '/').TrimEnd('/')
    $normalizedKataDir = $KataDirectory.Replace('\', '/').TrimEnd('/')

    # Check if KataDirectory already ends with the category name
    # This handles cases where -KataDirectory points directly to a category folder
    if ($normalizedKataDir.EndsWith("/$category", [StringComparison]::OrdinalIgnoreCase)) {
        $expectedPath = $normalizedKataDir
    } else {
        $expectedPath = "$normalizedKataDir/$category"
    }

    if (-not $normalizedFilePath.StartsWith($expectedPath, [StringComparison]::OrdinalIgnoreCase)) {
        Write-ValidationLog -Level Warning -Message "kata_category '$category' doesn't match file path. Expected under: $category/" -File $relativePath
    }
}

function Test-Tag {
    <#
    .SYNOPSIS
    Validates kata tags field for multi-category support.

    .DESCRIPTION
    Validates that the tags field exists, is an array, and contains only valid category names.
    Supports multi-category classification where katas can appear in multiple category READMEs.

    .PARAMETER Frontmatter
    The parsed YAML frontmatter as a hashtable.

    .PARAMETER FilePath
    The path to the kata file being validated.
    #>
    param(
        [hashtable]$Frontmatter,
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $tags = $Frontmatter['tags']

    # Tags are required by schema
    if (-not $tags) {
        Write-ValidationLog -Level Error -Message "tags field is required for multi-category support" -File $relativePath
        return
    }

    # Schema requires tags to be an array
    if ($tags -isnot [array] -and $tags -isnot [System.Collections.IList]) {
        Write-ValidationLog -Level Error -Message "Field 'tags' has wrong type: expected array, got $($tags.GetType().Name)" -File $relativePath
        return
    }

    # Tags can be any category names - no validation against predefined list
    # This allows flexibility for different repositories with their own category structures
}

function Test-Prerequisite {
    param(
        [hashtable]$Frontmatter,
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $prerequisites = $Frontmatter['prerequisite_katas']

    # Prerequisites are optional, but if present must be an array
    if (-not $prerequisites) {
        return
    }

    if ($prerequisites -isnot [array] -and $prerequisites -isnot [System.Collections.IList]) {
        Write-ValidationLog -Level Error -Message "Field 'prerequisite_katas' has wrong type: expected array, got $($prerequisites.GetType().Name)" -File $relativePath
        return
    }

    # Build a kata_id -> filepath lookup cache on first use to support slug-style prerequisites
    if ($Script:KataIdLookup.Count -eq 0) {
        $kataFiles = Get-ChildItem -Path $KataDirectory -Recurse -Filter "*.md" |
        Where-Object { $_.Name -match "^\d\d-.*\.md$" } |
        ForEach-Object { $_.FullName }

        foreach ($kf in $kataFiles) {
            $fm = Get-YamlFrontmatter -FilePath $kf
            if ($fm -and $fm.ContainsKey('kata_id')) {
                $id = $fm['kata_id']
                if ($id -and -not $Script:KataIdLookup.ContainsKey($id)) {
                    $Script:KataIdLookup[$id] = $kf
                }
            }
        }
    }

    foreach ($prereq in $prerequisites) {
        $found = $false

        # If the prereq looks like a path (contains a slash) or explicitly ends with .md, resolve as path
        if ($prereq -match '/|\\' -or $prereq.EndsWith('.md')) {
            $prereqWithExtension = if ($prereq.EndsWith('.md')) { $prereq } else { "$prereq.md" }
            $prereqPath = Join-Path $KataDirectory $prereqWithExtension
            if (Test-Path $prereqPath) {
                $found = $true
            }
            else {
                # Also accept a form where the caller provided a kata_id but with a slash mistakenly included
                $possibleId = ($prereqWithExtension -split '/|\\')[-1] -replace '\.md$', ''
                if ($Script:KataIdLookup.ContainsKey($possibleId)) {
                    $found = $true
                }
            }
        }
        else {
            # Treat the prereq as a kata_id slug and look it up in the cache
            if ($Script:KataIdLookup.ContainsKey($prereq)) {
                $found = $true
            }
            else {
                # Fallback: try to match by trailing filename (e.g., "02-name") or by searching frontmatter
                $files = Get-ChildItem -Path $KataDirectory -Recurse -Filter "*.md"
                foreach ($f in $files) {
                    $fm = Get-YamlFrontmatter -FilePath $f.FullName
                    if ($fm -and $fm.ContainsKey('kata_id') -and $fm['kata_id'] -eq $prereq) {
                        $Script:KataIdLookup[$prereq] = $f.FullName
                        $found = $true
                        break
                    }
                }
            }
        }

        if (-not $found) {
            Write-ValidationLog -Level Error -Message "Prerequisite kata not found: $prereq" -File $relativePath
        }
    }
}

function Test-RedundantSection {
    <#
    .SYNOPSIS
    Detects redundant sections that duplicate content or delay hands-on work.

    .DESCRIPTION
    Validates against cleaned kata quality standards:
    - No multiple Setup sections
    - No multiple Validation sections
    - No Learning Objectives section when frontmatter has learning_objectives
    - No Success Criteria section when frontmatter has success_criteria
    - No "Instructions" bridge sections
    - No explanatory sections between orientation and tasks
    #>
    param([string]$FilePath, [hashtable]$Frontmatter)

    $relativePath = Get-RelativePath $FilePath
    $isCategoryReadme = Test-IsCategoryReadme -FilePath $FilePath

    # Category READMEs have sections in both frontmatter AND body (not redundant)
    # Only check for redundant sections in individual kata files
    if ($isCategoryReadme) {
        return
    }

    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'
    $hasErrors = $false

    # Find all section headers
    $sections = @{}
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+(.+)$') {
            $header = $Matches[1].Trim()
            if ($sections.ContainsKey($header)) {
                $sections[$header] += @($i + 1)
            }
            else {
                $sections[$header] = @($i + 1)
            }
        }
    }

    # Rule 1: Check for multiple setup-related sections
    $setupKeywords = @('Setup', 'Essential Setup', 'Quick Tool Walkthrough', 'Getting Started', 'Orientation')
    $setupSections = $sections.Keys | Where-Object {
        $keyword = $_
        $setupKeywords | Where-Object { $keyword -match $_ }
    }
    if ($setupSections.Count -gt 2) {
        Write-ValidationLog -Level Error -Message "Found $($setupSections.Count) setup-related sections ($(($setupSections | ForEach-Object { "'$_'" }) -join ', ')). Consider merging into single 'Setup & Orientation' section." -File $relativePath
        $hasErrors = $true
    }

    # Rule 2: Check for multiple validation sections
    $validationKeywords = @('Validation', 'Self-Assessment', 'Kata Validation', 'Success Criteria', 'Ready Check')
    $validationSections = $sections.Keys | Where-Object {
        $keyword = $_
        $validationKeywords | Where-Object { $keyword -match $_ }
    }
    if ($validationSections.Count -gt 1) {
        Write-ValidationLog -Level Error -Message "Found $($validationSections.Count) validation sections ($(($validationSections | ForEach-Object { "'$_'" }) -join ', ')). Consolidate into single 'Validation' section." -File $relativePath
        $hasErrors = $true
    }

    # Rule 3: Check for Learning Objectives section when frontmatter has it
    if ($sections.ContainsKey('Learning Objectives') -and $Frontmatter.ContainsKey('learning_objectives')) {
        Write-ValidationLog -Level Error -Message "Contains '## Learning Objectives' section when frontmatter already has learning_objectives field. Remove duplicate section." -File $relativePath
        $hasErrors = $true
    }

    # Rule 4: Check for Success Criteria section when frontmatter has it
    if ($sections.ContainsKey('Success Criteria') -and $Frontmatter.ContainsKey('success_criteria')) {
        Write-ValidationLog -Level Error -Message "Contains '## Success Criteria' section when frontmatter already has success_criteria field. Remove duplicate section." -File $relativePath
        $hasErrors = $true
    }

    # Rule 5: Check for "Instructions" bridge sections
    if ($sections.ContainsKey('Instructions')) {
        Write-ValidationLog -Level Warning -Message "Contains standalone '## Instructions' section. Consider removing if it just bridges between intro and tasks." -File $relativePath
    }

    # Rule 6: Check for explanatory sections between orientation and tasks
    $tasksLine = ($sections.Keys | Where-Object { $_ -match 'Practice Tasks|Tasks|Task \d+' } | ForEach-Object { $sections[$_][0] } | Sort-Object | Select-Object -First 1)
    $orientationLine = ($sections.Keys | Where-Object { $_ -match 'Setup|Orientation|Getting Started' } | ForEach-Object { $sections[$_][0] } | Sort-Object -Descending | Select-Object -First 1)

    if ($tasksLine -and $orientationLine) {
        $betweenSections = $sections.Keys | Where-Object {
            $lineNum = $sections[$_][0]
            $lineNum -gt $orientationLine -and $lineNum -lt $tasksLine
        }

        $explanatorySections = $betweenSections | Where-Object { $_ -match 'Understanding|Overview|About|How to' }
        if ($explanatorySections.Count -gt 0) {
            Write-ValidationLog -Level Warning -Message "Found explanatory sections between orientation and tasks: $(($explanatorySections | ForEach-Object { "'$_'" }) -join ', '). Consider removing to get learners into tasks faster." -File $relativePath
        }
    }

    return -not $hasErrors
}

function Test-RequiredSection {
    param(
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw

    # Check for required main sections
    foreach ($section in $Script:RequiredSections) {
        if ($content -notmatch [regex]::Escape($section)) {
            Write-ValidationLog -Level Error -Message "Missing required section: $section" -File $relativePath
        }
    }

    # Check for task structure (only for individual katas, not category READMEs)
    $isCategoryReadme = Test-IsCategoryReadme -FilePath $FilePath

    if (-not $isCategoryReadme) {
        if ($content -notmatch '## Task \d+:') {
            Write-ValidationLog -Level Error -Message "No task sections found (expected format: '## Task 1:', '## Task 2:', etc.)" -File $relativePath
        }
    }
}

function Test-SectionCompliance {
    <#
    .SYNOPSIS
    Validates that kata sections match template-defined sections.

    .DESCRIPTION
    Checks that all H2 sections (##) are in the allowed list from the template.
    Flags unknown sections as warnings (not errors).

    Template-defined sections:
    - Quick Context
    - Essential Setup
    - Practice Tasks (or Task 1, Task 2, etc.)
    - Completion Check
    - Reference Appendix
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'

    # Skip frontmatter
    $frontmatterEnd = 0
    $delimiterCount = 0
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^---\s*$') {
            $delimiterCount++
            if ($delimiterCount -eq 2) {
                $frontmatterEnd = $i
                break
            }
        }
    }

    # Task N pattern (matches Task 1:, Task 2:, etc.)
    $taskPattern = '^Task \d+:'

    # Find all H2 sections
    $unknownSections = @()
    for ($i = $frontmatterEnd; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+(.+)$') {
            $sectionName = $Matches[1].Trim()

            # Check if section is allowed
            $isAllowed = $false

            # Check against allowed list
            if ($Script:AllowedSections -contains $sectionName) {
                $isAllowed = $true
            }

            # Check if it's a Task N: section
            if ($sectionName -match $taskPattern) {
                $isAllowed = $true
            }

            # Flag unknown sections
            if (-not $isAllowed) {
                $unknownSections += $sectionName
            }
        }
    }

    # Report unknown sections as warnings
    if ($unknownSections.Count -gt 0) {
        foreach ($section in $unknownSections) {
            Write-ValidationLog -Level Warning -Message "Unknown section '## $section' not defined in template. Consider using standard sections: $(($Script:AllowedSections | ForEach-Object { "'$_'" }) -join ', ')" -File $relativePath
        }
    }

    return $true  # Warnings don't fail validation
}

function Test-SectionOrdering {
    <#
    .SYNOPSIS
    Strictly validates that kata sections appear in the exact order defined by the template.

    .DESCRIPTION
    Enforces strict section ordering from kata template:
    1. Quick Context
    2. Essential Setup
    3. Practice Tasks (or individual Task N sections)
    4. Completion Check
    5. Reference Appendix
    6. Footer (AI attribution)
    7. Reference Links comment

    This is an ERROR-level validation - sections out of order will fail validation.
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'

    # Skip frontmatter
    $frontmatterEnd = 0
    $delimiterCount = 0
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^---\s*$') {
            $delimiterCount++
            if ($delimiterCount -eq 2) {
                $frontmatterEnd = $i
                break
            }
        }
    }

    # Extract all H2 sections with their line numbers
    $sectionsFound = @()
    for ($i = $frontmatterEnd; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+(.+)$') {
            $sectionName = $Matches[1].Trim()
            $sectionsFound += @{
                Name       = $sectionName
                LineNumber = $i + 1
            }
        }
    }

    # Map found sections to expected order (excluding Task N sections which are part of Practice Tasks)
    $taskPattern = '^Task \d+:'
    $mappedSections = @()
    $lastExpectedIndex = -1

    foreach ($section in $sectionsFound) {
        $sectionName = $section.Name

        # Skip Task N sections as they're part of Practice Tasks
        if ($sectionName -match $taskPattern) {
            continue
        }

        # Find this section in expected order
        $expectedIndex = $Script:ExpectedSectionOrder.IndexOf($sectionName)

        if ($expectedIndex -ge 0) {
            # Check if this section appears after the previous expected section
            if ($expectedIndex -lt $lastExpectedIndex) {
                Write-ValidationLog -Level Error -Message "Section '## $sectionName' (line $($section.LineNumber)) appears out of order. Expected order: $($Script:ExpectedSectionOrder -join ' → ')" -File $relativePath
            }
            $lastExpectedIndex = $expectedIndex
            $mappedSections += $sectionName
        }
    }

    # Validate footer placement (must appear after Reference Appendix and before Reference Links)
    $footerPattern = '🤖 Crafted with precision|Copilot following brilliant human instruction'
    $referenceLinksPattern = '<!-- Reference Links -->'

    $footerLine = -1
    $referenceLinksLine = -1
    $referenceAppendixLine = -1

    for ($i = $frontmatterEnd; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match $footerPattern) {
            $footerLine = $i + 1
        }
        if ($lines[$i] -match $referenceLinksPattern) {
            $referenceLinksLine = $i + 1
        }
        if ($lines[$i] -match '^##\s+Reference Appendix') {
            $referenceAppendixLine = $i + 1
        }
    }

    # Strictly enforce footer presence
    if ($footerLine -eq -1) {
        Write-ValidationLog -Level Error -Message "Missing required AI attribution footer (must contain '🤖 Crafted with precision' and 'Copilot following brilliant human instruction')" -File $relativePath
    }
    elseif ($referenceAppendixLine -gt 0 -and $footerLine -lt $referenceAppendixLine) {
        Write-ValidationLog -Level Error -Message "Footer (line $footerLine) must appear AFTER Reference Appendix section (line $referenceAppendixLine)" -File $relativePath
    }

    # Strictly enforce reference links presence and placement
    if ($referenceLinksLine -eq -1) {
        Write-ValidationLog -Level Error -Message "Missing required reference links section ('<!-- Reference Links -->' comment must be at end of file)" -File $relativePath
    }
    elseif ($footerLine -gt 0 -and $referenceLinksLine -lt $footerLine) {
        Write-ValidationLog -Level Error -Message "Reference Links comment (line $referenceLinksLine) must appear AFTER footer (line $footerLine)" -File $relativePath
    }

    # Validate required section separators (---) after Completion Check and Reference Appendix
    $completionCheckLine = -1
    for ($i = $frontmatterEnd; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+Completion Check') {
            $completionCheckLine = $i + 1
            break
        }
    }

    if ($completionCheckLine -gt 0 -and $referenceAppendixLine -gt 0) {
        # Find separator between Completion Check and Reference Appendix
        $separatorFound = $false
        for ($i = $completionCheckLine; $i -lt $referenceAppendixLine; $i++) {
            if ($lines[$i] -match '^---\s*$') {
                $separatorFound = $true
                break
            }
        }
        if (-not $separatorFound) {
            Write-ValidationLog -Level Error -Message "Missing required '---' separator between Completion Check (line $completionCheckLine) and Reference Appendix (line $referenceAppendixLine)" -File $relativePath
        }
    }

    if ($referenceAppendixLine -gt 0 -and $footerLine -gt 0) {
        # Find separator between Reference Appendix and footer
        $separatorFound = $false
        for ($i = $referenceAppendixLine; $i -lt $footerLine; $i++) {
            if ($lines[$i] -match '^---\s*$') {
                $separatorFound = $true
                break
            }
        }
        if (-not $separatorFound) {
            Write-ValidationLog -Level Error -Message "Missing required '---' separator between Reference Appendix (line $referenceAppendixLine) and footer (line $footerLine)" -File $relativePath
        }
    }

    # Validate no invalid H2 sections exist (ERROR level)
    $allowedSections = $Script:ExpectedSectionOrder + @()
    $taskPattern = '^Task \d+:'

    foreach ($section in $sectionsFound) {
        $sectionName = $section.Name

        # Skip Task N sections (valid)
        if ($sectionName -match $taskPattern) {
            continue
        }

        # Check if section is in allowed list
        if ($allowedSections -notcontains $sectionName) {
            Write-ValidationLog -Level Error -Message "Invalid section '## $sectionName' (line $($section.LineNumber)) not found in kata template. Allowed sections: $($allowedSections -join ', ')" -File $relativePath
        }
    }

    return $true
}

function Test-ReferenceAppendixStructure {
    <#
    .SYNOPSIS
    Strictly validates Reference Appendix subsection structure and ordering.

    .DESCRIPTION
    Enforces that Reference Appendix contains all required subsections in exact order:
    1. Help Resources
    2. Professional Tips
    3. Troubleshooting

    This is an ERROR-level validation.
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'

    # Find Reference Appendix section
    $appendixStartLine = -1
    $appendixEndLine = $lines.Length

    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+Reference Appendix\s*$') {
            $appendixStartLine = $i
        }
        elseif ($appendixStartLine -ge 0 -and $lines[$i] -match '^##\s+') {
            # Next H2 section marks end of Reference Appendix
            $appendixEndLine = $i
            break
        }
    }

    if ($appendixStartLine -eq -1) {
        Write-ValidationLog -Level Error -Message "Missing required section '## Reference Appendix'" -File $relativePath
        return $false
    }

    # Extract subsections within Reference Appendix
    $subsectionsFound = @()
    for ($i = $appendixStartLine; $i -lt $appendixEndLine; $i++) {
        if ($lines[$i] -match '^###\s+(.+)$') {
            $subsectionName = "### $($Matches[1].Trim())"
            $subsectionsFound += @{
                Name       = $subsectionName
                LineNumber = $i + 1
            }
        }
    }

    # Validate required subsections exist and are in order
    $lastExpectedIndex = -1

    foreach ($requiredSubsection in $Script:RequiredReferenceAppendixSubsections) {
        $found = $false
        $foundIndex = -1

        for ($j = 0; $j -lt $subsectionsFound.Count; $j++) {
            if ($subsectionsFound[$j].Name -eq $requiredSubsection) {
                $found = $true
                $foundIndex = $j
                break
            }
        }

        if (-not $found) {
            Write-ValidationLog -Level Error -Message "Missing required subsection '$requiredSubsection' in Reference Appendix. Required subsections: $($Script:RequiredReferenceAppendixSubsections -join ', ')" -File $relativePath
        }
        elseif ($foundIndex -lt $lastExpectedIndex) {
            Write-ValidationLog -Level Error -Message "Subsection '$requiredSubsection' (line $($subsectionsFound[$foundIndex].LineNumber)) appears out of order in Reference Appendix. Expected order: $($Script:RequiredReferenceAppendixSubsections -join ' → ')" -File $relativePath
        }

        $lastExpectedIndex = [Math]::Max($lastExpectedIndex, $foundIndex)
    }

    # Validate no unexpected subsections exist (enforce exact schema)
    foreach ($foundSubsection in $subsectionsFound) {
        if ($foundSubsection.Name -notin $Script:RequiredReferenceAppendixSubsections) {
            Write-ValidationLog -Level Error -Message "Unexpected subsection '$($foundSubsection.Name)' found at line $($foundSubsection.LineNumber) in Reference Appendix. Reference Appendix must contain ONLY these subsections: $($Script:RequiredReferenceAppendixSubsections -join ', ')" -File $relativePath
        }
    }

    return $true
}

function Test-EssentialSetupMetaReference {
    <#
    .SYNOPSIS
    Detects meta-reference anti-pattern where Essential Setup references prerequisites in other sections.

    .DESCRIPTION
    Essential Setup should contain all prerequisite requirements directly with checkboxes.
    Meta-references like "Review Prerequisites Knowledge in Reference Appendix" are anti-patterns
    that force learners to hunt for critical setup information.

    This is an ERROR-level validation.
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'

    # Find Essential Setup section
    $setupStartLine = -1
    $setupEndLine = $lines.Length

    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+Essential Setup\s*$') {
            $setupStartLine = $i
        }
        elseif ($setupStartLine -ge 0 -and $lines[$i] -match '^##\s+') {
            # Next H2 section marks end of Essential Setup
            $setupEndLine = $i
            break
        }
    }

    if ($setupStartLine -eq -1) {
        # Essential Setup section missing (caught by other validation)
        return $false
    }

    # Extract Essential Setup content
    $setupContent = ($lines[$setupStartLine..$setupEndLine] -join "`n")

    # Pattern 1: Direct meta-reference to Prerequisites Knowledge in Reference Appendix
    if ($setupContent -match '(?i)(review|see|check|refer to|find).*prerequisite.*reference appendix') {
        $lineMatch = $null
        for ($i = $setupStartLine; $i -lt $setupEndLine; $i++) {
            if ($lines[$i] -match '(?i)(review|see|check|refer to|find).*prerequisite.*reference appendix') {
                $lineMatch = $i + 1
                break
            }
        }

        Write-ValidationLog -Level Error -Message "Meta-reference anti-pattern detected at line $lineMatch`: Essential Setup references prerequisites in Reference Appendix. Prerequisites must be directly in Essential Setup section with checkboxes, not referenced elsewhere." -File $relativePath
        return $true
    }

    # Pattern 2: Generic reference to "Reference Appendix for requirements/prerequisites"
    if ($setupContent -match '(?i)reference appendix.*(requirement|prerequisite|setup|preparation)') {
        $lineMatch = $null
        for ($i = $setupStartLine; $i -lt $setupEndLine; $i++) {
            if ($lines[$i] -match '(?i)reference appendix.*(requirement|prerequisite|setup|preparation)') {
                $lineMatch = $i + 1
                break
            }
        }

        Write-ValidationLog -Level Error -Message "Meta-reference anti-pattern detected at line $lineMatch`: Essential Setup references requirements in Reference Appendix. All requirements must be directly in Essential Setup section, not referenced elsewhere." -File $relativePath
        return $true
    }

    return $false
}

function Test-OrientationEfficiency {
    <#
    .SYNOPSIS
    Validates that orientation is efficient and gets learners into tasks quickly.

    .DESCRIPTION
    Checks the "5-minute rule":
    - Setup/Orientation section should have ≤5 actionable checkboxes
    - Pre-task content should be <100 lines
    - Minimal file references before Task 1 (≤5)
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $lines = $content -split '\r?\n'
    $hasWarnings = $false

    # Find frontmatter end
    $frontmatterEnd = 0
    $delimiterCount = 0
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $delimiterCount++
            if ($delimiterCount -eq 2) {
                $frontmatterEnd = $i
                break
            }
        }
    }

    # Find first Task line
    $firstTaskLine = $lines.Length
    for ($i = $frontmatterEnd; $i -lt $lines.Length; $i++) {
        if ($lines[$i] -match '^##\s+(Task \d+|Practice Tasks|Tasks)') {
            $firstTaskLine = $i
            break
        }
    }

    # Skip orientation efficiency checks for category READMEs (they don't have tasks)
    $isCategoryReadme = Test-IsCategoryReadme -FilePath $FilePath

    if ($isCategoryReadme) {
        return $false
    }

    # Rule 1: Pre-task content length check
    $preTaskLines = $firstTaskLine - $frontmatterEnd
    if ($preTaskLines -gt 100) {
        Write-ValidationLog -Level Warning -Message "Pre-task content is $preTaskLines lines (recommended: <100). Learners should reach hands-on tasks within first 5 minutes." -File $relativePath
        $hasWarnings = $true
    }

    # Rule 2: Setup/Orientation checkbox count
    $setupSection = ""
    $inSetup = $false

    for ($i = $frontmatterEnd; $i -lt $firstTaskLine; $i++) {
        if ($lines[$i] -match '^##\s+.*(Setup|Orientation|Getting Started)') {
            $inSetup = $true
        }
        elseif ($inSetup -and $lines[$i] -match '^##\s+') {
            break
        }
        if ($inSetup) {
            $setupSection += $lines[$i] + "`n"
        }
    }

    if ($setupSection) {
        $setupCheckboxes = ([regex]::Matches($setupSection, '- \[ \]')).Count
        if ($setupCheckboxes -gt 5) {
            Write-ValidationLog -Level Warning -Message "Setup/Orientation section has $setupCheckboxes checkboxes (recommended: ≤5 for 5-minute rule). Consider streamlining initial setup." -File $relativePath
            $hasWarnings = $true
        }
    }

    # Rule 3: File reference count before Task 1
    $preTaskContent = ($lines[$frontmatterEnd..$firstTaskLine] -join "`n")
    $fileReferences = ([regex]::Matches($preTaskContent, '`[^`]+\.(md|json|yaml|txt|sh|ps1)`')).Count

    if ($fileReferences -gt 5) {
        Write-ValidationLog -Level Warning -Message "Found $fileReferences file references before Task 1 (recommended: ≤5). Introduce files progressively as learners need them." -File $relativePath
        $hasWarnings = $true
    }

    return $hasWarnings
}

function Test-ResourceRedundancy {
    <#
    .SYNOPSIS
    Detects repeated mentions of the same resources across sections.

    .DESCRIPTION
    Validates single-source-of-truth principle:
    - Each file path should be mentioned ≤2 times total
    - Each chatmode should be described once, then referenced
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $hasWarnings = $false

    # Extract all file path references
    $filePathPattern = '`([^`]+\.(md|json|yaml|txt|sh|ps1|chatmode))`'
    $fileReferences = [regex]::Matches($content, $filePathPattern)

    $fileCount = @{}
    foreach ($match in $fileReferences) {
        $path = $match.Groups[1].Value
        if ($fileCount.ContainsKey($path)) {
            $fileCount[$path]++
        }
        else {
            $fileCount[$path] = 1
        }
    }

    # Report files mentioned >2 times
    $redundantFiles = $fileCount.Keys | Where-Object { $fileCount[$_] -gt 2 }
    foreach ($file in $redundantFiles) {
        Write-ValidationLog -Level Warning -Message "File '$file' mentioned $($fileCount[$file]) times. Consider introducing once and referencing thereafter." -File $relativePath
        $hasWarnings = $true
    }

    return $hasWarnings
}

function Test-ValidationConcreteness {
    <#
    .SYNOPSIS
    Validates that validation sections have concrete, actionable self-tests.

    .DESCRIPTION
    Checks for:
    - Concrete mechanisms: "list from memory", "read aloud", "explain in X sentences"
    - Avoid abstract: "can you demonstrate", "do you understand"
    #>
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $content = Get-Content -Path $FilePath -Raw
    $hasWarnings = $false

    # Find Validation section
    $validationMatch = [regex]::Match($content, '(?s)##\s+Validation.*?(?=(##|$))')
    if (-not $validationMatch.Success) {
        return $true  # No validation section to check
    }

    $validationContent = $validationMatch.Value

    # Check for abstract validation language
    $abstractPatterns = @(
        'can you demonstrate',
        'do you understand',
        'are you able to',
        'have you learned'
    )

    foreach ($pattern in $abstractPatterns) {
        if ($validationContent -match $pattern) {
            Write-ValidationLog -Level Warning -Message "Validation section contains abstract question '$pattern'. Prefer concrete self-tests like 'list from memory', 'read aloud', 'explain in N sentences'." -File $relativePath
            $hasWarnings = $true
        }
    }

    # Check for concrete validation mechanisms
    $concretePatterns = @(
        'list.*from memory',
        'read aloud',
        'explain in \d+ sentence',
        'show.*to.*colleague'
    )

    $hasConcreteTests = $false
    foreach ($pattern in $concretePatterns) {
        if ($validationContent -match $pattern) {
            $hasConcreteTests = $true
            break
        }
    }

    if (-not $hasConcreteTests) {
        Write-ValidationLog -Level Warning -Message "Validation section lacks concrete self-test mechanisms. Add actionable checks like 'list from memory', 'read aloud', or 'explain in N sentences'." -File $relativePath
        $hasWarnings = $true
    }

    return $hasWarnings
}

function Test-NestedCheckboxStructure {
    <#
    .SYNOPSIS
        Validates that checkboxes with nested content follow proper markdown structure patterns

    .DESCRIPTION
        Detects checkboxes followed by colons with nested bullets, blockquotes, code blocks, or numbered lists.
        These patterns cause CSS rendering issues:
        - Nested bullets lose list-style-type
        - Completed checkbox strikethrough propagates to nested content

        VALID PATTERNS:
        - [ ] Checkpoint: description text only
        - [ ] Task with inline text and **formatting**

        INVALID PATTERNS (Will trigger warnings):
        - [ ] Setup validation:
          - Step 1
          - Step 2

        - [ ] Task with nested code:
          ```bash
          command
          ```

        - [ ] Task with nested list:
          1. First
          2. Second

    .PARAMETER Content
        Full markdown content of the kata

    .PARAMETER FilePath
        Path to kata file being validated (for error reporting)

    .RETURNS
        Boolean indicating if warnings were found
    #>
    param(
        [string]$Content,
        [string]$FilePath
    )

    $relativePath = $FilePath.Replace($Script:ProjectRoot, '').TrimStart('\', '/')
    $hasWarnings = $false
    $lines = $Content -split "`n"

    for ($i = 0; $i -lt $lines.Count; $i++) {
        $currentLine = $lines[$i].TrimEnd()

        # Match checkbox lines ending with colon
        if ($currentLine -match '^\s*-\s*\[[ x]\]\s+.*:$') {
            # Look ahead for nested content patterns
            $nextLineIdx = $i + 1
            if ($nextLineIdx -lt $lines.Count) {
                $nextLine = $lines[$nextLineIdx].TrimEnd()

                # Detect nested bullets (unordered list)
                if ($nextLine -match '^\s{2,}-\s+') {
                    Write-ValidationLog -Level Warning -Message "Line $($i + 1): Checkbox followed by nested bullet list. Convert to flat checkbox structure or remove colon." -File $relativePath
                    $hasWarnings = $true
                }

                # Detect nested numbered list
                if ($nextLine -match '^\s{2,}\d+\.\s+') {
                    Write-ValidationLog -Level Warning -Message "Line $($i + 1): Checkbox followed by nested numbered list. Convert to flat checkbox structure or remove colon." -File $relativePath
                    $hasWarnings = $true
                }

                # Detect nested code block
                if ($nextLine -match '^\s{2,}```') {
                    Write-ValidationLog -Level Warning -Message "Line $($i + 1): Checkbox followed by nested code block. Convert to flat checkbox structure or remove colon." -File $relativePath
                    $hasWarnings = $true
                }

                # Detect nested blockquote
                if ($nextLine -match '^\s{2,}>') {
                    Write-ValidationLog -Level Warning -Message "Line $($i + 1): Checkbox followed by nested blockquote. Convert to flat checkbox structure or remove colon." -File $relativePath
                    $hasWarnings = $true
                }
            }
        }
    }

    return $hasWarnings
}

function Test-CategoryDirectory {
    if (-not (Test-Path $KataDirectory)) {
        Write-ValidationLog -Level Error -Message "Kata directory not found: $KataDirectory"
        return
    }

    $actualCategories = Get-ChildItem -Path $KataDirectory -Directory | ForEach-Object { $_.Name }

    if (-not $Script:Quiet) {
        Write-Information "📁 Found $($actualCategories.Count) category directories:" -InformationAction Continue
        foreach ($cat in $actualCategories) {
            Write-Information "   - $cat" -InformationAction Continue
        }
    }

    # Accept any category names - no validation against predefined list
    # This allows flexibility for different repositories

    return $actualCategories
}

function Initialize-CategoryStat {
    param([string[]]$Categories)

    foreach ($category in $Categories) {
        $categoryPath = Join-Path $KataDirectory $category
        $kataFiles = Get-ChildItem -Path $categoryPath -Recurse -Name "README.md" | Measure-Object

        $Script:CategoryStats[$category] = @{
            FileCount    = $kataFiles.Count
            ValidKatas   = 0
            InvalidKatas = 0
        }
    }
}

function Test-SchemaCompliance {
    <#
    .SYNOPSIS
    Validates frontmatter against the comprehensive JSON schema.

    .DESCRIPTION
    Performs comprehensive validation of all frontmatter fields against the JSON schema,
    including required fields, types, patterns, enums, array constraints, and nested objects.

    .PARAMETER Frontmatter
    The parsed YAML frontmatter as a hashtable.

    .PARAMETER FilePath
    The path to the kata file being validated.

    .EXAMPLE
    Test-SchemaCompliance -Frontmatter $frontmatter -FilePath $filePath
    #>
    param(
        [hashtable]$Frontmatter,
        [string]$FilePath
    )

    if (-not $Script:KataSchema) {
        # Schema not loaded, skip validation
        Write-ValidationLog -Level Warning -Message "Schema not loaded, skipping schema validation" -File (Get-RelativePath $FilePath)
        return $true
    }

    $relativePath = Get-RelativePath $FilePath
    $hasErrors = $false

    # Check required fields
    foreach ($requiredField in $Script:KataSchema.required) {
        if (-not $Frontmatter.ContainsKey($requiredField)) {
            Write-ValidationLog -Level Error -Message "Missing required field: $requiredField" -File $relativePath
            $hasErrors = $true
        }
    }

    # Validate each field present in frontmatter
    foreach ($fieldName in $Frontmatter.Keys) {
        $fieldValue = $Frontmatter[$fieldName]
        $schemaProperty = $Script:KataSchema.properties.$fieldName

        if (-not $schemaProperty) {
            Write-ValidationLog -Level Warning -Message "Unknown field: $fieldName (not in schema)" -File $relativePath
            continue
        }

        $fieldType = $schemaProperty.type

        # Type validation
        if ($fieldType) {
            $actualType = if ($null -eq $fieldValue) { 'null' }
            elseif ($fieldValue -is [array] -or $fieldValue -is [System.Collections.IList]) { 'array' }
            elseif ($fieldValue -is [hashtable]) { 'object' }
            elseif ($fieldValue -is [bool]) { 'boolean' }
            elseif ($fieldValue -is [int] -or $fieldValue -is [long]) { 'integer' }
            elseif ($fieldValue -is [double] -or $fieldValue -is [float]) { 'number' }
            else { 'string' }

            if ($actualType -ne $fieldType) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' has wrong type: expected $fieldType, got $actualType" -File $relativePath
                $hasErrors = $true
                continue
            }
        }

        # String validations
        if ($fieldType -eq 'string' -and $fieldValue) {
            # Pattern validation
            if ($schemaProperty.pattern) {
                if ($fieldValue -notmatch $schemaProperty.pattern) {
                    Write-ValidationLog -Level Error -Message "Field '$fieldName' does not match required pattern: $($schemaProperty.pattern)" -File $relativePath
                    $hasErrors = $true
                }
            }

            # Enum validation
            if ($schemaProperty.enum) {
                if ($fieldValue -notin $schemaProperty.enum) {
                    Write-ValidationLog -Level Error -Message "Field '$fieldName' must be one of: $($schemaProperty.enum -join ', ')" -File $relativePath
                    $hasErrors = $true
                }
            }

            # Length validation
            if ($schemaProperty.minLength -and $fieldValue.Length -lt $schemaProperty.minLength) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' is too short: minimum length is $($schemaProperty.minLength), got $($fieldValue.Length)" -File $relativePath
                $hasErrors = $true
            }
            if ($schemaProperty.maxLength -and $fieldValue.Length -gt $schemaProperty.maxLength) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' is too long: maximum length is $($schemaProperty.maxLength), got $($fieldValue.Length)" -File $relativePath
                $hasErrors = $true
            }
        }

        # Integer validations
        if ($fieldType -eq 'integer' -and $null -ne $fieldValue) {
            if ($schemaProperty.minimum -and $fieldValue -lt $schemaProperty.minimum) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' is too small: minimum is $($schemaProperty.minimum), got $fieldValue" -File $relativePath
                $hasErrors = $true
            }
            if ($schemaProperty.maximum -and $fieldValue -gt $schemaProperty.maximum) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' is too large: maximum is $($schemaProperty.maximum), got $fieldValue" -File $relativePath
                $hasErrors = $true
            }
        }

        # Array validations (check both array and IList types)
        $isArrayType = ($fieldValue -is [array]) -or ($fieldValue -is [System.Collections.IList])
        if ($fieldType -eq 'array' -and $isArrayType) {
            # Item count validation
            if ($schemaProperty.minItems -and $fieldValue.Count -lt $schemaProperty.minItems) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' has too few items: minimum is $($schemaProperty.minItems), got $($fieldValue.Count)" -File $relativePath
                $hasErrors = $true
            }
            if ($schemaProperty.maxItems -and $fieldValue.Count -gt $schemaProperty.maxItems) {
                Write-ValidationLog -Level Error -Message "Field '$fieldName' has too many items: maximum is $($schemaProperty.maxItems), got $($fieldValue.Count)" -File $relativePath
                $hasErrors = $true
            }

            # Array item validation
            if ($schemaProperty.items) {
                $itemSchema = $schemaProperty.items

                for ($i = 0; $i -lt $fieldValue.Count; $i++) {
                    $item = $fieldValue[$i]

                    # Validate item type
                    if ($itemSchema.type -eq 'object' -and $item -is [hashtable]) {
                        # Validate required properties in object
                        if ($itemSchema.required) {
                            foreach ($requiredProp in $itemSchema.required) {
                                if (-not $item.ContainsKey($requiredProp)) {
                                    Write-ValidationLog -Level Error -Message "Field '$fieldName[$i]' missing required property: $requiredProp" -File $relativePath
                                    $hasErrors = $true
                                }
                            }
                        }
                    }
                    elseif ($itemSchema.type -eq 'string') {
                        # Validate string item constraints
                        if ($itemSchema.minLength -and $item.Length -lt $itemSchema.minLength) {
                            Write-ValidationLog -Level Error -Message "Field '$fieldName[$i]' is too short: minimum length is $($itemSchema.minLength)" -File $relativePath
                            $hasErrors = $true
                        }
                        if ($itemSchema.pattern -and $item -notmatch $itemSchema.pattern) {
                            Write-ValidationLog -Level Error -Message "Field '$fieldName[$i]' does not match required pattern" -File $relativePath
                            $hasErrors = $true
                        }
                    }
                }
            }
        }

        # Object validations
        if ($fieldType -eq 'object' -and $fieldValue -is [hashtable]) {
            # Validate required properties
            if ($schemaProperty.required) {
                foreach ($requiredProp in $schemaProperty.required) {
                    if (-not $fieldValue.ContainsKey($requiredProp)) {
                        Write-ValidationLog -Level Error -Message "Field '$fieldName' missing required property: $requiredProp" -File $relativePath
                        $hasErrors = $true
                    }
                }
            }
        }
    }

    # Return true if no errors (warnings don't fail validation)
    return -not $hasErrors
}

function Test-SingleKata {
    param([string]$FilePath)

    $relativePath = Get-RelativePath $FilePath
    $fileName = Split-Path -Leaf $FilePath

    if (-not $Script:Quiet) {
        Write-Information "🔍 Validating: $relativePath" -InformationAction Continue
    }

    $frontmatter = Get-YamlFrontmatter -FilePath $FilePath
    if (-not $frontmatter) {
        return
    }

    # Determine file type: README.md uses docs headers, numbered katas use kata schema
    $isReadme = Test-IsCategoryReadme -FilePath $FilePath
    $isNumberedKata = $fileName -match '^\d\d-.*\.md$'

    # Validation logic: Only apply kata-specific validations to numbered kata files
    # README.md files are category overviews with docs headers (ms.author, ms.service, etc.)
    # and should not be validated against the kata frontmatter schema
    if (-not $Script:Quiet -and $isReadme) {
        Write-Debug "Skipping kata schema validation for category README: $relativePath"
    }

    # Determine which validations to run
    $runAll = $Script:ValidationTypes -contains 'All'
    $runTemplate = $runAll -or $Script:ValidationTypes -contains 'Template'
    $runCategories = $runAll -or $Script:ValidationTypes -contains 'Categories'
    $runPrerequisites = $runAll -or $Script:ValidationTypes -contains 'Prerequisites'
    $runFields = $runAll -or $Script:ValidationTypes -contains 'Fields'
    $runQuality = $runAll -or $Script:ValidationTypes -contains 'Quality'
    $runStructure = $runAll -or $Script:ValidationTypes -contains 'Structure'

    # Always run content quality checks (critical for kata standards compliance)
    Test-ContentQuality -FilePath $FilePath

    # Only run kata-specific required sections check for numbered katas
    if ($isNumberedKata) {
        Test-RequiredSection -FilePath $FilePath
    }

    # Only run strict structural validations for numbered kata files (not category READMEs)
    if ($isNumberedKata) {
        Test-SectionOrdering -FilePath $FilePath
        Test-ReferenceAppendixStructure -FilePath $FilePath
        Test-EssentialSetupMetaReference -FilePath $FilePath
    }

    # Run quality checks if requested (only for numbered katas)
    if ($runQuality -and $isNumberedKata) {
        Test-RedundantSection -FilePath $FilePath -Frontmatter $frontmatter
        Test-OrientationEfficiency -FilePath $FilePath
        Test-ResourceRedundancy -FilePath $FilePath
        Test-ValidationConcreteness -FilePath $FilePath
    }

    # Run structure checks if requested (only for numbered katas)
    if ($runStructure -and $isNumberedKata) {
        $fileContent = Get-Content -Path $FilePath -Raw
        Test-NestedCheckboxStructure -Content $fileContent -FilePath $FilePath
    }

    # Only validate kata-specific fields for numbered kata files, not READMEs
    if ($runFields -and $isNumberedKata) {
        Test-RequiredField -Frontmatter $frontmatter -FilePath $FilePath
        Test-SchemaCompliance -Frontmatter $frontmatter -FilePath $FilePath
    }

    # Only validate template compliance for numbered kata files
    if ($runTemplate -and $isNumberedKata) {
        Test-TemplateCompliance -Frontmatter $frontmatter -FilePath $FilePath
    }

    # Category validation applies to all files
    if ($runCategories) {
        Test-Category -Frontmatter $frontmatter -FilePath $FilePath
        Test-Tag -Frontmatter $frontmatter -FilePath $FilePath
    }

    # Prerequisite validation only for numbered kata files
    if ($runPrerequisites -and $isNumberedKata) {
        Test-Prerequisite -Frontmatter $frontmatter -FilePath $FilePath
    }

    # Update category stats if running category validation
    if ($runCategories) {
        $category = $frontmatter['category']
        if ($category -and $Script:CategoryStats.ContainsKey($category)) {
            if ($Script:Errors.Count -eq 0) {
                $Script:CategoryStats[$category].ValidKatas++
            }
            else {
                $Script:CategoryStats[$category].InvalidKatas++
            }
        }
    }
}

function Show-ValidationSummary {
    Write-Output "`n📊 Validation Summary:"

    # Show category statistics if categories were validated
    if ($Script:ValidationTypes -contains 'All' -or $Script:ValidationTypes -contains 'Categories') {
        if ($Script:CategoryStats.Count -gt 0) {
            Write-Output "`n📂 Category Statistics:"
            $totalKatas = 0
            $totalValid = 0

            foreach ($category in $Script:CategoryStats.Keys) {
                $stats = $Script:CategoryStats[$category]
                $totalKatas += $stats.FileCount
                $totalValid += $stats.ValidKatas
                $status = if ($stats.InvalidKatas -eq 0) { "✅" } else { "❌" }
                Write-Output "   $status $category`: $($stats.ValidKatas)/$($stats.FileCount) valid"
            }

            Write-Output "`n📈 Overall Statistics:"
            Write-Output "   📚 Total katas: $totalKatas"
            Write-Output "   ✅ Valid katas: $totalValid"
            Write-Output "   ❌ Invalid katas: $($totalKatas - $totalValid)"
            Write-Output "   🏷️  Categories: $($Script:CategoryStats.Keys.Count)"
        }
    }

    Write-Output "`n📋 Validation Results:"
    Write-Output "   📚 Files validated: $($Script:KataFiles.Count)"
    Write-Output "   ❌ Errors: $($Script:Errors.Count)"
    Write-Output "   ⚠️  Warnings: $($Script:Warnings.Count)"

    if ($Script:Errors.Count -gt 0) {
        Write-Output "`n🔍 Error Details:"
        foreach ($errorEntry in $Script:Errors) {
            $fileContext = if ($errorEntry.File) { " [$($errorEntry.File)]" } else { "" }
            Write-Output "   ❌ $($errorEntry.Message)$fileContext"
        }
    }

    if ($Script:Warnings.Count -gt 0) {
        Write-Output "`n⚠️  Warning Details:"
        foreach ($warningEntry in $Script:Warnings) {
            $fileContext = if ($warningEntry.File) { " [$($warningEntry.File)]" } else { "" }
            Write-Output "   ⚠️  $($warningEntry.Message)$fileContext"
        }
    }

    $status = if ($Script:Errors.Count -eq 0) { "✅ PASS" } else { "❌ FAIL" }
    Write-Output "`n🎯 Overall Status: $status"
}

function Invoke-KataValidation {
    $validationTypesList = $Script:ValidationTypes -join ', '

    if (-not $Script:Quiet) {
        Write-Information "🚀 Starting kata validation ($validationTypesList)...`n" -InformationAction Continue
    }

    # Initialize based on validation types
    $runCategories = $Script:ValidationTypes -contains 'All' -or $Script:ValidationTypes -contains 'Categories'

    if ($runCategories) {
        $categories = Test-CategoryDirectory
        Initialize-CategoryStat -Categories $categories
    }

    $kataFiles = Find-KataFile

    if ($kataFiles.Count -eq 0) {
        Write-ValidationLog -Level Error -Message "No kata files found to validate"
        return $false
    }

    foreach ($filePath in $kataFiles) {
        Test-SingleKata -FilePath $filePath
    }

    Show-ValidationSummary
    return $Script:Errors.Count -eq 0
}

function Repair-KataContent {
    <#
    .SYNOPSIS
    Fixes programmatically correctable content issues in kata files.

    .DESCRIPTION
    Applies automated fixes for common issues discovered during Phase 4 remediation:
    - Master language → Learn language (inclusive language compliance)
    - Orphaned YAML blocks (excess --- delimiters beyond first frontmatter pair)
    - Runs markdownlint --fix for compliance

    .PARAMETER FilePath
    Path to the kata file to repair
    #>
    param(
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    Write-Information "🔧 Fixing content issues in: $relativePath" -InformationAction Continue

    $content = Get-Content $FilePath -Raw
    $lines = $content -split '\r?\n'
    $fixesApplied = @()

    # Fix 1: Replace "Master" language with inclusive alternatives
    $masterReplacements = @{
        '\bMaster deploying\b' = 'Learn to deploy'
        '\bMaster how\b'       = 'Learn how'
        '\bMaster complex\b'   = 'Learn complex'
        '\bMaster advanced\b'  = 'Learn advanced'
        '\bMaster the\b'       = 'Learn the'
        '\bMaster\s+([a-z])'   = 'Learn $1'  # General "Master <word>" → "Learn <word>"
        '\bMastery\b'          = 'Proficiency'
        '\bmaster-slave\b'     = 'primary-secondary'
        '\bmaster node\b'      = 'primary node'
        '\bmaster branch\b'    = 'main branch'
    }

    $originalContent = $content
    foreach ($pattern in $masterReplacements.Keys) {
        $replacement = $masterReplacements[$pattern]
        if ($content -match $pattern) {
            $content = $content -replace $pattern, $replacement
            $fixesApplied += "Replaced '$pattern' with '$replacement'"
        }
    }

    if ($content -ne $originalContent) {
        Write-Information "   ✅ Fixed Master language issues" -InformationAction Continue
    }

    # Fix 2: Remove orphaned YAML blocks (excess --- delimiters)
    # Strategy: Find all --- delimiters, keep first 2 (frontmatter), investigate extras
    $lines = $content -split '\r?\n'
    $delimiterIndices = @()
    for ($i = 0; $i -lt $lines.Length; $i++) {
        if ($lines[$i].Trim() -eq '---') {
            $delimiterIndices += $i
        }
    }

    if ($delimiterIndices.Count -gt 4) {
        # More than 4 delimiters = definitely orphaned YAML
        Write-Information "   🔍 Found $($delimiterIndices.Count) delimiters, removing orphaned YAML blocks" -InformationAction Continue

        # Keep first 2 (frontmatter), remove delimiters 3-4 if they appear before line 200
        $linesToRemove = @()
        for ($i = 2; $i -lt $delimiterIndices.Count; $i++) {
            $delimiterLine = $delimiterIndices[$i]
            if ($delimiterLine -lt 200) {
                # Check if this is part of an orphaned YAML block (preceded/followed by YAML-like content)
                $prevLine = if ($delimiterLine -gt 0) { $lines[$delimiterLine - 1] } else { "" }
                $nextLine = if ($delimiterLine -lt $lines.Length - 1) { $lines[$delimiterLine + 1] } else { "" }

                # If surrounded by YAML-like content (key: value patterns), mark for removal
                if ($prevLine -match '^\s*[a-z_]+:\s' -or $nextLine -match '^\s*[a-z_]+:\s') {
                    Write-Information "   🗑️  Removing orphaned YAML block around line $($delimiterLine + 1)" -InformationAction Continue

                    # Find the block boundaries (from this delimiter to next delimiter or next non-YAML line)
                    $blockStart = $delimiterLine
                    $blockEnd = $delimiterLine

                    # Find block end (next delimiter or non-YAML content)
                    for ($j = $delimiterLine + 1; $j -lt $lines.Length; $j++) {
                        if ($lines[$j].Trim() -eq '---') {
                            $blockEnd = $j
                            break
                        }
                        if ($lines[$j].Trim() -ne '' -and $lines[$j] -notmatch '^\s*[a-z_]+:\s' -and $lines[$j] -notmatch '^\s*-\s') {
                            $blockEnd = $j - 1
                            break
                        }
                        $blockEnd = $j
                    }

                    # Mark all lines in block for removal
                    for ($k = $blockStart; $k -le $blockEnd; $k++) {
                        $linesToRemove += $k
                    }

                    $fixesApplied += "Removed orphaned YAML block (lines $($blockStart + 1)-$($blockEnd + 1))"
                }
            }
        }

        # Remove marked lines
        if ($linesToRemove.Count -gt 0) {
            $newLines = @()
            for ($i = 0; $i -lt $lines.Length; $i++) {
                if ($i -notin $linesToRemove) {
                    $newLines += $lines[$i]
                }
            }
            $content = $newLines -join "`n"
            Write-Information "   ✅ Removed $($linesToRemove.Count) lines of orphaned YAML" -InformationAction Continue
        }
    }
    elseif ($delimiterIndices.Count -eq 4) {
        # Exactly 4 delimiters - check if 3rd and 4th are in first 200 lines (duplicate frontmatter pattern)
        $thirdDelim = $delimiterIndices[2]
        $fourthDelim = $delimiterIndices[3]

        if ($thirdDelim -lt 200 -and $fourthDelim -lt 200) {
            # Check if lines between 3rd and 4th delimiters look like duplicate frontmatter
            $blockLines = $lines[($thirdDelim + 1)..($fourthDelim - 1)]
            $yamlLikeLines = ($blockLines | Where-Object { $_ -match '^\s*[a-z_]+:\s' }).Count

            if ($yamlLikeLines -gt 3) {
                Write-Information "   🗑️  Removing duplicate frontmatter block (lines $($thirdDelim + 1)-$($fourthDelim + 1))" -InformationAction Continue

                $newLines = @()
                for ($i = 0; $i -lt $lines.Length; $i++) {
                    if ($i -lt $thirdDelim -or $i -gt $fourthDelim) {
                        $newLines += $lines[$i]
                    }
                }
                $content = $newLines -join "`n"
                $fixesApplied += "Removed duplicate frontmatter block (lines $($thirdDelim + 1)-$($fourthDelim + 1))"
                Write-Information "   ✅ Removed duplicate frontmatter" -InformationAction Continue
            }
        }
    }

    # Write fixed content back to file
    try {
        Set-Content -Path $FilePath -Value $content -Encoding UTF8 -NoNewline
        if ($fixesApplied.Count -gt 0) {
            Write-Information "   ✅ Applied $($fixesApplied.Count) fix(es) to $relativePath" -InformationAction Continue
        }
    }
    catch {
        Write-ValidationLog -Level Error -Message "Failed to write fixed content: $($_.Exception.Message)" -File $relativePath
        return
    }

    # Fix 3: Run markdownlint --fix for compliance
    try {
        $markdownlintResult = & npx -c "markdownlint-cli2" -- "--fix" "$FilePath" 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Information "   ✅ Markdownlint validation passed (0 errors)" -InformationAction Continue
        }
        else {
            Write-ValidationLog -Level Warning -Message "Markdownlint reported issues: $markdownlintResult" -File $relativePath
        }
    }
    catch {
        Write-ValidationLog -Level Warning -Message "Failed to run markdownlint: $($_.Exception.Message)" -File $relativePath
    }
}

function Repair-KataFrontmatter {
    param(
        [string]$FilePath
    )

    $relativePath = Get-RelativePath $FilePath
    Write-Information "🔧 Fixing frontmatter issues in: $relativePath" -InformationAction Continue

    $content = Get-Content $FilePath -Raw
    $frontmatterMatch = [regex]::Match($content, '(?s)^---\s*\n(.*?)\n---')

    if (-not $frontmatterMatch.Success) {
        Write-ValidationLog -Level Error -Message "No frontmatter found to fix" -File $relativePath
        return
    }

    $frontmatterText = $frontmatterMatch.Groups[1].Value
    $bodyContent = $content.Substring($frontmatterMatch.Length).TrimStart()

    # Common field mappings for auto-fix
    $fieldMappings = @{
        'type'               = ''  # Remove this field
        'learning_path'      = ''  # Remove this field
        'prerequisites'      = ''  # Remove this field
        'completed'          = ''  # Remove this field
        'github_discussions' = ''  # Remove this field
        'share_link'         = ''  # Remove this field
        'notes_file'         = ''  # Remove this field
        'estimated_duration' = 'duration'  # Map to duration
        'components'         = ''  # Remove nested field
        'causes'             = ''  # Remove nested field
        'blueprints'         = ''  # Remove nested field
        'solutions'          = ''  # Remove nested field unless it's the special solution field
        'instructions'       = ''  # Remove nested field
        'symptoms'           = ''  # Remove nested field
        'escalation_path'    = ''  # Remove nested field
        'common_issues'      = ''  # Remove nested field
        'solution'           = ''  # Remove this standalone field
    }

    # Apply field mappings and add missing required fields
    $lines = $frontmatterText -split '\n'
    $newLines = @()
    $processedFields = @{}

    foreach ($line in $lines) {
        if ($line -match '^(\s*)([^:]+):\s*(.*)$') {
            $indent = $Matches[1]
            $field = $Matches[2].Trim()
            $value = $Matches[3]

            if ($fieldMappings.ContainsKey($field)) {
                $newField = $fieldMappings[$field]
                if ($newField) {
                    $newLines += "$indent$newField`: $value"
                    $processedFields[$newField] = $true
                }
                # Skip removed fields
            }
            else {
                $newLines += $line
                $processedFields[$field] = $true
            }
        }
        else {
            $newLines += $line
        }
    }

    # Add missing required fields with proper structure from template
    $requiredDefaults = @{
        'repository_integration' = @'
repository_integration:
  blueprints:
    - blueprint-name/
  components:
    - src/category/component-name/
  instructions:
    - instruction-file.instructions.md
'@
        'troubleshooting_guide'  = @'
troubleshooting_guide:
  common_issues:
    - issue: Common Problem
      symptoms: How this manifests
      causes: Why this happens
      solutions: How to fix it
  escalation_path:
    - Learning platform documentation
    - Community forums or support channels
'@
        'tags'                   = @'
tags:
  - learning
  - hve-learning
'@
    }

    foreach ($field in $requiredDefaults.Keys) {
        if (-not $processedFields.ContainsKey($field)) {
            $newLines += $requiredDefaults[$field]
        }
    }

    # Reconstruct the file
    $newFrontmatter = ($newLines | Where-Object { $_ -ne '' }) -join "`n"
    $newContent = "---`n$newFrontmatter`n---`n`n$bodyContent"

    try {
        Set-Content -Path $FilePath -Value $newContent -Encoding UTF8
        Write-Information "✅ Fixed frontmatter for: $relativePath" -InformationAction Continue
    }
    catch {
        Write-ValidationLog -Level Error -Message "Failed to write fixed content: $($_.Exception.Message)" -File $relativePath
    }
}

# Main execution - always run when script is executed
try {
    if ($Script:FixCommonIssues) {
            # Auto-fix mode - find all individual kata files
            Write-Information "🔧 Running auto-fix mode for individual kata files..." -InformationAction Continue

            if (-not (Test-Path $KataDirectory)) {
                Write-Error "Kata directory not found: $KataDirectory"
                exit 1
            }

            $individualKataFiles = Get-ChildItem -Path $KataDirectory -Recurse -Filter "*.md" |
            Where-Object { $_.Name -notmatch "README\.md" -and $_.Name -match "^\d\d-.*\.md$" } |
            ForEach-Object { $_.FullName }

            Write-Information "📚 Found $($individualKataFiles.Count) individual kata files to fix" -InformationAction Continue

            foreach ($filePath in $individualKataFiles) {
                # Fix frontmatter field issues (existing functionality)
                Repair-KataFrontmatter -FilePath $filePath

                # Fix content issues (NEW: Master language, orphaned YAML, markdownlint)
                Repair-KataContent -FilePath $filePath
            }

            Write-Information "`n✅ Auto-fix completed for $($individualKataFiles.Count) files" -InformationAction Continue
            Write-Information "   🔍 Run validation to verify fixes: .\Validate-Katas.ps1" -InformationAction Continue
        }
        else {
            # Normal validation mode
            $success = Invoke-KataValidation
            $exitCode = if ($success) { 0 } else { 1 }

            # Always emit a final, pipeline-friendly status line.
            # (Some hosts/piping setups do not consistently surface the summary footer.)
            [Console]::Out.WriteLine($(if ($success) { 'VALIDATION_STATUS=PASSED' } else { 'VALIDATION_STATUS=FAILED' }))
            [Console]::Out.Flush()

            exit $exitCode
        }
    }
    catch {
        Write-Error "💥 Validation failed with error: $($_.Exception.Message)"
        exit 1
    }
