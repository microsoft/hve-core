# Validate-MarkdownFrontmatter.ps1
#
# Purpose: Validates frontmatter consistency and footer presence across markdown files
# Author: HVE Core Team
# Created: 2025-11-05
#
# This script validates:
# - Required frontmatter fields (title, description, author, ms.date)
# - Date format (ISO 8601: YYYY-MM-DD)
# - Standard Copilot attribution footer (excludes Microsoft template files)
# - Content structure by file type (GitHub configs, DevContainer docs, etc.)

#requires -Version 7.0

using namespace System.Collections.Generic

param(
    [Parameter(Mandatory = $false)]
    [string[]]$Paths = @('.'),

    [Parameter(Mandatory = $false)]
    [string[]]$Files = @(),

    [Parameter(Mandatory = $false)]
    [string[]]$ExcludePaths = @(),

    [Parameter(Mandatory = $false)]
    [switch]$WarningsAsErrors,

    [Parameter(Mandatory = $false)]
    [switch]$ChangedFilesOnly,

    [Parameter(Mandatory = $false)]
    [string]$BaseBranch = "origin/main",

    [Parameter(Mandatory = $false)]
    [switch]$SkipFooterValidation,

    [Parameter(Mandatory = $false)]
    [switch]$EnableSchemaValidation
)

# Import LintingHelpers module
Import-Module (Join-Path -Path $PSScriptRoot -ChildPath 'Modules/LintingHelpers.psm1') -Force

#region Type Definitions

class FrontmatterResult {
    [hashtable]$Frontmatter
    [int]$FrontmatterEndIndex
    [string]$Content

    FrontmatterResult([hashtable]$frontmatter, [int]$endIndex, [string]$content) {
        $this.Frontmatter = $frontmatter
        $this.FrontmatterEndIndex = $endIndex
        $this.Content = $content
    }
}

class SchemaValidationResult {
    [bool]$IsValid
    [string[]]$Errors
    [string[]]$Warnings
    [string]$SchemaUsed
    [string]$Note

    SchemaValidationResult([bool]$isValid, [string[]]$errors, [string[]]$warnings, [string]$schemaUsed, [string]$note) {
        $this.IsValid = $isValid
        $this.Errors = if ($null -eq $errors) { @() } else { $errors }
        $this.Warnings = if ($null -eq $warnings) { @() } else { $warnings }
        $this.SchemaUsed = $schemaUsed
        $this.Note = $note
    }
}

class ValidationResult {
    [string[]]$Errors
    [string[]]$Warnings
    [bool]$HasIssues
    [int]$TotalFilesChecked

    ValidationResult([string[]]$errors, [string[]]$warnings, [bool]$hasIssues, [int]$totalFiles) {
        $this.Errors = if ($null -eq $errors) { @() } else { $errors }
        $this.Warnings = if ($null -eq $warnings) { @() } else { $warnings }
        $this.HasIssues = $hasIssues
        $this.TotalFilesChecked = $totalFiles
    }
}

class FileTypeInfo {
    [bool]$IsGitHub
    [bool]$IsChatMode
    [bool]$IsPrompt
    [bool]$IsInstruction
    [bool]$IsRootCommunityFile
    [bool]$IsDevContainer
    [bool]$IsVSCodeReadme
    [bool]$IsDocsFile

    FileTypeInfo() {
        $this.IsGitHub = $false
        $this.IsChatMode = $false
        $this.IsPrompt = $false
        $this.IsInstruction = $false
        $this.IsRootCommunityFile = $false
        $this.IsDevContainer = $false
        $this.IsVSCodeReadme = $false
        $this.IsDocsFile = $false
    }
}

#endregion Type Definitions

function ConvertFrom-YamlFrontmatter {
    <#
    .SYNOPSIS
    Parses YAML frontmatter content string into a hashtable.

    .DESCRIPTION
    Pure function that converts raw YAML frontmatter text into a structured hashtable.
    Handles scalar values, JSON-style arrays, and YAML block arrays.
    Does not perform file I/O - accepts content string directly.

    .PARAMETER Content
    The raw markdown content string containing YAML frontmatter.

    .INPUTS
    [string] Raw markdown content with YAML frontmatter delimited by '---'.

    .OUTPUTS
    [FrontmatterResult] Object containing:
      - Frontmatter: Parsed key-value hashtable
      - FrontmatterEndIndex: Line index where frontmatter ends
      - Content: Remaining markdown content after frontmatter

    Returns $null if content lacks valid frontmatter delimiters.

    .EXAMPLE
    $content = Get-Content -Path 'README.md' -Raw
    $result = ConvertFrom-YamlFrontmatter -Content $content
    $result.Frontmatter['title']

    .EXAMPLE
    $yaml = @"
---
title: My Document
tags: [a, b, c]
---
# Content here
"@
    $parsed = ConvertFrom-YamlFrontmatter -Content $yaml
    # $parsed.Frontmatter = @{ title = 'My Document'; tags = @('a','b','c') }

    .NOTES
    This is a pure function with no side effects. Error handling returns $null
    rather than throwing exceptions to support pipeline operations.
    #>
    [CmdletBinding()]
    [OutputType([FrontmatterResult])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    process {
        if ([string]::IsNullOrEmpty($Content) -or -not $Content.StartsWith('---')) {
            return $null
        }

        $lines = $Content -split "`n"
        $endIndex = -1

        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].Trim() -eq '---') {
                $endIndex = $i
                break
            }
        }

        if ($endIndex -eq -1) {
            return $null
        }

        $frontmatterLines = $lines[1..($endIndex - 1)]
        $frontmatter = @{}

        foreach ($line in $frontmatterLines) {
            $trimmedLine = $line.Trim()
            if ($trimmedLine -eq '' -or $trimmedLine.StartsWith('#')) {
                continue
            }

            if ($line -match '^([^:]+):\s*(.*)$') {
                $key = $matches[1].Trim()
                $value = $matches[2].Trim()

                if ($value.StartsWith('[') -and $value.EndsWith(']')) {
                    try {
                        $frontmatter[$key] = $value | ConvertFrom-Json
                    }
                    catch {
                        $frontmatter[$key] = $value
                    }
                }
                elseif ($value.StartsWith('-') -or $value -eq '') {
                    $arrayValues = @()
                    if ($value.StartsWith('-')) {
                        $arrayValues += $value.Substring(1).Trim()
                    }

                    $j = $frontmatterLines.IndexOf($line) + 1
                    while ($j -lt $frontmatterLines.Count -and $frontmatterLines[$j].StartsWith('  -')) {
                        $arrayValues += $frontmatterLines[$j].Substring(3).Trim()
                        $j++
                    }

                    $frontmatter[$key] = if ($arrayValues.Count -gt 0) { $arrayValues } else { $value }
                }
                else {
                    if (($value.StartsWith('"') -and $value.EndsWith('"')) -or
                        ($value.StartsWith("'") -and $value.EndsWith("'"))) {
                        $value = $value.Substring(1, $value.Length - 2)
                    }
                    $frontmatter[$key] = $value
                }
            }
        }

        $remainingContent = ($lines[($endIndex + 1)..($lines.Count - 1)] -join "`n")
        return [FrontmatterResult]::new($frontmatter, ($endIndex + 1), $remainingContent)
    }
}

function Get-MarkdownFrontmatter {
    <#
    .SYNOPSIS
    Extracts YAML frontmatter from a markdown file or content string.

    .DESCRIPTION
    Parses YAML frontmatter and returns a structured object containing the
    frontmatter data and remaining content. Supports both file path and
    direct content input via parameter sets.

    .PARAMETER FilePath
    Path to the markdown file to parse. Mutually exclusive with -Content.

    .PARAMETER Content
    Raw markdown content string to parse. Mutually exclusive with -FilePath.

    .INPUTS
    [string] File path or content string depending on parameter set.

    .OUTPUTS
    [FrontmatterResult] Object containing:
      - Frontmatter: Parsed key-value hashtable
      - FrontmatterEndIndex: Line index where frontmatter ends
      - Content: Remaining markdown content after frontmatter

    Returns $null if:
      - File not found (FilePath parameter set)
      - Content lacks valid frontmatter delimiters
      - Malformed YAML frontmatter (unclosed delimiter)

    .EXAMPLE
    # Read from file
    $result = Get-MarkdownFrontmatter -FilePath 'docs/README.md'
    if ($result) {
        Write-Host "Title: $($result.Frontmatter['title'])"
    }

    .EXAMPLE
    # Parse content directly (for testing)
    $markdown = @"
---
title: Test Doc
description: A test document
---
# Heading
Body content
"@
    $result = Get-MarkdownFrontmatter -Content $markdown
    $result.Frontmatter['description']  # Returns 'A test document'

    .NOTES
    File operations emit warnings on error but do not throw exceptions.
    #>
    [CmdletBinding(DefaultParameterSetName = 'FilePath')]
    [OutputType([FrontmatterResult])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'FilePath', Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $true, ParameterSetName = 'Content', ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq 'FilePath') {
            if (-not (Test-Path $FilePath)) {
                Write-Warning "File not found: $FilePath"
                return $null
            }

            try {
                $Content = Get-Content -Path $FilePath -Raw -Encoding UTF8
            }
            catch {
                Write-Warning "Error reading file ${FilePath}: [$($_.Exception.GetType().Name)] $($_.Exception.Message)"
                return $null
            }
        }

        $result = ConvertFrom-YamlFrontmatter -Content $Content

        if ($null -eq $result -and $PSCmdlet.ParameterSetName -eq 'FilePath') {
            if ($Content.StartsWith('---')) {
                Write-Warning "Malformed YAML frontmatter in: $FilePath"
            }
        }

        return $result
    }
}

function Test-MarkdownFooter {
    <#
    .SYNOPSIS
    Checks if markdown content contains the standard Copilot attribution footer.

    .DESCRIPTION
    Pure function that validates markdown content ends with the standard Copilot
    attribution footer. Normalizes content by removing HTML comments and markdown
    formatting before pattern matching.

    Supported footer variants:
    - Plain text footer
    - Markdownlint-wrapped footer (with HTML comments)
    - Bold/italic formatted footer

    .PARAMETER Content
    The markdown content string to validate (typically from FrontmatterResult.Content).

    .INPUTS
    [string] Markdown content string.

    .OUTPUTS
    [bool] $true if valid footer present; $false otherwise.

    .EXAMPLE
    $frontmatter = Get-MarkdownFrontmatter -FilePath 'README.md'
    $hasFooter = Test-MarkdownFooter -Content $frontmatter.Content
    if (-not $hasFooter) {
        Write-Warning "Missing Copilot attribution footer"
    }

    .EXAMPLE
    # Direct content validation
    $content = "Some content`n`n🤖 Crafted with precision by ✨Copilot following brilliant human instruction, carefully refined by our team of discerning human reviewers."
    Test-MarkdownFooter -Content $content  # Returns $true

    .NOTES
    Footer pattern is flexible to accommodate minor variations in punctuation
    and whitespace while maintaining consistent attribution messaging.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
        [AllowEmptyString()]
        [string]$Content
    )

    process {
        if ([string]::IsNullOrEmpty($Content)) {
            return $false
        }

        $normalized = $Content -replace '(?s)<!--.*?-->', ''
        $normalized = $normalized -replace '\*\*([^*]+)\*\*', '$1'
        $normalized = $normalized -replace '__([^_]+)__', '$1'
        $normalized = $normalized -replace '\*([^*]+)\*', '$1'
        $normalized = $normalized -replace '_([^_]+)_', '$1'
        $normalized = $normalized -replace '~~([^~]+)~~', '$1'
        $normalized = $normalized -replace '`([^`]+)`', '$1'
        $normalized = $normalized.TrimEnd()

        $pattern = '🤖\s*Crafted\s+with\s+precision\s+by\s+✨Copilot\s+following\s+brilliant\s+human\s+instruction[,\s]+(then\s+)?carefully\s+refined\s+by\s+our\s+team\s+of\s+discerning\s+human\s+reviewers\.?'

        return $normalized -match $pattern
    }
}

function Initialize-JsonSchemaValidation {
    <#
    .SYNOPSIS
    Validates that PowerShell JSON processing capabilities are available.

    .DESCRIPTION
    Pure function that tests whether PowerShell can process JSON data,
    which is required for JSON Schema validation operations. Does not
    load external modules or modify state.

    .INPUTS
    None.

    .OUTPUTS
    [bool] $true if JSON processing is available; $false otherwise.

    .EXAMPLE
    if (Initialize-JsonSchemaValidation) {
        $schema = Get-Content 'schema.json' | ConvertFrom-Json
    }

    .NOTES
    PowerShell 7+ includes built-in JSON support via ConvertFrom-Json
    and ConvertTo-Json cmdlets. This function verifies that capability.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    try {
        $testJson = '{"test": "value"}' | ConvertFrom-Json
        return ($null -ne $testJson)
    }
    catch {
        Write-Warning "Error initializing schema validation: $_"
        return $false
    }
}

function Get-SchemaForFile {
    <#
    .SYNOPSIS
    Determines the appropriate JSON Schema for a given file path.

    .DESCRIPTION
    Resolves the correct JSON Schema to use for validating a file's frontmatter
    based on the schema-mapping.json configuration. Matches file paths against
    glob patterns defined in the mapping rules.

    Pattern matching priority:
    1. Directory-based patterns (e.g., 'docs/**/*.md')
    2. Pipe-separated root file patterns (e.g., 'README.md|CONTRIBUTING.md')
    3. Simple file patterns
    4. Default schema fallback

    .PARAMETER FilePath
    Absolute or relative path to the file needing schema resolution.

    .PARAMETER RepoRoot
    Repository root directory for computing relative paths. If not specified,
    attempts to locate .git directory by walking up the directory tree.

    .PARAMETER SchemaDirectory
    Directory containing JSON Schema files. Defaults to 'schemas' subdirectory
    relative to this script.

    .INPUTS
    [string] File path to resolve schema for.

    .OUTPUTS
    [string] Absolute path to the appropriate JSON Schema file.
    Returns $null if no schema applies or configuration is missing.

    .EXAMPLE
    $schema = Get-SchemaForFile -FilePath 'docs/getting-started/README.md'
    # Returns path to docs-frontmatter.schema.json

    .EXAMPLE
    $schema = Get-SchemaForFile -FilePath '.github/instructions/shell.instructions.md' -RepoRoot '/repo'
    # Returns path to instruction-frontmatter.schema.json

    .NOTES
    Relies on schema-mapping.json in the SchemaDirectory for pattern definitions.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FilePath,

        [Parameter(Mandatory = $false)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $false)]
        [string]$SchemaDirectory
    )

    $schemaDir = if ($SchemaDirectory) { $SchemaDirectory } else { Join-Path -Path $PSScriptRoot -ChildPath 'schemas' }
    $mappingPath = Join-Path -Path $schemaDir -ChildPath 'schema-mapping.json'

    if (-not (Test-Path $mappingPath)) {
        return $null
    }

    try {
        $mapping = Get-Content $mappingPath | ConvertFrom-Json

        if (-not $RepoRoot) {
            $RepoRoot = $PSScriptRoot
            while ($RepoRoot -and -not (Test-Path (Join-Path $RepoRoot '.git'))) {
                $RepoRoot = Split-Path -Parent $RepoRoot
            }
            if (-not $RepoRoot) {
                Write-Warning "Could not find repository root"
                return $null
            }
        }

        $relativePath = [System.IO.Path]::GetRelativePath($RepoRoot, $FilePath) -replace '\\', '/'
        $fileName = [System.IO.Path]::GetFileName($FilePath)

        foreach ($rule in $mapping.mappings) {
            # Handle recursive glob patterns (e.g., docs/**/*.md)
            if ($rule.pattern -like "*/**/*") {
                $regexPattern = $rule.pattern -replace '\.', '\.'
                $regexPattern = $regexPattern -replace '\*\*/', '(.*/)?'
                $regexPattern = $regexPattern -replace '\*', '[^/]*'
                $regexPattern = '^' + $regexPattern + '$'
                if ($relativePath -match $regexPattern) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Handle pipe-separated filename alternatives (e.g., README.md|CONTRIBUTING.md)
            elseif ($rule.pattern -match '\|') {
                $patterns = $rule.pattern -split '\|'
                if ($relativePath -eq $fileName -and $fileName -in $patterns) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
            # Handle simple glob patterns with wildcard pre-filter
            elseif ($relativePath -like $rule.pattern -or $fileName -like $rule.pattern) {
                $regexPattern = $rule.pattern -replace '\.', '\.'
                $regexPattern = $regexPattern -replace '\*\*/', '(.*/)?'
                $regexPattern = $regexPattern -replace '\*', '[^/]*'
                $regexPattern = '^' + $regexPattern + '$'
                if ($relativePath -match $regexPattern) {
                    return Join-Path -Path $schemaDir -ChildPath $rule.schema
                }
            }
        }

        if ($mapping.defaultSchema) {
            return Join-Path -Path $schemaDir -ChildPath $mapping.defaultSchema
        }
    }
    catch {
        Write-Warning "Error reading schema mapping: $_"
    }

    return $null
}

function Test-JsonSchemaValidation {
    <#
    .SYNOPSIS
    Validates a frontmatter hashtable against a JSON Schema.

    .DESCRIPTION
    Performs validation of frontmatter data against a JSON Schema file using
    PowerShell native capabilities. Checks required fields, type constraints,
    pattern matching, enum values, and minimum length requirements.

    Validation coverage:
    - required: Field presence validation
    - type: string, array, boolean type checking
    - pattern: Regex pattern matching for strings
    - enum: Allowed value constraints
    - minLength: Minimum string length validation

    Limitations (intentional for soft validation):
    - $ref: Schema references not resolved
    - allOf/anyOf/oneOf: Composition keywords not supported
    - object: Nested object validation not implemented

    .PARAMETER Frontmatter
    Hashtable containing parsed frontmatter key-value pairs.

    .PARAMETER SchemaPath
    Absolute path to the JSON Schema file.

    .PARAMETER SchemaContent
    Pre-loaded schema object (PSCustomObject from ConvertFrom-Json).
    Alternative to SchemaPath for testing without file I/O.

    .INPUTS
    [hashtable] Frontmatter data to validate.

    .OUTPUTS
    [SchemaValidationResult] Object containing:
      - IsValid: Boolean indicating validation success
      - Errors: Array of error messages
      - Warnings: Array of warning messages
      - SchemaUsed: Path to schema file used
      - Note: Additional validation context

    .EXAMPLE
    $frontmatter = @{ title = 'My Doc'; description = 'A description' }
    $result = Test-JsonSchemaValidation -Frontmatter $frontmatter -SchemaPath 'schemas/docs.schema.json'
    if (-not $result.IsValid) {
        $result.Errors | ForEach-Object { Write-Error $_ }
    }

    .EXAMPLE
    # Testing with in-memory schema
    $schema = @{
        required = @('title')
        properties = @{
            title = @{ type = 'string'; minLength = 1 }
        }
    } | ConvertTo-Json | ConvertFrom-Json
    $result = Test-JsonSchemaValidation -Frontmatter @{ title = '' } -SchemaContent $schema
    # Result.Errors contains "Field 'title' must have minimum length of 1"

    .NOTES
    This implements soft validation suitable for advisory feedback without
    blocking builds on schema violations.
    #>
    [CmdletBinding(DefaultParameterSetName = 'SchemaPath')]
    [OutputType([SchemaValidationResult])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaPath')]
        [ValidateNotNullOrEmpty()]
        [string]$SchemaPath,

        [Parameter(Mandatory = $true, ParameterSetName = 'SchemaContent')]
        [PSCustomObject]$SchemaContent
    )

    $errors = [List[string]]::new()
    $warnings = [List[string]]::new()
    $schemaUsed = $SchemaPath

    if ($PSCmdlet.ParameterSetName -eq 'SchemaPath') {
        if (-not (Test-Path $SchemaPath)) {
            return [SchemaValidationResult]::new(
                $false,
                @("Schema file not found: $SchemaPath"),
                @(),
                $SchemaPath,
                $null
            )
        }

        try {
            $SchemaContent = Get-Content $SchemaPath -Raw | ConvertFrom-Json
        }
        catch {
            return [SchemaValidationResult]::new(
                $false,
                @("Failed to parse schema: $_"),
                @(),
                $SchemaPath,
                $null
            )
        }
    }
    else {
        $schemaUsed = '<in-memory>'
    }

    try {
        if ($SchemaContent.required) {
            foreach ($requiredField in $SchemaContent.required) {
                if (-not $Frontmatter.ContainsKey($requiredField)) {
                    $errors.Add("Missing required field: $requiredField")
                }
            }
        }

        if ($SchemaContent.properties) {
            foreach ($prop in $SchemaContent.properties.PSObject.Properties) {
                $fieldName = $prop.Name
                $fieldSchema = $prop.Value

                if ($Frontmatter.ContainsKey($fieldName)) {
                    $value = $Frontmatter[$fieldName]

                    if ($fieldSchema.type) {
                        switch ($fieldSchema.type) {
                            'string' {
                                if ($value -isnot [string]) {
                                    $errors.Add("Field '$fieldName' must be a string")
                                }
                            }
                            'array' {
                                if ($value -isnot [array] -and $value -isnot [System.Collections.IEnumerable]) {
                                    $errors.Add("Field '$fieldName' must be an array")
                                }
                            }
                            'boolean' {
                                if ($value -isnot [bool] -and $value -notin @('true', 'false', 'True', 'False')) {
                                    $errors.Add("Field '$fieldName' must be a boolean")
                                }
                            }
                        }
                    }

                    if ($fieldSchema.pattern -and $value -is [string]) {
                        if ($value -notmatch $fieldSchema.pattern) {
                            $errors.Add("Field '$fieldName' does not match required pattern: $($fieldSchema.pattern)")
                        }
                    }

                    if ($fieldSchema.enum) {
                        if ($value -is [array]) {
                            foreach ($item in $value) {
                                if ($item -notin $fieldSchema.enum) {
                                    $errors.Add("Field '$fieldName' contains invalid value: $item. Allowed: $($fieldSchema.enum -join ', ')")
                                }
                            }
                        }
                        else {
                            if ($value -notin $fieldSchema.enum) {
                                $errors.Add("Field '$fieldName' must be one of: $($fieldSchema.enum -join ', '). Got: $value")
                            }
                        }
                    }

                    if ($fieldSchema.minLength -and $value -is [string]) {
                        if ($value.Length -lt $fieldSchema.minLength) {
                            $errors.Add("Field '$fieldName' must have minimum length of $($fieldSchema.minLength)")
                        }
                    }
                }
            }
        }

        return [SchemaValidationResult]::new(
            ($errors.Count -eq 0),
            $errors.ToArray(),
            $warnings.ToArray(),
            $schemaUsed,
            'Schema validation using PowerShell native capabilities'
        )
    }
    catch {
        return [SchemaValidationResult]::new(
            $false,
            @("Schema validation error: $_"),
            @(),
            $schemaUsed,
            $null
        )
    }
}

function Get-FileTypeInfo {
    <#
    .SYNOPSIS
    Classifies a markdown file by its type and location within the repository.

    .DESCRIPTION
    Pure function that analyzes a file's path and name to determine its type
    category for frontmatter validation rules. Returns a typed object with
    boolean flags for each recognized file type.

    .PARAMETER File
    FileInfo object representing the markdown file to classify.

    .PARAMETER RepoRoot
    Repository root path for determining relative location.

    .INPUTS
    [System.IO.FileInfo] File object to classify.

    .OUTPUTS
    [FileTypeInfo] Object with boolean flags for file classification.

    .EXAMPLE
    $fileInfo = Get-Item 'docs/getting-started/README.md'
    $type = Get-FileTypeInfo -File $fileInfo -RepoRoot '/repo'
    if ($type.IsDocsFile) { # Apply docs validation rules }
    #>
    [CmdletBinding()]
    [OutputType([FileTypeInfo])]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]$RepoRoot
    )

    $info = [FileTypeInfo]::new()
    $info.IsGitHub = $File.DirectoryName -like "*.github*"
    $info.IsChatMode = $File.Name -like "*.chatmode.md"
    $info.IsPrompt = $File.Name -like "*.prompt.md"
    $info.IsInstruction = $File.Name -like "*.instructions.md"
    $info.IsRootCommunityFile = ($File.DirectoryName -eq $RepoRoot) -and
        ($File.Name -in @('CODE_OF_CONDUCT.md', 'CONTRIBUTING.md', 'SECURITY.md', 'SUPPORT.md', 'README.md'))
    $info.IsDevContainer = $File.DirectoryName -like "*.devcontainer*" -and $File.Name -eq 'README.md'
    $info.IsVSCodeReadme = $File.DirectoryName -like "*.vscode*" -and $File.Name -eq 'README.md'
    # Exclude .copilot-tracking (gitignored workflow artifacts) and GitHub templates from docs validation
    $isCopilotTracking = $File.DirectoryName -like "*.copilot-tracking*"
    $isTemplate = $File.Name -like "*TEMPLATE*"
    $info.IsDocsFile = $File.DirectoryName -like "*docs*" -and -not $info.IsGitHub -and -not $isCopilotTracking -and -not $isTemplate

    return $info
}

function Get-RepoRoot {
    <#
    .SYNOPSIS
    Resolves the repository root, falling back to git when available.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param()

    $repoRoot = (Get-Location).Path
    if (-not (Test-Path '.git')) {
        $gitRoot = git rev-parse --show-toplevel 2>$null
        if ($gitRoot) {
            $repoRoot = $gitRoot
        }
    }

    return $repoRoot
}

function Sanitize-InputList {
    <#
    .SYNOPSIS
    Trims and filters out empty entries from string arrays.
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$InputList = @()
    )

    $sanitized = @()
    foreach ($item in $InputList) {
        if (-not [string]::IsNullOrEmpty($item)) {
            $sanitized += $item.Trim()
        }
    }

    return $sanitized
}

function New-ValidationState {
    <#
    .SYNOPSIS
    Creates a shared state object for accumulating validation results.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    return @{
        Errors = [System.Collections.Generic.List[string]]::new()
        Warnings = [System.Collections.Generic.List[string]]::new()
        FilesWithErrors = [System.Collections.Generic.HashSet[string]]::new()
        FilesWithWarnings = [System.Collections.Generic.HashSet[string]]::new()
    }
}

function Add-ValidationError {
    <#
    .SYNOPSIS
    Records an error and tracks the associated file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$FilePath
    )

    $State.Errors.Add($Message)
    if (-not [string]::IsNullOrEmpty($FilePath)) {
        [void]$State.FilesWithErrors.Add($FilePath)
    }
}

function Add-ValidationWarning {
    <#
    .SYNOPSIS
    Records a warning and tracks the associated file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$FilePath
    )

    $State.Warnings.Add($Message)
    if (-not [string]::IsNullOrEmpty($FilePath)) {
        [void]$State.FilesWithWarnings.Add($FilePath)
    }
}

function Get-FooterRequirement {
    <#
    .SYNOPSIS
    Determines whether a file should include the Copilot footer and its severity.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [FileTypeInfo]$FileTypeInfo,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File
    )

    $shouldHaveFooter = $false
    $footerSeverity = 'Error'

    if ($FileTypeInfo.IsRootCommunityFile -or $FileTypeInfo.IsDevContainer -or $FileTypeInfo.IsVSCodeReadme) {
        $shouldHaveFooter = $true
    }
    elseif ($FileTypeInfo.IsGitHub -and $File.Name -eq 'README.md') {
        $shouldHaveFooter = $true
    }

    return [pscustomobject]@{
        ShouldHaveFooter = $shouldHaveFooter
        Severity = $footerSeverity
    }
}

function Validate-RootCommunityFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter
    )

    $requiredFields = @('title', 'description')
    $suggestedFields = @('author', 'ms.date')

    foreach ($field in $requiredFields) {
        if (-not $Frontmatter.ContainsKey($field)) {
            Add-ValidationError -State $State -Message "Missing required field '$field' in: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $File.FullName
        }
    }

    foreach ($field in $suggestedFields) {
        if (-not $Frontmatter.ContainsKey($field)) {
            Add-ValidationWarning -State $State -Message "Suggested field '$field' missing in: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'warning' -Message "Suggested field '$field' missing" -File $File.FullName
        }
    }

    if ($Frontmatter.ContainsKey('ms.date')) {
        $date = $Frontmatter['ms.date']
        if ($date -notmatch '^(\d{4}-\d{2}-\d{2}|\(YYYY-MM-dd\))$') {
            Add-ValidationWarning -State $State -Message "Invalid date format in: $($File.FullName). Expected YYYY-MM-DD (ISO 8601), got: $date" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'warning' -Message "Invalid date format: Expected YYYY-MM-DD (ISO 8601), got: $date" -File $File.FullName
        }
    }
}

function Validate-DevContainerFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter
    )

    $requiredFields = @('title', 'description')

    foreach ($field in $requiredFields) {
        if (-not $Frontmatter.ContainsKey($field)) {
            Add-ValidationError -State $State -Message "Missing required field '$field' in: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $File.FullName
        }
    }
}

function Validate-VSCodeReadmeFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter
    )

    $requiredFields = @('title', 'description')

    foreach ($field in $requiredFields) {
        if (-not $Frontmatter.ContainsKey($field)) {
            Add-ValidationError -State $State -Message "Missing required field '$field' in: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $File.FullName
        }
    }
}

function Validate-GitHubFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter,

        [Parameter(Mandatory = $true)]
        [bool]$IsAgent,

        [Parameter(Mandatory = $true)]
        [bool]$IsChatMode,

        [Parameter(Mandatory = $true)]
        [bool]$IsInstruction,

        [Parameter(Mandatory = $true)]
        [bool]$IsPrompt
    )

    if ($IsAgent -or $IsChatMode) {
        if (-not $Frontmatter.ContainsKey('description')) {
            Add-ValidationWarning -State $State -Message "Agent file missing 'description' field: $($File.FullName)" -FilePath $File.FullName
        }
        return
    }

    if ($IsInstruction) {
        if (-not $Frontmatter.ContainsKey('applyTo')) {
            Write-Verbose "Instruction file missing optional 'applyTo' field: $($File.FullName)"
        }

        if (-not $Frontmatter.ContainsKey('description')) {
            Add-ValidationError -State $State -Message "Instruction file missing required 'description' field: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'error' -Message "Missing required field 'description'" -File $File.FullName
        }
        return
    }

    if ($IsPrompt) {
        return
    }

    if ($File.Name -like "*template*" -and -not ($File.Name -in @('PULL_REQUEST_TEMPLATE.md', 'ISSUE_TEMPLATE.md')) -and -not $Frontmatter.ContainsKey('name')) {
        Add-ValidationWarning -State $State -Message "GitHub template missing 'name' field: $($File.FullName)" -FilePath $File.FullName
    }
}

function Validate-DocsFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter
    )

    $requiredDocsFields = @('title', 'description')
    $suggestedDocsFields = @('author', 'ms.date', 'ms.topic')

    foreach ($field in $requiredDocsFields) {
        if (-not $Frontmatter.ContainsKey($field)) {
            Add-ValidationError -State $State -Message "Documentation file missing required field '$field' in: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'error' -Message "Missing required field '$field'" -File $File.FullName
        }
    }

    foreach ($field in $suggestedDocsFields) {
        if (-not $Frontmatter.ContainsKey($field)) {
            Add-ValidationWarning -State $State -Message "Documentation file missing suggested field '$field' in: $($File.FullName)" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'warning' -Message "Suggested field '$field' missing" -File $File.FullName
        }
    }

    if ($Frontmatter.ContainsKey('ms.date')) {
        $date = $Frontmatter['ms.date']
        if ($date -notmatch '^(\d{4}-\d{2}-\d{2}|\(YYYY-MM-dd\))$') {
            Add-ValidationWarning -State $State -Message "Invalid date format in: $($File.FullName). Expected YYYY-MM-DD (ISO 8601), got: $date" -FilePath $File.FullName
            Write-GitHubAnnotation -Type 'warning' -Message "Invalid date format: Expected YYYY-MM-DD (ISO 8601), got: $date" -File $File.FullName
        }
    }
}

function Validate-SharedFields {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [hashtable]$Frontmatter
    )

    if ($Frontmatter.ContainsKey('keywords')) {
        $keywords = $Frontmatter['keywords']
        if ($keywords -isnot [array] -and $keywords -notmatch ',') {
            Add-ValidationWarning -State $State -Message "Keywords should be an array in: $($File.FullName)" -FilePath $File.FullName
        }
    }

    if ($Frontmatter.ContainsKey('estimated_reading_time')) {
        $readingTime = $Frontmatter['estimated_reading_time']
        if ($readingTime -notmatch '^\d+$') {
            Add-ValidationWarning -State $State -Message "Invalid estimated_reading_time format in: $($File.FullName). Should be a number." -FilePath $File.FullName
        }
    }
}

function Validate-FooterPresence {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$Requirement,

        [Parameter(Mandatory = $true)]
        [string]$Content,

        [Parameter(Mandatory = $true)]
        [bool]$SkipFooterValidation
    )

    if ($SkipFooterValidation -or -not $Requirement.ShouldHaveFooter -or [string]::IsNullOrEmpty($Content)) {
        return
    }

    $hasFooter = Test-MarkdownFooter -Content $Content
    if ($hasFooter) {
        return
    }

    $footerMessage = "Missing standard Copilot footer in: $($File.FullName)"

    if ($Requirement.Severity -eq 'Error') {
        Add-ValidationError -State $State -Message $footerMessage -FilePath $File.FullName
        Write-GitHubAnnotation -Type 'error' -Message "Missing standard Copilot footer" -File $File.FullName
    }
    else {
        Add-ValidationWarning -State $State -Message $footerMessage -FilePath $File.FullName
        Write-GitHubAnnotation -Type 'warning' -Message "Missing standard Copilot footer" -File $File.FullName
    }
}

function Handle-MissingFrontmatter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State
    )

    $isGitHubLocal = $File.DirectoryName -like '*.github*'
    $isMainDocLocal = ($File.DirectoryName -like '*docs*' -or $File.DirectoryName -like '*scripts*') -and -not $isGitHubLocal

    if ($isMainDocLocal) {
        Add-ValidationWarning -State $State -Message "No frontmatter found in: $($File.FullName)" -FilePath $File.FullName
    }
}

function Resolve-ExplicitMarkdownFiles {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Files,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [string[]]$ExcludePaths = @(),

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    [System.IO.FileInfo[]]$resolved = @()

    foreach ($file in $Files) {
        if (-not [string]::IsNullOrEmpty($file) -and (Test-Path $file -PathType Leaf)) {
            if ($file -like '*.md') {
                $fileItem = Get-Item $file
                if ($null -ne $fileItem -and -not [string]::IsNullOrEmpty($fileItem.FullName)) {
                    $excluded = $false
                    if ($ExcludePaths.Count -gt 0) {
                        $relativePath = $fileItem.FullName.Replace($RepoRoot, '').TrimStart([char[]]@('\', '/')).Replace('\\', '/')
                        foreach ($excludePattern in $ExcludePaths) {
                            if ($relativePath -like $excludePattern) {
                                $excluded = $true
                                Write-Verbose "Excluding file matching pattern '$excludePattern': $relativePath"
                                break
                            }
                        }
                    }

                    if (-not $excluded) {
                        $resolved += $fileItem
                        Write-Verbose "Added specific file: $file"
                    }
                }
            }
            else {
                Write-Verbose "Skipping non-markdown file: $file"
            }
        }
        else {
            Write-Warning "File not found or invalid: $file"
        }
    }

    return $resolved
}

function Discover-MarkdownFilesFromPaths {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$Paths,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [string[]]$GitIgnorePatterns = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [string[]]$ExcludePaths = @(),

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    [System.IO.FileInfo[]]$discovered = @()

    foreach ($path in $Paths) {
        if (-not (Test-Path $path)) {
            Write-Warning "Path not found: $path"
            continue
        }

        $rawFiles = Get-ChildItem -Path $path -Filter '*.md' -Recurse -File -ErrorAction SilentlyContinue

        foreach ($f in $rawFiles) {
            if ($null -eq $f -or [string]::IsNullOrEmpty($f.FullName) -or $f.PSIsContainer) {
                continue
            }

            $excluded = $false
            foreach ($pattern in $GitIgnorePatterns) {
                if ($f.FullName -like $pattern) {
                    $excluded = $true
                    break
                }
            }

            if (-not $excluded -and $ExcludePaths.Count -gt 0) {
                $relativePath = $f.FullName.Replace($RepoRoot, '').TrimStart([char[]]@('\', '/')).Replace('\\', '/')
                foreach ($excludePattern in $ExcludePaths) {
                    if ($relativePath -like $excludePattern) {
                        $excluded = $true
                        Write-Verbose "Excluding file matching pattern '$excludePattern': $relativePath"
                        break
                    }
                }
            }

            if (-not $excluded) {
                $discovered += $f
            }
        }
    }

    return $discovered
}

function Get-MarkdownFilesFromInputs {
    [CmdletBinding()]
    [OutputType([System.IO.FileInfo[]])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Files = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Paths = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [string[]]$ExcludePaths = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [AllowNull()]
        [string[]]$GitIgnorePatterns = @(),

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    if ($Files.Count -gt 0) {
        Write-Host "Validating specific files..." -ForegroundColor Cyan
        return Resolve-ExplicitMarkdownFiles -Files $Files -ExcludePaths $ExcludePaths -RepoRoot $RepoRoot
    }

    Write-Host "Searching for markdown files in specified paths..." -ForegroundColor Cyan
    return Discover-MarkdownFilesFromPaths -Paths $Paths -GitIgnorePatterns $GitIgnorePatterns -ExcludePaths $ExcludePaths -RepoRoot $RepoRoot
}

function Validate-MarkdownFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]$File,

        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot,

        [Parameter(Mandatory = $true)]
        [bool]$SkipFooterValidation,

        [Parameter(Mandatory = $true)]
        [bool]$SchemaValidationEnabled
    )

    Write-Verbose "Validating: $($File.FullName)"

    $frontmatter = Get-MarkdownFrontmatter -FilePath $File.FullName
    if (-not $frontmatter) {
        Handle-MissingFrontmatter -File $File -State $State
        return
    }

    if ($SchemaValidationEnabled) {
        $schemaPath = Get-SchemaForFile -FilePath $File.FullName
        if ($schemaPath) {
            $schemaResult = Test-JsonSchemaValidation -Frontmatter $frontmatter.Frontmatter -SchemaPath $schemaPath
            if ($schemaResult.Errors.Count -gt 0) {
                Write-Warning "JSON Schema validation errors in $($File.FullName):"
                $schemaResult.Errors | ForEach-Object { Write-Warning "  - $_" }
            }
            if ($schemaResult.Warnings.Count -gt 0) {
                Write-Verbose "JSON Schema validation warnings in $($File.FullName):"
                $schemaResult.Warnings | ForEach-Object { Write-Verbose "  - $_" }
            }
        }
    }

    $fileTypeInfo = Get-FileTypeInfo -File $File -RepoRoot $RepoRoot
    $isAgent = $File.Name -like '*.agent.md'
    $isChatMode = $fileTypeInfo.IsChatMode
    $isPrompt = $fileTypeInfo.IsPrompt
    $isInstruction = $fileTypeInfo.IsInstruction

    if ($fileTypeInfo.IsRootCommunityFile) {
        Validate-RootCommunityFrontmatter -File $File -State $State -Frontmatter $frontmatter.Frontmatter
    }
    elseif ($fileTypeInfo.IsDevContainer) {
        Validate-DevContainerFrontmatter -File $File -State $State -Frontmatter $frontmatter.Frontmatter
    }
    elseif ($fileTypeInfo.IsVSCodeReadme) {
        Validate-VSCodeReadmeFrontmatter -File $File -State $State -Frontmatter $frontmatter.Frontmatter
    }
    elseif ($fileTypeInfo.IsGitHub) {
        Validate-GitHubFrontmatter -File $File -State $State -Frontmatter $frontmatter.Frontmatter -IsAgent $isAgent -IsChatMode $isChatMode -IsInstruction $isInstruction -IsPrompt $isPrompt
    }

    if ($fileTypeInfo.IsDocsFile) {
        Validate-DocsFrontmatter -File $File -State $State -Frontmatter $frontmatter.Frontmatter
    }

    Validate-SharedFields -File $File -State $State -Frontmatter $frontmatter.Frontmatter

    $footerRequirement = Get-FooterRequirement -FileTypeInfo $fileTypeInfo -File $File
    Validate-FooterPresence -File $File -State $State -Requirement $footerRequirement -Content $frontmatter.Content -SkipFooterValidation $SkipFooterValidation
}

function Export-ValidationResults {
    <#
    .SYNOPSIS
    Writes validation results to logs/frontmatter-validation-results.json.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$MarkdownFiles,

        [Parameter(Mandatory = $true)]
        [string]$RepoRoot
    )

    $logsDir = Join-Path -Path $RepoRoot -ChildPath 'logs'
    if (-not (Test-Path $logsDir)) {
        New-Item -ItemType Directory -Path $logsDir -Force | Out-Null
    }

    $resultsJson = @{
        timestamp = (Get-Date).ToUniversalTime().ToString('o')
        script = 'frontmatter-validation'
        summary = @{
            total_files = $MarkdownFiles.Count
            files_with_errors = $State.FilesWithErrors.Count
            files_with_warnings = $State.FilesWithWarnings.Count
            total_errors = $State.Errors.Count
            total_warnings = $State.Warnings.Count
        }
        errors = $State.Errors
        warnings = $State.Warnings
    }

    $resultsPath = Join-Path -Path $logsDir -ChildPath 'frontmatter-validation-results.json'
    $resultsJson | ConvertTo-Json -Depth 10 | Set-Content -Path $resultsPath -Encoding UTF8

    return [pscustomobject]@{
        Results = $resultsJson
        Path    = $resultsPath
    }
}

function Write-ValidationSummary {
    <#
    .SYNOPSIS
    Emits console and GitHub summary output and returns overall status.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$State,

        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo[]]$MarkdownFiles,

        [Parameter(Mandatory = $true)]
        [pscustomobject]$ResultsJson,

        [Parameter(Mandatory = $true)]
        [bool]$WarningsAsErrors
    )

    $hasIssues = $false

    if ($State.Warnings.Count -gt 0) {
        Write-Host "⚠️ Warnings found:" -ForegroundColor Yellow
        $State.Warnings | ForEach-Object { Write-Host "  $_" -ForegroundColor Yellow }
        if ($WarningsAsErrors) {
            $hasIssues = $true
        }
    }

    if ($State.Errors.Count -gt 0) {
        Write-Host "❌ Errors found:" -ForegroundColor Red
        $State.Errors | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
        $hasIssues = $true
    }

    if ($hasIssues) {
        $summaryContent = @"
## ❌ Frontmatter Validation Failed

**Files checked:** $($MarkdownFiles.Count)
**Files with errors:** $($ResultsJson.summary.files_with_errors)
**Files with warnings:** $($ResultsJson.summary.files_with_warnings)
**Total errors:** $($State.Errors.Count)
**Total warnings:** $($State.Warnings.Count)

### Issues Found

"@

        if ($State.Errors.Count -gt 0) {
            $summaryContent += "`n#### Errors`n`n"
            foreach ($errorItem in $State.Errors | Select-Object -First 10) {
                $summaryContent += "- ❌ $errorItem`n"
            }
            if ($State.Errors.Count -gt 10) {
                $summaryContent += "`n*... and $($State.Errors.Count - 10) more errors*`n"
            }
        }

        if ($State.Warnings.Count -gt 0) {
            $summaryContent += "`n#### Warnings`n`n"
            foreach ($warning in $State.Warnings | Select-Object -First 10) {
                $summaryContent += "- ⚠️ $warning`n"
            }
            if ($State.Warnings.Count -gt 10) {
                $summaryContent += "`n*... and $($State.Warnings.Count - 10) more warnings*`n"
            }
        }

        $summaryContent += @"


### How to Fix

1. Review the errors and warnings listed above
2. Update frontmatter fields as required
3. Ensure date formats follow ISO 8601 (YYYY-MM-DD)
4. Add missing Copilot attribution footer where required
5. Re-run validation to verify fixes

See the uploaded artifact for complete details.
"@

        Write-GitHubStepSummary -Content $summaryContent
        Set-GitHubEnv -Name 'FRONTMATTER_VALIDATION_FAILED' -Value 'true'
    }
    else {
        $summaryContent = @"
## ✅ Frontmatter Validation Passed

**Files checked:** $($MarkdownFiles.Count)
**Errors:** 0
**Warnings:** 0

All frontmatter fields are valid and properly formatted. Great job! 🎉
"@

        Write-GitHubStepSummary -Content $summaryContent
        Write-Host "✅ Frontmatter validation completed successfully" -ForegroundColor Green
    }

    return $hasIssues
}

function Test-FrontmatterValidation {
    <#
    .SYNOPSIS
    Validates frontmatter consistency across markdown files in specified paths.

    .DESCRIPTION
    Performs comprehensive frontmatter validation including:
    - Required field presence (title, description)
    - Date format validation (ISO 8601: YYYY-MM-DD)
    - Content type-specific requirements (docs, instructions, chatmodes)
    - Optional JSON Schema validation against defined schemas
    - Copilot attribution footer presence (configurable)

    Supports multiple input modes:
    - Directory scanning with -Paths parameter
    - Explicit file list with -Files parameter
    - Git diff-based changed files with -ChangedFilesOnly switch

    Output includes GitHub Actions annotations for CI integration and
    generates a JSON results file in the logs directory.

    .PARAMETER Paths
    Array of directory paths to search recursively for markdown files.
    Mutually exclusive with -Files when -Files has values.

    .PARAMETER Files
    Array of specific file paths to validate. Takes precedence over -Paths.

    .PARAMETER SkipFooterValidation
    Skip validation of Copilot attribution footer presence.

    .PARAMETER WarningsAsErrors
    Treat warnings as errors (causes validation to fail on warnings).

    .PARAMETER ChangedFilesOnly
    Only validate markdown files changed since the base branch (git diff).

    .PARAMETER BaseBranch
    Git reference for comparison when using -ChangedFilesOnly. Default: 'origin/main'.

    .PARAMETER EnableSchemaValidation
    Enable JSON Schema validation against schema-mapping.json definitions.
    Schema validation operates in soft mode (advisory only, does not fail builds).
    #>
    [CmdletBinding()]
    [OutputType([ValidationResult])]
    param(
        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Paths = @(),

        [Parameter(Mandatory = $false)]
        [switch]$SkipFooterValidation,

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$Files = @(),

        [Parameter(Mandatory = $false)]
        [AllowEmptyCollection()]
        [string[]]$ExcludePaths = @(),

        [Parameter(Mandatory = $false)]
        [switch]$WarningsAsErrors,

        [Parameter(Mandatory = $false)]
        [switch]$ChangedFilesOnly,

        [Parameter(Mandatory = $false)]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [switch]$EnableSchemaValidation
    )

    $repoRoot = Get-RepoRoot
    $gitignorePath = Join-Path $repoRoot '.gitignore'
    $gitignorePatterns = Get-GitIgnorePatterns -GitIgnorePath $gitignorePath
    if ($null -eq $gitignorePatterns) {
        $gitignorePatterns = @()
    }

    Write-Host "🔍 Validating frontmatter across markdown files..." -ForegroundColor Cyan

    $state = New-ValidationState

    if ($ChangedFilesOnly) {
        Write-Host "🔍 Detecting changed markdown files from git diff..." -ForegroundColor Cyan
        $gitChangedFiles = Get-ChangedMarkdownFileGroup -BaseBranch $BaseBranch
        if ($gitChangedFiles.Count -gt 0) {
            $Files = $gitChangedFiles
            Write-Host "Found $($Files.Count) changed markdown files to validate" -ForegroundColor Cyan
        }
        else {
            Write-Host "No changed markdown files found - validation complete" -ForegroundColor Green
            return [ValidationResult]::new(@(), @(), $false, 0)
        }
    }

    $Files = Sanitize-InputList -InputList $Files
    $Paths = Sanitize-InputList -InputList $Paths

    if ($null -eq $Files) {
        $Files = @()
    }

    if ($null -eq $Paths) {
        $Paths = @()
    }

    if ($Files.Count -eq 0 -and $Paths.Count -eq 0) {
        Add-ValidationWarning -State $state -Message 'No valid files or paths provided for validation'
        return [ValidationResult]::new(@(), $state.Warnings.ToArray(), $true, 0)
    }

    if ($null -eq $ExcludePaths) { $ExcludePaths = @() }
    if ($null -eq $gitignorePatterns) { $gitignorePatterns = @() }

    $markdownFiles = Get-MarkdownFilesFromInputs -Files $Files -Paths $Paths -ExcludePaths $ExcludePaths -GitIgnorePatterns $gitignorePatterns -RepoRoot $repoRoot
    Write-Host "Found $($markdownFiles.Count) total markdown files to validate" -ForegroundColor Cyan

    $schemaValidationEnabled = $false
    if ($EnableSchemaValidation) {
        $schemaValidationEnabled = Initialize-JsonSchemaValidation
        if (-not $schemaValidationEnabled) {
            Write-Warning 'Schema validation requested but not available - continuing without schema validation'
        }
    }

    foreach ($file in $markdownFiles) {
        if ($null -eq $file -or [string]::IsNullOrEmpty($file.FullName)) {
            Write-Verbose 'Skipping null or empty file reference'
            continue
        }

        try {
            Validate-MarkdownFile -File $file -State $state -RepoRoot $repoRoot -SkipFooterValidation:$SkipFooterValidation -SchemaValidationEnabled:$schemaValidationEnabled
        }
        catch {
            Add-ValidationError -State $state -Message "Error processing file '$($file.FullName)': $($_.Exception.Message)" -FilePath $file.FullName
            Write-Verbose "Error processing file '$($file.FullName)': $($_.Exception.Message)"
        }
    }

    $resultsInfo = Export-ValidationResults -State $state -MarkdownFiles $markdownFiles -RepoRoot $repoRoot
    $hasIssues = Write-ValidationSummary -State $state -MarkdownFiles $markdownFiles -ResultsJson $resultsInfo.Results -WarningsAsErrors:$WarningsAsErrors

    return [ValidationResult]::new($state.Errors.ToArray(), $state.Warnings.ToArray(), $hasIssues, $markdownFiles.Count)
}

function Get-ChangedMarkdownFileGroup {
    <#
    .SYNOPSIS
    Retrieves changed markdown files from git diff comparison.

    .DESCRIPTION
    Uses git diff to identify markdown files that have changed between the current
    HEAD and a base branch. Implements a fallback strategy when standard comparison
    methods fail:

    1. First attempts: git merge-base comparison with specified base branch
    2. Fallback 1: Comparison with HEAD~1 (previous commit)
    3. Fallback 2: Staged and unstaged files against HEAD

    .PARAMETER BaseBranch
    Git reference for the base branch to compare against. Defaults to 'origin/main'.
    Can be any valid git ref (branch name, tag, commit SHA).

    .PARAMETER FallbackStrategy
    Controls fallback behavior when primary comparison fails.
    - 'Auto' (default): Tries all fallback strategies automatically
    - 'HeadOnly': Only uses HEAD~1 fallback
    - 'None': No fallback, returns empty on failure

    .INPUTS
    None. Does not accept pipeline input.

    .OUTPUTS
    [string[]] Array of relative file paths for changed markdown files.
    Returns empty array if no changes detected or git operations fail.

    .EXAMPLE
    $changedFiles = Get-ChangedMarkdownFileGroup
    # Returns markdown files changed compared to origin/main

    .EXAMPLE
    $changedFiles = Get-ChangedMarkdownFileGroup -BaseBranch 'origin/develop'
    # Returns markdown files changed compared to develop branch

    .EXAMPLE
    $changedFiles = Get-ChangedMarkdownFileGroup -FallbackStrategy 'None'
    # Returns empty array if merge-base comparison fails

    .NOTES
    Requires git to be available in PATH. Files must exist on disk to be included
    in the result (deleted files are excluded).
    #>
    [CmdletBinding()]
    [OutputType([string[]])]
    param(
        [Parameter(Mandatory = $false, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$BaseBranch = "origin/main",

        [Parameter(Mandatory = $false)]
        [ValidateSet('Auto', 'HeadOnly', 'None')]
        [string]$FallbackStrategy = 'Auto'
    )

    try {
        $changedFiles = git diff --name-only $(git merge-base HEAD $BaseBranch) HEAD 2>$null
        if ($LASTEXITCODE -ne 0) {
            Write-Verbose "Merge base comparison with '$BaseBranch' failed"

            if ($FallbackStrategy -eq 'None') {
                Write-Warning "Unable to determine changed files from git (no fallback enabled)"
                return @()
            }

            Write-Verbose "Attempting fallback: HEAD~1 comparison"
            $changedFiles = git diff --name-only HEAD~1 HEAD 2>$null

            if ($LASTEXITCODE -ne 0 -and $FallbackStrategy -eq 'Auto') {
                Write-Verbose "HEAD~1 comparison failed, attempting staged/unstaged files"
                $changedFiles = git diff --name-only HEAD 2>$null

                if ($LASTEXITCODE -ne 0) {
                    Write-Warning "Unable to determine changed files from git"
                    return @()
                }
            }
            elseif ($LASTEXITCODE -ne 0) {
                Write-Warning "Unable to determine changed files from git"
                return @()
            }
        }

        [string[]]$changedMarkdownFiles = $changedFiles | Where-Object {
            -not [string]::IsNullOrEmpty($_) -and
            $_ -match '\.md$' -and
            (Test-Path $_ -PathType Leaf)
        }

        Write-Verbose "Found $($changedMarkdownFiles.Count) changed markdown files from git diff"
        $changedMarkdownFiles | ForEach-Object { Write-Verbose "  Changed: $_" }

        return $changedMarkdownFiles
    }
    catch {
        Write-Warning "Error getting changed files from git: $($_.Exception.Message)"
        return @()
    }
}

# Main execution
if ($MyInvocation.InvocationName -ne '.') {
    if ($ChangedFilesOnly) {
        $result = Test-FrontmatterValidation -ChangedFilesOnly -BaseBranch $BaseBranch -ExcludePaths $ExcludePaths -WarningsAsErrors:$WarningsAsErrors -SkipFooterValidation:$SkipFooterValidation -EnableSchemaValidation:$EnableSchemaValidation
    }
    elseif ($Files.Count -gt 0) {
        $result = Test-FrontmatterValidation -Files $Files -ExcludePaths $ExcludePaths -WarningsAsErrors:$WarningsAsErrors -SkipFooterValidation:$SkipFooterValidation -EnableSchemaValidation:$EnableSchemaValidation
    }
    else {
        $result = Test-FrontmatterValidation -Paths $Paths -ExcludePaths $ExcludePaths -WarningsAsErrors:$WarningsAsErrors -SkipFooterValidation:$SkipFooterValidation -EnableSchemaValidation:$EnableSchemaValidation
    }

    if ($result.HasIssues) {
        exit 1
    }
    else {
        Write-Host "✅ All frontmatter validation checks passed!" -ForegroundColor Green
        exit 0
    }
}
